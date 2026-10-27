#!/usr/bin/env bash
# Capture the tailoring done in ./.claude as a profile of this repo:
#   profiles/NAME/overrides/   changed or new skills, commands and agents (same layout as .claude/)
#   profiles/NAME/remove.txt   upstream items deleted for this product
#   profiles/NAME/profile.lock pins in effect now (bootstrap.sh warns when sources.lock moves on)
#                              and the packs installed (bootstrap.sh installs them with the profile)
#   profiles/NAME/CHANGES.diff unified diff against upstream, for review only (never applied)
#   profiles/NAME/NOTICE.md    which overrides are tailored copies of third-party files, and their licences
#   profiles/NAME/LICENSES/    licence texts for tailored third-party files that are not in a skill folder
# Compares .claude/ with the pristine snapshot that `bootstrap.sh --scope project` took.
# Writes only under profiles/NAME/. PROJECT.md is written by hand and left alone.
#
#   bash scripts/profile_save.sh NAME [CLAUDE_DIR]     (CLAUDE_DIR defaults to ./.claude)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../sources.lock
. "$HERE/sources.lock"
die() { echo "STOP: $*" >&2; exit 1; }
has() { case " $1 " in *" $2 "*) return 0 ;; esac; return 1; }
# path_of LIST NAME: the repo-relative path in LIST whose last part is NAME
path_of() { local e; for e in $1; do if [ "${e##*/}" = "$2" ]; then echo "$e"; return 0; fi; done; return 1; }

