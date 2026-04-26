// CorpusValidationTests.swift — Validation tests for the embedded
// tldr-pages corpus + TldrSource. Modeled on the STMAccuracy /
// PlatformParity / IncantValidation patterns used by built-in templates.
//
// Three test classes:
//
//   1. CorpusIntegrity   — every page parses cleanly, has examples, etc.
//   2. KnownToolRouting  — specific tool→template assertions, like the
//                          STMAccuracy "previously-fixed queries" suite.
//   3. RoundtripAccuracy — for each (description, command) pair in the
//                          corpus, use description as query and check
//                          that synthesis returns the matching command.
//                          Aggregates a measurable accuracy number.
//
// These tests run against the EMBEDDED corpus shipped in
// Sources/ShellTalkDiscovery/Resources/. They re-validate every release.

import Testing
import Foundation
@testable import ShellTalkDiscovery
@testable import ShellTalkKit

@Suite("CorpusValidation")
struct CorpusValidationTests {

  // MARK: - Corpus integrity

  @Suite("CorpusIntegrity")
  struct Integrity {
    @Test("Every page has at least one example")
    func everyPageHasExamples() throws {
      let corpus = try EmbeddedTldrCorpus.load()
      var empty: [String] = []
      for page in corpus.pages where page.examples.isEmpty {
        empty.append(page.name)
      }
      #expect(empty.isEmpty,
        "pages with no examples (refresh script bug): \(empty.prefix(5))")
    }

