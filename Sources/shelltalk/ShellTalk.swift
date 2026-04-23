// ShellTalk.swift — CLI entry point
import ArgumentParser
import ShellTalkKit

@main
struct ShellTalk: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "shelltalk",
    abstract: "Convert natural language to shell commands",
    version: "0.1.0"
  )

  @Argument(help: "Natural language query (use quotes for multi-word).")
  var query: String?

  @Flag(name: [.customShort("x"), .long], help: "Execute the generated command.")
  var execute = false

  @Flag(name: .long, help: "Dry-run: validate without executing.")
  var dryRun = false

  @Flag(name: .long, help: "Show debug info (matched template, scores).")
  var debug = false

  @Flag(name: .long, help: "Show top-N alternative matches.")
  var alternatives = false

  @Flag(name: .long, help: "Show the detected system profile.")
  var profile = false

  @Option(name: .long, help: "Heal a failed command (pass the command in quotes).")
  var heal: String?

  @Option(name: .long, help: "Stderr from a failed command (used with --heal).")
  var stderr: String?

  func run() throws {
    // Profile mode
    if profile {
      showProfile()
      return
    }

    // Heal mode
    if let healCmd = heal {
      runHeal(command: healCmd)
      return
    }

    let text = query ?? ""
    if text.isEmpty {
      print("ShellTalk v0.1.0 — natural language to shell commands")
      print()
      print("Usage:")
      print("  shelltalk\"find swift files modified today\"")
      print("  shelltalk-x \"show disk usage\"")
      print("  shelltalk--dry-run \"delete all DS_Store files\"")
      print("  shelltalk--debug \"replace foo with bar in config.yaml\"")
      print("  shelltalk--heal \"sed -i 's/old/new/g' file.txt\" --stderr \"invalid command code\"")
      print("  shelltalk--profile")
      return
    }

    let config = debug ? PipelineConfig.debug : PipelineConfig.default
    let pipeline = STMPipeline(config: config)

    // Alternatives mode
    if alternatives {
      let raw = pipeline.processWithAlternatives(text, n: 5)
      if raw.isEmpty {
        printError("No matching commands found for: \(text)")
        throw ExitCode.failure
      }
      // Sort by confidence descending so the displayed rank matches the
      // displayed score. `matchTopN` returns in BM25 template-score order,
      // but `confidence = min(categoryScore, templateScore)` — these can
      // disagree, producing [1] with score < [2]. Stable sort preserves
      // original matcher order within ties.
      let results = raw.enumerated().sorted { lhs, rhs in
        if lhs.element.confidence != rhs.element.confidence {
          return lhs.element.confidence > rhs.element.confidence
        }
        return lhs.offset < rhs.offset
      }.map { $0.element }
      for (i, result) in results.enumerated() {
        let marker = i == 0 ? ">" : " "
        let safety = safetyIcon(result.validation?.safetyLevel)
        print("\(marker) [\(i + 1)] \(result.command)")
        print("     \(safety) \(result.categoryId)/\(result.templateId) (score: \(String(format: "%.2f", result.confidence)))")
      }
      return
    }

    // Main pipeline
    guard let result = pipeline.process(text) else {
      printError("No matching command found for: \(text)")
      throw ExitCode.failure
    }

    // Debug output
    if debug, let info = result.debugInfo {
      printDebug(result: result, debug: info, initMs: pipeline.initMs)
    }

    // Display the command
    let safety = safetyIcon(result.validation?.safetyLevel)
    print("\(safety) \(result.command)")

    // Validation warnings
    if let validation = result.validation {
      for warning in validation.warnings {
        printWarning(warning)
      }
    }

    // Dry-run mode
    if dryRun {
      if let v = result.validation {
        print()
        print("Validation:")
        print("  Syntax:  \(v.syntaxValid ? "valid" : "INVALID")")
        print("  Command: \(v.commandExists ? "exists" : "NOT FOUND")")
        print("  Safety:  \(v.safetyLevel.rawValue)")
      }
      return
    }

    // Execute mode
    if execute {
      guard result.validation?.safetyLevel != .dangerous else {
        printError("Refusing to execute dangerous command.")
        throw ExitCode.failure
      }

      let shell = SafeShell(workingDirectory: FileManager.default.currentDirectoryPath)
      do {
        let shellResult = try shell.execute(result.command)
        if !shellResult.stdout.isEmpty {
          print(shellResult.stdout)
        }
        if !shellResult.stderr.isEmpty {
          printError(shellResult.stderr)
        }
        if !shellResult.succeeded {
          let healer = CommandHealer(profile: SystemProfile.detect())
          let healResult = healer.heal(original: result.command, result: shellResult)
          if healResult.healed {
            printWarning("Healed: \(healResult.explanation)")
            print("> \(healResult.command)")
            let retryResult = try shell.execute(healResult.command)
            if !retryResult.stdout.isEmpty { print(retryResult.stdout) }
            if !retryResult.succeeded {
              printError("Healed command also failed (exit \(retryResult.exitCode))")
              throw ExitCode(rawValue: retryResult.exitCode)
            }
          } else {
            printError("Command failed: \(healResult.explanation)")
            throw ExitCode(rawValue: shellResult.exitCode)
          }
        }
      } catch let error as ShellError {
        switch error {
        case .blocked(let pattern):
          printError("Blocked: command matches dangerous pattern '\(pattern)'")
        case .timeout(let seconds):
          printError("Timeout after \(seconds)s")
        case .executionFailed(let msg):
          printError("Execution failed: \(msg)")
        }
        throw ExitCode.failure
      }
    }
  }

  // MARK: - Heal Mode

  private func runHeal(command: String) {
    let sysProfile = SystemProfile.detect()
    let healer = CommandHealer(profile: sysProfile)
    let result = ShellResult(stdout: "", stderr: stderr ?? "", exitCode: 1)
    let healResult = healer.heal(original: command, result: result)

    if healResult.healed {
      print("\u{001B}[32mFixed:\u{001B}[0m \(healResult.explanation)")
      print("> \(healResult.command)")
    } else {
      print("\u{001B}[33mDiagnosis:\u{001B}[0m \(healResult.explanation)")
      print("Category: \(healResult.category.rawValue)")
    }
  }

  // MARK: - Profile Mode

  private func showProfile() {
    let prof = SystemProfile.detect(full: true)
    print("OS:       \(prof.os.rawValue) \(prof.osVersion)")
    print("Arch:     \(prof.arch)")
    print("Shell:    \(prof.shell.rawValue)")
    print("Pkg Mgr:  \(prof.packageManager.rawValue)")
    print("Commands: \(prof.availableCommands.count) on PATH")

    if !prof.commandVersions.isEmpty {
      print("\nVersions:")
      for (cmd, ver) in prof.commandVersions.sorted(by: { $0.key < $1.key }) {
        print("  \(cmd): \(ver)")
      }
    }
    if !prof.gnuOverrides.isEmpty {
      print("\nGNU overrides:")
      for (bsd, gnu) in prof.gnuOverrides.sorted(by: { $0.key < $1.key }) {
        print("  \(bsd) -> \(gnu)")
      }
    }
    if !prof.missingAlternatives.isEmpty {
      print("\nMissing tools (alternatives):")
      for (tool, alt) in prof.missingAlternatives.sorted(by: { $0.key < $1.key }) {
        print("  \(tool) -> \(alt)")
      }
    }
  }

  // MARK: - Output Helpers

  private func printError(_ msg: String) {
    var err = StderrStream()
    print("\u{001B}[31merror:\u{001B}[0m \(msg)", to: &err)
  }

  private func printWarning(_ msg: String) {
    var err = StderrStream()
    print("\u{001B}[33mwarning:\u{001B}[0m \(msg)", to: &err)
  }

  private func safetyIcon(_ level: SafetyLevel?) -> String {
    switch level {
    case .safe, nil: return "\u{001B}[32m>\u{001B}[0m"
    case .caution: return "\u{001B}[33m!\u{001B}[0m"
    case .dangerous: return "\u{001B}[31mX\u{001B}[0m"
    }
  }

  private func printDebug(result: PipelineResult, debug: DebugInfo, initMs: Double) {
    print("--- Debug ---")

    // Timings
    let stageStr = debug.timings.map { "\($0.name) \(String(format: "%.2f", $0.elapsedMs))ms" }.joined(separator: " | ")
    print("Timing: init \(String(format: "%.0f", initMs))ms | \(stageStr) | total \(String(format: "%.0f", initMs + debug.totalMs))ms")

    if !debug.entities.isEmpty {
      print("Entities:")
      for e in debug.entities {
        let role = e.role == .unknown ? "" : " [\(e.role.rawValue)]"
        print("  \(e.text) -> \(e.type.rawValue)\(role) (\(e.source.rawValue), \(String(format: "%.0f%%", e.confidence * 100)))")
      }
    }
    print("Category: \(result.categoryId) (score: \(String(format: "%.3f", result.categoryScore)))")
    print("Template: \(result.templateId) (score: \(String(format: "%.3f", result.templateScore)))")
    if !result.extractedSlots.isEmpty {
      print("Slots: \(result.extractedSlots.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
    }
    if !debug.resolvedPlatformSlots.isEmpty {
      print("Platform: \(debug.resolvedPlatformSlots.map { "\($0.key)->\($0.value)" }.joined(separator: ", "))")
    }
    print("Alternatives:")
    for (i, alt) in debug.topMatches.prefix(3).enumerated() {
      print("  [\(i + 1)] \(alt.categoryId)/\(alt.templateId) (cat=\(String(format: "%.2f", alt.categoryScore)), tpl=\(String(format: "%.2f", alt.templateScore)))")
    }
    print("---")
  }
}

// MARK: - Stderr Output

/// Wrapper for writing to stderr without @retroactive conformance issues.
struct StderrStream: TextOutputStream {
  mutating func write(_ string: String) {
    if let data = string.data(using: .utf8) {
      FileHandle.standardError.write(data)
    }
  }
}
