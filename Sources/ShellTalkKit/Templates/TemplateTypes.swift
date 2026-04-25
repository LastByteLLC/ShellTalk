// TemplateTypes.swift — Data model for command templates
//
// Templates are the core data structure of STM. Each template represents
// a single command pattern with intent phrases, parameterized slots,
// and platform-specific variants.

import Foundation

/// A category grouping related command templates.
public struct TemplateCategory: Sendable, Codable {
  public let id: String
  public let name: String
  public let description: String
  public let templates: [CommandTemplate]

  public init(id: String, name: String, description: String, templates: [CommandTemplate]) {
    self.id = id
    self.name = name
    self.description = description
    self.templates = templates
  }
}

/// A single command template with intent phrases and parameterized command.
public struct CommandTemplate: Sendable, Codable {
  public let id: String
  public let intents: [String]
  public let command: String
  public let slots: [String: SlotDefinition]
  public let platformOverrides: [String: String]?
  public let flags: [FlagDefinition]?
  public let tags: [String]?
  /// Tokens that should penalize this template's score when present in the query.
  public let negativeKeywords: [String]?
  /// Tokens that MUST be present for this template to win command-prefix matching.
  /// Templates without discriminators are the "default" for their command prefix.
  public let discriminators: [String]?
  /// Capability predicates (see `SystemProfile.satisfies`) that must hold for the
  /// template to be a high-confidence pick. Unsatisfied requirements *demote*
  /// (not exclude) the template, so debug/alternatives still surface it.
  public let requires: [String]?

  public init(
    id: String,
    intents: [String],
    command: String,
    slots: [String: SlotDefinition] = [:],
    platformOverrides: [String: String]? = nil,
    flags: [FlagDefinition]? = nil,
    tags: [String]? = nil,
    negativeKeywords: [String]? = nil,
    discriminators: [String]? = nil,
    requires: [String]? = nil
  ) {
    self.id = id
    self.intents = intents
    self.command = command
    self.slots = slots
    self.platformOverrides = platformOverrides
    self.flags = flags
    self.tags = tags
    self.negativeKeywords = negativeKeywords
    self.discriminators = discriminators
    self.requires = requires
  }
}

/// Definition for a template slot (parameter).
public struct SlotDefinition: Sendable, Codable {
  public let type: SlotType
  public let defaultValue: String?
  public let extractPattern: String?
  public let description: String?
  /// T2.1: when true, regex extraction collects ALL matches and joins
  /// them with a space. Used for `{SOURCES}`-style multi-arg patterns
  /// like `cp a.txt and b.txt to dst/` → SOURCES="a.txt b.txt".
  public let multi: Bool

  public init(
    type: SlotType,
    defaultValue: String? = nil,
    extractPattern: String? = nil,
    description: String? = nil,
    multi: Bool = false
  ) {
    self.type = type
    self.defaultValue = defaultValue
    self.extractPattern = extractPattern
    self.description = description
    self.multi = multi
  }

  enum CodingKeys: String, CodingKey {
    case type
    case defaultValue = "default"
    case extractPattern = "extract"
    case description
    case multi
  }
}

/// Type of a template slot, used for validation and formatting.
public enum SlotType: String, Sendable, Codable {
  case string       // Free-form text
  case path         // File or directory path
  case glob         // Glob pattern (*.swift, etc.)
  case number       // Integer value
  case port         // Port number (1-65535)
  case url          // URL
  case branch       // Git branch name
  case pattern      // Regex or search pattern
  case command      // A sub-command
  case fileExtension // File extension, canonicalized (markdown→md, javascript→js)
  case fileSize     // Byte size with optional unit: "100M", "1G", "512K"
  case relativeDays // Day count converted from unit words: "week"→"7", "month"→"30"
  case commandFlag  // Shell flag like -r, --recursive — never bind a filename here
}

/// An optional flag that can be appended to a command.
public struct FlagDefinition: Sendable, Codable {
  public let name: String
  public let aliases: [String]
  public let template: String
  public let description: String?

  public init(name: String, aliases: [String], template: String, description: String? = nil) {
    self.name = name
    self.aliases = aliases
    self.template = template
    self.description = description
  }
}

/// Result of matching a user query to a template.
public struct MatchResult: Sendable {
  public let category: String
  public let categoryScore: Double
  public let template: CommandTemplate
  public let templateScore: Double
  public let extractedSlots: [String: String]
  public let resolvedCommand: String

  /// Combined confidence score (0..1).
  public var confidence: Double {
    min(categoryScore, templateScore)
  }
}
