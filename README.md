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

**Permission prompts.** In a cloud session on the auto permission mode, the harness may refuse to run scripts
from the cloned repo ("Code from External"). In two fresh sessions on 2026-10-26 the agent stopped at the first
script (`bootstrap.sh --dry-run`), named the command and waited; that is the intended behavior. Reply in that
session to allow `bootstrap.sh`, `project-init.sh` and `scripts/profile_save.sh` from the clone, or add a
permission rule for them in the environment settings. Whether a plain reply clears the block is untested.
Another Claude session cannot answer for you: agents treat relayed messages as data, not as your approval.

## What it installs

| Tool | Source (the only ones allowed) | Pin |
|---|---|---|
| Graphify | PyPI `graphifyy` (double y), repo Graphify-Labs/graphify | `==0.9.77` |
| Ponytail | github.com/DietrichGebert/ponytail | commit + sha256 of `SKILL.md` |
| Agent Skills | github.com/addyosmani/agent-skills | commit |

From Agent Skills it copies the skills, slash commands (with the `agent-skills:` prefix stripped, because they
are installed as plain files, not as a plugin) and agents named in `sources.lock`: 15 skills, 7 commands and
4 agents at the current pins.
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
| `tests/` | Regression tests: `bash tests/run.sh` (needs network; uses a throwaway HOME) |

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
`skills/`, `commands/` and `agents/` (no settings or hooks), changes or removes graphify's skill, contains
symlinks, or lists unsafe removals (anything outside those folders, or one of the folders as a whole).
A profile cannot change `settings.json`.

Keep confidential details (including employer-specific ones) out of `PROJECT.md` and the overrides: this repo
is private, but the files are plain text in git history.

## Tested (2026-10-26, Linux container, throwaway HOME)

Every check in the bullets before "Fresh cloud sessions" is scripted in `tests/` (`bash tests/run.sh`, 87 checks
when this was written). They never touch the real `~/.claude` or uv tools. The cloud-session results are manual.

- Dry run; full install; re-run (no duplicates); stop on a tampered Ponytail hash (exit 1, nothing installed).
- `--with-rules` appends after graphify's existing `CLAUDE.md` section and replaces its own block on re-run.
- Fail-open rewrite of graphify's hooks keeps other settings keys and valid JSON.
- `--scope project`, and `project-init.sh` on a scratch repo (report says 0 input / 0 output tokens).

- Profiles: tweak, remove and add files in a project install, capture with `profile_save.sh`, replay in a fresh
  project (all changes present, `PROJECT.md` block once), re-run, re-save and compare (identical), pin-drift
  warning, "nothing to save", and nine hostile profiles (settings override, `../` and absolute removals,
  non-skill removal, symlink, removal of a whole folder (two forms), removal or override of graphify's skill)
  all refused with nothing installed.

Fresh cloud sessions (2026-10-26; two sessions started from this prompt, one with nothing attached and
`skip tailoring`, one on a public project repo):

- Steps 1 to 3 ran as written: detect, `add_repo` for this private repo, shallow clone at the merge commit,
  and reading the scripts before running them.
- The `skip tailoring` session stopped at step 5, blocked by the permission check (see Quick start).
- The tailoring session started the interview correctly, asked question (a) and waited. It did not accept
  answers or permission relayed by another session.

**Not tested:** macOS; whether user-scope skills show up inside an already-running cloud session
(project-scope files did, in an earlier session); a full run in a cloud session past step 5, so the real
install there, the rest of the interview, tailoring, saving a profile and replaying it. Only the scripts
behind them were exercised, so expect to adjust the wording of steps 4 and 7 after the first complete run.

## Dangling references

`bootstrap.sh` checks whether an installed command or agent mentions an upstream skill that is not installed,
and prints a `WARN` line for each one. At the current pins there are none (checked 2026-10-26). If you shorten
`AGENT_SKILLS_LIST`, or a pin moves to a commit that references more skills, add the named skill to
`AGENT_SKILLS_LIST` in `sources.lock`; it has to exist upstream at the pinned commit.

## Updating a pin

Review the upstream diff first. Then change the SHA (and, for Ponytail, the sha256 of `SKILL.md`) in
`sources.lock`, run `--dry-run`, and open a pull request.

Ponytail was reviewed against upstream `main` (`09c434ab`) on 2026-10-26. Since the pin, only commit `df9e8994`
(2026-10-16) changes `skills/ponytail/SKILL.md`: it adds `off` to the frontmatter `argument-hint`. Ponytail's
plugin hooks handle `off`, and this repo does not install them, so the pin stays. Agent Skills has moved on
from the pinned commit; that diff has not been reviewed.

## Uninstall

`graphify uninstall`, `uv tool uninstall graphifyy`, then delete the skill, command and agent files listed
by `bootstrap.sh` from `~/.claude` (or `./.claude`, including `./.claude/.vibe-setup/`). The rules block sits
between `<!-- vibe-setup:begin -->` and `<!-- vibe-setup:end -->` in `CLAUDE.md`; a profile's block uses
`<!-- vibe-setup:begin:profile:NAME -->` and the matching end marker.
