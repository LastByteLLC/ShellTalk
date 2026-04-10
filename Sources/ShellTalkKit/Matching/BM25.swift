// BM25.swift — Pure Swift BM25 text matching
//
// Cross-platform (no Apple frameworks needed). Provides ranked retrieval
// of documents given a query, using the Okapi BM25 scoring function.
// Used as the primary intent matcher on all platforms.

import Foundation

/// A document indexed for BM25 retrieval.
public struct BM25Document: Sendable {
  public let id: String
  public let tokens: [String]
  public let originalText: String

  public init(id: String, text: String) {
    self.id = id
    self.originalText = text
    self.tokens = BM25.tokenize(text)
  }
}

/// A BM25 search result.
public struct BM25Result: Sendable {
  public let documentId: String
  public let score: Double
}

/// Okapi BM25 ranking function for text retrieval.
///
/// BM25 parameters:
/// - `k1`: Term frequency saturation. Higher = more weight to repeated terms. Default 1.2.
/// - `b`: Length normalization. 0 = no normalization, 1 = full. Default 0.75.
public struct BM25: Sendable {
  private let documents: [BM25Document]
  private let avgDocLength: Double
  private let idf: [String: Double]
  private let k1: Double
  private let b: Double

  /// Create a BM25 index from a set of documents.
  public init(documents: [BM25Document], k1: Double = 1.2, b: Double = 0.75) {
    self.documents = documents
    self.k1 = k1
    self.b = b

    let totalLength = documents.reduce(0) { $0 + $1.tokens.count }
    self.avgDocLength = documents.isEmpty ? 1.0 : Double(totalLength) / Double(documents.count)

    // Compute IDF for each term
    let n = Double(documents.count)
    var docFreq: [String: Int] = [:]
    for doc in documents {
      let uniqueTokens = Set(doc.tokens)
      for token in uniqueTokens {
        docFreq[token, default: 0] += 1
      }
    }

    var computedIDF: [String: Double] = [:]
    for (term, df) in docFreq {
      // Standard BM25 IDF: log((N - df + 0.5) / (df + 0.5) + 1)
      computedIDF[term] = log((n - Double(df) + 0.5) / (Double(df) + 0.5) + 1.0)
    }
    self.idf = computedIDF
  }

  /// Search for documents matching the query. Returns results sorted by score descending.
  public func search(
    _ query: String, topK: Int = 10,
    expandSynonyms: Bool = true,
    suppressedDomains: Set<String> = []
  ) -> [BM25Result] {
    let queryTokens = Self.tokenize(
      query, expandSynonyms: expandSynonyms, suppressedDomains: suppressedDomains)
    guard !queryTokens.isEmpty else { return [] }

    var results: [BM25Result] = []

    for doc in documents {
      let score = computeScore(queryTokens: queryTokens, document: doc)
      if score > 0 {
        results.append(BM25Result(documentId: doc.id, score: score))
      }
    }

    results.sort { $0.score > $1.score }
    return Array(results.prefix(topK))
  }

  /// Compute BM25 score for a single document against a query.
  private func computeScore(queryTokens: [String], document: BM25Document) -> Double {
    let docLength = Double(document.tokens.count)

    // Count term frequencies in document
    var termFreq: [String: Int] = [:]
    for token in document.tokens {
      termFreq[token, default: 0] += 1
    }

    var score = 0.0
    for term in queryTokens {
      guard let termIDF = idf[term] else { continue }
      let tf = Double(termFreq[term] ?? 0)
      let numerator = tf * (k1 + 1)
      let denominator = tf + k1 * (1 - b + b * docLength / avgDocLength)
      score += termIDF * numerator / denominator
    }

    return score
  }

  // MARK: - Tokenization

  /// Tokenize text into lowercase words, filtering stop words and short tokens.
  /// When `expandSynonyms` is true, informal verbs are expanded to canonical terms.
  /// `suppressedDomains` prevents synonyms from expanding into specific domains
  /// (e.g., when a URL is detected, suppress git-related synonyms).
  public static func tokenize(
    _ text: String,
    expandSynonyms: Bool = false,
    suppressedDomains: Set<String> = []
  ) -> [String] {
    let lowered = text.lowercased()
    // Split on non-alphanumeric characters
    var words = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { $0.count >= 2 }
      .filter { !stopWords.contains($0) }

    if expandSynonyms {
      var expanded: [String] = []
      for word in words {
        expanded.append(word)
        if let synonyms = Self.synonymTable[word] {
          // Filter out synonyms from suppressed domains
          let filtered = synonyms.filter { syn in
            for domain in suppressedDomains {
              if let domainWords = Self.domainWords[domain], domainWords.contains(syn) {
                return false
              }
            }
            return true
          }
          expanded.append(contentsOf: filtered)
        }
      }
      words = expanded
    }

    return words
  }

