// SlotExtractor.swift — Extract parameter values from natural language queries
//
// Three-strategy extraction:
//   1. Entity-based — match recognized entities to slot types
//   2. Regex-based — per-template regex patterns
//   3. Type-heuristic — fallback extraction by slot type
//
// Entity-based extraction is preferred because it understands the semantic
// structure of the query (preposition frames, POS tags, lexicon matching).

import Foundation

#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Extracts slot values from a user query based on template slot definitions.
public struct SlotExtractor: Sendable {

  public init() {}

  /// Extract slot values using entity recognition + regex fallback.
  public func extract(
    from query: String,
    slots: [String: SlotDefinition],
    entities: [RecognizedEntity],
    profile: SystemProfile
  ) -> [String: String] {
    var extracted: [String: String] = [:]
    var usedEntities = Set<String>()  // Track which entities we've consumed

    // C8: deterministic slot iteration + consumed-range tracking.
    // Swift dictionary order is non-deterministic, which makes slot
    // collisions (two slots whose extractPattern matches the same span)
    // resolve differently across runs. Sort by (specificity, name) so
    // narrower patterns win first, and track which character ranges of
    // the query each slot's regex consumed.
    let sortedSlotNames = slots.keys.sorted(by: Self.slotPrioritySort(slots: slots))
    var consumedRanges: [Range<String.Index>] = []

    for name in sortedSlotNames {
      guard let definition = slots[name] else { continue }
      // Strategy 1: Regex extraction pattern (most precise, template-author-designed)
      // T2.1: when multi=true, collect all matches and join with space.
      if let pattern = definition.extractPattern {
        let value: String?
        let matchRange: Range<String.Index>?
        if definition.multi {
          value = extractAllMatches(pattern: pattern, from: query)
          matchRange = nil  // multi consumes many spans; conservative: don't reserve
        } else {
          let result = Self.extractByRegexWithRange(
            pattern: pattern, from: query, excluding: consumedRanges)
          value = result.value
          matchRange = result.range
        }
        if let v = value, !isNoiseValue(v, type: definition.type) {
          if definition.multi {
            let parts = v.split(separator: " ").map { sanitize(String($0), type: definition.type) }
            extracted[name] = parts.joined(separator: " ")
          } else {
            extracted[name] = sanitize(v, type: definition.type)
          }
          if let r = matchRange { consumedRanges.append(r) }
          // C8: also tell entity matching this value was consumed so a
          // later slot's entity-fallback doesn't grab the same string.
          usedEntities.insert(v)
          if let cleaned = extracted[name] { usedEntities.insert(cleaned) }
          continue
        }
      }

      // Strategy 2: Entity-based matching (fills gaps regex can't cover)
      if let value = matchEntity(
        slotName: name, definition: definition,
        entities: entities, used: &usedEntities
      ) {
        extracted[name] = sanitize(value, type: definition.type)
        continue
      }

      // Strategy 3: Type-specific heuristic extraction
      if let value = extractByType(definition.type, from: query, slotName: name),
         !isNoiseValue(value, type: definition.type) {
        extracted[name] = sanitize(value, type: definition.type)         // T1.8: was bypassing sanitize
        continue
      }

      // Strategy 3.5 (A3): Glob synthesis from natural-language quantifiers.
      // For .glob slots that nothing else filled, try to derive a `*.ext`
      // pattern from queries like "all PNG", "every JPEG", "the mp4 files".
      // This converts "convert all png to jpg" from a no-confident-match
      // (after the A1 placeholder guard) into a runnable `magick *.png ...`.
      if definition.type == .glob,
         let glob = FileExtensionAliases.synthesizeGlob(from: query) {
        extracted[name] = glob
        continue
      }

      // Strategy 3.6 (B5): Semantic-shape synthesis. Slot names like
      // TILE / GEOMETRY have natural-language forms — "row" implies
      // tile=Nx1, "column" implies 1xN, "grid" implies NxN. When the
      // query uses a shape word and the regex didn't pick it up, fall
      // through to this synthesis instead of the literal default.
      if let shape = Self.synthesizeShape(slotName: name, from: query) {
        extracted[name] = shape
        continue
      }

      // Fallback: default value
      if let defaultValue = definition.defaultValue {
        extracted[name] = defaultValue
      }
    }

    // Post-extraction validation: replace noise values with defaults
    for (name, value) in extracted {
      guard let definition = slots[name] else { continue }
      if isNoiseValue(value, type: definition.type) {
        if let defaultValue = definition.defaultValue {
          extracted[name] = defaultValue
        } else {
          extracted.removeValue(forKey: name)
        }
      }
    }

    // A2: Slot-name-aware validation. Some slots are too domain-specific
    // for SlotType to capture — COLOR must be a color, BITRATE must be
    // a digit+unit, DAYS must be in a sane range, etc. When a value
    // fails its name-specific validator we try semantic-shape synthesis
    // first (B5: "row" → tile=0x1), then fall back to defaultValue,
    // then drop the slot.
    for (name, value) in extracted {
      guard let definition = slots[name] else { continue }
      if !Self.passesNameValidation(name: name, value: value) {
        if let shape = Self.synthesizeShape(slotName: name, from: query) {
          extracted[name] = shape
        } else if let defaultValue = definition.defaultValue {
          extracted[name] = defaultValue
        } else {
          extracted.removeValue(forKey: name)
        }
      }
    }

    return extracted
  }

