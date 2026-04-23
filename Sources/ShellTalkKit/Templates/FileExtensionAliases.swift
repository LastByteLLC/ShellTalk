// FileExtensionAliases.swift — Canonical mapping from format names to extensions.
//
// Consumed by SlotExtractor.sanitize when a slot is typed `.fileExtension`.
// Lookup is case-insensitive; unknown names fall through lowercased to
// avoid emitting mangled uppercase like '*.CONFIG'.
//
// Identity entries (swift→swift, html→html) are explicit — the table
// doubles as a list of formats we've verified work end-to-end.

import Foundation

public enum FileExtensionAliases {

  /// Canonical format-name → file-extension map. Keys MUST be lowercase.
  /// Values are the canonical on-disk extension without leading dot.
  public static let canonical: [String: String] = [
    // Aliases that differ from the format name
    "markdown":   "md",
    "javascript": "js",
    "typescript": "ts",
    "python":     "py",
    "ruby":       "rb",
    "golang":     "go",
    "rust":       "rs",
    "kotlin":     "kt",
    "csharp":     "cs",
    "shell":      "sh",
    "bash":       "sh",

    // Identity entries — format name already matches the on-disk extension.
    // Kept explicit as documentation of what's been verified.
    "swift":      "swift",
    "yaml":       "yaml",
    "json":       "json",
    "html":       "html",
    "css":        "css",
    "go":         "go",
    "java":       "java",
    "c":          "c",
    "h":          "h",
    "md":         "md",
    "js":         "js",
    "ts":         "ts",
    "py":         "py",
    "rb":         "rb",
    "rs":         "rs",
    "kt":         "kt",
    "cs":         "cs",
    "sh":         "sh",
    "xml":        "xml",
    "toml":       "toml",
    "txt":        "txt",
    "sql":        "sql",
    "php":        "php",
    "scss":       "scss",
    "sass":       "sass",
  ]

  /// Resolve a raw captured token to its canonical extension.
  /// Lowercases, looks up the table, falls back to the lowercased raw value.
  public static func resolve(_ raw: String) -> String {
    let lower = raw.lowercased()
    return canonical[lower] ?? lower
  }
}
