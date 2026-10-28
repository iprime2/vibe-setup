#!/usr/bin/env bash
# Install path: flags, dry run, user scope, idempotence, pin enforcement, fail-open hooks,
# project scope and project-init.sh. Run via tests/run.sh.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NSKILLS=$(( $(lockvar "$REPO" AGENT_SKILLS_LIST | wc -w) + 1 ))   # the lock's skills plus ponytail
NCMDS=$(lockvar "$REPO" AGENT_COMMANDS | wc -w | tr -d ' ')
PIN_PT=$(lockvar "$REPO" PONYTAIL_SKILL_SHA256)
PIN_PTL=$(lockvar "$REPO" PONYTAIL_LICENSE_SHA256)
count() { ls "$1" 2>/dev/null | wc -l | tr -d ' '; }

echo "== flags"
mkdir -p "$W/cwd0"; cd "$W/cwd0" || exit 2
if command -v timeout >/dev/null 2>&1; then
  timeout 10 bash "$REPO/bootstrap.sh" --scope >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 2 ]; then ok "--scope without a value exits 2 (no hang)"; else bad "--scope without a value: rc=$rc"; fi
else
  echo "SKIP: 'timeout' is not installed, so the no-hang check for '--scope' was not run"
fi
capture bash "$REPO/bootstrap.sh" --bogus
expect_rc "an unknown flag exits 2" 2
capture bash "$REPO/bootstrap.sh" --profile x --dry-run
expect_out "a profile at user scope is refused" "needs --scope project"

echo "== dry run changes nothing"
capture bash "$REPO/bootstrap.sh" --dry-run
expect_rc "dry run exits 0" 0
check "dry run created no ~/.claude" test ! -e "$HOME/.claude"

echo "== user-scope install"
capture bash "$REPO/bootstrap.sh" --with-rules
expect_rc "install exits 0" 0
C="$HOME/.claude"
n=$(count "$C/skills")
if [ "$n" -eq $((NSKILLS + 1)) ]; then ok "skills: $NSKILLS from the lock plus graphify"; else bad "skills: $n, wanted $((NSKILLS + 1))"; fi
n=$(count "$C/commands")
if [ "$n" -eq "$NCMDS" ]; then ok "commands: $NCMDS"; else bad "commands: $n, wanted $NCMDS"; fi
n=$(count "$C/agents")
if [ "$n" -gt 0 ]; then ok "agents installed ($n)"; else bad "no agents installed"; fi
if [ "$(sha256_of "$C/skills/ponytail/SKILL.md")" = "$PIN_PT" ]; then ok "ponytail SKILL.md matches the pinned sha256"; else bad "ponytail SKILL.md differs from the pin"; fi
if [ "$(sha256_of "$C/skills/ponytail/LICENSE" 2>/dev/null)" = "$PIN_PTL" ]; then ok "ponytail LICENSE matches the pinned sha256"; else bad "ponytail LICENSE missing or differs from the pin"; fi
lic=""; for s in ponytail $(lockvar "$REPO" AGENT_SKILLS_LIST); do grep -q "MIT License" "$C/skills/$s/LICENSE" 2>/dev/null || lic="$lic $s"; done
if [ -z "$lic" ]; then ok "every Ponytail and Agent Skills skill folder has its upstream MIT LICENSE"; else bad "no LICENSE in:$lic"; fi
check "no 'agent-skills:' prefix is left in the commands" bash -c "! grep -rq 'agent-skills:' '$C/commands'"
if printf '%s\n' "$OUT" | grep -q '^WARN'; then
  bad "dangling-reference warnings were printed"; printf '%s\n' "$OUT" | grep '^WARN' | sed 's/^/    /'
else ok "no dangling-reference warnings"; fi

echo "== re-running is idempotent"
capture bash "$REPO/bootstrap.sh" --with-rules
expect_rc "second run exits 0" 0
if [ "$(grep -c 'vibe-setup:begin' "$C/CLAUDE.md")" -eq 1 ]; then ok "rules block appears once"; else bad "rules block count"; fi
e="$(grep -n 'vibe-setup:end' "$C/CLAUDE.md" | cut -d: -f1)"; g="$(grep -n '^# graphify$' "$C/CLAUDE.md" | cut -d: -f1)"
if [ "$(printf '%s\n' "$e" | grep -c .)" -eq 1 ] && [ -n "$g" ] && [ "$e" -lt "$g" ]; then
  ok "the rules block has one end marker and sits above graphify's section"
else bad "rules block end marker or position"; fi
if [ "$(grep -cE '^#{1,2} graphify' "$C/CLAUDE.md")" -eq 1 ]; then ok "graphify section appears once"; else bad "graphify section count"; fi

echo "== a changed Ponytail file is refused"
copy_repo "$W/tamper"
sed -i.bak 's/^PONYTAIL_SKILL_SHA256=.*/PONYTAIL_SKILL_SHA256="0000000000000000000000000000000000000000000000000000000000000000"/' "$W/tamper/sources.lock"
H2="$W/home2"; mkdir -p "$H2"
capture env HOME="$H2" bash "$W/tamper/bootstrap.sh"
expect_rc "exits 1" 1
expect_out "prints STOP with the reason" "STOP: ponytail SKILL.md differs"
check "ponytail was not installed" test ! -e "$H2/.claude/skills/ponytail"
check "agent skills were not installed" test ! -e "$H2/.claude/skills/interview-me"

