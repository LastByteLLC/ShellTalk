// TldrSource.swift — V1.5 discovery source backed by tldr-pages.
//
// Routing: the user's query is tokenized; we search the full corpus by
// (a) matching the first query token to a tldr page name when possible
// (e.g., "lazygit show all branches" → page "lazygit"), then (b) ranking
// that page's examples by description similarity to the rest of the
// query. If no tool token matches, we fall back to a global BM25 over
// all (page-name + description) text.
//
// The synthesized command is the tldr example with `{{placeholder}}`
// tokens preserved literally; the user fills them in. This is honest:
// we don't fabricate file paths, the user sees exactly what's missing.

import Foundation
import ShellTalkKit

public final class TldrSource: DiscoveryProvider {

  public let diagnosticName: String

  /// Confidence cap for tldr-derived synthesis. Pipeline enforces this
  /// downstream (the CLI's auto-exec gate refuses < 0.85). Lower than
  /// hand-written templates (1.0) and user patterns (0.9), higher than
  /// `--help`-derived (0.5).
  public static let defaultConfidenceCap: Double = 0.7

  public init() {
    self.diagnosticName = "tldr@embedded"
  }

  /// Lazy-loaded corpus. Loading + decompression happens on first
  /// synthesize() call; subsequent calls are O(log n) lookup + BM25.
  /// EmbeddedTldrCorpus.load() handles its own caching + locking.
  private func corpus() -> TldrCorpus? {
    return try? EmbeddedTldrCorpus.load()
  }

