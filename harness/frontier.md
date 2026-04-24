# Pareto frontier

| state | n_cases | tpl_acc | cat_acc | substr_acc | slot_acc | BM25 lane | p95_ms | notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| **shipped (main)** | **454** | **0.9692** | **0.9868** | **0.9748** | **0.9155** | **0.893** | 359 | Run 2026-04-24-tier-1-2: Tier 1 (T1.1-T1.8) + Tier 2 (T2.1-T2.4) shipped + post-Tier extras (conversational filter, wild-cleanup, healing diag). New slot types `.fileSize`/`.relativeDays`/`.commandFlag`; `.host` entity + multi-word proper-noun chunker; templates `git_commit_push`, `swift_build_and_test`, `find_mtime_range`, `git_log_date_range`, `yq_parse`; multi-source extraction; healing flag-correction map + permission-path hint + empty-stderr handling; STMPipeline conversational filter. **163 tests**. |
| pre-round-a wildtests shipped | 442 | 0.9321 | 0.9661 | 0.9574 | 0.9643 | 0.784 | 424 | Run 2026-04-23-wildtests: 5 candidates (routing, typo healing, range/no-merges templates, alternatives display). 31 refinements. |
| pre-tier1-2 round-a shipped | 443 | 0.9345 | 0.9661 | 0.9593 | 0.9667 | 0.790 | 680 | Run 2026-04-23-round-a: slot-extraction polish on top of wildtests. |
| pre-wildtests shipped | 397 | 0.9597 | 0.9849 | 0.9742 | 0.9592 | 0.850 | 389 | `.fileExtension` slot type + canonical alias table + find_by_extension routing (run 2026-04-23-fileext). 20 refinements. |
| pre-fileext shipped | 380 | 0.9500 | 0.9763 | — | — | 0.850 | 319 | 19 refinements + F1/F7/F10 source fixes. |
| original baseline | 380 | 0.8947 | 0.9421 | — | — | 0.687 | 1038 | Non-deterministic (F1 flake). |

Run 2026-04-23-wildtests added 45 new `Wild*` EvalCases probing real-world
NL patterns (time, negations, politeness, multi-source, compound entities,
ordinals, ranges, shell metachars, entity gaps). Headline on the expanded
442-case set: **+1.81pp tpl_acc, +1.13pp cat_acc, +5.32pp BM25 lane**
versus the audit baseline. Big per-suite wins: **WildRanges +67pp**,
**WildOrdinals +50pp**, **AmbiguousVO +20pp**. Healing also improved —
Levenshtein typo correction (`gti`→`git`) and timeout classification
distinct from network errors. `p95_ms` rose 389→424 because 3 new
templates added init-time work; per-query latency unchanged.

Run 2026-04-23-fileext added 17 new `FileExtensions` EvalCases, growing
the set 380 → 397. Slot-type canonicalization + routing refinements
delivered +1.26pp tpl_acc, +32.65pp slot_acc on the matched 397 set.

Append new rows only when a candidate is Pareto-improved on (`tpl_acc`, `p95_ms`)
AND the curated gate passes. Prune dominated rows on update.
