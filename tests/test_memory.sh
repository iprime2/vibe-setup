#!/usr/bin/env bash
# The memory pack's checker (skills/agent-memory/check.py): formats, likely secrets reported without their
# value, symlinks, and that the skill's own examples pass it. Offline and fast. Run via tests/run.sh.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILL="$REPO/skills/agent-memory"
CHECK="$SKILL/check.py"
chk() { capture python3 -I "$CHECK" "$@"; }

# examples DIR: write the skill's own lesson and handoff examples (its markdown blocks) into DIR/.agent-memory
examples() {
  mkdir -p "$1/.agent-memory/handoffs"
  python3 -I - "$SKILL/SKILL.md" "$1/.agent-memory" <<'EOF'
import pathlib, re, sys
blocks = re.findall(r"```markdown\n(.*?)```", pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"), re.S)
out = pathlib.Path(sys.argv[2])
(out / "LESSONS.md").write_text(blocks[0] + "\n" + blocks[1], encoding="utf-8")
h = blocks[2]
for a, b in [("<title>", "Example"), ("<YYYY-MM-DD HH:MM>", "2026-10-26 18:30"), ("<agent or tool>", "an agent"),
             ("<any agent, or who>", "any agent"), ("<owner/repo or path>", "owner/repo"), ("<name>", "feat/x"),
             ("<short sha>", "1a2b3c4"), ("<clean, or n files uncommitted>", "clean"),
             ("<in progress | blocked on ... | done, waiting on ...>", "in progress")]:
    h = h.replace(a, b)
(out / "handoffs" / "2026-10-26-1830-example.md").write_text(h, encoding="utf-8")
EOF
}

echo "== nothing to check"
mkdir -p "$W/m0"; cd "$W/m0" || exit 2
chk
expect_rc "no .agent-memory: exits 0" 0
expect_out "and says so" "nothing to check"
chk a b
expect_rc "two arguments: usage error" 2

echo "== the skill's own examples pass"
examples "$W/m1"; cd "$W/m1" || exit 2
before="$(cd .agent-memory && find . -type f -exec cat {} + | cksum)"
chk
expect_rc "examples: exits 0" 0
expect_out "counts one lesson and one handoff" "ok: 1 lesson(s), 1 handoff(s)"
check "the checker changes nothing" test "$before" = "$(cd .agent-memory && find . -type f -exec cat {} + | cksum)"
chk "$W/m1/.agent-memory"
expect_rc "an explicit directory works too" 0
want="$(python3 -I -B -c 'import importlib.util as u, sys
s = u.spec_from_file_location("check", sys.argv[1]); m = u.module_from_spec(s); s.loader.exec_module(m)
print("\n".join(m.HANDOFF_SECTIONS))' "$CHECK")"
missing=""; while IFS= read -r s; do grep -qxF "## $s" "$SKILL/SKILL.md" || missing="$missing [$s]"; done <<< "$want"
if [ -z "$missing" ]; then ok "the skill's handoff format has every section the checker requires"; else bad "not in SKILL.md:$missing"; fi
nc=0; for c in learn promote-lessons handoff pickup; do grep -q 'agent-memory skill' "$REPO/commands/$c.md" && nc=$((nc + 1)); done
check "all four commands point to the agent-memory skill" test "$nc" -eq 4

echo "== lesson format problems are named"
mkdir -p "$W/m2/.agent-memory"; cd "$W/m2" || exit 2
cat > .agent-memory/LESSONS.md <<'EOF'
# Lessons

### good-one
- When: a trigger
- Do: an action
- Why: a reason
- Scope: project
- Status: candidate
- Seen: 1, last 2026-10-26
- Evidence:
  - 2026-10-26: seen once

### good-one
- When: a trigger
- Do: an action
- Why: a reason
- Scope: project
- Status: candidate
- Seen: 1, last 2026-10-26
- Evidence:
  - 2026-10-26: duplicate id

### Bad_Id
- When: a trigger
- Do: an action
- Why: a reason
- Scope: everywhere
- Status: maybe
- Seen: 0, last 2026-13-40
- Mood: unknown field
- Evidence:
  - yesterday: no date

### no-evidence
- When: a trigger
- Do:
- Scope: generic
- Status: retired
- Seen: 1, last 2026-10-26
EOF
chk
expect_rc "exits 1" 1
expect_out "duplicate id" "duplicate id 'good-one'"
expect_out "bad id" "id 'Bad_Id' must be lowercase"
expect_out "bad Scope" "Scope must be 'project' or 'generic'"
expect_out "bad Status" "Status must be candidate"
expect_out "bad Seen" "Seen must read"
expect_out "unknown field" "unknown field 'Mood'"
expect_out "undated evidence" "evidence lines read"
expect_out "missing Evidence" "missing field 'Evidence'"
expect_out "missing Why" "missing field 'Why'"
expect_out "empty Do" "field 'Do' is empty"
expect_out "retired needs a reason" "'retired: <reason>'"
printf 'Some notes\n' > .agent-memory/LESSONS.md
chk
expect_out "a file without the header" "must start with '# Lessons'"

echo "== handoff format problems are named"
examples "$W/m3"; cd "$W/m3/.agent-memory/handoffs" || exit 2
good="2026-10-26-1830-example.md"
sed '/^## Did not work (do not retry)$/,/^## Decisions$/{/^## Decisions$/!d;}' "$good" > 2026-10-26-1831-no-section.md
python3 -I - "$good" <<'EOF'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
open("2026-10-26-1832-no-closing.md", "w", encoding="utf-8").write(
    "\n".join(l for l in t.splitlines() if not l.startswith("Nothing in this handoff")) + "\n")
i = t.index("## Open questions\n") + len("## Open questions\n")
j = t.index("## Rules in force")
open("2026-10-26-1833-empty-section.md", "w", encoding="utf-8").write(t[:i] + "\n" + t[j:])
open("2026-10-26-1834-no-repo.md", "w", encoding="utf-8").write(
    "\n".join(l for l in t.splitlines() if not l.startswith("- Repo:")) + "\n")
EOF
cp "$good" "handoff notes.md"
cd "$W/m3" || exit 2
chk
expect_rc "exits 1" 1
expect_out "missing section" "1831-no-section.md: missing section '## Did not work (do not retry)'"
expect_out "missing closing line" "1832-no-closing.md: missing the closing line"
expect_out "empty section" "1833-empty-section.md: section '## Open questions' is empty"
expect_out "missing header line" "1834-no-repo.md: missing '- Repo: ...'"
expect_out "bad file name" "handoff notes.md: name must be YYYY-MM-DD-HHMM-<slug>.md"
if printf '%s\n' "$OUT" | grep -q "1830-example.md"; then bad "the good handoff is flagged"; else ok "the good handoff is not flagged"; fi

echo "== likely secrets are reported by line, never by value"
examples "$W/m4"; cd "$W/m4" || exit 2
# Fake values, assembled here so that no secret-shaped string sits in the repo.
tok="gh""p_$(printf 'Ab1%.0s' $(seq 12))"
key="-----BEGIN RSA PRIVATE"" KEY-----"
pw="s3cr3t-$(printf 'x%.0s' $(seq 9))"
url="postgres://admin:${pw}@db.internal:5432/app"
cloud="AKI""A$(printf 'Q%.0s' $(seq 16))"
{
  cat .agent-memory/LESSONS.md
  printf '\n### leaked-values\n- When: %s\n- Do: use %s\n- Why: password = %s\n- Scope: project\n' "$tok" "$url" "$pw"
  printf -- '- Status: candidate\n- Seen: 1, last 2026-10-26\n- Evidence:\n  - 2026-10-26: %s\n' "$cloud"
} > "$W/l.md" && mv "$W/l.md" .agent-memory/LESSONS.md
printf '%s\nAAAA\n' "$key" > .agent-memory/notes.txt
chk
expect_rc "exits 1" 1
expect_out "code host token" "LESSONS.md:[0-9]*: possible code host token"
expect_out "password in a URL" "possible password in a URL"
expect_out "secret assignment" "possible secret assignment"
expect_out "cloud access key" "possible cloud access key"
expect_out "private key in any file" "notes.txt:1: possible private key"
leak=""; for v in "$tok" "$pw" "$cloud" "$key"; do printf '%s\n' "$OUT" | grep -qF -- "$v" && leak="$leak [${#v} chars]"; done
if [ -z "$leak" ]; then ok "no value appears in the output"; else bad "values printed:$leak"; fi

echo "== ordinary text is not flagged"
examples "$W/m5"; cd "$W/m5" || exit 2
cat >> .agent-memory/LESSONS.md <<'EOF'

### read-the-key-from-the-environment
- When: a client needs the API key, a token or a password
- Do: read it from the environment (`token=$SERVICE_TOKEN`), as in `postgres://<user>:<password>@host/db`
- Why: the secret store injects it; never paste the value into code, tests or memory
- Scope: generic
- Status: candidate
- Seen: 1, last 2026-10-26
- Evidence:
  - 2026-10-26: user correction; the password: is set by the deploy job
EOF
chk
expect_rc "names of secrets, placeholders and variables pass" 0

echo "== symlinks are skipped and reported"
examples "$W/m6"; cd "$W/m6" || exit 2
printf 'password = %s\n' "$pw" > "$W/outside.md"
ln -s "$W/outside.md" .agent-memory/handoffs/2026-10-26-1840-linked.md
chk
expect_rc "exits 1" 1
expect_out "the link is named" "1840-linked.md: symlink skipped"
if printf '%s\n' "$OUT" | grep -q "possible secret"; then bad "the link was followed"; else ok "the link is not followed"; fi
ln -s "$W/m1/.agent-memory" "$W/m7"
chk "$W/m7"
expect_rc "a symlinked memory directory is refused" 1
check "no bytecode was written into the skill folder (it is copied as is)" test ! -e "$SKILL/__pycache__"

finish
