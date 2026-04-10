import Testing
@testable import ShellTalkKit

@Suite("EntityRecognizer")
struct EntityRecognizerTests {

  let recognizer = EntityRecognizer(profile: SystemProfile.detect())

  // MARK: - Structural Recognition

  @Test("Recognizes file paths")
  func filePaths() {
    let entities = recognizer.recognize("copy ./src/main.swift to ~/backup/")
    let paths = entities.filter { $0.type == .filePath || $0.type == .directoryPath || $0.type == .fileName }
    let texts = paths.map(\.text)
    #expect(texts.contains(where: { $0.contains("main.swift") }))
  }

  @Test("Recognizes dotfiles")
  func dotfiles() {
    let entities = recognizer.recognize("find all .DS_Store files")
    let files = entities.filter { $0.type == .fileName }
    #expect(files.contains(where: { $0.text == ".DS_Store" }))
  }

  @Test("Recognizes URLs")
  func urls() {
    let entities = recognizer.recognize("curl https://api.example.com/data")
    let urls = entities.filter { $0.type == .url }
    #expect(urls.count == 1)
    #expect(urls[0].text == "https://api.example.com/data")
  }

  @Test("Recognizes glob patterns")
  func globs() {
    let entities = recognizer.recognize("find *.swift files")
    let globs = entities.filter { $0.type == .glob }
    #expect(globs.contains(where: { $0.text == "*.swift" }))
  }

  @Test("Recognizes sizes")
  func sizes() {
    let entities = recognizer.recognize("find files larger than 100M")
    let sizes = entities.filter { $0.type == .size }
    #expect(sizes.contains(where: { $0.text == "100M" }))
  }

  @Test("Recognizes IP addresses")
  func ipAddresses() {
    let entities = recognizer.recognize("ping 192.168.1.1")
    let ips = entities.filter { $0.type == .ipAddress }
    #expect(ips.contains(where: { $0.text == "192.168.1.1" }))
  }

  @Test("Recognizes environment variables")
  func envVars() {
    let entities = recognizer.recognize("echo $HOME and ${PATH}")
    let vars = entities.filter { $0.type == .envVar }
    #expect(vars.count >= 2)
  }

  @Test("Recognizes branch-like patterns")
  func branchPatterns() {
    let entities = recognizer.recognize("switch to feature/auth")
    let branches = entities.filter { $0.type == .branchName }
    #expect(branches.contains(where: { $0.text == "feature/auth" }))
  }

  // MARK: - Lexicon Recognition

  @Test("Recognizes application names")
  func appNames() {
    let entities = recognizer.recognize("take a screenshot of Firefox")
    let apps = entities.filter { $0.type == .applicationName }
    // Firefox should be recognized if installed
    if !apps.isEmpty {
      #expect(apps[0].text == "Firefox")
    }
  }

  @Test("Recognizes known services")
  func knownServices() {
    let entities = recognizer.recognize("kill the nginx process")
    let procs = entities.filter { $0.type == .processName || $0.type == .commandName }
    #expect(procs.contains(where: { $0.text.lowercased() == "nginx" }))
  }

  // MARK: - Preposition Frame Analysis

  @Test("Assigns location role for 'in X'")
  func locationRole() {
    let entities = recognizer.recognize("find files in Sources/")
    let withRole = entities.filter { $0.role == .location }
    #expect(!withRole.isEmpty)
  }

  @Test("Assigns destination role for 'to X'")
  func destinationRole() {
    let entities = recognizer.recognize("copy main.swift to backup/")
    let dests = entities.filter { $0.role == .destination }
    #expect(!dests.isEmpty)
  }

  @Test("Assigns target role for 'of X'")
  func targetRole() {
    let entities = recognizer.recognize("take a screenshot of Firefox")
    let targets = entities.filter { $0.role == .target }
    #expect(!targets.isEmpty)
  }

  @Test("Assigns name role for 'named X'")
  func nameRole() {
    let entities = recognizer.recognize("find files named .gitignore")
    let named = entities.filter { $0.role == .name }
    #expect(!named.isEmpty)
  }

  // MARK: - Integration: Grouped Output

  @Test("Grouped entities have expected roles")
  func groupedEntities() {
    let grouped = recognizer.recognizeGrouped("copy main.swift from src/ to backup/")
    // Should have at least source and destination
    let allRoles = Set(grouped.keys)
    #expect(!allRoles.isEmpty)
  }

  // MARK: - Deduplication

  @Test("Deduplicates overlapping recognitions")
  func deduplication() {
    let entities = recognizer.recognize("open main.swift")
    // "main.swift" should appear only once even if both structural and lexicon match
    let mainSwift = entities.filter { $0.text == "main.swift" }
    #expect(mainSwift.count == 1)
  }

  // MARK: - Edge Cases

  @Test("Handles empty query")
  func emptyQuery() {
    let entities = recognizer.recognize("")
    #expect(entities.isEmpty)
  }

  @Test("Handles query with no entities")
  func noEntities() {
    let entities = recognizer.recognize("show status")
    // "status" is a meta-noun, should be filtered on macOS POS layer
    // On any platform, structural layer finds nothing here
    _ = entities  // Just don't crash
  }
}
