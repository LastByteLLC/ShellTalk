// STMPipeline.swift — End-to-end query → command pipeline
//
// Wires together: IntentMatcher → SlotExtractor → TemplateResolver → CommandValidator
// This is the main entry point for converting natural language to bash.

import Foundation

/// Configuration for the STM pipeline.
public struct PipelineConfig: Sendable {
  public let matcherConfig: MatcherConfig
  public let validateCommands: Bool
  public let includeDebugInfo: Bool

  public init(
    matcherConfig: MatcherConfig,
    validateCommands: Bool,
    includeDebugInfo: Bool
  ) {
    self.matcherConfig = matcherConfig
    self.validateCommands = validateCommands
    self.includeDebugInfo = includeDebugInfo
  }

  public static let `default` = PipelineConfig(
    matcherConfig: .default,
    validateCommands: true,
    includeDebugInfo: false
  )

  public static let debug = PipelineConfig(
    matcherConfig: .default,
    validateCommands: true,
    includeDebugInfo: true
  )
}

/// Result of the full STM pipeline.
public struct PipelineResult: Sendable {
  public let command: String
  public let categoryId: String
  public let templateId: String
  public let categoryScore: Double
  public let templateScore: Double
  public let extractedSlots: [String: String]
  public let validation: CommandValidation?
  public let debugInfo: DebugInfo?
  /// B6: Multi-operation hint. When non-nil the query was detected as a
  /// compound that ShellTalk's single-template architecture cannot
  /// faithfully express. The hint describes the unhandled tail (e.g.,
  /// "with a 4px border") so the CLI/UX can surface it to the user.
  public let multiOperationHint: String?
  /// V1.5: where this command came from. Built-in templates (the
  /// pre-discovery default) are `.builtIn`; tldr-derived synthesis is
  /// `.tldr`; user-saved patterns will be `.userPattern` (V1.5b);
  /// `--help`-derived will be `.help` (V1.6+). The CLI uses this to
  /// label confidence-bounded output ("~" prefix vs ">").
  public let source: TemplateSource
  /// V1.5: provenance string for synthesized commands (e.g.
  /// "tldr/git-stash.md@209d423b"). nil for built-in templates.
  public let provenance: String?

  public init(
    command: String,
    categoryId: String,
    templateId: String,
    categoryScore: Double,
    templateScore: Double,
    extractedSlots: [String: String],
    validation: CommandValidation?,
    debugInfo: DebugInfo?,
    multiOperationHint: String? = nil,
    source: TemplateSource = .builtIn,
    provenance: String? = nil
  ) {
    self.command = command
    self.categoryId = categoryId
    self.templateId = templateId
    self.categoryScore = categoryScore
    self.templateScore = templateScore
    self.extractedSlots = extractedSlots
    self.validation = validation
    self.debugInfo = debugInfo
    self.multiOperationHint = multiOperationHint
    self.source = source
    self.provenance = provenance
  }

  /// Whether the command is valid and safe to display/execute.
  public var isValid: Bool {
    validation?.isValid ?? true
  }

  /// Confidence score (0..1 range, higher is better).
  public var confidence: Double {
    min(categoryScore, templateScore)
  }
}

/// Timing for a single pipeline stage.
public struct StageTiming: Sendable {
  public let name: String
  public let elapsedMs: Double
}

/// Debug information for diagnosing match quality.
public struct DebugInfo: Sendable {
  public let entities: [RecognizedEntity]
  public let topMatches: [IntentMatchResult]
  public let allExtractedSlots: [String: String]
  public let resolvedPlatformSlots: [String: String]
  public let timings: [StageTiming]
  public let totalMs: Double
}

/// The main STM pipeline: query → command.
public final class STMPipeline: Sendable {
  private let matcher: IntentMatcher
  private let extractor: SlotExtractor
  private let recognizer: EntityRecognizer
  private let resolver: TemplateResolver
  private let validator: CommandValidator
  private let profile: SystemProfile
  private let config: PipelineConfig
  /// V1.5 discovery provider. Set by the executable target on macOS/Linux
  /// when SHELLTALK_DISCOVERY != "off"; nil otherwise (WASM, opt-out).
  /// When nil the pipeline behaves exactly as it did pre-V1.5.
  private let discoveryProvider: DiscoveryProvider?