  /// Slot-name-specific validators. Catches structurally-wrong bindings
  /// that SlotType-level checks would miss. Returns true if the value is
  /// acceptable for a slot of this name. Names matched here are uppercase
  /// canonical forms used in templates (e.g., "COLOR", "BITRATE", "DAYS").
  static func passesNameValidation(name: String, value: String) -> Bool {
    let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if v.isEmpty { return true }  // empty values handled elsewhere
    switch name {
    case "COLOR":
      // Named CSS-style color, hex (#rrggbb or #rgb), or rgba(...).
      let lower = v.lowercased()
      if Self.namedColors.contains(lower) { return true }
      if v.range(of: #"^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$"#, options: .regularExpression) != nil { return true }
      if v.range(of: #"^rgba?\("#, options: .regularExpression) != nil { return true }
      return false
    case "BITRATE":
      // 5M, 192k, 1500, 5000kbps, 5Mbps
      return v.range(of: #"^\d+[KkMmGg]?[Bb]?(?:ps)?$"#, options: .regularExpression) != nil
    case "DAYS":
      // 1 day to ~30 years
      guard let n = Int(v) else { return false }
      return n >= 1 && n <= 11000
    case "BITS":
      // RSA key sizes: 1024, 2048, 3072, 4096, 8192
      guard let n = Int(v) else { return false }
      return [512, 1024, 2048, 3072, 4096, 6144, 8192].contains(n)
    case "DEGREES":
      guard let n = Int(v) else { return false }
      return n >= -360 && n <= 360
    case "CRF":
      guard let n = Int(v) else { return false }
      return n >= 0 && n <= 51
    case "Q":
      guard let n = Int(v) else { return false }
      return n >= 1 && n <= 100
    case "FPS":
      guard let n = Int(v) else { return false }
      return n >= 1 && n <= 240
    case "SECS":
      guard let n = Int(v) else { return false }
      return n >= 1 && n <= 86400
    case "PORT":
      guard let n = Int(v) else { return false }
      return n >= 1 && n <= 65535
    case "SIZE":
      // SIZE is overloaded: imagemagick dimensions (200x200, 50%, 800x600+0+0)
      // AND filesystem size (100M, 1G, 512K) AND raw counts (1024).
      // Accept any of these; reject only random words like "JPEGs" or "border".
      if v.range(
        of: #"^\d+(x\d*){0,2}([+-]\d+){0,2}%?$|^\d+%$"#,
        options: .regularExpression) != nil { return true }
      // Filesystem size form
      if v.range(
        of: #"^\d+[KkMmGgTt]?[Bb]?$"#,
        options: .regularExpression) != nil { return true }
      return false
    case "GEOMETRY", "TILE", "DIMENSIONS":
      // ImageMagick geometry/tile: NxM, NxMxK, N%, AxB+C+D, also "4x" (open).
      // ImageMagick accepts `-tile 4x` (4 columns, rows auto), so the
      // closing dimension count is optional.
      return v.range(
        of: #"^\d+(x\d*){0,2}([+-]\d+){0,2}%?$|^\d+%$|^x\d+$"#,
        options: .regularExpression) != nil
    case "TIME", "START", "END":
      // HH:MM:SS, MM:SS, SS, or N+suffix (30s, 1m30, 1:30)
      return v.range(
        of: #"^\d+[:.][\d:.]+|^\d+(\.\d+)?$|^\d+(s|m|h|sec|min|hr)$"#,
        options: .regularExpression) != nil
    case "SUBJ":
      // OpenSSL DN format: /CN=foo/O=bar (or simpler /CN=foo).
      return v.hasPrefix("/") && v.contains("=")
    case "N":
      // Generic small integer (strip-components, transpose mode, etc.).
      guard let n = Int(v) else { return false }
      return n >= 0 && n <= 100
    case "LENGTH":
      // openssl rand length / similar
      guard let n = Int(v) else { return false }
      return n >= 1 && n <= 1024
    default:
      return true  // Unknown slot names pass through
    }
  }

  /// B5: Semantic-shape synthesis. Maps natural-language shape words
  /// to ImageMagick tile / geometry forms. "Put images in a row" →
  /// tile=Nx1; "into a grid" → tile=NxN. When the query specifies an
  /// integer dimension, that's used; otherwise sensible defaults fire.
  static func synthesizeShape(slotName: String, from query: String) -> String? {
    let lower = query.lowercased()
    let isTile = slotName == "TILE"
    let isGeo = slotName == "GEOMETRY"
    if !isTile && !isGeo { return nil }

    // Look for an explicit count near the shape word.
    func extractCount(near word: String) -> Int? {
      let pattern = #"(?:(\d+)\s+(?:wide|across|per\s+row|columns?|cols?|images?|files?)|(?:in\s+a\s+|into\s+a\s+)?\d+\s*x\s*\d*\s+\#(word)|(?:into\s+a\s+|in\s+a\s+|of\s+)(\d+)[ -]?\#(word))"#
      _ = pattern  // For documentation; below uses a simpler approach.
      let countPattern = #"(\d+)\s*(?:wide|per\s+row|across|columns?|cols?)"#
      if let regex = try? NSRegularExpression(pattern: countPattern),
         let m = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
         m.numberOfRanges >= 2,
         let r = Range(m.range(at: 1), in: lower),
         let n = Int(lower[r]) {
        return n
      }
      return nil
    }

    // ROW shape: NxM where M=1.
    if lower.contains(" row ") || lower.contains("a row ") || lower.contains("into a row")
       || lower.contains("in a row") || lower.contains(" row\u{0}") || lower.hasSuffix("row") {
      let n = extractCount(near: "row") ?? 0
      // tile=Nx1: Nx0 means "as many as needed in 1 row" in ImageMagick.
      // For GEOMETRY return a per-cell size default.
      if isTile { return n > 0 ? "\(n)x1" : "0x1" }
      if isGeo { return "200x200+5+5" }
    }

    // COLUMN shape: 1xN.
    if lower.contains("column") || lower.contains(" col ") || lower.contains("a column")
       || lower.contains("into a column") || lower.contains("in a column") {
      let n = extractCount(near: "column") ?? 0
      if isTile { return n > 0 ? "1x\(n)" : "1x0" }
      if isGeo { return "200x200+5+5" }
    }

    // GRID / contact-sheet shape: NxM. Look for explicit AxB form first.
    if lower.contains("grid") || lower.contains("contact sheet") || lower.contains("tile") {
      // If the query mentions "NxM grid", capture it.
      let gridPattern = #"(\d+)\s*x\s*(\d+)\s*(?:grid|tile)?"#
      if let regex = try? NSRegularExpression(pattern: gridPattern),
         let m = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
         m.numberOfRanges >= 3,
         let rA = Range(m.range(at: 1), in: lower),
         let rB = Range(m.range(at: 2), in: lower) {
        if isTile { return "\(lower[rA])x\(lower[rB])" }
      }
      // Default grid: 4x without specified rows (auto)
      if isTile { return "4x" }
      if isGeo { return "200x200+5+5" }
    }

    return nil
  }

  /// Common color names accepted by ImageMagick / CSS / X11.
  static let namedColors: Set<String> = [
    "white", "black", "red", "green", "blue", "yellow", "cyan", "magenta",
    "gray", "grey", "orange", "purple", "pink", "brown", "transparent",
    "none", "lightgray", "lightgrey", "darkgray", "darkgrey", "navy",
    "teal", "olive", "maroon", "silver", "gold", "violet", "indigo",
  ]

  // MARK: - Noise Detection

  /// Check if an extracted value is a noise word that shouldn't be used as a slot value.
  private func isNoiseValue(_ value: String, type: SlotType) -> Bool {
    let lowered = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    // File-size slots must be digits with optional K/M/G/T + optional B.
    // Reject anything else ("top", "biggest", bare words) so defaultValue
    // fires instead of emitting a malformed `-size +top`.
    if type == .fileSize {
      return lowered.range(of: #"^\d+[kmgt]?b?$"#, options: .regularExpression) == nil
    }

    // Single stop words are never valid slot values
    if Self.slotStopWords.contains(lowered) {
      return true
    }

    // For PATH-type slots, also reject meta-nouns
    if type == .path || type == .glob {
      if Self.pathMetaNouns.contains(lowered) {
        return true
      }
    }

    // Numbers can't be paths
    if type == .path, lowered.allSatisfy(\.isNumber) {
      return true
    }

    // Very short generic words without path separators are unlikely to be real paths
    // But allow common directory names like "build", "src", "dist", "tmp"
    let commonDirNames: Set<String> = [
      "build", "src", "dist", "tmp", "out", "bin", "lib", "docs",
      "test", "tests", "vendor", "node_modules", "target", "output",
    ]
    if type == .path, !lowered.contains("/"), !lowered.contains("."),
       lowered.count <= 4, !commonDirNames.contains(lowered) {
      return true
    }

    return false
  }

  /// Words that should never be extracted as slot values.
  static let slotStopWords: Set<String> = [
    "the", "a", "an", "in", "of", "to", "at", "on", "for", "with",
    "from", "by", "what", "how", "this", "that", "all", "my", "your",
    "its", "our", "their", "me", "him", "her", "us", "them",
    "is", "are", "was", "were", "be", "been", "being",
    "do", "does", "did", "will", "would", "could", "should",
    "have", "has", "had", "get", "got", "make", "made",
    "just", "also", "very", "too", "here", "there", "now",
    "up", "out", "about", "into", "over", "some", "more",
    "every", "each", "both", "own", "such", "like",
    "yes", "no", "not", "please", "yo", "bro", "dude",
  ]

  /// Meta-nouns that describe types, not entities — invalid as path values.
  static let pathMetaNouns: Set<String> = [
    "file", "files", "directory", "directories", "folder", "folders",
    "command", "commands", "output", "input", "result", "results",
    "change", "changes", "process", "package", "version",
    "status", "info", "data", "archive", "image",
  ]

  /// Legacy extraction without entities (backward compatible).
  public func extract(
    from query: String,
    slots: [String: SlotDefinition],
    profile: SystemProfile
  ) -> [String: String] {
    extract(from: query, slots: slots, entities: [], profile: profile)
  }

  // MARK: - Entity-Based Matching

  /// Match a recognized entity to a slot by type compatibility.
  private func matchEntity(
    slotName: String,
    definition: SlotDefinition,
    entities: [RecognizedEntity],
    used: inout Set<String>
  ) -> String? {
    // Map slot types to compatible entity types
    let compatibleTypes = Self.slotToEntityTypes[definition.type] ?? []
    guard !compatibleTypes.isEmpty else { return nil }

    // Also consider role-based matching
    let preferredRole = Self.slotNameToRole[slotName.lowercased()]

    // Score each entity for this slot
    var bestMatch: (entity: RecognizedEntity, score: Float)?

    for entity in entities {
      // Skip already-used entities
      guard !used.contains(entity.text) else { continue }

      // Must be a compatible type
      guard compatibleTypes.contains(entity.type) else { continue }

      var score = entity.confidence

      // Boost if the role matches the slot name expectation
      if let preferred = preferredRole, entity.role == preferred {
        score += 0.3
      }

      // Boost if entity role matches common slot-role associations
      if let roleBoost = roleScore(entity.role, forSlot: slotName) {
        score += roleBoost
      }

      if bestMatch == nil || score > bestMatch!.score {
        bestMatch = (entity, score)
      }
    }

    if let match = bestMatch {
      used.insert(match.entity.text)
      return match.entity.text
    }

    return nil
  }

  /// Score bonus for entity role matching a slot name pattern.
  private func roleScore(_ role: EntityRole, forSlot slotName: String) -> Float? {
    let name = slotName.lowercased()

    switch role {
    case .source:
      if name.contains("source") || name.contains("from") || name == "find" { return 0.2 }
    case .destination:
      if name.contains("dest") || name.contains("to") || name.contains("output") { return 0.2 }
    case .location:
      if name.contains("path") || name.contains("dir") || name == "file" { return 0.2 }
    case .target:
      if name.contains("target") || name.contains("pattern") || name.contains("file") { return 0.15 }
    case .name:
      if name.contains("name") || name.contains("pattern") { return 0.25 }
    case .instrument:
      if name.contains("flag") || name.contains("tool") { return 0.1 }
    case .pattern:
      if name.contains("pattern") || name.contains("find") || name.contains("match") { return 0.25 }
    default:
      break
    }

    return nil
  }

  // MARK: - Regex Extraction

  /// Pre-compiled regex for the N-unit form in `resolveRelativeDays`
  /// (e.g., "3 days", "2 weeks"). Compiled once at load time.
  private static let relativeDaysRegex: NSRegularExpression =
    try! NSRegularExpression(pattern: #"^(\d+)\s+(days?|weeks?|months?|years?)$"#)

  /// Process-wide cache of compiled template extract-pattern regexes.
  /// Template `extractPattern` strings are drawn from a fixed set (~245
  /// templates); this fills within a few queries and every subsequent
  /// lookup is O(1). NSCache is thread-safe internally; the
  /// `nonisolated(unsafe)` annotation tells Swift 6 strict concurrency
  /// we've audited this.
  nonisolated(unsafe) private static let patternCache: NSCache<NSString, NSRegularExpression> = {
    let cache = NSCache<NSString, NSRegularExpression>()
    cache.countLimit = 512
    return cache
  }()

  private static func compiledPattern(_ pattern: String) -> NSRegularExpression? {
    let key = pattern as NSString
    if let cached = patternCache.object(forKey: key) {
      return cached
    }
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return nil
    }
    patternCache.setObject(regex, forKey: key)
    return regex
  }

  private func extractByRegex(pattern: String, from text: String) -> String? {
    guard let regex = Self.compiledPattern(pattern) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range) else { return nil }

    // Return first non-nil capture group
    for i in 1..<match.numberOfRanges {
      if let captureRange = Range(match.range(at: i), in: text) {
        let value = String(text[captureRange])
        if !value.isEmpty { return value }
      }
    }
    return nil
  }

  /// C8: regex extraction that skips matches whose capture group lies
  /// entirely within a previously-consumed range. Returns the captured
  /// value AND the FULL match range so callers can mark it consumed.
  static func extractByRegexWithRange(
    pattern: String,
    from text: String,
    excluding consumed: [Range<String.Index>]
  ) -> (value: String?, range: Range<String.Index>?) {
    guard let regex = Self.compiledPattern(pattern) else { return (nil, nil) }
    let nsrange = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, range: nsrange)
    for match in matches {
      // Walk capture groups for this match. If the first non-empty capture
      // is INSIDE a consumed range, skip the whole match and try next.
      for i in 1..<match.numberOfRanges {
        guard let captureRange = Range(match.range(at: i), in: text) else { continue }
        let value = String(text[captureRange])
        if value.isEmpty { continue }
        // If the captured span overlaps any consumed range, skip.
        if consumed.contains(where: { $0.overlaps(captureRange) }) {
          break  // try next match
        }
        // Use the full match range for consumption (so connector tokens
        // like "to ", "from " also get consumed).
        let fullRange = Range(match.range, in: text)
        return (value, fullRange)
      }
    }
    return (nil, nil)
  }

  /// C8: priority sort for slots. Slots with anchored extractPatterns
  /// (longer literal prefixes, more groups) are tried first because they
  /// have lower false-positive risk. Falls back to alphabetical name.
  static func slotPrioritySort(
    slots: [String: SlotDefinition]
  ) -> (String, String) -> Bool {
    return { a, b in
      let pa = slots[a]?.extractPattern ?? ""
      let pb = slots[b]?.extractPattern ?? ""
      // Prefer anchored alternation patterns (more literal context) by
      // counting non-meta characters as a rough specificity proxy.
      let sa = patternSpecificity(pa)
      let sb = patternSpecificity(pb)
      if sa != sb { return sa > sb }
      return a < b  // lexical tie-break for determinism
    }
  }

  private static func patternSpecificity(_ pattern: String) -> Int {
    if pattern.isEmpty { return 0 }
    // Count "literal anchor" characters: alphanumerics + dot inside
    // non-bracket context. Crude but effective for the templates we ship.
    var score = 0
    var inClass = false
    for c in pattern {
      if c == "[" { inClass = true; continue }
      if c == "]" { inClass = false; continue }
      if inClass { continue }
      if c.isLetter || c == "." { score += 1 }
      if c == "|" { score -= 1 }  // alternations broaden the pattern
    }
    return score
  }

  /// T2.1: Collect ALL matches' first non-nil capture group, joined with
  /// space. For `(\S+)\s+(?:and|,)\s+(\S+)` against "a.txt and b.txt"
  /// this returns "a.txt b.txt". Used for multi-source slots like cp/mv
  /// when SlotDefinition.multi is true.
  private func extractAllMatches(pattern: String, from text: String) -> String? {
    guard let regex = Self.compiledPattern(pattern) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, range: range)
    guard !matches.isEmpty else { return nil }

    var values: [String] = []
    for match in matches {
      for i in 1..<match.numberOfRanges {
        if let captureRange = Range(match.range(at: i), in: text) {
          let value = String(text[captureRange])
          if !value.isEmpty {
            values.append(value)
            break  // first non-nil group per match
          }
        }
      }
    }
    return values.isEmpty ? nil : values.joined(separator: " ")
  }

  // MARK: - Type-Specific Extraction

  private func extractByType(_ type: SlotType, from query: String, slotName: String) -> String? {
    switch type {
    case .path:
      return extractPath(from: query)
    case .glob:
      return extractGlob(from: query)
    case .number:
      return extractNumber(from: query)
    case .port:
      return extractPort(from: query)
    case .url:
      return extractURL(from: query)
    case .branch:
      return extractBranch(from: query)
    case .pattern, .string, .command, .fileExtension, .fileSize, .relativeDays, .commandFlag:
      return nil
    }
  }

  /// Convert human-readable time phrases into a day count suitable for
  /// `-mtime -N`. Accepts: "today", "yesterday", "week", "month", "year",
  /// "N days", "N weeks", "N months", "N years", or weekday names
  /// (monday..sunday) which compute days-since-last-occurrence.
  /// Case-insensitive. Falls back to the input if no unit word matches.
  ///
  /// Note: weekday-name resolution depends on the current date and is
  /// therefore non-deterministic across days. Tests should assert
  /// structure (`"-mtime"` present, slot is a digit) rather than a
  /// specific day count.
  private func resolveRelativeDays(_ raw: String) -> String {
    let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
    if lower == "today" || lower == "yesterday" { return "1" }
    if lower == "week"  { return "7" }
    if lower == "month" { return "30" }
    if lower == "year"  { return "365" }

    // Weekday names: days since the most recent occurrence.
    // "Since monday" when today is Wednesday → 2 days. When today IS
    // Monday → 7 (last week's Monday).
    let weekdayMap: [String: Int] = [
      "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
      "thursday": 5, "friday": 6, "saturday": 7,
    ]
    if let target = weekdayMap[lower] {
      let cal = Calendar(identifier: .gregorian)
      let today = cal.component(.weekday, from: Date())
      let diff = (today - target + 7) % 7
      return diff == 0 ? "7" : String(diff)
    }

    // N unit form — pattern compiled once at load time
    let nsRange = NSRange(lower.startIndex..., in: lower)
    if let match = Self.relativeDaysRegex.firstMatch(in: lower, range: nsRange),
       let matchRange = Range(match.range, in: lower) {
      let body = String(lower[matchRange])
      let parts = body.split(separator: " ")
      if parts.count == 2, let n = Int(parts[0]) {
        let unit = String(parts[1])
        let mult: Int = unit.hasPrefix("week")  ? 7
                       : unit.hasPrefix("month") ? 30
                       : unit.hasPrefix("year")  ? 365
                       : 1
        return String(n * mult)
      }
    }

    // If it's already a plain integer, return as-is.
    if Int(lower) != nil { return lower }
    // Unrecognized → let the extractor fall through to defaultValue via isNoiseValue.
    return raw
  }

  private func extractPath(from query: String) -> String? {
    let pathPattern = #"(?:^|\s)((?:\.{0,2}/|~/)[^\s]+|[^\s]+\.[a-zA-Z]{1,10})"#
    guard let captured = extractByRegex(pattern: pathPattern, from: query) else { return nil }
    // T1.8: reject glob/wildcard tokens — those are PATTERN values, not
    // PATH values. Stops `find . -name '*.py' -type f` from binding
    // PATH=`*.py` (which is a valid but semantically wrong invocation).
    if captured.hasPrefix("*") || captured.contains("*.") && !captured.contains("/") {
      return nil
    }
    return captured
  }

  private func extractGlob(from query: String) -> String? {
    let globPattern = #"(\*\*?(?:/[^\s]+)?|\*\.[a-zA-Z]+)"#
    return extractByRegex(pattern: globPattern, from: query)
  }

  private func extractNumber(from query: String) -> String? {
    let numberPattern = #"(\d+)"#
    return extractByRegex(pattern: numberPattern, from: query)
  }

  private func extractPort(from query: String) -> String? {
    let portPattern = #"(?:port\s+)(\d{1,5})"#
    if let port = extractByRegex(pattern: portPattern, from: query),
       let num = Int(port), num >= 1, num <= 65535 {
      return port
    }
    return nil
  }

  private func extractURL(from query: String) -> String? {
    let urlPattern = #"(https?://[^\s]+)"#
    return extractByRegex(pattern: urlPattern, from: query)
  }

  private func extractBranch(from query: String) -> String? {
    let branchPattern = #"(?:branch\s+|to\s+|from\s+)([a-zA-Z0-9._/-]+)"#
    return extractByRegex(pattern: branchPattern, from: query)
  }

  // MARK: - Sanitization

  private func sanitize(_ value: String, type: SlotType) -> String {
    var cleaned = value.trimmingCharacters(in: .whitespaces)

    // T1.8: strip leading/trailing quotes for path/glob/string slots so
    // CLI-style queries like `find . -name '*.py' -type f` don't
    // produce double-quoted output (`-name ''*.py''`). Stripped
    // independently on each side to handle the regex-cropped case where
    // the closing quote sits outside the captured boundary.
    if type == .path || type == .glob || type == .string {
      while let first = cleaned.first, first == "'" || first == "\"" {
        cleaned.removeFirst()
      }
      while let last = cleaned.last, last == "'" || last == "\"" {
        cleaned.removeLast()
      }
    }

    switch type {
    case .path:
      cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
    case .pattern:
      cleaned = cleaned.replacingOccurrences(of: "'", with: "'\\''")
    case .port:
      if let num = Int(cleaned), num < 1 || num > 65535 {
        return "8080"
      }
    case .fileExtension:
      cleaned = FileExtensionAliases.resolve(cleaned)
    case .relativeDays:
      cleaned = resolveRelativeDays(cleaned)
    case .number:
      cleaned = Self.normalizeNumericUnit(cleaned)
    case .fileSize:
      cleaned = Self.normalizeFileSize(cleaned)
    default:
      break
    }

    return cleaned
  }

  /// A4: Normalize natural-language numeric forms into bare integers.
  /// "4px"→"4", "10sec"→"10", "30min"→"30", "2x"→"2", "180°"→"180".
  /// Pure-digit values pass through unchanged.
  static func normalizeNumericUnit(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return trimmed }
    if Int(trimmed) != nil { return trimmed }
    // Strip a known unit suffix.
    let suffixes = [
      "px", "pixels", "pixel",
      "sec", "secs", "seconds", "second", "s",
      "min", "mins", "minutes", "minute",
      "hr", "hrs", "hours", "hour", "h",
      "ms", "millis",
      "x",
      "°", "deg", "degrees", "degree",
      "%",
    ]
    let lower = trimmed.lowercased()
    for suffix in suffixes where lower.hasSuffix(suffix) {
      let stripped = String(trimmed.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
      if Int(stripped) != nil { return stripped }
    }
    return trimmed
  }

  /// A4: Normalize file-size expressions to ShellTalk's canonical form.
  /// "10MB"→"10M", "5 gigabytes"→"5G", "100kb"→"100K". Unrecognized
  /// values pass through; the .fileSize isNoiseValue gate catches junk.
  static func normalizeFileSize(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    let lower = trimmed.lowercased().replacingOccurrences(of: " ", with: "")
    // Match digits then unit.
    let pattern = #"^(\d+)(b|byte|bytes|k|kb|kilobyte|kilobytes|m|mb|megabyte|megabytes|g|gb|gigabyte|gigabytes|t|tb|terabyte|terabytes)?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
          let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
          match.numberOfRanges >= 2,
          let numRange = Range(match.range(at: 1), in: lower)
    else { return trimmed }
    let num = String(lower[numRange])
    let unitRange = match.range(at: 2)
    let unit: String
    if unitRange.location == NSNotFound {
      unit = ""
    } else if let r = Range(unitRange, in: lower) {
      unit = String(lower[r])
    } else {
      unit = ""
    }
    let canonical: String
    switch unit {
    case "k", "kb", "kilobyte", "kilobytes": canonical = "K"
    case "m", "mb", "megabyte", "megabytes": canonical = "M"
    case "g", "gb", "gigabyte", "gigabytes": canonical = "G"
    case "t", "tb", "terabyte", "terabytes": canonical = "T"
    case "b", "byte", "bytes", "": canonical = ""
    default: canonical = unit.uppercased()
    }
    return num + canonical
  }

  // MARK: - Slot Type → Entity Type Mapping

  /// Which entity types are compatible with each slot type.
  static let slotToEntityTypes: [SlotType: Set<EntityType>] = [
    .path: [.filePath, .fileName, .directoryPath],
    .glob: [.glob, .fileName],
    .url: [.url],
    .port: [.port],
    .branch: [.branchName, .gitRef],
    .pattern: [.glob, .fileName, .string],
    .number: [.number, .size, .port],
    .string: [.string, .applicationName, .processName, .commandName, .packageName, .fileName],
    .command: [.commandName],
    .fileExtension: [.string],
    .commandFlag: [],   // T2.1: deliberately empty — only regex extraction allowed
  ]

  /// Common slot name → preferred entity role.
  static let slotNameToRole: [String: EntityRole] = [
    "source": .source, "src": .source, "from": .source, "input": .source,
    "dest": .destination, "destination": .destination, "to": .destination, "output": .destination,
    "path": .location, "dir": .location, "directory": .location, "file": .location,
    "pattern": .pattern, "match": .pattern, "find": .pattern,
    "name": .name, "named": .name,
    "target": .target,
  ]
}
