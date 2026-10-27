#!/usr/bin/env bash
# Profiles: tailor, capture, replay, round trip, pin drift and hostile profiles. Run via tests/run.sh.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

R="$W/repo"; copy_repo "$R"     # a throwaway copy: profile_save.sh writes into its own profiles/
NSKILLS=$(( $(lockvar "$R" AGENT_SKILLS_LIST | wc -w) + 1 ))
NCMDS=$(lockvar "$R" AGENT_COMMANDS | wc -w | tr -d ' ')
count() { ls "$1" 2>/dev/null | wc -l | tr -d ' '; }

echo "== early validation"
mkdir -p "$W/p0"; cd "$W/p0" || exit 2
capture bash "$R/bootstrap.sh" --scope project --profile nope --dry-run
expect_out "an unknown profile is refused" "not found"
capture bash "$R/bootstrap.sh" --scope project --profile Bad_Name --dry-run
expect_out "a bad profile name is refused" "invalid profile name"

echo "== project install keeps a pristine snapshot"
mkdir -p "$W/p1"; cd "$W/p1" || exit 2
capture bash "$R/bootstrap.sh" --scope project
expect_rc "install exits 0" 0
SNAP="$W/p1/.claude/.vibe-setup/pristine"
n=$(count "$SNAP/skills");   if [ "$n" -eq "$NSKILLS" ]; then ok "snapshot skills: $NSKILLS"; else bad "snapshot skills: $n, wanted $NSKILLS"; fi
n=$(count "$SNAP/commands"); if [ "$n" -eq "$NCMDS" ]; then ok "snapshot commands: $NCMDS"; else bad "snapshot commands: $n, wanted $NCMDS"; fi
check "the snapshot excludes graphify's generated skill" test ! -e "$SNAP/skills/graphify"

echo "== tailor, then capture"
cd "$W/p1/.claude" || exit 2
echo "- ACME: every endpoint must declare a latency budget." >> skills/frontend-ui-engineering/SKILL.md
rm -rf skills/shipping-and-launch
mkdir skills/acme-domain
printf -- '---\nname: acme-domain\ndescription: Acme domain rules.\n---\nBody\n' > skills/acme-domain/SKILL.md
echo "<!-- tweak -->" >> agents/security-auditor.md
rm commands/ship.md
mkdir -p "$R/profiles/acme"
printf '# Acme\nTrading operations assistant.\n' > "$R/profiles/acme/PROJECT.md"
cd "$W/p1" || exit 2
capture bash "$R/scripts/profile_save.sh" acme
expect_rc "profile_save exits 0" 0
A="$R/profiles/acme"
check "override: tweaked skill saved" test -f "$A/overrides/skills/frontend-ui-engineering/SKILL.md"
check "override: new skill saved" test -f "$A/overrides/skills/acme-domain/SKILL.md"
check "override: tweaked agent saved" test -f "$A/overrides/agents/security-auditor.md"
check "an unchanged skill is not saved" test ! -e "$A/overrides/skills/interview-me"
check "graphify's skill is not saved" test ! -e "$A/overrides/skills/graphify"
if [ "$(sort "$A/remove.txt" | tr '\n' ' ')" = "commands/ship.md skills/shipping-and-launch " ]; then ok "remove.txt lists exactly the two removals"; else bad "remove.txt: $(tr '\n' ' ' < "$A/remove.txt")"; fi
check "CHANGES.diff shows the tweak" grep -q 'ACME: every endpoint' "$A/CHANGES.diff"
check "PROJECT.md is left alone" grep -q 'Trading operations' "$A/PROJECT.md"
check "profile.lock records the pins" grep -q "PROFILE_AGENT_SKILLS_SHA=\"$(lockvar "$R" AGENT_SKILLS_SHA)\"" "$A/profile.lock"
check "the tailored Agent Skills skill keeps its MIT LICENSE" grep -q "MIT License" "$A/overrides/skills/frontend-ui-engineering/LICENSE"
check "the tailored Agent Skills agent gets LICENSES/agent-skills.txt" grep -q "MIT License" "$A/LICENSES/agent-skills.txt"
rows="$(grep '^| `' "$A/NOTICE.md" 2>/dev/null | cut -d'`' -f2 | sort | tr '\n' ' ')"
if [ "$rows" = "agents/security-auditor.md skills/frontend-ui-engineering " ]; then ok "NOTICE.md lists exactly the two tailored third-party items"; else bad "NOTICE.md rows: $rows"; fi
check "NOTICE.md names the source and the licence text" grep -q 'agents/security-auditor.md` | Agent Skills (addyosmani/agent-skills) | MIT | LICENSES/agent-skills.txt' "$A/NOTICE.md"

