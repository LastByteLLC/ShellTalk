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

  /// Time spent constructing the pipeline (system discovery, index building, etc.)
  public let initMs: Double

  public init(
    profile: SystemProfile? = nil,
    store: TemplateStore? = nil,
    config: PipelineConfig = .default
  ) {
    let initStart = PipelineTimer.now()
    let prof = profile ?? SystemProfile.detect()
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
    self.matcher = IntentMatcher(store: st, config: cfg.matcherConfig)
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

    // Step 0: Recognize entities
    var t0 = PipelineTimer.now()
    let entities = recognizer.recognize(query)
    timings.append(StageTiming(name: "entities", elapsedMs: t0.elapsedMs()))

    // Step 1: Match intent (entity-aware)
    t0 = PipelineTimer.now()
    guard let match = matcher.match(query, entities: entities) else { return nil }
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
    let valueNormalization: [String: String] = [
      "lines": "l", "line": "l",
      "words": "w", "word": "w",
      "characters": "c", "chars": "c", "char": "c",
      "bytes": "c",
      "code": "l",
    ]
    for (name, value) in slots {
      if let normalized = valueNormalization[value.lowercased()] {
        slots[name] = normalized
      }
    }
    timings.append(StageTiming(name: "extract", elapsedMs: t0.elapsedMs()))

    // Step 3: Resolve template
    t0 = PipelineTimer.now()
    let command = resolver.resolve(template: match.template, extractedSlots: slots)
    timings.append(StageTiming(name: "resolve", elapsedMs: t0.elapsedMs()))

    // Step 4: Validate (optional)
    t0 = PipelineTimer.now()
    let validation = config.validateCommands ? validator.validate(command) : nil
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

    return PipelineResult(
      command: command,
      categoryId: match.categoryId,
      templateId: match.templateId,
      categoryScore: match.categoryScore,
      templateScore: match.templateScore,
      extractedSlots: slots,
      validation: validation,
      debugInfo: debug
    )
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

  private func resolvePlatformSlotsUsed(in command: String) -> [String: String] {
    let platformSlots = PlatformSlots(profile: profile)
    var resolved: [String: String] = [:]

    let pattern = #"\{([A-Z][A-Z0-9_]+)\}"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return resolved }

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
