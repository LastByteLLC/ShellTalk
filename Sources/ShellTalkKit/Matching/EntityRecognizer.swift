// EntityRecognizer.swift — Multi-layer entity recognition for CLI queries
//
// Extracts typed entities (file paths, app names, commands, URLs, etc.)
// from natural language queries WITHOUT an LLM.
//
// Recognition layers (run in sequence, each refines the previous):
//   1. Structural — regex patterns for paths, URLs, IPs, globs, etc.
//   2. Lexicon — lookup against known apps, commands, packages
//   3. Preposition Frame — "in X" → location, "of X" → target, etc.
//   4. NLTagger POS — noun extraction + preposition context (macOS only)
//
// Cross-platform: layers 1-3 are pure Swift. Layer 4 uses #if canImport.

import Foundation

#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// MARK: - Types

/// A recognized entity in a query.
public struct RecognizedEntity: Sendable {
  public let text: String
  public let type: EntityType
  public let role: EntityRole
  public let confidence: Float
  public let source: RecognitionSource

  public init(
    text: String, type: EntityType, role: EntityRole,
    confidence: Float, source: RecognitionSource
  ) {
    self.text = text
    self.type = type
    self.role = role
    self.confidence = confidence
    self.source = source
  }
}

/// Classification of a recognized entity.
public enum EntityType: String, Sendable {
  case filePath         // ./foo/bar.swift, ~/Documents/x
  case fileName         // main.swift, .DS_Store, Makefile
  case directoryPath    // src/, ~/Documents/, ./build/
  case glob             // *.swift, **/*.json
  case url              // https://example.com/api
  case host             // example.com, 192.168.1.1
  case port             // 8080, 3000
  case ipAddress        // 192.168.1.1
  case email            // user@host.com
  case applicationName  // Firefox, Xcode, Safari
  case processName      // nginx, postgres, node
  case commandName      // grep, find, docker
  case packageName      // express, flask, vapor
  case branchName       // main, feature/auth
  case gitRef           // a1b2c3d (short SHA)
  case number           // 42, 100M, 3.14
  case size             // 100M, 1G, 500K
  case duration         // 30s, 5m, 2h
  case envVar           // $HOME, ${PATH}
  case string           // fallback
}

/// The semantic role of an entity, derived from preposition context.
public enum EntityRole: String, Sendable {
  case target       // "of X", "X" (direct object)
  case source       // "from X"
  case destination  // "to X", "into X"
  case location     // "in X", "inside X", "within X", "under X"
  case instrument   // "with X", "using X"
  case name         // "named X", "called X"
  case pattern      // "matching X", "like X"
  case subject      // inferred from POS (the main noun)
  case unknown      // no preposition context
}

/// Which recognition layer produced this entity.
public enum RecognitionSource: String, Sendable {
  case structural   // Regex pattern match
  case lexicon      // Dictionary lookup
  case preposition  // Preposition frame analysis
  case posTagger    // NLTagger POS tagging
}

// MARK: - Entity Recognizer

/// Multi-layer entity recognizer for CLI queries.
public struct EntityRecognizer: Sendable {
  private let profile: SystemProfile
  /// Installed applications, lowercased for O(1) case-insensitive lookup.
  private let appNamesLower: Set<String>

  public init(profile: SystemProfile) {
    self.profile = profile
    self.appNamesLower = Set(Self.discoverApplications().map { $0.lowercased() })
  }

  /// Recognize all entities in a query string.
  public func recognize(_ query: String) -> [RecognizedEntity] {
    var entities: [RecognizedEntity] = []

    // Layer 1: Structural patterns (regex)
    entities.append(contentsOf: recognizeStructural(query))

    // Layer 2: Lexicon lookup
    entities.append(contentsOf: recognizeLexicon(query, existing: entities))

    // Layer 3: Preposition frames
    entities = applyPrepositionFrames(query, entities: entities)

    // Layer 4: NLTagger POS (macOS only) — fills gaps
    #if canImport(NaturalLanguage)
    entities.append(contentsOf: recognizeWithPOS(query, existing: entities))
    #endif

    // Deduplicate: if the same text span was recognized by multiple layers,
    // keep the highest-confidence one
    return deduplicate(entities)
  }

