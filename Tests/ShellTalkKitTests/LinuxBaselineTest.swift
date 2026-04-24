// LinuxBaselineTest.swift — Runs the full 454-case evaluation corpus and
// emits a metrics JSON identical in shape to what `stm-eval --metrics-out`
// produces. Used to establish a Linux baseline when the `stm-eval`
// executable hangs under Docker Desktop's Linux VM.
//
// Gated by the `SHELLTALK_BASELINE_JSON` env var — only runs when a
// target output path is provided. This keeps it out of the default
// `swift test` cycle.
//
// Usage (inside the container):
//   SHELLTALK_BASELINE_JSON=/out/linux-baseline.json swift test --filter LinuxBaseline

import Foundation
import Testing
@testable import ShellTalkKit

@Suite("LinuxBaseline", .enabled(if: ProcessInfo.processInfo.environment["SHELLTALK_BASELINE_JSON"] != nil))
struct LinuxBaselineTest {

  @Test("Evaluate full corpus and emit metrics JSON")
  func runBaseline() throws {
    guard let outPath = ProcessInfo.processInfo.environment["SHELLTALK_BASELINE_JSON"] else {
      Issue.record("SHELLTALK_BASELINE_JSON not set — this test should not have run")
      return
    }

    let pipe = STMPipeline()

    // Collect per-case failure records so the diff script can name
    // exactly which queries regressed on Linux. Emitted into the JSON
    // under `failures:` for downstream analysis.
    struct Failure: Encodable {
      let suite: String
      let query: String
      let expected_tpl: String
      let got_tpl: String
      let expected_cat: String
      let got_cat: String
      let confidence: Double
      let path: String
    }
    var failures: [Failure] = []

    // Per-case accounting
    var totalTests = 0
    var templateOk = 0
    var categoryOk = 0
    var substrOk = 0
    var substrTotal = 0
    var slotOk = 0
    var slotTotal = 0
    var negTotal = 0
    var negOk = 0
    var latencies: [Double] = []
    var suiteTotals: [String: (n: Int, templateOk: Int)] = [:]
    var pathTotals: [String: (n: Int, ok: Int)] = [:]

    let wallStart = Date().timeIntervalSinceReferenceDate

    for (suite, cases) in allCases {
      var sn = 0
      var sTplOk = 0
      for tc in cases {
        totalTests += 1
        sn += 1

        let t0 = Date().timeIntervalSinceReferenceDate
        let r = pipe.process(tc.query)
        let ms = (Date().timeIntervalSinceReferenceDate - t0) * 1000
        latencies.append(ms)

        let isNeg = tc.expectedTemplateId == "_nil_"
        var tplMatch = false
        var catMatch = false
        if isNeg {
          // Negative cases: treat "no match" (r == nil) or a very low-
          // confidence match (< 0.3) as the correct outcome. Same logic
          // as stm-eval so tpl_acc / cat_acc numbers are comparable.
          negTotal += 1
          let accepted = r == nil || (r?.confidence ?? 1.0) < 0.3
          if accepted {
            negOk += 1
            tplMatch = true
            catMatch = true
          }
        } else {
          tplMatch = r?.templateId == tc.expectedTemplateId
          catMatch = r?.categoryId == tc.expectedCategoryId
        }
        if tplMatch { templateOk += 1; sTplOk += 1 }
        if catMatch { categoryOk += 1 }

        // Required substring check
        for req in tc.requiredSubstrings {
          substrTotal += 1
          if let cmd = r?.command, cmd.contains(req) { substrOk += 1 }
        }

        // Slot extraction check
        for (slotKey, expectedVal) in tc.requiredSlots {
          slotTotal += 1
          if let actual = r?.extractedSlots[slotKey], actual == expectedVal {
            slotOk += 1
          }
        }

        // Path bucketing from score signature (same heuristic as STMEval)
        let path: String
        if let r = r {
          let cs = r.categoryScore
          let ts = r.templateScore
          if cs == 1.0 && ts == 1.0 { path = "exact" }
          else if cs == 1.0 && abs(ts - 0.95) < 1e-9 { path = "phrase" }
          else if cs == 1.0 && abs(ts - 0.9) < 1e-9 { path = "prefix" }
          else { path = "bm25" }
        } else {
          path = "none"
        }
        var bucket = pathTotals[path, default: (n: 0, ok: 0)]
        bucket.n += 1
        let caseOk = isNeg ? (r == nil || (r?.confidence ?? 1.0) < 0.3) : tplMatch
        if caseOk { bucket.ok += 1 }
        pathTotals[path] = bucket

        if !caseOk {
          failures.append(Failure(
            suite: suite,
            query: tc.query,
            expected_tpl: tc.expectedTemplateId,
            got_tpl: r?.templateId ?? "(nil)",
            expected_cat: tc.expectedCategoryId,
            got_cat: r?.categoryId ?? "(nil)",
            confidence: r?.confidence ?? 0.0,
            path: path
          ))
        }
      }
      suiteTotals[suite] = (n: sn, templateOk: sTplOk)
    }

    let wallMs = (Date().timeIntervalSinceReferenceDate - wallStart) * 1000

    // Percentile helpers (match STMEval's percentile function)
    let sorted = latencies.sorted()
    func pct(_ p: Double) -> Double {
      guard !sorted.isEmpty else { return 0 }
      let idx = min(sorted.count - 1, Int((Double(sorted.count) * p).rounded(.down)))
      return sorted[idx]
    }

    let perSuite: [String: Double] = suiteTotals.mapValues { s in
      s.n > 0 ? Double(s.templateOk) / Double(s.n) : 0
    }

    struct PathBucket: Encodable { let n: Int; let acc: Double }
    let perPath: [String: PathBucket] = pathTotals.mapValues { b in
      PathBucket(n: b.n, acc: b.n > 0 ? Double(b.ok) / Double(b.n) : 0)
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
      let failures: [Failure]
      let overlay_hash: String
      let overlay_path: String?
      let timestamp: String
    }

    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]

