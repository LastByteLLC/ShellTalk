# Linux accuracy baseline + proposed experiments

Captured with `Tests/ShellTalkKitTests/LinuxBaselineTest.swift` on
**2026-04-24**, Swift 6.3-RELEASE, Ubuntu 24.04 LTS, `linux/arm64` Docker
Desktop on Apple Silicon. Three pooled runs per side.

## Headline baseline (macOS v1.2.0 vs Linux v1.2.0)

| metric | macOS | Linux | Δ |
|---|---:|---:|---:|
| **tpl_acc** | 0.9824 | **0.9604** | **−2.20 pp** |
| cat_acc | 0.9912 | 0.9736 | −1.76 pp |
| substr_acc | 0.9866 | 0.9648 | −2.18 pp |
| slot_acc | 0.9296 | 0.9296 | **0.00** |
| **neg_acc** | 1.0000 | **0.8750** | **−12.50 pp** |
| mean_ms | 10.70 | **0.57** | −94.7% |
| p50_ms | 3.15 | **0.27** | −91.4% |
| p90_ms | 31.38 | 1.01 | −96.8% |
| p99_ms | 117.09 | 5.22 | −95.5% |
| wall_ms | 4860 | **259** | −94.7% |
| init_ms | 59 | 38 | −35.5% |

**Bottom line**: Linux is ~**19× faster** with a **2.2 pp accuracy cost**,
concentrated in BM25-path queries where NLEmbedding rerank is absent on
Linux. Slot extraction is identical because it doesn't use embeddings.

## Where the gap lives

### Per-path

| path | n | macOS | Linux | Δ pp |
|---|---:|---:|---:|---:|
| bm25 | 120 | 0.933 | 0.883 | **−5.0** |
| phrase | 175 | 1.000 | 0.977 | **−2.3** |
| exact | 141 | 1.000 | 1.000 | 0.0 |
| prefix | 10 | 1.000 | 1.000 | 0.0 |
| none | 8 | 1.000 | 1.000 | 0.0 |

BM25 path: 6 new failures (5% × 120). Phrase path: 4 new failures
(2.3% × 175). Negative: 1 case leaks through.

### The 10 Linux-only regressions

```
[DevTools ]      bm25    conf=3.51  "docker run nginx"
    expected: docker_run           got: history_search

[FileOps  ]      bm25    conf=2.85  "file info for main.swift"
    expected: file_info            got: git_blame

[FileOps  ]      phrase  conf=0.95  "remove the old log files"
    expected: rm_file              got: find_by_extension

[Git      ]      phrase  conf=0.95  "show me what's different"
    expected: git_diff             got: diff_files

[MacOS    ]      bm25    conf=2.29  "open README.md"
    expected: open_file            got: lsof_open_files

[MacOS    ]      phrase  conf=0.95  "say hello world"
    expected: say_text             got: grep_search

[NegativeEdge]   bm25    conf=2.47  "what is the meaning of life"
    expected: _nil_                got: for_lines         (false-positive)

[Unknown  ]      bm25    conf=2.87  "flutter build apk"
    expected: docker_build         got: swift_build_and_test

[WildOrdinals]   bm25    conf=5.01  "show the top 3 largest files"
    expected: find_large_files     got: lsof_open_files

[WildPoliteness] phrase  conf=0.95  "I'd really appreciate if you could list python files"
    expected: find_by_extension    got: pip_list
```

### Pattern analysis

| Pattern | Cases | Root cause |
|---|---|---|
| Polysemous verb confusion | `open README.md`, `docker run nginx` | "open" / "run" appear in both correct + incorrect template intents; without rerank, lexical scoring ties or inverts |
| Compound concept dropped | `file info for`, `say hello world`, `show top 3 largest` | Individual words match multiple templates; a 2-gram phrase would discriminate — embeddings do this implicitly |
| Phrase-index override miss | 4 phrase-path cases | Phrase matched correctly at 0.95, but BM25 score > 5.0 overrode; rerank would have validated the phrase pick |
| Off-topic leak | `what is the meaning of life` | BM25 finds some match; confidence 2.47 exceeds the 0.3 filter threshold for negative tests |

## Proposed experiments (ranked by expected value × risk)

### Tier 1 — Low-risk, targeted, fast to verify

**E1. Tighten the BM25-over-phrase override** (closes up to 4 phrase-path failures)

Location: `IntentMatcher.swift:160-168`

```swift
if let phraseResult = tryPhraseMatch(normalized) {
  if let bm25 = bm25Result {
    let bm25Score = bm25.categoryScore * 0.3 + bm25.templateScore * 0.7
    if bm25Score > 5.0 && bm25.templateId != phraseResult.templateId {
      return bm25  // overrides phrase
    }
  }
  return phraseResult
}
```

**Change**: when embedding is unavailable (Linux / WASI), raise the override
threshold from 5.0 to 8.0. Rerank would have resolved this on macOS; without
rerank, trust the phrase index more. **Expected: +0.88 pp on tpl_acc.**

