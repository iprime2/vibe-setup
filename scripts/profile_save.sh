#!/usr/bin/env bash
# Capture the tailoring done in ./.claude as a profile of this repo:
#   profiles/NAME/overrides/   changed or new skills, commands and agents (same layout as .claude/)
#   profiles/NAME/remove.txt   upstream items deleted for this product
#   profiles/NAME/profile.lock pins in effect now (bootstrap.sh warns when sources.lock moves on)
#                              and the packs installed (bootstrap.sh installs them with the profile)
#   profiles/NAME/CHANGES.diff unified diff against upstream, for review only (never applied)
# Compares .claude/ with the pristine snapshot that `bootstrap.sh --scope project` took.
# Writes only under profiles/NAME/. PROJECT.md is written by hand and left alone.
#
#   bash scripts/profile_save.sh NAME [CLAUDE_DIR]     (CLAUDE_DIR defaults to ./.claude)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../sources.lock
. "$HERE/sources.lock"
die() { echo "STOP: $*" >&2; exit 1; }

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
rm -rf "$OUT/overrides" "$OUT/remove.txt" "$OUT/CHANGES.diff" "$OUT/profile.lock"
[ -z "$(ls -A "$STAGE/overrides")" ] || cp -R "$STAGE/overrides" "$OUT/overrides"
[ ! -s "$STAGE/remove.txt" ] || cp "$STAGE/remove.txt" "$OUT/remove.txt"
cp "$STAGE/CHANGES.diff" "$OUT/CHANGES.diff"
cat > "$OUT/profile.lock" <<EOF
# Pins in effect when this profile was captured. bootstrap.sh warns if sources.lock has moved on.
PROFILE_PONYTAIL_SHA="$PONYTAIL_SHA"
PROFILE_AGENT_SKILLS_SHA="$AGENT_SKILLS_SHA"
PROFILE_TOB_SHA="$TOB_SHA"
PROFILE_WSHOBSON_SHA="$WSHOBSON_SHA"
PROFILE_PACKS="$PACKS_USED"
EOF

echo "Saved profile '$NAME' to $OUT"
echo "  changed or new files: $(cd "$STAGE/overrides" && find . -type f | wc -l | tr -d ' ')"
echo "  removed entries:      $(wc -l < "$STAGE/remove.txt" | tr -d ' ')"
echo "  review: $OUT/CHANGES.diff"
[ -f "$OUT/PROJECT.md" ] || echo "  note: $OUT/PROJECT.md does not exist yet; write the confirmed project summary there."
