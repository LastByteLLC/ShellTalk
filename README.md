# ShellTalk

![macOS](https://img.shields.io/badge/macOS-15_Sequoia-000000?logo=apple)
![Linux](https://img.shields.io/badge/Linux-Ubuntu_24.04-FCC624?logo=linux&logoColor=black)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![Swift](https://img.shields.io/badge/Swift-6.0+-FA7343.svg)

A deterministic CLI that converts natural language into shell commands.

ShellTalk uses **Semantic Template Matching** (STM) to map intent → command, plus a **discovery layer** (V1.5) backed by an embedded [tldr-pages](https://tldr.sh) corpus for the long tail. Same query, same machine, same result — no LLM at runtime.

```bash
$ shelltalk "find swift files modified today"
> find . -name '*.swift' -type f -mtime -1

$ shelltalk "encode video.mov to h264 with crf 23"
> ffmpeg -i video.mov -c:v libx264 -preset medium -crf 23 out.mp4

$ shelltalk "verify cert.pem against ca.pem"
> /opt/homebrew/opt/openssl@3/bin/openssl verify -CAfile ca.pem cert.pem

$ shelltalk --explore "lazygit show all branches"
~ lazygit
  warning: Synthesized from tldr/lazygit.md@209d423b — verify before running.

$ shelltalk --heal "wget https://example.com/file.tar.gz" --stderr "command not found: wget"
Fixed: 'wget' not found. Using alternative: curl -LO
> curl -LO https://example.com/file.tar.gz
```

## Install

Requires Swift 6.0+.

```bash
git clone https://github.com/LastByteLLC/ShellTalk.git
cd ShellTalk
make install    # builds release, copies to /usr/local/bin
```

## Usage

```
shelltalk <query>           Convert query to a shell command
shelltalk -x <query>        Execute the generated command
shelltalk --dry-run <query> Validate without executing
shelltalk --debug <query>   Show match scores, entities, timing
shelltalk --alternatives    Show top-5 ranked matches
shelltalk --explore <query> Force discovery (tldr) path; bypass built-ins
shelltalk --no-discovery    Disable the discovery layer for this call
shelltalk --profile         Show detected system profile
shelltalk --heal <cmd>      Diagnose and fix a failed command
```

Output marker: `>` for hand-written templates, `~` for synthesized commands. Auto-execute (`-x`) refuses synthesized commands unless `--force` is passed; copy and review before running.

## How it works

```
Query
  ↓ Entity recognition (regex, lexicon, preposition frames, NLTagger POS)
  ↓ BM25 + TF-IDF template match (~500 built-in templates, 13 categories)
  ↓ Slot extraction (entity-aware + regex + glob + shape synthesis)
  ↓ Platform resolution (BSD/GNU, macOS/Linux, ImageMagick v6/v7, OpenSSL/LibreSSL)
  ↓ ── if no confident match ──→ Discovery: tldr corpus (6,611 pages)
  ↓ Validation (bash -n, command exists, safety, domain checks)
  ↓ Command
```

**Hybrid matcher**: BM25 ranks categories and templates by bag-of-words; TF-IDF cosine similarity boosts conceptual matches and injects candidates BM25 missed; on macOS, NLEmbedding reranks the top candidates semantically.

**Capability slots** auto-resolve cross-version differences: `{IM_CMD}` becomes `magick` (v7) or `convert` (v6); `{OPENSSL_CMD}` prefers Homebrew openssl@3 over LibreSSL on macOS; `{TAR_ZSTD_FLAG}` is `--zstd` on GNU tar, `-I zstd` on BSD tar. The `SystemProfile` mid-path probe detects flavors at startup.

**Validation pipeline** runs structural checks even on synthesized commands: `bash -n` syntax, command-existence, safety classifier, plus domain validators (file-overwrite warning, ffmpeg encoder availability, OpenSSL legacy-cipher-on-LibreSSL, ImageMagick HEIC/AVIF delegate). Multi-operation queries ("encode video then add watermark") are detected and surfaced as a hint rather than silently truncated.

## Discovery layer (V1.5)

When the standard matcher returns no confident result, ShellTalk consults an embedded [tldr-pages](https://tldr.sh) corpus and synthesizes a command from the closest example. This grows the reachable tool set from ~500 built-in templates to ~6,600 tldr-derived examples — modern tools (`bun`, `deno`, `lazygit`, `helm`, `kubectx`, `rg`, `bat`, `eza`, `gh`, etc.) just work without anyone having to write a template.

| Metric | Value | Test floor |
|---|---:|---:|
| `tldr_roundtrip_acc` (n=662 sampled pages) | **0.9879** | 0.95 |
| Within-page example ranking hit rate (n=200) | **0.9400** | 0.85 |

Synthesized commands display with a `~` prefix and surface their tldr provenance:

```bash
$ shelltalk --explore "deno run a script"
~ deno compile {{path/to/file.ts}}
  warning: Synthesized from tldr/deno.md@209d423b — verify before running.
```

Disabled in WASM builds (no resource bundle) and on macOS/Linux when `SHELLTALK_DISCOVERY=off` or `--no-discovery` is set.

**Refresh the corpus** before tagging a release:

```bash
./harness/refresh-tldr-baseline.sh    # shallow-clones tldr-pages, regenerates the embedded JSON
```

> tldr-pages content is licensed [CC-BY-4.0](https://github.com/tldr-pages/tldr/blob/main/LICENSE.md) by the tldr-pages contributors. ShellTalk embeds a snapshot; attribution is preserved in the binary and shown alongside synthesized output.

## Template categories

13 categories, ~500 built-in templates as of v1.5:

| Category | Templates | Examples |
|---|---:|---|
| File Operations | 26 | find, ls, cp, mv, rm, mkdir, du, chmod, chown |
| Git | 33 | status, diff, log, commit, branch, merge, stash, blame |
| Text Processing | 17 | grep, sed, awk, sort, uniq, wc, head, tail, jq, yq |
| Dev Tools | 25 | swift, cargo, go, node, python, docker, kubectl |
| macOS | 16 | open, pbcopy, say, defaults, mdfind, sips, screencapture |
| Network | 33 | curl (PUT/PATCH/DELETE/auth/mTLS/cookies/forms), ssh, scp, dig |
| System | 38 | ps, kill, df, env, which, uptime |
| Packages | 12 | brew, npm, pip, cargo |
| Compression | 26 | tar (xz/zst, exclude, strip-components, single-file), gzip, zip, xz, zstd |
| Cloud | 29 | aws s3/ec2/lambda, kubectl, helm, wrangler, sam, serverless |
| Media | 50+ | ffmpeg (h264/hevc/av1/concat/watermark/hls/...), imagemagick (crop/rotate/montage/...) |
| Shell Scripting | 12 | for, while, if, subshells, heredocs |
| **Crypto** *(v1.4)* | 30 | openssl (x509/csr/keys/aes/hmac/p12/sha256/...) |

## Cross-platform

Builds and runs on macOS, Linux, and WASM. On macOS, `NLEmbedding` provides semantic rerank. On Linux, BM25 + TF-IDF handles all matching with no external dependencies. The discovery layer (`ShellTalkDiscovery` target) ships only on macOS/Linux — WASM excludes it for binary size.

```bash
# Linux via Docker
docker build -t shelltalk .

# WASM (browser demo)
make wasm
```

## Quality + meta-harness

Matching quality is improved by an offline meta-harness loop: one Claude instance reads candidate traces in `harness/runs/`, proposes one overlay change, runs `stm-eval` against the curated 615-case corpus, and keeps only Pareto wins. Validated refinements graduate into `Sources/ShellTalkKit/Templates/TemplateRefinements.swift`. `harness/FINDINGS.md` carries forward durable methodology notes (F1–F12: Set iteration ordering, BM25 IDF perturbation, etc.).

| State | n cases | tpl_acc | cat_acc | p95 ms |
|---|---:|---:|---:|---:|
| **v1.5 shipped** (main) | 615 | **0.9902** | **0.9967** | ~70 |
| v1.4 (incant) | 615 | 0.9919 | 0.9967 | ~70 |
| v1.3 baseline | 454 | 0.9780 | 0.9890 | 358 |
| original baseline | 380 | 0.8947 | 0.9421 | 1038 |

```bash
swift test                                              # full suite (205 tests)
.build/release/stm-eval --quiet --metrics-out out.json  # 615-case eval
```

## Acknowledgements

- Inspired by [Hunch](https://github.com/es617/hunch), which uses an LLM-based approach.
- Discovery layer is backed by [tldr-pages](https://tldr.sh) (CC-BY-4.0).

## License

[Apache 2.0](./LICENSE)
