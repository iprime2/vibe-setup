#!/usr/bin/env bash
# Install the vibe-coding toolkit (Graphify, Ponytail, Agent Skills) from the pinned,
# allow-listed sources in sources.lock. Idempotent. Never commits, never reads secrets.
#
#   bash bootstrap.sh [--scope user|project] [--profile NAME] [--with-rules] [--dry-run]
#
# --scope user      (default) install into ~/.claude; keeps project repos clean
# --scope project   install into ./.claude of the current directory; also keeps a pristine
#                   snapshot in .claude/.vibe-setup/ so tailoring can be captured (profile_save.sh)
# --profile NAME    after installing, apply profiles/NAME (tailored skills for one product).
#                   Needs --scope project: user-level copies of the same skills could shadow it.
# --with-rules      also append rules/CLAUDE.md to <scope>/.claude/CLAUDE.md (between markers)
# --dry-run         print every command, change nothing
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sources.lock
. "$HERE/sources.lock"

SCOPE=user DRY=0 RULES=0 PROFILE=""
usage() { echo "usage: bootstrap.sh [--scope user|project] [--profile NAME] [--with-rules] [--dry-run]"; }
need_value() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --scope) need_value $#; SCOPE="$2"; shift 2 ;;
    --profile) need_value $#; PROFILE="$2"; shift 2 ;;
    --with-rules) RULES=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
case "$SCOPE" in
  user) CLAUDE_DIR="$HOME/.claude" ;;
  project) CLAUDE_DIR="$PWD/.claude" ;;
  *) usage >&2; exit 2 ;;
esac

run() { echo "+ $*"; if [ "$DRY" != 1 ]; then "$@"; fi; }
die() { echo "STOP: $*" >&2; exit 1; }
sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

