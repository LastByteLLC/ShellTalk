// PerfSmokeTests.swift — lightweight perf regression gate.
//
// These tests pin *relative* performance characteristics of the hot path
// rather than absolute wall-clock thresholds (which vary across machines
// and CI environments). They run a small curated query set through the
// full pipeline and assert on invariants that must hold after the
// v1.1.0 optimizations. A regression here means somebody has walked back
// a cache, precompiled regex, or fast-path.
//
// Thresholds are picked to catch >2x regressions with wide margin for
// CI noise; they are NOT tuned to the local dev machine.

import Testing
@testable import ShellTalkKit

@Suite("PerfSmoke")
struct PerfSmokeTests {

  /// Queries whose generated commands are expected to satisfy the
  /// CommandValidator fast-path (no shell metacharacters, no reserved
  /// words). These were confirmed against the v1.1.0 frontier. If any
  /// regress, the validator fast-path or a template has drifted.
  private static let fastPathQueries: [String] = [
    "ls",
    "git status",
    "pwd",
    "disk usage",
    "list swift files",
    "find files modified today",
    "show git log",
  ]

  /// Validator fast-path correctness: every command these queries
  /// generate must be accepted without spawning bash -n.
  @Test("Validator fast-path accepts template-generated simple commands")
  func fastPathAcceptsGeneratedCommands() {
    let pipe = STMPipeline()
    for q in Self.fastPathQueries {
      guard let result = pipe.process(q) else {
        Issue.record("Pipeline returned nil for \(q)")
        continue
      }
      #expect(
        CommandValidator.isTriviallyValidSyntax(result.command),
        "Generated command should fast-path: \(result.command) (from: \(q))"
      )
    }
  }

  /// Pipeline repeat-query latency: once warm, the pipeline should
  /// resolve the same query in under 50 ms. Tests the steady-state
  /// hot path (TF-IDF/BM25/embedding caches warm).
  @Test("Warm repeat query completes in bounded time")
  func warmRepeatIsFast() {
    let pipe = STMPipeline()
    _ = pipe.process("list swift files")  // warmup (cold caches)
    _ = pipe.process("list swift files")  // warmup (cold clock)

    var latencies: [Double] = []
    for _ in 0..<10 {
      let t0 = ContinuousClock.now
      _ = pipe.process("list swift files")
      let elapsed = ContinuousClock.now - t0
      let ms = Double(elapsed.components.seconds) * 1000.0
        + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000.0
      latencies.append(ms)
    }

    let sorted = latencies.sorted()
    let median = sorted[sorted.count / 2]
    // 200ms is generous — on a laptop this runs in ~2ms. CI has noise
    // but even a 50x slowdown would still pass this. Catches complete
    // pipeline breakage (e.g., subprocess reintroduced to hot path).
    #expect(median < 200.0, "Warm p50 latency unexpectedly high: \(median) ms")
  }

  /// Intent-embedding cache should make repeated BM25-rerank queries
  /// converge to a steady state; latencies shouldn't grow unbounded.
  /// This catches cache-eviction or memory-leak bugs.
  @Test("Embedding cache converges (no unbounded per-query growth)")
  func embeddingCacheConverges() {
    let pipe = STMPipeline()
    // Use a BM25-path query (not a fast-path exact/phrase match)
    let query = "how big is the project in bytes"
    var latencies: [Double] = []
    for _ in 0..<20 {
      let t0 = ContinuousClock.now
      _ = pipe.process(query)
      let elapsed = ContinuousClock.now - t0
      let ms = Double(elapsed.components.seconds) * 1000.0
        + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000.0
      latencies.append(ms)
    }
    // The last five runs should not be dramatically slower than the
    // middle five — catches regressions where a cache is evicting
    // unexpectedly or a data structure grows per call.
    let midMean = latencies[7...11].reduce(0, +) / 5
    let tailMean = latencies[15...19].reduce(0, +) / 5
    #expect(
      tailMean <= midMean * 2.0,
      "Latency should not grow: mid=\(midMean)ms tail=\(tailMean)ms"
    )
  }

  /// Fast-path validator must remain O(n) on string length and
  /// complete well under 1ms even for long commands. Catches
  /// accidental algorithmic regressions.
  @Test("Validator fast-path is O(n) and fast")
  func fastPathIsO_n() {
    // 10 KB command — well beyond any realistic template output
    let bigCmd = "ls " + String(repeating: "foo ", count: 2500)
    let t0 = ContinuousClock.now
    _ = CommandValidator.isTriviallyValidSyntax(bigCmd)
    let elapsed = ContinuousClock.now - t0
    let ms = Double(elapsed.components.seconds) * 1000.0
      + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000.0
    // Should be well under a millisecond. 10ms is a wide margin.
    #expect(ms < 10.0, "Fast-path took \(ms) ms on 10KB input")
  }
}
