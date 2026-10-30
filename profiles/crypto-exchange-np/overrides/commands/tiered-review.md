---
description: Two-stage review before merge - stage 1 runs senior-engineer and every module owner the diff touches, stage 2 runs lead-engineer on every PR, then lists the merge gate (CI green, both stages approved, the user approves). --tier runs a single agent as a quick check, not a merge review. Separate from /review, the single-pass five-axis review.
argument-hint: "[base-ref] [--tier mid|senior|lead]"
---

Review the current change the way this project merges it: two stages of read-only reviewers, then the
user approves. You orchestrate; the reviewers are agents that are read-only and cannot run git, so you
collect the change and hand it to them. Every PR goes through this gate, docs, specs, ADRs and plans
included.

## 1. Collect the change

- Base, in this order: the `base-ref` argument if given; else the PR's base commit if a PR exists
  (`gh pr view --json baseRefOid -q .baseRefOid`); else `git fetch origin` then
  `git merge-base HEAD origin/main`; else `origin/master`, then local `main` or `master`. Never use a local
  `main` without fetching first: it can be stale.
- Print the base you chose and `git diff --stat <base>...HEAD`. If more than 30 files changed, stop and ask
  the user to confirm the base before running any agent. If HEAD has no commits beyond the base, review
  the working tree instead (`git diff --stat HEAD`, `git diff HEAD`, and every untracked file that
  `git status --porcelain` lists).
- Collect the stated intent: the PR description if there is one, and `git log --format=%B <base>..HEAD`.
- If `graphify-out/graph.json` exists, run `graphify query "<one-line summary of the change>"` and add its
  output to every agent's brief. The agents cannot run graphify themselves.
- If there is no change, say so and stop.

## 2. Pick the tier

The user approved these tiers on 2026-10-30. Say which tier ran in the report and in the PR record.

- **Full gate**: the PR changes `SPEC.md`, any `SPEC-*.md`, `docs/adr/`, `docs/threat-model.md` or `tasks/`, or
  touches money code:
  `services/ledger/`, `engine/matching/`, `services/trading/`, `services/custody/`, `contracts/`,
  `services/npr-payments/`, `services/withdrawals/` or `services/reconciliation/`. Stage 1 runs
  senior-engineer and every owner the table below matches by path or by content.
- **Module tier**: any other PR. Stage 1 runs senior-engineer and the owners the task names under "Owner
  module" in `tasks/todo.md` (none for "Owner module: none"), plus any owner the table matches by path.

Stage 2 (lead-engineer) runs in both tiers.

## 3. Stage 1: senior engineer and module owners

Always run **senior-engineer**. Run the owners the tier calls for; quote the paths or diff lines that
matched. The capability map in `SPEC.md` is the source of truth: when this table and `SPEC.md` disagree,
run the owners `SPEC.md` names, and fix this table in the same PR.

| Module (`SPEC.md`) | Paths | Owner agents | Or the diff touches |
|---|---|---|---|
| platform | `crates/`, `services/skeleton/`, `infra/`, `.github/`, `Makefile` | none (senior only) | CI gates, pinning, the local stack |
| audit-log | `services/audit-log/` | compliance-owner | audit records, hash chain, retention |
| reference-data | `services/reference-data/` | quant-owner | assets, markets, steps, bands, fees, limits, thresholds |
| identity | `services/identity/` | compliance-owner (lead-engineer applies its API and identity checklist at stage 2) | sign-up, login, 2FA, sessions, API keys, the 24-hour lock |
| ledger | `services/ledger/` | ledger-owner | journals, postings, balances, holds, fees, chart of accounts, ledger migrations |
| compliance | `services/compliance/` | compliance-owner | KYC levels, screening, limits per level, tax hook, personal data |
| matching | `engine/matching/` | matching-engine-owner | order book, order types, self-trade prevention, sequencing, halts, replay |
| trading | `services/trading/` | matching-engine-owner, ledger-owner, risk-liquidation-owner | order intake, pre-trade checks, holds, trade and fee booking |
| market-data | `services/market-data/` | matching-engine-owner | book snapshots and deltas, trades, tickers, candles, sequence numbers |
| custody | `services/custody/`, `contracts/` | custody-blockchain-owner | wallets, addresses, deposits, signing, nonces, confirmations, sweeps |
| npr-payments | `services/npr-payments/` | npr-payments-owner | NPR deposits and payouts, the bank simulator, statement import |
| withdrawals | `services/withdrawals/` | custody-blockchain-owner, npr-payments-owner, compliance-owner, ledger-owner | approval tiers, 2FA, limits, screening, the pause switch |
| reconciliation | `services/reconciliation/` | ledger-owner, custody-blockchain-owner, npr-payments-owner | daily reconciliation, mismatches, the automatic pause |
| api-gateway | `services/api-gateway/` | none (lead-engineer applies its API checklist at stage 2) | public REST and WebSocket API, admin API, auth, rate limits |
| liquidity-bot | `services/liquidity-bot/` | quant-owner | reference rate, quoting, inventory and loss caps |
| web-app | `web/apps/web/` | none (lead-engineer applies its scope checklist at stage 2) | retail screens, i18n, Bikram Sambat dates |
| admin | `web/apps/admin/` | compliance-owner, ledger-owner | KYC review, withdrawal approvals, halts, fee and limit settings |
| threat model | `docs/threat-model.md` | security-auditor, custody-blockchain-owner | trust boundaries, attackers, controls, residual risk |
| Milestone 2 | `engine/risk/`, `engine/liquidation/`, `engine/pricing/`, `mm-gateway/` | risk-liquidation-owner, quant-owner | margin, liquidation, index and mark price, funding, the FIX gateway |

