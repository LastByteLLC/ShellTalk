// PlatformParityTests.swift — ungated cross-platform parity gate.
//
// These tests lock down a small set of gold-standard queries whose
// routing MUST be identical on every platform ShellTalk supports.
// Both macOS (with NLEmbedding rerank) and Linux / WASI (without it)
// have to return the same template for these queries. If macOS rerank
// is silently compensating for a wrong phrase-index mapping or template
// intent, the Linux / WASI build will fail these tests and surface the
// latent bug before it lands.
//
// Concrete motivation: the `"version of" → command_help` conceptPhrase
// bug lived for months because macOS rerank was quietly overriding the
// wrong mapping with command_version. The bug only surfaced when an
// unrelated Linux change raised the phrase-override threshold, exposing
// the latent mapping. A parity test like this one running on both
// platforms would have caught it pre-merge.

import Testing
@testable import ShellTalkKit

// `.serialized` avoids a known Swift Testing flake on macOS runners
// where a parameterized suite sharing static state (here, a single
// STMPipeline instance) can SIGSEGV the parallel test helper. The
// crash reproduces with the "Class _TtC7Testing10Serializer is
// implemented in both ..." objc warning — Xcode 26 ships its own
// Testing framework and the Swift 6.3 toolchain ships another, and
// the parallel runner occasionally dispatches through the wrong one.
// Running this small suite serially is harmless (< 50 ms total) and
// dodges the framework collision entirely.
@Suite("PlatformParity", .serialized)
struct PlatformParityTests {

  /// Gold-standard query → template mappings that must hold on every
  /// platform. Keep this list SMALL (< 20 cases) — it's a safety net,
  /// not an accuracy benchmark. The LinuxBaseline suite and STMAccuracy
  /// cover the broader eval corpus.
  ///
  /// An expected template of `_nil_` means "this query MUST be rejected"
  /// (returns nil or very-low-confidence). Use for gibberish and queries
  /// that exist to prove the matcher isn't overconfident.
  private static let goldQueries: [(query: String, expected: String)] = [
    // Common developer queries — anyone's first tests
    ("git status", "git_status"),
    ("find swift files", "find_by_extension"),
    ("list files", "ls_files"),
    ("show disk usage", "du_disk_usage"),
    ("delete temp.txt", "rm_file"),
    // Version vs help routing — regression test for the "version of"
    // conceptPhrase semantic bug (command_help → command_version fix).
    ("what version of node do I have", "command_version"),
    // Negation — R1 overrides route these to find_by_name even without
    // embedding rerank.
    ("find everything except node_modules", "find_by_name"),
    ("find files not ending in .log", "find_by_name"),
    // Date-range — R2 overrides route "X between yesterday/today/weekday Y"
    // to the range-aware templates.
    ("commits between yesterday and today", "git_log_date_range"),
    // "Did you mean?" negatives — off-topic queries must be rejected,
    // not silently routed to a confident-looking wrong answer.
    ("what is the meaning of life", "_nil_"),
    ("tell me about kubernetes", "_nil_"),
  ]

  // Instance-level (not static) — Swift Testing creates a new struct
  // instance per test method invocation, so each parameterized case
  // gets a fresh pipeline. Avoids any shared-state races in parallel.
  // (Paired with `.serialized` above, this is belt-and-braces.)
  private let pipeline = STMPipeline()

  @Test("Gold queries route identically on all platforms",
        arguments: goldQueries)
  func goldRouting(tc: (query: String, expected: String)) {
    let result = pipeline.process(tc.query)
    if tc.expected == "_nil_" {
      let accepted = result == nil || (result?.confidence ?? 1) < 0.3
      #expect(
        accepted,
        """
        Gold negative query was matched confidently:
          query:    \(tc.query)
          got:      \(result?.templateId ?? "(nil)")
          conf:     \(String(format: "%.2f", result?.confidence ?? 0))
        """
      )
    } else {
      #expect(
        result?.templateId == tc.expected,
        """
        Gold query routed wrong:
          query:    \(tc.query)
          expected: \(tc.expected)
          got:      \(result?.templateId ?? "(nil)")
          conf:     \(String(format: "%.2f", result?.confidence ?? 0))
        """
      )
    }
  }
}
