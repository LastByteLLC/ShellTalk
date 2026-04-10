# ShellTalk

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
  -> BM25 Template Match (167 templates, NLEmbedding rerank on macOS)
  -> Slot Extraction (entity-aware + regex)
  -> Platform Resolution (BSD/GNU, macOS/Linux)
  -> Validation (bash -n, command existence, safety check)
  -> Command
```

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
| File Operations | 17 | find, ls, cp, mv, rm, mkdir, du, chmod |
| Git | 20 | status, diff, log, commit, branch, merge, stash, blame |
| Text Processing | 16 | grep, sed, awk, sort, uniq, wc, head, tail, jq |
| Dev Tools | 15 | swift, cargo, go, node, python, docker, kubectl |
| macOS | 16 | open, pbcopy, say, defaults, mdfind, sips, screencapture |
| Network | 12 | curl, ssh, scp, dig, ping |
| System | 14 | ps, kill, df, env, which, uptime |
| Packages | 12 | brew, npm, pip, cargo |
| Compression | 12 | tar, gzip, zip, xz, zstd |
| Cloud | 12 | aws s3/ec2/lambda, kubectl |
| Media | 11 | ffmpeg, imagemagick, sips |
| Shell Scripting | 12 | for, while, if, subshells, heredocs |

## Cross-platform

Builds and runs on macOS and Linux. On macOS, [`NLEmbedding`](https://developer.apple.com/documentation/naturallanguage/nlembedding) provides enhanced semantic matching. On Linux, BM25 handles all matching with no external dependencies.

```bash
# Linux build via Docker
docker build -t shelltalk .
```

## Testing

```bash
swift test
```

## License

[Apache 2.0](./LICENSE)
