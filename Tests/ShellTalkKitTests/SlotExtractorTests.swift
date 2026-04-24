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

  // MARK: - New slot types (round-c regression coverage)

  @Test(".fileExtension canonicalizes via FileExtensionAliases")
  func fileExtensionCanonicalize() {
    let slots = [
      "EXT": SlotDefinition(type: .fileExtension,
        extractPattern: #"(?:find|list)\s+(\w+)\s+files"#),
    ]
    let result = extractor.extract(from: "find Markdown files", slots: slots, profile: profile)
    #expect(result["EXT"] == "md")
  }

  @Test(".fileSize rejects non-numeric tokens")
  func fileSizeRejectsGarbage() {
    let slots = [
      "SIZE": SlotDefinition(type: .fileSize, defaultValue: "1M",
        extractPattern: #"(?:over|larger than|top)\s+(\S+)"#),
    ]
    // 'top 5' would extract '5' first, then fall back. Try a clear bad case.
    let r = extractor.extract(from: "find files larger than xyz", slots: slots, profile: profile)
    #expect(r["SIZE"] == "1M")  // 'xyz' rejected, default fires
  }

  @Test(".relativeDays converts week/month/year to days")
  func relativeDaysUnitConversion() {
    let slots = [
      "DAYS": SlotDefinition(type: .relativeDays, defaultValue: "1",
        extractPattern: #"(?:past|last)\s+(\w+)"#),
    ]
    let week = extractor.extract(from: "files from past week", slots: slots, profile: profile)
    let month = extractor.extract(from: "files from past month", slots: slots, profile: profile)
    let year = extractor.extract(from: "files from past year", slots: slots, profile: profile)
    #expect(week["DAYS"] == "7")
    #expect(month["DAYS"] == "30")
    #expect(year["DAYS"] == "365")
  }

  @Test(".relativeDays handles 'N units' phrases")
  func relativeDaysCount() {
    let slots = [
      "DAYS": SlotDefinition(type: .relativeDays, defaultValue: "1",
        extractPattern: #"(\d+\s+(?:weeks?|months?))\s+ago"#),
    ]
    let r = extractor.extract(from: "files from 3 weeks ago", slots: slots, profile: profile)
    #expect(r["DAYS"] == "21")  // 3 * 7
  }

  @Test(".commandFlag has empty entity-fallback")
  func commandFlagEmptyEntities() {
    // FLAGS slot with .commandFlag type. Query contains a filename but
    // no flag — should NOT bind the filename via entity fallback.
    let slots = [
      "FLAGS": SlotDefinition(type: .commandFlag, defaultValue: "",
        extractPattern: #"\s(-[a-zA-Z]+)\b"#),
    ]
    let r = extractor.extract(from: "copy main.swift to backup", slots: slots, profile: profile)
    #expect(r["FLAGS"] == "")  // default — main.swift not bound
  }

  @Test("Quote-stripping for path/glob/string slots (T1.8)")
  func quoteStrip() {
    let slots = [
      "PATTERN": SlotDefinition(type: .glob,
        extractPattern: #"-name\s+(\S+)"#),
    ]
    let r = extractor.extract(from: "find . -name '*.py' -type f", slots: slots, profile: profile)
    // Both leading and trailing single quotes stripped.
    #expect(r["PATTERN"] == "*.py")
  }

  @Test("Multi-source slot collects all matches (T2.1)")
  func multiSourceExtraction() {
    let slots = [
      "SOURCES": SlotDefinition(type: .path,
        extractPattern: #"copy\s+(\S+\.\S+)|(?:and|,)\s+(\S+\.\S+)"#,
        multi: true),
    ]
    let r = extractor.extract(
      from: "copy a.txt and b.txt to dst",
      slots: slots, profile: profile
    )
    #expect(r["SOURCES"] == "a.txt b.txt")
  }
}
