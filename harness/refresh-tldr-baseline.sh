#!/usr/bin/env bash
# refresh-tldr-baseline.sh — Rebuild the embedded tldr-pages corpus.
#
# This script clones tldr-pages from upstream, parses the common/macos/linux
# pages into a single JSON document, and writes it to
# Sources/ShellTalkDiscovery/Resources/tldr-baseline.json.
#
# Invocation:
#   ./harness/refresh-tldr-baseline.sh           # uses /tmp/tldr-pages clone
#   TLDR_REF=v1.5.0 ./harness/refresh-tldr-baseline.sh  # pin to specific tag
#
# Run before each release. The output JSON is checked into source control so
# `swift build` is offline-capable; this script is the version-bump mechanism.
#
# tldr-pages is licensed under CC-BY-4.0:
#   https://github.com/tldr-pages/tldr/blob/main/LICENSE.md

set -euo pipefail

REPO_URL="https://github.com/tldr-pages/tldr.git"
TLDR_REF="${TLDR_REF:-main}"
WORK_DIR="${TMPDIR:-/tmp}/tldr-pages-refresh-$$"
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/Sources/ShellTalkDiscovery/Resources"
OUT_FILE="$OUT_DIR/tldr-baseline.json"
META_FILE="$OUT_DIR/tldr-baseline.meta.json"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

echo "==> Cloning tldr-pages ($TLDR_REF) to $WORK_DIR"
git clone --quiet --depth 1 --branch "$TLDR_REF" "$REPO_URL" "$WORK_DIR" 2>/dev/null \
  || git clone --quiet --depth 1 "$REPO_URL" "$WORK_DIR"

cd "$WORK_DIR"
TLDR_COMMIT=$(git rev-parse HEAD)
TLDR_DATE=$(git log -1 --format=%cI HEAD)

mkdir -p "$OUT_DIR"

echo "==> Parsing pages → $OUT_FILE"
python3 - <<'PYEOF' "$WORK_DIR" "$OUT_FILE" "$TLDR_COMMIT" "$TLDR_DATE"
import json
import os
import re
import sys
from pathlib import Path

work_dir = Path(sys.argv[1])
out_file = Path(sys.argv[2])
tldr_commit = sys.argv[3]
tldr_date = sys.argv[4]

# Sections we ship to ShellTalk's runtime: common/ + macos/ + linux/.
# Other platforms (windows, freebsd, sunos, android) are excluded —
# they double the corpus size for users we don't target.
SECTIONS = ["common", "osx", "macos", "linux"]


def parse_page(text):
    """Parse a tldr-pages markdown file.

    Format (rigid):
        # command-name
        > Short description.
        > More: <url>.

        - Description of example 1:

        `command-template-with-{{placeholders}}`

        - Description of example 2:
        ...

    Returns None if the page is malformed or empty.
    """
    lines = [line.rstrip() for line in text.splitlines()]
    if not lines:
        return None
    name = None
    short_desc = []
    examples = []
    cur_desc = None
    for line in lines:
        if line.startswith("# "):
            name = line[2:].strip()
        elif line.startswith("> "):
            short_desc.append(line[2:].strip().rstrip("."))
        elif line.startswith("- "):
            cur_desc = line[2:].strip().rstrip(":").strip()
        elif line.startswith("`") and line.endswith("`") and cur_desc is not None:
            cmd = line[1:-1]
            examples.append({"description": cur_desc, "command": cmd})
            cur_desc = None
    if not name or not examples:
        return None
    return {
        "name": name,
        "description": " — ".join(short_desc),
        "examples": examples,
    }


pages_root = work_dir / "pages"
collected = {}
for section in SECTIONS:
    section_dir = pages_root / section
    if not section_dir.is_dir():
        continue
    for md in sorted(section_dir.glob("*.md")):
        try:
            content = md.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        page = parse_page(content)
        if page is None:
            continue
        # When the same command appears in multiple sections, prefer common
        # over linux over macos (most-portable wins).
        prio = {"common": 0, "linux": 1, "osx": 2, "macos": 2}
        existing = collected.get(page["name"])
        if existing is None or prio[section] < prio[existing["_section"]]:
            page["_section"] = section
            collected[page["name"]] = page

# Strip the bookkeeping field before serialization.
out_pages = sorted(
    [{k: v for k, v in p.items() if not k.startswith("_")} for p in collected.values()],
    key=lambda p: p["name"],
)

doc = {
    "schema_version": 1,
    "tldr_pages_commit": tldr_commit,
    "tldr_pages_date": tldr_date,
    "license": "CC-BY-4.0 (tldr-pages)",
    "license_url": "https://github.com/tldr-pages/tldr/blob/main/LICENSE.md",
    "page_count": len(out_pages),
    "pages": out_pages,
}

# Stable, compact JSON for reproducible builds.
out_file.write_text(
    json.dumps(doc, separators=(",", ":"), sort_keys=False, ensure_ascii=False),
    encoding="utf-8",
)

print(f"   {len(out_pages)} pages, {sum(len(p['examples']) for p in out_pages)} examples", file=sys.stderr)
PYEOF

# Sidecar meta file (uncompressed, for human inspection / git diff)
python3 - <<PYEOF "$OUT_FILE" "$META_FILE"
import json, sys, datetime
src = json.loads(open(sys.argv[1]).read())
meta = {k: v for k, v in src.items() if k != "pages"}
meta["names"] = sorted(p["name"] for p in src["pages"])
meta["regenerated_at"] = datetime.datetime.utcnow().isoformat() + "Z"
open(sys.argv[2], "w").write(json.dumps(meta, indent=2))
PYEOF

# Gzip-compress the corpus for embedding. The runtime loader (TldrSource)
# decompresses on first access via Foundation's data(.decompressed) API.
# This trades ~5ms of cold-start CPU for ~3.7 MB of binary size savings.
gzip --force --keep -9 "$OUT_FILE"
GZ_FILE="${OUT_FILE}.gz"

OUT_BYTES=$(stat -f%z "$OUT_FILE" 2>/dev/null || stat -c%s "$OUT_FILE")
GZ_BYTES=$(stat -f%z "$GZ_FILE" 2>/dev/null || stat -c%s "$GZ_FILE")
echo "==> Wrote $OUT_FILE ($OUT_BYTES bytes uncompressed)"
echo "==> Wrote $GZ_FILE ($GZ_BYTES bytes — embedded in binary)"
echo "==> tldr-pages commit: $TLDR_COMMIT"
echo "==> tldr-pages date:   $TLDR_DATE"
echo
echo "    Commit the regenerated baseline:"
echo "      git add Sources/ShellTalkDiscovery/Resources/"
echo "      git commit -m 'discovery: refresh tldr-pages baseline ($TLDR_COMMIT)'"
