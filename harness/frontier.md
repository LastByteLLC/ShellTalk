# Pareto frontier

| state | n_cases | tpl_acc | cat_acc | substr_acc | slot_acc | BM25 lane | p95_ms | notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| **shipped (main)** | **397** | **0.9597** | **0.9849** | **0.9742** | **0.9592** | **0.850** | 389 | `.fileExtension` slot type + canonical alias table + find_by_extension routing refinement (run 2026-04-23-fileext, cand-001/002/003). 20 refinements in `TemplateRefinements.swift` + F1/F7/F10 source fixes. Deterministic. All 138 `swift test` pass. |
| pre-fileext shipped | 380 | 0.9500 | 0.9763 | — | — | 0.850 | 319 | 19 refinements + F1/F7/F10 source fixes. Superseded by run 2026-04-23-fileext. |
| original baseline | 380 | 0.8947 | 0.9421 | — | — | 0.687 | 1038 | Non-deterministic (F1 flake) — superseded. |

Run 2026-04-23-fileext added 17 new `FileExtensions` EvalCases, so the case
set grew from 380 → 397. On the matched 397-case baseline, the three
candidates delivered: **+1.26pp tpl_acc**, **+0.76pp cat_acc**,
**+4.17pp substr_acc**, **+32.65pp slot_acc**, zero suite regressions.
The `p95_ms` rose from 319 → 389 partly because the 17 new cases include
harder phrase-matching queries; per-path BM25 lane accuracy is unchanged.

Append new rows only when a candidate is Pareto-improved on (`tpl_acc`, `p95_ms`)
AND the curated gate passes. Prune dominated rows on update.