  /// Time spent constructing the pipeline (system discovery, index building, etc.)
  public let initMs: Double

  public init(
    profile: SystemProfile? = nil,
    store: TemplateStore? = nil,
    config: PipelineConfig = .default,
    discoveryProvider: DiscoveryProvider? = nil
  ) {
    let initStart = PipelineTimer.now()
    let prof = profile ?? SystemProfile.cached
    var st = store ?? TemplateStore.builtIn()
    var cfg = config

    // Meta-Harness overlay hook: if SHELLTALK_OVERLAY_PATH is set, layer the
    // overlay onto the matcher config and template corpus. This lets the
    // curated test gate (STMAccuracyTests) validate candidates without
    // duplicating pipeline construction.
    #if canImport(Yams) && !os(WASI)
    if let overlayPath = ProcessInfo.processInfo.environment["SHELLTALK_OVERLAY_PATH"],
       let overlay = PipelineOverlay.load(path: overlayPath) {
      cfg = PipelineConfig(
        matcherConfig: overlay.apply(to: cfg.matcherConfig),
        validateCommands: cfg.validateCommands,
        includeDebugInfo: cfg.includeDebugInfo
      )
      st = TemplateStore(categories: overlay.apply(to: st.categories))
    }
    #endif

    self.profile = prof
    self.config = cfg
    self.matcher = IntentMatcher(store: st, config: cfg.matcherConfig, profile: prof)
    // V1.5: Discovery provider is opt-in. Caller (the executable target)
    // passes a provider on macOS/Linux when SHELLTALK_DISCOVERY != "off";
    // here we just store whatever was passed.
    let discoveryDisabled = ProcessInfo.processInfo.environment["SHELLTALK_DISCOVERY"] == "off"
    self.discoveryProvider = discoveryDisabled ? nil : discoveryProvider
    self.extractor = SlotExtractor()
    self.recognizer = EntityRecognizer(profile: prof)
    self.resolver = TemplateResolver(profile: prof)
    self.validator = CommandValidator(profile: prof)
    self.initMs = initStart.elapsedMs()
  }

