#!/usr/bin/env bash
# Packs: flags, dry runs, installs with every pack at both scopes, idempotence, pin enforcement for the
# third-party sources, frontmatter, the snapshot, and a profile saved with packs. Run via tests/run.sh.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NSKILLS=$(( $(lockvar "$REPO" AGENT_SKILLS_LIST | wc -w) + 1 ))   # the lock's skills plus ponytail
NCMDS=$(lockvar "$REPO" AGENT_COMMANDS | wc -w | tr -d ' ')
count() { ls "$1" 2>/dev/null | wc -l | tr -d ' '; }
packvar() { ( . "$REPO/packs.conf"; eval "printf '%s' \"\${$1}\"" ); }
ALL_PACKS="$(packvar PACKS)"
ALL_ITEMS=""; for p in $ALL_PACKS; do ALL_ITEMS="$ALL_ITEMS $(packvar "PACK_$p")"; done
n_kind() { printf '%s\n' $ALL_ITEMS | grep -c "^$1:"; }
NPSKILLS=$(( $(n_kind skill) + $(n_kind tob) + $(n_kind wsh) + $(n_kind ecc) ))
NPCMDS=$(n_kind command)
NPAGENTS=$(n_kind agent)
TOB1="$(printf '%s\n' $ALL_ITEMS | grep -m1 '^tob:' | cut -d: -f2)"
WSH1="$(printf '%s\n' $ALL_ITEMS | grep -m1 '^wsh:' | cut -d: -f2)"
ECC1="$(printf '%s\n' $ALL_ITEMS | grep -m1 '^ecc:' | cut -d: -f2)"
item_path() { case "$2" in agent:*) echo "$1/agents/${2#*:}.md" ;; command:*) echo "$1/commands/${2#*:}.md" ;; *) echo "$1/skills/${2#*:}/SKILL.md" ;; esac; }
show_warns() { printf '%s\n' "$OUT" | grep '^WARN' | sed 's/^/    info: /'; }

# Frontmatter: every skill and agent has a name (matching its folder or file) and a description,
# names are unique per kind, and every command has a description.
cat > "$W/frontmatter.py" <<'EOF'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
problems, seen = [], {}
def front(path):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end < 0:
        return None
    keys = {}
    for line in text[4:end].splitlines():
        m = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if m:
            keys[m.group(1)] = m.group(2).strip().strip("\"'")
    return keys
for kind, paths in (("skill", root.glob("skills/*/SKILL.md")), ("agent", root.glob("agents/*.md"))):
    for p in sorted(paths):
        fm = front(p)
        if fm is None:
            problems.append(f"{p}: no frontmatter"); continue
        name, want = fm.get("name", ""), (p.parent.name if kind == "skill" else p.stem)
        if not fm.get("description"):
            problems.append(f"{p}: no description")
        if name != want:
            problems.append(f"{p}: name {name!r}, expected {want!r}")
        if (kind, name) in seen:
            problems.append(f"{p}: duplicate {kind} name {name!r}")
        seen[(kind, name)] = p
for c in sorted(root.glob("commands/*.md")):
    fm = front(c)
    if not fm or not fm.get("description"):
        problems.append(f"{c}: no description")
print("\n".join(problems) or f"ok: {len(seen)} skills and agents")
sys.exit(1 if problems else 0)
EOF

echo "== flags and validation"
mkdir -p "$W/c0"; cd "$W/c0" || exit 2
capture bash "$REPO/bootstrap.sh" --pack
expect_rc "--pack without a value exits 2" 2
capture bash "$REPO/bootstrap.sh" --pack nope --dry-run
expect_rc "an unknown pack exits 1" 1
expect_out "and names it" "unknown pack: nope"
capture bash "$REPO/bootstrap.sh" --pack roles,nope
expect_rc "a list with one unknown pack is refused" 1
check "nothing was installed" test ! -e "$HOME/.claude"