NAME="${1:-}"
[[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "usage: profile_save.sh NAME [CLAUDE_DIR]  (NAME: lowercase letters, digits, hyphens)"
CLAUDE_DIR="${2:-$PWD/.claude}"
SNAP="$CLAUDE_DIR/.vibe-setup/pristine"
[ -d "$SNAP" ] || die "no pristine snapshot at $SNAP; run bootstrap.sh --scope project first"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/overrides"
: > "$STAGE/CHANGES.diff"
: > "$STAGE/remove.txt"

# Changed or new files. Graphify's generated skill is not tailorable.
while IFS= read -r -d '' f; do
  rel="${f#"$CLAUDE_DIR"/}"
  case "$rel" in skills/graphify/*) continue ;; esac
  if [ -f "$SNAP/$rel" ]; then
    cmp -s "$SNAP/$rel" "$f" && continue
    diff -u --label "a/$rel" --label "b/$rel" "$SNAP/$rel" "$f" >> "$STAGE/CHANGES.diff" || true
  else
    diff -u --label /dev/null --label "b/$rel" /dev/null "$f" >> "$STAGE/CHANGES.diff" || true
  fi
  mkdir -p "$STAGE/overrides/$(dirname "$rel")"
  cp "$f" "$STAGE/overrides/$rel"
done < <(find "$CLAUDE_DIR" -mindepth 2 -type f \
  \( -path "$CLAUDE_DIR/skills/*" -o -path "$CLAUDE_DIR/commands/*" -o -path "$CLAUDE_DIR/agents/*" \) -print0)

# A tailored copy of a third-party skill keeps its upstream LICENSE (attribution, same licence).
for d in "$STAGE"/overrides/skills/*/; do
  [ -d "$d" ] || continue
  n="$(basename "$d")"
  if [ -f "$CLAUDE_DIR/skills/$n/LICENSE" ] && [ ! -f "$d/LICENSE" ]; then cp "$CLAUDE_DIR/skills/$n/LICENSE" "$d/LICENSE"; fi
done

# origin_of ITEM: "source|licence" for an upstream item (skills/NAME, agents/NAME.md, commands/NAME.md);
# nothing for this repo's own items. Agents in the snapshot that this repo does not ship are Agent Skills'.
origin_of() {
  local n="${1#*/}"; n="${n%.md}"
  case "$1" in
    skills/*)
      if [ "$n" = ponytail ]; then echo "Ponytail ($PONYTAIL_REPO)|MIT"
      elif has "$AGENT_SKILLS_LIST" "$n"; then echo "Agent Skills ($AGENT_SKILLS_REPO)|MIT"
      elif path_of "$TOB_SKILL_PATHS" "$n" >/dev/null; then echo "Trail of Bits ($TOB_REPO)|CC-BY-SA-4.0"
      elif path_of "$WSHOBSON_SKILL_PATHS" "$n" >/dev/null; then echo "wshobson ($WSHOBSON_REPO)|MIT"
      elif path_of "$ECC_SKILL_PATHS" "$n" >/dev/null; then echo "ECC ($ECC_REPO)|MIT"
      fi ;;
    agents/*) [ -f "$HERE/agents/$n.md" ] || echo "Agent Skills ($AGENT_SKILLS_REPO)|MIT" ;;
    commands/*) if has "$AGENT_COMMANDS" "$n"; then echo "Agent Skills ($AGENT_SKILLS_REPO)|MIT"; fi ;;
  esac
}

# NOTICE.md: every override that is a tailored copy of a third-party item, its source and licence. Skill
# folders carry their LICENSE (above). Agents and commands are single files, so the Agent Skills licence
# goes to LICENSES/agent-skills.txt, taken from an Agent Skills skill folder in the snapshot.
missing=""
: > "$STAGE/notice-rows"
while IFS= read -r item; do
  [ -e "$SNAP/$item" ] || continue                # new in this profile, not a copy of an upstream item
  o="$(origin_of "$item")"
  [ -n "$o" ] || continue
  if [ "${item%%/*}" = skills ]; then
    text="overrides/$item/LICENSE"
    [ -f "$STAGE/$text" ] || { missing="$missing $item"; text="missing"; }
  else
    text="LICENSES/agent-skills.txt"
    if [ ! -f "$STAGE/$text" ]; then
      for s in $AGENT_SKILLS_LIST; do
        if [ -f "$SNAP/skills/$s/LICENSE" ]; then mkdir -p "$STAGE/LICENSES"; cp "$SNAP/skills/$s/LICENSE" "$STAGE/$text"; break; fi
      done
    fi
    [ -f "$STAGE/$text" ] || { missing="$missing $item"; text="missing"; }
  fi
  printf '| `%s` | %s | %s | %s |\n' "$item" "${o%%|*}" "${o##*|}" "$text" >> "$STAGE/notice-rows"
done < <(cd "$STAGE/overrides" 2>/dev/null && { ls -d skills/*/ 2>/dev/null | sed 's#/$##'; ls agents/*.md commands/*.md 2>/dev/null; })
if [ -s "$STAGE/notice-rows" ]; then
  {
    printf '# Third-party files in this profile\n\n'
    printf 'These overrides are tailored copies of upstream files. Each keeps its upstream licence, and the changes\n'
    printf 'are in CHANGES.diff.\n\n| Override | Source | Licence | Licence text |\n|---|---|---|---|\n'
    cat "$STAGE/notice-rows"
  } > "$STAGE/NOTICE.md"
fi
if [ -n "$missing" ]; then
  echo "WARN: no upstream LICENSE in this install for:$missing. It was installed before bootstrap.sh copied the licences: replay the profile in a fresh project with bootstrap.sh --scope project --profile $NAME, then save it again from there."
fi

# Upstream files that are gone: a whole skill folder is recorded once, anything else per file.
while IFS= read -r -d '' s; do
  rel="${s#"$SNAP"/}"
  [ -e "$CLAUDE_DIR/$rel" ] && continue
  entry="$rel"
  if [ "${rel%%/*}" = skills ]; then
    top="$(printf '%s' "$rel" | cut -d/ -f1-2)"
    [ -d "$CLAUDE_DIR/$top" ] || entry="$top"
  fi
  grep -qxF "$entry" "$STAGE/remove.txt" || echo "$entry" >> "$STAGE/remove.txt"
  diff -u --label "a/$rel" --label /dev/null "$s" /dev/null >> "$STAGE/CHANGES.diff" || true
done < <(find "$SNAP" -type f -print0)

if [ -z "$(ls -A "$STAGE/overrides")" ] && [ ! -s "$STAGE/remove.txt" ]; then
  echo "No differences from upstream in $CLAUDE_DIR; nothing to save."
  exit 0
fi

PACKS_USED=""
if [ -f "$CLAUDE_DIR/.vibe-setup/packs" ]; then PACKS_USED="$(cat "$CLAUDE_DIR/.vibe-setup/packs")"; fi
[[ "$PACKS_USED" =~ ^[a-z0-9\ ]*$ ]] || die "unexpected content in $CLAUDE_DIR/.vibe-setup/packs"

OUT="$HERE/profiles/$NAME"
mkdir -p "$OUT"
rm -rf "$OUT/overrides" "$OUT/remove.txt" "$OUT/CHANGES.diff" "$OUT/profile.lock" "$OUT/NOTICE.md" "$OUT/LICENSES"
[ -z "$(ls -A "$STAGE/overrides")" ] || cp -R "$STAGE/overrides" "$OUT/overrides"
[ ! -f "$STAGE/NOTICE.md" ] || cp "$STAGE/NOTICE.md" "$OUT/NOTICE.md"
[ ! -d "$STAGE/LICENSES" ] || cp -R "$STAGE/LICENSES" "$OUT/LICENSES"
[ ! -s "$STAGE/remove.txt" ] || cp "$STAGE/remove.txt" "$OUT/remove.txt"
cp "$STAGE/CHANGES.diff" "$OUT/CHANGES.diff"
cat > "$OUT/profile.lock" <<EOF
# Pins in effect when this profile was captured. bootstrap.sh warns if sources.lock has moved on.
PROFILE_PONYTAIL_SHA="$PONYTAIL_SHA"
PROFILE_AGENT_SKILLS_SHA="$AGENT_SKILLS_SHA"
PROFILE_TOB_SHA="$TOB_SHA"
PROFILE_WSHOBSON_SHA="$WSHOBSON_SHA"
PROFILE_ECC_SHA="$ECC_SHA"
PROFILE_PACKS="$PACKS_USED"
EOF

echo "Saved profile '$NAME' to $OUT"
echo "  changed or new files: $(cd "$STAGE/overrides" && find . -type f | wc -l | tr -d ' ')"
echo "  removed entries:      $(wc -l < "$STAGE/remove.txt" | tr -d ' ')"
echo "  third-party copies:   $(wc -l < "$STAGE/notice-rows" | tr -d ' ')$([ -s "$STAGE/notice-rows" ] && echo " (see NOTICE.md)")"
echo "  review: $OUT/CHANGES.diff"
[ -f "$OUT/PROJECT.md" ] || echo "  note: $OUT/PROJECT.md does not exist yet; write the confirmed project summary there."
