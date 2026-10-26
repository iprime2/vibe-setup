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
| `bootstrap.sh` | Installer: `--scope user\|project`, `--profile NAME`, `--with-rules`, `--dry-run` |
| `project-init.sh` | Per-project graphify wiring and a code-only graph build |
| `sources.lock` | Allowed sources and pins |
| `scripts/profile_save.sh` | Captures tailoring done in `./.claude` as a profile |
| `scripts/*.py` | Two small helpers (fail-open hooks, marked `CLAUDE.md` blocks) |
| `profiles/<name>/` | Saved tailoring for one product (created by `profile_save.sh`) |
| `rules/CLAUDE.md` | My standing rules (draft); installed only with `--with-rules` |
| `docs/context-mode.md` | Evaluation notes on `context-mode`; not installed |

## Scopes

- **user** (default): everything goes to `~/.claude`. Project repos stay clean, and it applies to every repo
  on that machine. Graphify gets its skill and a `CLAUDE.md` section here, but no hooks.
- **project**: everything goes to `./.claude` of the working directory, plus a `CLAUDE.md` there, with
  graphify's hooks. Files stay untracked until you add them; do not commit them by accident.

Project scope also keeps a pristine copy of what it installed in `.claude/.vibe-setup/pristine/`, so any
tailoring can be diffed against upstream.

`project-init.sh` (run inside a git repo) adds graphify's hooks and git hooks, appends `graphify-out/` to
`.gitignore`, and builds the graph from code only (AST) with a stripped environment, so no API key can be used.
It also creates an untracked `.gitattributes` for graphify's merge driver. Nothing is committed.

## Tailoring the skills to a product

The upstream skills are written for someone else's projects. `SETUP_PROMPT.md` therefore has the agent
interview you about your product, propose tweaks, and apply only the ones you approve as diffs.

1. The agent installs at **project scope** (tailored copies must not sit beside untailored user-level ones;
   which copy wins is not something I could verify).
2. It edits the installed copies in `./.claude/{skills,commands,agents}`. Upstream and the pins are never edited.
3. `scripts/profile_save.sh NAME` diffs `./.claude` against the pristine snapshot and writes
   `profiles/NAME/`: `overrides/` (changed or new files), `remove.txt` (upstream items dropped),
   `profile.lock` (the pins it was made against) and `CHANGES.diff` (human-readable, never applied).
   `PROJECT.md`, the confirmed product summary, is written next to them. Review all of it in a pull request.
4. Next session: `bootstrap.sh --scope project --profile NAME` installs upstream at the pins, then replays the
   profile and adds `PROJECT.md` to `.claude/CLAUDE.md`. It warns if `sources.lock` has moved since the profile
   was saved.

`bootstrap.sh` validates a profile before it installs anything and refuses one that writes outside
`skills/`, `commands/` and `agents/` (no settings or hooks), contains symlinks, or lists unsafe removals.
A profile cannot change `settings.json`.

Keep confidential details (including employer-specific ones) out of `PROJECT.md` and the overrides: this repo
is private, but the files are plain text in git history.

## Tested (2026-10-26, Linux container, throwaway HOME)

- Dry run; full install; re-run (no duplicates); stop on a tampered Ponytail hash (exit 1, nothing installed).
- `--with-rules` appends after graphify's existing `CLAUDE.md` section and replaces its own block on re-run.
- Fail-open rewrite of graphify's hooks keeps other settings keys and valid JSON.
- `--scope project`, and `project-init.sh` on a scratch repo (report says 0 input / 0 output tokens).

- Profiles: tweak, remove and add files in a project install, capture with `profile_save.sh`, replay in a fresh
  project (all changes present, `PROJECT.md` block once), re-run, re-save and compare (identical), pin-drift
  warning, "nothing to save", and five hostile profiles (settings override, `../` and absolute removals,
  non-skill removal, symlink) all refused with nothing installed.

**Not tested:** macOS; whether user-scope skills show up inside an already-running cloud session
(project-scope files did, in an earlier session); the agent actually following the interview and tailoring
steps of the prompt. Only the scripts behind them were exercised, so expect to adjust the wording of
steps 4 and 7 after the first real run.

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
by `bootstrap.sh` from `~/.claude` (or `./.claude`, including `./.claude/.vibe-setup/`). The rules block sits
between `<!-- vibe-setup:begin -->` and `<!-- vibe-setup:end -->` in `CLAUDE.md`; a profile's block uses
`<!-- vibe-setup:begin:profile:NAME -->` and the matching end marker.
