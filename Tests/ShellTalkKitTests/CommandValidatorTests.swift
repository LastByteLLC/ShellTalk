import Testing
@testable import ShellTalkKit

@Suite("CommandValidator")
struct CommandValidatorTests {

  let validator = CommandValidator(profile: SystemProfile.detect())

  @Test("Valid simple command")
  func validSimpleCommand() {
    let result = validator.validate("ls -la")
    #expect(result.syntaxValid)
    #expect(result.commandExists)
    #expect(result.safetyLevel == .safe)
    #expect(result.isValid)
  }

  @Test("Syntax check catches bad syntax")
  func badSyntax() {
    let result = validator.validate("if then fi")
    #expect(!result.syntaxValid)
  }

  @Test("Command existence check")
  func commandExists() {
    let result = validator.validate("nonexistentcommand123 --flag")
    #expect(!result.commandExists)
    #expect(!result.isValid)
  }

  @Test("Git command is recognized")
  func gitCommand() {
    let result = validator.validate("git status")
    #expect(result.commandExists)
    #expect(result.safetyLevel == .safe)
  }

  @Test("rm is classified as caution")
  func rmCaution() {
    let result = validator.validate("rm file.txt")
    #expect(result.safetyLevel == .caution)
  }

  @Test("rm -rf / is dangerous")
  func rmRfDangerous() {
    let result = validator.validate("rm -rf /")
    #expect(result.safetyLevel == .dangerous)
  }

  @Test("sudo is dangerous")
  func sudoDangerous() {
    let result = validator.validate("sudo apt-get install foo")
    #expect(result.safetyLevel == .dangerous)
  }

  @Test("grep is safe")
  func grepSafe() {
    let result = validator.validate("grep -rn 'TODO' .")
    #expect(result.safetyLevel == .safe)
  }

  @Test("sed -i is caution")
  func sedInplaceCaution() {
    let result = validator.validate("sed -i '' 's/old/new/g' file.txt")
    #expect(result.safetyLevel == .caution)
  }

  @Test("Shell builtins are recognized")
  func shellBuiltins() {
    let result = validator.validate("echo hello world")
    #expect(result.commandExists)
  }

  @Test("Pipe commands check first command")
  func pipeCommand() {
    let result = validator.validate("find . -name '*.swift' | wc -l")
    #expect(result.commandExists)
    #expect(result.syntaxValid)
  }
}
