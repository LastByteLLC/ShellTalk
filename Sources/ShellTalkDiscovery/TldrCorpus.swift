// TldrCorpus.swift — Decoded tldr-pages corpus loaded from the embedded
// SwiftPM resource. Produced by harness/refresh-tldr-baseline.sh.
//
// tldr-pages content is licensed CC-BY-4.0:
//   https://github.com/tldr-pages/tldr/blob/main/LICENSE.md

import Foundation

/// One example from a tldr page — a (description, command) pair where
/// `command` may contain `{{placeholder}}` tokens that the synthesizer
/// substitutes with query-derived values.
public struct TldrExample: Sendable, Codable {
  public let description: String
  public let command: String
}

/// One tldr page — a single tool with its short description and a list of
/// usage examples.
public struct TldrPage: Sendable, Codable {
  public let name: String
  public let description: String
  public let examples: [TldrExample]
}

/// The full embedded tldr-pages corpus.
public struct TldrCorpus: Sendable, Codable {
  public let schemaVersion: Int
  public let tldrPagesCommit: String
  public let tldrPagesDate: String
  public let license: String
  public let licenseUrl: String
  public let pageCount: Int
  public let pages: [TldrPage]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case tldrPagesCommit = "tldr_pages_commit"
    case tldrPagesDate = "tldr_pages_date"
    case license
    case licenseUrl = "license_url"
    case pageCount = "page_count"
    case pages
  }
}

enum TldrCorpusError: Error {
  case resourceMissing
  case decompressionFailed
  case decodeFailed(Error)
}

/// Loads and decodes the embedded baseline corpus on first access.
/// Subsequent access is O(1). The decompression cost (~5 ms on a current
/// Mac) is paid lazily so processes that never invoke discovery don't pay
/// for it.
public enum EmbeddedTldrCorpus {

  /// nonisolated(unsafe) is correct: we mutate `cached` exactly once
  /// behind a barrier and treat it as set-and-publish thereafter.
  nonisolated(unsafe) private static var cached: Result<TldrCorpus, TldrCorpusError>?
  private static let lock = NSLock()

  public static func load() throws -> TldrCorpus {
    lock.lock(); defer { lock.unlock() }
    if let cached {
      switch cached {
      case .success(let c): return c
      case .failure(let e): throw e
      }
    }
    do {
      let corpus = try decode()
      cached = .success(corpus)
      return corpus
    } catch let err as TldrCorpusError {
      cached = .failure(err)
      throw err
    } catch {
      let wrapped = TldrCorpusError.decodeFailed(error)
      cached = .failure(wrapped)
      throw wrapped
    }
  }

  private static func decode() throws -> TldrCorpus {
    guard let url = Bundle.module.url(
      forResource: "tldr-baseline.json",
      withExtension: "gz"
    ) else {
      throw TldrCorpusError.resourceMissing
    }
    let gzData = try Data(contentsOf: url)
    let jsonData: Data
    if #available(macOS 10.15, iOS 13.0, *) {
      // NSData / Data exposes `decompressed(using:)` on Apple platforms;
      // .zlib expects raw deflate, so we use the gzip-compatible path
      // via Compression framework wrapper.
      jsonData = try gunzip(gzData)
    } else {
      throw TldrCorpusError.decompressionFailed
    }
    let decoder = JSONDecoder()
    return try decoder.decode(TldrCorpus.self, from: jsonData)
  }

  /// Decompress a gzip stream. Foundation's NSData.decompressed(using:)
  /// wants raw deflate, not gzip; we use the Compression framework to
  /// handle the gzip header.
  private static func gunzip(_ gzData: Data) throws -> Data {
    return try gzData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Data in
      guard let src = raw.bindMemory(to: UInt8.self).baseAddress else {
        throw TldrCorpusError.decompressionFailed
      }
      // Allocate a destination buffer. The corpus expands ~4.5×; size
      // generously to avoid a second pass.
      let cap = max(gzData.count * 8, 8 * 1024 * 1024)
      let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: cap)
      defer { dst.deallocate() }

      // COMPRESSION_ZLIB consumes raw deflate; we strip the gzip header
      // (10 bytes) + footer (8 bytes) and feed the deflate stream.
      // gzip header structure: 0x1f 0x8b 0x08 [flags] 4×mtime 1×xfl 1×os
      guard gzData.count > 18,
            gzData[0] == 0x1f, gzData[1] == 0x8b, gzData[2] == 0x08
      else {
        throw TldrCorpusError.decompressionFailed
      }
      let flags = gzData[3]
      var headerLen = 10
      // FEXTRA (bit 2): 2-byte length + payload
      if flags & 0x04 != 0 {
        guard gzData.count > headerLen + 2 else { throw TldrCorpusError.decompressionFailed }
        let xlen = Int(gzData[headerLen]) | (Int(gzData[headerLen + 1]) << 8)
        headerLen += 2 + xlen
      }
      // FNAME (bit 3) and FCOMMENT (bit 4): null-terminated strings
      if flags & 0x08 != 0 {
        while headerLen < gzData.count, gzData[headerLen] != 0 { headerLen += 1 }
        headerLen += 1
      }
      if flags & 0x10 != 0 {
        while headerLen < gzData.count, gzData[headerLen] != 0 { headerLen += 1 }
        headerLen += 1
      }
      // FHCRC (bit 1): 2-byte header CRC
      if flags & 0x02 != 0 { headerLen += 2 }
      let footerLen = 8
      guard headerLen + footerLen < gzData.count else {
        throw TldrCorpusError.decompressionFailed
      }
      let deflateLen = gzData.count - headerLen - footerLen
      let deflateStart = src.advanced(by: headerLen)

      #if canImport(Compression)
      let written = compression_decode_buffer(
        dst, cap,
        deflateStart, deflateLen,
        nil,
        COMPRESSION_ZLIB
      )
      guard written > 0 else { throw TldrCorpusError.decompressionFailed }
      return Data(bytes: dst, count: written)
      #else
      throw TldrCorpusError.decompressionFailed
      #endif
    }
  }
}

#if canImport(Compression)
import Compression
#endif
