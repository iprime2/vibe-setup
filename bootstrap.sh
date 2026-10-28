#!/usr/bin/env bash
# Install the vibe-coding toolkit (Graphify, Ponytail, Agent Skills, and optional packs) from the
# pinned, allow-listed sources in sources.lock. Idempotent. Never commits, never reads secrets.
#
#   bash bootstrap.sh [--scope user|project] [--pack NAME[,NAME]] [--profile NAME] [--with-rules] [--dry-run]
#
# --scope user      (default) install into ~/.claude; keeps project repos clean
# --scope project   install into ./.claude of the current directory; also keeps a pristine
#                   snapshot in .claude/.vibe-setup/ so tailoring can be captured (profile_save.sh)
# --pack NAME[,..]  also install optional packs from packs.conf, or "all"; may be repeated.
#                   Without it, only the base toolkit is installed.
# --profile NAME    after installing, apply profiles/NAME (tailored skills for one product).
#                   Needs --scope project: user-level copies of the same skills could shadow it.
#                   The packs the profile was saved with are installed as well.
# --with-rules      also append rules/CLAUDE.md to <scope>/.claude/CLAUDE.md (between markers)
# --dry-run         print every command, change nothing
#
# Every pinned source is fetched and checked before anything is installed, so a pin mismatch
# stops the run with nothing installed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sources.lock
. "$HERE/sources.lock"
# shellcheck source=packs.conf
. "$HERE/packs.conf"

SCOPE=user DRY=0 RULES=0 PROFILE="" PACK_ARGS=""
usage() { echo "usage: bootstrap.sh [--scope user|project] [--pack NAME[,NAME]] [--profile NAME] [--with-rules] [--dry-run]"; }
need_value() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --scope) need_value $#; SCOPE="$2"; shift 2 ;;
    --pack) need_value $#; PACK_ARGS="${PACK_ARGS:+$PACK_ARGS,}$2"; shift 2 ;;
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
has() { case " $1 " in *" $2 "*) return 0 ;; esac; return 1; }
# path_of LIST NAME: the repo-relative path in LIST whose last part is NAME
path_of() { local e; for e in $1; do if [ "${e##*/}" = "$2" ]; then echo "$e"; return 0; fi; done; return 1; }

# fetch_commit REPO SHA DIR: shallow fetch of exactly one commit; STOP unless HEAD is that commit.
fetch_commit() {
  run git init -q "$3"
  run git -C "$3" remote add origin "https://github.com/$1"
  run git -C "$3" fetch -q --depth 1 origin "$2" || die "could not fetch $1 at the pinned commit $2. Not installing."
  run git -C "$3" checkout -q FETCH_HEAD
  if [ "$DRY" != 1 ]; then
    [ "$(git -C "$3" rev-parse HEAD)" = "$2" ] || die "$1 checkout is not the pinned commit. Not installing."
  fi
}

# check_pinned_skills LABEL SRC PATHS NAMES: each selected skill exists at the pin, has no symlinks,
# and needs no plugin-only feature; the repo has a LICENSE to copy next to it.
check_pinned_skills() {
  local n p d
  if [ "$DRY" = 1 ]; then return 0; fi
  [ -f "$2/LICENSE" ] || die "$1 has no LICENSE at the pinned commit. Not installing."
  for n in $4; do
    p="$(path_of "$3" "$n")"
    d="$2/$p"
    [ -f "$d/SKILL.md" ] || die "$1 skill missing at the pinned commit: $p"
    [ -z "$(find "$d" -type l)" ] || die "$1 skill $n contains symlinks. Not installing."
    if grep -rqE 'CLAUDE_PLUGIN_ROOT|mcp__' "$d" || [ -n "$(find "$d" -name .mcp.json -o -name hooks.json)" ]; then
      die "$1 skill $n needs plugin-only features (CLAUDE_PLUGIN_ROOT, MCP or hooks). Not installing."
    fi
  done
}

