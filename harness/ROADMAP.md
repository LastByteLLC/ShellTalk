# ROADMAP — remaining ShellTalk work

Companion to `frontier.md` (shipped timeline), `FINDINGS.md` (durable
methodology), and `proposer.md` (candidate standing instructions). This
document covers **what's queued, deferred, or never**.

## Current frontier (2026-04-23)

Main at `c6d3a9b`: 443 cases, tpl_acc **0.9345**, cat_acc **0.9661**,
substr_acc **0.9593**, slot_acc **0.9667**, BM25 lane **0.790**.
Across three runs (fileext, wildtests, round-a) the session delivered
**+3.98pp tpl_acc / +0.76pp cat_acc** on the expanded set and
**+0.50pp tpl_acc** on the matched-curated 397 subset with **zero
regressions**.

## Taxonomy of remaining work

Every candidate in this codebase fixes one of four axes. A clean plan
organizes the work that way because each axis has a different tool.

| axis | tool | example |
|---|---|---|
| **A. Templates / slots** | new `CommandTemplate`, new `SlotType` | `find_size_range`, `.fileExtension` |
| **B. Routing / ranking** | `TemplateRefinements` overlay | `top_snapshot` negKw for "largest" |
| **C. Extraction / normalization** | slot regex + `sanitize` | `.relativeDays` unit conversion |
| **D. Architecture** | source edit in pipeline layers | confidence calibration, pipe synthesis |

**Most candidates touch exactly one axis.** The ones that span two
(e.g., Cand-002 added slot type + refinement) are legitimately larger.
Anything spanning three is a program, not a candidate.

## Greenlight filter

A candidate ships automatically if it meets all four:

1. **Signal** — at least one EvalCase fails today that this would pass.
2. **Blast radius ≤ low** — negativeKeywords / narrow addIntents (F2); new slot type additive only.
3. **Footprint ≤ 100 LOC** excluding tests.
4. **Generality ≥ few** — fixes at least 2-3 queries of the same pattern, not one-off hardcoding.

Anything failing ≥ one of these is deferred with a trigger (see Tier 3).

---

## Tier 1 — one-candidate fixes (queued)

Each row is a candidate-shaped task. Estimates assume post-F1 determinism
and familiarity with the harness loop.

| id | goal | axis | LOC | risk | target suite(s) |
|---|---|---|---:|---|---|
| ~~T1.1~~ | ~~Named-weekday date math (`since Monday`, `2 weeks ago` routing)~~ | C+B | ~70 | low | **Shipped `8aff863`** — WildTime 0.56 → 1.00 |
| ~~T1.2~~ | ~~`grep_search` wins on quoted-regex queries~~ | B | ~26 | low | **Shipped `18fed01`** — WildShellMetachars 0.33 → 1.00 |
| ~~T1.3~~ | ~~`.host` entity for bare domains (formalize)~~ | D-small | ~55 | low | **Shipped `7568281`** — 5 new EntityRecognizerTests, zero metric regression |
| ~~T1.4~~ | ~~Healing: common long→short flag corrections~~ | D-small | ~150 | low | **Shipped `93faa7e`** — 30+ GNU long→BSD short mappings, 4 new tests |
| ~~T1.5~~ | ~~`git_commit_push` + `build_and_test` compound templates~~ | A | ~40 | low | **Shipped `ecccc2d`** — Chained 0.67 → 1.00 |
| ~~T1.6~~ | ~~`awk_column` FILE slot: no-filename case emits `stdin` not `{FILE}`~~ | C | ~5 | low | **Shipped `ae6bb34`** — UX cleanup, no metric move |
| ~~T1.7~~ | ~~`.url` with query-string + fragment preservation~~ | B | ~19 | low | **Shipped `345385b`** — WildCompoundEntities 0.67 → 0.83 |
| ~~T1.8~~ | ~~TerseWithFlags audit~~ | B+C | ~44 | low | **Shipped `dedca5f`** — TerseWithFlags 0.80 → 1.00 + global slot quote-strip |

**Sequencing**: all T1 candidates are independent of each other. Any can
be picked up in isolation. Recommended execution order by value density:
**T1.5 → T1.1 → T1.8 → T1.2 → T1.7 → T1.6 → T1.4 → T1.3**.

**Exit criterion for Tier 1**: stop when the marginal candidate lifts
tpl_acc by < 0.05pp (below post-F1 signal threshold, F8).

## Tier 2 — multi-candidate programs

Each is a 2-4 candidate sequence with its own design brief. Don't start
one mid-Tier-1 — they want a dedicated run name (e.g.
`harness/runs/2026-04-NN-multisource/`).

### ~~T2.1~~ — Multi-source slot extraction — **SHIPPED `287f12a`**

`SlotDefinition.multi: Bool` + allMatches extraction + new
`.commandFlag` slot type (empty entity-fallback) wired into cp_file
and mv_file. WildMultiSource 0.60 → 0.80 (4/5). Pre-existing FLAGS
slot bug fixed in passing.

### ~~T2.2~~ — Multi-word proper noun entity — **SHIPPED `0d56d71`**

T2.2a only (title-case chunker via regex, emits .directoryPath).
WildCompoundEntities 0.83 → 1.00. T2.2b (quote-aware tokenizer)
deferred — chunker alone was sufficient.

