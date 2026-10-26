---
description: Tiered code review - picks the mid-level, senior or lead reviewer from what the diff touches, runs that read-only agent, and follows its escalations. Separate from /review, the single-pass five-axis review.
argument-hint: "[base-ref] [--tier mid|senior|lead]"
---

Review the current change with the reviewer tier it needs. You orchestrate; the reviewers are the
mid-level-engineer, senior-engineer and lead-engineer agents. They are read-only and cannot run git, so you
collect the change and hand it to them.

## 1. Collect the change

- Base: the `base-ref` argument if given. Otherwise the merge base with the default branch
  (`git merge-base HEAD origin/HEAD`, falling back to `main`, then `master`). If HEAD has no commits beyond
  that base, review the working tree (staged and unstaged) instead.
- Run `git diff --stat <base>...HEAD` and `git diff <base>...HEAD` (for the working tree:
  `git diff --stat HEAD` and `git diff HEAD`). Read any untracked files that `git status --porcelain` lists.
- Collect the stated intent: the PR description if you have it, and `git log --format=%B <base>..HEAD`.
- If there is no change, say so and stop.

## 2. Pick the tier

The highest tier that matches wins. Quote the paths or diff lines that decided it.

- **lead**: a new service, package or deployable (new Dockerfile, service directory, entry point or deploy
  job); schema changes (migrations, DDL, ORM model fields, indexes); public API changes (OpenAPI, `.proto`,
  GraphQL schema, route signatures, response shapes); event or message contract changes (topic or queue
  names, payload schemas); changes to clients or contracts shared between services; infrastructure or
  permission changes.
- **senior**: non-trivial logic; concurrency (threads, async, locks, atomics, channels, queues, transaction
  isolation); money and quantities (amount, balance, price, fee, rate, decimal, rounding, ledger, wallet,
  deposit, withdrawal); security (auth, sessions, permissions, crypto, signing, secrets, input validation,
  deserialisation, SQL or shell built from input).
- **mid-level** (default): everything else - tests, docs, renames, small refactors, configuration tweaks,
  dependency bumps without code changes.

`--tier` overrides the pick; say that it was overridden. Announce the tier, the reason and the files that
triggered it before running the reviewer.

## 3. Run the reviewer

Start the chosen agent with: the diff (for a diff too large to pass, the `--stat` output, the list of changed
files and the base ref, so it can read them), the stated intent, and the reason for the tier.

## 4. Follow escalations

If the mid-level report lists Escalations, run the named tier on just those areas and pass the escalation
lines. If the senior report has items under "Escalate to lead", run the lead tier on them. Run each tier at
most once.

## 5. Report

Return each reviewer's report as written, under a heading that names the tier, then one combined verdict:
the strictest verdict of any tier that ran. Do not change code here; fixes are a separate step the user asks
for.