  /// Convert a natural language query to a bash command.
  /// Returns nil if no template matches with sufficient confidence.
  public func process(_ query: String) -> PipelineResult? {
    let pipelineStart = PipelineTimer.now()
    var timings: [StageTiming] = []

    // Conversational filter: queries that are clearly meta-questions or
    // tutorial requests have no shell-command answer and should return
    // nil rather than match-anything. Improves Unknown-suite accuracy
    // and prevents wrong commands from running on chat-style input.
    if Self.isConversational(query) {
      return nil
    }

    // Step 0: Recognize entities
    var t0 = PipelineTimer.now()
    let entities = recognizer.recognize(query)
    timings.append(StageTiming(name: "entities", elapsedMs: t0.elapsedMs()))

    // Step 1: Match intent (entity-aware)
    t0 = PipelineTimer.now()
    guard let match = matcher.match(query, entities: entities) else {
      // V1.5: when standard matching fails, fall back to runtime discovery
      // (tldr-pages corpus, with `--help` parsing arriving in V1.6).
      // Discovery is gated by `discoveryProvider` being non-nil, which
      // happens only when the host platform supports it (macOS/Linux)
      // and SHELLTALK_DISCOVERY != "off".
      return discoveryFallback(
        query: query, entities: entities, timings: &timings,
        pipelineStart: pipelineStart)
    }
    timings.append(StageTiming(name: "match", elapsedMs: t0.elapsedMs()))

    // Step 2: Extract slots (entity-aware) + post-process
    t0 = PipelineTimer.now()
    var slots = extractor.extract(
      from: query,
      slots: match.template.slots,
      entities: entities,
      profile: profile
    )
    // Post-process: remove slot values that are just the command's own tokens
    let cmdTokens = Set(
      TemplateStore.extractCommandPrefix(match.template.command)
        .lowercased().split(separator: " ").map(String.init)
    )
    for (name, value) in slots {
      let lower = value.lowercased()
      if cmdTokens.contains(lower) {
        if let def = match.template.slots[name]?.defaultValue {
          slots[name] = def
        } else {
          slots.removeValue(forKey: name)
        }
      }
    }

    // Post-process: normalize human words to flag values
    for (name, value) in slots {
      if let normalized = Self.valueNormalization[value.lowercased()] {
        slots[name] = normalized
      }
    }
    timings.append(StageTiming(name: "extract", elapsedMs: t0.elapsedMs()))

    // Step 3: Resolve template
    t0 = PipelineTimer.now()
    let command = resolver.resolve(template: match.template, extractedSlots: slots)
    timings.append(StageTiming(name: "resolve", elapsedMs: t0.elapsedMs()))

    // Step 3.5: Unfilled-placeholder guard. After resolve, any remaining
    // `{UPPERCASE_SLOT}` token is a slot the user didn't supply and the
    // template didn't default. For incant-era templates (media, crypto,
    // and tar_*/curl_* additions) we'd rather return nil than emit a
    // command containing literal `{INPUT}` — those queries genuinely
    // need a user-supplied path to be runnable.
    //
    // Fallback: when the top match fails the guard, try the next-best
    // candidates in order. This handles cases where the BM25 winner has
    // unfilled slots but the runner-up resolves cleanly.
    //
    // For pre-existing templates the behavior is unchanged: a vague
    // query like "duplicate the config file" routes to cp_file with
    // unfilled SOURCE/DEST and ships as guidance.
    var workingMatch = match
    var workingCommand = command
    var workingSlots = slots
    if Self.shouldEnforcePlaceholderGuard(template: workingMatch.template, categoryId: workingMatch.categoryId)
       && Self.hasUnresolvedRequiredSlots(in: workingCommand) {
      // Walk top-N alternatives looking for one that resolves cleanly.
      let alternatives = matcher.matchTopN(query, n: 5).dropFirst()
      var found: (IntentMatchResult, [String: String], String)?
      for alt in alternatives {
        let altSlots = extractor.extract(
          from: query, slots: alt.template.slots,
          entities: entities, profile: profile)
        let altCmd = resolver.resolve(template: alt.template, extractedSlots: altSlots)
        if Self.shouldEnforcePlaceholderGuard(template: alt.template, categoryId: alt.categoryId) {
          if Self.hasUnresolvedRequiredSlots(in: altCmd) { continue }
        }
        found = (alt, altSlots, altCmd)
        break
      }
      guard let f = found else { return nil }
      workingMatch = f.0
      workingSlots = f.1
      workingCommand = f.2
    }

    // Step 4: Validate (optional)
    t0 = PipelineTimer.now()
    let validation = config.validateCommands ? validator.validate(workingCommand) : nil
    timings.append(StageTiming(name: "validate", elapsedMs: t0.elapsedMs()))

    // Step 5: Debug info (optional)
    let debug: DebugInfo?
    if config.includeDebugInfo {
      t0 = PipelineTimer.now()
      let topMatches = matcher.matchTopN(query, n: 5)
      let platformSlots = resolvePlatformSlotsUsed(in: match.template.command)
      timings.append(StageTiming(name: "debug", elapsedMs: t0.elapsedMs()))

      debug = DebugInfo(
        entities: entities,
        topMatches: topMatches,
        allExtractedSlots: slots,
        resolvedPlatformSlots: platformSlots,
        timings: timings,
        totalMs: pipelineStart.elapsedMs()
      )
    } else {
      debug = nil
    }

    // B6: Detect compound queries that the single-template result can't
    // fully express. We don't change the resolved command (the user gets
    // the dominant operation) but emit a `multiOperationHint` describing
    // the tail clause so the CLI can flag it.
    let multiOpHint = Self.detectMultiOperationTail(query: query, primaryTemplateId: workingMatch.templateId)

    return PipelineResult(
      command: workingCommand,
      categoryId: workingMatch.categoryId,
      templateId: workingMatch.templateId,
      categoryScore: workingMatch.categoryScore,
      templateScore: workingMatch.templateScore,
      extractedSlots: workingSlots,
      validation: validation,
      debugInfo: debug,
      multiOperationHint: multiOpHint
    )
  }