echo "== replay in a fresh project"
mkdir -p "$W/p2"; cd "$W/p2" || exit 2
capture bash "$R/bootstrap.sh" --scope project --profile acme
expect_rc "replay exits 0" 0
C="$W/p2/.claude"
check "the tweak is present" grep -q 'ACME: every endpoint' "$C/skills/frontend-ui-engineering/SKILL.md"
check "the removed skill is gone" test ! -e "$C/skills/shipping-and-launch"
check "the removed command is gone" test ! -e "$C/commands/ship.md"
check "the new skill is present" test -f "$C/skills/acme-domain/SKILL.md"
check "the tweaked agent is present" grep -q 'tweak' "$C/agents/security-auditor.md"
if [ "$(grep -c 'vibe-setup:begin:profile:acme' "$C/CLAUDE.md")" -eq 1 ]; then ok "PROJECT.md block is in CLAUDE.md once"; else bad "PROJECT.md block count"; fi
if printf '%s\n' "$OUT" | grep -q 'WARN: profile'; then bad "pin warning although the pins match"; else ok "no pin warning when the pins match"; fi
check "the snapshot is still pristine (no new skill)" test ! -e "$C/.vibe-setup/pristine/skills/acme-domain"
check "the snapshot still has the removed skill" test -d "$C/.vibe-setup/pristine/skills/shipping-and-launch"

echo "== re-running and re-saving"
capture bash "$R/bootstrap.sh" --scope project --profile acme
expect_rc "second replay exits 0" 0
if [ "$(grep -c 'vibe-setup:begin:profile:acme' "$C/CLAUDE.md")" -eq 1 ]; then ok "still one PROJECT.md block"; else bad "PROJECT.md block duplicated"; fi
cd "$W/p2" || exit 2
capture bash "$R/scripts/profile_save.sh" acme2
expect_rc "re-save exits 0" 0
check "round trip: overrides identical" diff -r "$R/profiles/acme/overrides" "$R/profiles/acme2/overrides"
check "round trip: remove.txt identical" diff "$R/profiles/acme/remove.txt" "$R/profiles/acme2/remove.txt"
check "round trip: NOTICE.md and LICENSES identical" bash -c "diff '$R/profiles/acme/NOTICE.md' '$R/profiles/acme2/NOTICE.md' && diff -r '$R/profiles/acme/LICENSES' '$R/profiles/acme2/LICENSES'"

echo "== no differences means nothing is saved"
mkdir -p "$W/p3"; cd "$W/p3" || exit 2
capture bash "$R/bootstrap.sh" --scope project
expect_rc "plain project install exits 0" 0
capture bash "$R/scripts/profile_save.sh" nochange
expect_out "reports there is nothing to save" "nothing to save"
check "no profile directory was created" test ! -e "$R/profiles/nochange"
mkdir -p "$W/p3/.claude/skills/own-skill"
printf -- '---\nname: own-skill\ndescription: A new skill.\n---\nBody\n' > "$W/p3/.claude/skills/own-skill/SKILL.md"
capture bash "$R/scripts/profile_save.sh" newonly
expect_rc "a profile with only a new skill saves" 0
check "it has no NOTICE.md and no LICENSES" bash -c "[ ! -e '$R/profiles/newonly/NOTICE.md' ] && [ ! -e '$R/profiles/newonly/LICENSES' ]"

