// TemplateRefinements.swift — Shipped overlay of validated matching refinements
//
// Each refinement was validated by the Meta-Harness loop
// (`harness/runs/2026-04-21-phase2/`). Each entry moved at least one failing
// curated EvalCase to a correct match without regressing others, and the
// combined stack (cand-043) passes `STMAccuracyTests` with a +4.74pp
// template-accuracy gain (0.8947 → 0.9421) over the raw `BuiltInTemplates.all`
// baseline.
//
// New refinements should be added here ONLY after they are:
//   1. Validated by an overlay experiment in `harness/runs/*`.
//   2. Shown to stack cleanly with the existing refinements.
//   3. Passing `swift test --filter STMAccuracy`.
//
// Refinements prefer `discriminators` and `negativeKeywords` over
// `addIntents` because intent changes perturb global BM25/TF-IDF/anchor-word
// statistics (see F1 in FINDINGS.md). A few queries still need `addIntents`
// because their target tokens conflict with `naturalLanguageVerbs` or prefix
// guards; these are clearly marked.
//
// Dictionary keys must be unique — consolidate all tweaks for a single
// template into one `TemplateOverlay` entry. Comments to the right of each
// entry list the candidate runs it derives from.

import Foundation

/// Built-in pipeline refinements shipped with the library.
/// Applied by `TemplateStore.builtIn()` before constructing the store.
public enum TemplateRefinements {
  public static let defaultOverlay: PipelineOverlay = PipelineOverlay(
    matcher: nil,
    bm25: nil,
    templates: [
      // ───── file_ops ────────────────────────────────────────────────
      "mv_file": TemplateOverlay(
        discriminators: ["rename"]                                       // cand-001
      ),
      "cp_file": TemplateOverlay(
        negativeKeywords: ["rename", "diff"]                             // cand-001, cand-027
      ),
      "rm_file": TemplateOverlay(
        discriminators: ["delete", "remove", "trash", "erase", "old"]    // cand-019
      ),
      "find_and_delete": TemplateOverlay(
        negativeKeywords: ["old"],                                       // cand-019
        discriminators: ["find"]
      ),
      "symlink": TemplateOverlay(
        discriminators: ["ln", "-s", "symlink"]                          // cand-006
      ),
      "make_target": TemplateOverlay(
        negativeKeywords: ["ln", "-s", "symlink"]                        // cand-006
      ),
      "diff_files": TemplateOverlay(
        addIntents: ["diff FILE FILE"],                                  // cand-027
        negativeKeywords: ["changes"],                                   // cand-007
        discriminators: ["diff", "compare"]
      ),
      "chown_owner": TemplateOverlay(
        discriminators: ["chown", "owner", "ownership"]                  // cand-028
      ),
      "chmod_perms": TemplateOverlay(
        discriminators: ["chmod", "755", "644", "777", "permissions"]    // cand-002
      ),
      "chmod_executable": TemplateOverlay(
        discriminators: ["chmod", "+x", "executable"]                    // cand-040
      ),
      "head_file": TemplateOverlay(
        addIntents: ["head FILE"],                                       // cand-020
        discriminators: ["head"]
      ),

      // ───── text_processing ─────────────────────────────────────────
      "sed_replace": TemplateOverlay(
        discriminators: ["substitute", "replace"]                        // cand-009
      ),
      "awk_column": TemplateOverlay(
        discriminators: ["awk", "column"]                                // cand-010
      ),
      "cut_columns": TemplateOverlay(
        negativeKeywords: ["extract"]                                    // cand-010
      ),

      // ───── git ─────────────────────────────────────────────────────
      "git_diff": TemplateOverlay(
        discriminators: ["compare", "changes"]                           // cand-007
      ),
      "git_log": TemplateOverlay(
        addIntents: ["last N commits", "recent commits on branch"],      // cand-033
        discriminators: ["commits", "10", "5", "last"]
      ),
      "git_branch_list": TemplateOverlay(
        negativeKeywords: ["commits", "see"]                             // cand-033
      ),
      "git_rebase": TemplateOverlay(
        negativeKeywords: ["head"]                                       // cand-020
      ),

      // ───── dev_tools / cloud ───────────────────────────────────────
      "docker_run": TemplateOverlay(
        addIntents: ["docker run IMAGE"],                                // cand-021
        discriminators: ["run"]
      ),
      "service_restart": TemplateOverlay(
        negativeKeywords: ["docker", "run"]                              // cand-021
      ),
      "serverless_deploy": TemplateOverlay(
        negativeKeywords: ["chmod", "+x"]                                // cand-040
      ),
      "sam_deploy": TemplateOverlay(
        negativeKeywords: ["chmod", "+x"]                                // cand-040
      ),
      "wrangler_deploy": TemplateOverlay(
        negativeKeywords: ["chmod", "+x"]                                // cand-040
      ),

      // ───── network ─────────────────────────────────────────────────
      "dig_lookup": TemplateOverlay(
        discriminators: ["dns", "lookup", "dig"]                         // cand-023
      ),
      "host_lookup": TemplateOverlay(
        negativeKeywords: ["dns"]                                        // cand-023
      ),
      "ping_host": TemplateOverlay(
        discriminators: ["check", "reach", "server"]                     // cand-035
      ),
      "python_http_server": TemplateOverlay(
        negativeKeywords: [
          "chmod", "755", "server.sh",           // cand-002
          "substitute", "replace", "with",       // cand-009
          "check",                                // cand-035
        ]
      ),
      "curl_post_json": TemplateOverlay(
        negativeKeywords: ["chown"]                                      // cand-028
      ),
      "curl_headers": TemplateOverlay(
        // Narrow addIntents to avoid collision with git_fetch semantics —
        // dropped "fetch headers only" which was regressing "fetch URL" queries.
        addIntents: ["curl -sI URL", "show http response headers"],      // cand-053 (trimmed)
        discriminators: ["-sI", "-I", "headers"]
      ),
      "curl_auth": TemplateOverlay(
        negativeKeywords: ["-sI", "-I", "headers"]                       // cand-053
      ),
      "openssl_check": TemplateOverlay(
        negativeKeywords: ["-sI", "headers"]                             // cand-053
      ),

      // ───── media ───────────────────────────────────────────────────
      "ffmpeg_info": TemplateOverlay(
        discriminators: ["info", "metadata", "probe"]                    // cand-024
      ),
      "ffmpeg_trim": TemplateOverlay(
        negativeKeywords: ["info", "metadata"]                           // cand-024
      ),

      // ───── system / shell ──────────────────────────────────────────
      "command_substitution": TemplateOverlay(
        addIntents: ["capture output of CMD"],                           // cand-025
        discriminators: ["capture", "output"]
      ),
      "date_show": TemplateOverlay(
        negativeKeywords: ["capture", "output"]                          // cand-025
      ),
      "df_disk_free": TemplateOverlay(
        discriminators: ["disk", "info", "free"]                         // cand-036
      ),
      "du_disk_usage": TemplateOverlay(
        negativeKeywords: ["info"]                                       // cand-036
      ),
    ],
    notes: nil
  )
}