# install_pinned_skills SRC PATHS NAMES: copy each skill folder, then the upstream LICENSE into it.
install_pinned_skills() {
  local n p
  for n in $3; do
    p="$(path_of "$2" "$n")"
    run rm -rf "${CLAUDE_DIR:?}/skills/$n"
    run cp -R "$1/$p" "$CLAUDE_DIR/skills/$n"
    run cp "$1/LICENSE" "$CLAUDE_DIR/skills/$n/LICENSE"
  done
}

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
    [ ! -e "$pdir/overrides/skills/graphify" ] || die "profile overrides must not change graphify's skill"
  fi
  if [ -f "$pdir/remove.txt" ]; then
    while IFS= read -r rel || [ -n "$rel" ]; do
      case "$rel" in ''|'#'*) continue ;; esac
      # One named item only: a bare "skills/" (or "skills//", "skills/.") would delete the whole folder.
      case "$rel" in
        /*|*..*|*//*|*/|*/.|*/./*) die "unsafe path in remove.txt: $rel" ;;
        skills/graphify|skills/graphify/*) die "remove.txt must not name graphify's skill: $rel" ;;
        skills/?*|commands/?*|agents/?*) ;;
        *) die "remove.txt may only name skills/, commands/ or agents/ paths: $rel" ;;
      esac
    done < "$pdir/remove.txt"
  fi
  # shellcheck disable=SC1091
  . "$pdir/profile.lock"
  if [ -n "${PROFILE_PACKS:-}" ]; then
    echo "profile '$PROFILE' was saved with packs: $PROFILE_PACKS (installing them too)"
    PACK_ARGS="${PACK_ARGS:+$PACK_ARGS,}${PROFILE_PACKS// /,}"
  fi
fi

# Resolve packs into items before anything is installed. Pack names are checked against packs.conf,
# third-party skills against the pins in sources.lock, and a skill name may come from one source only.
SEL_PACKS="" FP_SKILLS="" FP_AGENTS="" FP_COMMANDS="" TOB_SEL="" WSH_SEL="" ECC_SEL=""
for p in ${PACK_ARGS//,/ }; do
  if [ "$p" = all ]; then p="$PACKS"; fi
  for q in $p; do
    has "$PACKS" "$q" || die "unknown pack: $q (known: $PACKS, all)"
    has "$SEL_PACKS" "$q" || SEL_PACKS="${SEL_PACKS:+$SEL_PACKS }$q"
  done
done
taken="ponytail graphify $AGENT_SKILLS_LIST"
take_skill() { if has "$taken" "$1"; then die "pack skill '$1' clashes with a skill from another source"; fi; taken="$taken $1"; }
for p in $SEL_PACKS; do
  v="PACK_$p"
  [ -n "${!v:-}" ] || die "packs.conf lists pack '$p' in PACKS but has no PACK_$p line"
  for it in ${!v}; do
    n="${it#*:}"
    case "$it" in
      skill:*)
        if has "$FP_SKILLS" "$n"; then continue; fi
        [ -f "$HERE/skills/$n/SKILL.md" ] || die "pack $p: skills/$n/SKILL.md is missing"
        take_skill "$n"; FP_SKILLS="${FP_SKILLS:+$FP_SKILLS }$n" ;;
      agent:*)
        if has "$FP_AGENTS" "$n"; then continue; fi
        [ -f "$HERE/agents/$n.md" ] || die "pack $p: agents/$n.md is missing"
        FP_AGENTS="${FP_AGENTS:+$FP_AGENTS }$n" ;;
      command:*)
        if has "$FP_COMMANDS" "$n"; then continue; fi
        [ -f "$HERE/commands/$n.md" ] || die "pack $p: commands/$n.md is missing"
        if has "$AGENT_COMMANDS" "$n"; then die "pack command '$n' clashes with an Agent Skills command"; fi
        FP_COMMANDS="${FP_COMMANDS:+$FP_COMMANDS }$n" ;;
      tob:*)
        if has "$TOB_SEL" "$n"; then continue; fi
        path_of "$TOB_SKILL_PATHS" "$n" >/dev/null || die "pack $p: $n is not pinned in TOB_SKILL_PATHS"
        take_skill "$n"; TOB_SEL="${TOB_SEL:+$TOB_SEL }$n" ;;
      wsh:*)
        if has "$WSH_SEL" "$n"; then continue; fi
        path_of "$WSHOBSON_SKILL_PATHS" "$n" >/dev/null || die "pack $p: $n is not pinned in WSHOBSON_SKILL_PATHS"
        take_skill "$n"; WSH_SEL="${WSH_SEL:+$WSH_SEL }$n" ;;
      ecc:*)
        if has "$ECC_SEL" "$n"; then continue; fi
        path_of "$ECC_SKILL_PATHS" "$n" >/dev/null || die "pack $p: $n is not pinned in ECC_SKILL_PATHS"
        take_skill "$n"; ECC_SEL="${ECC_SEL:+$ECC_SEL }$n" ;;
      *) die "pack $p: unknown item '$it' (expected skill:, agent:, command:, tob:, wsh: or ecc:)" ;;
    esac
  done
done

echo "== detect"
echo "os: $(uname -srm) | user: $(id -un) | cloud: ${CLAUDE_CODE_REMOTE:-no} | scope: $SCOPE -> $CLAUDE_DIR | packs: ${SEL_PACKS:-none} | profile: ${PROFILE:-none} | cwd: $PWD"
for t in git curl python3 uv node claude; do
  printf '%s: ' "$t"
  if command -v "$t" >/dev/null 2>&1; then "$t" --version 2>&1 | head -1; else echo "missing"; fi
done
for t in git curl python3 uv; do
  command -v "$t" >/dev/null 2>&1 || die "$t is required but missing (this script does not install it)"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
src="$tmp/agent-skills" tobsrc="$tmp/trailofbits" wshsrc="$tmp/wshobson" eccsrc="$tmp/ecc"

echo "== fetch and check the pinned sources (nothing is installed until all pass)"
echo "-- ponytail @ ${PONYTAIL_SHA:0:8}"
run curl -fsSL -o "$tmp/ponytail.md" "https://raw.githubusercontent.com/$PONYTAIL_REPO/$PONYTAIL_SHA/skills/ponytail/SKILL.md"
if [ "$DRY" != 1 ]; then
  got="$(sha256 "$tmp/ponytail.md")"
  [ "$got" = "$PONYTAIL_SKILL_SHA256" ] || die "ponytail SKILL.md differs from the reviewed version (sha256 $got). Not installing."
fi
run curl -fsSL -o "$tmp/ponytail.LICENSE" "https://raw.githubusercontent.com/$PONYTAIL_REPO/$PONYTAIL_SHA/LICENSE"
if [ "$DRY" != 1 ]; then
  got="$(sha256 "$tmp/ponytail.LICENSE")"
  [ "$got" = "$PONYTAIL_LICENSE_SHA256" ] || die "ponytail LICENSE differs from the reviewed version (sha256 $got). Not installing."
fi
echo "-- agent-skills @ ${AGENT_SKILLS_SHA:0:8}"
fetch_commit "$AGENT_SKILLS_REPO" "$AGENT_SKILLS_SHA" "$src"
if [ "$DRY" != 1 ]; then
  [ -f "$src/LICENSE" ] || die "$AGENT_SKILLS_REPO has no LICENSE at the pinned commit. Not installing."
  for s in $AGENT_SKILLS_LIST; do
    [ -d "$src/skills/$s" ] || die "upstream skill missing at the pinned commit: $s"
  done
  for a in $FP_AGENTS; do
    [ ! -e "$src/agents/$a.md" ] || die "pack agent '$a' clashes with an Agent Skills agent"
  done
fi
if [ -n "$TOB_SEL" ]; then
  echo "-- trailofbits/skills @ ${TOB_SHA:0:8}"
  fetch_commit "$TOB_REPO" "$TOB_SHA" "$tobsrc"
  check_pinned_skills "$TOB_REPO" "$tobsrc" "$TOB_SKILL_PATHS" "$TOB_SEL"
fi
if [ -n "$WSH_SEL" ]; then
  echo "-- wshobson/agents @ ${WSHOBSON_SHA:0:8}"
  fetch_commit "$WSHOBSON_REPO" "$WSHOBSON_SHA" "$wshsrc"
  check_pinned_skills "$WSHOBSON_REPO" "$wshsrc" "$WSHOBSON_SKILL_PATHS" "$WSH_SEL"
fi
if [ -n "$ECC_SEL" ]; then
  echo "-- ECC @ ${ECC_SHA:0:8}"
  fetch_commit "$ECC_REPO" "$ECC_SHA" "$eccsrc"
  check_pinned_skills "$ECC_REPO" "$eccsrc" "$ECC_SKILL_PATHS" "$ECC_SEL"
fi

echo "== graphify ($GRAPHIFY_SPEC)"
if [ "$(id -u)" = 0 ]; then export UV_TOOL_BIN_DIR="${UV_TOOL_BIN_DIR:-/usr/local/bin}"; fi
export PATH="${UV_TOOL_BIN_DIR:-$HOME/.local/bin}:$PATH"
run uv tool install "$GRAPHIFY_SPEC"
# graphify rewrites its CLAUDE.md section down to the next "# " heading, which cut off a vibe-setup begin
# marker sitting below it (older runs put blocks there); move this repo's blocks above it first.
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then run python3 -I "$HERE/scripts/append_block.py" "$CLAUDE_DIR/CLAUDE.md"; fi
if [ "$SCOPE" = project ]; then run graphify install --project; else run graphify install; fi
if [ "$DRY" != 1 ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
  run python3 -I "$HERE/scripts/failopen_hooks.py" "$CLAUDE_DIR/settings.json"
fi

echo "== ponytail @ ${PONYTAIL_SHA:0:8}"
run mkdir -p "$CLAUDE_DIR/skills/ponytail"
run cp "$tmp/ponytail.md" "$CLAUDE_DIR/skills/ponytail/SKILL.md"
run cp "$tmp/ponytail.LICENSE" "$CLAUDE_DIR/skills/ponytail/LICENSE"

echo "== agent-skills @ ${AGENT_SKILLS_SHA:0:8}"
run mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/agents"
for s in $AGENT_SKILLS_LIST; do
  run rm -rf "${CLAUDE_DIR:?}/skills/$s"
  run cp -R "$src/skills/$s" "$CLAUDE_DIR/skills/$s"
  run cp "$src/LICENSE" "$CLAUDE_DIR/skills/$s/LICENSE"
done
for c in $AGENT_COMMANDS; do
  run cp "$src/.claude/commands/$c.md" "$CLAUDE_DIR/commands/$c.md"
  run sed -i.bak 's/agent-skills://g' "$CLAUDE_DIR/commands/$c.md"
  run rm -f "$CLAUDE_DIR/commands/$c.md.bak"
done
run cp "$src"/agents/*.md "$CLAUDE_DIR/agents/"

if [ -n "$SEL_PACKS" ]; then
  echo "== packs: $SEL_PACKS"
  for s in $FP_SKILLS; do
    run rm -rf "${CLAUDE_DIR:?}/skills/$s"
    run cp -R "$HERE/skills/$s" "$CLAUDE_DIR/skills/$s"
  done
  for a in $FP_AGENTS; do run cp "$HERE/agents/$a.md" "$CLAUDE_DIR/agents/$a.md"; done
  for c in $FP_COMMANDS; do run cp "$HERE/commands/$c.md" "$CLAUDE_DIR/commands/$c.md"; done
  install_pinned_skills "$tobsrc" "$TOB_SKILL_PATHS" "$TOB_SEL"
  install_pinned_skills "$wshsrc" "$WSHOBSON_SKILL_PATHS" "$WSH_SEL"
  install_pinned_skills "$eccsrc" "$ECC_SKILL_PATHS" "$ECC_SEL"
fi

# Project scope: remember exactly what upstream looked like, so tailoring can be diffed and captured.
# Pack items count as upstream too; the packs file lets profile_save.sh record them with a profile.
if [ "$SCOPE" = project ]; then
  echo "== pristine snapshot"
  snap="$CLAUDE_DIR/.vibe-setup/pristine"
  packs_file="$CLAUDE_DIR/.vibe-setup/packs"
  prev=""
  if [ -f "$packs_file" ]; then prev="$(cat "$packs_file")"; fi
  [[ "$prev" =~ ^[a-z0-9\ ]*$ ]] || prev=""
  for q in $prev; do
    has "$SEL_PACKS" "$q" || echo "WARN: pack '$q' was installed here before but is not selected now; its files stay in $CLAUDE_DIR and profile_save.sh would capture them as tailoring. Re-run with --pack $q, or delete them."
  done
  run rm -rf "${snap:?}"
  run mkdir -p "$snap/skills" "$snap/commands" "$snap/agents"
  for s in ponytail $AGENT_SKILLS_LIST $FP_SKILLS $TOB_SEL $WSH_SEL $ECC_SEL; do run cp -R "$CLAUDE_DIR/skills/$s" "$snap/skills/$s"; done
  for c in $AGENT_COMMANDS $FP_COMMANDS; do run cp "$CLAUDE_DIR/commands/$c.md" "$snap/commands/$c.md"; done
  for a in "$src"/agents/*.md; do run cp "$CLAUDE_DIR/agents/$(basename "$a")" "$snap/agents/"; done
  for a in $FP_AGENTS; do run cp "$CLAUDE_DIR/agents/$a.md" "$snap/agents/"; done
  if [ -n "$SEL_PACKS" ]; then
    echo "+ record packs '$SEL_PACKS' in $packs_file"
    if [ "$DRY" != 1 ]; then printf '%s\n' "$SEL_PACKS" > "$packs_file"; fi
  else
    run rm -f "$packs_file"
  fi
fi

if [ -n "$PROFILE" ]; then
  echo "== profile $PROFILE"
  if [ "${PROFILE_AGENT_SKILLS_SHA:-}" != "$AGENT_SKILLS_SHA" ] || [ "${PROFILE_PONYTAIL_SHA:-}" != "$PONYTAIL_SHA" ] \
     || { [ -n "$TOB_SEL" ] && [ "${PROFILE_TOB_SHA:-$TOB_SHA}" != "$TOB_SHA" ]; } \
     || { [ -n "$WSH_SEL" ] && [ "${PROFILE_WSHOBSON_SHA:-$WSHOBSON_SHA}" != "$WSHOBSON_SHA" ]; } \
     || { [ -n "$ECC_SEL" ] && [ "${PROFILE_ECC_SHA:-$ECC_SHA}" != "$ECC_SHA" ]; }; then
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
  # This repo's skills and agents, and every skill at the third-party pins fetched for this run:
  # warn when an installed command, agent or pack skill names one that is not installed.
  # Names are matched whole, hyphens included: "code-review" does not match "code-review-and-quality".
  # One-word names ("scan") are ordinary words in prose, so only hyphenated names are checked.
  scan=("$CLAUDE_DIR"/commands/*.md "$CLAUDE_DIR"/agents/*.md)
  for s in $FP_SKILLS $TOB_SEL $WSH_SEL $ECC_SEL; do
    if [ -f "$CLAUDE_DIR/skills/$s/SKILL.md" ]; then scan+=("$CLAUDE_DIR/skills/$s/SKILL.md"); fi
  done
  known=""
  for d in "$HERE"/skills/*/; do known="$known skill:$(basename "$d")"; done
  for f in "$HERE"/agents/*.md; do known="$known agent:$(basename "$f" .md)"; done
  if [ -n "$TOB_SEL" ]; then for d in "$tobsrc"/plugins/*/skills/*/; do known="$known skill:$(basename "$d")"; done; fi
  if [ -n "$WSH_SEL" ]; then for d in "$wshsrc"/plugins/*/skills/*/; do known="$known skill:$(basename "$d")"; done; fi
  if [ -n "$ECC_SEL" ]; then for d in "$eccsrc"/skills/*/; do known="$known skill:$(basename "$d")"; done; fi
  for k in $known; do
    n="${k#*:}"
    case "$n" in *-*) ;; *) continue ;; esac
    if [ "${k%%:*}" = agent ]; then
      if [ -f "$CLAUDE_DIR/agents/$n.md" ]; then continue; fi
    elif [ -d "$CLAUDE_DIR/skills/$n" ]; then continue
    fi
    hits="$(grep -lE -- "(^|[^A-Za-z0-9_-])$n([^A-Za-z0-9_-]|\$)" "${scan[@]}" 2>/dev/null | sed "s|^$CLAUDE_DIR/||" | tr '\n' ' ' || true)"
    if [ -n "$hits" ]; then echo "WARN: ${k%%:*} '$n' is mentioned by ${hits}but is not installed"; fi
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
