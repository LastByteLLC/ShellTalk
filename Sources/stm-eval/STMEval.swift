import Foundation
import ShellTalkKit

// EvalCase + allCases moved to ShellTalkKit/EvalCorpus.swift so they're
// shareable between this executable and the swift-test target.


// MARK: - CLI args

struct EvalArgs {
  var traceOut: String?
  var metricsOut: String?
  var overlayPath: String?
  var quiet: Bool = false

  static func parse() -> EvalArgs {
    var args = EvalArgs()
    var i = 1
    let argv = CommandLine.arguments
    while i < argv.count {
      switch argv[i] {
      case "--trace-out":
        i += 1
        if i < argv.count { args.traceOut = argv[i] }
      case "--metrics-out":
        i += 1
        if i < argv.count { args.metricsOut = argv[i] }
      case "--overlay":
        i += 1
        if i < argv.count { args.overlayPath = argv[i] }
      case "--quiet":
        args.quiet = true
      case "--help", "-h":
        print("""
        stm-eval — run ShellTalk accuracy evaluation

        Options:
          --overlay <path>       YAML overlay to mutate matcher config + templates
          --trace-out <path>     Emit JSONL trace (one record per case)
          --metrics-out <path>   Emit aggregate metrics.json
          --quiet                Suppress per-case stdout table
        """)
        exit(0)
      default:
        break
      }
      i += 1
    }
    return args
  }
}

// MARK: - Trace + Metrics schemas

struct TraceRecord: Encodable {
  let q: String
  let suite: String
  let gold_tpl: String
  let gold_cat: String
  let pred_tpl: String?
  let pred_cat: String?
  let ok_tpl: Bool
  let ok_cat: Bool
  let cat_score: Double?
  let tpl_score: Double?
  let conf: Double?
  let path: String
  let bm25_top5: [String]
  let entities: [String]
  let slots: [String: String]
  let miss_substr: [String]
  let safety: String
  let cmd: String?
  let ms: Double
}

struct PathBucket: Encodable {
  let n: Int
  let acc: Double
}

struct Metrics: Encodable {
  let n_cases: Int
  let tpl_acc: Double
  let cat_acc: Double
  let substr_acc: Double
  let slot_acc: Double
  let neg_acc: Double
  let mean_ms: Double
  let p50_ms: Double
  let p90_ms: Double
  let p95_ms: Double
  let p99_ms: Double
  let max_ms: Double
  let wall_ms: Double
  let init_ms: Double
  let per_suite: [String: Double]
  let per_path: [String: PathBucket]
  let overlay_hash: String
  let overlay_path: String?
  let timestamp: String
}

// MARK: - Helpers

private func inferMatchPath(_ r: PipelineResult) -> String {
  // Heuristic from score patterns (see IntentMatcher fast-path scoring):
  // exact/meta: 1.0/1.0, phrase: 1.0/0.95, prefix: 1.0/0.9, else bm25.
  let cs = r.categoryScore, ts = r.templateScore
  if cs == 1.0 && ts == 1.0 { return "exact" }
  if cs == 1.0 && abs(ts - 0.95) < 1e-9 { return "phrase" }
  if cs == 1.0 && abs(ts - 0.9) < 1e-9 { return "prefix" }
  return "bm25"
}

private func percentile(_ sorted: [Double], _ p: Double) -> Double {
  guard !sorted.isEmpty else { return 0 }
  let idx = min(sorted.count - 1, Int((Double(sorted.count) * p).rounded(.down)))
  return sorted[idx]
}

private func iso8601Now() -> String {
  let f = ISO8601DateFormatter()
  f.formatOptions = [.withInternetDateTime]
  return f.string(from: Date())
}

// MARK: - Main