  /// V1.5: Last-resort fallback when neither standard matching nor the
  /// top-N alternatives yielded a viable result. Asks the discovery
  /// provider (tldr-pages corpus in V1.5) to synthesize a template.
  /// Synthesized commands flow through the same resolve + validate
  /// path and carry a `source: .tldr` provenance tag for the CLI to
  /// label confidence-bounded output.
  private func discoveryFallback(
    query: String,
    entities: [RecognizedEntity],
    timings: inout [StageTiming],
    pipelineStart: PipelineTimer
  ) -> PipelineResult? {
    guard let provider = discoveryProvider else { return nil }
    var t0 = PipelineTimer.now()
    guard let synth = provider.synthesize(query: query, profile: profile) else {
      timings.append(StageTiming(name: "discovery", elapsedMs: t0.elapsedMs()))
      return nil
    }
    timings.append(StageTiming(name: "discovery", elapsedMs: t0.elapsedMs()))

    // Resolve the synthesized template. Slot extraction runs against
    // the synthesized template's slot definitions (currently empty —
    // tldr commands embed `{{placeholder}}` literals the user fills in).
    t0 = PipelineTimer.now()
    let slots = extractor.extract(
      from: query,
      slots: synth.template.slots,
      entities: entities,
      profile: profile)
    let command = resolver.resolve(template: synth.template, extractedSlots: slots)
    timings.append(StageTiming(name: "resolve", elapsedMs: t0.elapsedMs()))

    // Validate. Synthesized commands get the same syntax / safety /
    // domain (B7) checks as built-ins. The validator is source-agnostic.
    t0 = PipelineTimer.now()
    let validation = config.validateCommands ? validator.validate(command) : nil
    timings.append(StageTiming(name: "validate", elapsedMs: t0.elapsedMs()))

    // Confidence: capped by the source's defaultConfidenceCap (0.7 for
    // tldr). The CLI's auto-exec gate refuses anything below 0.85.
    let conf = synth.confidenceCap
    return PipelineResult(
      command: command,
      categoryId: "discovery",
      templateId: synth.template.id,
      categoryScore: conf,
      templateScore: conf,
      extractedSlots: slots,
      validation: validation,
      debugInfo: nil,
      multiOperationHint: nil,
      source: synth.source,
      provenance: synth.provenance
    )
  }

  /// "Did you mean?" suggestions for a query that `process(_:)` couldn't
  /// confidently resolve. Returns the top-K candidates the matcher considered,
  /// ranked by BM25/TF-IDF score, WITHOUT the confidence threshold gate that
  /// `process(_:)` applies. Useful for CLI / UI fallback:
  ///
  ///   if let result = pipe.process(query) {
  ///     // show confident answer
  ///   } else {
  ///     for s in pipe.suggestions(for: query) {
  ///       print("Did you mean: \(s.command)")
  ///     }
  ///   }
  ///
  /// Identical to `processWithAlternatives(_:n:)`; this alias exists because
  /// callers reach for it precisely when `process(_:)` returned nil.
  public func suggestions(for query: String, limit: Int = 3) -> [PipelineResult] {
    processWithAlternatives(query, n: limit)
  }

