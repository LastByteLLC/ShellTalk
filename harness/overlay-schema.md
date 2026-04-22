# Overlay schema (`overlay.yaml`)

Small YAML document that mutates the matching pipeline without editing
source. Applied by `stm-eval --overlay` and by `STMPipeline.init` when
`SHELLTALK_OVERLAY_PATH` is set (curated test gate). Every field is
optional — empty overlay (`{}`) is the baseline.

```yaml
matcher:                    # optional; nil fields inherit MatcherConfig.default
  categoryThreshold: 0.5    # reject category matches below
  templateThreshold: 0.3    # reject template matches below
  topCategories: 3
  topTemplates: 5
  useEmbeddings: true       # macOS NLEmbedding rerank

bm25:                       # parsed + hashed but NOT yet runtime-applied;
  k1: 1.2                   # real BM25 tuning requires a source edit.
  b: 0.75

templates:
  git_status:
    addIntents:       ["whats changed"]       # appended to template intents
    negativeKeywords: ["diff"]                # penalize when in query
    discriminators:   ["status"]              # route command-prefix match here

notes: |                    # free-form; not applied to pipeline
  Hypothesis breadcrumb.
```

## Merge semantics

- `matcher` fields: scalar overwrite; nil = inherit.
- `addIntents`: appended in order.
- `negativeKeywords` / `discriminators`: union with existing; deduped.
- `bm25.k1/b`: recorded in `overlay_hash` but not applied (source edit needed).

## Hash

`metrics.json:overlay_hash` = first 16 hex of SHA-256 over sorted-keys JSON.
Equal hash ⇒ equivalent pipeline behavior; useful for deduplicating candidates.

## Gotchas

- `addIntents` rebuilds BM25/TF-IDF/exact/phrase indexes (cost: init time,
  not per-query). It also mutates **global** corpus statistics — prefer
  `discriminators` / `negativeKeywords` for surgical fixes. See F2 in `FINDINGS.md`.
- `useEmbeddings: false` on macOS skips NLEmbedding rerank — massive p95
  drop, small accuracy hit (~−0.5pp) on semantic queries.
- Overlay cannot *remove* intents / kws, or add a new template — those are
  source edits on a candidate branch.
