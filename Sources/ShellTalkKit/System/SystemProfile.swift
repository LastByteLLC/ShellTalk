// SystemProfile.swift — Runtime machine discovery
//
// Detects OS, architecture, shell, package manager, available commands,
// versions, GNU overrides, and missing tool alternatives.
// Runs once at startup (~50ms), results cached for session.

import Foundation

/// Detected operating system family.
public enum OS: String, Sendable, Codable {
  case macOS, linux, freeBSD, unknown
}

/// Detected shell environment.
public enum Shell: String, Sendable, Codable {
  case zsh, bash, sh, fish, unknown
}

/// Detected package manager.
public enum PackageManager: String, Sendable, Codable {
  case brew, apt, yum, dnf, apk, port, pacman, nix, unknown
}

/// Runtime snapshot of the host machine's capabilities.
public struct SystemProfile: Sendable {
  public let os: OS
  public let arch: String
  public let osVersion: String
  public let shell: Shell
  public let packageManager: PackageManager
  public let availableCommands: Set<String>
  public let commandPaths: [String: String]
  public let commandVersions: [String: String]
  public let gnuOverrides: [String: String]
  public let missingAlternatives: [String: String]

  /// Compact description for embedding in prompts or debug output (~50 tokens).
  public var summary: String {
    let osStr = "\(os.rawValue) \(osVersion) \(arch) \(shell.rawValue)"
    let toolStr = commandVersions.sorted(by: { $0.key < $1.key })
      .prefix(10)
      .map { "\($0.key) \($0.value)" }
      .joined(separator: ", ")
    let missingStr = missingAlternatives.isEmpty ? "" :
      "\nMissing: " + missingAlternatives.map { "\($0.key)->\($0.value)" }.joined(separator: ", ")
    let gnuStr = gnuOverrides.isEmpty ? "" :
      "\nGNU: " + gnuOverrides.map { "\($0.key)->\($0.value)" }.joined(separator: ", ")
    return "\(osStr). \(toolStr)\(missingStr)\(gnuStr)"
  }

  /// Check if a command is available on this machine.
  public func hasCommand(_ name: String) -> Bool {
    availableCommands.contains(name)
  }

  /// Get the alternative for a missing command, if known.
  public func alternative(for command: String) -> String? {
    missingAlternatives[command]
  }
}

// MARK: - Detection

extension SystemProfile {

  /// Auto-detect the current machine profile.
  /// Fast path (~15ms): skips version probing. Use `detect(full:)` for versions.
  public static func detect(full: Bool = false) -> SystemProfile {
    let os = detectOS()
    let arch = run("uname", "-m") ?? "unknown"
    let osVersion = detectOSVersion(os: os)
    let shell = detectShell()
    let packageManager = detectPackageManager()
    let (commands, paths) = scanAvailableCommands()
    let gnu = detectGNUOverrides(available: commands)
    let missing = buildMissingAlternatives(available: commands, os: os)

    // Version probing is expensive (~800ms, 14 subprocess launches).
    // Only do it when explicitly requested (e.g., --profile).
    let versions = full ? probeVersions(available: commands) : [:]

    return SystemProfile(
      os: os,
      arch: arch,
      osVersion: osVersion,
      shell: shell,
      packageManager: packageManager,
      availableCommands: commands,
      commandPaths: paths,
      commandVersions: versions,
      gnuOverrides: gnu,
      missingAlternatives: missing
    )
  }

  // MARK: - OS Detection

  private static func detectOS() -> OS {
    #if os(macOS)
    return .macOS
    #elseif os(Linux)
    let uname = run("uname", "-s") ?? ""
    if uname.contains("FreeBSD") { return .freeBSD }
    return .linux
    #else
    return .unknown
    #endif
  }

  private static func detectOSVersion(os: OS) -> String {
    switch os {
    case .macOS:
      return run("sw_vers", "-productVersion") ?? "unknown"
    case .linux:
      // Try /etc/os-release
      if let content = try? String(contentsOfFile: "/etc/os-release", encoding: .utf8) {
        for line in content.split(separator: "\n") {
          if line.hasPrefix("VERSION_ID=") {
            return String(line.dropFirst(11)).replacingOccurrences(of: "\"", with: "")
          }
        }
      }
      return run("uname", "-r") ?? "unknown"
    default:
      return run("uname", "-r") ?? "unknown"
    }
  }

  // MARK: - Shell Detection

  private static func detectShell() -> Shell {
    let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"
    let name = (shellPath as NSString).lastPathComponent
    switch name {
    case "zsh": return .zsh
    case "bash": return .bash
    case "fish": return .fish
    case "sh": return .sh
    default: return .unknown
    }
  }

  // MARK: - Package Manager Detection

  private static func detectPackageManager() -> PackageManager {
    let checks: [(String, PackageManager)] = [
      ("brew", .brew),
      ("apt-get", .apt),
      ("dnf", .dnf),
      ("yum", .yum),
      ("apk", .apk),
      ("pacman", .pacman),
      ("port", .port),
      ("nix-env", .nix),
    ]
    for (cmd, pm) in checks {
      if which(cmd) != nil { return pm }
    }
    return .unknown
  }

  // MARK: - Command Scanning