  /// Recognize entities and return them grouped by role for easy slot filling.
  public func recognizeGrouped(_ query: String) -> [EntityRole: [RecognizedEntity]] {
    let entities = recognize(query)
    return Dictionary(grouping: entities, by: \.role)
  }

  // MARK: - Layer 1: Structural Recognition (Regex)

  private func recognizeStructural(_ query: String) -> [RecognizedEntity] {
    var entities: [RecognizedEntity] = []
    let nsRange = NSRange(query.startIndex..., in: query)

    for rule in Self.structuralRules {
      for match in rule.regex.matches(in: query, range: nsRange) {
        // Use capture group 1 if it exists, otherwise group 0
        let captureIdx = match.numberOfRanges > 1 ? 1 : 0
        guard let range = Range(match.range(at: captureIdx), in: query) else { continue }
        let text = String(query[range]).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, text.count >= 2 else { continue }

        // Don't re-classify URLs as filenames
        if rule.type == .fileName && text.contains("://") { continue }

        entities.append(RecognizedEntity(
          text: text, type: rule.type, role: .unknown,
          confidence: rule.confidence, source: .structural
        ))
      }
    }

    return entities
  }

  /// Compiled structural rule: one NSRegularExpression + metadata.
  /// Patterns are literal and compile-safe; `try!` is correct here.
  private struct StructuralRule: Sendable {
    let regex: NSRegularExpression
    let type: EntityType
    let confidence: Float
  }