### ~~T2.3~~ — Time-range slots — **SHIPPED `c30762f`**

`find_mtime_range` + `git_log_date_range` templates, paired
START/END slot regex. WildTimeRanges new suite at 0.60 (3/5);
ISO-date and yesterday/today edge cases fall to existing templates
but produce semi-valid commands.

### ~~T2.4~~ — Structured-data format routing — **SHIPPED `3b26f5c`**

`yq_parse` template added (parallels `jq_parse`). Routing intents
on jq_parse + yq_parse for "process the X file" patterns.
WildDataFormats new suite at 1.00 (6/6). `usermod_group` negKw
compensation for cumulative ripple.

## Tier 3 — explicit defers (with revisit triggers)

Each has a concrete condition that would promote it to Tier 1/2.

| id | thing | deferred because | revisit when |
|---|---|---|---|
| T3.1 | First-class negation (`.excluded` entity) | Touches 10+ templates; marginal demand in WildNegations | 3+ distinct user-reported exclusion-query failures OR WildNegations drops to ≤ 33% after other fixes |
| T3.2 | Pipe synthesis (chained commands) | Violates STM's one-query-one-command determinism contract | Product decision to change the contract OR Chained suite drops to ≤ 50% after T1.5 compound-template approach |
| T3.3 | Confidence calibration (BM25 → probability) | No code path consumes calibrated values; Unknown suite isn't demand-justified at 40% | Adding confidence thresholds to routing gates OR external tool consuming `.confidence` |
| T3.4 | Quote-aware global tokenizer | BM25 corpus-wide perturbation risk; narrow fix in T1.2 may be sufficient | T1.2 proves insufficient AND ≥ 5 failing shell-metachar cases remain |
| T3.5 | LLM fallback for low-confidence matches | Architecturally opposed to STM's deterministic positioning | Explicit product pivot |
| T3.6 | Cross-platform extension (Windows PowerShell) | Separate product concern; no demand signal | Roadmap-level product decision |

## Cross-cutting concerns (every candidate checks)

- **F1** — sort any `Set` iteration that feeds a ranking decision.
- **F2** — prefer `discriminators` / `negativeKeywords`; each `addIntents` must be justified.
- **F3** — re-run the curated gate after every stack, not just once.
- **F8** — deltas < 0.05pp are noise; require multiple cases to claim a win.
- **F10** — strong prefix matches must outrank BM25 (score 1.0 vs score-based).
- **F11** — `TemplateOverlay` dictionary literals reject duplicate keys; consolidate per template.
- **Gold-label integrity** — updating an EvalCase's expected template is OK only when a new template genuinely changes what "correct" means (Cand-3 pattern). Never silently rewrite a failing case's expectation to pass.
- **Test mirroring** — when a fix stabilizes on the audit eval, mirror the passing cases into `STMAccuracyTests` so the gate will catch future regressions.

## Measurement framework

Per tier, what "success" looks like at the metrics level:

### Tier 1
- `tpl_acc` or `cat_acc` moves ≥ 0.10pp on 442+ set
- Or: one specific suite moves ≥ 10pp
- Zero regressions on any pre-existing suite

### Tier 2 (whole program)
- Suite-level improvement ≥ 30pp (a program shouldn't ship for a 10pp lift)
- New templates populate new path lane (exact/phrase/prefix) cleanly
- p95_ms within 10% of pre-program baseline

### Tier 3
- Not a metrics question — a product/architecture decision. When promoted, apply Tier 1/2 criteria.

## Proposer entry playbook

A fresh proposer picking this up should:

1. Read `frontier.md` + this doc's "current frontier" section.
2. Pick the highest-value Tier 1 item OR start a Tier 2 program.
3. For Tier 1: create `harness/cand/YYYY-MM-DD-<slug>/cand-N-<id>` branch, artifact dir, overlay (if applicable), run stm-eval, diff against latest main metrics, iterate until clean.
4. For Tier 2: create `harness/runs/YYYY-MM-DD-<program>/` and sequence candidates inside.
5. Gate with `swift test --filter STMAccuracy` before considering shipped.
6. Graduate via fast-forward merge to main; update `frontier.md` only on Pareto improvement; update this doc's Tier 1 table to strike completed items.
7. If stuck (3 consecutive gate failures), pause per proposer.md F5/F6 analysis.

## Open questions (need product-level answers)

These block some Tier 3 items but don't block Tier 1/2:

1. **Is pipe synthesis in scope?** Currently the STM contract says "one query → one command." The audit found 6 Chained cases where users want compound operations. T1.5 gives a per-pair template workaround. A yes on pipe synthesis unlocks T3.2.
2. **How ambitious is Unknown-suite handling?** 40% conversational-rejection is the weakest axis. Fixing it needs T3.3 (confidence calibration). If conversational queries aren't expected to reach ShellTalk at all, Unknown is fine at 40%.
3. **Is Linux parity on par with macOS for this work?** All recent candidates passed GNU/BSD splits via existing platform slots, but Tier 2 time-range and multi-source work should explicitly test on Linux. Docker CI path exists (`Dockerfile`); unclear if it's run.
