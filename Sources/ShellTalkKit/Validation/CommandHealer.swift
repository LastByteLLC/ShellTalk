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

    // Timeout distinct from network: "timed out" / "timeout" / "deadline exceeded".
    // Caught BEFORE networkError to avoid mis-classifying curl's (28) timeout
    // as a DNS/connection issue.
    if lower.contains("timed out") || lower.contains("timeout")
      || lower.contains("deadline exceeded") {
      return .timeout
    }

    if lower.contains("could not resolve host") || lower.contains("connection refused")
      || lower.contains("network is unreachable") {
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

    // Typo correction: find nearest command by Damerau-Levenshtein distance.
    // Only suggest if distance <= 2 and the typo is a reasonable length
    // (short tokens match too many things).
    if cmdName.count >= 3, let correction = nearestInstalledCommand(to: cmdName) {
      let healed = original.replacingOccurrences(of: cmdName, with: correction)
      return HealResult(
        healed: true, command: healed, category: .commandNotFound,
        explanation: "'\(cmdName)' not found — did you mean '\(correction)'?"
      )
    }

    return HealResult(
      healed: false, command: original, category: .commandNotFound,
      explanation: "'\(cmdName)' is not installed. Install it or use an alternative."
    )
  }

  /// Find the installed command closest to the given typo, if within edit
  /// distance 2. Tiebreak (in priority order, deterministic):
  ///   1. smaller edit distance
  ///   2. commands NOT prefixed with `g` (GNU overrides like `gtr`, `gsed`
  ///      are aliases for BSD counterparts — real user intent is the
  ///      un-prefixed form)
  ///   3. shorter command name (short typos usually target short commands)
  ///   4. alphabetical order
  /// The Set iteration order of availableCommands is non-deterministic per
  /// F1 in FINDINGS.md; the alphabetical tiebreak makes this method stable.
  private func nearestInstalledCommand(to typo: String) -> String? {
    let maxDistance = typo.count <= 4 ? 1 : 2
    struct Candidate {
      let command: String
      let distance: Int
      let isGnuPrefix: Bool   // true for "gsed", "gawk" etc. — deprioritized
    }
    var candidates: [Candidate] = []
    for cmd in profile.availableCommands {
      if abs(cmd.count - typo.count) > maxDistance { continue }
      let d = editDistance(typo, cmd)
      if d > maxDistance { continue }
      let isGnu = cmd.count >= 4 && cmd.hasPrefix("g")
        && profile.availableCommands.contains(String(cmd.dropFirst()))
      candidates.append(Candidate(command: cmd, distance: d, isGnuPrefix: isGnu))
    }
    // Sort by the priority tuple; first element wins.
    candidates.sort { a, b in
      if a.distance != b.distance { return a.distance < b.distance }
      if a.isGnuPrefix != b.isGnuPrefix { return !a.isGnuPrefix }
      if a.command.count != b.command.count { return a.command.count < b.command.count }
      return a.command < b.command
    }
    return candidates.first?.command
  }

  /// Damerau-Levenshtein distance (handles adjacent transpositions as one
  /// edit — most common typo pattern). Mirrors the implementation in
  /// `IntentMatcher.editDistance`.
  private func editDistance(_ a: String, _ b: String) -> Int {
    let m = a.count, n = b.count
    if m == 0 { return n }
    if n == 0 { return m }
    let aChars = Array(a)
    let bChars = Array(b)
    var d = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    for i in 0...m { d[i][0] = i }
    for j in 0...n { d[0][j] = j }
    for i in 1...m {
      for j in 1...n {
        let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
        d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
        if i > 1 && j > 1
          && aChars[i - 1] == bChars[j - 2]
          && aChars[i - 2] == bChars[j - 1]
        {
          d[i][j] = min(d[i][j], d[i - 2][j - 2] + cost)
        }
      }
    }
    return d[m][n]
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

    let cmdName = original.split(separator: " ").first.map(String.init) ?? ""

    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
         let match = regex.firstMatch(in: stderr, range: NSRange(stderr.startIndex..., in: stderr)),
         match.numberOfRanges > 1,
         let range = Range(match.range(at: 1), in: stderr) {
        let badFlag = String(stderr[range])

        // T1.4: try long→short flag mapping for the offending command
        // before falling back to flag removal. macOS BSD utilities
        // typically don't support GNU-style long options.
        if let shortForm = Self.longToShortFlag(command: cmdName, longFlag: badFlag) {
          // Replace --longflag (or --longflag=val) with -shortform
          let healed = replaceLongFlag(in: original, longFlag: badFlag, shortForm: shortForm)
          if healed != original {
            return HealResult(
              healed: true, command: healed, category: .flagUnknown,
              explanation: "Replaced unsupported '\(badFlag)' with short form '\(shortForm)' for \(cmdName)."
            )
          }
        }

        // Normalize badFlag: regex may capture with leading dashes
        // ("--foo") or without ("v" from BSD's "illegal option -- v").
        let bare: String
        if badFlag.hasPrefix("--") { bare = String(badFlag.dropFirst(2)) }
        else if badFlag.hasPrefix("-") { bare = String(badFlag.dropFirst()) }
        else { bare = badFlag }
        let stripped = original.replacingOccurrences(of: " --\(bare)", with: "")
          .replacingOccurrences(of: " -\(bare)", with: "")
        if stripped != original {
          return HealResult(healed: true, command: stripped, category: .flagUnknown,
                            explanation: "Removed unsupported flag: --\(bare)")
        }
      }
    }

    return HealResult(healed: false, command: original, category: .flagUnknown,
                      explanation: "Unknown flag. Check command help: \(cmdName) --help")
  }

  /// Map a long-form flag to its conventional BSD short form for known
  /// commands. Returns nil if no mapping exists. Returns the short form
  /// WITHOUT the leading dash.
  private static func longToShortFlag(command: String, longFlag: String) -> String? {
    // Normalize: strip leading dashes from longFlag if present.
    let lf: String
    if longFlag.hasPrefix("--") { lf = String(longFlag.dropFirst(2)) }
    else if longFlag.hasPrefix("-") { lf = String(longFlag.dropFirst()) }
    else { lf = longFlag }
    let key = "\(command):\(lf.lowercased())"
    return commonLongShortMap[key]
  }

  /// Curated long→short flag mapping for common BSD command quirks. Each
  /// key is `command:longflag` (lowercased, no dashes). Value is the
  /// short form without dashes. Limited to high-confidence equivalents.
  private static let commonLongShortMap: [String: String] = [
    "ls:verbose":         "l",      // ls --verbose ≈ ls -l (closest BSD)
    "ls:long":            "l",
    "ls:all":             "a",
    "ls:human-readable":  "h",
    "ls:reverse":         "r",
    "grep:invert-match":  "v",
    "grep:line-number":   "n",
    "grep:recursive":     "r",
    "grep:ignore-case":   "i",
    "grep:count":         "c",
    "grep:files-with-matches": "l",
    "tail:lines":         "n",
    "tail:follow":        "f",
    "tail:bytes":         "c",
    "head:lines":         "n",
    "head:bytes":         "c",
    "wc:lines":           "l",
    "wc:words":           "w",
    "wc:bytes":           "c",
    "wc:chars":           "m",
    "sort:reverse":       "r",
    "sort:numeric-sort":  "n",
    "sort:unique":        "u",
    "cp:recursive":       "R",
    "cp:verbose":         "v",
    "cp:force":           "f",
    "rm:recursive":       "r",
    "rm:force":           "f",
    "rm:verbose":         "v",
    "mv:verbose":         "v",
    "mv:force":           "f",
    "du:human-readable":  "h",
    "du:summarize":       "s",
    "df:human-readable":  "h",
  ]

  /// Replace a long flag (with optional `=value`) by its short equivalent.
  /// Converts `--lines=20` → `-n 20` (space separator — the BSD form).
  private func replaceLongFlag(in command: String, longFlag: String, shortForm: String) -> String {
    let lf: String
    if longFlag.hasPrefix("--") { lf = String(longFlag.dropFirst(2)) }
    else if longFlag.hasPrefix("-") { lf = String(longFlag.dropFirst()) }
    else { lf = longFlag }

    // Match "--longflag=value" first (with value); convert to "-X value".
    let escaped = NSRegularExpression.escapedPattern(for: lf)
    if let regexEq = try? NSRegularExpression(pattern: "--\(escaped)=(\\S+)") {
      let nsRange = NSRange(command.startIndex..., in: command)
      let withValueReplaced = regexEq.stringByReplacingMatches(
        in: command, range: nsRange, withTemplate: "-\(shortForm) $1"
      )
      if withValueReplaced != command { return withValueReplaced }
    }

    // Match bare "--longflag" (no value).
    guard let regex = try? NSRegularExpression(
      pattern: "--\(escaped)\\b"
    ) else { return command }
    let nsRange = NSRange(command.startIndex..., in: command)
    return regex.stringByReplacingMatches(
      in: command, range: nsRange, withTemplate: "-\(shortForm)"
    )
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
