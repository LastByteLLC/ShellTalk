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

    for (name, definition) in slots {
      // Strategy 1: Regex extraction pattern (most precise, template-author-designed)
      if let pattern = definition.extractPattern,
         let value = extractByRegex(pattern: pattern, from: query) {
        extracted[name] = sanitize(value, type: definition.type)
        continue
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
      if let value = extractByType(definition.type, from: query, slotName: name) {
        extracted[name] = value
        continue
      }

      // Fallback: default value
      if let defaultValue = definition.defaultValue {
        extracted[name] = defaultValue
      }
    }

    return extracted
  }

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

  private func extractByRegex(pattern: String, from text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return nil
    }
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
    case .pattern, .string, .command:
      return nil
    }
  }

  private func extractPath(from query: String) -> String? {
    let pathPattern = #"(?:^|\s)((?:\.{0,2}/|~/)[^\s]+|[^\s]+\.[a-zA-Z]{1,10})"#
    return extractByRegex(pattern: pathPattern, from: query)
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

    switch type {
    case .path:
      cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
    case .pattern:
      cleaned = cleaned.replacingOccurrences(of: "'", with: "'\\''")
    case .port:
      if let num = Int(cleaned), num < 1 || num > 65535 {
        return "8080"
      }
    default:
      break
    }

    return cleaned
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
