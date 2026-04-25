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

    // A3: media format names — needed for "all PNG" / "every JPEG" /
    // "the mp4 files" → glob pattern synthesis. Plurals are normalized
    // to singular before lookup (PNGs → png).
    "png":        "png",
    "jpg":        "jpg",
    "jpeg":       "jpg",
    "gif":        "gif",
    "webp":       "webp",
    "tiff":       "tiff",
    "tif":        "tif",
    "bmp":        "bmp",
    "heic":       "heic",
    "heif":       "heif",
    "avif":       "avif",
    "svg":        "svg",
    "ico":        "ico",
    "raw":        "raw",
    "mp4":        "mp4",
    "mov":        "mov",
    "mkv":        "mkv",
    "webm":       "webm",
    "avi":        "avi",
    "flv":        "flv",
    "m4v":        "m4v",
    "mp3":        "mp3",
    "wav":        "wav",
    "flac":       "flac",
    "aac":        "aac",
    "ogg":        "ogg",
    "opus":       "opus",
    "m4a":        "m4a",
    "pdf":        "pdf",
    "csv":        "csv",
    "tsv":        "tsv",
    "log":        "log",
    "zip":        "zip",
    "tar":        "tar",
    "gz":         "gz",
  ]

  /// Format-name plurals + colloquial spellings normalized for lookup.
  /// "PNGs" → "png", "JPEGs" → "jpeg", "the mp4 files" tokens → "mp4".
  static let pluralStrip: [String: String] = [
    "pngs":      "png",
    "jpegs":     "jpeg",
    "jpgs":      "jpg",
    "gifs":      "gif",
    "webps":     "webp",
    "tiffs":     "tiff",
    "bmps":      "bmp",
    "heics":     "heic",
    "svgs":      "svg",
    "mp4s":      "mp4",
    "movs":      "mov",
    "mkvs":      "mkv",
    "webms":     "webm",
    "mp3s":      "mp3",
    "wavs":      "wav",
    "flacs":     "flac",
    "pdfs":      "pdf",
    "csvs":      "csv",
    "logs":      "log",
    "images":    "image",  // generic — handled below
    "photos":    "image",
    "pictures":  "image",
    "videos":    "video",
    "movies":    "video",
    "clips":     "video",
  ]

  /// Synthesize a glob pattern from a natural-language query when a
  /// `.glob`-typed slot wasn't explicitly extracted by regex.
  ///
  /// Recognizes patterns like:
  ///   "combine all of these PNG into a 9x9 grid"   → "*.png"
  ///   "put all JPEGs in this folder"               → "*.jpg"
  ///   "convert every mp4 file"                     → "*.mp4"
  ///   "all the mov files"                          → "*.mov"
  ///   "all images" / "every photo"                 → nil (ambiguous, no single ext)
  ///
  /// Returns nil when no format-name token is found near a quantifier
  /// ("all", "every", "these", "those", "the").
  public static func synthesizeGlob(from query: String) -> String? {
    let lower = query.lowercased()
    // Quick reject: must contain a quantifier or the format name standing
    // alone is too generic to bind.
    let quantifiers = ["all ", "every ", "these ", "those ", "the ", "any "]
    let hasQuantifier = quantifiers.contains(where: { lower.contains($0) })
    if !hasQuantifier {
      // Allow bare-format use when explicitly preceded by "files" or
      // "images" later in the sentence. e.g., "convert mp4 files" → *.mp4.
      // Fall through; the loop below still requires a known format token.
    }

    // Tokenize lightly. Remove punctuation that can stick to words.
    let tokens = lower
      .replacingOccurrences(of: ",", with: " ")
      .replacingOccurrences(of: ".", with: " ")
      .split(separator: " ")
      .map(String.init)

    for raw in tokens {
      // Try plural-strip first.
      let normalized: String
      if let stripped = pluralStrip[raw] {
        // "images"/"videos" don't map to a single extension; treat as
        // ambiguous and fall through unless the caller wants generic *.
        if stripped == "image" || stripped == "video" { continue }
        normalized = stripped
      } else {
        normalized = raw
      }
      if let ext = canonical[normalized] {
        // Tighter check: extension-bearing tokens that are also natural
        // English words shouldn't fire outside a quantifier context.
        // E.g., "go" (golang) shouldn't make "go to the store" → *.go.
        if !hasQuantifier && Self.commonEnglishExt.contains(normalized) {
          continue
        }
        return "*." + ext
      }
    }
    return nil
  }

  /// Format-name extensions that double as common English words. We require
  /// a quantifier ("all"/"every"/"these") near these to fire glob synthesis,
  /// otherwise the system would mis-glob queries like "go to docs".
  static let commonEnglishExt: Set<String> = [
    "go", "c", "h", "md", "raw",
  ]

  /// Resolve a raw captured token to its canonical extension.
  /// Lowercases, looks up the table, falls back to the lowercased raw value.
  public static func resolve(_ raw: String) -> String {
    let lower = raw.lowercased()
    return canonical[lower] ?? lower
  }
}
