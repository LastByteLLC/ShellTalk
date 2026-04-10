import Testing
@testable import ShellTalkKit

@Suite("IntentMatcher")
struct IntentMatcherTests {

  let store = TemplateStore.builtIn()

  @Test("Matches git status query")
  func gitStatus() {
    let matcher = IntentMatcher(store: store, config: .default)
    let result = matcher.match("show git status")
    #expect(result != nil)
    #expect(result?.templateId == "git_status")
    #expect(result?.categoryId == "git")
  }

  @Test("Matches find files query")
  func findFiles() {
    let matcher = IntentMatcher(store: store, config: .default)
    let result = matcher.match("find all swift files")
    #expect(result != nil)
    #expect(result?.categoryId == "file_ops")
  }

  @Test("Matches grep search query")
  func grepSearch() {
    let matcher = IntentMatcher(store: store, config: .default)
    let result = matcher.match("search for TODO in files")
    #expect(result != nil)
    #expect(result?.categoryId == "text_processing")
  }

  @Test("Matches sed replace query")
  func sedReplace() {
    let matcher = IntentMatcher(store: store, config: .default)
    let result = matcher.match("sed replace foo with bar in file")
    #expect(result != nil)
    #expect(result?.templateId == "sed_replace")
  }

  @Test("Matches commit query")
  func gitCommit() {
    let matcher = IntentMatcher(store: store, config: .default)
    let result = matcher.match("commit changes with message fix auth bug")
    #expect(result != nil)
    #expect(result?.categoryId == "git")
  }

  @Test("Returns nil for gibberish")
  func gibberish() {
    let matcher = IntentMatcher(store: store, config: .default)
    let result = matcher.match("xyzzy plugh")
    // Should return nil or very low confidence
    if let result {
      #expect(result.confidence < 0.5)
    }
  }

  @Test("Top-N returns multiple results")
  func topN() {
    let matcher = IntentMatcher(store: store, config: .default)
    let results = matcher.matchTopN("find files", n: 3)
    #expect(results.count >= 1)
    #expect(results.count <= 3)
  }

  @Test("Embedding reranking doesn't crash")
  func embeddingReranking() {
    // Test with embeddings enabled (will use NLEmbedding on macOS, no-op on Linux)
    let config = MatcherConfig(
      categoryThreshold: 0.1,
      templateThreshold: 0.1,
      topCategories: 3,
      topTemplates: 5,
      useEmbeddings: true
    )
    let matcher = IntentMatcher(store: store, config: config)
    let result = matcher.match("list all files in the directory")
    #expect(result != nil)
  }
}
