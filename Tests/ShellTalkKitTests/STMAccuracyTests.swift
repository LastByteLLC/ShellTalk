// STMAccuracyTests.swift — Continuous accuracy regression suite
//
// Curated test cases that verify ShellTalk's intent matching, slot extraction,
// and command generation. Each test has a single unambiguous correct answer.
//
// These tests run in CI to prevent regressions. When adding new templates,
// add corresponding test cases here.
//
// Run: swift test --filter STMAccuracy

import Testing
@testable import ShellTalkKit

// MARK: - Shared Pipeline

private let pipeline = STMPipeline()

// MARK: - Test Helpers

private func expectTemplate(_ query: String, _ expectedTemplate: String, file: String = #file, line: Int = #line) {
  let result = pipeline.process(query)
  #expect(result != nil, "Nil result for: \(query)")
  guard let result else { return }
  #expect(result.templateId == expectedTemplate,
    "Expected \(expectedTemplate), got \(result.templateId) for: \(query)")
}

private func expectCategory(_ query: String, _ expectedCategory: String) {
  let result = pipeline.process(query)
  #expect(result != nil, "Nil result for: \(query)")
  guard let result else { return }
  #expect(result.categoryId == expectedCategory,
    "Expected category \(expectedCategory), got \(result.categoryId) for: \(query)")
}

private func expectCommand(_ query: String, contains substring: String) {
  let result = pipeline.process(query)
  #expect(result != nil, "Nil result for: \(query)")
  guard let result else { return }
  #expect(result.command.contains(substring),
    "Command '\(result.command)' missing '\(substring)' for: \(query)")
}

private func expectNil(_ query: String) {
  let result = pipeline.process(query)
  if let result {
    #expect(result.confidence < 0.3,
      "Expected nil/low confidence for '\(query)', got \(result.templateId) at \(result.confidence)")
  }
}

// MARK: - Core Intent Matching (Terse Commands)

@Suite("STMAccuracy", .serialized)
struct STMAccuracyTests {

  @Suite("TerseCommands")
  struct TerseCommands {
    @Test("Bare CLI commands route correctly")
    func bareCommands() {
      expectTemplate("git status", "git_status")
      expectTemplate("git diff", "git_diff")
      expectTemplate("git log", "git_log")
      expectTemplate("git stash", "git_stash")
      expectTemplate("git stash pop", "git_stash_pop")
      expectTemplate("docker ps", "docker_ps")
      expectTemplate("brew install wget", "brew_install")
      expectTemplate("brew list", "brew_list")
      expectTemplate("pip install requests", "pip_install")
      expectTemplate("cargo build", "cargo_build")
      expectTemplate("cargo test", "cargo_test")
      expectTemplate("swift build", "swift_build")
      expectTemplate("swift test", "swift_test")
      expectTemplate("npm run dev", "npm_run")
      expectTemplate("uptime", "uptime")
      expectTemplate("whoami", "whoami")
      expectTemplate("pwd", "pwd")
      expectTemplate("cal", "cal_show")
      expectTemplate("env", "env_vars")
    }

    @Test("Commands with arguments")
    func commandsWithArgs() {
      expectTemplate("ping google.com", "ping_host")
      expectCommand("ping google.com", contains: "ping -c")
      // which python3 routing varies by platform (NLEmbedding availability)
      // On macOS: which_cmd (system), on Linux: may route to python_run (dev_tools)
      let whichResult = pipeline.process("which python3")
      #expect(whichResult != nil)
      #expect(whichResult?.command.contains("python") == true)
      expectTemplate("wrangler deploy", "wrangler_deploy")
      expectTemplate("sam deploy", "sam_deploy")
    }
  }

  // MARK: - Natural Language (Conversational Queries)

  @Suite("NaturalLanguage")
  struct NaturalLanguage {
    @Test("File operations in natural language")
    func fileOps() {
      expectTemplate("find swift files", "find_by_extension")
      expectTemplate("find files modified today", "find_by_mtime")
      expectTemplate("find files larger than 100M", "find_large_files")
      expectTemplate("show directory structure", "tree_view")
      expectTemplate("how much space is this directory using", "du_disk_usage")
      expectTemplate("count files", "file_count")
      // du_disk_usage (file_ops) on macOS, du_summary (system) on Linux — both valid
      expectCommand("disk usage sorted by size", contains: "du")
      expectCategory("copy main.swift to backup/", "file_ops")
      expectCategory("move old.txt to archive/", "file_ops")
      expectCategory("delete temp.txt", "file_ops")
      expectTemplate("create directory src/models", "mkdir_dir")
    }