Specs, ADRs and plans are reviewed by the owners whose topics they name, using the same table.

Run the stage 1 agents in parallel. Give each one: the diff (for a diff too large to pass, the `--stat`
output, the list of changed files and the base ref, so it can read them), the stated intent, why it was
picked, the graphify output if any, and, for a spec, ADR or plan, this brief:

> This is a Milestone 1 document (spot only, test funds, synthetic identities), to be judged against
> `SPEC.md` and `SPEC-platform.md`, not as code. Check (1) contradictions with the decisions table in
> `SPEC.md`, (2) gaps that would block your module's own spec or its first sprint task, (3) anything that
> pulls Milestone 2 scope into Milestone 1. Cite file:line. Rate each item "decide now", "decide before
> SPEC-<module>.md" or "later", as your agent file's "Specs, ADRs and plans" section says.

## 4. Stage 2: lead engineer

Always run **lead-engineer** last, with the diff, the stated intent, the brief above when it applies and
every stage 1 report. It reviews the change against the whole codebase and rules on what stage 1
escalated.

## 5. Follow escalations

If a report names an owner that did not run, run that owner on the named areas and pass the escalation
lines, before stage 2 when you can. Run each agent at most once.

## 6. Report

- Save each agent's raw report to a file outside the repository (the session's scratchpad, or `/tmp`),
  named `<agent>.md`, and give the paths. Do not paste the raw reports into the reply.
- Return one de-duplicated list. For code, group it by severity. For specs, ADRs and plans, group it as
  "decide now", "decide before SPEC-<module>.md" and "later", and put first the decisions only the user can
  make (scope, cost, product).
- Give the combined verdict. For code it is the strictest verdict of any agent that ran. For a spec, ADR or
  plan it depends only on "decide now" items: none left means APPROVE WITH FOLLOW-UPS.

## 7. Record and merge gate

- Post one comment on the PR (`gh api repos/{owner}/{repo}/issues/{n}/comments`) with one line per agent:
  agent, tier, verdict, blocking items. Add the session link.
- Before a merge, post a second comment quoting the user's approval message word for word, with its time.
  The user merges in GitHub, or the agent merges only when the user says so in that session.

End the report with the merge gate:

- [ ] CI is green on the PR head: `rust-lint`, `rust-test`, `integration`, `ts`, `build` and `security`
  (once they exist; until then, say there is no CI)
- [ ] Stage 1 approved: senior-engineer and every owner that ran
- [ ] Stage 2 approved: lead-engineer
- [ ] The verdicts and the user's approval are posted on the PR
- [ ] The user approved the PR. Squash-merge only after that, or when the user explicitly tells you to merge.

Do not change code here; fixes are a separate step the user asks for.

## `--tier`

`--tier mid` runs only mid-level-engineer, as a quick check before a PR is opened. `--tier senior` or
`--tier lead` runs only that agent. None of these is a merge review; say which one ran and that the merge
gate still needs the full two stages.
