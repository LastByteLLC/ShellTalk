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
///
/// The underlying `NLEmbedding.sentenceEmbedding(for:)` load is ~200 ms.
/// To avoid paying that cost for CLI queries that resolve via fast-path
/// (exact match, phrase match, command prefix) and never need embedding
/// rerank, the model is loaded lazily on first `embed(_:)` call. Thread-
/// safe via an internal lock.
public final class NLEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
  private let language: NLLanguage
  private let lock = NSLock()
  private var loaded = false
  private var embedding: NLEmbedding?

  public init(language: NLLanguage = .english) {
    self.language = language
  }

  /// Returns the NLEmbedding model, loading it on first access. Returns
  /// nil if the model isn't available on this OS/version.
  private func loadedEmbedding() -> NLEmbedding? {
    lock.lock()
    defer { lock.unlock() }
    if !loaded {
      embedding = NLEmbedding.sentenceEmbedding(for: language)
      loaded = true
    }
    return embedding
  }

  public func embed(_ text: String) -> [Float]? {
    guard let e = loadedEmbedding() else { return nil }
    guard let vector = e.vector(for: text) else { return nil }
    return vector.map(Float.init)
  }

  /// Sentence-embedding dimension is fixed at 512 by the macOS NL framework.
  /// Reported without triggering a model load.
  public var dimensions: Int { 512 }

  /// Returns `true` optimistically to avoid forcing a model load just to
  /// check availability. Callers should treat a `nil` result from
  /// `embed(_:)` as the authoritative "not available" signal — that path
  /// is already in use at every call site.
  public var isAvailable: Bool { true }

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
/// On macOS/iOS the NLEmbedding provider is returned lazily — its model
/// load is deferred until first use so CLI fast-path queries pay nothing.
public func makeEmbeddingProvider() -> any EmbeddingProvider {
  #if canImport(NaturalLanguage)
  return NLEmbeddingProvider()
  #else
  return NullEmbeddingProvider()
  #endif
}
