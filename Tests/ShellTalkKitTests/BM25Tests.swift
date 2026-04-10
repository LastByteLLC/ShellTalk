import Testing
@testable import ShellTalkKit

@Suite("BM25")
struct BM25Tests {

  @Test("Tokenize splits and lowercases")
  func tokenize() {
    let tokens = BM25.tokenize("Find all Swift files in the project")
    #expect(tokens.contains("find"))
    #expect(tokens.contains("swift"))
    #expect(tokens.contains("files"))
    #expect(tokens.contains("project"))
    // "all", "in", "the" are stop words — should be filtered
    #expect(!tokens.contains("all"))
    #expect(!tokens.contains("the"))
  }

  @Test("Tokenize filters single-char words")
  func tokenizeFiltersSingleChar() {
    let tokens = BM25.tokenize("a b cd efg")
    // Single chars are filtered (< 2)
    #expect(!tokens.contains("a"))
    #expect(!tokens.contains("b"))
    // 2+ char tokens are kept
    #expect(tokens.contains("cd"))
    #expect(tokens.contains("efg"))
  }

  @Test("Empty query returns no results")
  func emptyQuery() {
    let docs = [BM25Document(id: "1", text: "list files")]
    let index = BM25(documents: docs)
    let results = index.search("")
    #expect(results.isEmpty)
  }

  @Test("Exact match ranks highest")
  func exactMatch() {
    let docs = [
      BM25Document(id: "git_status", text: "show git status of the repository"),
      BM25Document(id: "git_log", text: "show git commit log history"),
      BM25Document(id: "ls_files", text: "list files in the directory"),
    ]
    let index = BM25(documents: docs)
    let results = index.search("git status")
    #expect(results.first?.documentId == "git_status")
  }

  @Test("Relevant documents score higher than irrelevant")
  func relevanceRanking() {
    let docs = [
      BM25Document(id: "find_files", text: "find files by name pattern glob search"),
      BM25Document(id: "grep_content", text: "search file contents text grep pattern"),
      BM25Document(id: "git_branch", text: "git branch create delete list switch"),
    ]
    let index = BM25(documents: docs)
    let results = index.search("find files matching a pattern")
    #expect(!results.isEmpty)
    #expect(results[0].documentId == "find_files")
  }

  @Test("TopK limits results")
  func topKLimit() {
    let docs = (0..<20).map { BM25Document(id: "doc\($0)", text: "common word test \($0)") }
    let index = BM25(documents: docs)
    let results = index.search("common word", topK: 5)
    #expect(results.count == 5)
  }

  @Test("Scores are positive for matches")
  func positiveScores() {
    let docs = [BM25Document(id: "1", text: "copy file from source to destination")]
    let index = BM25(documents: docs)
    let results = index.search("copy file")
    #expect(!results.isEmpty)
    #expect(results[0].score > 0)
  }

  @Test("No match returns empty")
  func noMatch() {
    let docs = [BM25Document(id: "1", text: "compile swift package")]
    let index = BM25(documents: docs)
    let results = index.search("kubernetes deploy pod")
    #expect(results.isEmpty)
  }

  @Test("Multi-word queries work")
  func multiWordQuery() {
    let docs = [
      BM25Document(id: "sed_replace", text: "replace text find substitute sed inplace file"),
      BM25Document(id: "mv_rename", text: "rename move file directory folder"),
      BM25Document(id: "grep_search", text: "search grep find text content pattern"),
    ]
    let index = BM25(documents: docs)
    let results = index.search("replace text in file")
    #expect(results.first?.documentId == "sed_replace")
  }

  @Test("IDF weights rare terms higher")
  func idfWeighting() {
    // "kubernetes" appears in only 1 doc, "file" appears in all 3
    let docs = [
      BM25Document(id: "k8s", text: "kubernetes deploy pod container file"),
      BM25Document(id: "copy", text: "copy file backup duplicate"),
      BM25Document(id: "edit", text: "edit file modify change"),
    ]
    let index = BM25(documents: docs)
    let results = index.search("kubernetes file")
    // k8s should rank first because "kubernetes" has high IDF
    #expect(results.first?.documentId == "k8s")
  }
}