echo "== dry runs change nothing"
capture bash "$REPO/bootstrap.sh" --pack all --dry-run
expect_rc "user scope, all packs: exits 0" 0
expect_out "it plans the Trail of Bits fetch at the pin" "fetch -q --depth 1 origin $(lockvar "$REPO" TOB_SHA)"
expect_out "and the wshobson fetch at the pin" "fetch -q --depth 1 origin $(lockvar "$REPO" WSHOBSON_SHA)"
expect_out "and the ECC fetch at the pin" "fetch -q --depth 1 origin $(lockvar "$REPO" ECC_SHA)"
expect_out "and copies this repo's skills" "cp -R $REPO/skills/system-design"
capture bash "$REPO/bootstrap.sh" --scope project --pack roles --dry-run
expect_rc "project scope, one pack: exits 0" 0
capture bash "$REPO/bootstrap.sh" --dry-run
expect_rc "no packs: exits 0" 0
if printf '%s\n' "$OUT" | grep -qE 'trailofbits|wshobson|== packs'; then bad "without --pack, nothing from the packs is planned"
else ok "without --pack, nothing from the packs is planned"; fi
check "no ~/.claude was created" test ! -e "$HOME/.claude"
check "no ./.claude was created" test ! -e "$W/c0/.claude"

echo "== user-scope install with every pack"
capture bash "$REPO/bootstrap.sh" --pack all
expect_rc "install exits 0" 0
show_warns
C="$HOME/.claude"
n=$(count "$C/skills"); want=$((NSKILLS + 1 + NPSKILLS))
if [ "$n" -eq "$want" ]; then ok "skills: $want (base, graphify and $NPSKILLS from packs)"; else bad "skills: $n, wanted $want"; fi
n=$(count "$C/commands"); want=$((NCMDS + NPCMDS))
if [ "$n" -eq "$want" ]; then ok "commands: $want"; else bad "commands: $n, wanted $want"; fi
missing=""; for it in $ALL_ITEMS; do [ -f "$(item_path "$C" "$it")" ] || missing="$missing $it"; done
if [ -z "$missing" ]; then ok "every pack item is installed"; else bad "missing:$missing"; fi
lic=""; for it in $ALL_ITEMS; do case "$it" in tob:*|wsh:*|ecc:*) [ -f "$C/skills/${it#*:}/LICENSE" ] || lic="$lic ${it#*:}" ;; esac; done
if [ -z "$lic" ]; then ok "every third-party skill has its upstream LICENSE"; else bad "no LICENSE in:$lic"; fi
check "Trail of Bits copies carry CC-BY-SA-4.0" grep -q "Attribution-ShareAlike 4.0" "$C/skills/$TOB1/LICENSE"
check "wshobson copies carry the MIT licence" grep -q "MIT License" "$C/skills/$WSH1/LICENSE"
check "ECC copies carry the MIT licence" grep -q "MIT License" "$C/skills/$ECC1/LICENSE"
check "no installed skill needs CLAUDE_PLUGIN_ROOT" bash -c "! grep -rlq CLAUDE_PLUGIN_ROOT '$C/skills'"
ro=""; for it in $ALL_ITEMS; do case "$it" in agent:*) grep -qx 'tools: Read, Grep, Glob' "$C/agents/${it#*:}.md" || ro="$ro ${it#*:}" ;; esac; done
if [ -z "$ro" ]; then ok "the $NPAGENTS role agents are read-only (Read, Grep, Glob)"; else bad "not read-only:$ro"; fi
capture python3 -I "$W/frontmatter.py" "$C"
expect_rc "frontmatter is valid and names are unique" 0
# This repo's items must not mention anything that the full install leaves out
OURS="$(for it in $ALL_ITEMS; do case "$it" in skill:*|agent:*|command:*) item_path "" "$it" | sed 's|^/||' ;; esac; done | paste -sd'|' -)"
if printf '%s\n' "$OUT" | grep '^WARN' | grep -qE "($OURS)"; then
  bad "an item of this repo mentions something that is not installed"; printf '%s\n' "$OUT" | grep '^WARN' | grep -E "($OURS)" | sed 's/^/    /'
else ok "no item of this repo mentions something that is not installed"; fi

echo "== re-running is idempotent"
capture bash "$REPO/bootstrap.sh" --pack all
expect_rc "second run exits 0" 0
n=$(count "$C/skills"); want=$((NSKILLS + 1 + NPSKILLS))
if [ "$n" -eq "$want" ]; then ok "still $want skills"; else bad "skills after re-run: $n, wanted $want"; fi
check "no leftover .bak files" bash -c "[ -z \"\$(find '$C' -name '*.bak')\" ]"

