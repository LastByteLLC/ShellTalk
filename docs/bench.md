# ShellTalk benchmarks — Linux / WASM size & perf

Results and methodology for the v1.2.0 Linux / WASM measurement and
size-reduction pass. Paired with the v1.1.x macOS baseline in commit
messages.

## Headline results

| Artifact | Before v1.2.0 | After v1.2.0 | Δ |
|---|---|---|---|
| Linux `shelltalk` binary (arm64, Ubuntu 24.04, stripped) | ~30–80 MB typical Swift default | **2.0 MB** | huge (−95%+) |
| Linux `stm-eval` binary (arm64, stripped) | — | **1.4 MB** | — |
| WASM `shelltalk.wasm` (raw on-disk) | 43.81 MB | 43.80 MB | −0.1% (wasm-opt already near ceiling) |
| WASM wire transfer (gzip, `.wasm.gz`) | not emitted | **17.3 MB** | −60% vs raw |
| WASM wire transfer (brotli, `.wasm.br`) | not emitted | **11.6 MB** | **−74% vs raw** |

The dominant win for the web demo is **wire-size compression**, not on-disk
binary size — the uncompressed WASM is mostly data-segment strings that
wasm-opt and Swift size-flags can't meaningfully compress, but that
compress very well with brotli (26% of raw).

## WASM binary breakdown (v1.2.0 baseline)

From `wasm-objdump -h Web/shelltalk.wasm`:

| Section | Size | % of binary | Notes |
|---|---|---|---|
| Data | 35.7 MB | **78%** | String literals + static initializers for 245 templates / 1970 intents |
| Code | 10.0 MB | 22% | Compiled Swift code + stdlib + Foundation-for-WASI |
| Function | 34 KB | 0.08% | 34,767 function signatures |
| Elem | 100 KB | 0.22% | Function table |
| other | ~80 KB | 0.17% | Type, Import, Custom sections |

The Data section is the only lever that can materially shrink the binary
itself. Since brotli already compresses the Data section ~75% for wire
transfer, the on-disk size question is mostly academic for the web demo.
A future Part-3.3 (template data compressed to a brotli-packed resource
decoded at init) would shrink the raw binary by ~2–3 MB.

## Build-flag measurements (what actually moved the needle)

### WASM

Taking the raw Swift-WASM output (pre-wasm-opt), measuring each flag A/B:

| Config | Raw WASM size |
|---|---|
| `-Osize` baseline | 46.26 MB |
| `-Osize` + `-gnone` + `-disable-reflection-metadata` + `-disable-availability-checking` | 46.25 MB (−7.6 KB) |
| Same + new wasm-opt (`-Oz --strip-eh --strip-target-features --vacuum --dae-optimizing --converge`) | 46.01 MB |
| Same + `wasm-strip` post-pass | **45.93 MB** (−330 KB vs baseline) |

Swift-side flags save only ~8 KB — reflection-metadata and availability
scaffolding are a tiny fraction of the binary. The real story is that
Swift-WASM's stdlib + Foundation-for-WASI is ~45 MB on its own and can't
be pruned without recompiling stdlib.

### Linux

Linux binaries with `-Osize` + `-gnone` + `-Xlinker -s` + `strip --strip-all`
after build land at **2.0 MB** (`shelltalk`) and **1.4 MB** (`stm-eval`).
Before strip, each binary would be ~10–15 MB (with symbols). With
`-static-stdlib` the binary would be 30–40 MB (self-contained).

## How to reproduce

### macOS (baseline)

```
make build
swift test
.build/release/stm-eval --quiet --metrics-out /tmp/macos-metrics.json
```

### Linux (Docker)

```
make bench-linux         # builds multi-stage image + runs stm-eval in container
make bench-linux-size    # reports stripped binary sizes
```

**Known limitation**: on Apple Silicon with Docker Desktop running
linux/arm64 containers in the Linux VM, `stm-eval` has been observed to
hang inside `SystemProfile.detect()` on first static-let access — stuck in
`ppoll()`. The binary loads, dynamic linking resolves cleanly, `--help`
returns instantly, but any code path that touches `SystemProfile.cached`
deadlocks. Direct subprocess spawns (`uname`, `which`) from a shell in
the same container complete in milliseconds, so the issue is not
subprocess cost. Suspected Swift 6.3 corelibs-foundation `Process`
behavior specific to the Docker VM; reproduces across fresh builds and
survives `strip` being removed.

CI's Linux job (native Ubuntu 24.04 runners, no nested VM) runs
`stm-eval --quiet --metrics-out /tmp/metrics.json` successfully on every
push. See the GitHub Actions logs for `linux` job on recent commits for
the live numbers.

Actionable: to get local Linux perf numbers on this Mac host, either
(a) rely on the CI job's metrics JSON emitted to the workflow summary,
(b) use a real Linux machine over SSH, or
(c) investigate the Docker hang — likely needs a Swift backtrace tool
    installed in the runtime image.

### WASM

```
brew install brotli binaryen wabt
make wasm                # rebuild with new flags
make wasm-compressed     # produce .wasm.br and .wasm.gz wire variants
make bench-wasm-size     # report sizes + section breakdown
```

## What moved between v1.1.1 and v1.2.0 (infra + size)

- **New multi-stage Dockerfile** builds Swift-6.3-RELEASE release binaries
  on Ubuntu 24.04 and ships them in a slim runtime image. Both stages
  install dependencies explicitly (including `git` for `swift package
  resolve` and `libncurses6` for the Swift runtime). Binaries stripped
  in the builder stage.
- **Makefile** gains `bench-linux`, `bench-linux-size`, `bench-wasm-size`,
  `bench-all`, and `wasm-compressed` targets.
- **CI Linux job** now adds `-Osize -gnone -Xlinker -s` + `strip --strip-all`
  to release builds, reporting stripped binary sizes to the job summary.
- **CI WASM job** adds the new wasm-opt flag set + wasm-strip, then emits
  `shelltalk.wasm.br` and `shelltalk.wasm.gz` alongside the raw `.wasm`.
- **Web demo (`shelltalk.js`)** now prefers brotli (Chrome 117+ /
  Safari 17+ via DecompressionStream), falls back to gzip, and finally
  to raw WASM — transparent to users, no server cooperation needed.
- **Swift reflection + availability metadata** disabled via
  `-Xfrontend -disable-reflection-metadata` and
  `-Xfrontend -disable-availability-checking` in the WASM build. Audit
  confirms no `Mirror(reflecting:)` use in ShellTalkKit before enabling.

## What's NOT in v1.2.0

- Linux rerank support (Part 5 of the plan): deferred pending a usable
  local measurement. Phase 1 numbers will come from CI once stable.
- Template-data resource compression (Part 3.3): the ~35 MB Data section
  could shed 2–3 MB with a brotli-packed template blob, but wasm-opt +
  wire-compression already deliver 74% of the perceived win, and the
  decompression-at-init complexity wasn't worth it at this phase.
- Wizer pre-init (Part 3.5): optional; deferred.

## References

- Plan document: `.claude/plans/ultrathink-review-the-codebase-pure-beaver.md`
  (overwritten by the Linux/WASM plan after the v1.1.x perf plan was completed).
- v1.1.0 / v1.1.1 tags include the hot-path optimization + lazy NL init pass.
- CI workflows: `.github/workflows/ci.yml` (macos, linux, wasm jobs).
