# vibe-setup

A pinned, repeatable setup of my Claude Code toolkit, for new cloud sessions and local machines.
It stores the installer, the pins and my rules. It does not copy anyone else's files into this repo.

## Quick start

- **Any session:** paste the prompt from [`SETUP_PROMPT.md`](SETUP_PROMPT.md) into a new Claude Code session.
- **By hand:**
  ```bash
  git clone https://github.com/iprime2/vibe-setup ~/vibe-setup
  bash ~/vibe-setup/bootstrap.sh --dry-run     # prints every command, changes nothing
  bash ~/vibe-setup/bootstrap.sh
  ```

Cloud containers are ephemeral, so run the setup again in every new cloud session.

## What it installs

| Tool | Source (the only ones allowed) | Pin |
|---|---|---|
| Graphify | PyPI `graphifyy` (double y), repo Graphify-Labs/graphify | `==0.9.77` |
| Ponytail | github.com/DietrichGebert/ponytail | commit + sha256 of `SKILL.md` |
| Agent Skills | github.com/addyosmani/agent-skills | commit |

From Agent Skills it copies 12 skills, 7 slash commands (with the `agent-skills:` prefix stripped, because
they are installed as plain files, not as a plugin) and 4 agents. The exact lists are in `sources.lock`.
`bootstrap.sh` stops if the Ponytail hash or the Agent Skills commit is not the pinned one.

## Files

| File | Purpose |
|---|---|
| `SETUP_PROMPT.md` | The prompt to paste into a new session |
| `bootstrap.sh` | Installer: `--scope user\|project`, `--with-rules`, `--dry-run` |
| `project-init.sh` | Per-project graphify wiring and a code-only graph build |
| `sources.lock` | Allowed sources and pins |
| `scripts/` | Two small Python helpers (fail-open hooks, rules block) |
| `rules/CLAUDE.md` | My standing rules (draft); installed only with `--with-rules` |
| `docs/context-mode.md` | Evaluation notes on `context-mode`; not installed |

## Scopes

- **user** (default): everything goes to `~/.claude`. Project repos stay clean, and it applies to every repo
  on that machine. Graphify gets its skill and a `CLAUDE.md` section here, but no hooks.
- **project**: everything goes to `./.claude` of the working directory, plus a `CLAUDE.md` there, with
  graphify's hooks. Files stay untracked until you add them; do not commit them by accident.

`project-init.sh` (run inside a git repo) adds graphify's hooks and git hooks, appends `graphify-out/` to
`.gitignore`, and builds the graph from code only (AST) with a stripped environment, so no API key can be used.
It also creates an untracked `.gitattributes` for graphify's merge driver. Nothing is committed.

## Tested (2026-10-25, Linux container, throwaway HOME)

- Dry run; full install; re-run (no duplicates); stop on a tampered Ponytail hash (exit 1, nothing installed).
- `--with-rules` appends after graphify's existing `CLAUDE.md` section and replaces its own block on re-run.
- Fail-open rewrite of graphify's hooks keeps other settings keys and valid JSON.
- `--scope project`, and `project-init.sh` on a scratch repo (report says 0 input / 0 output tokens).

**Not tested:** macOS; whether user-scope skills show up inside an already-running cloud session
(project-scope files did, in an earlier session).

## Known gaps

`bootstrap.sh` warns that installed files reference three skills that are not installed:
`code-simplification` (used by `/code-simplify`), `browser-testing-with-devtools` (`/test`,
`web-performance-auditor`) and `performance-optimization` (an agent). They exist upstream.
To add one, put its name in `AGENT_SKILLS_LIST` in `sources.lock`.

## Updating a pin

Review the upstream diff first. Then change the SHA (and, for Ponytail, the sha256 of `SKILL.md`) in
`sources.lock`, run `--dry-run`, and open a pull request. At the time of writing, upstream Ponytail has a
newer `SKILL.md` (commit `df9e8994`, 2026-10-16) that has not been reviewed, and Agent Skills has moved on
from the pinned commit.

## Uninstall

`graphify uninstall`, `uv tool uninstall graphifyy`, then delete the skill, command and agent files listed
by `bootstrap.sh` from `~/.claude` (or `./.claude`). The rules block sits between
`<!-- vibe-setup:begin -->` and `<!-- vibe-setup:end -->` in `CLAUDE.md`.