    // File-format-name → on-disk extension canonicalization.
    // Covers both slot-type canonicalization (Cand-002) and routing
    // refinement (Cand-003). "find CONFIG files" remains stm-eval-only —
    // generic-unknown-token routing to find_by_name is a larger problem
    // not addressed here.
    @Test("File extension canonicalization (format-name → on-disk ext)")
    func fileExtensionAliases() {
      expectTemplate("find all Markdown files", "find_by_extension")
      expectCommand("find all Markdown files", contains: "'*.md'")
      expectCommand("find markdown files", contains: "'*.md'")
      expectCommand("find all TypeScript files", contains: "'*.ts'")
      expectCommand("find Python files", contains: "'*.py'")
      expectCommand("list all Python files", contains: "'*.py'")
      expectCommand("find Rust files", contains: "'*.rs'")
      expectCommand("find Kotlin files", contains: "'*.kt'")
      expectCommand("find shell files", contains: "'*.sh'")
      expectCommand("find YAML files", contains: "'*.yaml'")
      expectCommand("find MARKDOWN files", contains: "'*.md'")
      expectCommand("find all PYTHON files", contains: "'*.py'")

      // Routing-refinement cases (Cand-003).
      expectTemplate("list JavaScript files", "find_by_extension")
      expectCommand("list JavaScript files", contains: "'*.js'")
      expectTemplate("find Ruby files", "find_by_extension")
      expectCommand("find Ruby files", contains: "'*.rb'")
      expectTemplate("find all Golang files", "find_by_extension")
      expectCommand("find all Golang files", contains: "'*.go'")
      expectTemplate("list all .ts files", "find_by_extension")
      expectCommand("list all .ts files", contains: "'*.ts'")
      expectTemplate("find HTML files", "find_by_extension")
      expectCommand("find HTML files", contains: "'*.html'")
    }

    @Test("Git operations in natural language")
    func gitOps() {
      expectTemplate("show me uncommitted changes", "git_status")
      expectTemplate("show last 5 commits", "git_log")
      expectTemplate("create branch feature/auth", "git_branch_create")
      expectTemplate("switch to main", "git_switch")
      expectTemplate("merge develop", "git_merge")
      expectTemplate("push my commits to remote", "git_push")
      expectTemplate("pull latest changes", "git_pull")
      expectTemplate("undo all uncommitted changes", "git_restore")
      expectTemplate("squash my last 3 commits", "git_squash")
      expectTemplate("create a pull request", "gh_pr_create")
      expectTemplate("show all tags sorted by date", "git_tag_sorted")
    }

    @Test("Text processing in natural language")
    func textProcessing() {
      expectTemplate("search for error in log files", "grep_search")
      expectTemplate("find files containing the word password", "grep_search")
      expectTemplate("replace foo with bar in config.yaml", "sed_replace")
      expectCommand("replace foo with bar in config.yaml", contains: "sed")
      expectCommand("replace foo with bar in config.yaml", contains: "foo")
      expectTemplate("count lines in README.md", "wc_count")
      expectTemplate("show first 20 lines of config.yaml", "head_file")
      // tail_file vs tail_follow routing varies by platform
      expectCategory("tail server.log", "text_processing")
      expectTemplate("follow the log file", "tail_follow")
      expectTemplate("pretty print json", "jq_parse")
    }

    @Test("Network operations in natural language")
    func network() {
      expectTemplate("fetch https://example.com", "curl_get")
      expectTemplate("download a file with curl", "curl_download")
      expectTemplate("what is listening on port 443", "lsof_ports")
      expectTemplate("check which ports are open", "lsof_ports")
      expectTemplate("check if example.com is reachable", "ping_host")
      expectTemplate("ssh as root to 192.168.1.1", "ssh_connect")
      expectCategory("dns lookup for google.com", "network")
    }

    @Test("System operations in natural language")
    func system() {
      expectTemplate("what is eating my cpu", "top_snapshot")
      expectTemplate("how long has this machine been up", "uptime")
      expectTemplate("show all environment variables", "env_vars")
      expectTemplate("where is python installed", "which_cmd")
      expectTemplate("how much ram is being used", "free_memory")
      expectTemplate("generate a random password", "random_password")
      expectTemplate("list all cron jobs", "crontab_list")
    }

