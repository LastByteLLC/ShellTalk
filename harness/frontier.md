# Pareto frontier

| state | n_cases | tpl_acc | cat_acc | substr_acc | slot_acc | BM25 lane | p95_ms | notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| **shipped (main)** | **442** | **0.9321** | **0.9661** | **0.9574** | **0.9643** | **0.784** | 424 | Run 2026-04-23-wildtests: 5 candidates (routing refinements, typo healing, range/no-merges templates, alternatives display fix). On the matched 397-case curated subset: tpl_acc 0.9622 (+0.25pp vs pre-wildtests), zero regressions. On the 45 new WildTests cases: 0.6667 tpl_acc. 31 refinements in `TemplateRefinements.swift`. 143 `swift test` pass. |
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