echo "== an install from before the licences were copied warns"
find "$W/p3/.claude/skills" "$W/p3/.claude/.vibe-setup/pristine/skills" -name LICENSE -delete
echo "<!-- tweak -->" >> "$W/p3/.claude/agents/security-auditor.md"
echo "<!-- tweak -->" >> "$W/p3/.claude/skills/interview-me/SKILL.md"
capture bash "$R/scripts/profile_save.sh" oldinstall
expect_rc "the save still exits 0" 0
expect_out "a warning names both items" "WARN: no upstream LICENSE in this install for: skills/interview-me agents/security-auditor.md"
check "NOTICE.md marks the licence text as missing" grep -q 'agents/security-auditor.md` | Agent Skills (addyosmani/agent-skills) | MIT | missing' "$R/profiles/oldinstall/NOTICE.md"

echo "== pin drift warns"
sed -i.bak 's/^PROFILE_AGENT_SKILLS_SHA=.*/PROFILE_AGENT_SKILLS_SHA="deadbeef"/' "$R/profiles/acme/profile.lock"
mkdir -p "$W/p4"; cd "$W/p4" || exit 2
capture bash "$R/bootstrap.sh" --scope project --profile acme
expect_out "a pin-drift warning is printed" "WARN: profile .acme. was tailored against different pins"

echo "== hostile profiles are refused before anything is installed"
mkevil() { mkdir -p "$R/profiles/$1"; printf 'PROFILE_AGENT_SKILLS_SHA="x"\nPROFILE_PONYTAIL_SHA="x"\n' > "$R/profiles/$1/profile.lock"; }
evil() {   # name, expected message ; runs in a fresh directory
  local n="$1" want="$2" d="$W/evil-$1"
  mkdir -p "$d"; cd "$d" || return
  capture bash "$R/bootstrap.sh" --scope project --profile "$n"
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q "$want" && [ ! -d "$d/.claude" ]; then
    ok "$n: refused ($want), nothing installed"
  else bad "$n: rc=$RC"; printf '%s\n' "$OUT" | tail -3 | sed 's/^/    /'; fi
}
mkevil evil1; mkdir -p "$R/profiles/evil1/overrides"; echo '{"hooks":{}}' > "$R/profiles/evil1/overrides/settings.json"
evil evil1 "may only contain skills"
mkevil evil2; printf '../../x\n' > "$R/profiles/evil2/remove.txt"
evil evil2 "unsafe path"
mkevil evil3; printf 'settings.json\n' > "$R/profiles/evil3/remove.txt"
evil evil3 "may only name"
mkevil evil4; mkdir -p "$R/profiles/evil4/overrides/skills/x"; ln -s /etc/passwd "$R/profiles/evil4/overrides/skills/x/SKILL.md"
evil evil4 "symlinks"
mkevil evil5; printf '/etc/passwd\n' > "$R/profiles/evil5/remove.txt"
evil evil5 "unsafe path"
mkevil evil6; printf 'skills/\n' > "$R/profiles/evil6/remove.txt"
evil evil6 "unsafe path"
mkevil evil7; printf 'commands//\n' > "$R/profiles/evil7/remove.txt"
evil evil7 "unsafe path"
mkevil evil8; printf 'skills/graphify\n' > "$R/profiles/evil8/remove.txt"
evil evil8 "must not name graphify"
mkevil evil9; mkdir -p "$R/profiles/evil9/overrides/skills/graphify"; echo x > "$R/profiles/evil9/overrides/skills/graphify/SKILL.md"
evil evil9 "must not change graphify"

echo "== a removal that only starts with 'graphify' is still accepted"
mkevil okname; printf 'skills/graphify-notes\n' > "$R/profiles/okname/remove.txt"
mkdir -p "$W/ok"; cd "$W/ok" || exit 2
capture bash "$R/bootstrap.sh" --scope project --profile okname --dry-run
expect_rc "the dry run exits 0" 0
expect_out "and plans the removal" "rm -rf .*/skills/graphify-notes"

finish
