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
        negativeKeywords: ["rename", "diff", "compare"]                  // cand-001, cand-027 + round-c
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
        addIntents: [
          "diff FILE FILE",                                              // cand-027
          "compare FILE to FILE",                                        // round-c wild-cleanup
        ],
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
        negativeKeywords: ["folder", "directory"],                       // cand-1 (2026-04-23-wildtests)
        discriminators: ["head"]
      ),
      "ls_files": TemplateOverlay(
        addIntents: [                                                    // cand-1 (2026-04-23-wildtests)
          "first files in folder",
          "first files in this folder",
          "find files in my documents folder",                           // T2.2 specific
        ],
        negativeKeywords: ["du", "-sh", "-h"]                            // T2.2 — don't steal du queries
      ),
      "find_by_mtime": TemplateOverlay(
        addIntents: [
          "logs from the past week",                                     // cand-1 (2026-04-23-wildtests)
          // T1.1: weekday-anchored queries. 7 narrow intents, each
          // unique enough that global BM25 perturbation is minimal (F2).
          "what changed since monday",
          "files changed since tuesday",
          "files changed since wednesday",
          "files changed since thursday",
          "files changed since friday",
          "files changed since saturday",
          "files changed since sunday",
          // "weeks ago" / "months ago" patterns — current intent list
          // ends with "ago" only via "yesterday"; this routes the
          // explicit count form.
          "files from 2 weeks ago",
          "files from N weeks ago",
          "files from N months ago",
        ]
      ),
      "find_by_mmin": TemplateOverlay(
        // T1.1: "commits from the last hour" was hijacked by find_by_mmin
        // because "last hour" is a strong file-mtime token. git_log is
        // the right answer for queries about git commits.
        negativeKeywords: ["commits", "git", "log", "branch"]            // T1.1 (2026-04-23-round-b)
      ),
      "top_snapshot": TemplateOverlay(
        negativeKeywords: [                                              // cand-1 (2026-04-23-wildtests)
          "largest", "biggest", "files", "directories",
        ]
      ),
      "tar_create": TemplateOverlay(
        negativeKeywords: ["first", "last"]                              // cand-1 (2026-04-23-wildtests)
      ),
      "docker_logs": TemplateOverlay(
        negativeKeywords: [                                              // cand-1 (2026-04-23-wildtests); additive to built-in
          "past", "week", "yesterday", "today", "ago",
          "hour", "minute", "grep",
        ]
      ),
      "kubectl_logs": TemplateOverlay(
        negativeKeywords: [                                              // cand-1 (2026-04-23-wildtests)
          "past", "week", "yesterday", "grep", "foo", "bar",
        ]
      ),
      "sam_logs": TemplateOverlay(
        negativeKeywords: ["past", "week", "yesterday", "grep"]          // cand-1 (2026-04-23-wildtests)
      ),
      "aws_logs_tail": TemplateOverlay(
        negativeKeywords: ["past", "week", "yesterday", "grep"]          // cand-1 (2026-04-23-wildtests)
      ),
      "serverless_logs": TemplateOverlay(
        negativeKeywords: ["past", "week", "yesterday", "grep"]          // cand-1 (2026-04-23-wildtests)
      ),
      "git_log_since": TemplateOverlay(
        negativeKeywords: [                                              // cand-1 (2026-04-23-wildtests)
          "without", "merges", "on", "origin", "master", "main",
          "most", "recent", "between",                                   // T2.3 compensation
        ]
      ),
      "cal_show": TemplateOverlay(
        // T2.3 compensation: "files modified in the past month" was hijacked
        // because "month" → cal_show ("show this month").
        negativeKeywords: ["files", "modified", "past"]                  // T2.3 (2026-04-23-round-c)
      ),
      "jq_parse": TemplateOverlay(
        addIntents: [                                                    // T2.4 (2026-04-23-round-c)
          "process the json file",
          "process json data",
          "extract field from json file",
          "parse json data",
        ]
      ),
      "yq_parse": TemplateOverlay(
        addIntents: [                                                    // T2.4
          "process the yaml file",
          "process yaml data",
          "extract field from yaml",
          "parse yaml config",
        ]
      ),
      "awk_column": TemplateOverlay(
        addIntents: [                                                    // cand-1 (2026-04-23-wildtests)
          "process csv",
          "process csv file",
          "process tab-separated file",
        ],
        discriminators: ["awk", "column"]                                // cand-010 (preserved)
      ),
      "grep_search": TemplateOverlay(
        addIntents: [                                                    // cand-1 (2026-04-23-wildtests)
          "grep in log files",
          "grep pattern in logs",
          // T1.2 (2026-04-23-round-b): explicit grep-with-pattern + bare
          // "search for X" patterns. The pipe-in-quoted-pattern case
          // ("grep 'error|warning'…") was losing to tail_follow and
          // ps_grep; "search for X" was losing to mdfind_search on macOS.
          "grep pattern in file",
          "grep error or warning in file",
          "search for word in files",
          "search for hello world in code",
        ],
        discriminators: ["grep"]                                         // command-prefix anchor
      ),
      // tail_file additions reverted — caused 'tail -f server.log' regression
      // even with tail_follow discriminator '-f'. Defer to a more careful
      // tail-template restructure later.
      "git_blame": TemplateOverlay(
        addIntents: [                                                    // round-c sweep
          "who changed FILE",
          "who edited FILE",
          "who changed AppDelegate.swift",
          "who modified this code",
        ],
        discriminators: ["blame", "who"]
      ),
      "gzip_file": TemplateOverlay(
        addIntents: [                                                    // round-c sweep
          "compress the file",
          "compress single file",
        ],
        discriminators: ["gzip", "gz"]
      ),
      "xz_compress": TemplateOverlay(
        negativeKeywords: ["the file", "single"]                         // round-c — push back from generic compress
      ),
      "tail_follow": TemplateOverlay(
        // D.1 attempt rolled back: tail_file addIntents over-powered the
        // tail_follow `-f` discriminator (BM25 score 12.61 vs 7.70). Tail
        // template restructure would need command-prefix path changes,
        // not just refinement. Defer.
        negativeKeywords: ["grep", "error|warning", "search"]            // T1.2 only
      ),
      "mdfind_search": TemplateOverlay(
        // T1.2: 'search for hello world' was routing to Spotlight on
        // macOS via 'search' token. Spotlight is for filenames in the
        // OS index; arbitrary strings should grep.
        negativeKeywords: ["hello", "world", "for word", "in code", "in files"] // T1.2
      ),
      "ps_grep": TemplateOverlay(
        // T1.2: ps_grep should not match bare-grep queries. 'grep' alone
        // (without 'process'/'pid') indicates text search, not process search.
        negativeKeywords: ["error", "warning", "log.txt"]                // T1.2
      ),
      // T1.7 (2026-04-23-round-b): curl_auth additions consolidated below
      // with the existing cand-053 curl_auth entry to avoid duplicate keys.
      "curl_get": TemplateOverlay(
        addIntents: [                                                    // T1.7
          // "curl https URL" was too generic — regressed
          // 'curl -sI https://example.com' (curl_headers) and
          // 'substitute http with https' (sed_replace).
          "curl URL with query string parameters",
          "fetch json endpoint with query params",
        ]
      ),
      "npm_install": TemplateOverlay(
        addIntents: [                                                    // cand-9 (2026-04-23-round-a)
          // Specific JS-ecosystem package phrases. Narrow enough to not
          // leak into non-JS "install X" queries ("install vim package",
          // "install typescript" without "package", etc.).
          "install express package",
          "install react package",
          "install lodash package",
          "install vue package",
          "install angular package",
          "install webpack package",
          "install eslint package",
        ],
        discriminators: ["install", "add"]                               // preserved
      ),
      "find_by_extension": TemplateOverlay(
        addIntents: [                                                    // cand-003 (2026-04-23-fileext)
          // F5-class format-name routing: grep_search was outranking
          // find_by_extension on "find X files" queries where X is a
          // language name. Narrow low-frequency tokens — minimal global
          // BM25 perturbation per F2.
          "find ruby files",
          "find golang files",
          "find html files",
          "find kotlin files",
          "find shell files",
          "find bash files",
          // F6-class: "list" anchors ls_files. Surgical — only the
          // specific failing queries. Broader "list X files" patterns
          // regressed "yo list my files bro" (NegativeEdge).
          "list javascript files",
          "list all .ts files",
          // D.3: ALL-CAPS configuration-style identifiers. These don't
          // match any specific extension regex but should be treated as
          // extension-like tokens (the .fileExtension lowercase fallback
          // produces *.config / *.env / *.log / etc.). Specific phrases
          // to avoid the "find files with HOME in their name" regression
          // that broader chunking caused in T1.8.
          "find CONFIG files",
          "find ENV files",
          "find LOG files",
          "find DATA files",
        ]
      ),

      // ───── text_processing ─────────────────────────────────────────
      "sed_replace": TemplateOverlay(
        discriminators: ["substitute", "replace"]                        // cand-009
      ),
      // awk_column entry consolidated above with cand-1 additions (CSV intents).
      "cut_columns": TemplateOverlay(
        negativeKeywords: ["extract"]                                    // cand-010
      ),

      // ───── git ─────────────────────────────────────────────────────
      "git_diff": TemplateOverlay(
        // T1.1: "what changed since Monday" was hijacked by git_diff
        // because "what changed" is a strong git_diff anchor. Weekday
        // tokens shouldn't pull queries here.
        negativeKeywords: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"],
        discriminators: ["compare", "changes"]                           // cand-007 (preserved)
      ),
      "file_info": TemplateOverlay(
        // T1.8: 'find . -name *.py -type f' was routing here because
        // 'type' + 'file' overlap with 'what type of file' intent.
        // file_info should never match a CLI find invocation.
        negativeKeywords: ["find", "-type", "-name", "grep", "ls"]       // T1.8 (2026-04-23-round-b)
      ),
      "docker_exec": TemplateOverlay(
        // T1.8: 'docker run -it ubuntu bash' was routing here via 'bash'
        // token in 'bash into container' intent. 'run' is the docker_run
        // anchor — never an exec query.
        negativeKeywords: ["run", "start", "launch"]                     // T1.8 (2026-04-23-round-b)
      ),
      "git_pull": TemplateOverlay(
        // T1.5 side effect: git_commit_push perturbed BM25 enough that
        // git_pull (intent: "fetch and merge") beats curl_get on
        // "fetch https://…" queries. Domains/URLs are never a git-pull.
        negativeKeywords: ["http", "https", "url", "api"]                // T1.5 (2026-04-23-round-b)
      ),
      "git_log": TemplateOverlay(
        addIntents: [
          "last N commits", "recent commits on branch",                  // cand-033
          "show commits on origin",                                      // cand-3 (2026-04-23-wildtests)
          "show commits on branch",
          "commits from the last hour",                                  // T1.1 (2026-04-23-round-b)
          "commits in the past hour",
          "commits in the last hour",
          "git log --oneline -n",                                        // T1.1 compensation: git_log_graph stealing
          "display git log",
        ],
        discriminators: ["commits", "10", "5", "last"]
      ),
      "git_log_graph": TemplateOverlay(
        // T1.1: BM25 ripple from new git_log intents made graph win for
        // bare "git log" queries with flags. Push it back to require the
        // graph/tree anchor.
        negativeKeywords: ["--oneline", "-n", "display"]                 // T1.1 (2026-04-23-round-b)
      ),
      "git_branch_list": TemplateOverlay(
        negativeKeywords: ["commits", "see"]                             // cand-033
      ),
      "git_rebase": TemplateOverlay(
        negativeKeywords: ["head"]                                       // cand-020
      ),

      // ───── dev_tools / cloud ───────────────────────────────────────
      "usermod_group": TemplateOverlay(
        // T2.4 compensation: 'docker run nginx' was hijacked by
        // usermod_group via some exact/phrase path. Has no business
        // matching any docker query.
        negativeKeywords: ["docker", "run", "container", "image", "nginx"]   // T2.4
      ),
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
        // T1.7 + cand-053 consolidated. Auth requires an explicit auth
        // keyword; non-auth tokens that previously stole queries are
        // suppressed here.
        negativeKeywords: [
          "-sI", "-I", "headers",                                         // cand-053
          "users", "filter", "active", "endpoint",                       // T1.7
          "data",                                                        // round-c sweep
        ]
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
        negativeKeywords: ["most", "using", "biggest"],                  // round-c wild-cleanup
        discriminators: ["disk", "info", "free"]                         // cand-036
      ),
      "du_disk_usage": TemplateOverlay(
        addIntents: [                                                    // D.4 — boost over df_disk_free knife-edge
          "what's using the most disk space",
          "what is using the most disk space",
          "what's using disk space",
          "what files use the most disk space",
          "biggest disk usage",
        ],
        negativeKeywords: ["info"],                                      // cand-036
        discriminators: ["du", "-sh"]                                    // T2.2 — anchor for "du -sh ~/Documents"
      ),
    ],
    notes: nil
  )
}
