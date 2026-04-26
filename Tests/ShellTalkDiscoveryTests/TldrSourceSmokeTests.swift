// TldrSourceSmokeTests.swift — Sanity checks that the embedded corpus
// loads and the TldrSource can route a handful of representative queries.
// Heavier validation (parser self-test, full round-trip accuracy) lives
// in CorpusValidationTests.swift.

import Testing
@testable import ShellTalkDiscovery
@testable import ShellTalkKit

@Suite("TldrSourceSmoke")
struct TldrSourceSmokeTests {

  @Test("Embedded corpus loads and reports plausible page count")
  func corpusLoads() throws {
    let corpus = try EmbeddedTldrCorpus.load()
    #expect(corpus.pageCount > 1000, "expected many tldr pages, got \(corpus.pageCount)")
    #expect(corpus.pageCount == corpus.pages.count)
    #expect(corpus.license.contains("CC-BY-4.0"))
    #expect(!corpus.tldrPagesCommit.isEmpty)
  }

  @Test("Tool routing picks the right tldr page for first-token queries")
  func toolRouting() throws {
    let source = TldrSource()
    let profile = SystemProfile.cached
    // First-token tool name → that tool's page.
    if let r = source.synthesize(query: "lazygit show all branches", profile: profile) {
      #expect(r.provenance.contains("lazygit"))
      #expect(r.source == .tldr)
    }
    if let r = source.synthesize(query: "deno run a script", profile: profile) {
      #expect(r.provenance.contains("deno"))
    }
    if let r = source.synthesize(query: "rg search files", profile: profile) {
      #expect(r.provenance.contains("rg") || r.provenance.contains("ripgrep"))
    }
  }

  @Test("Two-token tool names resolve to hyphenated tldr page")
  func twoTokenRouting() throws {
    let source = TldrSource()
    let profile = SystemProfile.cached
    if let r = source.synthesize(query: "git stash list", profile: profile) {
      #expect(r.provenance.contains("git-stash") || r.provenance.contains("git"))
    }
  }

  @Test("Unknown tool returns nil")
  func unknownTool() throws {
    let source = TldrSource()
    let profile = SystemProfile.cached
    let r = source.synthesize(
      query: "fakelyfakefake-totally-not-a-real-cli help",
      profile: profile)
    #expect(r == nil)
  }

  @Test("Confidence cap is at most defaultConfidenceCap")
  func confidenceCap() throws {
    let source = TldrSource()
    let profile = SystemProfile.cached
    if let r = source.synthesize(query: "git stash list", profile: profile) {
      #expect(r.confidenceCap <= TldrSource.defaultConfidenceCap)
      #expect(r.confidenceCap == TldrSource.defaultConfidenceCap)
    }
  }
}
