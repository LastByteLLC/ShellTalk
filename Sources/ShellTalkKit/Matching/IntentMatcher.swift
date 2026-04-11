// IntentMatcher.swift — Two-level hierarchical intent matching
//
// Level 1: Match query to category (BM25 over category descriptions + intents)
// Level 2: Match query to template within category (BM25 over template intents)
// Optional enhancement: NLEmbedding reranking on macOS for improved accuracy.
//
// Embeddings are computed LAZILY — only for BM25 candidate templates at query time,
// not for all 1300+ intent phrases at init. This keeps init under 20ms.

import Foundation

/// Configuration for the intent matcher.
public struct MatcherConfig: Sendable {
  /// Minimum BM25 score to consider a category match valid.
  public let categoryThreshold: Double
  /// Minimum BM25 score to consider a template match valid.
  public let templateThreshold: Double
  /// Number of top categories to search for templates.
  public let topCategories: Int
  /// Number of top templates to return per category.
  public let topTemplates: Int
  /// Whether to use NLEmbedding reranking (macOS only).
  public let useEmbeddings: Bool

  public static let `default` = MatcherConfig(
    categoryThreshold: 0.5,
    templateThreshold: 0.3,
    topCategories: 3,
    topTemplates: 5,
    useEmbeddings: true
  )
}

/// Two-level hierarchical intent matcher.
/// Matches user queries to command templates using BM25 + optional NLEmbedding.
public final class IntentMatcher: Sendable {
  private let store: TemplateStore
  private let embedding: any EmbeddingProvider
  private let config: MatcherConfig

  /// All meaningful tokens from template intents + command names.
  /// Used as the correction dictionary for typo tolerance.
  private let anchorWords: Set<String>

  /// Known CLI command names (from commandPrefixIndex).
  /// These are never "corrected" to a different command.
  private let knownCommands: Set<String>

  public init(
    store: TemplateStore,
    embedding: (any EmbeddingProvider)? = nil,
    config: MatcherConfig = .default
  ) {
    self.store = store
    self.config = config
    self.embedding = embedding ?? makeEmbeddingProvider()

    // Build anchor word dictionary for typo correction.
    var anchors = Set<String>()
    for cat in store.categories {
      for template in cat.templates {
        for intent in template.intents {
          for token in BM25.tokenize(intent) {
            anchors.insert(token)
          }
        }
      }
    }
    self.anchorWords = anchors
    self.knownCommands = Set(store.commandPrefixIndex.keys)
  }

  /// Match a user query to the best command template.
  /// Returns nil if no match exceeds the confidence threshold.
  public func match(_ query: String, entities: [RecognizedEntity] = []) -> IntentMatchResult? {
    let result = matchInternal(query, entities: entities)

    // Check if the query likely contains typos: any non-trivial token that isn't
    // a known anchor word, entity, or structured token is suspicious.
    let likelyHasTypos = queryLikelyHasTypos(query, entities: entities)

    // If we got a confident match AND no suspected typos, use it directly
    if let result, !likelyHasTypos {
      return result
    }

    // Try typo correction — may produce a better match
    if likelyHasTypos, let corrected = tryTypoCorrection(query, entities: entities) {
      // Always prefer the corrected match when we detected typos —
      // the corrected query is inherently more trustworthy than a match
      // against misspelled tokens.
      return corrected
    }

    return result
  }

  /// Check whether the query likely contains typos by looking for tokens
  /// that aren't recognized as anchor words, entities, or structured data.
  private func queryLikelyHasTypos(_ query: String, entities: [RecognizedEntity]) -> Bool {
    let tokens = BM25.tokenize(query)
    let entityTexts = Set(
      entities.flatMap { entity -> [String] in
        entity.text.lowercased()
          .components(separatedBy: CharacterSet.alphanumerics.inverted)
          .filter { $0.count >= 2 }
      }
    )

    for token in tokens {
      guard token.count >= 4 else { continue }
      if anchorWords.contains(token) { continue }
      if knownCommands.contains(token) { continue }
      if entityTexts.contains(token) { continue }
      if looksLikeStructuredToken(token) { continue }
      // Found an unrecognized token — likely a typo
      return true
    }
    return false
  }

