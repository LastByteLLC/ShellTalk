// TemplateStore.swift — Load, index, and search command templates
//
// Manages the template corpus. Templates can be loaded from:
// 1. Built-in YAML resources (shipped with the binary)
// 2. User-defined YAML files (~/.config/stm/templates/)

import Foundation
#if canImport(Yams)
import Yams
#endif

/// Central store for all command templates, indexed for fast lookup.
public final class TemplateStore: Sendable {
  public let categories: [TemplateCategory]

  /// BM25 index over category descriptions (for category selection).
  public let categoryIndex: BM25

  /// Per-category BM25 indexes over template intents (for template selection).
  public let templateIndexes: [String: BM25]

  /// Quick lookup: template ID → (category ID, template).
  private let templateMap: [String: (String, CommandTemplate)]

  /// Exact match index: normalized short phrase → template ID.
  /// Covers all intents ≤ 4 words, template IDs as phrases, and command prefixes.
  public let exactMatchIndex: [String: String]

  /// Command-prefix index: first command token → [template IDs].
  /// Used when the first word of the query is a known shell command.
  public let commandPrefixIndex: [String: [String]]

  public init(categories: [TemplateCategory]) {
    self.categories = categories

    // Build category-level BM25 index
    let categoryDocs = categories.map { cat in
      let intentText = cat.templates.flatMap(\.intents).joined(separator: " ")
      return BM25Document(id: cat.id, text: "\(cat.name) \(cat.description) \(intentText)")
    }
    self.categoryIndex = BM25(documents: categoryDocs)

    // Build per-category template indexes
    var indexes: [String: BM25] = [:]
    for cat in categories {
      let docs = cat.templates.map { template in
        let text = template.intents.joined(separator: " ")
        return BM25Document(id: template.id, text: text)
      }
      indexes[cat.id] = BM25(documents: docs)
    }
    self.templateIndexes = indexes

    // Build flat lookup map
    var map: [String: (String, CommandTemplate)] = [:]
    for cat in categories {
      for template in cat.templates {
        map[template.id] = (cat.id, template)
      }
    }
    self.templateMap = map

    // Build exact match index
    var exact: [String: String] = [:]
    for cat in categories {
      for template in cat.templates {
        // Add short intents (≤ 3 words after normalization)
        for intent in template.intents {
          let normalized = Self.normalize(intent)
          let wordCount = normalized.split(separator: " ").count
          if wordCount >= 1 && wordCount <= 3 && !normalized.isEmpty {
            // Only add if no conflict, or prefer template with shorter command
            if let existing = exact[normalized],
               let existingTemplate = map[existing]?.1 {
              let existingCmdLen = existingTemplate.command.replacingOccurrences(
                of: #"\{[A-Z_]+\}"#, with: "", options: .regularExpression).count
              let newCmdLen = template.command.replacingOccurrences(
                of: #"\{[A-Z_]+\}"#, with: "", options: .regularExpression).count
              if newCmdLen < existingCmdLen {
                exact[normalized] = template.id
              }
            } else {
              exact[normalized] = template.id
            }
          }
        }
        // Add template ID as phrase: "git_status" → "git status"
        let idPhrase = template.id.replacingOccurrences(of: "_", with: " ")
        if exact[idPhrase] == nil {
          exact[idPhrase] = template.id
        }
        // Add command prefix (up to first slot placeholder)
        let cmdPrefix = Self.extractCommandPrefix(template.command)
        if !cmdPrefix.isEmpty && cmdPrefix.split(separator: " ").count <= 3 {
          let normalizedPrefix = Self.normalize(cmdPrefix)
          if exact[normalizedPrefix] == nil {
            exact[normalizedPrefix] = template.id
          }
        }
      }
    }
    self.exactMatchIndex = exact

    // Build command-prefix index
    var cmdPrefixes: [String: [String]] = [:]
    for cat in categories {
      for template in cat.templates {
        let prefix = Self.extractCommandPrefix(template.command)
        guard !prefix.isEmpty else { continue }
        let firstToken = prefix.split(separator: " ").first.map(String.init) ?? prefix
        let normalized = firstToken.lowercased()
        cmdPrefixes[normalized, default: []].append(template.id)
      }
    }
    // Add templates whose commands start with platform slots that resolve to
    // known command names. E.g., open_file uses {OPEN_CMD} which becomes "open".
    let platformSlotCommands: [String: String] = [
      "OPEN_CMD": "open",    // macOS: open, Linux: xdg-open
    ]
    for cat in categories {
      for template in cat.templates {
        let cmd = template.command
        guard let first = cmd.split(separator: " ").first,
              first.hasPrefix("{"), first.hasSuffix("}") else { continue }
        let slotName = String(first.dropFirst().dropLast())
        if let resolved = platformSlotCommands[slotName] {
          if !cmdPrefixes[resolved, default: []].contains(template.id) {
            cmdPrefixes[resolved, default: []].append(template.id)
          }
        }
      }
    }
    self.commandPrefixIndex = cmdPrefixes

    // Build phrase index: extract 2-3 word phrases from intents
    var phrases: [String: String] = [:]
    for cat in categories {
      for template in cat.templates {
        for intent in template.intents {
          let words = intent.lowercased().split(separator: " ").map(String.init)
          // Extract all 2-word and 3-word n-grams
          for n in 2...3 {
            for i in 0...(max(0, words.count - n)) {
              guard i + n <= words.count else { break }
              let phrase = words[i..<(i + n)].joined(separator: " ")
              // Only index phrases where at least one word is not a stop word
              // Only index phrases where ALL words are content words (not stop words)
              // and at least one word is specific (not a common verb)
              let commonVerbs: Set<String> = ["list", "show", "find", "search", "create",
                "delete", "remove", "run", "start", "stop", "check", "set", "add"]
              let allContent = words[i..<(i + n)].allSatisfy { !BM25.stopWords.contains($0) }
              let hasSpecific = words[i..<(i + n)].contains { !commonVerbs.contains($0) }
              if allContent && hasSpecific && phrases[phrase] == nil {
                phrases[phrase] = template.id
              }
            }
          }
        }
      }
    }
    // Override with known concept phrases (these take priority over auto-generated)
    let conceptPhrases: [String: String] = [
      "txt record": "dig_lookup", "mx record": "dig_lookup",
      "dns record": "dig_lookup", "a record": "dig_lookup",
      "cname record": "dig_lookup",
      "png files": "find_by_extension", "jpg files": "find_by_extension",
      "json files": "find_by_extension", "yaml files": "find_by_extension",
      "csv files": "find_by_extension", "log files": "find_by_extension",
      "image files": "find_images", "photo files": "find_images",
      "execute permission": "chmod_executable",
      "executable permission": "chmod_executable",
      "environment variable": "echo_var",
      "env var": "echo_var",
      "working directory": "pwd",
      "network interfaces": "ifconfig_show",
      "ip address": "ifconfig_show",
      // Git phrases
      "pull request": "gh_pr_create",
      "squash commits": "git_squash",
      "revert commit": "git_revert",
      "discard changes": "git_restore",
      "undo changes": "git_restore",
      "uncommitted changes": "git_restore",
      // Docker phrases
      "docker volumes": "docker_volume_ls",
      "container logs": "docker_logs",
      "unused images": "docker_image_prune",
      "all containers": "docker_stop_all",
      // System phrases
      "cron jobs": "crontab_list",
      "cron job": "crontab_edit",
      "random password": "random_password",
      "network connections": "netstat_connections",
      "open connections": "netstat_connections",
      // File finding phrases
      "hidden files": "ls_files",
      "containing word": "grep_search",
      "files containing": "grep_search",
      "blank lines": "sed_delete_lines",
      "email addresses": "grep_search",
      // Disk space
      "disk space": "du_summary",
      "takes up space": "du_summary",
      "using space": "du_summary",
      // Containers
      "running containers": "docker_ps",
      "stop containers": "docker_stop_all",
      "stop all": "docker_stop_all",
      // Directory operations
      "directory called": "mkdir_dir",
      "folder called": "mkdir_dir",
      // SSL
      "ssl certificate": "openssl_check",
      "ssl cert": "openssl_check",
      // Version checking
      "version of": "command_help",
      // Brew
      "brew packages": "brew_update",
      "update packages": "brew_update",
      "update brew": "brew_update",
      // Clipboard
      "to clipboard": "pbcopy",
      "ssh key": "ssh_keygen",
      // Shell identity
      "which shell": "echo_var",
      "my shell": "echo_var",
    ]
    for (phrase, templateId) in conceptPhrases {
      phrases[phrase] = templateId
    }
    self.phraseIndex = phrases

    // Build TF-IDF index from template intents
    var tfidfInput: [(id: String, intents: [String])] = []
    for cat in categories {
      for template in cat.templates {
        tfidfInput.append((template.id, template.intents))
      }
    }
    self.tfidfIndex = TFIDFIndex(templates: tfidfInput)
  }

  /// Phrase index: 2-3 word phrases from intents → template ID.
  /// Matches compound concepts that BM25 bag-of-words misses.
  public let phraseIndex: [String: String]

  /// TF-IDF vector space index for cosine similarity matching.
  /// Complements BM25 by scoring in continuous vector space.
  public let tfidfIndex: TFIDFIndex

  /// Normalize a string for exact matching: lowercase, trim, collapse whitespace.
  static func normalize(_ text: String) -> String {
    text.lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  /// Extract the command prefix from a template command string (up to first slot placeholder).
  static func extractCommandPrefix(_ command: String) -> String {
    var result: [String] = []
    for token in command.split(separator: " ") {
      if token.contains("{") { break }
      result.append(String(token))
    }
    return result.joined(separator: " ")
  }

  /// Look up a template by ID.
  public func template(byId id: String) -> CommandTemplate? {
    templateMap[id]?.1
  }

  /// Get the category for a template ID.
  public func category(forTemplateId id: String) -> String? {
    templateMap[id]?.0
  }

  /// Find the best matching categories for a query.
  public func matchCategories(
    _ query: String, topK: Int = 3, suppressedDomains: Set<String> = []
  ) -> [BM25Result] {
    categoryIndex.search(query, topK: topK, suppressedDomains: suppressedDomains)
  }

  /// Find the best matching templates within a specific category.
  public func matchTemplates(
    _ query: String, inCategory categoryId: String, topK: Int = 5
  ) -> [BM25Result] {
    guard let index = templateIndexes[categoryId] else { return [] }
    return index.search(query, topK: topK)
  }

  /// Total template count across all categories.
  public var templateCount: Int {
    categories.reduce(0) { $0 + $1.templates.count }
  }

  // MARK: - Loading from YAML

  /// Load categories from YAML strings.
  /// Requires the Yams library (not available in WASM builds).
  #if canImport(Yams)
  public static func fromYAML(_ yamlStrings: [String]) throws -> TemplateStore {
    var categories: [TemplateCategory] = []
    let decoder = YAMLDecoder()
    for yaml in yamlStrings {
      let category = try decoder.decode(TemplateCategory.self, from: yaml)
      categories.append(category)
    }
    return TemplateStore(categories: categories)
  }
  #endif

  /// Load categories from YAML files in a directory.
  /// Not available in WASM — use `builtIn()` or `fromYAML()` instead.
  #if !os(WASI)
  public static func fromDirectory(_ path: String) throws -> TemplateStore {
    let fm = FileManager.default
    let contents = try fm.contentsOfDirectory(atPath: path)
    let yamlFiles = contents.filter { $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") }

    var yamlStrings: [String] = []
    for file in yamlFiles.sorted() {
      let fullPath = (path as NSString).appendingPathComponent(file)
      let content = try String(contentsOfFile: fullPath, encoding: .utf8)
      yamlStrings.append(content)
    }

    return try fromYAML(yamlStrings)
  }
  #endif

  /// Load from built-in templates bundled with the library.
  public static func builtIn() -> TemplateStore {
    TemplateStore(categories: BuiltInTemplates.all)
  }
}
