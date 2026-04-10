import Testing
@testable import ShellTalkKit

@Suite("TemplateStore")
struct TemplateStoreTests {

  @Test("Built-in store has templates")
  func builtInHasTemplates() {
    let store = TemplateStore.builtIn()
    #expect(store.categories.count == 12)
    #expect(store.templateCount > 150)
  }

  @Test("Category matching finds file_ops for file queries")
  func categoryMatchFileOps() {
    let store = TemplateStore.builtIn()
    let results = store.matchCategories("find swift files")
    #expect(!results.isEmpty)
    #expect(results[0].documentId == "file_ops")
  }

  @Test("Category matching finds git for git queries")
  func categoryMatchGit() {
    let store = TemplateStore.builtIn()
    let results = store.matchCategories("show commit history")
    #expect(!results.isEmpty)
    #expect(results[0].documentId == "git")
  }

  @Test("Category matching finds text_processing for grep queries")
  func categoryMatchText() {
    let store = TemplateStore.builtIn()
    let results = store.matchCategories("search for text in files")
    #expect(!results.isEmpty)
    #expect(results[0].documentId == "text_processing")
  }

  @Test("Template matching within category works")
  func templateMatchWithinCategory() {
    let store = TemplateStore.builtIn()
    let results = store.matchTemplates("git status", inCategory: "git")
    #expect(!results.isEmpty)
    #expect(results[0].documentId == "git_status")
  }

  @Test("Template lookup by ID")
  func templateLookup() {
    let store = TemplateStore.builtIn()
    let template = store.template(byId: "grep_search")
    #expect(template != nil)
    #expect(template?.command.contains("grep") == true)
  }

  @Test("Category for template ID")
  func categoryForTemplate() {
    let store = TemplateStore.builtIn()
    #expect(store.category(forTemplateId: "git_status") == "git")
    #expect(store.category(forTemplateId: "ls_files") == "file_ops")
    #expect(store.category(forTemplateId: "grep_search") == "text_processing")
  }

  @Test("Nonexistent template returns nil")
  func nonexistentTemplate() {
    let store = TemplateStore.builtIn()
    #expect(store.template(byId: "nonexistent") == nil)
  }

  @Test("sed_replace template found for replace query")
  func sedReplaceMatch() {
    let store = TemplateStore.builtIn()
    let results = store.matchTemplates("replace text find and replace", inCategory: "text_processing")
    #expect(!results.isEmpty)
    // sed_replace should be among top results
    let ids = results.map(\.documentId)
    #expect(ids.contains("sed_replace"))
  }
}
