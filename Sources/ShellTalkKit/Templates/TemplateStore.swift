// TemplateStore.swift — Load, index, and search command templates
//
// Manages the template corpus. Templates can be loaded from:
// 1. Built-in YAML resources (shipped with the binary)
// 2. User-defined YAML files (~/.config/stm/templates/)

import Foundation
import Yams

/// Central store for all command templates, indexed for fast lookup.
public final class TemplateStore: Sendable {
  public let categories: [TemplateCategory]

  /// BM25 index over category descriptions (for category selection).
  public let categoryIndex: BM25

  /// Per-category BM25 indexes over template intents (for template selection).
  public let templateIndexes: [String: BM25]

  /// Quick lookup: template ID → (category ID, template).
  private let templateMap: [String: (String, CommandTemplate)]

  public init(categories: [TemplateCategory]) {
    self.categories = categories

    // Build category-level BM25 index
    let categoryDocs = categories.map { cat in
      // Combine category name, description, and all template intents for category matching
      let intentText = cat.templates.flatMap(\.intents).joined(separator: " ")
      return BM25Document(id: cat.id, text: "\(cat.name) \(cat.description) \(intentText)")
    }
    self.categoryIndex = BM25(documents: categoryDocs)

    // Build per-category template indexes
    var indexes: [String: BM25] = [:]
    for cat in categories {
      let docs = cat.templates.map { template in
        let text = template.intents.joined(separator: " ")
        return BM25Document(id: template.id, text: text)
      }
      indexes[cat.id] = BM25(documents: docs)
    }
    self.templateIndexes = indexes

    // Build flat lookup map
    var map: [String: (String, CommandTemplate)] = [:]
    for cat in categories {
      for template in cat.templates {
        map[template.id] = (cat.id, template)
      }
    }
    self.templateMap = map
  }

  /// Look up a template by ID.
  public func template(byId id: String) -> CommandTemplate? {
    templateMap[id]?.1
  }

  /// Get the category for a template ID.
  public func category(forTemplateId id: String) -> String? {
    templateMap[id]?.0
  }

  /// Find the best matching categories for a query.
  public func matchCategories(_ query: String, topK: Int = 3) -> [BM25Result] {
    categoryIndex.search(query, topK: topK)
  }

  /// Find the best matching templates within a specific category.
  public func matchTemplates(
    _ query: String, inCategory categoryId: String, topK: Int = 5
  ) -> [BM25Result] {
    guard let index = templateIndexes[categoryId] else { return [] }
    return index.search(query, topK: topK)
  }

  /// Total template count across all categories.
  public var templateCount: Int {
    categories.reduce(0) { $0 + $1.templates.count }
  }

  // MARK: - Loading from YAML

  /// Load categories from YAML strings.
  public static func fromYAML(_ yamlStrings: [String]) throws -> TemplateStore {
    var categories: [TemplateCategory] = []
    let decoder = YAMLDecoder()
    for yaml in yamlStrings {
      let category = try decoder.decode(TemplateCategory.self, from: yaml)
      categories.append(category)
    }
    return TemplateStore(categories: categories)
  }

  /// Load categories from YAML files in a directory.
  public static func fromDirectory(_ path: String) throws -> TemplateStore {
    let fm = FileManager.default
    let contents = try fm.contentsOfDirectory(atPath: path)
    let yamlFiles = contents.filter { $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") }

    var yamlStrings: [String] = []
    for file in yamlFiles.sorted() {
      let fullPath = (path as NSString).appendingPathComponent(file)
      let content = try String(contentsOfFile: fullPath, encoding: .utf8)
      yamlStrings.append(content)
    }

    return try fromYAML(yamlStrings)
  }

  /// Load from built-in templates bundled with the library.
  public static func builtIn() -> TemplateStore {
    TemplateStore(categories: BuiltInTemplates.all)
  }
}