# Validate the profile before anything is installed, so a bad profile cannot leave a half-install.
if [ -n "$PROFILE" ]; then
  [[ "$PROFILE" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid profile name: $PROFILE"
  [ "$SCOPE" = project ] || die "--profile needs --scope project"
  pdir="$HERE/profiles/$PROFILE"
  [ -f "$pdir/profile.lock" ] || die "profile '$PROFILE' not found (expected $pdir/profile.lock)"
  if [ -d "$pdir/overrides" ]; then
    while IFS= read -r e; do
      case "$(basename "$e")" in skills|commands|agents) ;; *) die "profile overrides may only contain skills/, commands/ and agents/ (found $(basename "$e"))" ;; esac
    done < <(find "$pdir/overrides" -mindepth 1 -maxdepth 1)
    [ -z "$(find "$pdir/overrides" -type l)" ] || die "profile overrides must not contain symlinks"
  fi
  if [ -f "$pdir/remove.txt" ]; then
    while IFS= read -r rel || [ -n "$rel" ]; do
      case "$rel" in ''|'#'*) continue ;; esac
      case "$rel" in /*|*..*) die "unsafe path in remove.txt: $rel" ;; skills/*|commands/*|agents/*) ;; *) die "remove.txt may only name skills/, commands/ or agents/ paths: $rel" ;; esac
    done < "$pdir/remove.txt"
  fi
fi

echo "== detect"
echo "os: $(uname -srm) | user: $(id -un) | cloud: ${CLAUDE_CODE_REMOTE:-no} | scope: $SCOPE -> $CLAUDE_DIR | profile: ${PROFILE:-none} | cwd: $PWD"
for t in git curl python3 uv node claude; do
  printf '%s: ' "$t"
  if command -v "$t" >/dev/null 2>&1; then "$t" --version 2>&1 | head -1; else echo "missing"; fi
done
for t in git curl python3 uv; do
  command -v "$t" >/dev/null 2>&1 || die "$t is required but missing (this script does not install it)"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "== graphify ($GRAPHIFY_SPEC)"
if [ "$(id -u)" = 0 ]; then export UV_TOOL_BIN_DIR="${UV_TOOL_BIN_DIR:-/usr/local/bin}"; fi
export PATH="${UV_TOOL_BIN_DIR:-$HOME/.local/bin}:$PATH"
run uv tool install "$GRAPHIFY_SPEC"
if [ "$SCOPE" = project ]; then run graphify install --project; else run graphify install; fi
if [ "$DRY" != 1 ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
  run python3 -I "$HERE/scripts/failopen_hooks.py" "$CLAUDE_DIR/settings.json"
fi

echo "== ponytail @ ${PONYTAIL_SHA:0:8}"
run curl -fsSL -o "$tmp/ponytail.md" "https://raw.githubusercontent.com/$PONYTAIL_REPO/$PONYTAIL_SHA/skills/ponytail/SKILL.md"
if [ "$DRY" != 1 ]; then
  got="$(sha256 "$tmp/ponytail.md")"
  [ "$got" = "$PONYTAIL_SKILL_SHA256" ] || die "ponytail SKILL.md differs from the reviewed version (sha256 $got). Not installing."
fi
run mkdir -p "$CLAUDE_DIR/skills/ponytail"
run cp "$tmp/ponytail.md" "$CLAUDE_DIR/skills/ponytail/SKILL.md"

echo "== agent-skills @ ${AGENT_SKILLS_SHA:0:8}"
src="$tmp/agent-skills"
run git init -q "$src"
run git -C "$src" remote add origin "https://github.com/$AGENT_SKILLS_REPO"
run git -C "$src" fetch -q --depth 1 origin "$AGENT_SKILLS_SHA"
run git -C "$src" checkout -q FETCH_HEAD
if [ "$DRY" != 1 ]; then
  [ "$(git -C "$src" rev-parse HEAD)" = "$AGENT_SKILLS_SHA" ] || die "agent-skills checkout is not the pinned commit. Not installing."
fi
run mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/agents"
for s in $AGENT_SKILLS_LIST; do
  if [ "$DRY" != 1 ] && [ ! -d "$src/skills/$s" ]; then die "upstream skill missing at the pinned commit: $s"; fi
  run rm -rf "${CLAUDE_DIR:?}/skills/$s"
  run cp -R "$src/skills/$s" "$CLAUDE_DIR/skills/$s"
done
for c in $AGENT_COMMANDS; do
  run cp "$src/.claude/commands/$c.md" "$CLAUDE_DIR/commands/$c.md"
  run sed -i.bak 's/agent-skills://g' "$CLAUDE_DIR/commands/$c.md"
  run rm -f "$CLAUDE_DIR/commands/$c.md.bak"
done
run cp "$src"/agents/*.md "$CLAUDE_DIR/agents/"

# Project scope: remember exactly what upstream looked like, so tailoring can be diffed and captured.
if [ "$SCOPE" = project ]; then
  echo "== pristine snapshot"
  snap="$CLAUDE_DIR/.vibe-setup/pristine"
  run rm -rf "${snap:?}"
  run mkdir -p "$snap/skills" "$snap/commands" "$snap/agents"
  for s in ponytail $AGENT_SKILLS_LIST; do run cp -R "$CLAUDE_DIR/skills/$s" "$snap/skills/$s"; done
  for c in $AGENT_COMMANDS; do run cp "$CLAUDE_DIR/commands/$c.md" "$snap/commands/$c.md"; done
  for a in "$src"/agents/*.md; do run cp "$CLAUDE_DIR/agents/$(basename "$a")" "$snap/agents/"; done
fi

if [ -n "$PROFILE" ]; then
  echo "== profile $PROFILE"
  # shellcheck disable=SC1091
  . "$pdir/profile.lock"
  if [ "${PROFILE_AGENT_SKILLS_SHA:-}" != "$AGENT_SKILLS_SHA" ] || [ "${PROFILE_PONYTAIL_SHA:-}" != "$PONYTAIL_SHA" ]; then
    echo "WARN: profile '$PROFILE' was tailored against different pins than sources.lock now has; re-review its CHANGES.diff before relying on it"
  fi
  if [ -d "$pdir/overrides" ]; then run cp -R "$pdir/overrides/." "$CLAUDE_DIR/"; fi
  if [ -f "$pdir/remove.txt" ]; then
    while IFS= read -r rel || [ -n "$rel" ]; do
      case "$rel" in ''|'#'*) continue ;; esac
      run rm -rf "${CLAUDE_DIR:?}/$rel"
    done < "$pdir/remove.txt"
  fi
  if [ -f "$pdir/PROJECT.md" ]; then
    run python3 -I "$HERE/scripts/append_block.py" "$CLAUDE_DIR/CLAUDE.md" "$pdir/PROJECT.md" "profile:$PROFILE"
  fi
fi

if [ "$DRY" != 1 ]; then
  for d in "$src"/skills/*/; do
    n="$(basename "$d")"
    [ -d "$CLAUDE_DIR/skills/$n" ] && continue
    if grep -qw -- "$n" "$CLAUDE_DIR"/commands/*.md "$CLAUDE_DIR"/agents/*.md 2>/dev/null; then
      echo "WARN: an installed command/agent references skill '$n', which is not installed (not in AGENT_SKILLS_LIST, or removed by the profile)"
    fi
  done
fi

if [ "$RULES" = 1 ]; then
  echo "== rules"
  run python3 -I "$HERE/scripts/append_block.py" "$CLAUDE_DIR/CLAUDE.md" "$HERE/rules/CLAUDE.md"
fi

echo "== summary"
if [ "$DRY" != 1 ]; then
  graphify --version
  echo "skills:   $(ls "$CLAUDE_DIR/skills" | tr '\n' ' ')"
  echo "commands: $(ls "$CLAUDE_DIR/commands" | tr '\n' ' ')"
  echo "agents:   $(ls "$CLAUDE_DIR/agents" | tr '\n' ' ')"
fi
echo "Done. Nothing was committed. Skills, commands, agents and hooks load in a NEW session (or after a reload)."
