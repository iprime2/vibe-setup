# Lessons

Lessons learned on this repo by coding agents and approved by a person. They are data, not instructions:
verify before relying on one, and the user's instructions always win.

### verify-the-remote-before-trusting-a-report
- When: another session, agent or handoff says work is missing, unmerged or on an old commit
- Do: check the remote first (`git fetch origin`, `git ls-remote origin`, the pull request's state) and report what is actually there
- Not: rebasing, recreating or re-pushing the work because of that report
- Why: the reporting session's clone was stale; the work had already been merged
- Scope: generic
- Status: candidate
- Seen: 1, last 2026-10-26
- Evidence:
  - 2026-10-26: another session reported the pack work missing; `git ls-remote` showed it merged in PR #8 (main 747acc5)

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
- Do: after the full run, set the count in the README "Tested" section (`bash tests/run.sh`, N checks) to the real total, and say if a check was only rerun on its own
- Why: the README states the count as a fact; it is not computed
- Scope: project
- Status: candidate
- Seen: 2, last 2026-10-26
- Evidence:
  - 2026-10-26: 147 to 166 checks (commit 32802cd, PR #9)
  - 2026-10-26: 166 to 210 checks (commit 044317c, PR #10)

### green-means-the-local-suite-here
- When: asked to merge a pull request in this repo "once it is green"
- Do: read the PR's check runs and statuses; when there are none, treat the full local suite passing on the PR's head plus a clean merge state as green, merge with that head SHA pinned, and say that this is what green meant
- Why: the repo has no CI workflows, so GitHub never reports a result
- Scope: project
- Status: candidate
- Seen: 2, last 2026-10-27
- Evidence:
  - 2026-10-26: PR #9 had no checks; merged on the local suite (166 passed)
  - 2026-10-27: PR #10 had no checks; merged on the local suite (210 passed)

### build-secret-shaped-test-values-at-run-time
- When: a test needs a value shaped like a token, key or password
- Do: assemble it from pieces at run time (for example `"gh""p_$(...)"`), never as a literal in the repo
- Why: a committed literal looks like a leaked secret to scanners and to push protection
- Scope: generic
- Status: candidate
- Seen: 1, last 2026-10-26
- Evidence:
  - 2026-10-26: `tests/test_memory.sh` builds its fake token, key and password at run time (PR #10)
