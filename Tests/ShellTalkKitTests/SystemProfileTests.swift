import Testing
@testable import ShellTalkKit

@Suite("SystemProfile")
struct SystemProfileTests {

  @Test("Detects current machine")
  func detectCurrentMachine() {
    let profile = SystemProfile.detect()

    #if os(macOS)
    #expect(profile.os == .macOS)
    #elseif os(Linux)
    #expect(profile.os == .linux)
    #endif

    #expect(!profile.arch.isEmpty)
    #expect(!profile.osVersion.isEmpty)
    #expect(profile.shell != .unknown)
    #expect(!profile.availableCommands.isEmpty)
  }

  @Test("Has common commands")
  func hasCommonCommands() {
    let profile = SystemProfile.detect()
    // These should exist on any Unix-like system
    let expected = ["ls", "cat", "grep", "find", "mkdir", "rm", "cp", "mv"]
    for cmd in expected {
      #expect(profile.hasCommand(cmd), "Missing expected command: \(cmd)")
    }
  }

  @Test("Command paths are populated")
  func commandPathsPopulated() {
    let profile = SystemProfile.detect()
    #expect(profile.commandPaths["ls"] != nil)
    #expect(profile.commandPaths["git"] != nil)
  }

  @Test("Version probing finds git with full detection")
  func versionProbingFindsGit() {
    let profile = SystemProfile.detect(full: true)
    #expect(profile.commandVersions["git"] != nil)
  }

  @Test("Summary is compact")
  func summaryIsCompact() {
    let profile = SystemProfile.detect()
    let summary = profile.summary
    #expect(!summary.isEmpty)
    // Should be reasonably compact — under 1000 chars
    #expect(summary.count < 1000, "Summary too long: \(summary.count) chars")
  }

  @Test("Missing alternatives populated")
  func missingAlternatives() {
    let profile = SystemProfile.detect()
    // If wget is missing, there should be an alternative
    if !profile.hasCommand("wget") {
      #expect(profile.alternative(for: "wget") == "curl -LO")
    }
  }

  #if os(macOS)
  @Test("Detects GNU overrides on macOS")
  func gnuOverrides() {
    let profile = SystemProfile.detect()
    // If gsed is installed, it should appear as an override
    if profile.hasCommand("gsed") {
      #expect(profile.gnuOverrides["sed"] == "gsed")
    }
  }
  #endif
}