  /// Process a query and return top-N alternatives.
  public func processWithAlternatives(_ query: String, n: Int = 3) -> [PipelineResult] {
    let entities = recognizer.recognize(query)
    let topMatches = matcher.matchTopN(query, n: n)

    return topMatches.compactMap { match in
      let slots = extractor.extract(
        from: query,
        slots: match.template.slots,
        entities: entities,
        profile: profile
      )
      let command = resolver.resolve(template: match.template, extractedSlots: slots)
      let validation = config.validateCommands ? validator.validate(command) : nil

      return PipelineResult(
        command: command,
        categoryId: match.categoryId,
        templateId: match.templateId,
        categoryScore: match.categoryScore,
        templateScore: match.templateScore,
        extractedSlots: slots,
        validation: validation,
        debugInfo: nil
      )
    }
  }

  // MARK: - Helpers

  /// Human-word → flag-value normalization for post-processing extracted slots.
  /// Hoisted out of `process()` so it's not reallocated per query.
  private static let valueNormalization: [String: String] = [
    "lines": "l", "line": "l",
    "words": "w", "word": "w",
    "characters": "c", "chars": "c", "char": "c",
    "bytes": "c",
    "code": "l",
  ]

  private func resolvePlatformSlotsUsed(in command: String) -> [String: String] {
    let platformSlots = PlatformSlots(profile: profile)
    var resolved: [String: String] = [:]

    let regex = TemplateResolver.platformSlotRegex
    let matches = regex.matches(in: command, range: NSRange(command.startIndex..., in: command))
    for match in matches {
      if let range = Range(match.range(at: 1), in: command) {
        let name = String(command[range])
        if let value = platformSlots.resolve(name) {
          resolved[name] = value
        }
      }
    }

    return resolved
  }

  /// Whether to apply the strict unfilled-placeholder guard for this match.
  /// Scoped to "incant-era" template clusters (media, crypto, plus the
  /// tar_*/curl_* additions in compression/network) where unfilled inputs
  /// produce strictly-broken commands. Pre-existing templates retain their
  /// "emit-as-guidance" behavior so existing eval cases stay green.
  static func shouldEnforcePlaceholderGuard(template: CommandTemplate, categoryId: String) -> Bool {
    if categoryId == "media" || categoryId == "crypto" { return true }
    let id = template.id
    if id.hasPrefix("tar_create_")
       || id.hasPrefix("tar_extract_")
       || id == "tar_list_verbose"
       || id == "tar_append"
       || id == "tar_exclude"
       || id == "tar_compare"
       || id == "tar_preserve_perms"
       || id == "tar_dereference" {
      return true
    }
    if id.hasPrefix("curl_") && id != "curl_get" && id != "curl_post_json"
       && id != "curl_download" && id != "curl_headers" && id != "curl_auth" {
      return true
    }
    return false
  }

  /// Unfilled-required-slot detector. After resolver runs (which fills user
  /// slots, then platform slots, then per-slot defaults), any remaining
  /// `{UPPERCASE_SLOT}` token is a required slot the user didn't supply and
  /// the template didn't default. Shipping such a command is always wrong.
  ///
  /// Excludes the `${VAR}` pattern (shell variable expansion), which is
  /// legitimate output (e.g., `echo ${HOME}`).
  static func hasUnresolvedRequiredSlots(in command: String) -> Bool {
    // Match {NAME} but not ${NAME} (shell var). Use negative lookbehind:
    // RE: a `{` that is not preceded by `$`, followed by [A-Z][A-Z0-9_]+ and `}`.
    let regex = TemplateResolver.platformSlotRegex
    let matches = regex.matches(in: command, range: NSRange(command.startIndex..., in: command))
    for match in matches {
      // Check that the `{` was not preceded by `$`. NSRegularExpression doesn't
      // support negative lookbehind on older targets, so check here.
      let braceRange = match.range
      let braceStart = braceRange.location
      if braceStart > 0 {
        let prevIndex = command.index(command.startIndex, offsetBy: braceStart - 1)
        if command[prevIndex] == "$" { continue }
      }
      return true
    }
    return false
  }

