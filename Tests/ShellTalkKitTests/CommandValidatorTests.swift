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

  // MARK: - isTriviallyValidSyntax fast-path invariant
  //
  // These tests pin down the safety invariant: the fast path returns
  // `true` only when bash -n would also return 0. We assert that every
  // case accepted by the fast path also passes a live `bash -n` subprocess
  // (matching semantics), and every case rejected by the fast path is
  // either also rejected by bash or legitimately complex (deferred).

  private static let fastPathAccepts: [String] = [
    "ls",
    "ls -la",
    "git status",
    "find . -type f",
    "find . -name '*.swift' -type f",
    "grep -rn 'TODO' .",
    "echo \"hello world\"",
    "du -sh *",
    "chmod +x script.sh",
    "cat a.txt | grep pattern",
    "ls && pwd",
    "ls || true",
    "cat a.txt > b.txt",
    "echo $HOME",
    "echo ${HOME}",
    "echo \"${HOME}\"",
    "find . -exec rm {} +",
    "tar -xzf archive.tar.gz",
    "sed -i '' 's/old/new/g' file.txt",
    "curl -s -X POST -H 'Content-Type: application/json' -d '{\"a\":1}' 'https://x.y/z'",
    "rm -rf /tmp/foo",
  ]

  private static let fastPathFallsThrough: [String] = [
    "echo $(date)",                    // $(...) command substitution
    "echo `date`",                      // backtick substitution
    "(cd dir && ls)",                   // subshell
    "cat <<EOF\nhi\nEOF",                // here-doc + newline
    "cmd |",                            // trailing pipe
    "cmd &&",                           // trailing logical op
    "cmd \\",                           // trailing backslash
    "echo \"foo",                       // unbalanced double quote
    "echo 'foo",                        // unbalanced single quote
    "echo ${foo",                       // unclosed ${...}
  ]

  @Test("Fast-path accepts simple commands", arguments: fastPathAccepts)
  func fastPathAcceptsSimple(cmd: String) {
    #expect(CommandValidator.isTriviallyValidSyntax(cmd))
  }

  @Test("Fast-path falls through on complex or invalid commands",
        arguments: fastPathFallsThrough)
  func fastPathFallsThroughOnComplex(cmd: String) {
    #expect(!CommandValidator.isTriviallyValidSyntax(cmd))
  }

  #if !os(WASI) && !os(Linux)
  /// Invariant check: every fast-path acceptance must also be accepted
  /// by the real bash. If this ever regresses, the fast path has a
  /// false-positive and validity guarantees have been broken.
  @Test("Invariant: fast-path accept ⇒ bash -n accepts", arguments: fastPathAccepts)
  func fastPathAcceptMatchesBashN(cmd: String) {
    #expect(runBashN(cmd) == 0, "bash -n rejected a fast-path acceptance: \(cmd)")
  }

  private func runBashN(_ command: String) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = ["-n", "-c", command]
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do {
      try p.run()
      p.waitUntilExit()
      return p.terminationStatus
    } catch {
      return -1
    }
  }
  #endif
}