    @Test("Docker operations in natural language")
    func docker() {
      expectTemplate("see all running containers", "docker_ps")
      expectTemplate("exec into the running nginx container", "docker_exec")
      expectTemplate("list all docker volumes", "docker_volume_ls")
      expectTemplate("remove all unused docker images", "docker_image_prune")
      expectTemplate("stop all running containers", "docker_stop_all")
      expectTemplate("show logs for the postgres container", "docker_logs")
      expectTemplate("stop the docker compose stack", "docker_compose_down")
    }

    @Test("Cloud operations in natural language")
    func cloud() {
      expectTemplate("deploy cloudflare worker", "wrangler_deploy")
      expectTemplate("start cloudflare worker locally", "wrangler_dev")
      expectTemplate("build this project for production", "swift_build_release")
      expectCategory("list ec2 instances", "cloud")
      // kubectl routing varies: cloud category on macOS, dev_tools on Linux
      let k8sResult = pipeline.process("kubectl get pods")
      #expect(k8sResult != nil)
      #expect(k8sResult?.command.contains("kubectl get") == true)
    }
  }

  // MARK: - Meta-Questions

  @Suite("MetaQuestions")
  struct MetaQuestions {
    @Test("Questions about commands route to man/help")
    func metaQuestions() {
      expectTemplate("how do I use grep", "man_page")
      expectTemplate("explain the find command", "man_page")
      expectTemplate("view the manual for chmod", "man_page")
      expectTemplate("what flags does curl allow", "command_help")
      expectTemplate("what version of node do I have", "command_version")
    }
  }

  // MARK: - Entity-Aware Routing

  @Suite("EntityRouting")
  struct EntityRouting {
    @Test("URL entities route to network")
    func urlRouting() {
      expectCategory("fetch https://example.com", "network")
      expectCategory("curl https://api.github.com/users", "network")
    }

    @Test("DNS/domain queries route correctly")
    func dnsRouting() {
      expectTemplate("look up TXT record for google.com", "dig_lookup")
    }
  }

  // MARK: - Phrase Matching

  @Suite("PhraseMatching")
  struct PhraseMatching {
    @Test("Compound phrases match correctly")
    func compoundPhrases() {
      // png files may route to find_by_extension or find_images depending on platform
      expectCategory("find all png files", "file_ops")
      expectTemplate("add execute permission to deploy.sh", "chmod_executable")
      expectTemplate("print working directory", "pwd")
      expectTemplate("list network interfaces", "ifconfig_show")
      expectTemplate("show me environment variable PATH", "echo_var")
    }
  }

  // MARK: - Command Quality (Slot Extraction)

  @Suite("CommandQuality")
  struct CommandQuality {
    @Test("Slot extraction produces correct values")
    func slotExtraction() {
      // Numeric extraction
      let logResult = pipeline.process("show last 5 commits")
      #expect(logResult?.extractedSlots["COUNT"] == "5")

      // File extension extraction
      let findResult = pipeline.process("find swift files")
      #expect(findResult?.extractedSlots["EXT"] == "swift")

      // Ping count
      let pingResult = pipeline.process("ping google 5 times")
      #expect(pingResult?.command.contains("-c 5") == true)
    }

    @Test("Commands don't contain noise words as values")
    func noNoiseValues() {
      let result = pipeline.process("show me all the files in the current directory")
      if let cmd = result?.command {
        #expect(!cmd.contains("the "), "Command contains noise word 'the': \(cmd)")
      }
    }

    @Test("Platform-specific slots resolve correctly")
    func platformSlots() {
      #if os(macOS)
      let result = pipeline.process("replace foo with bar in config.yaml")
      if let cmd = result?.command {
        #expect(cmd.contains("-i ''"), "macOS sed should use -i ''")
      }
      #endif
    }
  }

  // MARK: - Negative Tests

  @Suite("NegativeTests")
  struct NegativeTests {
    @Test("Gibberish returns nil or low confidence")
    func gibberish() {
      expectNil("zzzyyyxxx")
      expectNil("aslkdjfalskdjf")
    }

    @Test("Dangerous commands are flagged")
    func dangerous() {
      // Use the pipeline's validation rather than creating a new SystemProfile
      // (SystemProfile.detect() spawns subprocesses which can crash under concurrency)
      let result = pipeline.process("rm -rf /")
      // Either the pipeline returns a result with non-safe safety, or it blocks entirely
      if let result, let validation = result.validation {
        #expect(validation.safetyLevel != .safe)
      }
      // If nil, the pipeline correctly refused to process a dangerous command
    }
  }

