# Pareto frontier

| state | tpl_acc | cat_acc | BM25 lane | p95_ms | notes |
|---|---:|---:|---:|---:|---|
| **shipped (main)** | **0.9500** | **0.9763** | 0.850 | 319 | 19 refinements in `TemplateRefinements.swift` + F1/F7/F10 source fixes. Deterministic. All 132 `swift test` pass. |
| original baseline | 0.8947 | 0.9421 | 0.687 | 1038 | Non-deterministic (F1 flake) — superseded. |

Net improvement: **+5.53pp `tpl_acc`**, **+3.42pp `cat_acc`**, **+16.3pp** on
the BM25 ranking lane. Determinism restored.

Append new rows only when a candidate is Pareto-improved on (`tpl_acc`, `p95_ms`)
AND the curated gate passes. Prune dominated rows on update.