echo "== a changed Ponytail LICENSE is refused"
copy_repo "$W/tamper-lic"
sed -i.bak 's/^PONYTAIL_LICENSE_SHA256=.*/PONYTAIL_LICENSE_SHA256="0000000000000000000000000000000000000000000000000000000000000000"/' "$W/tamper-lic/sources.lock"
H4="$W/home4"; mkdir -p "$H4"
capture env HOME="$H4" bash "$W/tamper-lic/bootstrap.sh"
expect_rc "exits 1" 1
expect_out "prints STOP with the reason" "STOP: ponytail LICENSE differs"
check "nothing was installed" test ! -e "$H4/.claude/skills"

echo "== an unreachable Agent Skills commit is refused"
copy_repo "$W/badsha"
sed -i.bak 's/^AGENT_SKILLS_SHA=.*/AGENT_SKILLS_SHA="0123456789abcdef0123456789abcdef01234567"/' "$W/badsha/sources.lock"
H3="$W/home3"; mkdir -p "$H3"
capture env HOME="$H3" bash "$W/badsha/bootstrap.sh"
if [ "$RC" -ne 0 ]; then ok "exits non-zero (rc=$RC)"; else bad "an unreachable pinned commit did not fail"; fi
check "agent skills were not installed" test ! -e "$H3/.claude/skills/interview-me"

echo "== fail-open hook rewrite"
cat > "$W/settings.json" <<'EOF'
{"model":"x","hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/usr/local/bin/graphify hook-guard search"},{"type":"command","command":"echo keep-me"}]}]},"permissions":{"deny":["Read(.env)"]}}
EOF
capture python3 -I "$REPO/scripts/failopen_hooks.py" "$W/settings.json"
expect_out "reports one rewritten hook" "1 hook(s) made fail-open"
check "result is valid JSON; other hooks and keys are kept" python3 -I -c "
import json, sys
d = json.load(open(sys.argv[1]))
cmds = [h['command'] for e in d['hooks']['PreToolUse'] for h in e['hooks']]
assert cmds[0].startswith('command -v graphify') and cmds[1] == 'echo keep-me', cmds
assert d['model'] == 'x' and d['permissions']['deny'] == ['Read(.env)']
" "$W/settings.json"
capture python3 -I "$REPO/scripts/failopen_hooks.py" "$W/settings.json"
expect_out "a second run changes nothing" "0 hook(s) made fail-open"
cmd="$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['hooks']['PreToolUse'][0]['hooks'][0]['command'])" "$W/settings.json" | sed 's/graphify/nonexistent-tool-xyz/g')"
bash -c "$cmd" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then ok "the hook exits 0 when the binary is missing"; else bad "the hook failed with rc=$rc when the binary is missing"; fi

echo "== project scope"
mkdir -p "$W/proj"; cd "$W/proj" || exit 2
capture bash "$REPO/bootstrap.sh" --scope project
expect_rc "project install exits 0" 0
P="$W/proj/.claude"
if [ "$(grep -c 'command -v graphify' "$P/settings.json")" -eq 2 ]; then ok "graphify hooks are fail-open"; else bad "graphify hooks are not fail-open"; fi
SNAP="$P/.vibe-setup/pristine"
n=$(count "$SNAP/skills");   if [ "$n" -eq "$NSKILLS" ]; then ok "snapshot skills: $NSKILLS"; else bad "snapshot skills: $n, wanted $NSKILLS"; fi
n=$(count "$SNAP/commands"); if [ "$n" -eq "$NCMDS" ]; then ok "snapshot commands: $NCMDS"; else bad "snapshot commands: $n, wanted $NCMDS"; fi
n=$(count "$SNAP/agents");   m=$(count "$P/agents"); if [ "$n" -eq "$m" ] && [ "$n" -gt 0 ]; then ok "snapshot agents: $n"; else bad "snapshot agents: $n vs $m"; fi
check "the snapshot excludes graphify's generated skill" test ! -e "$SNAP/skills/graphify"

echo "== project-init.sh"
mkdir -p "$W/nogit"; cd "$W/nogit" || exit 2
capture bash "$REPO/project-init.sh"
expect_rc "outside a git repo it exits 1" 1
expect_out "and says why" "not inside a git repository"
mkdir -p "$W/repo1"; cd "$W/repo1" || exit 2
git init -q
printf 'def a():\n    return b()\n\n\ndef b():\n    return 1\n' > m.py
printf 'node_modules/' > .gitignore    # no trailing newline, on purpose
capture bash "$REPO/project-init.sh"
expect_rc "project-init exits 0" 0
expect_out "the graph build runs with a stripped environment" '^+ env -i'
if [ "$(grep -c 'command -v graphify' .claude/settings.json)" -eq 2 ]; then ok "hooks are fail-open"; else bad "hooks are not fail-open"; fi
check "git hooks are installed" test -x .git/hooks/post-commit
if [ "$(tail -n 2 .gitignore | tr '\n' ' ')" = "node_modules/ graphify-out/ " ]; then ok ".gitignore got graphify-out/ on its own line"; else bad ".gitignore: $(tail -n 2 .gitignore | tr '\n' '|')"; fi
check "GRAPH_REPORT.md exists" test -f graphify-out/GRAPH_REPORT.md
check "the report shows zero token cost (no LLM)" grep -q 'Token cost: 0 input' graphify-out/GRAPH_REPORT.md
check "no commit was created" bash -c '! git rev-parse --verify HEAD'

finish
