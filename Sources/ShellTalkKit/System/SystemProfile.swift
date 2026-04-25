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
  /// Tool flavor classifications: e.g., "tar"→"gnu"/"bsd", "openssl"→"openssl"/"libressl",
  /// "magick"→"imagemagick7"/"imagemagick6". Empty when probe runs in fast mode.
  public let commandFlavors: [String: String]
  /// Boolean feature capabilities the matcher's `requires` predicates check against,
  /// e.g., "tar.zstd", "openssl.legacy". Populated by the mid-path probe.
  public let capabilities: Set<String>

  public init(
    os: OS,
    arch: String,
    osVersion: String,
    shell: Shell,
    packageManager: PackageManager,
    availableCommands: Set<String>,
    commandPaths: [String: String],
    commandVersions: [String: String],
    gnuOverrides: [String: String],
    missingAlternatives: [String: String],
    commandFlavors: [String: String] = [:],
    capabilities: Set<String> = []
  ) {
    self.os = os
    self.arch = arch
    self.osVersion = osVersion
    self.shell = shell
    self.packageManager = packageManager
    self.availableCommands = availableCommands
    self.commandPaths = commandPaths
    self.commandVersions = commandVersions
    self.gnuOverrides = gnuOverrides
    self.missingAlternatives = missingAlternatives
    self.commandFlavors = commandFlavors
    self.capabilities = capabilities
  }

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

  /// Process-wide cached profile (fast path, no version probing).
  /// First access triggers `detect()` (~50ms); all subsequent accesses are
  /// zero-cost. Swift's `static let` lazy init is thread-safe. Use this
  /// instead of `detect()` everywhere except `--profile` (which wants the
  /// expensive `full: true` probe).
  public static let cached: SystemProfile = detect()

  /// Auto-detect the current machine profile.
  /// Fast path (~15ms): skips version probing. Use `detect(full:)` for versions.
  /// On WASI/WASM, returns a minimal stub profile (no subprocess access).
  public static func detect(full: Bool = false) -> SystemProfile {
    #if os(WASI)
    return SystemProfile(
      os: .unknown,
      arch: "wasm32",
      osVersion: "wasi",
      shell: .sh,
      packageManager: .unknown,
      availableCommands: [],
      commandPaths: [:],
      commandVersions: [:],
      gnuOverrides: [:],
      missingAlternatives: [:],
      commandFlavors: [:],
      capabilities: []
    )
    #else
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

    // Flavor + capability probe (mid-path, ~30ms). Skipped in fast mode
    // unless explicitly opted in via SHELLTALK_PROBE=mid|full. The probe
    // populates commandFlavors (tar→gnu/bsd, openssl→openssl/libressl,
    // magick→imagemagick7/6) and capabilities (tar.zstd, openssl.legacy).
    let probeMode = ProcessInfo.processInfo.environment["SHELLTALK_PROBE"] ?? "mid"
    let (flavors, caps) = (full || probeMode == "mid" || probeMode == "full")
      ? probeFlavors(available: commands)
      : ([:], Set<String>())

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
      missingAlternatives: missing,
      commandFlavors: flavors,
      capabilities: caps
    )
    #endif
  }

  /// Check whether the profile satisfies a capability predicate. Predicates:
  ///   - "command:NAME"            — `availableCommands` contains NAME
  ///   - "flavor:TOOL=VALUE"       — `commandFlavors[TOOL]` equals VALUE
  ///   - "capability:NAME" or NAME — `capabilities` contains NAME
  /// Unrecognized predicates fail-soft (return true) to avoid surprise demotions.
  public func satisfies(_ requirement: String) -> Bool {
    if requirement.hasPrefix("command:") {
      return availableCommands.contains(String(requirement.dropFirst("command:".count)))
    }
    if requirement.hasPrefix("flavor:") {
      let body = String(requirement.dropFirst("flavor:".count))
      let parts = body.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return true }
      return commandFlavors[parts[0]] == parts[1]
    }
    if requirement.hasPrefix("capability:") {
      return capabilities.contains(String(requirement.dropFirst("capability:".count)))
    }
    // Bareword form is treated as a capability for ergonomics.
    return capabilities.contains(requirement)
  }

  #if !os(WASI)

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

  // MARK: - Flavor + Capability Probing

  /// Probe the 5 incant-target tools for vendor flavor and feature flags.
  /// Each subprocess call is short (~5ms); the whole probe runs ~30ms cold.
  ///
  /// Populates:
  ///   commandFlavors: ["tar": "gnu"|"bsd", "openssl": "openssl"|"libressl",
  ///                    "magick": "imagemagick7", "convert": "imagemagick6"]
  ///   capabilities  : ["tar.zstd", "tar.xz", "openssl.legacy", "magick.v7"]
  private static func probeFlavors(available: Set<String>) -> ([String: String], Set<String>) {
    var flavors: [String: String] = [:]
    var caps = Set<String>()

    // tar — GNU vs BSD, plus zstd/xz support
    if available.contains("tar") {
      if let v = run("tar", "--version") {
        if v.lowercased().contains("gnu tar") {
          flavors["tar"] = "gnu"
        } else if v.lowercased().contains("bsdtar") || v.lowercased().contains("libarchive") {
          flavors["tar"] = "bsd"
        }
        // zstd: GNU 1.31+ has --zstd; bsdtar uses -I zstd which works whenever
        // the zstd binary is on PATH. xz is similar. We mark the capability
        // present in either path so templates with `requires: capability:tar.zstd`
        // fire correctly on both flavors.
        if let help = run("tar", "--help"), help.contains("zstd") || help.contains("--zstd") {
          caps.insert("tar.zstd")
        } else if available.contains("zstd") {
          // bsdtar without --zstd in help still supports `-I zstd`.
          caps.insert("tar.zstd")
        }
        if let help = run("tar", "--help"), help.contains("xz") || help.contains("--xz") {
          caps.insert("tar.xz")
        } else if available.contains("xz") {
          caps.insert("tar.xz")
        }
      }
    }

    // openssl — OpenSSL vs LibreSSL, major version
    if available.contains("openssl") {
      if let v = run("openssl", "version") {
        if v.lowercased().contains("libressl") {
          flavors["openssl"] = "libressl"
        } else if v.lowercased().contains("openssl") {
          flavors["openssl"] = "openssl"
          // OpenSSL 3+ has the legacy provider for old ciphers.
          if v.contains("OpenSSL 3") || v.contains("OpenSSL 4") {
            caps.insert("openssl.legacy")
            caps.insert("openssl.v3")
          } else if v.contains("OpenSSL 1") {
            caps.insert("openssl.v1")
          }
        }
      }
    }

    // ImageMagick — v7 has `magick`; v6 has `convert` only.
    if available.contains("magick") {
      if let v = run("magick", "-version"), v.contains("ImageMagick") {
        flavors["magick"] = "imagemagick7"
        caps.insert("magick.v7")
      }
    } else if available.contains("convert") {
      // Distinguish ImageMagick v6 `convert` from coreutils-style `convert`.
      if let v = run("convert", "-version"), v.contains("ImageMagick") {
        flavors["convert"] = "imagemagick6"
        caps.insert("magick.v6")
      }
    }

    // ffmpeg — distinguish ffmpeg from avconv (the latter is mostly extinct
    // post-2018 but Debian historically symlinked it).
    if available.contains("ffmpeg") {
      flavors["ffmpeg"] = "ffmpeg"
    } else if available.contains("avconv") {
      flavors["ffmpeg"] = "avconv"
    }

    // curl — version-stable; no flavor variants worth gating on in V1.
    return (flavors, caps)
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

  #endif // !os(WASI) — end detection methods

  // MARK: - Helpers

  #if !os(WASI)
  private static func which(_ command: String) -> String? {
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
  #endif

  /// Compiled-once cache keyed by pattern literal. The version-probe table
  /// uses ~7 distinct patterns; compiling once per pattern amortizes over
  /// the lifetime of the process (and per-probe across `full: true` calls).
  nonisolated(unsafe) private static let extractFirstCache: NSCache<NSString, NSRegularExpression> = {
    let c = NSCache<NSString, NSRegularExpression>()
    c.countLimit = 32
    return c
  }()

  private static func extractFirst(pattern: String, from text: String) -> String? {
    let key = pattern as NSString
    let regex: NSRegularExpression
    if let cached = extractFirstCache.object(forKey: key) {
      regex = cached
    } else {
      guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
      extractFirstCache.setObject(r, forKey: key)
      regex = r
    }
    guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
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
