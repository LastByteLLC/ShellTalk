// EmbeddingProvider.swift — Cross-platform embedding abstraction
//
// Protocol for vector embedding providers. On macOS, uses NLEmbedding.
// On Linux, falls back to BM25 (no embedding). Future: ONNX Runtime.

import Foundation

/// Protocol for embedding text into vector space for similarity search.
public protocol EmbeddingProvider: Sendable {
  /// Embed a text string into a vector. Returns nil if unavailable.
  func embed(_ text: String) -> [Float]?

  /// Embedding dimensionality.
  var dimensions: Int { get }

  /// Whether this provider is functional.
  var isAvailable: Bool { get }

  /// Provider name for debug output.
  var name: String { get }
}

/// Cosine similarity between two vectors.
public func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
  guard a.count == b.count, !a.isEmpty else { return 0 }
  var dot: Float = 0
  var normA: Float = 0
  var normB: Float = 0
  for i in 0..<a.count {
    dot += a[i] * b[i]
    normA += a[i] * a[i]
    normB += b[i] * b[i]
  }
  let denom = sqrt(normA) * sqrt(normB)
  return denom > 0 ? dot / denom : 0
}

// MARK: - macOS NLEmbedding Provider

#if canImport(NaturalLanguage)
import NaturalLanguage

/// NLEmbedding-based provider. Available on macOS 14+ / iOS 17+.
public final class NLEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
  private let embedding: NLEmbedding?

  public init(language: NLLanguage = .english) {
    self.embedding = NLEmbedding.sentenceEmbedding(for: language)
  }

  public func embed(_ text: String) -> [Float]? {
    guard let embedding else { return nil }
    guard let vector = embedding.vector(for: text) else { return nil }
    return vector.map(Float.init)
  }

  public var dimensions: Int {
    embedding != nil ? 512 : 0
  }

  public var isAvailable: Bool {
    embedding != nil
  }

  public var name: String { "NLEmbedding" }
}
#endif

// MARK: - Null Provider (Fallback)

/// No-op embedding provider for platforms without native embeddings.
public final class NullEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
  public init() {}

  public func embed(_ text: String) -> [Float]? { nil }
  public var dimensions: Int { 0 }
  public var isAvailable: Bool { false }
  public var name: String { "None" }
}

// MARK: - Factory

/// Create the best available embedding provider for the current platform.
public func makeEmbeddingProvider() -> any EmbeddingProvider {
  #if canImport(NaturalLanguage)
  let provider = NLEmbeddingProvider()
  if provider.isAvailable { return provider }
  #endif
  return NullEmbeddingProvider()
}
