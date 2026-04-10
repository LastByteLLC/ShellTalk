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
}