  private func matchInternal(_ query: String, entities: [RecognizedEntity]) -> IntentMatchResult? {
    let normalized = TemplateStore.normalize(query)
    guard !normalized.isEmpty else { return nil }

    // Fast path 0: Meta-question detection
    // "how do I use grep" → man grep, "what flags does curl allow" → curl --help
    if let result = tryMetaQuestion(query: query, normalized: normalized) {
      return result
    }

    // Fast path 1: Exact match shortcut
    if let result = tryExactMatch(normalized) {
      return result
    }

    // Run BM25 (entity-aware) — always runs now
    let bm25Result = bm25Match(query, entities: entities)

    // Fast path 2: Phrase match — compound concepts
    // BM25 overrides phrase match only if it scores > 5.0 AND picked a different template
    if let phraseResult = tryPhraseMatch(normalized) {
      if let bm25 = bm25Result {
        let bm25Score = bm25.categoryScore * 0.3 + bm25.templateScore * 0.7
        if bm25Score > 5.0 && bm25.templateId != phraseResult.templateId {
          return bm25
        }
      }
      return phraseResult
    }

    // Fast path 3: Command-prefix match — only wins if BM25 didn't score higher
    if let prefixResult = tryCommandPrefixMatch(query: query, normalized: normalized) {
      if let bm25 = bm25Result {
        let bm25Score = bm25.categoryScore * 0.3 + bm25.templateScore * 0.7
        if bm25Score > 3.0 && bm25.templateId != prefixResult.templateId {
          return bm25
        }
      }
      return prefixResult
    }

    return bm25Result
  }

  // MARK: - Fast Path: Meta-Question Detection

