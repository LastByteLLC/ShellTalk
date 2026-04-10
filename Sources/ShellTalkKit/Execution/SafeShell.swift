// SafeShell.swift — Sandboxed shell execution with safety checks
//
// Executes commands with timeout support, output capture, and
// dangerous command blocking. Cross-platform (macOS + Linux).

import Foundation

/// Result of a shell command execution.
public struct ShellResult: Sendable {
  public let stdout: String
  public let stderr: String
  public let exitCode: Int32

  public init(stdout: String, stderr: String, exitCode: Int32) {
    self.stdout = stdout
    self.stderr = stderr
    self.exitCode = exitCode
  }

  /// Whether the command succeeded (exit code 0).
  public var succeeded: Bool { exitCode == 0 }

  /// Formatted output for display, truncated to maxChars.
  public func formatted(maxChars: Int = 2000) -> String {
    var output = stdout
    if !stderr.isEmpty {
      output += (output.isEmpty ? "" : "\n") + "STDERR: \(stderr)"
    }
    if exitCode != 0 {
      output += "\n[exit code: \(exitCode)]"
    }
    if output.isEmpty { return "(no output)" }
    if output.count > maxChars {
      return String(output.prefix(maxChars)) + "\n... (truncated)"
    }
    return output
  }
}

/// Errors from shell execution.
public enum ShellError: Error, Sendable {
  case blocked(String)
  case timeout(seconds: Int)
  case executionFailed(String)
}

/// Safe shell executor with dangerous command blocking and timeout support.
public struct SafeShell: Sendable {
  public let workingDirectory: String
  public let defaultTimeout: TimeInterval

  public init(workingDirectory: String = ".", defaultTimeout: TimeInterval = 30) {
    self.workingDirectory = workingDirectory
    self.defaultTimeout = defaultTimeout
  }

  /// Execute a shell command with safety checks and timeout.
  public func execute(_ command: String, timeout: TimeInterval? = nil) throws -> ShellResult {
    // Safety check
    let lower = command.lowercased()
    for pattern in Self.blockedPatterns {
      if lower.contains(pattern) {
        throw ShellError.blocked(pattern)
      }
    }

    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: Self.shellPath)
    process.arguments = ["-c", command]
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

    do {
      try process.run()
    } catch {
      throw ShellError.executionFailed(error.localizedDescription)
    }

    // Timeout handling
    let effectiveTimeout = timeout ?? defaultTimeout
    let deadline = Date().addingTimeInterval(effectiveTimeout)

    while process.isRunning && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.05)
    }

    if process.isRunning {
      process.terminate()
      throw ShellError.timeout(seconds: Int(effectiveTimeout))
    }

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    return ShellResult(
      stdout: String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? "",
      stderr: String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? "",
      exitCode: process.terminationStatus
    )
  }

  /// Shell path — use /bin/sh on Linux for maximum portability, /bin/bash on macOS.
  static let shellPath: String = {
    #if os(Linux)
    // /bin/sh exists on all POSIX systems; bash may not be installed (e.g., Alpine)
    return "/bin/sh"
    #else
    return "/bin/bash"
    #endif
  }()

  static let blockedPatterns: [String] = [
    "rm -rf /", "rm -rf ~", "rm -rf $home",
    "sudo", "shutdown", "reboot", "halt",
    "> /dev/sd", "> /dev/disk", "mkfs",
    "dd if=", ":(){",
    "chmod -r 777 /",
    "passwd", "visudo",
  ]
}
