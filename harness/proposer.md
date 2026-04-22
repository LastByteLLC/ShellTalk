# Proposer — Standing instructions for Meta-Harness candidates

The contract for any iteration of the ShellTalk improvement loop. Inspired
by Meta-Harness (arxiv 2603.28052): an agentic proposer with filesystem
access to prior candidates' source, traces, and scores iteratively
discovers better harness configurations. Causal reasoning only emerges
when the proposer reads many prior attempts — compressed feedback loses
the signal needed to diagnose regressions.

`harness/runs/` is gitignored (local-only). Artifacts accumulate over time;
only the shipped state lives in source + `frontier.md`.

## Candidate = git branch + artifact directory

- **Git branch** `harness/cand/<run_id>/<candidate_id>` for any source edits.
- **Artifact dir** `harness/runs/<run_id>/<candidate_id>/`:
  `overlay.yaml`, `metrics.json`, `traces/eval.jsonl`, `notes.md`.

Naming: `<run_id>` = `YYYY-MM-DD-<slug>`, `<candidate_id>` = `cand-NNN-<slug>`.
Use descriptive slugs — `grep -r discriminator harness/runs/` replaces an index.

## The loop (execute in order)

1. **Orient.** `cat harness/frontier.md harness/runs/*/INDEX.md | tail -200`.
2. **Pick a failure class by evidence, not intuition:**
   `jq -r 'select(.ok_tpl==false) | .path' <best>/traces/eval.jsonl | sort | uniq -c | sort -rn`.
3. **Read ≥ 5 prior `notes.md`** + one trace diff before proposing.
4. **Write a one-paragraph hypothesis in `notes.md` BEFORE editing.** Format:
   "failing cases X/Y/Z share property P; change C fixes them without
   breaking class Q." No paragraph = no understanding — go back to step 3.
5. **One logical change per candidate.** `git diff --stat parent..HEAD` ≤ 50 lines.
   Overlay > source edits when both work.
6. **Build + evaluate:**
   ```
   swift build -c release --product stm-eval
   .build/release/stm-eval --quiet \
     --overlay    harness/runs/<run>/<cand>/overlay.yaml \
     --trace-out  harness/runs/<run>/<cand>/traces/eval.jsonl \
     --metrics-out harness/runs/<run>/<cand>/metrics.json
   ```
7. **Curated gate:**
   `SHELLTALK_OVERLAY_PATH=<overlay> swift test --filter STMAccuracy`.
   Any regression → non-mergeable, no exceptions.
8. **Append to run's `INDEX.md`.** Update `frontier.md` only on Pareto improvement.
9. **Retrospective** at bottom of `notes.md`: hypothesis hold? what surprised?
10. **Gate failure:** post-mortem, delete branch, move on. 3 consecutive → pause.

## Metrics axes

- `tpl_acc` (primary), `cat_acc`, `substr_acc`, `slot_acc`, `neg_acc`.
- `p95_ms` (cost axis; inflated 3× when `--trace-out` is set).
- `curated_pass` — **gate, not axis**. Zero tolerance.
- `per_path` ∈ {`exact`, `phrase`, `prefix`, `bm25`, `none`} — diagnoses which lane to target.
- `per_suite` — diagnoses which query class to target.

A `tpl_acc` win can mask a `per_suite` regression. **Always diff `per_path`
and `per_suite` before claiming a win.**

## Scope of edits

**Overlay** (preferred, see `overlay-schema.md`):
- Matcher thresholds, `useEmbeddings`.
- Per-template `discriminators`, `negativeKeywords`, `addIntents`.

**Source, on candidate branch only** (when overlay can't express it):
- Entity boosts, fast-path ordering, TF-IDF thresholds — `IntentMatcher.swift`.
- Phrase / concept-phrase index — `TemplateStore.swift`.
- New templates — `BuiltInTemplates.swift` (rare; first try extending intents).

**Never on main.** Winning changes go through a separate human-reviewed
cherry-pick. Validated refinements graduate into
`Sources/ShellTalkKit/Templates/TemplateRefinements.swift`.

## What NOT to do

- Don't run the 13k `intent_data.json` set in the loop — the 370 `STMEval.swift`
  EvalCases are dense enough; use the larger set for offline audits only.
- Don't edit EvalCases to make a candidate pass — surface wrong cases in
  `notes.md`, don't silently rewrite them.
- Don't cherry-pick across candidates mid-run. One candidate, one change, one metrics.json.
- Don't build dashboards or ranking binaries. The agent is the ranker;
  infra competes with that.

## Key prior findings

See `FINDINGS.md` for the durable methodological insights (F1–F12) carried
forward from Run 2026-04-21-phase2. At minimum, know:
- **F2:** prefer `discriminators` + `negativeKeywords` over `addIntents`.
- **F3:** stacking disjoint wins is additive; still re-run the gate after stacking.
- **F8:** single-case deltas are signal only after the F1 determinism fix.