  /// Structural recognition rules, compiled once per process.
  /// Previously rebuilt + recompiled on every `recognize()` call (~10–15ms/query).
  private static let structuralRules: [StructuralRule] = [
    // URLs (must come before path detection)
    StructuralRule(regex: try! NSRegularExpression(pattern: #"https?://[^\s]+"#), type: .url, confidence: 0.95),

    // Email addresses
    StructuralRule(regex: try! NSRegularExpression(pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#), type: .email, confidence: 0.9),

    // IP addresses
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"#), type: .ipAddress, confidence: 0.9),

    // T1.3: Bare hostnames (example.com, api.github.com, my-server.local).
    // Must come AFTER URL/email so https://x.com and a@b.com are
    // captured as their richer types first. Excludes obvious file
    // patterns (single .ext form) by requiring at least one dot AND
    // a TLD-like suffix from the curated list, OR multi-label hyphen-
    // bearing labels which file extensions don't have.
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\b(?:[a-zA-Z][a-zA-Z0-9-]*\.)+(?:com|net|org|io|dev|local|internal|cloud|app|ai|co|gov|edu|info|tech|us|uk|de|fr|jp|cn|ca|au)\b"#), type: .host, confidence: 0.85),

    // Environment variables
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\$\{?\w+\}?"#), type: .envVar, confidence: 0.95),

    // Glob patterns (*.swift, **/*.json) — specific patterns first
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\*\.[a-zA-Z]+|\*\*/[^\s]+"#), type: .glob, confidence: 0.9),

    // File paths with directory (./foo/bar, ~/Documents/x, /usr/bin/y)
    StructuralRule(regex: try! NSRegularExpression(pattern: #"(?:\.{1,2}|~)?/[^\s]+"#), type: .filePath, confidence: 0.85),

    // Bare directory paths (Sources/, backup/, src/) — no leading ./ or ~/
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\b[a-zA-Z0-9_][a-zA-Z0-9_.-]*/(?=\s|$)"#), type: .directoryPath, confidence: 0.8),

    // Dotfiles (.DS_Store, .gitignore, .env)
    StructuralRule(regex: try! NSRegularExpression(pattern: #"(?<=\s|^)\.[a-zA-Z][a-zA-Z0-9_.-]+"#), type: .fileName, confidence: 0.85),

    // Files with extensions (main.swift, config.yaml, package.json)
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\b[a-zA-Z0-9_-]+\.[a-zA-Z]{1,10}\b"#), type: .fileName, confidence: 0.7),

    // Sizes (100M, 1G, 500K, 2.5GB)
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\b\d+(?:\.\d+)?[kKmMgGtT][bB]?\b"#), type: .size, confidence: 0.9),

    // Durations (30s, 5m, 2h, 1d)
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\b\d+[smhd]\b"#), type: .duration, confidence: 0.85),

    // Port numbers (explicit: "port 8080")
    StructuralRule(regex: try! NSRegularExpression(pattern: #"(?i)port\s+(\d{1,5})"#), type: .port, confidence: 0.9),

    // Standalone port-like numbers after colon (localhost:8080)
    StructuralRule(regex: try! NSRegularExpression(pattern: #":(\d{1,5})\b"#), type: .port, confidence: 0.8),

    // Git short SHA — low confidence, easy to false match
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\b[a-f0-9]{7,12}\b"#), type: .gitRef, confidence: 0.5),

    // Branch-like patterns (feature/auth, fix/crash-123)
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\b(?:feature|fix|hotfix|release|bugfix)/[a-zA-Z0-9._-]+\b"#), type: .branchName, confidence: 0.85),

    // T2.2: Multi-word proper nouns (My Documents, Program Files,
    // Application Support). Two or more consecutive Title-Case tokens
    // form a compound directory path. Treated as .directoryPath so
    // path-typed slots can consume it.
    StructuralRule(regex: try! NSRegularExpression(pattern: #"\b(?:[A-Z][a-z]+\s+){1,3}[A-Z][a-z]+\b"#), type: .directoryPath, confidence: 0.75),
  ]

  // MARK: - Layer 2: Lexicon Recognition

  private func recognizeLexicon(
    _ query: String, existing: [RecognizedEntity]
  ) -> [RecognizedEntity] {
    var entities: [RecognizedEntity] = []
    let existingTexts = Set(existing.map { $0.text.lowercased() })
    let words = tokenize(query)

    // Hoisted: previously re-lowercased + re-scanned per matching word.
    let queryLower = query.lowercased()
    let queryIsGitRelated = Self.gitContextKeywords.contains { queryLower.contains($0) }

    for word in words {
      let lower = word.lowercased()

      // Skip if already recognized structurally
      if existingTexts.contains(lower) { continue }

      // Check against installed applications (case-insensitive Set lookup)
      if appNamesLower.contains(lower) {
        entities.append(RecognizedEntity(
          text: word, type: .applicationName, role: .unknown,
          confidence: 0.85, source: .lexicon
        ))
        continue
      }

      // Check against known commands
      if profile.hasCommand(lower) {
        entities.append(RecognizedEntity(
          text: word, type: .commandName, role: .unknown,
          confidence: 0.6, source: .lexicon  // lower confidence — many common words are commands
        ))
        continue
      }

      // Check known process/service names
      if Self.knownServices.contains(lower) {
        entities.append(RecognizedEntity(
          text: word, type: .processName, role: .unknown,
          confidence: 0.8, source: .lexicon
        ))
        continue
      }

      // Check git branch keywords
      if Self.gitBranchKeywords.contains(lower) {
        // Only tag as branch if query seems git-related
        if queryIsGitRelated {
          entities.append(RecognizedEntity(
            text: word, type: .branchName, role: .unknown,
            confidence: 0.7, source: .lexicon
          ))
        }
      }
    }

    return entities
  }

  /// Fixed keyword sets for `recognizeLexicon`'s hot loop.
  private static let gitBranchKeywords: Set<String> =
    ["main", "master", "develop", "staging", "production"]
  private static let gitContextKeywords: [String] =
    ["branch", "merge", "checkout", "switch", "rebase", "push", "pull"]

  // MARK: - Layer 3: Preposition Frame Analysis

  private func applyPrepositionFrames(
    _ query: String, entities: [RecognizedEntity]
  ) -> [RecognizedEntity] {
    let words = tokenize(query)

    // Build a map of preposition → following word
    let prepFrames: [String: EntityRole] = [
      "in": .location, "inside": .location, "within": .location, "under": .location,
      "to": .destination, "into": .destination,
      "from": .source,
      "of": .target,
      "with": .instrument, "using": .instrument,
      "named": .name, "called": .name,
      "matching": .pattern, "like": .pattern,
      "on": .location, "at": .location,
      "for": .target,
      "by": .instrument,
    ]

    // Find the word following each preposition
    var prepTargets: [String: EntityRole] = [:]
    for (i, word) in words.enumerated() {
      if let role = prepFrames[word.lowercased()], i + 1 < words.count {
        let target = words[i + 1]
        prepTargets[target] = role
        // Also capture two-word targets (e.g., "in Sources/JuncoKit")
        if i + 2 < words.count && words[i + 1].hasSuffix("/") {
          prepTargets[words[i + 1] + words[i + 2]] = role
        }
      }
    }

    // Apply roles to existing entities
    return entities.map { entity in
      if let role = prepTargets[entity.text] {
        return RecognizedEntity(
          text: entity.text, type: entity.type, role: role,
          confidence: entity.confidence, source: entity.source
        )
      }
      // If no preposition context, try to infer from position
      if entity.role == .unknown {
        // The last noun-like entity without a role is often the direct object
        return entity
      }
      return entity
    }
  }

  // MARK: - Layer 4: NLTagger POS (macOS only)

  #if canImport(NaturalLanguage)
  private func recognizeWithPOS(
    _ query: String, existing: [RecognizedEntity]
  ) -> [RecognizedEntity] {
    let existingTexts = Set(existing.map { $0.text.lowercased() })
    var entities: [RecognizedEntity] = []

    let tagger = NLTagger(tagSchemes: [.lexicalClass])
    tagger.string = query

    // Collect nouns that aren't already recognized
    var nouns: [(String, NLTag)] = []
    tagger.enumerateTags(
      in: query.startIndex..<query.endIndex,
      unit: .word,
      scheme: .lexicalClass
    ) { tag, range in
      guard let tag else { return true }
      let word = String(query[range]).trimmingCharacters(in: .whitespaces)
      guard !word.isEmpty else { return true }

      if tag == .noun {
        let wordLower = word.lowercased()
        if !existingTexts.contains(wordLower) && !Self.metaNouns.contains(wordLower) {
          nouns.append((word, tag))
        }
      }
      return true
    }

    // Classify discovered nouns using heuristics
    for (noun, _) in nouns {
      let type = classifyNoun(noun)
      let role = inferRole(noun, in: query)
      entities.append(RecognizedEntity(
        text: noun, type: type, role: role,
        confidence: 0.6, source: .posTagger
      ))
    }

    return entities
  }

  /// Classify a noun using surface-form heuristics.
  private func classifyNoun(_ noun: String) -> EntityType {
    // Starts with uppercase, no dots → likely app or proper name
    if noun.first?.isUppercase == true && !noun.contains(".") {
      if appNamesLower.contains(noun.lowercased()) {
        return .applicationName
      }
      return .string  // Could be an app we don't know about
    }

    // Contains dot → likely a file
    if noun.contains(".") {
      if noun.hasPrefix(".") { return .fileName }  // dotfile
      return .fileName
    }

    // Known as a command or process (lowercased once)
    let nounLower = noun.lowercased()
    if profile.hasCommand(nounLower) {
      return .commandName
    }
    if Self.knownServices.contains(nounLower) {
      return .processName
    }

    return .string
  }

  /// Infer the role of a noun from its preposition context.
  private func inferRole(_ noun: String, in query: String) -> EntityRole {
    let lower = query.lowercased()
    let nounLower = noun.lowercased()

    // Check what preposition precedes this noun
    let prepPatterns: [(String, EntityRole)] = [
      ("in \(nounLower)", .location),
      ("of \(nounLower)", .target),
      ("to \(nounLower)", .destination),
      ("from \(nounLower)", .source),
      ("with \(nounLower)", .instrument),
      ("named \(nounLower)", .name),
      ("called \(nounLower)", .name),
      ("on \(nounLower)", .location),
    ]
    for (pattern, role) in prepPatterns {
      if lower.contains(pattern) { return role }
    }

    return .unknown
  }
  #endif

  // MARK: - Deduplication

  private func deduplicate(_ entities: [RecognizedEntity]) -> [RecognizedEntity] {
    var seen: [String: RecognizedEntity] = [:]
    for entity in entities {
      let key = entity.text.lowercased()
      if let existing = seen[key] {
        // Keep the higher-confidence one
        if entity.confidence > existing.confidence {
          seen[key] = entity
        }
        // But if the new one has a role and existing doesn't, prefer the new one
        if entity.role != .unknown && existing.role == .unknown {
          seen[key] = entity
        }
      } else {
        seen[key] = entity
      }
    }
    return Array(seen.values)
  }

  // MARK: - Helpers

  /// Simple word tokenization (preserves punctuation attached to words).
  private func tokenize(_ query: String) -> [String] {
    // Split on whitespace, keeping tokens with embedded punctuation intact
    query.split(separator: " ").map(String.init)
  }

  /// Discover installed applications on the system.
  private static func discoverApplications() -> Set<String> {
    var apps = Set<String>()

    #if os(macOS)
    let fm = FileManager.default
    let appDirs = ["/Applications", "/System/Applications"]
    for dir in appDirs {
      guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
      for entry in contents where entry.hasSuffix(".app") {
        let name = entry.replacingOccurrences(of: ".app", with: "")
        apps.insert(name)
        // Also add single-word variants (e.g., "Google Chrome" → "Chrome")
        let lastWord = name.split(separator: " ").last.map(String.init)
        if let last = lastWord, last != name {
          apps.insert(last)
        }
      }
    }
    #elseif os(Linux)
    // On Linux, check .desktop files
    let fm = FileManager.default
    let desktopDirs = ["/usr/share/applications", "/usr/local/share/applications"]
    for dir in desktopDirs {
      guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
      for entry in contents where entry.hasSuffix(".desktop") {
        // Extract Name= from .desktop file
        let path = "\(dir)/\(entry)"
        if let data = fm.contents(atPath: path),
           let content = String(data: data, encoding: .utf8) {
          for line in content.split(separator: "\n") {
            if line.hasPrefix("Name=") {
              apps.insert(String(line.dropFirst(5)))
              break
            }
          }
        }
      }
    }
    #endif

    return apps
  }

  /// Meta-nouns that describe types rather than being entities themselves.
  static let metaNouns: Set<String> = [
    "file", "files", "directory", "directories", "folder", "folders",
    "command", "commands", "process", "processes", "line", "lines",
    "output", "input", "result", "results", "content", "contents",
    "change", "changes", "commit", "commits", "branch", "branches",
    "package", "packages", "container", "containers", "image", "images",
    "version", "status", "log", "logs", "error", "errors",
    "screenshot", "screen", "window", "tab", "text", "code",
    "permission", "permissions", "size", "space", "usage", "disk",
    "port", "host", "server", "connection", "request", "response",
    "key", "value", "field", "column", "row", "entry",
  ]

  /// Well-known service/daemon names.
  static let knownServices: Set<String> = [
    "nginx", "apache", "httpd", "postgres", "postgresql", "mysql", "mariadb",
    "redis", "memcached", "mongodb", "mongod", "elasticsearch", "kibana",
    "rabbitmq", "kafka", "zookeeper", "consul", "vault", "nomad",
    "docker", "dockerd", "containerd", "kubelet",
    "node", "npm", "deno", "bun",
    "python", "python3", "gunicorn", "uvicorn", "celery",
    "ruby", "rails", "puma", "sidekiq",
    "java", "gradle", "maven",
    "swift", "swiftc",
    "ollama", "hugo",
    "sshd", "cron", "systemd",
  ]
}
