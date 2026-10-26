#!/usr/bin/env bash
# Per-project graphify wiring, then a code-only (AST) graph build. Run inside the git repo
# you want indexed, after bootstrap.sh. Never uses an LLM or an API key, never commits.
#
#   bash /path/to/vibe-setup/project-init.sh [--dry-run]
#
# Touches: CLAUDE.md (graphify section), .claude/settings.json (hooks, made fail-open),
# .git/hooks (graphify post-commit/post-checkout), .gitattributes (graphify merge driver),
# .gitignore (adds graphify-out/), graphify-out/. All left uncommitted.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

run() { echo "+ $*"; if [ "$DRY" != 1 ]; then "$@"; fi; }
die() { echo "STOP: $*" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository (cwd: $PWD)"
command -v graphify >/dev/null 2>&1 || die "graphify not found; run bootstrap.sh first"

run graphify claude install
run graphify hook install
if [ "$DRY" != 1 ] && [ -f .claude/settings.json ]; then
  run python3 -I "$HERE/scripts/failopen_hooks.py" .claude/settings.json
fi

if ! grep -qxF 'graphify-out/' .gitignore 2>/dev/null; then
  echo "+ add 'graphify-out/' to .gitignore"
  if [ "$DRY" != 1 ]; then
    { [ -s .gitignore ] && [ -n "$(tail -c1 .gitignore)" ] && echo; echo 'graphify-out/'; } >> .gitignore
  fi
fi

# Stripped environment: no API key or token can reach the build, whatever the shell holds.
run env -i PATH="$PATH" HOME="$HOME" graphify extract . --code-only
# --no-label keeps "Community N" placeholders instead of asking an LLM to name them.
run env -i PATH="$PATH" HOME="$HOME" graphify cluster-only . --no-label --no-viz

if [ "$DRY" != 1 ] && [ -f graphify-out/GRAPH_REPORT.md ]; then
  echo "== graphify-out/GRAPH_REPORT.md (first lines)"
  head -n 12 graphify-out/GRAPH_REPORT.md
fi
echo "Done. Nothing was committed; review 'git status' before you do."
