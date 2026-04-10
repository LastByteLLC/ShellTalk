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

  public init(
    id: String,
    intents: [String],
    command: String,
    slots: [String: SlotDefinition] = [:],
    platformOverrides: [String: String]? = nil,
    flags: [FlagDefinition]? = nil,
    tags: [String]? = nil
  ) {
    self.id = id
    self.intents = intents
    self.command = command
    self.slots = slots
    self.platformOverrides = platformOverrides
    self.flags = flags
    self.tags = tags
  }
}

/// Definition for a template slot (parameter).
public struct SlotDefinition: Sendable, Codable {
  public let type: SlotType
  public let defaultValue: String?
  public let extractPattern: String?
  public let description: String?

  public init(
    type: SlotType,
    defaultValue: String? = nil,
    extractPattern: String? = nil,
    description: String? = nil
  ) {
    self.type = type
    self.defaultValue = defaultValue
    self.extractPattern = extractPattern
    self.description = description
  }

  enum CodingKeys: String, CodingKey {
    case type
    case defaultValue = "default"
    case extractPattern = "extract"
    case description
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
