# context-mode (evaluated, not installed)

Plugin `context-mode@context-mode`, repo `mksglu/context-mode`, v1.0.169, licence Elastic-2.0.
Evaluated on 2026-10-25 from its README and plugin manifests only; the hook source was not read.
It is **not** in `sources.lock`, so `bootstrap.sh` never installs it.

## What it does

An MCP server (`ctx_execute`, `ctx_batch_execute`, `ctx_execute_file`, `ctx_index`, `ctx_search`,
`ctx_fetch_and_index` plus stats/doctor/upgrade/purge) that keeps large tool output out of the context
window, and six hooks (PreToolUse, PostToolUse, UserPromptSubmit, PreCompact, SessionStart, Stop) that
record session events in a per-project SQLite database.

## For setting up a new session

- A fresh session starts empty: per the README, previous session data is deleted unless you resume with
  `--continue`, `--resume` or `/resume`.
- After compaction or resume it restores the last prompt, tasks, files, decisions and `CLAUDE.md` paths.
- `ctx_index` / `context-mode index . --source project:<name>` loads docs into a persistent search index.
- Cloud containers are ephemeral, so the database is lost with the container. In cloud sessions the gain
  is context savings and survival across compaction, not memory across sessions (my inference).

## Concerns before installing

- Its PreToolUse hooks cover `Bash`, `Read` and `Grep`, the same tools graphify's hooks guard. Interaction untested.
- PostToolUse records almost every tool call, including MCP calls. The README says credentials in MCP inputs
  are redacted; it does not say the same for prompts or outputs.
- "Think in code" routes work through `ctx_execute`, which runs arbitrary code. The README says it is not an OS sandbox.
- `package.json` has a `postinstall` script and a native dependency (`better-sqlite3`); Node >= 22.5 required.
- The README's "used at Microsoft, Google, ..." badges link to `#`, and the 98% savings figure is its own number.

## Install commands (from its README, untested)

    claude plugin marketplace add mksglu/context-mode
    claude plugin install context-mode@context-mode --scope user

MCP-only trial without hooks (README says about 60% savings instead of 98%):

    claude mcp add context-mode -- npx -y context-mode