@main
struct STMEval {
  static func main() {
    let args = EvalArgs.parse()

    // Load overlay explicitly (if given). Build pipeline with overlay applied
    // on top of the shipped built-in refinements (TemplateRefinements.default).
    let overlay: PipelineOverlay? = args.overlayPath.flatMap { PipelineOverlay.load(path: $0) }
    let baseMatcherConfig = overlay?.apply(to: .default) ?? .default
    let includeDebug = (args.traceOut != nil)
    let pipelineConfig = PipelineConfig(
      matcherConfig: baseMatcherConfig,
      validateCommands: true,
      includeDebugInfo: includeDebug
    )
    // Base = built-in templates WITH shipped refinements. User overlay stacks on top.
    let refinedCategories = TemplateRefinements.defaultOverlay.apply(to: BuiltInTemplates.all)
    let overlaidCategories = overlay?.apply(to: refinedCategories) ?? refinedCategories
    let store = TemplateStore(categories: overlaidCategories)
    let pipe = STMPipeline(profile: nil, store: store, config: pipelineConfig)

    let totalCount = allCases.reduce(0) { $0 + $1.1.count }
    if !args.quiet {
      print("ShellTalk STM Accuracy Evaluation — \(totalCount) test cases")
      if let p = args.overlayPath { print("Overlay: \(p) (hash=\(overlay?.contentHash() ?? "n/a"))") }
      print(String(repeating: "=", count: 160))
    }

    var totalTests = 0
    var templateOk = 0
    var categoryOk = 0
    var substrOk = 0
    var substrTotal = 0
    var slotOk = 0
    var slotTotal = 0
    var negTotal = 0
    var negOk = 0
    var failures: [(String, String, String, String, String, String)] = []
    var catBreak: [String: (Int, Int, Int)] = [:]
    var latencies: [Double] = []
    var pathCounts: [String: (n: Int, ok: Int)] = [:]
    var traces: [TraceRecord] = []
    let wantTraces = args.traceOut != nil
    let wallStart = Date().timeIntervalSinceReferenceDate

    for (suite, cases) in allCases {
      var st = 0, stOk = 0, scOk = 0

      for tc in cases {
        totalTests += 1; st += 1

        let t0 = Date().timeIntervalSinceReferenceDate
        let r = pipe.process(tc.query)
        let ms = (Date().timeIntervalSinceReferenceDate - t0) * 1000
        latencies.append(ms)

        let isNeg = tc.expectedTemplateId == "_nil_"
        var tOk = false, cOk = false

        if isNeg {
          negTotal += 1
          tOk = r == nil || r!.confidence < 0.3
          cOk = tOk
          if tOk { negOk += 1 }
        } else {
          tOk = r?.templateId == tc.expectedTemplateId
          cOk = r?.categoryId == tc.expectedCategoryId
        }
        if tOk { templateOk += 1; stOk += 1 }
        if cOk { categoryOk += 1; scOk += 1 }

        var missSubstr: [String] = []
        for s in tc.requiredSubstrings {
          substrTotal += 1
          if r?.command.contains(s) == true {
            substrOk += 1
          } else {
            missSubstr.append(s)
          }
        }
        for (k, v) in tc.requiredSlots {
          slotTotal += 1
          if r?.extractedSlots[k] == v { slotOk += 1 }
        }

        let safety: String
        if let v = r?.validation {
          switch v.safetyLevel {
          case .safe: safety = "SAFE"
          case .caution: safety = "CAUTION"
          case .dangerous: safety = "DANGER"
          }
        } else { safety = "N/A" }

        let path: String = r.map(inferMatchPath) ?? "none"
        var bucket = pathCounts[path] ?? (0, 0)
        bucket.n += 1
        if tOk { bucket.ok += 1 }
        pathCounts[path] = bucket

        if !args.quiet {
          let mark = tOk ? "OK " : " X "
          let q = tc.query.isEmpty ? "(empty)" : tc.query
          let cmd = r?.command ?? "(nil)"
          let act = r?.templateId ?? "(nil)"
          print("\(mark) \(q.padding(toLength: 50, withPad: " ", startingAt: 0)) exp=\(tc.expectedTemplateId.padding(toLength: 20, withPad: " ", startingAt: 0)) act=\(act.padding(toLength: 20, withPad: " ", startingAt: 0)) \(safety.padding(toLength: 7, withPad: " ", startingAt: 0)) \(String(format: "%5.1f", ms))ms  \(cmd.prefix(60))")
        }

        if !tOk {
          failures.append((suite, tc.query.isEmpty ? "(empty)" : tc.query, tc.expectedTemplateId, r?.templateId ?? "(nil)", r?.categoryId ?? "(nil)", r?.command ?? "(nil)"))
        }

        if wantTraces {
          let topMatches: [String] = r?.debugInfo?.topMatches.prefix(5).map {
            "\($0.templateId):\(String(format: "%.2f", $0.templateScore))"
          } ?? []
          let entityStrs: [String] = r?.debugInfo?.entities.map {
            "\($0.type.rawValue):\($0.text)"
          } ?? []
          traces.append(TraceRecord(
            q: tc.query,
            suite: suite,
            gold_tpl: tc.expectedTemplateId,
            gold_cat: tc.expectedCategoryId,
            pred_tpl: r?.templateId,
            pred_cat: r?.categoryId,
            ok_tpl: tOk,
            ok_cat: cOk,
            cat_score: r?.categoryScore,
            tpl_score: r?.templateScore,
            conf: r?.confidence,
            path: path,
            bm25_top5: topMatches,
            entities: entityStrs,
            slots: r?.extractedSlots ?? [:],
            miss_substr: missSubstr,
            safety: safety,
            cmd: r?.command,
            ms: ms
          ))
        }
      }
      catBreak[suite] = (st, stOk, scOk)
    }

    if !args.quiet {
      print("\n" + String(repeating: "=", count: 160))
      print("SUMMARY")
      print(String(repeating: "=", count: 160))
    }

    let ta = Double(templateOk) / Double(totalTests) * 100
    let ca = Double(categoryOk) / Double(totalTests) * 100
    let sa = substrTotal > 0 ? Double(substrOk) / Double(substrTotal) * 100 : 100
    let sla = slotTotal > 0 ? Double(slotOk) / Double(slotTotal) * 100 : 100
    let neg = negTotal > 0 ? Double(negOk) / Double(negTotal) * 100 : 100

    if !args.quiet {
      print("Template accuracy:   \(templateOk) / \(totalTests) (\(String(format: "%.1f", ta))%)")
      print("Category accuracy:   \(categoryOk) / \(totalTests) (\(String(format: "%.1f", ca))%)")
      print("Substring checks:    \(substrOk) / \(substrTotal) (\(String(format: "%.1f", sa))%)")
      print("Slot extraction:     \(slotOk) / \(slotTotal) (\(String(format: "%.1f", sla))%)")
      print("Negative rejection:  \(negOk) / \(negTotal) (\(String(format: "%.1f", neg))%)")

      print("\nPER-CATEGORY:")
      for (n, s) in catBreak.sorted(by: { $0.key < $1.key }) {
        let tp = s.0 > 0 ? Double(s.1) / Double(s.0) * 100 : 0
        let cp = s.0 > 0 ? Double(s.2) / Double(s.0) * 100 : 0
        print("  \(n.padding(toLength: 18, withPad: " ", startingAt: 0)) \(s.0) tests  template=\(String(format: "%.0f", tp))%  category=\(String(format: "%.0f", cp))%")
      }

      if !failures.isEmpty {
        print("\nFAILURES (\(failures.count)):")
        for f in failures {
          print("  [\(f.0)] \"\(f.1)\"  expected=\(f.2)  got=\(f.3)  cat=\(f.4)")
          print("    cmd: \(f.5.prefix(100))")
        }
      }

      print("\nDone.")
    }

    // Emit JSONL traces
    if let tracePath = args.traceOut {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      var buf = ""
      for t in traces {
        if let data = try? encoder.encode(t), let s = String(data: data, encoding: .utf8) {
          buf.append(s); buf.append("\n")
        }
      }
      try? createDirectories(forFile: tracePath)
      try? buf.write(toFile: tracePath, atomically: true, encoding: .utf8)
    }

    // Emit metrics.json
    if let metricsPath = args.metricsOut {
      let sorted = latencies.sorted()
      let perSuite = catBreak.mapValues { s -> Double in
        s.0 > 0 ? Double(s.1) / Double(s.0) : 0
      }
      let perPath = pathCounts.mapValues { b -> PathBucket in
        PathBucket(n: b.n, acc: b.n > 0 ? Double(b.ok) / Double(b.n) : 0)
      }
      let wallMs = (Date().timeIntervalSinceReferenceDate - wallStart) * 1000
      let mean = sorted.isEmpty ? 0 : sorted.reduce(0, +) / Double(sorted.count)
      let metrics = Metrics(
        n_cases: totalTests,
        tpl_acc: Double(templateOk) / Double(totalTests),
        cat_acc: Double(categoryOk) / Double(totalTests),
        substr_acc: substrTotal > 0 ? Double(substrOk) / Double(substrTotal) : 1.0,
        slot_acc: slotTotal > 0 ? Double(slotOk) / Double(slotTotal) : 1.0,
        neg_acc: negTotal > 0 ? Double(negOk) / Double(negTotal) : 1.0,
        mean_ms: mean,
        p50_ms: percentile(sorted, 0.50),
        p90_ms: percentile(sorted, 0.90),
        p95_ms: percentile(sorted, 0.95),
        p99_ms: percentile(sorted, 0.99),
        max_ms: sorted.last ?? 0,
        wall_ms: wallMs,
        init_ms: pipe.initMs,
        per_suite: perSuite,
        per_path: perPath,
        overlay_hash: overlay?.contentHash() ?? "none",
        overlay_path: args.overlayPath,
        timestamp: iso8601Now()
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
      if let data = try? encoder.encode(metrics) {
        try? createDirectories(forFile: metricsPath)
        try? data.write(to: URL(fileURLWithPath: metricsPath))
      }
    }
  }
}

private func createDirectories(forFile path: String) throws {
  let url = URL(fileURLWithPath: path)
  let dir = url.deletingLastPathComponent()
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
}
