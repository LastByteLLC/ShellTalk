import Testing
@testable import ShellTalkKit

@Suite("CommandHealer")
struct CommandHealerTests {

  @Test("Classifies command not found")
  func classifyCommandNotFound() {
    let healer = makeHealer(os: .macOS)
    let cat = healer.classifyError(
      stderr: "zsh: command not found: wget", exitCode: 127
    )
    #expect(cat == .commandNotFound)
  }

  @Test("Classifies BSD/GNU mismatch for sed")
  func classifyBsdGnuSed() {
    let healer = makeHealer(os: .macOS)
    let cat = healer.classifyError(
      stderr: "sed: 1: \"s/old/new/g\": invalid command code s", exitCode: 1
    )
    #expect(cat == .bsdGnuMismatch)
  }

  @Test("Classifies file not found")
  func classifyFileNotFound() {
    let healer = makeHealer(os: .macOS)
    let cat = healer.classifyError(
      stderr: "cat: nonexistent.txt: No such file or directory", exitCode: 1
    )
    #expect(cat == .fileNotFound)
  }

  @Test("Classifies permission denied")
  func classifyPermissionDenied() {
    let healer = makeHealer(os: .macOS)
    let cat = healer.classifyError(
      stderr: "bash: /etc/shadow: Permission denied", exitCode: 1
    )
    #expect(cat == .permissionDenied)
  }

  @Test("Heals missing command with alternative")
  func healsMissingCommand() {
    let profile = makeMockProfile(os: .macOS, missing: ["wget": "curl -LO"])
    let healer = CommandHealer(profile: profile)
    let result = healer.heal(
      original: "wget https://example.com/file.tar.gz",
      result: ShellResult(stdout: "", stderr: "command not found: wget", exitCode: 127)
    )
    #expect(result.healed)
    #expect(result.command.contains("curl -LO"))
  }

  @Test("Heals BSD sed -i on macOS")
  func healsSedInplace() {
    let profile = makeMockProfile(os: .macOS)
    let healer = CommandHealer(profile: profile)
    let result = healer.heal(
      original: "sed -i 's/old/new/g' file.txt",
      result: ShellResult(stdout: "", stderr: "sed: 1: invalid command code s", exitCode: 1)
    )
    #expect(result.healed)
    #expect(result.command.contains("-i ''"))
  }

  @Test("Heals stat -c on macOS to -f")
  func healsStatFlag() {
    let profile = makeMockProfile(os: .macOS)
    let healer = CommandHealer(profile: profile)
    let result = healer.heal(
      original: "stat -c '%s' file.txt",
      result: ShellResult(stdout: "", stderr: "stat: illegal option -- c", exitCode: 1)
    )
    #expect(result.healed)
    #expect(result.command.contains("stat -f"))
  }

  @Test("Does not add sudo for permission denied")
  func noSudoForPermissionDenied() {
    let healer = makeHealer(os: .macOS)
    let result = healer.heal(
      original: "cat /etc/shadow",
      result: ShellResult(stdout: "", stderr: "Permission denied", exitCode: 1)
    )
    #expect(!result.healed)
    #expect(!result.command.contains("sudo"))
  }

  @Test("Uses GNU override when available")
  func usesGnuOverride() {
    let profile = makeMockProfile(os: .macOS, gnuOverrides: ["sed": "gsed"])
    let healer = CommandHealer(profile: profile)
    let result = healer.heal(
      original: "sed -r 's/pattern/replace/' file",
      result: ShellResult(stdout: "", stderr: "sed: illegal option -- r", exitCode: 1)
    )
    #expect(result.healed)
    #expect(result.command.contains("gsed"))
  }

  // MARK: - Helpers

  private func makeHealer(os: OS) -> CommandHealer {
    CommandHealer(profile: makeMockProfile(os: os))
  }

  private func makeMockProfile(
    os: OS,
    missing: [String: String] = [:],
    gnuOverrides: [String: String] = [:]
  ) -> SystemProfile {
    SystemProfile(
      os: os,
      arch: "arm64",
      osVersion: "1.0",
      shell: .zsh,
      packageManager: os == .macOS ? .brew : .apt,
      availableCommands: ["sed", "grep", "find", "stat", "curl"],
      commandPaths: [:],
      commandVersions: [:],
      gnuOverrides: gnuOverrides,
      missingAlternatives: missing
    )
  }
}
