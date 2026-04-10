// CommandHealer.swift — Deterministic self-healing for failed commands
//
// Analyzes stderr output to classify errors and apply deterministic fixes.
// No LLM in the loop — all healing is rule-based for speed and portability.

import Foundation

/// Categories of command errors, derived from stderr analysis.
public enum ErrorCategory: String, Sendable {
  case commandNotFound
  case flagUnknown
  case fileNotFound
  case permissionDenied
  case syntaxError
  case bsdGnuMismatch
  case networkError
  case timeout
  case other
}

/// Result of a healing attempt.
public struct HealResult: Sendable {
  public let healed: Bool
  public let command: String
  public let category: ErrorCategory
  public let explanation: String
}

/// Deterministic command healer — analyzes errors and suggests fixes.
public struct CommandHealer: Sendable {
  private let profile: SystemProfile

  public init(profile: SystemProfile) {
    self.profile = profile
  }

  /// Attempt to heal a failed command based on its error output.
  public func heal(
    original: String,
    result: ShellResult
  ) -> HealResult {
    let category = classifyError(stderr: result.stderr, exitCode: result.exitCode)

    switch category {
    case .commandNotFound:
      return healCommandNotFound(original: original, stderr: result.stderr)
    case .bsdGnuMismatch:
      return healBSDGnuMismatch(original: original, stderr: result.stderr)
    case .flagUnknown:
      return healFlagUnknown(original: original, stderr: result.stderr)
    case .fileNotFound:
      return healFileNotFound(original: original, stderr: result.stderr)
    case .permissionDenied:
      return HealResult(
        healed: false, command: original, category: category,
        explanation: "Permission denied. Check file ownership and permissions (will not add sudo)."
      )
    case .syntaxError:
      return healSyntaxError(original: original, stderr: result.stderr)
    case .networkError:
      return HealResult(
        healed: false, command: original, category: category,
        explanation: "Network error. Check connectivity and URL."
      )
    case .timeout:
      return HealResult(
        healed: false, command: original, category: category,
        explanation: "Command timed out. Consider adding a timeout flag or reducing scope."
      )
    case .other:
      return HealResult(
        healed: false, command: original, category: category,
        explanation: "Unrecognized error: \(result.stderr.prefix(200))"
      )
    }
  }

  // MARK: - Error Classification

  /// Classify a command error from stderr and exit code.
  public func classifyError(stderr: String, exitCode: Int32) -> ErrorCategory {
    let lower = stderr.lowercased()

    if lower.contains("command not found") || lower.contains("not found")
      && exitCode == 127 {
      return .commandNotFound
    }

    // BSD/GNU mismatch patterns
    if lower.contains("invalid command code") || lower.contains("illegal option")
      || lower.contains("invalid option") {
      // Distinguish BSD/GNU issues from generic flag errors
      if lower.contains("sed:") || lower.contains("stat:") || lower.contains("date:") {
        return .bsdGnuMismatch
      }
      return .flagUnknown
    }

    if lower.contains("unknown option") || lower.contains("unrecognized option")
      || lower.contains("bad option") {
      return .flagUnknown
    }

    if lower.contains("no such file") || lower.contains("cannot stat")
      || lower.contains("does not exist") {
      return .fileNotFound
    }

    if lower.contains("permission denied") || lower.contains("operation not permitted") {
      return .permissionDenied
    }

    if lower.contains("syntax error") || lower.contains("parse error")
      || lower.contains("unexpected token") {
      return .syntaxError
    }

    if lower.contains("could not resolve host") || lower.contains("connection refused")
      || lower.contains("network is unreachable") || lower.contains("timed out") {
      return .networkError
    }

    return .other
  }

  // MARK: - Healing Strategies

  private func healCommandNotFound(original: String, stderr: String) -> HealResult {
    // Extract the missing command name
    let tokens = original.split(separator: " ")
    guard let cmdName = tokens.first.map(String.init) else {
      return HealResult(healed: false, command: original, category: .commandNotFound,
                        explanation: "Could not identify the missing command.")
    }

    // Check for known alternative
    if let alternative = profile.alternative(for: cmdName) {
      let healed = original.replacingOccurrences(of: cmdName, with: alternative)
      return HealResult(
        healed: true, command: healed, category: .commandNotFound,
        explanation: "'\(cmdName)' not found. Using alternative: \(alternative)"
      )
    }

    return HealResult(
      healed: false, command: original, category: .commandNotFound,
      explanation: "'\(cmdName)' is not installed. Install it or use an alternative."
    )
  }

