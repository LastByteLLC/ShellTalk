// ShellTalkWASM.swift — WASM/WASI entry point for ShellTalk
//
// Reads natural language queries from stdin (one per line),
// outputs the generated shell command to stdout.
// Designed for both CLI-over-WASI usage and browser integration.
//
// Usage (WASI runtime):
//   echo "find swift files" | wasmtime shelltalk.wasm
//
// Protocol:
//   Input:  one query per line
//   Output: JSON per line: {"command":"...","template":"...","category":"...","confidence":0.95}
//   Error:  {"error":"no match","query":"..."}

import Foundation
import ShellTalkKit

@main
struct ShellTalkWASM {
  static func main() {
    let pipeline = STMPipeline()

    while let line = readLine() {
      let query = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !query.isEmpty else { continue }

      if let result = pipeline.process(query) {
        let json = formatResult(query: query, result: result)
        print(json)
      } else {
        print("{\"error\":\"no match\",\"query\":\"\(escapeJSON(query))\"}")
      }
      // Flush stdout for streaming consumers
      fflush(stdout)
    }
  }

  static func formatResult(query: String, result: PipelineResult) -> String {
    let safety: String
    if let v = result.validation {
      switch v.safetyLevel {
      case .safe: safety = "safe"
      case .caution: safety = "caution"
      case .dangerous: safety = "dangerous"
      }
    } else {
      safety = "safe"
    }

    return """
    {"command":"\(escapeJSON(result.command))","template":"\(result.templateId)","category":"\(result.categoryId)","confidence":\(String(format: "%.3f", result.confidence)),"safety":"\(safety)","query":"\(escapeJSON(query))"}
    """.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func escapeJSON(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
     .replacingOccurrences(of: "\n", with: "\\n")
     .replacingOccurrences(of: "\r", with: "\\r")
     .replacingOccurrences(of: "\t", with: "\\t")
  }
}