  /// Detect queries that are ABOUT a command rather than requesting a command.
  /// Routes to man_page or command_help templates.
  private func tryMetaQuestion(query: String, normalized: String) -> IntentMatchResult? {
    let metaPatterns: [(pattern: String, templateId: String)] = [
      // "how do I use grep" → man grep
      (#"how (?:do i|to|can i) (?:use|run|do) (\w+)"#, "man_page"),
      // "explain the find command" → man find
      (#"explain (?:the )?(\w+)(?: command)?"#, "man_page"),
      // "what does grep do" → man grep
      (#"what does (\w+) do"#, "man_page"),
      // "help with git" → man git
      (#"help (?:with|on|about) (\w+)"#, "man_page"),
      // "what flags does curl allow" → curl --help
      (#"what (?:flags|options|arguments|args) (?:does|can|are) (\w+)"#, "command_help"),
      // "show curl options" → curl --help
      (#"show (\w+) (?:options|flags|help)"#, "command_help"),
    ]

    for (pattern, templateId) in metaPatterns {
      guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
            let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
            match.numberOfRanges > 1,
            let cmdRange = Range(match.range(at: 1), in: normalized) else { continue }

      let commandName = String(normalized[cmdRange])

      // Verify the extracted word is actually a known command (not a random noun)
      let isKnownCommand = store.commandPrefixIndex[commandName] != nil
        || store.exactMatchIndex[commandName] != nil

      guard isKnownCommand,
            let (categoryId, template) = lookupTemplate(templateId) else { continue }

      return IntentMatchResult(
        categoryId: categoryId,
        categoryScore: 1.0,
        templateId: templateId,
        templateScore: 1.0,
        embeddingScore: nil,
        template: template
      )
    }

    return nil
  }

  // MARK: - Fast Path: Phrase Match

  /// Check if the query contains a known 2-3 word phrase that maps to a template.
  private func tryPhraseMatch(_ normalized: String) -> IntentMatchResult? {
    let words = normalized.split(separator: " ").map(String.init)
    guard words.count >= 2 else { return nil }

    // Check 3-word phrases first (more specific), then 2-word
    for n in [3, 2] {
      for i in 0...(max(0, words.count - n)) {
        guard i + n <= words.count else { break }
        let phrase = words[i..<(i + n)].joined(separator: " ")
        if let templateId = store.phraseIndex[phrase],
           let (categoryId, template) = lookupTemplate(templateId) {
          return IntentMatchResult(
            categoryId: categoryId,
            categoryScore: 1.0,
            templateId: templateId,
            templateScore: 0.95,
            embeddingScore: nil,
            template: template
          )
        }
      }
    }
    return nil
  }

  // MARK: - Fast Path: Exact Match

  /// Check the exact match index for short/canonical queries.
  /// Only matches when the full normalized query is in the index.
  private func tryExactMatch(_ normalized: String) -> IntentMatchResult? {
    // Only use exact match for short queries (≤ 4 words)
    // Longer queries need BM25 to consider all tokens
    let wordCount = normalized.split(separator: " ").count
    guard wordCount <= 4 else { return nil }

    guard let templateId = store.exactMatchIndex[normalized],
          let (categoryId, template) = lookupTemplate(templateId) else { return nil }
    return IntentMatchResult(
      categoryId: categoryId,
      categoryScore: 1.0,
      templateId: templateId,
      templateScore: 1.0,
      embeddingScore: nil,
      template: template
    )
  }

  // MARK: - Fast Path: Command-Prefix Match

  /// When the first token of the query is a known shell command with few candidate
  /// templates (≤ 4), restrict search to those templates using discriminator logic.
  /// For commands with many templates (like "git"), fall through to BM25.
  /// Words that are common English verbs AND CLI command names.
  /// When these appear as the first word of a 3+ word query, skip command-prefix
  /// and let BM25 handle it — the user is speaking naturally, not invoking the CLI tool.
  private static let naturalLanguageVerbs: Set<String> = [
    "which", "find", "list", "show", "make", "open", "remove", "format",
    "set", "check", "clear", "test", "run", "start", "stop", "create",
    "watch", "export", "sort", "head", "tail", "top", "kill", "host",
    "touch", "file", "date", "diff", "split", "join", "cut", "tr",
    "look", "mount", "read", "write", "link", "cal",
  ]

  private func tryCommandPrefixMatch(query: String, normalized: String) -> IntentMatchResult? {
    let words = normalized.split(separator: " ").map(String.init)
    guard words.count >= 2 else { return nil }

    // Skip command-prefix for natural-language verbs in longer queries.
    // "which python3" (2 words) → command-prefix OK
    // "which file was modified recently" (5 words) → skip, use BM25
    if words.count >= 3, Self.naturalLanguageVerbs.contains(words[0]) {
      return nil
    }

    // Try two-token prefix first (e.g., "aws s3", "git stash"), then single-token
    let prefixesToTry: [String]
    if words.count >= 2 {
      prefixesToTry = [words[0] + " " + words[1], words[0]]
    } else {
      prefixesToTry = [words[0]]
    }

    for prefix in prefixesToTry {
      // For two-word prefixes, check exact match index first
      if prefix.contains(" ") {
        if store.exactMatchIndex[normalized] != nil {
          // Already handled by exact match — skip
          continue
        }
      }

      let firstToken = prefix.split(separator: " ").first.map(String.init) ?? prefix
      guard let candidateIds = store.commandPrefixIndex[firstToken] else { continue }

      // Only use command-prefix for small candidate sets (≤ 5 templates)
      // Larger sets (like "git" with 20 templates) need BM25 discrimination
      guard candidateIds.count <= 5, candidateIds.count >= 1 else { continue }

      // Single candidate — use it directly if the first token is the actual
      // command name AND no negative keywords are present in the query
      if candidateIds.count == 1 {
        let candidateId = candidateIds[0]
        guard let (categoryId, template) = lookupTemplate(candidateId) else { continue }
        // Verify the first token matches the start of the actual command
        let cmdPrefix = TemplateStore.extractCommandPrefix(template.command)
        let cmdFirstToken = cmdPrefix.lowercased().split(separator: " ").first.map(String.init)
        if cmdFirstToken == firstToken {
          // Check negative keywords before short-circuiting
          if let negatives = template.negativeKeywords {
            let queryWords = Set(words)
            let hasNegative = negatives.contains { queryWords.contains($0.lowercased()) }
            if hasNegative {
              // Negative keyword present — fall through to BM25
              continue
            }
          }
          return IntentMatchResult(
            categoryId: categoryId,
            categoryScore: 1.0,
            templateId: candidateId,
            templateScore: 0.9,
            embeddingScore: nil,
            template: template
          )
        }
        // First token doesn't match actual command — fall through to BM25
        continue
      }

      // Flag-aware matching: if query has flag-like tokens (starting with "-"),
      // check which template's command string contains those flags
      let queryFlags = words.filter { $0.hasPrefix("-") }
      if !queryFlags.isEmpty, candidateIds.count >= 2 {
        var bestFlagMatch: (id: String, template: CommandTemplate, matchCount: Int)?
        for candidateId in candidateIds {
          guard let (_, template) = lookupTemplate(candidateId) else { continue }
          let cmdLower = template.command.lowercased()
          let matchCount = queryFlags.filter { cmdLower.contains($0) }.count
          if matchCount > 0 {
            if bestFlagMatch == nil || matchCount > bestFlagMatch!.matchCount {
              bestFlagMatch = (candidateId, template, matchCount)
            }
          }
        }
        if let flagMatch = bestFlagMatch,
           let (categoryId, _) = lookupTemplate(flagMatch.id) {
          return IntentMatchResult(
            categoryId: categoryId,
            categoryScore: 1.0,
            templateId: flagMatch.id,
            templateScore: 0.95,
            embeddingScore: nil,
            template: flagMatch.template
          )
        }
      }

      let queryTokensLower = Set(words)

      // Multiple candidates — check discriminators
      var discriminatorMatch: (id: String, template: CommandTemplate)?
      var defaultCandidate: (id: String, template: CommandTemplate)?

      for candidateId in candidateIds {
        guard let (_, template) = lookupTemplate(candidateId) else { continue }

        if let discriminators = template.discriminators {
          let hasDiscriminator = discriminators.contains { disc in
            queryTokensLower.contains(disc.lowercased()) ||
            normalized.contains(disc.lowercased())
          }
          if hasDiscriminator && discriminatorMatch == nil {
            discriminatorMatch = (candidateId, template)
          }
        } else if defaultCandidate == nil {
          defaultCandidate = (candidateId, template)
        }
      }

      // Prefer discriminator match, then default
      let winner = discriminatorMatch ?? defaultCandidate
      guard let (winnerId, winnerTemplate) = winner,
            let (categoryId, _) = lookupTemplate(winnerId) else { continue }

      return IntentMatchResult(
        categoryId: categoryId,
        categoryScore: 1.0,
        templateId: winnerId,
        templateScore: 0.9,
        embeddingScore: nil,
        template: winnerTemplate
      )
    }

    return nil
  }

  // MARK: - Standard Path: BM25

  private func bm25Match(_ query: String, entities: [RecognizedEntity] = []) -> IntentMatchResult? {
    // Determine which synonym domains to suppress based on entities
    var suppressedDomains = Set<String>()
    let hasURL = entities.contains { $0.type == .url }
    let hasIP = entities.contains { $0.type == .ipAddress }
    let hasGitRef = entities.contains { $0.type == .branchName || $0.type == .gitRef }
    if hasURL || hasIP {
      suppressedDomains.insert("git")  // Don't expand "fetch" to git terms when URL present
    }
    if hasGitRef {
      suppressedDomains.insert("network")  // Don't expand to network terms when git ref present
    }

    // Level 1: Category matching with entity-aware boosting
    // Use scoped synonyms for category matching
    var categoryResults = store.matchCategories(
      query, topK: config.topCategories, suppressedDomains: suppressedDomains)
    guard !categoryResults.isEmpty else { return nil }

    // Apply entity-based category boosts
    let entityBoosts = computeEntityCategoryBoosts(entities)
    if !entityBoosts.isEmpty {
      categoryResults = categoryResults.map { result in
        let boost = entityBoosts[result.documentId] ?? 1.0
        return BM25Result(documentId: result.documentId, score: result.score * boost)
      }
      // Re-sort and also inject boosted categories that BM25 missed
      for (categoryId, boost) in entityBoosts where boost > 1.5 {
        if !categoryResults.contains(where: { $0.documentId == categoryId }) {
          categoryResults.append(BM25Result(documentId: categoryId, score: boost))
        }
      }
      categoryResults.sort { $0.score > $1.score }
      categoryResults = Array(categoryResults.prefix(config.topCategories + 1))
    }

    // Level 2: Template matching within top categories
    var candidates: [(category: String, categoryScore: Double, template: BM25Result)] = []

    for catResult in categoryResults {
      let templateResults = store.matchTemplates(
        query, inCategory: catResult.documentId, topK: config.topTemplates
      )
      for templateResult in templateResults {
        candidates.append((
          category: catResult.documentId,
          categoryScore: catResult.score,
          template: templateResult
        ))
      }
    }

    // TF-IDF hybrid: boost BM25 candidates that have high TF-IDF similarity,
    // and inject candidates BM25 missed entirely.
    let tfidfResults = store.tfidfIndex.search(query, topK: 5)
    let tfidfScores = Dictionary(uniqueKeysWithValues: tfidfResults.map { ($0.templateId, $0.score) })

    // Boost existing BM25 candidates by their TF-IDF similarity
    candidates = candidates.map { candidate in
      if let tfidfScore = tfidfScores[candidate.template.documentId], tfidfScore > 0.15 {
        let boost = 1.0 + Double(tfidfScore) * 0.5
        return (
          candidate.category,
          candidate.categoryScore * boost,
          BM25Result(documentId: candidate.template.documentId, score: candidate.template.score * boost)
        )
      }
      return candidate
    }

    // Inject TF-IDF-only candidates (not already in BM25 list) with conservative scoring
    for tfidf in tfidfResults {
      let alreadyCandidate = candidates.contains { $0.template.documentId == tfidf.templateId }
      if !alreadyCandidate, tfidf.score > 0.3 {
        if let catId = store.category(forTemplateId: tfidf.templateId) {
          let syntheticTemplateScore = Double(tfidf.score) * 3.0
          let syntheticCategoryScore = Double(tfidf.score) * 2.0
          candidates.append((
            category: catId,
            categoryScore: syntheticCategoryScore,
            template: BM25Result(documentId: tfidf.templateId, score: syntheticTemplateScore)
          ))
        }
      }
    }

    guard !candidates.isEmpty else { return nil }

    // Apply negative keyword penalties
    candidates = applyNegativeKeywordPenalties(candidates: candidates, query: query)

    // Optional: Rerank BM25 candidates with embeddings (lazy — only embed candidates)
    if embedding.isAvailable, config.useEmbeddings, let queryVec = embedding.embed(query) {
      candidates = rerankWithEmbeddings(candidates: candidates, queryVector: queryVec)
    }

    // Sort by combined score
    candidates.sort { combined($0) > combined($1) }

    guard let best = candidates.first else { return nil }

    // Check thresholds
    guard best.categoryScore >= config.categoryThreshold,
          best.template.score >= config.templateThreshold else { return nil }

    // Confidence gap check: reject low-confidence ambiguous matches.
    // This prevents garbage results for off-topic queries.
    let bestScore = combined(best)

    // Check 1: If the combined score is very low, reject
    if bestScore < 1.0 {
      return nil
    }

    // Check 2: If there are alternatives from different categories with
    // similar scores, the match is ambiguous
    if candidates.count >= 2 {
      let secondBestDifferentCategory = candidates.dropFirst()
        .first { $0.category != best.category }
      if let second = secondBestDifferentCategory {
        let ratio = bestScore / max(combined(second), 0.001)
        if ratio < 1.2 && bestScore < 2.5 {
          return nil
        }
      }
    }

    guard let template = store.template(byId: best.template.documentId) else { return nil }

    return IntentMatchResult(
      categoryId: best.category,
      categoryScore: best.categoryScore,
      templateId: best.template.documentId,
      templateScore: best.template.score,
      embeddingScore: nil,
      template: template
    )
  }

  // MARK: - Negative Keyword Penalties

  /// Penalize candidates whose templates have negative keywords matching the query.
  private func applyNegativeKeywordPenalties(
    candidates: [(category: String, categoryScore: Double, template: BM25Result)],
    query: String
  ) -> [(category: String, categoryScore: Double, template: BM25Result)] {
    let queryTokens = Set(BM25.tokenize(query))

    return candidates.map { candidate in
      guard let template = store.template(byId: candidate.template.documentId),
            let negatives = template.negativeKeywords else { return candidate }

      var penalty = 1.0
      for neg in negatives {
        if queryTokens.contains(neg.lowercased()) {
          penalty *= 0.3
        }
      }
      guard penalty < 1.0 else { return candidate }

      let penalizedResult = BM25Result(
        documentId: candidate.template.documentId,
        score: candidate.template.score * penalty
      )
      return (candidate.category, candidate.categoryScore, penalizedResult)
    }
  }

  // MARK: - Entity-Aware Category Boosting

  /// Compute category boost factors based on detected entities.
  /// Returns a map of categoryId → multiplier (1.0 = no change, >1.0 = boost).
  private func computeEntityCategoryBoosts(_ entities: [RecognizedEntity]) -> [String: Double] {
    guard !entities.isEmpty else { return [:] }

    var boosts: [String: Double] = [:]

    for entity in entities {
      switch entity.type {
      case .url:
        // URL detected → strongly boost network, suppress git/cloud
        boosts["network", default: 1.0] *= 3.0
        boosts["git", default: 1.0] *= 0.3
        boosts["cloud", default: 1.0] *= 0.5

      case .ipAddress:
        // IP address → network or system
        boosts["network", default: 1.0] *= 2.5
        boosts["system", default: 1.0] *= 1.5

      case .host:
        // Domain name → network (dig, ping, curl)
        boosts["network", default: 1.0] *= 2.0

      case .port:
        // Port number → network (lsof, nc)
        boosts["network", default: 1.0] *= 2.0

      case .processName:
        // Known service name → system (ps, kill)
        boosts["system", default: 1.0] *= 2.0
        boosts["cloud", default: 1.0] *= 0.5

      case .applicationName:
        // App name → macOS
        boosts["macos", default: 1.0] *= 2.0

      case .branchName, .gitRef:
        // Git ref → git
        boosts["git", default: 1.0] *= 2.0

      case .glob:
        // Glob pattern → file_ops
        boosts["file_ops", default: 1.0] *= 1.5

      case .envVar:
        // Environment variable → system
        boosts["system", default: 1.0] *= 1.5

      case .commandName:
        // A known CLI tool → boost the category that owns that command's template
        if let categoryId = store.category(forTemplateId: findTemplateForCommand(entity.text)) {
          boosts[categoryId, default: 1.0] *= 2.0
        }

      default:
        break
      }
    }

    return boosts
  }

  /// Find a template ID whose command starts with the given command name.
  private func findTemplateForCommand(_ commandName: String) -> String {
    let lower = commandName.lowercased()
    if let candidates = store.commandPrefixIndex[lower] {
      return candidates.first ?? ""
    }
    return ""
  }

  // MARK: - Helpers

  private func lookupTemplate(_ id: String) -> (String, CommandTemplate)? {
    guard let (categoryId, template) = store.category(forTemplateId: id).flatMap({ catId in
      store.template(byId: id).map { (catId, $0) }
    }) else { return nil }
    return (categoryId, template)
  }

  /// Return top-N matches (for debug/disambiguation).
  public func matchTopN(_ query: String, n: Int = 5) -> [IntentMatchResult] {
    let categoryResults = store.matchCategories(query, topK: config.topCategories)
    var candidates: [(category: String, categoryScore: Double, template: BM25Result)] = []

    for catResult in categoryResults {
      let templateResults = store.matchTemplates(
        query, inCategory: catResult.documentId, topK: config.topTemplates
      )
      for templateResult in templateResults {
        candidates.append((catResult.documentId, catResult.score, templateResult))
      }
    }

    if embedding.isAvailable, config.useEmbeddings, let queryVec = embedding.embed(query) {
      candidates = rerankWithEmbeddings(candidates: candidates, queryVector: queryVec)
    }

    candidates.sort { combined($0) > combined($1) }

    return candidates.prefix(n).compactMap { candidate in
      guard let template = store.template(byId: candidate.template.documentId) else { return nil }
      return IntentMatchResult(
        categoryId: candidate.category,
        categoryScore: candidate.categoryScore,
        templateId: candidate.template.documentId,
        templateScore: candidate.template.score,
        embeddingScore: nil,
        template: template
      )
    }
  }

  // MARK: - Embedding Reranking (Lazy)

  /// Rerank BM25 candidates by embedding similarity.
  /// Only embeds the candidate templates' intents — not the entire corpus.
  private func rerankWithEmbeddings(
    candidates: [(category: String, categoryScore: Double, template: BM25Result)],
    queryVector: [Float]
  ) -> [(category: String, categoryScore: Double, template: BM25Result)] {
    candidates.map { candidate in
      guard let template = store.template(byId: candidate.template.documentId) else {
        return candidate
      }
      // Embed just this template's intents (typically 5-8 phrases, ~3ms)
      let intentVecs = template.intents.compactMap { embedding.embed($0) }
      guard !intentVecs.isEmpty else { return candidate }

      let similarities = intentVecs.map { cosineSimilarity(queryVector, $0) }
      let avgSim = Double(similarities.reduce(0, +) / Float(similarities.count))

      // Boost BM25 score with embedding similarity
      let boostedScore = candidate.template.score * (1.0 + avgSim)
      let boostedResult = BM25Result(documentId: candidate.template.documentId, score: boostedScore)
      return (candidate.category, candidate.categoryScore, boostedResult)
    }
  }

  private func combined(
    _ c: (category: String, categoryScore: Double, template: BM25Result)
  ) -> Double {
    c.categoryScore * 0.3 + c.template.score * 0.7
  }

  // MARK: - Typo Tolerance

  /// Attempt to correct typos in the query and re-match.
  /// Only runs when all other matching paths failed to produce a result.
  ///
  /// Safety: skips tokens that are recognized entities (file names, URLs, app names,
  /// paths, extensions, IPs, etc.), known CLI commands, or structurally non-word tokens.
  private func tryTypoCorrection(
    _ query: String, entities: [RecognizedEntity]
  ) -> IntentMatchResult? {
    let tokens = BM25.tokenize(query)
    guard !tokens.isEmpty else { return nil }

    // Collect entity text spans to protect from correction.
    // Lowercased for comparison against lowercased tokens.
    let entityTexts = Set(
      entities.flatMap { entity -> [String] in
        // Protect the full entity text and each word within it
        let words = entity.text.lowercased()
          .components(separatedBy: CharacterSet.alphanumerics.inverted)
          .filter { $0.count >= 2 }
        return [entity.text.lowercased()] + words
      }
    )

    var corrected = tokens
    var didCorrect = false

    for (i, token) in tokens.enumerated() {
      // Skip if token is already a known anchor word
      if anchorWords.contains(token) { continue }

      // Skip if token is a known CLI command (never correct "ls" → "ps")
      if knownCommands.contains(token) { continue }

      // Skip if token overlaps with any recognized entity
      if entityTexts.contains(token) { continue }

      // Skip tokens that look like paths, extensions, or structured data
      if looksLikeStructuredToken(token) { continue }

      // Skip very short tokens (too ambiguous)
      guard token.count >= 4 else { continue }

      // Distance threshold based on word length
      let maxDist = token.count <= 5 ? 1 : 2

      var bestMatch: (word: String, dist: Int)?

      for anchor in anchorWords {
        // Quick length filter: tokens differing by more than maxDist chars can't match
        guard abs(anchor.count - token.count) <= maxDist else { continue }

        // Don't correct to very short words (avoids "gist" → "git" type issues)
        guard anchor.count >= 4 else { continue }

        let dist = editDistance(token, anchor)
        if dist > 0 && dist <= maxDist {
          if bestMatch == nil || dist < bestMatch!.dist {
            bestMatch = (anchor, dist)
          }
        }
      }

      if let best = bestMatch {
        corrected[i] = best.word
        didCorrect = true
      }
    }

    guard didCorrect else { return nil }

    // Rebuild the query with corrections applied to the ORIGINAL query string
    // (preserving tokens that BM25 would have stripped as stop words)
    let correctedQuery = rebuildQuery(original: query, originalTokens: tokens, correctedTokens: corrected)

    // Re-match with the corrected query (no recursion — entities stay the same)
    return matchInternal(correctedQuery, entities: entities)
  }

  /// Check if a token looks like structured data that should not be spell-corrected.
  private func looksLikeStructuredToken(_ token: String) -> Bool {
    // Contains path separators
    if token.contains("/") || token.contains("\\") { return true }

    // Looks like a file extension (.swift, .py)
    if token.hasPrefix(".") { return true }

    // Contains dots (file.txt, example.com)
    if token.contains(".") { return true }

    // Contains hyphens or underscores (kebab-case, snake_case identifiers)
    if token.contains("-") || token.contains("_") { return true }

    // Contains digits mixed with letters (abc123, v1, HEAD~2)
    let hasDigit = token.contains(where: \.isNumber)
    let hasLetter = token.contains(where: \.isLetter)
    if hasDigit && hasLetter { return true }

    // All digits (port numbers, PIDs, etc.)
    if token.allSatisfy(\.isNumber) { return true }

    return false
  }

  /// Rebuild the original query with corrected tokens.
  /// Maps BM25-tokenized words back to their positions in the original string
  /// and substitutes the corrected versions.
  private func rebuildQuery(original: String, originalTokens: [String], correctedTokens: [String]) -> String {
    var result = original.lowercased()
    for (i, token) in originalTokens.enumerated() where token != correctedTokens[i] {
      // Replace the first occurrence of the misspelled token
      if let range = result.range(of: token) {
        result = result.replacingCharacters(in: range, with: correctedTokens[i])
      }
    }
    return result
  }

  /// Compute the Damerau-Levenshtein distance between two strings.
  /// Counts insertions, deletions, substitutions, AND adjacent transpositions
  /// (e.g., "grpe" → "grep") as single edits. This handles the most common
  /// typo pattern: swapped adjacent characters.
  private func editDistance(_ a: String, _ b: String) -> Int {
    let m = a.count, n = b.count
    if m == 0 { return n }
    if n == 0 { return m }

    let aChars = Array(a)
    let bChars = Array(b)

    // Full matrix needed for Damerau-Levenshtein (transposition looks back 2 rows)
    var d = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    for i in 0...m { d[i][0] = i }
    for j in 0...n { d[0][j] = j }

    for i in 1...m {
      for j in 1...n {
        let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
        d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)

        // Transposition: swap of two adjacent characters
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
}

/// Result of intent matching.
public struct IntentMatchResult: Sendable {
  public let categoryId: String
  public let categoryScore: Double
  public let templateId: String
  public let templateScore: Double
  public let embeddingScore: Float?
  public let template: CommandTemplate

  public var confidence: Double {
    min(categoryScore, templateScore)
  }
}
