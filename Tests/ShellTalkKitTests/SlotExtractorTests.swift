import Testing
@testable import ShellTalkKit

@Suite("SlotExtractor")
struct SlotExtractorTests {

  let extractor = SlotExtractor()
  let profile = SystemProfile.detect()

  @Test("Extract path from query")
  func extractPath() {
    let slots: [String: SlotDefinition] = [
      "FILE": SlotDefinition(type: .path, extractPattern: #"(?:in|of)\s+(\S+)"#),
    ]
    let result = extractor.extract(from: "replace text in config.yaml", slots: slots, profile: profile)
    #expect(result["FILE"] == "config.yaml")
  }

  @Test("Extract pattern from search query")
  func extractPattern() {
    let slots: [String: SlotDefinition] = [
      "PATTERN": SlotDefinition(type: .pattern,
        extractPattern: #"(?:search\s+for|find|grep)\s+['\"]?(\S+)['\"]?"#),
    ]
    let result = extractor.extract(from: "search for TODO", slots: slots, profile: profile)
    #expect(result["PATTERN"] == "TODO")
  }

  @Test("Uses default when extraction fails")
  func usesDefault() {
    let slots: [String: SlotDefinition] = [
      "PATH": SlotDefinition(type: .path, defaultValue: ".",
        extractPattern: #"(?:in)\s+(\S+)"#),
    ]
    let result = extractor.extract(from: "list files", slots: slots, profile: profile)
    #expect(result["PATH"] == ".")
  }

  @Test("Extract number")
  func extractNumber() {
    let slots: [String: SlotDefinition] = [
      "COUNT": SlotDefinition(type: .number, defaultValue: "20",
        extractPattern: #"(?:last|recent)\s+(\d+)"#),
    ]
    let result = extractor.extract(from: "last 5 commits", slots: slots, profile: profile)
    #expect(result["COUNT"] == "5")
  }

  @Test("Extract git branch")
  func extractBranch() {
    let slots: [String: SlotDefinition] = [
      "BRANCH": SlotDefinition(type: .branch,
        extractPattern: #"(?:switch\s+to|checkout)\s+(\S+)"#),
    ]
    let result = extractor.extract(from: "switch to feature/auth", slots: slots, profile: profile)
    #expect(result["BRANCH"] == "feature/auth")
  }

  @Test("Extract URL")
  func extractURL() {
    let slots: [String: SlotDefinition] = [
      "URL": SlotDefinition(type: .url,
        extractPattern: #"(https?://\S+)"#),
    ]
    let result = extractor.extract(
      from: "download https://example.com/file.tar.gz",
      slots: slots,
      profile: profile
    )
    #expect(result["URL"] == "https://example.com/file.tar.gz")
  }

  @Test("Extract glob pattern")
  func extractGlob() {
    let slots: [String: SlotDefinition] = [
      "PATTERN": SlotDefinition(type: .glob,
        extractPattern: #"(\*\.\w+)"#),
    ]
    let result = extractor.extract(from: "find *.swift files", slots: slots, profile: profile)
    #expect(result["PATTERN"] == "*.swift")
  }

  @Test("Multiple slots extracted from same query")
  func multipleSlots() {
    let slots: [String: SlotDefinition] = [
      "FIND": SlotDefinition(type: .string,
        extractPattern: #"(?:replace)\s+['\"]?(\S+)['\"]?"#),
      "REPLACE": SlotDefinition(type: .string,
        extractPattern: #"(?:with)\s+['\"]?(\S+)['\"]?"#),
      "FILE": SlotDefinition(type: .path,
        extractPattern: #"(?:in)\s+(\S+)"#),
    ]
    let result = extractor.extract(
      from: "replace foo with bar in config.yaml",
      slots: slots,
      profile: profile
    )
    #expect(result["FIND"] == "foo")
    #expect(result["REPLACE"] == "bar")
    #expect(result["FILE"] == "config.yaml")
  }
}
