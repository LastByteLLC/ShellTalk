# ShellTalk
---

![macOS](https://img.shields.io/badge/macOS-15_Sequoia-000000?logo=apple)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![Swift](https://img.shields.io/badge/Swift-6.2-FA7343.svg)

A deterministic CLI that converts natural language into shell commands.

ShellTalk uses **Semantic Template Matching** (STM) to map **intent → command**. It discovers available commands, resolves BSD–GNU flag differences, and validates commands before execution.

Inspired by [Hunch](https://github.com/es617/hunch), which uses an LLM-based approach.

```bash
$ shelltalk "find swift files modified today"
> find . -name '*.swift' -type f -mtime -1

$ shelltalk "replace foo with bar in config.yaml"
! sed -i '' 's/foo/bar/g' config.yaml

$ shelltalk --heal "wget https://example.com/file.tar.gz" --stderr "command not found: wget"
Fixed: 'wget' not found. Using alternative: curl -LO
> curl -LO https://example.com/file.tar.gz
```

## Install

Requires Swift 6.0+.

```bash
git clone https://github.com/LastByteLLC/ShellTalk.git
cd ShellTalk
make install    # builds release binary, copies to /usr/local/bin
```

Or build and run directly:

```bash
swift build -c release
.build/release/shelltalk "your query"
```

## Usage

```bash
shelltalk <query>           Convert query to a shell command
shelltalk -x <query>        Execute the generated command
shelltalk --dry-run <query> Validate without executing
shelltalk --debug <query>   Show match scores, entities, and timing
shelltalk --alternatives <query>  Show top-5 ranked matches
shelltalk --profile         Show detected system profile
shelltalk --heal <cmd>      Diagnose and suggest fixes for a failed command
```

### Examples

```bash
# File operations
shelltalk "find all .DS_Store files"
shelltalk "list files larger than 100M"
shelltalk "disk usage by directory"

# Git
shelltalk "show recent commits"
shelltalk "switch to feature/auth"
shelltalk "who changed main.swift"

# Text processing
shelltalk "search for TODO in files"
shelltalk "count lines in Package.swift"
shelltalk "replace http with https in config.yaml"

# macOS
shelltalk "take a screenshot of Firefox"
shelltalk "copy output to clipboard"
shelltalk "prevent mac from sleeping"

# Execute directly
shelltalk -x "show git status"

# Validate before running
shelltalk --dry-run "delete all log files"
```

### Debug mode

```bash
$ shelltalk --debug "take a screenshot of Firefox"
--- Debug ---
Timing: init 260ms | entities 0.85ms | match 28ms | extract 0.15ms | resolve 0.03ms | validate 66ms | total 355ms
Entities:
  Firefox -> applicationName [target] (lexicon, 85%)
Category: macos (score: 9.094)
Template: screencapture_window (score: 10.897)
Alternatives:
  [1] macos/screencapture_window
  [2] macos/screencapture
---
> screencapture -w screenshot.png
```

### Command healing

```bash
# Diagnose a failed command
shelltalk --heal "sed -i 's/old/new/g' file.txt" --stderr "invalid command code"
# Fixed: macOS sed requires -i '' (empty string for backup suffix)
# > sed -i '' 's/old/new/g' file.txt

# Missing tool suggestion
shelltalk --heal "wget https://example.com/file.tar.gz" --stderr "command not found: wget"
# Fixed: 'wget' not found. Using alternative: curl -LO
# > curl -LO https://example.com/file.tar.gz
```

## How it works

ShellTalk is fully deterministic. Same query, same machine, same result.

```bash
Query
  -> Entity Recognition (regex, lexicon, preposition frames, NLTagger POS)
  -> BM25 Category Match (12 categories)
  -> BM25 + TF-IDF Template Match (255 templates, NLEmbedding rerank on macOS)
  -> Slot Extraction (entity-aware + regex)
  -> Platform Resolution (BSD/GNU, macOS/Linux)
  -> Validation (bash -n, command existence, safety check)
  -> Command
```

**Template matching** uses a hybrid BM25 + TF-IDF scoring pipeline:

1. **BM25** ranks categories and templates using bag-of-words term matching with length normalization (k1=1.2, b=0.75)
2. **TF-IDF** computes cosine similarity in a continuous vector space using sublinear term frequency (1 + log(tf)) and smoothed IDF, then acts as a hybrid layer:
   - **Boost**: if a BM25 candidate also scores > 0.15 in TF-IDF, its score is boosted
   - **Inject**: candidates found only by TF-IDF (score > 0.3) are injected into the results, catching matches that require broader conceptual overlap (e.g., "build for production" matching "compile for release")
3. **NLEmbedding** (macOS only) provides a final semantic rerank pass

**Entity recognition** identifies files, apps, URLs, processes, and other entities in your query using four layers:

1. **Structural** (regex) -- paths, URLs, globs, IPs, sizes, env vars
2. **Lexicon** -- installed applications, known commands, service names
3. **Preposition frames** -- "in X" = location, "of X" = target, "to X" = destination
4. **NLTagger POS** (macOS) -- noun extraction for entities missed by layers 1-3

**Platform slots** resolve command differences automatically:

| Slot | macOS | Linux |
| ------ | ------- | ------- |
| `sed -i` | `sed -i ''` | `sed -i` |
| `stat size` | `stat -f '%z'` | `stat -c '%s'` |
| `clipboard` | `pbcopy` | `xclip -selection clipboard` |
| `open` | `open` | `xdg-open` |
| `pkg install` | `brew install` | `apt-get install` |

## Template categories

| Category | Templates | Examples |
| ---------- | ----------- | --------- |
| File Operations | 26 | find, ls, cp, mv, rm, mkdir, du, chmod |
| Git | 33 | status, diff, log, commit, branch, merge, stash, blame, range |
| Text Processing | 17 | grep, sed, awk, sort, uniq, wc, head, tail, jq, yq |
| Dev Tools | 25 | swift, cargo, go, node, python, docker, kubectl |
| macOS | 16 | open, pbcopy, say, defaults, mdfind, sips, screencapture |
| Network | 12 | curl, ssh, scp, dig, ping |
| System | 38 | ps, kill, df, env, which, uptime |
| Packages | 12 | brew, npm, pip, cargo |
| Compression | 12 | tar, gzip, zip, xz, zstd |
| Cloud | 29 | aws s3/ec2/lambda, kubectl |
| Media | 11 | ffmpeg, imagemagick, sips |
| Shell Scripting | 12 | for, while, if, subshells, heredocs |

## Cross-platform

Builds and runs on macOS and Linux. On macOS, [`NLEmbedding`](https://developer.apple.com/documentation/naturallanguage/nlembedding) provides enhanced semantic matching. On Linux, BM25 + TF-IDF handles all matching with no external dependencies.

```bash
# Linux build via Docker
docker build -t shelltalk .
```

## Meta-Harness

Matching quality is improved by an agentic proposer loop — one Claude instance reads prior candidate traces in `harness/runs/`, proposes one change, evaluates it, and keeps only Pareto wins. Inspired by [Meta-Harness](https://arxiv.org/abs/2603.28052): causal reasoning emerges from reading many prior attempts, not from summaries.

Each candidate is a branch + artifact dir containing an `overlay.yaml`, `metrics.json`, and `traces/eval.jsonl`. Overlays (see `harness/overlay-schema.md`) tweak matcher thresholds, per-template `discriminators`, `negativeKeywords`, or `addIntents` without touching source. Source edits are allowed only on candidate branches.

Candidates are scored by `stm-eval` against 454 curated `EvalCase`s and gated by `swift test --filter STMAccuracy` — zero-regression, no exceptions. Validated refinements graduate into `Sources/ShellTalkKit/Templates/TemplateRefinements.swift`.

Current shipped frontier (see `harness/frontier.md` for the full timeline):

| state            | n   | tpl_acc | cat_acc | BM25 lane | p95_ms |
| ---------------- | ---:| ------: | ------: | --------: | -----: |
| shipped (main)   | 454 |  0.9780 |  0.9890 |     0.925 |    358 |
| original baseline | 380 |  0.8947 |  0.9421 |     0.687 |   1038 |

Net across all rounds: **+8.33pp tpl_acc**, **+4.69pp cat_acc**, **+23.8pp** on the BM25 ranking lane, **65% lower p95**. Eval set grew 380 → 454 cases (+74 from audit additions). 28 of 35 suites at 100%. Determinism restored (F1 in `harness/FINDINGS.md`). `harness/runs/` is gitignored — only the shipped state lives in source and `frontier.md` / `ROADMAP.md`.

```bash
# Evaluate an overlay candidate
swift build -c release --product stm-eval
.build/release/stm-eval --quiet \
  --overlay    harness/runs/<run>/<cand>/overlay.yaml \
  --trace-out  harness/runs/<run>/<cand>/traces/eval.jsonl \
  --metrics-out harness/runs/<run>/<cand>/metrics.json

# Gate: curated STMAccuracy tests with overlay applied
SHELLTALK_OVERLAY_PATH=<overlay> swift test --filter STMAccuracy
```

`harness/FINDINGS.md` carries forward durable methodology notes (F1–F12) — e.g. `Set` iteration must be sorted for deterministic ranking, and `discriminators` should be preferred over `addIntents` because the latter perturbs global BM25/TF-IDF statistics.

## Testing

```bash
swift test
```

## License

[Apache 2.0](./LICENSE)
