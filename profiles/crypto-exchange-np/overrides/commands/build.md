---
description: Implement tasks incrementally — build, test, verify, commit. Add "auto" to run the whole plan in one approved pass.
---

Invoke the incremental-implementation skill alongside test-driven-development.

## Modes

- **`/build`** — implement the *next* pending task, then stop (careful, one slice at a time).
- **`/build auto`** — generate the plan if needed, get a single approval, then implement *every* task without stopping between them.

`$ARGUMENTS` selects the mode. Treat `auto` (canonical) or `all` as autonomous mode; anything else (or empty) is the default single-task mode. Note: autonomous mode is not faster *per task* — it runs the same test-driven loop — it only removes the human stepping *between* tasks.

## Default: one task

Pick the next pending task from the plan. Then:

1. Read the task's acceptance criteria
2. Load relevant context (existing code, patterns, types)
3. Write a failing test for the expected behavior (RED)
4. Implement the minimum code to pass the test (GREEN)
5. Run the full test suite to check for regressions
6. Run the build to verify compilation
7. Commit on the task branch with a Conventional Commits message. The task branch is `feat/<ticket>-<short-name>`, created from `origin/main` (`git fetch origin && git checkout -B feat/<ticket>-<short-name> origin/main`). In a Claude cloud session that can only push its assigned branch, reset that branch to `origin/main` first and use it. Never commit to `main`, and never put a second task on a branch whose PR is still open.
8. In the task's last commit, tick the boxes in `tasks/todo.md` that this PR meets (a box that needs the review or the owner's acceptance is ticked in a later PR). Push the branch and open a PR titled `<ticket>: <task title>` whose body lists the acceptance criteria and the tests added. Run `/tiered-review` (it posts its verdicts on the PR) and stop for the user. A commit pushed after the review needs a new review. The user approves and merges; the next task starts from the updated `origin/main`.

## Autonomous: the whole plan (`/build auto`)

Use this once a spec exists and you want to collapse plan + build into one run. It removes the manual stepping between tasks — **not** the verification. Every task still earns a passing test and its own commit.

1. **Require a spec.** Look only for a spec at a known path: `SPEC.md` at the repo root, `docs/SPEC.md`, or a file under `spec/`. A README or arbitrary doc does **not** count. If none exists, stop and tell the user to run `/spec` first — do not invent requirements.
2. **Establish a clean baseline.** Run `git status --porcelain`. If there are uncommitted changes outside the expected planning artifacts (`SPEC.md`, `docs/SPEC.md`, `spec/*`, `tasks/plan.md`, `tasks/todo.md`), stop and ask the user to commit, stash, or confirm how to handle them. Autonomous per-task commits must not absorb unrelated local work, or the clean-rollback guarantee breaks.
3. **Plan if needed.** If there is no `tasks/plan.md`, invoke planning-and-task-breakdown to generate one.
4. **Single checkpoint.** Present the full plan and wait for an unambiguous affirmative (e.g. "approve", "go", "yes"). Treat hedged responses ("looks reasonable", "I guess") as **not** approved. This is the only human gate — after approval, run autonomously. If you generated `tasks/plan.md`, commit it as a single preparatory commit now so it doesn't bleed into the first task's commit.
5. **In this project, auto mode stops at the PR boundary.** It implements the tasks of one PR only (normally one task), opens that PR, runs `/tiered-review` and stops until the PR is merged. It never continues to the next task on the same branch. Then, for those tasks:
   **Execute in dependency order.** Use each task's declared dependencies; if they aren't explicit, execute in the order the plan lists them. For each task, run the full default loop above (RED → GREEN → regression → build → commit → mark complete). Stage only the files that task touched plus its task-status update — never `git add -A` blindly — and make one commit per task so any point is a clean rollback.
6. **Stop and ask the user** (do not push through) when:
   - a test can't be made to pass or the build breaks without an obvious fix → follow debugging-and-error-recovery
   - the spec is ambiguous, or a task needs a decision the spec doesn't cover
   - a task is high-risk or irreversible — auth/permission changes, destructive data migrations, payments, deletions, deploys, anything touching secrets, **or anything you can't undo with `git revert`** → follow doubt-driven-development and get explicit sign-off before continuing. In this project that always includes the ledger, matching, margin and liquidation, custody and signing, crypto and NPR withdrawals, KYC/AML rules, CI workflows and required checks, the `main` branch protection, `deny.toml` and the secret-scanning config

   After the user resolves a blocker, they re-invoke `/build auto` — it resumes from the next pending task.
7. **Summarize at the end:** tasks completed, tests added, commits made, and anything skipped, flagged, or left for the user.

If any step fails, follow the debugging-and-error-recovery skill.
