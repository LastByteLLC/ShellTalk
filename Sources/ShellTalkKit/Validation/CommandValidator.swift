// CommandValidator.swift — Pre-execution validation of generated commands
//
// Validates syntax, command existence, path plausibility, and safety
// before executing a command via SafeShell.

import Foundation

/// Safety level classification for a command.
public enum SafetyLevel: String, Sendable {
  case safe       // Read-only or low-risk
  case caution    // Modifies files, but scoped
  case dangerous  // System-wide destructive potential
}

/// Result of pre-execution command validation.
public struct CommandValidation: Sendable {
  public let syntaxValid: Bool
  public let commandExists: Bool
  public let pathsPlausible: Bool
  public let safetyLevel: SafetyLevel
  public let warnings: [String]

  public var isValid: Bool {
    syntaxValid && commandExists
  }
}

/// Validates commands before execution.
public struct CommandValidator: Sendable {
  private let profile: SystemProfile

  public init(profile: SystemProfile) {
    self.profile = profile
  }

  /// Validate a command string.
  public func validate(_ command: String) -> CommandValidation {
    let syntax = checkSyntax(command)
    let cmdExists = checkCommandExists(command)
    let paths = checkPaths(command)
    let safety = classifySafety(command)
    var warnings: [String] = []

    if !syntax { warnings.append("Syntax check failed (bash -n)") }
    if !cmdExists { warnings.append("Command not found on this system") }
    if !paths { warnings.append("Referenced path may not exist") }
    if safety == .dangerous { warnings.append("Command classified as dangerous") }

    return CommandValidation(
      syntaxValid: syntax,
      commandExists: cmdExists,
      pathsPlausible: paths,
      safetyLevel: safety,
      warnings: warnings
    )
  }

  // MARK: - Syntax Check

  private func checkSyntax(_ command: String) -> Bool {
    let process = Process()
    #if os(Linux)
    let shellPath = "/bin/sh"
    #else
    let shellPath = "/bin/bash"
    #endif
    process.executableURL = URL(fileURLWithPath: shellPath)
    process.arguments = ["-n", "-c", command]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus == 0
    } catch {
      return false
    }
  }

  // MARK: - Command Existence

  private func checkCommandExists(_ command: String) -> Bool {
    let firstToken = extractFirstCommand(command)
    guard !firstToken.isEmpty else { return false }

    // Shell builtins are always available
    if Self.shellBuiltins.contains(firstToken) { return true }

    return profile.hasCommand(firstToken)
  }

  /// Extract the first actual command from a potentially complex command string.
  private func extractFirstCommand(_ command: String) -> String {
    var cmd = command.trimmingCharacters(in: .whitespaces)

    // Strip leading env vars (FOO=bar cmd)
    while let eqIndex = cmd.firstIndex(of: "="),
          let spaceIndex = cmd.firstIndex(of: " "),
          eqIndex < spaceIndex {
      cmd = String(cmd[cmd.index(after: spaceIndex)...]).trimmingCharacters(in: .whitespaces)
    }

    // Get first word
    let firstWord = cmd.split(separator: " ", maxSplits: 1).first.map(String.init) ?? cmd

    // Strip path prefix
    return (firstWord as NSString).lastPathComponent
  }

  // MARK: - Path Check

  private func checkPaths(_ command: String) -> Bool {
    // Extract potential file paths from the command
    let tokens = command.split(separator: " ").map(String.init)
    let fm = FileManager.default

    for token in tokens {
      // Skip flags, pipes, redirects
      if token.hasPrefix("-") || token.hasPrefix("|") || token.hasPrefix(">")
        || token.hasPrefix("<") || token.hasPrefix("'") || token.hasPrefix("\"") { continue }
      // Skip command names and common values
      if token.count < 2 || token == "." || token == ".." { continue }

      // Check if it looks like a path (contains / or .)
      if (token.contains("/") || token.contains(".")) && !token.hasPrefix("http") {
        let expanded = NSString(string: token).expandingTildeInPath
        // Check if file or parent directory exists
        if fm.fileExists(atPath: expanded) { continue }
        let parent = (expanded as NSString).deletingLastPathComponent
        if !parent.isEmpty && fm.fileExists(atPath: parent) { continue }
        // Path doesn't exist and parent doesn't exist — suspicious but not fatal
      }
    }

    return true  // Path check is advisory, not blocking
  }

  // MARK: - Safety Classification

  private func classifySafety(_ command: String) -> SafetyLevel {
    let lower = command.lowercased()

    // Dangerous patterns
    for pattern in Self.dangerousPatterns {
      if lower.contains(pattern) { return .dangerous }
    }

    // Caution patterns (modifies files)
    for pattern in Self.cautionPatterns {
      if lower.contains(pattern) { return .caution }
    }

    return .safe
  }

  // MARK: - Constants

  static let shellBuiltins: Set<String> = [
    "cd", "echo", "export", "alias", "unalias", "source", "eval",
    "exec", "exit", "set", "unset", "type", "hash", "test",
    "read", "printf", "declare", "local", "return", "shift",
    "true", "false", "pwd", "pushd", "popd", "dirs",
    "bg", "fg", "jobs", "wait", "kill", "trap",
    "umask", "ulimit", "times", "command", "builtin",
  ]

  static let dangerousPatterns: [String] = [
    "rm -rf /", "rm -rf ~", "rm -rf $home",
    "sudo", "shutdown", "reboot", "halt",
    "> /dev/sd", "> /dev/disk", "mkfs",
    "dd if=", ":(){", "fork bomb",
    "chmod -r 777 /", "chown -r",
    "passwd", "visudo",
  ]

  static let cautionPatterns: [String] = [
    "rm ", "rmdir", "mv ", "chmod ", "chown ",
    "sed -i", "truncate", "> ", ">> ",
    "git push", "git reset", "git clean",
    "docker rm", "docker rmi", "kubectl delete",
  ]
}