Risk: Some phrase-path queries that currently correctly override to
BM25 on Linux would stop overriding. Estimate: 1–2 cases regress, net +2 cases.

**E2. Gibberish guard — raise minimum confidence on BM25-only path** (closes 1 negative case)

Location: `IntentMatcher.bm25Match` end — currently rejects if `bestScore < 1.0`.
On Linux, raise to 1.5 when no rerank is available. **Expected: +0.22 pp on tpl_acc, +12.5 pp on neg_acc.**

Risk: Could reject some legitimate-but-weak BM25 matches. Sample
macOS's current low-confidence successes at the higher threshold before shipping.

### Tier 2 — Template-specific tweaks (closes 3–5 of the 6 BM25 cases)

**E3. Add `negativeKeywords` / `discriminators` to confusing templates**

- `lsof_open_files`: add `discriminators: ["lsof", "listening", "port", "process"]` — `open README.md` (no discriminator hits) then falls through.
- `history_search`: add `negativeKeywords: ["docker", "npm", "git"]` — `docker run nginx` doesn't leak to history.
- `git_blame`: add `negativeKeywords: ["info"]` — "file info" stays in file_info territory.
- `for_lines`: add `negativeKeywords: ["meaning", "what is", "why"]` — philosophical queries shouldn't match.

Cost: 4 small overlay entries in `TemplateRefinements.defaultOverlay`.
Must be validated against the full 454-case suite to ensure no regression on macOS.

**E4. Add `addIntents` for compound-concept cases**

- `file_info`: `["file info for NAME", "info about file"]`
- `say_text`: `["say something", "say hello"]`
- `open_file`: `["open FILENAME"]` with high specificity
- `find_large_files`: `["top N largest", "biggest N files"]`

### Tier 3 — Systemic

**E5. Boost TF-IDF weight in hybrid scoring when embedding unavailable**

Location: `IntentMatcher.bm25Match:569-576`

```swift
if let tfidfScore = tfidfScores[candidate.template.documentId], tfidfScore > 0.15 {
  let boost = 1.0 + Double(tfidfScore) * 0.5   // 0.5 factor
}
```

Change: when `embedding.isAvailable == false`, bump factor from 0.5 to 1.0.
TF-IDF captures some of what embeddings do (rare-token emphasis, concept
co-occurrence). Risk: could push wrong templates over the threshold. A/B.

**E6. Character-n-gram BM25 as a third lane**

Add a character-trigram BM25 index over template intents. Catches
morphology ("build"/"building"/"rebuild") that word-BM25 misses and
embeddings handle via subword tokens.

Cost: ~100 lines, new index at `TemplateStore` init, ~200 KB RAM.
Expected: +0.5–1.5 pp on tpl_acc across BM25 path. Applies to all
platforms including macOS.

### Tier 4 — Big lever

**E7. Pre-computed intent embeddings + cross-platform query embedder** (deferred Part 5.2)

- CI's macOS job dumps `Resources/intent-embeddings.bin` via NLEmbedding — 2000 phrases × 512-dim float16 ≈ 2 MB raw, ~600 KB brotli.
- At Linux runtime: load the blob; intent vectors are ready-made.
- For query embedding cross-platform: SimHash over BM25-tokens into the same dimensionality, OR ship a tiny pretrained word-vector table (~5–10 MB) for mean-pooling.

Expected: closes 80–100% of the Linux gap. Cost: ~300 lines + build step + resource management.

**E8. ONNX Runtime + MiniLM-L6-v2 int8** (heavy option)

Real transformer embeddings on Linux. +25 MB Linux binary. Full macOS-parity accuracy.

## Recommended path

Execute in order, re-measuring after each step:

1. **E1** (phrase override) — targeted, ~+0.9 pp, zero template touches.
2. **E2** (gibberish guard) — restores neg_acc.
3. **E3 + E4** (template polishes) — closes most of the BM25 6.
4. Re-measure. If residual gap is < 0.5 pp, stop.
5. **E6** (char n-grams) — helps macOS too.
6. Only if residual still > 1 pp after steps 1–5: consider **E5 / E7**.

Expected post-E1..E4: Linux tpl_acc **~0.975–0.98** (closing 85–90% of the gap) with no macOS regression.

## Reproducibility

```
# macOS (from repo root)
SHELLTALK_BASELINE_JSON=/tmp/baseline-macos.json swift test --filter LinuxBaseline

# Linux (inside Docker Desktop on Apple Silicon)
docker build --platform=linux/arm64 --target=builder -t shelltalk:linux-builder .
docker run --rm --platform=linux/arm64 \
  -v /tmp/shelltalk-bench:/out \
  -e SHELLTALK_BASELINE_JSON=/out/linux-baseline.json \
  shelltalk:linux-builder sh -c 'cd /src && swift test --filter LinuxBaseline'
```

The test is gated on `SHELLTALK_BASELINE_JSON` so it doesn't run during
default `swift test` cycles.