  private static func scanAvailableCommands() -> (Set<String>, [String: String]) {
    var commands = Set<String>()
    var paths: [String: String] = [:]

    let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
    let dirs = pathEnv.split(separator: ":").map(String.init)

    let fm = FileManager.default
    for dir in dirs {
      guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
      for entry in entries {
        if !commands.contains(entry) {
          commands.insert(entry)
          paths[entry] = "\(dir)/\(entry)"
        }
      }
    }

    return (commands, paths)
  }

  // MARK: - Version Probing

  /// Probe versions for commonly used tools. Quick — only checks ~15 commands.
  private static func probeVersions(available: Set<String>) -> [String: String] {
    let probes: [(String, [String], (String) -> String?)] = [
      ("git", ["--version"], { $0.replacingOccurrences(of: "git version ", with: "").trimmingWhitespace() }),
      ("swift", ["--version"], { extractFirst(pattern: "Swift version ([\\d.]+)", from: $0) }),
      ("python3", ["--version"], { $0.replacingOccurrences(of: "Python ", with: "").trimmingWhitespace() }),
      ("node", ["--version"], { $0.trimmingWhitespace() }),
      ("go", ["version"], { extractFirst(pattern: "go([\\d.]+)", from: $0) }),
      ("rustc", ["--version"], { extractFirst(pattern: "rustc ([\\d.]+)", from: $0) }),
      ("cargo", ["--version"], { extractFirst(pattern: "cargo ([\\d.]+)", from: $0) }),
      ("docker", ["--version"], { extractFirst(pattern: "Docker version ([\\d.]+)", from: $0) }),
      ("kubectl", ["version", "--client"], { extractFirst(pattern: "v([\\d.]+)", from: $0) }),
      ("aws", ["--version"], { extractFirst(pattern: "aws-cli/([\\d.]+)", from: $0) }),
      ("curl", ["--version"], { extractFirst(pattern: "curl ([\\d.]+)", from: $0) }),
      ("ffmpeg", ["-version"], { extractFirst(pattern: "ffmpeg version ([\\d.]+)", from: $0) }),
      ("ruby", ["--version"], { extractFirst(pattern: "ruby ([\\d.]+)", from: $0) }),
      ("npm", ["--version"], { $0.trimmingWhitespace() }),
    ]

    var versions: [String: String] = [:]
    for (cmd, args, parser) in probes {
      guard available.contains(cmd) else { continue }
      if let output = run(cmd, args), let version = parser(output) {
        versions[cmd] = version
      }
    }
    return versions
  }

  // MARK: - GNU Override Detection

  private static func detectGNUOverrides(available: Set<String>) -> [String: String] {
    // On macOS with Homebrew, GNU coreutils are prefixed with 'g'
    let bsdToGnu: [String: String] = [
      "sed": "gsed", "awk": "gawk", "find": "gfind",
      "xargs": "gxargs", "sort": "gsort", "date": "gdate",
      "readlink": "greadlink", "stat": "gstat", "head": "ghead",
      "tail": "gtail", "wc": "gwc", "cut": "gcut",
      "tr": "gtr", "uniq": "guniq", "mktemp": "gmktemp",
    ]
    var overrides: [String: String] = [:]
    for (bsd, gnu) in bsdToGnu {
      if available.contains(gnu) {
        overrides[bsd] = gnu
      }
    }
    return overrides
  }

  // MARK: - Missing Tool Alternatives

  private static func buildMissingAlternatives(
    available: Set<String>, os: OS
  ) -> [String: String] {
    let knownAlternatives: [String: String] = [
      "wget": "curl -LO",
      "htop": "top",
      "tree": "find . -type d | head -50",
      "watch": "while true; do clear; $CMD; sleep 2; done",
      "bat": "cat",
      "eza": "ls",
      "fzf": "grep -rn",
      "tmux": "screen",
      "parallel": "xargs -P$(sysctl -n hw.ncpu 2>/dev/null || nproc)",
      "pv": "cat",
      "glow": "cat",
      "delta": "diff",
      "sd": "sed",
      "hyperfine": "time",
      "tokei": "find . -name '*.swift' | xargs wc -l",
      "tldr": "man",
      "rg": "grep -rn",
      "fd": "find",
    ]

    var missing: [String: String] = [:]
    for (tool, alt) in knownAlternatives {
      if !available.contains(tool) {
        missing[tool] = alt
      }
    }
    return missing
  }

  // MARK: - Helpers

  private static func which(_ command: String) -> String? {
    // Use /usr/bin/env to find 'which' portably across platforms
    run("which", command)
  }

  private static func run(_ command: String, _ args: String...) -> String? {
    run(command, Array(args))
  }

  private static func run(_ command: String, _ args: [String]) -> String? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: command.hasPrefix("/") ? command : "/usr/bin/env")
    process.arguments = command.hasPrefix("/") ? args : [command] + args
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
      process.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      return nil
    }
  }

  private static func extractFirst(pattern: String, from text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          match.numberOfRanges > 1,
          let range = Range(match.range(at: 1), in: text)
    else { return nil }
    return String(text[range])
  }
}

// MARK: - String Extension

extension String {
  func trimmingWhitespace() -> String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