  /// B6: Detect compound-operation tails that the single-template result
  /// can't fully express. Looks for connector phrases (`with a`, `and`,
  /// `then`, `plus`) introducing a clause that names another operation
  /// the dominant template doesn't cover.
  ///
  /// Returns a short hint string like "with a 4px border" when the tail
  /// is detected, or nil for single-op queries.
  ///
  /// Conservative by design: well-known multi-input templates
  /// (concat A and B, mix audio A and B) are exempt because their
  /// command syntax natively takes both clauses.
  static func detectMultiOperationTail(query: String, primaryTemplateId: String) -> String? {
    let lower = query.lowercased()
    let secondOpKeywords = [
      "border", "watermark", "subtitle", "fade", "blur", "sharpen",
      "crop", "rotate", "resize", "scale", "compress", "encode",
      "thumbnail", "encrypt", "sign", "verify another",
    ]

    // Templates whose syntax natively consumes "X and Y" — for these,
    // a single " and " connector is *not* a compound signal. Only flag
    // when there are 2+ ANDs OR a non-`and` connector is present.
    let nativeAndConsuming: Set<String> = [
      "ffmpeg_concat", "ffmpeg_concat_filter", "ffmpeg_concat_demuxer",
      "ffmpeg_audio_mix", "ffmpeg_replace_audio",
      "magick_compose", "magick_montage",
      "diff_files", "git_commit_push",
    ]

    // Non-`and` connectors always indicate a second operation when the
    // tail names an action keyword — even for native-and-consuming templates.
    // ("concat A and B with a fade-in" → still a multi-op).
    let strongConnectors = [" then ", " plus ", " also ", " with a ", " and also "]
    for connector in strongConnectors {
      if let range = lower.range(of: connector) {
        let tail = String(lower[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
        if secondOpKeywords.contains(where: { tail.contains($0) }) {
          return tail
        }
      }
    }

    // " and " is a weaker signal — may be a native-syntax conjunction.
    // Only flag for non-native templates AND require an action keyword
    // in the tail.
    if !nativeAndConsuming.contains(primaryTemplateId),
       let range = lower.range(of: " and ") {
      let tail = String(lower[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
      if secondOpKeywords.contains(where: { tail.contains($0) }) {
        return tail
      }
    }
    return nil
  }

  /// Detect conversational/meta queries that have no shell-command answer.
  /// Examples: "tell me about kubernetes", "explain how to use grep",
  /// "what is the difference between sed and awk".
  /// Returns true if the query starts with a conversational prefix AND
  /// is followed by enough words to be a real question (>= 3 words total).
  static func isConversational(_ query: String) -> Bool {
    let lower = query.lowercased().trimmingCharacters(in: .whitespaces)
    // Narrow set: only true meta-questions that have NO command answer.
    // 'explain the find command' / 'how do I use grep' are intentionally
    // NOT here — those legitimately route to man/help.
    let conversationalPrefixes: [String] = [
      "tell me about ",
      "tell me what is ",
      "what is the difference between ",
      "what's the difference between ",
      "why does ",
      "why is ",
    ]
    for prefix in conversationalPrefixes {
      if lower.hasPrefix(prefix) {
        // Require at least 1 token after the prefix (sanity)
        let rest = String(lower.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { return true }
      }
    }
    return false
  }
}

// MARK: - Cross-Platform Timing Helper

#if os(WASI)
/// Lightweight timing wrapper for platforms without ContinuousClock.
struct PipelineTimer {
  private let start: Double
  init() { self.start = 0 }  // No high-res timer in WASI
  func elapsedMs() -> Double { 0 }
  static func now() -> PipelineTimer { PipelineTimer() }
}
#else
/// Timing wrapper using ContinuousClock.
struct PipelineTimer {
  private let instant: ContinuousClock.Instant
  private init(_ instant: ContinuousClock.Instant) { self.instant = instant }
  func elapsedMs() -> Double {
    let elapsed = ContinuousClock.now - instant
    return Double(elapsed.components.seconds) * 1000.0
      + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000.0
  }
  static func now() -> PipelineTimer { PipelineTimer(.now) }
}
#endif
