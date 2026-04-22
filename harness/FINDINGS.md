# Findings — durable methodology notes

Carried forward from Run 2026-04-21-phase2. Read before proposing a new
candidate. The per-run FINDINGS files live under `harness/runs/` (gitignored);
this doc captures only the insights that generalize.

## F1 — `Set<String>` iteration is non-deterministic

Swift's `Set` iteration order is hash-seed dependent and unstable across
process runs. `IntentMatcher.anchorWords` was being iterated to tiebreak
equal-distance typo anchors, which made `"git stauts"` flake between
`git_status` and `git_log` across otherwise-identical runs.

**Fix (shipped):** `anchorWordsSorted: [String]` maintained alongside the
Set; typo correction iterates the sorted array and tiebreaks equal
distances by `abs(anchor.count - token.count)` (prefer same-length matches,
biases toward transposition corrections — the most common typo class).

**Rule:** any new Set iteration that affects a ranking decision must either
sort before iteration or have a deterministic tiebreak.

## F2 — `addIntents` has global side effects; discriminators don't

Adding intents to any template mutates BM25/TF-IDF corpus statistics
globally — it changes IDF for every token in the new intent, which ripples
into unrelated queries. One curl_headers overlay caused
`"fetch https://example.com"` → `git_pull` because adding `"fetch headers only"`
shifted fetch-token IDF.

**Rule:** prefer `discriminators` + `negativeKeywords` for ranking fixes.
Only use `addIntents` with narrow, specific phrases whose component tokens
don't collide with common verbs (`fetch`, `show`, `list`, `get`…).

## F3 — Stacking disjoint wins is additive

18 independent single-case wins stacked exactly as 18/380 case improvements
(+4.74pp). Zero interaction breakage at `ok_tpl` level. The harness can be
driven greedily — find a win, stack, find the next, stack.

**Rule:** re-run the curated gate after each stack. Interactions are rare
at this scale but not zero (F11).

## F4 — Embeddings stay on by default

`useEmbeddings: false` trades −0.53pp `tpl_acc` for −93% p95 (1036ms → 70ms).
Consider exposing as a `--fast` CLI flag if latency matters for a use case;
not currently shipped.

## F5/F6 — Two failure classes require different tools

- **Ranking bugs** (gold in `bm25_top5`, wrong rank): fix with
  `discriminators` + `negativeKeywords`. 18 fixed in Phase 2.
- **Candidate-set bugs** (gold outside `bm25_top5`): need `addIntents` on
  the target template. Higher risk (F2). Only ~1-in-3 attempts land.

The F5/F6 ratio matters for estimating how much remaining tpl_acc is
reachable via overlay work vs. requires source edits / template rewrites.

## F7 — `naturalLanguageVerbs` guards need path-awareness

`"head main.swift"`, `"tail server.log"` were failing the command-prefix
fast-path because `head`/`tail` are in `naturalLanguageVerbs`. A blanket
skip is wrong when the 2nd token is a path / flag / filename.

**Fix (shipped):** `tokenLooksLikePathOrFlag(_:)` — recognises `-flag`,
`path/x`, `file.ext` (1-5 alphanumeric chars). Used to bypass the NL-verb
guard in 3+-word queries. Added a 2-word guard: "who is", "show me",
"find my" → natural language (skip); "which python3", "head main.swift" → CLI.

## F8 — Single-case deltas became signal only after F1

Pre-F1: any candidate delta under 3 cases was indistinguishable from
hash-seed noise. Post-F1: three consecutive runs of the same binary
produce bit-identical metrics. 0.26pp (1 case) is now reliable signal.

## F9 — `matchTopN` triples debug-path latency (deferred)

`includeDebugInfo: true` (set by `--trace-out`) triggers a secondary
`matchTopN` call that re-runs BM25/embedding work. Production (no debug)
is unaffected. Optimization: return `(winner, topN)` from a single pass —
deferred pending a clear user need.

## F10 — Strong single-candidate prefix matches must win over BM25

`tryCommandPrefixMatch` single-candidate direct match was returning
`templateScore: 0.9`; `matchInternal` allowed any BM25 > 3.0 to override.
`"which python3"` routed to `python_run` (BM25 5.61) instead of `which_cmd`
(prefix 0.9) even though the user explicitly invoked `which`.

**Fix (shipped):** direct match returns `templateScore: 1.0`; matchInternal
guards the BM25 override with `prefixResult.templateScore < 1.0`. Added
`"who"` to `naturalLanguageVerbs` to patch a `"who changed X"` →
`who_logged_in` regression discovered during this fix.

## F11 — Swift dictionary literals reject duplicate keys

When consolidating refinements, a template touched by multiple candidates
(e.g. `cp_file`, `python_http_server`) needs a single `TemplateOverlay`
entry with merged arrays. Dictionary literal duplicates crash at init
with `"Dictionary literal contains duplicate keys"`.

## F12 — `inferMatchPath` in stm-eval is a heuristic

After F10, `(cs=1.0, ts=1.0)` is ambiguous between `exact` and strong-prefix.
`per_path` reporting is therefore slightly muddled. Not critical — for
accurate path attribution, add an explicit `path` field to
`IntentMatchResult` or reserve `1.01` for strong-prefix.
