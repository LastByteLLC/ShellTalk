import Testing
@testable import ShellTalkKit

@Suite("EmbeddingProvider")
struct EmbeddingProviderTests {

  @Test("Cosine similarity of identical vectors is 1")
  func identicalVectors() {
    let v: [Float] = [1.0, 2.0, 3.0]
    let sim = cosineSimilarity(v, v)
    #expect(abs(sim - 1.0) < 0.001)
  }

  @Test("Cosine similarity of orthogonal vectors is 0")
  func orthogonalVectors() {
    let a: [Float] = [1.0, 0.0, 0.0]
    let b: [Float] = [0.0, 1.0, 0.0]
    let sim = cosineSimilarity(a, b)
    #expect(abs(sim) < 0.001)
  }

  @Test("Cosine similarity of opposite vectors is -1")
  func oppositeVectors() {
    let a: [Float] = [1.0, 2.0, 3.0]
    let b: [Float] = [-1.0, -2.0, -3.0]
    let sim = cosineSimilarity(a, b)
    #expect(abs(sim + 1.0) < 0.001)
  }

  @Test("Cosine similarity of empty vectors is 0")
  func emptyVectors() {
    let sim = cosineSimilarity([], [])
    #expect(sim == 0)
  }

  @Test("Cosine similarity of mismatched lengths is 0")
  func mismatchedLengths() {
    let a: [Float] = [1.0, 2.0]
    let b: [Float] = [1.0, 2.0, 3.0]
    let sim = cosineSimilarity(a, b)
    #expect(sim == 0)
  }

  @Test("NullEmbeddingProvider returns nil")
  func nullProvider() {
    let provider = NullEmbeddingProvider()
    #expect(!provider.isAvailable)
    #expect(provider.embed("hello") == nil)
    #expect(provider.dimensions == 0)
  }

  @Test("makeEmbeddingProvider returns something")
  func factory() {
    let provider = makeEmbeddingProvider()
    // On macOS, should be NLEmbedding; on Linux, NullProvider
    #if canImport(NaturalLanguage)
    // NLEmbedding may or may not be available depending on OS version
    _ = provider.isAvailable
    #else
    #expect(!provider.isAvailable)
    #endif
    _ = provider.name
  }

  #if canImport(NaturalLanguage)
  @Test("NLEmbedding produces 512-dim vectors")
  func nlEmbeddingDimensions() {
    let provider = NLEmbeddingProvider()
    guard provider.isAvailable else { return }
    #expect(provider.dimensions == 512)
    let vec = provider.embed("find swift files")
    #expect(vec != nil)
    #expect(vec?.count == 512)
  }

  @Test("Similar queries have high cosine similarity")
  func semanticSimilarity() {
    let provider = NLEmbeddingProvider()
    guard provider.isAvailable else { return }
    guard let a = provider.embed("find all swift files"),
          let b = provider.embed("search for swift source files"),
          let c = provider.embed("deploy kubernetes cluster")
    else { return }

    let simAB = cosineSimilarity(a, b)
    let simAC = cosineSimilarity(a, c)
    // "find swift files" should be more similar to "search for swift source files"
    // than to "deploy kubernetes cluster"
    #expect(simAB > simAC, "Expected similar queries to score higher: AB=\(simAB) AC=\(simAC)")
  }
  #endif
}