  public func synthesize(query: String, profile: SystemProfile) -> SynthesizedTemplate? {
    guard let corpus = corpus() else { return nil }

    let queryTokens = tokenize(query)
    guard !queryTokens.isEmpty else { return nil }

    // Phase 1: tool routing. Try the first 1–2 query tokens as a page
    // name. tldr-pages stores names in three relevant forms:
    //   "lazygit"          → simple lowercase
    //   "VBoxManage"       → preserved binary casing
    //   "git stash"        → multi-word with SPACE (not hyphen)
    // We tokenize the query lowercase, try each candidate against the
    // page name's lowercase form. Examples:
    //   "lazygit show all branches" → page "lazygit"
    //   "git stash list"            → page "git stash"
    //   "vboxmanage list vms"       → page "VBoxManage" (lc match)
    let firstOne = queryTokens.first ?? ""
    let firstTwoSpace = queryTokens.prefix(2).joined(separator: " ")
    let firstTwoHyphen = queryTokens.prefix(2).joined(separator: "-")
    let firstThreeSpace = queryTokens.prefix(3).joined(separator: " ")
    let candidates = [firstThreeSpace, firstTwoSpace, firstTwoHyphen, firstOne]

    var page: TldrPage?
    for cand in candidates {
      if let p = corpus.pages.first(where: { $0.name.lowercased() == cand }) {
        page = p
        break
      }
    }

    guard let chosenPage = page, !chosenPage.examples.isEmpty else {
      // No direct page hit. Returning nil here means discovery hands
      // control back to the pipeline; the pipeline returns its
      // "no confident match" outcome rather than guessing globally.
      // (V1.6 may add cross-page semantic search.)
      return nil
    }

    // Phase 2: rank page's examples by description+command similarity to
    // query. Three signals combined, in increasing order of importance:
    //
    //   (a) Per-page IDF-weighted description-token overlap. Tokens that
    //       appear in MANY examples on this page (e.g., "files", "list")
    //       contribute less than tokens that appear in ONE example
    //       (e.g., "concatenate", "reproducible"). This is the within-
    //       page TF-IDF dual to the global BM25 pipeline.
    //   (b) Command-token overlap. If the query contains a token from
    //       the example's COMMAND (a flag, subcommand, or literal),
    //       that's stronger evidence than description-only match.
    //   (c) Stable last-wins tiebreak. tldr-pages typically orders
    //       examples by frequency-of-use; ties tend to mean genuine
    //       ambiguity, and the LATER example often shows a more
    //       specific operation. Preferring later breaks the systematic
    //       bias toward examples[0] under plain `max(by:)`.
    let pageNameTokens = Set(tokenize(chosenPage.name))
    let restTokens = Set(queryTokens).subtracting(pageNameTokens)

    // Per-page IDF: how many examples on this page contain each token?
    // log((N+1)/(df+1)) is a smoothed IDF that stays positive for df==N.
    var docFreq: [String: Int] = [:]
    for ex in chosenPage.examples {
      for tok in Set(tokenize(ex.description)) {
        docFreq[tok, default: 0] += 1
      }
    }
    let nExamples = Double(chosenPage.examples.count)
    func idf(_ token: String) -> Double {
      let df = Double(docFreq[token] ?? 0)
      return log((nExamples + 1.0) / (df + 1.0))
    }

    let scored = chosenPage.examples.enumerated().map { (idx, ex) -> (Int, TldrExample, Double) in
      let descTokens = Set(tokenize(ex.description))
      let cmdTokens = Set(tokenize(ex.command))
      // (a) IDF-weighted description-token overlap.
      let descScore = restTokens.intersection(descTokens)
        .map { idf($0) }
        .reduce(0.0, +)
      // (b) Command-token overlap. Each shared token gets a constant
      //     bonus of 0.5 — strong signal but not so strong it dominates
      //     a clear description match.
      let cmdScore = Double(restTokens.intersection(cmdTokens).count) * 0.5
      // (c) Slight position prior: later examples preferred at ties
      //     (epsilon scaled to per-page index).
      let posPrior = Double(idx) * 1e-6
      return (idx, ex, descScore + cmdScore + posPrior)
    }
    let best = scored.max(by: { $0.2 < $1.2 })
    let chosen: TldrExample
    if let (_, b, score) = best, score > 0 {
      chosen = b
    } else {
      // No description- or command-token signal at all. Return the FIRST
      // example as a sensible default — the user at least sees a canonical
      // invocation of the tool — and the CLI's confidence cap + tilde
      // prefix signal it's a guess.
      chosen = chosenPage.examples[0]
    }

    // Build a SynthesizedTemplate. The command keeps `{{placeholder}}`
    // tokens literally; the CLI will display these so the user knows
    // what to fill in. Confidence cap is fixed by source.
    let templateId = "tldr_synth/\(chosenPage.name)/\(chosen.description.prefix(40))"
    let template = CommandTemplate(
      id: templateId,
      intents: [chosen.description],
      command: chosen.command,
      slots: [:]
    )
    let provenance = "tldr/\(chosenPage.name).md@\(corpus.tldrPagesCommit.prefix(8))"
    return SynthesizedTemplate(
      template: template,
      source: .tldr,
      provenance: provenance,
      confidenceCap: Self.defaultConfidenceCap
    )
  }

  /// Lowercase, strip punctuation, split on whitespace.
  ///
  /// We tried Porter-style suffix stemming (-ing/-ed/-s) and measured it
  /// regressed both metrics: within-page 0.94→0.90, roundtrip 0.99→0.91.
  /// English subword matching needs proper morphology (running→run, not
  /// "runn"); naive truncation broke more matches than it created. The
  /// path to better than 0.94 is per-page TF-IDF + command-token boost
  /// (already in place) plus a real stemmer or NLTagger lemma — deferred.
  private func tokenize(_ text: String) -> [String] {
    return text
      .lowercased()
      .replacingOccurrences(of: "[^a-z0-9 \\-_.]", with: " ", options: .regularExpression)
      .split(separator: " ", omittingEmptySubsequences: true)
      .map(String.init)
  }
}

/// Convenience constructor used by the CLI / pipeline. Returns the default
/// V1.5 provider stack: TldrSource only.
public func makeDefaultDiscoveryProvider() -> DiscoveryProvider {
  return TldrSource()
}
