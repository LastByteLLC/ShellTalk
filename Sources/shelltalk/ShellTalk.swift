// ShellTalk.swift — CLI entry point
import ArgumentParser
import Foundation
import ShellTalkKit
#if canImport(ShellTalkDiscovery)
import ShellTalkDiscovery
#endif

@main
struct ShellTalk: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "shelltalk",
    abstract: "Convert natural language to shell commands",
    discussion: """
      Discovery layer (V1.5) augments hand-written templates with examples
      synthesized from the embedded tldr-pages corpus. Synthesized commands
      are marked with a tilde ('~') prefix; auto-execute (-x) refuses them
      unless --force is passed.

      tldr-pages content is licensed under CC-BY-4.0 by the tldr-pages
      maintainers and contributors. See:
        https://github.com/tldr-pages/tldr/blob/main/LICENSE.md
      """,
    version: "1.5.0"
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

  @Flag(name: .long, help: "Disable the discovery layer (no tldr fallback).")
  var noDiscovery = false

  @Flag(name: .long, help: "Force discovery path even when a built-in template would match (debug/exploration).")
  var explore = false

  @Flag(name: .long, help: "Force auto-execute of a synthesized command (with -x).")
  var force = false

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

    // V1.5: Construct the discovery provider when the layer is built in
    // and not disabled by --no-discovery / SHELLTALK_DISCOVERY=off.
    // On WASM canImport(ShellTalkDiscovery) is false; on macOS/Linux it
    // wires the embedded tldr-pages corpus.
    let discoveryProvider: DiscoveryProvider? = {
      #if canImport(ShellTalkDiscovery)
      if noDiscovery { return nil }
      let envOff = ProcessInfo.processInfo.environment["SHELLTALK_DISCOVERY"] == "off"
      if envOff { return nil }
      return makeDefaultDiscoveryProvider()
      #else
      return nil
      #endif
    }()

    let pipeline = STMPipeline(
      config: config,
      discoveryProvider: discoveryProvider
    )

    // V1.5: --explore forces the discovery path. Bypasses the standard
    // matcher entirely so the user can see what tldr-pages would have
    // produced, even when a built-in template would have matched. Useful
    // for debugging the synthesizer and for "show me tldr's take."
    if explore {
      guard let provider = discoveryProvider else {
        printError("--explore requires the discovery layer (not built in this build / disabled).")
        throw ExitCode.failure
      }
      let synth = provider.synthesize(query: text, profile: SystemProfile.cached)
      guard let s = synth else {
        printError("Discovery returned no synthesis for: \(text)")
        throw ExitCode.failure
      }
      print("~ \(s.template.command)")
      printWarning("Synthesized from \(s.provenance) — verify before running. tldr-pages content © contributors, CC-BY-4.0.")
      if debug {
        print()
        print("--- Discovery debug ---")
        print("Source:     \(s.source.rawValue)")
        print("Provenance: \(s.provenance)")
        print("Conf cap:   \(s.confidenceCap)")
        print("Provider:   \(provider.diagnosticName)")
      }
      return
    }

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
      printError("No confident match for: \(text)")
      // R3: surface the matcher's top-K rejected candidates as "did you
      // mean?" suggestions. Transforms a silent failure into a prompt
      // the user can actually act on.
      let suggestions = pipeline.suggestions(for: text, limit: 3)
      if !suggestions.isEmpty {
        print("")
        print("Did you mean:")
        for (i, s) in suggestions.enumerated() {
          let safety = safetyIcon(s.validation?.safetyLevel)
          print(
            "  \(i + 1). \(safety) \(s.command)"
              + "  (\(s.templateId), conf=\(String(format: "%.2f", s.confidence)))"
          )
        }
      }
      throw ExitCode.failure
    }

    // Debug output
    if debug, let info = result.debugInfo {
      printDebug(result: result, debug: info, initMs: pipeline.initMs)
    }

    // Display the command. Synthesized commands (V1.5) use a tilde
    // prefix instead of the safety icon to make their lower-confidence
    // status visually obvious.
    if result.source == .builtIn || result.source == .userPattern {
      let safety = safetyIcon(result.validation?.safetyLevel)
      print("\(safety) \(result.command)")
    } else {
      print("~ \(result.command)")
      let provLabel = result.provenance ?? "synthesized"
      printWarning("Synthesized from \(provLabel) — verify before running. tldr-pages content © contributors, CC-BY-4.0.")
    }

    // B6: Multi-operation hint. ShellTalk picked the dominant operation;
    // the trailing clause needs a separate command. Surface this so the
    // user knows the output is incomplete rather than discovering it at
    // run time.
    if let hint = result.multiOperationHint {
      printWarning("Query has a second operation '\(hint)' — run that as a separate command.")
    }

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
      // V1.5: refuse auto-exec for synthesized commands unless --force.
      // Synthesized commands have lower confidence and may contain
      // unsubstituted {{placeholders}} from tldr examples; running
      // them blindly is a foot-gun.
      if result.source != .builtIn && result.source != .userPattern && !force {
        printError("Refusing to auto-execute synthesized command. Pass --force to override, or copy the command and run it manually.")
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
          let healer = CommandHealer(profile: SystemProfile.cached)
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
    let sysProfile = SystemProfile.cached
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
