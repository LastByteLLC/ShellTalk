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