  // MARK: - Incant validation gates (Categories A & B)

  @Suite("IncantValidation")
  struct IncantValidation {
    /// A1: incant-era templates (media, crypto, tar_*, curl_*, etc.) MUST
    /// NOT emit commands containing literal `{UPPERCASE}` placeholders.
    /// If the user's query lacks the required entity, return nil — never
    /// `magick {INPUT} {OUTPUT}`.
    @Test("Incant queries without filenames return nil, not unfilled placeholders")
    func incantPlaceholderGuard() {
      // Genuinely under-specified queries — no concrete file paths.
      let underspecified = [
        "convert all png to jpg",
        "make a thumbnail of every photo at 200x200",
        "encode video to h265",
      ]
      for q in underspecified {
        let r = pipeline.process(q)
        if let r {
          // Either nil OR a runnable command — never a literal {X} placeholder.
          let hasPlaceholder = r.command.range(
            of: #"\{[A-Z][A-Z0-9_]+\}"#, options: .regularExpression) != nil
          #expect(!hasPlaceholder,
            "Query '\(q)' produced unfilled placeholder: \(r.command)")
        }
      }
    }

    /// A1: queries that DO supply concrete entities must produce
    /// runnable commands (no `{X}` literals).
    @Test("Incant queries with filenames produce runnable commands")
    func incantConcreteQueries() {
      let cases: [(String, String)] = [
        ("rotate IMG_1234.jpg 90 degrees", "magick"),
        ("convert video.mov to video.mp4", "ffmpeg"),
        ("verify cert.pem against ca.pem", "openssl"),
        ("crop region 800x600+0+0 from photo.jpg", "magick"),
        ("encode video.mov to h264 with crf 23", "libx264"),
      ]
      for (q, mustContain) in cases {
        let r = pipeline.process(q)
        #expect(r != nil, "Expected match for: \(q)")
        if let r {
          let hasPlaceholder = r.command.range(
            of: #"\{[A-Z][A-Z0-9_]+\}"#, options: .regularExpression) != nil
          #expect(!hasPlaceholder,
            "Query '\(q)' produced unfilled placeholder: \(r.command)")
          #expect(r.command.contains(mustContain),
            "Query '\(q)' missing '\(mustContain)' in output: \(r.command)")
        }
      }
    }

    /// A2: name-aware slot validators reject structurally-wrong bindings.
    /// The query "border" being captured as a COLOR slot value, "h265"
    /// as a BITRATE, "4096" (RSA bits) as DAYS — all of these should
    /// either fall through to the slot's default or be filtered out.
    @Test("Slot-name validators reject structurally-wrong values")
    func slotNameValidation() {
      // COLOR must accept color names / hex; reject random words.
      #expect(SlotExtractor.passesNameValidation(name: "COLOR", value: "white"))
      #expect(SlotExtractor.passesNameValidation(name: "COLOR", value: "#ff0000"))
      #expect(!SlotExtractor.passesNameValidation(name: "COLOR", value: "border"))
      #expect(!SlotExtractor.passesNameValidation(name: "COLOR", value: "JPEGs"))

      // BITRATE must be digits + optional unit.
      #expect(SlotExtractor.passesNameValidation(name: "BITRATE", value: "5M"))
      #expect(SlotExtractor.passesNameValidation(name: "BITRATE", value: "192k"))
      #expect(SlotExtractor.passesNameValidation(name: "BITRATE", value: "1500"))
      #expect(!SlotExtractor.passesNameValidation(name: "BITRATE", value: "h265"))
      #expect(!SlotExtractor.passesNameValidation(name: "BITRATE", value: "fast"))

      // DAYS must be sane (1..~30 years).
      #expect(SlotExtractor.passesNameValidation(name: "DAYS", value: "365"))
      #expect(SlotExtractor.passesNameValidation(name: "DAYS", value: "3650"))
      #expect(!SlotExtractor.passesNameValidation(name: "DAYS", value: "0"))
      #expect(!SlotExtractor.passesNameValidation(name: "DAYS", value: "99999"))

      // BITS: known RSA key sizes only.
      #expect(SlotExtractor.passesNameValidation(name: "BITS", value: "4096"))
      #expect(SlotExtractor.passesNameValidation(name: "BITS", value: "2048"))
      #expect(!SlotExtractor.passesNameValidation(name: "BITS", value: "365"))

      // SIZE: NxM dimensions or percent; reject random words.
      #expect(SlotExtractor.passesNameValidation(name: "SIZE", value: "200x200"))
      #expect(SlotExtractor.passesNameValidation(name: "SIZE", value: "50%"))
      #expect(SlotExtractor.passesNameValidation(name: "SIZE", value: "10x20+5+5"))
      #expect(!SlotExtractor.passesNameValidation(name: "SIZE", value: "JPEGs"))
      #expect(!SlotExtractor.passesNameValidation(name: "SIZE", value: "border"))

      // SUBJ: openssl DN format.
      #expect(SlotExtractor.passesNameValidation(name: "SUBJ", value: "/CN=foo"))
      #expect(SlotExtractor.passesNameValidation(name: "SUBJ", value: "/CN=foo/O=bar"))
      #expect(!SlotExtractor.passesNameValidation(name: "SUBJ", value: "valid"))
    }