echo "== without --pack nothing from the packs is installed; each pack alone adds exactly its items"
# names DIR: every installed skill folder, command and agent, as skills/X, commands/X.md, agents/X.md
names() { (cd "$1" && { ls -d skills/*/ 2>/dev/null | sed 's#/$##'; ls commands/*.md agents/*.md 2>/dev/null; }) | LC_ALL=C sort; }
expected_items() {
  for it in $(packvar "PACK_$1"); do
    case "$it" in agent:*) echo "agents/${it#*:}.md" ;; command:*) echo "commands/${it#*:}.md" ;; *) echo "skills/${it#*:}" ;; esac
  done | LC_ALL=C sort
}
HB="$W/home-base"; mkdir -p "$HB" "$W/c-base"; cd "$W/c-base" || exit 2
capture env HOME="$HB" bash "$REPO/bootstrap.sh"
expect_rc "default install (no --pack) exits 0" 0
names "$HB/.claude" > "$W/base.names"
want="$(for s in ponytail graphify $(lockvar "$REPO" AGENT_SKILLS_LIST); do echo "skills/$s"; done | LC_ALL=C sort)"
if [ "$(grep '^skills/' "$W/base.names")" = "$want" ]; then ok "default install: exactly the base skills from sources.lock"
else bad "default install skills differ from sources.lock"; fi
leak=""; for p in $ALL_PACKS; do for f in $(expected_items "$p"); do grep -qxF "$f" "$W/base.names" && leak="$leak $f"; done; done
if [ -z "$leak" ]; then ok "default install: no pack item"; else bad "default install contains pack items:$leak"; fi
for p in $ALL_PACKS; do
  Hp="$W/home-pack-$p"; mkdir -p "$Hp" "$W/c-pack-$p"; cd "$W/c-pack-$p" || exit 2
  capture env HOME="$Hp" bash "$REPO/bootstrap.sh" --pack "$p"
  expect_rc "--pack $p exits 0" 0
  names "$Hp/.claude" > "$W/pack-$p.names"
  added="$(LC_ALL=C comm -13 "$W/base.names" "$W/pack-$p.names")"
  removed="$(LC_ALL=C comm -23 "$W/base.names" "$W/pack-$p.names")"
  if [ "$added" = "$(expected_items "$p")" ] && [ -z "$removed" ]; then
    ok "--pack $p adds exactly its $(expected_items "$p" | wc -l | tr -d ' ') items and removes nothing"
  else
    bad "--pack $p: added [$(echo $added)], removed [$(echo $removed)], wanted [$(echo $(expected_items "$p"))]"
  fi
done

echo "== a Trail of Bits pin that cannot be fetched stops with nothing installed"
copy_repo "$W/tob-bad"
sed -i.bak 's/^TOB_SHA=.*/TOB_SHA="0123456789abcdef0123456789abcdef01234567"/' "$W/tob-bad/sources.lock"
H2="$W/home-tob"; mkdir -p "$H2" "$W/c-tob"; cd "$W/c-tob" || exit 2
capture env HOME="$H2" bash "$W/tob-bad/bootstrap.sh" --pack systems
expect_rc "exits 1" 1
expect_out "prints STOP with the reason" "STOP: could not fetch trailofbits/skills"
check "nothing was installed in that HOME" test ! -e "$H2/.claude"

echo "== a pinned skill that needs plugin-only features is refused"
copy_repo "$W/tob-plugin"
sed -i.bak 's#^TOB_SKILL_PATHS=.*#TOB_SKILL_PATHS="plugins/rust-review/skills/rust-review"#' "$W/tob-plugin/sources.lock"
sed -i.bak 's/^PACK_systems=.*/PACK_systems="tob:rust-review"/' "$W/tob-plugin/packs.conf"
H3="$W/home-plugin"; mkdir -p "$H3" "$W/c-plugin"; cd "$W/c-plugin" || exit 2
capture env HOME="$H3" bash "$W/tob-plugin/bootstrap.sh" --pack systems
expect_rc "exits 1" 1
expect_out "prints STOP with the reason" "needs plugin-only features"
check "nothing was installed in that HOME" test ! -e "$H3/.claude"

echo "== project scope with every pack: the snapshot covers the packs"
mkdir -p "$W/p1"; cd "$W/p1" || exit 2
capture bash "$REPO/bootstrap.sh" --scope project --pack all
expect_rc "project install exits 0" 0
P="$W/p1/.claude"; SNAP="$P/.vibe-setup/pristine"
n=$(count "$SNAP/skills"); want=$((NSKILLS + NPSKILLS))
if [ "$n" -eq "$want" ]; then ok "snapshot skills: $want"; else bad "snapshot skills: $n, wanted $want"; fi
n=$(count "$SNAP/commands"); want=$((NCMDS + NPCMDS))
if [ "$n" -eq "$want" ]; then ok "snapshot commands: $want"; else bad "snapshot commands: $n, wanted $want"; fi
n=$(count "$SNAP/agents"); m=$(count "$P/agents")
if [ "$n" -eq "$m" ]; then ok "snapshot agents: $n"; else bad "snapshot agents: $n vs installed $m"; fi
check "the packs are recorded" grep -qx "$ALL_PACKS" "$P/.vibe-setup/packs"
capture python3 -I "$W/frontmatter.py" "$P"
expect_rc "frontmatter is valid at project scope too" 0
R="$W/repo"; copy_repo "$R"     # profile_save.sh writes into the copy's profiles/
capture bash "$R/scripts/profile_save.sh" packs-nochange
expect_out "profile_save.sh finds nothing to save" "nothing to save"
check "no profile directory was created" test ! -e "$R/profiles/packs-nochange"

echo "== a profile saved with packs brings them back"
echo "- Example tweak for a product." >> "$P/skills/quant-researcher/SKILL.md"
echo "<!-- example tweak -->" >> "$P/skills/$TOB1/SKILL.md"
mkdir -p "$R/profiles/withpacks"; printf '# Example\nA product summary.\n' > "$R/profiles/withpacks/PROJECT.md"
capture bash "$R/scripts/profile_save.sh" withpacks
expect_rc "profile_save exits 0" 0
L="$R/profiles/withpacks"
check "profile.lock records the packs" grep -qx "PROFILE_PACKS=\"$ALL_PACKS\"" "$L/profile.lock"
check "profile.lock records the Trail of Bits pin" grep -q "PROFILE_TOB_SHA=\"$(lockvar "$REPO" TOB_SHA)\"" "$L/profile.lock"
check "the tailored third-party skill keeps its LICENSE" test -f "$L/overrides/skills/$TOB1/LICENSE"
check "this repo's own skill gets no LICENSE" test ! -e "$L/overrides/skills/quant-researcher/LICENSE"
check "only the two tweaks were captured" test "$(cd "$L/overrides" && find . -name SKILL.md | wc -l | tr -d ' ')" -eq 2
mkdir -p "$W/p2"; cd "$W/p2" || exit 2
capture bash "$R/bootstrap.sh" --scope project --profile withpacks
expect_rc "replay without --pack exits 0" 0
expect_out "it says the packs come from the profile" "saved with packs"
if printf '%s\n' "$OUT" | grep -q 'WARN: profile'; then bad "pin warning although the pins match"; else ok "no pin warning when the pins match"; fi
check "pack items from every pack are installed" test -f "$W/p2/.claude/skills/react-native-expo/SKILL.md"
check "the tweak to our skill is present" grep -q "Example tweak for a product" "$W/p2/.claude/skills/quant-researcher/SKILL.md"
check "the tweak to the third-party skill is present" grep -q "example tweak" "$W/p2/.claude/skills/$TOB1/SKILL.md"
capture bash "$R/scripts/profile_save.sh" withpacks2
check "round trip: overrides identical" diff -r "$L/overrides" "$R/profiles/withpacks2/overrides"

echo "== re-running without the packs warns about the files left behind"
cd "$W/p1" || exit 2
capture bash "$REPO/bootstrap.sh" --scope project
expect_rc "re-run without packs exits 0" 0
expect_out "a warning names a dropped pack" "WARN: pack 'roles' was installed here before"
check "the packs record is removed" test ! -e "$P/.vibe-setup/packs"

finish
