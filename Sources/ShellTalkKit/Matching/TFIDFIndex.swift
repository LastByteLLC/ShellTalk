// TFIDFIndex.swift — TF-IDF vector space for semantic similarity matching
//
// Complements BM25 by providing cosine similarity scoring in a continuous
// vector space. Unlike BM25 which scores individual documents, TF-IDF
// cosine similarity compares the overall "shape" of the query against
// each template's intent space.
//
// Key advantage over BM25: handles vocabulary diversity better.
// "build for production" matches "compile for release" because both share
// the concept space, even when individual token overlap is limited.
//
// Cross-platform: pure Swift math, works on macOS, Linux, and WASM.

import Foundation

/// A sparse TF-IDF vector (term → weight).
public struct TFIDFVector: Sendable {
  let weights: [String: Float]

  /// Cosine similarity with another vector.
  func cosineSimilarity(with other: TFIDFVector) -> Float {
    var dot: Float = 0
    var normA: Float = 0
    var normB: Float = 0

    // Only iterate over terms in the smaller vector for efficiency
    let (smaller, larger) = weights.count <= other.weights.count
      ? (weights, other.weights) : (other.weights, weights)

    for (term, weightA) in smaller {
      if let weightB = larger[term] {
        dot += weightA * weightB
      }
    }

    for v in weights.values { normA += v * v }
    for v in other.weights.values { normB += v * v }

    let denom = sqrt(normA) * sqrt(normB)
    return denom > 0 ? dot / denom : 0
  }
}

/// TF-IDF index over templates for cosine similarity search.
public struct TFIDFIndex: Sendable {
  /// Per-template TF-IDF vectors, keyed by template ID.
  private let templateVectors: [String: TFIDFVector]

  /// Inverse document frequency for each term.
  private let idf: [String: Float]

  /// Total number of documents (templates).
  private let documentCount: Int

  /// Build a TF-IDF index from template intent phrases.
  /// Each template's intents are concatenated into a single document.
  public init(templates: [(id: String, intents: [String])]) {
    let n = templates.count
    self.documentCount = n

    // Step 1: Tokenize each template's intents
    var tokenizedDocs: [(id: String, tokens: [String])] = []
    var docFreq: [String: Int] = [:]
    var allTermsPerDoc: [String: Set<String>] = [:]

    for (id, intents) in templates {
      var tokens: [String] = []
      var uniqueTerms = Set<String>()
      for intent in intents {
        let words = Self.tokenize(intent)
        tokens.append(contentsOf: words)
        uniqueTerms.formUnion(words)
      }
      tokenizedDocs.append((id, tokens))
      allTermsPerDoc[id] = uniqueTerms

      for term in uniqueTerms {
        docFreq[term, default: 0] += 1
      }
    }

    // Step 2: Compute IDF
    var computedIDF: [String: Float] = [:]
    for (term, df) in docFreq {
      // Standard IDF with smoothing: log(N / (1 + df))
      computedIDF[term] = log(Float(n) / Float(1 + df))
    }
    self.idf = computedIDF

    // Step 3: Build TF-IDF vectors
    var vectors: [String: TFIDFVector] = [:]
    for (id, tokens) in tokenizedDocs {
      let tf = Self.termFrequency(tokens)
      var weights: [String: Float] = [:]
      for (term, freq) in tf {
        if let termIDF = computedIDF[term] {
          // Sublinear TF: 1 + log(tf)
          weights[term] = (1 + log(Float(freq))) * termIDF
        }
      }
      vectors[id] = TFIDFVector(weights: weights)
    }
    self.templateVectors = vectors
  }

  /// Search for the most similar templates to a query.
  /// Returns template IDs sorted by cosine similarity, descending.
  public func search(_ query: String, topK: Int = 5) -> [(templateId: String, score: Float)] {
    let queryTokens = Self.tokenize(query)
    guard !queryTokens.isEmpty else { return [] }

    // Build query TF-IDF vector
    let tf = Self.termFrequency(queryTokens)
    var queryWeights: [String: Float] = [:]
    for (term, freq) in tf {
      if let termIDF = idf[term] {
        queryWeights[term] = (1 + log(Float(freq))) * termIDF
      }
    }
    let queryVector = TFIDFVector(weights: queryWeights)

    // Compute cosine similarity against all templates
    var results: [(templateId: String, score: Float)] = []
    for (templateId, templateVector) in templateVectors {
      let sim = queryVector.cosineSimilarity(with: templateVector)
      if sim > 0 {
        results.append((templateId, sim))
      }
    }

    results.sort { $0.score > $1.score }
    return Array(results.prefix(topK))
  }

  // MARK: - Tokenization

  /// Tokenize text for TF-IDF. Uses the same stop words as BM25 for consistency,
  /// but also applies synonym expansion for broader coverage.
  static func tokenize(_ text: String) -> [String] {
    BM25.tokenize(text, expandSynonyms: true)
  }

  /// Count term frequencies in a token list.
  private static func termFrequency(_ tokens: [String]) -> [String: Int] {
    var freq: [String: Int] = [:]
    for token in tokens {
      freq[token, default: 0] += 1
    }
    return freq
  }
}
