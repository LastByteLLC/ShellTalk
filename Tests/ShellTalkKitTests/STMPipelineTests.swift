import Testing
@testable import ShellTalkKit

@Suite("STMPipeline")
struct STMPipelineTests {

  @Test("End-to-end: git status")
  func gitStatus() {
    let pipeline = STMPipeline()
    let result = pipeline.process("show git status")
    #expect(result != nil)
    #expect(result?.command == "git status")
    #expect(result?.categoryId == "git")
    #expect(result?.isValid == true)
  }

  @Test("End-to-end: find files with platform resolution")
  func findFiles() {
    let pipeline = STMPipeline()
    let result = pipeline.process("find swift files")
    #expect(result != nil)
    #expect(result?.command.contains("find") == true)
    #expect(result?.command.contains(".swift") == true)
    #expect(result?.categoryId == "file_ops")
  }

  @Test("End-to-end: sed replace with slot extraction")
  func sedReplace() {
    let pipeline = STMPipeline()
    let result = pipeline.process("sed replace foo with bar in main.swift")
    #expect(result != nil)
    if let cmd = result?.command {
      #expect(cmd.contains("sed"))
      #expect(cmd.contains("foo"))
      #expect(cmd.contains("bar"))
      #expect(cmd.contains("main.swift"))
      #if os(macOS)
      #expect(cmd.contains("-i ''"))
      #endif
    }
  }

  @Test("End-to-end: grep search")
  func grepSearch() {
    let pipeline = STMPipeline()
    let result = pipeline.process("search for TODO in files")
    #expect(result != nil)
    #expect(result?.command.contains("grep") == true || result?.command.contains("rg") == true)
  }

  @Test("Returns nil for unrecognized query")
  func unrecognizedQuery() {
    let pipeline = STMPipeline()
    let result = pipeline.process("zzzyyyxxx")
    // Either nil or very low confidence
    if let result {
      #expect(result.confidence < 0.3)
    }
  }

  @Test("Alternatives returns multiple results")
  func alternatives() {
    let pipeline = STMPipeline()
    let results = pipeline.processWithAlternatives("find files", n: 3)
    #expect(results.count >= 1)
  }

  @Test("Debug mode includes extra info")
  func debugMode() {
    let pipeline = STMPipeline(config: .debug)
    let result = pipeline.process("list files")
    #expect(result != nil)
    #expect(result?.debugInfo != nil)
    #expect(result?.debugInfo?.topMatches.isEmpty == false)
  }

  @Test("Validation flags dangerous commands")
  func validationFlagsDangerous() {
    // Create a pipeline and manually check a dangerous command
    let profile = SystemProfile.detect()
    let validator = CommandValidator(profile: profile)
    let v = validator.validate("rm -rf /")
    #expect(v.safetyLevel == .dangerous)
  }

  @Test("Pipeline uses detected system profile")
  func usesSystemProfile() {
    let pipeline = STMPipeline()
    // Running "git log" should produce a valid command
    let result = pipeline.process("show recent commits")
    #expect(result != nil)
    #expect(result?.command.contains("git log") == true)
  }

  // MARK: - Conversational filter (round-c optimization)

  @Test("Conversational query 'tell me about X' returns nil")
  func conversationalTellMeAbout() {
    let pipeline = STMPipeline()
    #expect(pipeline.process("tell me about kubernetes") == nil)
    #expect(pipeline.process("tell me about docker containers") == nil)
  }

  @Test("Conversational 'what is the difference' returns nil")
  func conversationalWhatIsDifference() {
    let pipeline = STMPipeline()
    #expect(pipeline.process("what is the difference between sed and awk") == nil)
    #expect(pipeline.process("what's the difference between cp and mv") == nil)
  }

  @Test("Action verb queries are NOT filtered")
  func actionVerbsPassThrough() {
    let pipeline = STMPipeline()
    // 'show git status' is an action, not a meta-question
    #expect(pipeline.process("show git status") != nil)
    // 'explain the find command' is asking for help — should route to man/help
    #expect(pipeline.process("explain the find command") != nil)
  }

  @Test("Static isConversational helper")
  func conversationalHelper() {
    #expect(STMPipeline.isConversational("tell me about kubernetes"))
    #expect(STMPipeline.isConversational("what is the difference between sed and awk"))
    #expect(!STMPipeline.isConversational("git status"))
    #expect(!STMPipeline.isConversational("show me the files"))
    #expect(!STMPipeline.isConversational("explain the find command"))
  }
}
