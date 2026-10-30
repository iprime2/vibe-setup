#!/usr/bin/env bash
# Start a session in a project that already commits its toolkit (.claude/ from bootstrap.sh --scope project).
# Installs graphify's command-line tool at the pinned version (the committed hooks call it), then reports
# whether .claude/ still matches the pristine snapshot and the profile. Writes nothing under .claude/.
#
#   bash session-start.sh [PROFILE]      run from the project root
#
# Use bootstrap.sh only to refresh the toolkit; this script never replaces skills, commands or agents.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sources.lock
. "$HERE/sources.lock"
PROFILE="${1:-}"
CLAUDE_DIR="$PWD/.claude"
die() { echo "STOP: $*" >&2; exit 1; }

[ -f "$CLAUDE_DIR/.vibe-setup/packs" ] || [ -d "$CLAUDE_DIR/.vibe-setup/pristine" ] \
  || die "no project-scope toolkit in $CLAUDE_DIR; run bootstrap.sh --scope project instead"
if [ -n "$PROFILE" ]; then
  [[ "$PROFILE" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid profile name: $PROFILE"
  [ -f "$HERE/profiles/$PROFILE/profile.lock" ] || die "profile '$PROFILE' not found"
fi
command -v uv >/dev/null 2>&1 || die "uv is required but missing (this script does not install it)"

echo "== graphify ($GRAPHIFY_SPEC)"
if [ "$(id -u)" = 0 ]; then export UV_TOOL_BIN_DIR="${UV_TOOL_BIN_DIR:-/usr/local/bin}"; fi
export PATH="${UV_TOOL_BIN_DIR:-$HOME/.local/bin}:$PATH"
want="${GRAPHIFY_SPEC#*==}"
if command -v graphify >/dev/null 2>&1 && [ "$(graphify --version 2>/dev/null | awk '{print $2}')" = "$want" ]; then
  echo "graphify $want is already installed"
else
  echo "+ uv tool install $GRAPHIFY_SPEC --exclude-newer $GRAPHIFY_EXCLUDE_NEWER"
  uv tool install "$GRAPHIFY_SPEC" --exclude-newer "$GRAPHIFY_EXCLUDE_NEWER"
fi

echo "== toolkit drift"
pdir=""
if [ -n "$PROFILE" ]; then pdir="$HERE/profiles/$PROFILE"; fi
if [ -d "$CLAUDE_DIR/.vibe-setup/pristine" ]; then
  drift="$(python3 -I "$HERE/scripts/tailoring_drift.py" "$CLAUDE_DIR" "$pdir")"
  if [ -z "$drift" ]; then
    echo "none: .claude/ matches the pristine snapshot${PROFILE:+ and profile '$PROFILE'}"
  else
    echo "WARN: .claude/ differs from the pristine snapshot${PROFILE:+ and profile '$PROFILE'}; save it with scripts/profile_save.sh before any bootstrap.sh re-run:"
    printf '%s\n' "$drift" | sed 's/^/  /'
  fi
fi
if git -C "$PWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "== git status .claude"
  git -C "$PWD" status --short -- .claude
fi
echo "Done. Nothing under .claude/ was changed."
