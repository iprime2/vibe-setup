---
description: Two-stage review before merge - stage 1 runs senior-engineer and every module owner the diff touches, stage 2 runs lead-engineer on every PR, then lists the merge gate (CI green, both stages approved, the user approves). --tier runs a single agent as a quick check, not a merge review. Separate from /review, the single-pass five-axis review.
argument-hint: "[base-ref] [--tier mid|senior|lead]"
---

Review the current change the way this project merges it: two stages of read-only reviewers, then the
user approves. You orchestrate; the reviewers are agents that are read-only and cannot run git, so you
collect the change and hand it to them.

## 1. Collect the change

- Base: the `base-ref` argument if given. Otherwise the merge base with the default branch
  (`git merge-base HEAD origin/HEAD`, falling back to `main`, then `master`). If HEAD has no commits beyond
  that base, review the working tree (staged and unstaged) instead.
- Run `git diff --stat <base>...HEAD` and `git diff <base>...HEAD` (for the working tree:
  `git diff --stat HEAD` and `git diff HEAD`). Read any untracked files that `git status --porcelain` lists.
- Collect the stated intent: the PR description if you have it, and `git log --format=%B <base>..HEAD`.
- If there is no change, say so and stop.

## 2. Stage 1: senior engineer and module owners

Always run **senior-engineer**. Also run every module owner whose area the diff touches, by path or by
content; quote the paths or diff lines that matched. The paths are the planned layout; update this table
when the code exists.

| Owner agent | Paths | Or the diff touches |
|---|---|---|
| matching-engine-owner | `engine/matching/` | order book, order types, matching, self-trade prevention, sequencing, market states |
| risk-liquidation-owner | `engine/risk/`, `engine/liquidation/` | margin, leverage, positions, pre-trade checks, liquidation, insurance fund, auto-deleveraging |
| ledger-owner | `services/ledger/` | journals, postings, balances, holds, fees, rebates, funding payments, settlement, ledger migrations |
| custody-blockchain-owner | `services/custody/`, `services/chains/`, `contracts/` | wallets, addresses, crypto deposits and withdrawals, signing, nonces, confirmations, token listings |
| quant-owner | `engine/pricing/`, `mm-gateway/` | index or mark price, funding rate, risk parameters, fee and market-maker tiers, the FIX gateway |
| npr-payments-owner | `services/payments/` | NPR deposits and payouts, bank or payment-network adapters, fiat reconciliation |
| compliance-owner | `services/compliance/` | KYC, KYB, screening, sanctions, transaction monitoring, travel rule, personal data, audit logs |

Run the stage 1 agents in parallel. Give each one the diff (for a diff too large to pass, the `--stat`
output, the list of changed files and the base ref, so it can read them), the stated intent, and why it
was picked.

## 3. Stage 2: lead engineer

Always run **lead-engineer** last, with the diff, the stated intent and every stage 1 report. It reviews
the change against the whole codebase and rules on what stage 1 escalated.

## 4. Follow escalations

If a report names an owner that did not run, run that owner on the named areas and pass the escalation
lines, before stage 2 when you can. Run each agent at most once.

## 5. Report and merge gate

Return each report as written, under a heading that names the agent, then one combined verdict: the
strictest verdict of any agent that ran. End with the merge gate:

- [ ] CI is green on the PR head: unit, integration, build and security jobs
- [ ] Stage 1 approved: senior-engineer and every owner that ran
- [ ] Stage 2 approved: lead-engineer
- [ ] The user approved the PR. Squash-merge only after that, or when the user explicitly tells you to merge.

Do not change code here; fixes are a separate step the user asks for.

## `--tier`

`--tier mid` runs only mid-level-engineer, as a quick check before a PR is opened. `--tier senior` or
`--tier lead` runs only that agent. None of these is a merge review; say which one ran and that the merge
gate still needs the full two stages.