  private func healBSDGnuMismatch(original: String, stderr: String) -> HealResult {
    var healed = original

    // sed -i without '' on macOS
    if original.contains("sed -i '") && !original.contains("sed -i '' '"),
       profile.os == .macOS {
      healed = original.replacingOccurrences(of: "sed -i '", with: "sed -i '' '")
      return HealResult(healed: true, command: healed, category: .bsdGnuMismatch,
                        explanation: "macOS sed requires -i '' (empty string for backup suffix)")
    }

    if original.contains("sed -i \"") && !original.contains("sed -i \"\" \""),
       profile.os == .macOS {
      healed = original.replacingOccurrences(of: "sed -i \"", with: "sed -i \"\" \"")
      return HealResult(healed: true, command: healed, category: .bsdGnuMismatch,
                        explanation: "macOS sed requires -i '' (empty string for backup suffix)")
    }

    // stat -c on macOS → stat -f
    if original.contains("stat -c"), profile.os == .macOS {
      healed = original.replacingOccurrences(of: "stat -c", with: "stat -f")
      return HealResult(healed: true, command: healed, category: .bsdGnuMismatch,
                        explanation: "macOS stat uses -f (format), not -c")
    }

    // date -d on macOS → date -v (basic case)
    if original.contains("date -d"), profile.os == .macOS {
      return HealResult(healed: false, command: original, category: .bsdGnuMismatch,
                        explanation: "macOS date uses -v for relative dates, not -d. Try gdate if installed.")
    }

    // Try GNU prefixed command
    let firstToken = original.split(separator: " ").first.map(String.init) ?? ""
    if let gnuCmd = profile.gnuOverrides[firstToken] {
      healed = original.replacingOccurrences(of: firstToken, with: gnuCmd)
      return HealResult(healed: true, command: healed, category: .bsdGnuMismatch,
                        explanation: "Using GNU version: \(gnuCmd) instead of BSD \(firstToken)")
    }

    return HealResult(healed: false, command: original, category: .bsdGnuMismatch,
                      explanation: "BSD/GNU flag mismatch. Check platform-specific flags.")
  }

  private func healFlagUnknown(original: String, stderr: String) -> HealResult {
    // Try to extract the bad flag from stderr
    // Common patterns: "illegal option -- x", "unknown option: --foo"
    let patterns = [
      #"illegal option -- (\w)"#,
      #"unknown option:?\s+(-{1,2}\S+)"#,
      #"unrecognized option:?\s+(-{1,2}\S+)"#,
      #"invalid option:?\s+(-{1,2}\S+)"#,
    ]

    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
         let match = regex.firstMatch(in: stderr, range: NSRange(stderr.startIndex..., in: stderr)),
         match.numberOfRanges > 1,
         let range = Range(match.range(at: 1), in: stderr) {
        let badFlag = String(stderr[range])
        let stripped = original.replacingOccurrences(of: " -\(badFlag)", with: "")
          .replacingOccurrences(of: " --\(badFlag)", with: "")
        if stripped != original {
          return HealResult(healed: true, command: stripped, category: .flagUnknown,
                            explanation: "Removed unsupported flag: -\(badFlag)")
        }
      }
    }

    return HealResult(healed: false, command: original, category: .flagUnknown,
                      explanation: "Unknown flag. Check command help: \(original.split(separator: " ").first ?? "") --help")
  }

  private func healFileNotFound(original: String, stderr: String) -> HealResult {
    // Extract the missing path from stderr
    let patterns = [
      #"No such file or directory:\s*(\S+)"#,
      #"cannot stat '([^']+)'"#,
      #"'([^']+)': No such file"#,
    ]

    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern),
         let match = regex.firstMatch(in: stderr, range: NSRange(stderr.startIndex..., in: stderr)),
         match.numberOfRanges > 1,
         let range = Range(match.range(at: 1), in: stderr) {
        let missingPath = String(stderr[range])
        return HealResult(
          healed: false, command: original, category: .fileNotFound,
          explanation: "File not found: \(missingPath). Check the path and try: find . -name '\((missingPath as NSString).lastPathComponent)'"
        )
      }
    }

    return HealResult(healed: false, command: original, category: .fileNotFound,
                      explanation: "File or directory not found. Verify the path exists.")
  }

  private func healSyntaxError(original: String, stderr: String) -> HealResult {
    // Check for common quoting issues
    let singleQuotes = original.filter { $0 == "'" }.count
    let doubleQuotes = original.filter { $0 == "\"" }.count

    if singleQuotes % 2 != 0 {
      return HealResult(healed: false, command: original, category: .syntaxError,
                        explanation: "Unbalanced single quotes in command.")
    }
    if doubleQuotes % 2 != 0 {
      return HealResult(healed: false, command: original, category: .syntaxError,
                        explanation: "Unbalanced double quotes in command.")
    }

    return HealResult(healed: false, command: original, category: .syntaxError,
                      explanation: "Syntax error: \(stderr.prefix(200))")
  }
}