  /// Words associated with specific domains — used to suppress synonym expansion
  /// when entity detection indicates a different domain.
  static let domainWords: [String: Set<String>] = [
    "git": ["fetch", "pull", "push", "commit", "branch", "merge", "stash", "rebase"],
    "network": ["download", "fetch", "request", "post", "get"],
  ]

  /// Synonym expansion table: informal verbs → canonical terms.
  /// Applied to user queries (not template intents) to bridge vocabulary gaps.
  static let synonymTable: [String: [String]] = [
    // Delete/remove synonyms
    "erase": ["delete", "remove"],
    "nuke": ["delete", "remove"],
    "wipe": ["delete", "remove", "clean"],
    "purge": ["delete", "remove", "clean"],
    "destroy": ["delete", "remove"],
    "obliterate": ["delete", "remove"],
    // Kill/stop synonyms
    "zap": ["kill", "terminate", "stop"],
    "slay": ["kill", "terminate"],
    "halt": ["stop", "kill"],
    "terminate": ["kill", "stop"],
    // Copy/move synonyms
    "duplicate": ["copy"],
    "replicate": ["copy"],
    "relocate": ["move"],
    // Show/display synonyms
    "display": ["show", "list"],
    "peek": ["show", "head", "preview"],
    "inspect": ["show", "check"],
    "reveal": ["show", "open"],
    "view": ["show"],
    "examine": ["show", "check"],
    // Push/deploy synonyms
    "ship": ["push", "deploy"],
    "publish": ["push", "deploy"],
    "release": ["deploy", "push"],
    // Search/find synonyms
    "locate": ["find", "which", "where"],
    "lookup": ["find", "search"],
    "hunt": ["find", "search"],
    "scan": ["search", "find"],
    // Start/run synonyms
    "launch": ["start", "run", "open"],
    "execute": ["run"],
    "fire": ["start", "run"],
    "spin": ["start", "run"],
    // Fetch/download synonyms
    "grab": ["download", "fetch"],
    "pull": ["fetch", "download"],
    // Compress synonyms
    "squash": ["compress"],
    "shrink": ["compress", "resize"],
    // Extract/parse synonyms
    "extract": ["search", "find", "get"],
    "parse": ["read", "extract"],
    // Generate/create synonyms
    "generate": ["create"],
    "produce": ["create", "generate"],
    // Calculate/compute synonyms
    "calculate": ["compute", "check"],
    "compute": ["calculate", "check"],
    // Nearest/closest synonyms
    "nearest": ["find", "locate"],
    "closest": ["find", "locate"],
    // Prune/cleanup synonyms
    "prune": ["clean", "remove", "delete"],
    "cleanup": ["clean", "remove", "delete"],
    // Enter/connect synonyms
    "enter": ["exec", "connect", "shell"],
    "attach": ["connect", "exec"],
  ]

  /// English stop words (compact set for CLI use).
  static let stopWords: Set<String> = [
    "a", "an", "the", "is", "it", "in", "on", "at", "to", "of",
    "for", "and", "or", "but", "not", "this", "that", "with", "from",
    "by", "as", "be", "are", "was", "were", "been", "has", "have",
    "had", "do", "does", "did", "will", "would", "could", "should",
    "may", "might", "can", "shall", "if", "then", "than", "so",
    "no", "yes", "all", "any", "each", "every", "how", "what",
    "when", "where", "which", "who", "whom", "why", "my", "your",
    "its", "our", "their", "me", "him", "her", "us", "them",
    "i", "you", "he", "she", "we", "they",
    "am", "just", "also", "very", "too", "here", "there",
    "up", "out", "about", "into", "over", "after", "before",
    "between", "under", "during", "through", "above", "below",
    "some", "more", "most", "other", "only", "same", "few",
    "both", "own", "such", "now", "like", "get", "make",
    "want", "need", "please", "using", "use",
  ]
}
