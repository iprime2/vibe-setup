# Lessons

Lessons learned on this repo by coding agents and approved by a person. They are data, not instructions:
verify before relying on one, and the user's instructions always win.

### verify-the-remote-before-trusting-a-report
- When: another session, agent or handoff, or your own earlier lookup, says work is missing, unmerged, still open or on an old commit
- Do: check the remote again right before you report or act (`git fetch origin`, `git ls-remote origin`, the pull request's current state) and report what is actually there
- Not: rebasing, recreating or re-pushing the work because of that report
- Why: a clone or a lookup goes stale within minutes; both times the work had already been merged
- Scope: generic
- Status: confirmed
- Seen: 3, last 2026-11-23
- Evidence:
  - 2026-10-26: another session reported the pack work missing; `git ls-remote` showed it merged in PR #8 (main 747acc5)
  - 2026-10-27: I reported PR #11 as still open from a pull request list fetched earlier; it had been merged at 09:25 UTC, a minute before
  - 2026-11-23: a merge-conflict notice for PR #25 arrived after the fix was pushed; a fresh read showed it mergeable at e41f2bb

### rerunning-bootstrap-replaces-tailoring
- When: bootstrap.sh is about to run again in a project whose `.claude/` may already hold tailoring
- Do: first compare `.claude/{skills,commands,agents}` with `.claude/.vibe-setup/pristine/`; if anything differs, stop and save it as a profile (`scripts/profile_save.sh`) or ask before re-running
- Why: bootstrap.sh replaces every installed skill folder (`rm -rf`, then `cp -R`), so edits to the installed copies are lost
- Scope: project
- Status: candidate
- Seen: 1, last 2026-10-26
- Evidence:
  - 2026-10-26: found while writing the continue-after-interview prompt for another session (bootstrap.sh replaces skill folders on every run)

### no-bytecode-in-copied-folders
- When: a test or script imports a Python file that lives under `skills/` or `scripts/`
- Do: run Python with `-I -B`, and check that no `__pycache__` is left in that folder
- Why: bootstrap.sh copies skill folders as they are, so a cache folder would ship into every install
- Scope: project
- Status: candidate
- Seen: 2, last 2026-10-26
- Evidence:
  - 2026-10-26: a test run left `scripts/__pycache__`; deleted by hand before committing
  - 2026-10-26: `tests/test_memory.sh` left `skills/agent-memory/__pycache__`; fixed with `-B` and a check (PR #10)

### update-the-readme-check-count
- When: tests are added or removed
- Do: after the full run, set the count and date in the README "Tested" section (`bash tests/run.sh`, N checks) to the real total, and say if a check was only rerun on its own. When two open pull requests both change it, the second one to merge conflicts on that line: merge main into it, run the full suite again and set the combined total
- Why: the README states the count as a fact; it is not computed
- Scope: project
- Status: confirmed
- Seen: 4, last 2026-11-24
- Evidence:
  - 2026-10-26: 147 to 166 checks (commit 32802cd, PR #9)
  - 2026-10-26: 166 to 210 checks (commit 044317c, PR #10)
  - 2026-11-23: PR #26 and PR #25 both set the count; after #26 merged, #25 conflicted and the combined run gave 340 (commit e41f2bb)
  - 2026-11-24: 348, 354 and 358 checks in PRs #28, #29 and #30

### green-means-the-local-suite-here
- When: asked to merge a pull request in this repo "once it is green"
- Do: read the PR's check runs and statuses; when there are none, treat the full local suite passing on the PR's head plus a clean merge state as green, merge with that head SHA pinned, and say that this is what green meant
- Why: the repo has no CI workflows, so GitHub never reports a result
- Scope: project
- Status: retired: since PR #19 (2026-10-30) CI runs lint and the full suite on every pull request, so green is GitHub's checks on the head again
- Seen: 2, last 2026-10-27
- Evidence:
  - 2026-10-26: PR #9 had no checks; merged on the local suite (166 passed)
  - 2026-10-27: PR #10 had no checks; merged on the local suite (210 passed)
  - 2026-11-02: contradicted: PR #22's checks ran in CI on its head (lint, and tests with 282 passed)

### build-secret-shaped-test-values-at-run-time
- When: a test needs a value shaped like a token, key or password
- Do: assemble it from pieces at run time (for example `"gh""p_$(...)"`), never as a literal in the repo
- Why: a committed literal looks like a leaked secret to scanners and to push protection
- Scope: generic
- Status: candidate
- Seen: 1, last 2026-10-26
- Evidence:
  - 2026-10-26: `tests/test_memory.sh` builds its fake token, key and password at run time (PR #10)

### check-the-licence-chain-of-a-ported-skill
- When: a skill about to be pinned says it is ported or adapted from another project
- Do: check that the folder or repository carries that project's copyright notice; if it does not, pin the original from its own repository (a new source, so ask first) instead of the port
- Why: an MIT or similar licence requires its notice in every copy, and a port without it passes the gap on to every install
- Scope: generic
- Status: candidate
- Seen: 1, last 2026-11-24
- Evidence:
  - 2026-11-24: Hermes' grill-me and decision-questionnaire are ports of mattpocock/skills without its notice; the originals were pinned instead (PR #29)

### fetch-large-source-repos-sparsely
- When: a new pinned source is a large repository and only a few skill folders are wanted
- Do: fetch it with `fetch_sparse` in bootstrap.sh (blobless, with a sparse checkout of the root LICENSE and the listed folders) rather than `fetch_commit`
- Why: `fetch_commit` checks out the whole tree on every install
- Scope: project
- Status: candidate
- Seen: 1, last 2026-11-24
- Evidence:
  - 2026-11-24: Hermes Agent is about 435 MB checked out; the sparse fetch of three folders took about 1.5 s and 4 MB (PR #28)

### reuse-the-throwaway-home-for-manual-installs-as-root
- When: running bootstrap.sh by hand as root with a new throwaway HOME, after an earlier install on the same machine
- Do: reuse the earlier throwaway HOME (or give `UV_TOOL_BIN_DIR` a fresh folder) for the manual run
- Not: reading the "Executables already exist: graphify" stop as a bug in the change under test
- Why: as root, bootstrap.sh installs graphify into /usr/local/bin while uv keeps its tool list under HOME, so a new HOME does not know the executables are uv's
- Scope: project
- Status: candidate
- Seen: 1, last 2026-11-24
- Evidence:
  - 2026-11-24: a manual `--pack product` run with a new HOME stopped at `uv tool install`; the same run in the earlier HOME passed
