// FileExtensionAliasesTests.swift — Integrity checks for the canonical map.
//
// These tests pin the shape of the alias table so silent drift is caught.
// Behavioral tests (query → command with correct extension) live in
// STMAccuracyTests.fileExtensionAliases().

import Testing
@testable import ShellTalkKit

@Suite("FileExtensionAliases")
struct FileExtensionAliasesTests {

  @Test("Every key is lowercase and every value is a plausible short extension")
  func tableShape() {
    for (key, value) in FileExtensionAliases.canonical {
      #expect(key == key.lowercased(), "Key '\(key)' must be lowercase")
      #expect(!value.isEmpty, "Value for '\(key)' is empty")
      #expect(value == value.lowercased(), "Value '\(value)' for '\(key)' must be lowercase")
      #expect(value.count <= 8, "Value '\(value)' for '\(key)' longer than 8 chars — likely a format name, not an extension")
      #expect(!value.hasPrefix("."), "Value '\(value)' for '\(key)' must not have a leading dot")
    }
  }

  @Test("Resolve canonicalizes known aliases")
  func knownAliases() {
    #expect(FileExtensionAliases.resolve("markdown") == "md")
    #expect(FileExtensionAliases.resolve("javascript") == "js")
    #expect(FileExtensionAliases.resolve("typescript") == "ts")
    #expect(FileExtensionAliases.resolve("python") == "py")
    #expect(FileExtensionAliases.resolve("ruby") == "rb")
    #expect(FileExtensionAliases.resolve("golang") == "go")
    #expect(FileExtensionAliases.resolve("rust") == "rs")
    #expect(FileExtensionAliases.resolve("kotlin") == "kt")
    #expect(FileExtensionAliases.resolve("shell") == "sh")
    #expect(FileExtensionAliases.resolve("bash") == "sh")
  }

  @Test("Resolve is case-insensitive")
  func caseInsensitive() {
    #expect(FileExtensionAliases.resolve("Markdown") == "md")
    #expect(FileExtensionAliases.resolve("MARKDOWN") == "md")
    #expect(FileExtensionAliases.resolve("JavaScript") == "js")
    #expect(FileExtensionAliases.resolve("PYTHON") == "py")
  }

  @Test("Unknown names lowercase through identity fallback (no mangled uppercase)")
  func identityFallback() {
    #expect(FileExtensionAliases.resolve("CONFIG") == "config")
    #expect(FileExtensionAliases.resolve("Custom") == "custom")
    #expect(FileExtensionAliases.resolve("xyz") == "xyz")
  }

  @Test("Identity entries are idempotent")
  func identityEntries() {
    #expect(FileExtensionAliases.resolve("swift") == "swift")
    #expect(FileExtensionAliases.resolve("yaml") == "yaml")
    #expect(FileExtensionAliases.resolve("html") == "html")
    #expect(FileExtensionAliases.resolve("json") == "json")
    #expect(FileExtensionAliases.resolve("css") == "css")
  }
}
