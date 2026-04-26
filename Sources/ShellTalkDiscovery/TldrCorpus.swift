// TldrCorpus.swift — Decoded tldr-pages corpus loaded from the embedded
// SwiftPM resource. Produced by harness/refresh-tldr-baseline.sh.
//
// tldr-pages content is licensed CC-BY-4.0:
//   https://github.com/tldr-pages/tldr/blob/main/LICENSE.md

import Foundation
import CZlib

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
    let jsonData = try gunzip(gzData)
    let decoder = JSONDecoder()
    return try decoder.decode(TldrCorpus.self, from: jsonData)
  }

  /// Decompress a gzip stream using libz. windowBits=47 (= MAX_WBITS + 32)
  /// asks zlib to auto-detect the gzip header, so we don't have to parse
  /// the FEXTRA / FNAME / FCOMMENT / FHCRC fields by hand.
  ///
  /// libz is universally available — macOS ships it in the SDK, every
  /// Linux distro ships it as zlib1g, and the swiftlang/swift Docker
  /// images include the dev headers. This is what lets the same code path
  /// work on macOS and Linux; an earlier revision used Apple's
  /// Compression.framework, which is Darwin-only and broke Linux CI.
  private static func gunzip(_ gzData: Data) throws -> Data {
    guard !gzData.isEmpty else { throw TldrCorpusError.decompressionFailed }

    var output = Data()
    var streamErr: Int32 = Z_OK

    gzData.withUnsafeBytes { (rawIn: UnsafeRawBufferPointer) in
      guard let inBase = rawIn.bindMemory(to: UInt8.self).baseAddress else {
        streamErr = Z_DATA_ERROR
        return
      }

      var strm = z_stream()
      strm.next_in = UnsafeMutablePointer(mutating: inBase)
      strm.avail_in = UInt32(gzData.count)

      // 47 = MAX_WBITS (15) + 32 → enable automatic zlib/gzip header detection.
      // ZLIB_VERSION + sizeof(z_stream) match what the zlib headers expect;
      // we go through inflateInit2_ since the inflateInit2 macro doesn't
      // bridge to Swift.
      let initResult = inflateInit2_(
        &strm, 47,
        ZLIB_VERSION,
        Int32(MemoryLayout<z_stream>.size)
      )
      guard initResult == Z_OK else {
        streamErr = initResult
        return
      }
      defer { inflateEnd(&strm) }

      // 256 KB chunks — the corpus expands to ~4.7 MB, so this is ~19
      // inflate iterations. Larger chunks would reduce overhead but also
      // grow the resident set; this is a fine middle.
      let chunkSize = 256 * 1024
      var chunk = [UInt8](repeating: 0, count: chunkSize)

      while true {
        let result: Int32 = chunk.withUnsafeMutableBufferPointer { buf in
          strm.next_out = buf.baseAddress
          strm.avail_out = UInt32(chunkSize)
          return inflate(&strm, Z_NO_FLUSH)
        }
        let written = chunkSize - Int(strm.avail_out)
        if written > 0 {
          output.append(contentsOf: chunk[0..<written])
        }
        if result == Z_STREAM_END {
          return
        }
        if result != Z_OK {
          streamErr = result
          return
        }
      }
    }

    if streamErr != Z_OK {
      throw TldrCorpusError.decompressionFailed
    }
    return output
  }
}