    let metrics = Metrics(
      n_cases: totalTests,
      tpl_acc: Double(templateOk) / Double(totalTests),
      cat_acc: Double(categoryOk) / Double(totalTests),
      substr_acc: substrTotal > 0 ? Double(substrOk) / Double(substrTotal) : 1.0,
      slot_acc: slotTotal > 0 ? Double(slotOk) / Double(slotTotal) : 1.0,
      neg_acc: negTotal > 0 ? Double(negOk) / Double(negTotal) : 1.0,
      mean_ms: sorted.isEmpty ? 0 : sorted.reduce(0, +) / Double(sorted.count),
      p50_ms: pct(0.50),
      p90_ms: pct(0.90),
      p95_ms: pct(0.95),
      p99_ms: pct(0.99),
      max_ms: sorted.last ?? 0,
      wall_ms: wallMs,
      init_ms: pipe.initMs,
      per_suite: perSuite,
      per_path: perPath,
      failures: failures,
      overlay_hash: "none",
      overlay_path: nil,
      timestamp: f.string(from: Date())
    )

    let enc = JSONEncoder()
    enc.outputFormatting = [.sortedKeys, .prettyPrinted]
    let data = try enc.encode(metrics)
    let url = URL(fileURLWithPath: outPath)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: url)

    print("LinuxBaseline: wrote \(data.count) bytes to \(outPath)")
    print("  tpl_acc=\(String(format: "%.4f", metrics.tpl_acc))")
    print("  cat_acc=\(String(format: "%.4f", metrics.cat_acc))")
    print("  slot_acc=\(String(format: "%.4f", metrics.slot_acc))")
    print("  wall_ms=\(String(format: "%.0f", metrics.wall_ms))")

    // Sanity: at least 95% template accuracy should still hold on any platform
    // (way below macOS's 98% but catches total breakage).
    #expect(metrics.tpl_acc >= 0.95)
  }
}
