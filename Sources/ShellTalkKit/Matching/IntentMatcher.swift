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

  public init(
    store: TemplateStore,
    embedding: (any EmbeddingProvider)? = nil,
    config: MatcherConfig = .default
  ) {
    self.store = store
    self.config = config
    self.embedding = embedding ?? makeEmbeddingProvider()
    // No pre-computation — embeddings are computed lazily at query time.
  }

  /// Match a user query to the best command template.
  /// Returns nil if no match exceeds the confidence threshold.
  public func match(_ query: String) -> IntentMatchResult? {
    let normalized = TemplateStore.normalize(query)
    guard !normalized.isEmpty else { return nil }

    // Fast path 1: Exact match shortcut
    if let result = tryExactMatch(normalized) {
      return result
    }

    // Fast path 2: Command-prefix match
    if let result = tryCommandPrefixMatch(query: query, normalized: normalized) {
      return result
    }

    // Standard path: Two-level BM25 matching
    return bm25Match(query)
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
  private func tryCommandPrefixMatch(query: String, normalized: String) -> IntentMatchResult? {
    let words = normalized.split(separator: " ").map(String.init)
    guard words.count >= 2 else { return nil }

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

  private func bm25Match(_ query: String) -> IntentMatchResult? {
    // Level 1: Category matching
    let categoryResults = store.matchCategories(query, topK: config.topCategories)
    guard !categoryResults.isEmpty else { return nil }

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
