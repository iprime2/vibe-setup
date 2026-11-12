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
TOB1="$(printf '%s\n' $ALL_ITEMS | grep -m1 '^tob:' | cut -d: -f2)"
WSH1="$(printf '%s\n' $ALL_ITEMS | grep -m1 '^wsh:' | cut -d: -f2)"
ECC1="$(printf '%s\n' $ALL_ITEMS | grep -m1 '^ecc:' | cut -d: -f2)"
item_path() { case "$2" in agent:*) echo "$1/agents/${2#*:}.md" ;; command:*) echo "$1/commands/${2#*:}.md" ;; *) echo "$1/skills/${2#*:}/SKILL.md" ;; esac; }
show_warns() { printf '%s\n' "$OUT" | grep '^WARN' | sed 's/^/    info: /'; }
has_word() { case " $1 " in *" $2 "*) return 0 ;; esac; return 1; }

# The builder allowlist: the only agents with write tools, each with its default effort. Every other agent
# in agents/ must stay read-only; a new agent with write tools fails here until it is added by name.
BUILDERS="junior-dev mid-dev senior-dev lead-dev"
BUILDER_TOOLS="Read, Edit, Write, Bash, Grep, Glob"
effort_of() { case "$1" in junior-dev) echo medium ;; mid-dev) echo high ;; senior-dev) echo xhigh ;; lead-dev) echo max ;; esac; }
# The pm pack's items, as installed paths in C-locale order.
PM_WANT="agents/junior-dev.md agents/lead-dev.md agents/mid-dev.md agents/qa-engineer.md agents/senior-dev.md commands/gated-review.md skills/github-api skills/project-manager"
# fm FILE KEY: every value of KEY in FILE's frontmatter, one per line. body FILE: the text after the frontmatter.
fm() { awk -v k="$2" 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } index($0, k ": ") == 1 { print substr($0, length(k) + 3) }' "$1" 2>/dev/null; }
body() { awk 'NR == 1 && $0 == "---" { f = 1; next } f && $0 == "---" { f = 0; b = 1; next } b' "$1" 2>/dev/null; }
body_has() { body "$1" | grep -qF -- "$2"; }
# keys FILE: the frontmatter's key names, sorted. tail_of FILE: from "## Never" to the end (the builders' safety text).
keys() { awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { if (match($0, /^[A-Za-z_-]+: /)) print substr($0, 1, RLENGTH - 2); else print "?" }' "$1" 2>/dev/null | LC_ALL=C sort | xargs; }
tail_of() { sed -n '/^## Never$/,$p' "$1" 2>/dev/null; }
# The owner's merge rule (2026-11-01), word for word wherever it is stated. flat FILE joins lines and squeezes spaces.
MERGE_RULE="By default, every merge needs the owner's word in the session, quoted on the PR with its time. A project may switch on a rule in its \`AGENTS.md\` that lets the PM merge a clean PR at QA pass; a PR in an ask-first area always waits for the owner's word."
flat() { tr '\n' ' ' < "$1" 2>/dev/null | tr -s ' '; }
n_rule() { flat "$1" | grep -oF -- "$MERGE_RULE" | wc -l | tr -d ' '; }

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

echo "== agent tools: the builders by name, every other agent read-only (offline)"
ro=""; for f in "$REPO"/agents/*.md; do
  n="$(basename "$f" .md)"; has_word "$BUILDERS" "$n" && continue
  [ "$(fm "$f" tools)" = "Read, Grep, Glob" ] || ro="$ro $n"
done
if [ -z "$ro" ]; then ok "every agent outside the builder allowlist has exactly tools: Read, Grep, Glob"; else bad "not read-only, and not an allowlisted builder:$ro"; fi
for n in $BUILDERS; do
  f="$REPO/agents/$n.md"
  check "$n: tools are exactly $BUILDER_TOOLS" test "$(fm "$f" tools)" = "$BUILDER_TOOLS"
  check "$n: default effort is $(effort_of "$n")" test "$(fm "$f" effort)" = "$(effort_of "$n")"
  check "$n: says it never reviews, approves, QAs or merges" body_has "$f" "Never review, approve, QA or merge"
  check "$n: says it never pushes to main" body_has "$f" 'Never push to `main`'
done
# No agent gains a privilege through another frontmatter key (model, permission mode, hooks, ...).
for f in "$REPO"/agents/*.md; do
  n="$(basename "$f" .md)"
  if has_word "$BUILDERS" "$n"; then want="description effort name tools"; else want="description name tools"; fi
  check "$n: frontmatter keys are exactly [$want]" test "$(keys "$f")" = "$want"
done
# The four builders carry one safety text: Never and When blocked are identical in every builder.
check "junior-dev: its safety text runs from Never to When blocked" grep -qx '## When blocked' <(tail_of "$REPO/agents/junior-dev.md")
for n in mid-dev senior-dev lead-dev; do
  check "$n: its Never and When blocked sections match junior-dev's" diff <(tail_of "$REPO/agents/junior-dev.md") <(tail_of "$REPO/agents/$n.md")
done

echo "== the merge rule reads the same everywhere (offline)"
check "project-manager states it in sections 2, 6 and 11" test "$(n_rule "$REPO/skills/project-manager/SKILL.md")" -eq 3
check "/gated-review section 8 states it" test "$(n_rule "$REPO/commands/gated-review.md")" -eq 1
check "docs/workflow.md states it" test "$(n_rule "$REPO/docs/workflow.md")" -eq 1

echo "== one merge gate, and its QA agent ships (offline)"
check "/gated-review says it is the only merge gate" body_has "$REPO/commands/gated-review.md" "This is the only merge gate."
check "/tiered-review's description says it is not a merge gate" bash -c "grep -q '^description:.*Not a merge gate' '$REPO/commands/tiered-review.md'"
check "/gated-review names qa-engineer as the default QA agent" body_has "$REPO/commands/gated-review.md" 'The default is `qa-engineer` (the `pm` pack).'
check "qa-engineer ships in the pm pack" has_word "$(packvar PACK_pm)" agent:qa-engineer

echo "== the pm pack (offline)"
check "packs.conf lists the pm pack" has_word "$ALL_PACKS" pm
pm_items="$(for it in $(packvar PACK_pm); do case "$it" in agent:*) echo "agents/${it#*:}.md" ;; command:*) echo "commands/${it#*:}.md" ;; *) echo "skills/${it#*:}" ;; esac; done | LC_ALL=C sort | xargs)"
if [ "$pm_items" = "$PM_WANT" ]; then ok "PACK_pm lists exactly its eight items"; else bad "PACK_pm: [$pm_items], wanted [$PM_WANT]"; fi
leak=""; for p in $ALL_PACKS; do [ "$p" = pm ] && continue; for it in $(packvar "PACK_$p"); do
  case "$it" in agent:*) has_word "$BUILDERS" "${it#*:}" && leak="$leak $p:$it" ;; esac; done; done
if [ -z "$leak" ]; then ok "no other pack installs a builder"; else bad "builders outside the pm pack:$leak"; fi

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
INSTALL_OUT="$OUT"   # the frontmatter check below replaces $OUT; the reference check needs this install's WARN lines
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
ro="" nro=0 wr="" nwr=0
for it in $ALL_ITEMS; do case "$it" in agent:*)
  n="${it#*:}"
  if has_word "$BUILDERS" "$n"; then
    nwr=$((nwr + 1)); [ "$(fm "$C/agents/$n.md" tools)" = "$BUILDER_TOOLS" ] || wr="$wr $n"
  else
    nro=$((nro + 1)); [ "$(fm "$C/agents/$n.md" tools)" = "Read, Grep, Glob" ] || ro="$ro $n"
  fi ;; esac; done
if [ -z "$ro" ]; then ok "the $nro role agents are read-only (Read, Grep, Glob)"; else bad "not read-only:$ro"; fi
if [ -z "$wr" ] && [ "$nwr" -eq 4 ]; then ok "the 4 installed builders have exactly $BUILDER_TOOLS"; else bad "builders installed: $nwr, with other tools:$wr"; fi
capture python3 -I "$W/frontmatter.py" "$C"
expect_rc "frontmatter is valid and names are unique" 0
# This repo's items must not mention anything that the full install leaves out
OURS="$(for it in $ALL_ITEMS; do case "$it" in skill:*|agent:*|command:*) item_path "" "$it" | sed 's|^/||' ;; esac; done | paste -sd'|' -)"
if printf '%s\n' "$INSTALL_OUT" | grep '^WARN' | grep -qE "($OURS)"; then
  bad "an item of this repo mentions something that is not installed"; printf '%s\n' "$INSTALL_OUT" | grep '^WARN' | grep -E "($OURS)" | sed 's/^/    /'
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
    bad "--pack $p: added [$(echo $added)], removed [$(echo $removed)], wanted [$(expected_items "$p" | xargs)]"
  fi
done
pm_added="$( [ -f "$W/pack-pm.names" ] && LC_ALL=C comm -13 "$W/base.names" "$W/pack-pm.names" | xargs)"
if [ "$pm_added" = "$PM_WANT" ]; then ok "--pack pm installs exactly the project-manager and github-api skills, the four builders, qa-engineer and /gated-review"
else bad "--pack pm installed [$pm_added], wanted [$PM_WANT]"; fi

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
check "NOTICE.md lists the third-party skill under CC-BY-SA-4.0" grep -q "skills/$TOB1\` | Trail of Bits (trailofbits/skills) | CC-BY-SA-4.0 | overrides/skills/$TOB1/LICENSE" "$L/NOTICE.md"
check "NOTICE.md does not list this repo's own skill" bash -c "! grep -q quant-researcher '$L/NOTICE.md'"
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
# p1 carries the two tweaks saved above, so a plain re-run stops before overwriting them; --force overrides that.
capture bash "$REPO/bootstrap.sh" --scope project
expect_rc "a re-run that would overwrite the saved tweaks exits 1" 1
capture bash "$REPO/bootstrap.sh" --scope project --force
expect_rc "re-run without packs exits 0" 0
expect_out "a warning names a dropped pack" "WARN: pack 'roles' was installed here before"
check "the packs record is removed" test ! -e "$P/.vibe-setup/packs"

finish