    /// A3: format-name → glob synthesis.
    @Test("Glob synthesis from natural-language quantifiers")
    func globSynthesis() {
      // Quantifier + format name → *.ext
      #expect(FileExtensionAliases.synthesizeGlob(from: "all PNG files") == "*.png")
      #expect(FileExtensionAliases.synthesizeGlob(from: "every JPEG in folder") == "*.jpg")
      #expect(FileExtensionAliases.synthesizeGlob(from: "all of these PNG into a grid") == "*.png")
      #expect(FileExtensionAliases.synthesizeGlob(from: "the mp4 files") == "*.mp4")
      #expect(FileExtensionAliases.synthesizeGlob(from: "all webp images") == "*.webp")

      // No quantifier + format that's also a common English word: no fire.
      #expect(FileExtensionAliases.synthesizeGlob(from: "go to docs") == nil)

      // No format name at all: nil.
      #expect(FileExtensionAliases.synthesizeGlob(from: "list files in folder") == nil)
    }

    /// A4: numeric-unit normalization.
    @Test("Numeric-unit normalization strips natural-language suffixes")
    func numericUnitNormalization() {
      #expect(SlotExtractor.normalizeNumericUnit("4px") == "4")
      #expect(SlotExtractor.normalizeNumericUnit("30sec") == "30")
      #expect(SlotExtractor.normalizeNumericUnit("90 degrees") == "90")
      #expect(SlotExtractor.normalizeNumericUnit("2x") == "2")
      #expect(SlotExtractor.normalizeNumericUnit("100%") == "100")
      #expect(SlotExtractor.normalizeNumericUnit("180°") == "180")
      #expect(SlotExtractor.normalizeNumericUnit("42") == "42")
      #expect(SlotExtractor.normalizeNumericUnit("not-a-number") == "not-a-number")
    }

    @Test("File-size canonicalization")
    func fileSizeCanonicalization() {
      #expect(SlotExtractor.normalizeFileSize("10MB") == "10M")
      #expect(SlotExtractor.normalizeFileSize("5 gigabytes") == "5G")
      #expect(SlotExtractor.normalizeFileSize("100kb") == "100K")
      #expect(SlotExtractor.normalizeFileSize("2tb") == "2T")
      #expect(SlotExtractor.normalizeFileSize("100M") == "100M")
    }
  }

  // MARK: - Regression Guards

  @Suite("Regressions")
  struct Regressions {
    @Test("Previously-fixed queries stay correct")
    func previousFixes() {
      // These all failed in earlier iterations and were fixed.
      // They serve as regression guards.

      // Cycle 1: New templates
      expectTemplate("undo all uncommitted changes", "git_restore")
      expectTemplate("create a pull request", "gh_pr_create")
      expectTemplate("squash my last 3 commits", "git_squash")
      expectTemplate("exec into the running nginx container", "docker_exec")
      expectTemplate("generate a random password", "random_password")

      // Cycle 2: BM25 validation
      expectTemplate("what takes up the most disk space", "du_summary")
      expectTemplate("update all brew packages", "brew_update")
      expectTemplate("stop all running containers", "docker_stop_all")

      // Cycle 3: Slot extraction
      expectTemplate("create directory src/components", "mkdir_dir")
      expectTemplate("extract all email addresses from this file", "grep_search")

      // Cycle 4: Intent expansion
      expectTemplate("check out the develop branch", "git_switch")
      expectTemplate("roll back to the previous commit", "git_reset")
      expectTemplate("make this script runnable", "chmod_executable")
      expectTemplate("where is python installed", "which_cmd")

      // TF-IDF hybrid
      expectTemplate("build this project for production", "swift_build_release")
    }
  }
}