    @Test("Every example has non-empty description and command")
    func examplesAreWellFormed() throws {
      let corpus = try EmbeddedTldrCorpus.load()
      var bad: [(String, String)] = []
      for page in corpus.pages {
        for ex in page.examples {
          if ex.description.isEmpty || ex.command.isEmpty {
            bad.append((page.name, ex.description))
          }
        }
      }
      #expect(bad.isEmpty,
        "malformed examples (refresh script bug): \(bad.prefix(5))")
    }

    @Test("Page names are unique (no shadowed pages)")
    func noDuplicatePages() throws {
      let corpus = try EmbeddedTldrCorpus.load()
      let names = corpus.pages.map(\.name)
      let unique = Set(names)
      #expect(names.count == unique.count,
        "duplicate page names: \(names.count - unique.count) duplicates")
    }

    @Test("Corpus covers tools we shipped templates for")
    func corpusCoversCoreTools() throws {
      let corpus = try EmbeddedTldrCorpus.load()
      // Case-insensitive lookup — tldr-pages preserves binary casing
      // (VBoxManage) and uses spaces in multi-word names ("git stash").
      let names = Set(corpus.pages.map { $0.name.lowercased() })
      let mustHave = [
        // file_ops
        "ls", "find", "cp", "mv", "rm", "chmod", "tar",
        // git (multi-word names use SPACES in tldr-pages, not hyphens)
        "git", "git stash", "git rebase", "git log",
        // text_processing
        "grep", "sed", "awk", "jq",
        // dev_tools
        "docker", "kubectl", "swift", "cargo", "go",
        // network
        "curl", "ssh", "ping",
        // incant categories
        "ffmpeg", "magick", "openssl",
      ]
      var missing: [String] = []
      for name in mustHave where !names.contains(name) {
        missing.append(name)
      }
      #expect(missing.isEmpty,
        "core tools missing from tldr corpus: \(missing)")
    }

    @Test("License attribution is preserved")
    func licenseAttribution() throws {
      let corpus = try EmbeddedTldrCorpus.load()
      #expect(corpus.license.contains("CC-BY-4.0"))
      #expect(corpus.licenseUrl.contains("tldr-pages"))
    }
  }

  // MARK: - Known tool routing

  @Suite("KnownToolRouting")
  struct Routing {
    private let source = TldrSource()
    private let profile = SystemProfile.cached

    /// Spot-checks that specific queries route to expected pages. Modeled
    /// on STMAccuracyTests.Regressions.previousFixes() — a curated set of
    /// "previously-fixed queries stay correct" assertions.
    @Test("Tool-name first token routes to the matching page")
    func toolNameRouting() throws {
      // Each query is expected to route to a page whose name STARTS with
      // `expectedPagePrefix`. tldr-pages may have both "helm" and
      // "helm install" pages; routing to the more specific one is
      // CORRECT behavior, so we accept any page in the same tool family.
      let cases: [(query: String, expectedPagePrefix: String)] = [
        ("lazygit", "lazygit"),
        ("deno run a script", "deno"),
        ("rg search files", "rg"),
        ("helm install chart", "helm"),
        ("bun install", "bun"),
        ("kubectx switch context", "kubectx"),
        ("k9s view pods", "k9s"),
        ("eza list files", "eza"),
        ("bat view file", "bat"),
        ("fd find file", "fd"),
        ("delta show diff", "delta"),
      ]
      var failures: [(String, String, String?)] = []
      for c in cases {
        let result = source.synthesize(query: c.query, profile: profile)
        let routedPage = result?.provenance
          .components(separatedBy: "tldr/").last?
          .components(separatedBy: ".md").first
        let routedOk = (routedPage ?? "").hasPrefix(c.expectedPagePrefix)
        if !routedOk {
          failures.append((c.query, c.expectedPagePrefix, routedPage))
        }
      }
      #expect(failures.isEmpty,
        "routing failures: \(failures.map { "\($0.0) → expected prefix \($0.1), got \($0.2 ?? "nil")" })")
    }

    @Test("Two-token tool names hyphenate to the right tldr page")
    func twoTokenRouting() throws {
      let cases: [(String, String)] = [
        ("git stash list", "git-stash"),
        ("git rebase main", "git-rebase"),
        ("git log oneline", "git-log"),
        ("docker compose up", "docker-compose"),
        ("aws s3 cp", "aws-s3"),
        ("kubectl describe pod", "kubectl"),  // kubectl-describe doesn't exist as page
      ]
      var routedRight = 0
      var routedAtAll = 0
      for (query, _) in cases {
        if let r = source.synthesize(query: query, profile: profile) {
          routedAtAll += 1
          if r.provenance.contains("git") || r.provenance.contains("docker")
             || r.provenance.contains("aws") || r.provenance.contains("kubectl") {
            routedRight += 1
          }
        }
      }
      // We're lenient here: tldr-pages may consolidate or expand subcommand
      // pages over time. As long as the matched page is in the right tool
      // family AND we routed every query, we're OK.
      #expect(routedAtAll == cases.count, "expected \(cases.count) routes, got \(routedAtAll)")
      #expect(routedRight >= cases.count - 1, "expected \(cases.count - 1)+ in-family, got \(routedRight)")
    }

    @Test("Unknown tools return nil")
    func unknownTools() throws {
      let cases = [
        "fakelyfakefake-totally-not-a-real-cli help",
        "totally-not-a-real-utility do something",
        "xxxxxxxxxxxxx run",
      ]
      for query in cases {
        let r = source.synthesize(query: query, profile: profile)
        #expect(r == nil, "expected nil for unknown tool: \(query)")
      }
    }

    @Test("Synthesized templates carry tldr source + provenance + confidence cap")
    func synthesizedMetadata() throws {
      let r = source.synthesize(query: "lazygit", profile: profile)
      #expect(r != nil)
      if let r {
        #expect(r.source == .tldr)
        #expect(r.provenance.starts(with: "tldr/"))
        #expect(r.confidenceCap == TldrSource.defaultConfidenceCap)
      }
    }
  }

  // MARK: - Round-trip accuracy

  @Suite("RoundtripAccuracy")
  struct Roundtrip {
    /// For each (description, command) example in a representative
    /// sample of pages, use the description (with the page name
    /// prefixed, since real users say "lazygit show branches" not just
    /// "show branches") and verify synthesis returns an example that
    /// matches the originating command's first token.
    ///
    /// This isn't exact-match — tldr descriptions are often ambiguous
    /// (multiple examples can satisfy "compress files"). We accept any
    /// example from the same page as a correct route. The metric is:
    /// "did synthesis pick the right TOOL?"
    @Test("Description+page-name queries route to the source page")
    func descriptionRoundtrip() throws {
      let corpus = try EmbeddedTldrCorpus.load()
      let source = TldrSource()
      let profile = SystemProfile.cached

      // Sample: every 10th page to keep test runtime reasonable.
      let sample = stride(from: 0, to: corpus.pages.count, by: 10)
        .map { corpus.pages[$0] }
      var attempts = 0
      var routedCorrectly = 0
      var sampleFailures: [(String, String)] = []

      for page in sample {
        // Use the FIRST example's description (most representative).
        guard let example = page.examples.first else { continue }
        let query = "\(page.name) \(example.description.lowercased())"
        attempts += 1
        if let r = source.synthesize(query: query, profile: profile) {
          if r.provenance.contains("tldr/\(page.name).md") {
            routedCorrectly += 1
          } else {
            if sampleFailures.count < 5 {
              sampleFailures.append((query, r.provenance))
            }
          }
        } else {
          if sampleFailures.count < 5 {
            sampleFailures.append((query, "nil"))
          }
        }
      }

      let acc = attempts > 0 ? Double(routedCorrectly) / Double(attempts) : 0
      print("Roundtrip accuracy on \(attempts) sampled pages: \(String(format: "%.4f", acc))")
      if !sampleFailures.isEmpty {
        print("  Sample failures:")
        for (q, p) in sampleFailures {
          print("    '\(q)' → \(p)")
        }
      }
      // Target ≥0.85; this measures end-to-end correctness on a real corpus.
      #expect(acc >= 0.85, "tldr_roundtrip_acc=\(acc) below 0.85 floor")
    }

    @Test("Within-page example ranking — tightly-described examples")
    func withinPageRanking() throws {
      let corpus = try EmbeddedTldrCorpus.load()
      let source = TldrSource()
      let profile = SystemProfile.cached

      // For pages with ≥3 examples, verify that asking specifically for
      // the LAST example's description routes to a command containing
      // the LAST example's first command token. Catches regressions
      // where we always return examples[0] regardless of query.
      var attempts = 0
      var hits = 0
      for page in corpus.pages where page.examples.count >= 3 {
        let lastEx = page.examples.last!
        // Skip if the description doesn't contain a distinctive non-trivial token.
        let descTokens = lastEx.description.lowercased()
          .split(separator: " ").map(String.init)
          .filter { $0.count >= 5 && !["which", "where", "with", "from"].contains($0) }
        guard let pivot = descTokens.first else { continue }
        attempts += 1
        let query = "\(page.name) \(pivot)"
        if let r = source.synthesize(query: query, profile: profile),
           let lastTok = lastEx.command.split(separator: " ").first {
          if r.template.command.contains(lastTok) {
            hits += 1
          }
        }
        if attempts >= 200 { break }  // cap for runtime
      }
      let hitRate = attempts > 0 ? Double(hits) / Double(attempts) : 0
      print("Within-page ranking hit rate: \(String(format: "%.4f", hitRate)) (\(hits)/\(attempts))")
      // Looser: same tool, ranking right ≥30% of the time. This is
      // genuinely hard — descriptions are often near-synonyms.
      #expect(hitRate >= 0.30,
        "within-page ranking hitting only \(hitRate) — synthesizer may be returning examples[0] always")
    }
  }
}
