// Overlay.swift — YAML pipeline overlay for iterative harness search
//
// An overlay is a small YAML document that mutates the matching pipeline
// without editing source. It layers over MatcherConfig (thresholds, BM25
// parameters, topK values) and optionally extends individual templates
// (add intents, negative keywords, discriminators).
//
// Overlays are the primary experimental knob for Meta-Harness-style
// candidate search. Source-level edits go on candidate git branches;
// overlays live in `harness/runs/<run_id>/<candidate_id>/overlay.yaml`.

import Foundation
#if canImport(Yams)
import Yams
#endif

/// Per-template additive overlay.
public struct TemplateOverlay: Sendable, Codable {
  public let addIntents: [String]?
  public let negativeKeywords: [String]?
  public let discriminators: [String]?

  public init(
    addIntents: [String]? = nil,
    negativeKeywords: [String]? = nil,
    discriminators: [String]? = nil
  ) {
    self.addIntents = addIntents
    self.negativeKeywords = negativeKeywords
    self.discriminators = discriminators
  }
}

/// Overlay for MatcherConfig knobs. Nil fields keep the base value.
public struct MatcherOverlay: Sendable, Codable {
  public let categoryThreshold: Double?
  public let templateThreshold: Double?
  public let topCategories: Int?
  public let topTemplates: Int?
  public let useEmbeddings: Bool?

  public init(
    categoryThreshold: Double? = nil,
    templateThreshold: Double? = nil,
    topCategories: Int? = nil,
    topTemplates: Int? = nil,
    useEmbeddings: Bool? = nil
  ) {
    self.categoryThreshold = categoryThreshold
    self.templateThreshold = templateThreshold
    self.topCategories = topCategories
    self.topTemplates = topTemplates
    self.useEmbeddings = useEmbeddings
  }
}

/// BM25 tuning overlay (reserved — current BM25 uses hardcoded k1/b).
/// Kept in the schema so candidates can record intent even before wiring.
public struct BM25Overlay: Sendable, Codable {
  public let k1: Double?
  public let b: Double?

  public init(k1: Double? = nil, b: Double? = nil) {
    self.k1 = k1
    self.b = b
  }
}

/// Top-level overlay document. Every field is optional — an empty overlay
/// is a valid "baseline" candidate.
public struct PipelineOverlay: Sendable, Codable {
  public let matcher: MatcherOverlay?
  public let bm25: BM25Overlay?
  public let templates: [String: TemplateOverlay]?
  public let notes: String?

  public init(
    matcher: MatcherOverlay? = nil,
    bm25: BM25Overlay? = nil,
    templates: [String: TemplateOverlay]? = nil,
    notes: String? = nil
  ) {
    self.matcher = matcher
    self.bm25 = bm25
    self.templates = templates
    self.notes = notes
  }

  /// Load an overlay from a YAML file. Returns nil if the file is missing
  /// or unparseable — callers should treat nil as "no overlay applied".
  #if canImport(Yams)
  public static func load(path: String) -> PipelineOverlay? {
    guard let data = try? String(contentsOfFile: path, encoding: .utf8),
          !data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }
    return try? YAMLDecoder().decode(PipelineOverlay.self, from: data)
  }
  #else
  public static func load(path: String) -> PipelineOverlay? { nil }
  #endif

  /// Merge this overlay into a MatcherConfig, returning a new config.
  public func apply(to base: MatcherConfig) -> MatcherConfig {
    MatcherConfig(
      categoryThreshold: matcher?.categoryThreshold ?? base.categoryThreshold,
      templateThreshold: matcher?.templateThreshold ?? base.templateThreshold,
      topCategories: matcher?.topCategories ?? base.topCategories,
      topTemplates: matcher?.topTemplates ?? base.topTemplates,
      useEmbeddings: matcher?.useEmbeddings ?? base.useEmbeddings
    )
  }

  /// Apply per-template overlays to a category list, returning new categories
  /// with modified templates. Templates not listed in the overlay pass through.
  public func apply(to categories: [TemplateCategory]) -> [TemplateCategory] {
    guard let templates, !templates.isEmpty else { return categories }

    return categories.map { category in
      let overlaidTemplates = category.templates.map { template -> CommandTemplate in
        guard let ov = templates[template.id] else { return template }

        let newIntents: [String] = template.intents + (ov.addIntents ?? [])
        let newNegatives: [String]? = mergeStringList(template.negativeKeywords, ov.negativeKeywords)
        let newDiscriminators: [String]? = mergeStringList(template.discriminators, ov.discriminators)

        return CommandTemplate(
          id: template.id,
          intents: newIntents,
          command: template.command,
          slots: template.slots,
          platformOverrides: template.platformOverrides,
          flags: template.flags,
          tags: template.tags,
          negativeKeywords: newNegatives,
          discriminators: newDiscriminators
        )
      }
      return TemplateCategory(
        id: category.id,
        name: category.name,
        description: category.description,
        templates: overlaidTemplates
      )
    }
  }

  /// Stable content hash (sha256 hex, first 16 chars) for recording in metrics.
  /// Returns "empty" for an overlay that merges to no-op.
  public func contentHash() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(self) else { return "unhashable" }
    return shortSHA256(data)
  }

  private func mergeStringList(_ base: [String]?, _ add: [String]?) -> [String]? {
    switch (base, add) {
    case (nil, nil): return nil
    case (let b?, nil): return b
    case (nil, let a?): return a.isEmpty ? nil : a
    case (let b?, let a?):
      var merged = b
      for item in a where !merged.contains(item) { merged.append(item) }
      return merged
    }
  }
}

// MARK: - Lightweight SHA-256 (avoids pulling CryptoKit on Linux)

private func shortSHA256(_ data: Data) -> String {
  // Minimal SHA-256 implementation — overlays are tiny so performance is
  // irrelevant; this is just for a stable identifier in metrics.json.
  var h: [UInt32] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  ]
  let k: [UInt32] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ]

  var bytes = Array(data)
  let originalBitLen = UInt64(bytes.count) * 8
  bytes.append(0x80)
  while bytes.count % 64 != 56 { bytes.append(0) }
  for i in (0..<8).reversed() { bytes.append(UInt8((originalBitLen >> (UInt64(i) * 8)) & 0xff)) }

  for chunkStart in stride(from: 0, to: bytes.count, by: 64) {
    var w = [UInt32](repeating: 0, count: 64)
    for i in 0..<16 {
      let base = chunkStart + i * 4
      w[i] = UInt32(bytes[base]) << 24 | UInt32(bytes[base + 1]) << 16
        | UInt32(bytes[base + 2]) << 8 | UInt32(bytes[base + 3])
    }
    for i in 16..<64 {
      let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
      let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
      w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
    }

    var a = h[0], b = h[1], c = h[2], d = h[3]
    var e = h[4], f = h[5], g = h[6], hh = h[7]

    for i in 0..<64 {
      let S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
      let ch = (e & f) ^ (~e & g)
      let temp1 = hh &+ S1 &+ ch &+ k[i] &+ w[i]
      let S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
      let mj = (a & b) ^ (a & c) ^ (b & c)
      let temp2 = S0 &+ mj

      hh = g; g = f; f = e; e = d &+ temp1
      d = c; c = b; b = a; a = temp1 &+ temp2
    }

    h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
    h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
  }

  return h.prefix(2).map { String(format: "%08x", $0) }.joined()
}

private func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
  (x >> n) | (x << (32 - n))
}
