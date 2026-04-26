// DiscoveryProvider.swift — Protocol for runtime template synthesis sources.
//
// Discovery sources fill the long tail beyond hand-written templates. The
// macOS/Linux ShellTalkDiscovery target implements this protocol; WASI/WASM
// builds run with `discoveryProvider == nil` and fall back to the
// pre-discovery behavior (return nil when no template matches).
//
// V1.5 ships ONE source — TldrSource — backed by an embedded tldr-pages
// corpus (CC-BY-4.0). V1.6+ will add HelpProberSource for `tool --help`
// parsing.

import Foundation

/// Where a CommandTemplate / synthesized command came from. Used by the CLI
/// to tag output ("~" prefix vs ">"), gate auto-execution, and surface
/// provenance in --debug.
public enum TemplateSource: String, Sendable, Codable {
  case builtIn       // Hand-written in BuiltInTemplates.swift
  case userPattern   // ~/.shelltalk/patterns/ (V1.5b)
  case tldr          // Synthesized from embedded tldr-pages corpus
  case help          // Synthesized from `tool --help` parse (V1.6+)
  case man           // Synthesized from man page parse (V2+)
}

/// Result of a successful synthesis from a discovery source.
public struct SynthesizedTemplate: Sendable {
  public let template: CommandTemplate
  public let source: TemplateSource
  /// Stable, human-readable origin reference. For tldr: the page path +
  /// upstream commit, e.g. "tldr/common/git-stash.md@209d423b020213".
  public let provenance: String
  /// Confidence floor for this source. Pipeline caps confidence at this
  /// value regardless of BM25 score, so synthesized commands never claim
  /// higher confidence than a hand-written template.
  public let confidenceCap: Double

  public init(
    template: CommandTemplate,
    source: TemplateSource,
    provenance: String,
    confidenceCap: Double
  ) {
    self.template = template
    self.source = source
    self.provenance = provenance
    self.confidenceCap = confidenceCap
  }
}

/// Runtime synthesis source. Implementations:
///   - TldrSource (Sources/ShellTalkDiscovery/TldrSource.swift)
///   - UserPatternSource (V1.5b)
///   - HelpProberSource (V1.6+)
public protocol DiscoveryProvider: Sendable {
  /// Synthesize a template for `query` using whatever sources this
  /// provider has access to. Returns nil when no source has a confident
  /// match — the pipeline then returns nil to the caller (the post-A1
  /// "no confident match" path).
  func synthesize(query: String, profile: SystemProfile) -> SynthesizedTemplate?

  /// Diagnostic name for --debug output, e.g. "tldr@209d423b" or
  /// "tldr+user-pattern@v1.5.0".
  var diagnosticName: String { get }
}
