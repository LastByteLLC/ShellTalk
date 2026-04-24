// TemplateResolver.swift — Resolve a matched template into a concrete command
//
// Takes a CommandTemplate, extracted slot values, and the SystemProfile,
// then produces the final executable command string.

import Foundation

/// Resolves templates into concrete shell commands.
public struct TemplateResolver: Sendable {
  private let platformSlots: PlatformSlots
  private let profile: SystemProfile

  public init(profile: SystemProfile) {
    self.profile = profile
    self.platformSlots = PlatformSlots(profile: profile)
  }

  /// Resolve a template with extracted slots into a concrete command.
  public func resolve(
    template: CommandTemplate,
    extractedSlots: [String: String]
  ) -> String {
    // Start with the base command (or platform override)
    var command = platformCommand(for: template)

    // Replace platform slots first (SED_INPLACE, STAT_SIZE, etc.)
    command = resolvePlatformSlots(in: command)

    // Replace user-extracted slots
    command = resolveUserSlots(in: command, slots: extractedSlots, definitions: template.slots)

    // Replace any remaining unresolved slots with defaults
    command = resolveDefaults(in: command, definitions: template.slots)

    // Clean up extra whitespace
    command = command
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespaces)

    return command
  }

  // MARK: - Platform Command Selection

  private func platformCommand(for template: CommandTemplate) -> String {
    guard let overrides = template.platformOverrides else {
      return template.command
    }

    let key = profile.os.rawValue.lowercased()
    return overrides[key] ?? template.command
  }

  // MARK: - Platform Slot Resolution

  /// Pre-compiled slot-placeholder pattern, matching `{UPPERCASE_SLOT}`.
  /// Public so STMPipeline can reuse the same compiled instance for its
  /// debug-info platform-slot resolution.
  static let platformSlotRegex: NSRegularExpression =
    try! NSRegularExpression(pattern: #"\{([A-Z][A-Z0-9_]+)\}"#)

  private func resolvePlatformSlots(in command: String) -> String {
    var result = command
    // Find all {UPPERCASE_SLOT} patterns and try to resolve as platform slots
    let regex = Self.platformSlotRegex

    let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

    // Process in reverse order to preserve ranges
    for match in matches.reversed() {
      guard let slotRange = Range(match.range(at: 1), in: result),
            let fullRange = Range(match.range, in: result) else { continue }

      let slotName = String(result[slotRange])

      if let resolved = platformSlots.resolve(slotName) {
        result.replaceSubrange(fullRange, with: resolved)
      }
    }

    return result
  }

  // MARK: - User Slot Resolution

  private func resolveUserSlots(
    in command: String,
    slots: [String: String],
    definitions: [String: SlotDefinition]
  ) -> String {
    var result = command

    for (name, value) in slots {
      let placeholder = "{\(name)}"
      result = result.replacingOccurrences(of: placeholder, with: value)
    }

    return result
  }

  // MARK: - Default Resolution

  private func resolveDefaults(in command: String, definitions: [String: SlotDefinition]) -> String {
    var result = command

    for (name, definition) in definitions {
      let placeholder = "{\(name)}"
      if result.contains(placeholder), let defaultValue = definition.defaultValue {
        result = result.replacingOccurrences(of: placeholder, with: defaultValue)
      }
    }

    return result
  }
}
