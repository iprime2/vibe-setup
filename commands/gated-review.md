---
description: Two-stage merge review - stage 1 runs senior-engineer and every module owner the diff touches (routed by path from a table the project fills in), stage 2 runs lead-engineer, then QA, then the owner's word. The merge gate for a PR. /tiered-review stays the single-tier quick review; /review is the single-pass five-axis review.
argument-hint: "[base-ref]"
---

Review the current change the way it merges: two stages of read-only reviewers, then QA, then the owner's word.
You orchestrate. The reviewers and QA are read-only agents that cannot run git or commands, so you collect the
change, run what they need, and hand it to them. Every PR goes through this gate, docs, specs, design decisions
and plans included.

This command needs the `senior-engineer` and `lead-engineer` agents (the `roles` pack) and the project's module
owner agents named in section 3. If one that the change calls for is not installed, stop and name it. The
project's `AGENTS.md` wins over this file. `/tiered-review` is unchanged: it picks one tier for a quick check and
is not a merge review.

## 1. Collect the change

- Base, in this order: the `base-ref` argument; else the PR's base commit if a PR exists
  (`gh api repos/{owner}/{repo}/pulls/<n> --jq .base.sha`); else `git fetch origin`, then
  `git merge-base HEAD origin/main`; else `origin/master`. Never use a local `main` without fetching first.
- Print the base and `git diff --stat <base>...HEAD`. If more than 30 files changed, ask the owner to confirm the
  base before starting any agent. If HEAD has no commits beyond the base, review the working tree
  (`git diff --stat HEAD`, `git diff HEAD`, and every untracked file `git status --porcelain` lists).
- Note the head SHA. Every verdict, QA result and CI result in the record names this one SHA.
- Collect the stated intent: the PR body, the ticket and its acceptance criteria, and
  `git log --format=%B <base>..HEAD`. If there is no stated intent, that is a blocking question.
- If `graphify-out/graph.json` exists, run `graphify query "<one-line summary of the change>"` and add its output
  to every brief.
- If there is no change, say so and stop.

## 2. Pick the gate

- **Full gate:** the change touches a path or topic in the project's full-gate list (section 9): typically the
  spec, design decisions, the plan, rule files, CI and security gates, and money code. Stage 1 runs
  senior-engineer and every owner that section 3's table matches by path or by topic.
- **Standard gate:** any other change. Stage 1 runs senior-engineer, the owners the ticket names, and any owner
  the table matches by path.

Stage 2 runs in both. Say which gate ran, and quote the paths or diff lines that decided it.

## 3. Stage 1: senior engineer and module owners

Always run **senior-engineer**. Add the owners the gate calls for, from this table. The project fills it in
(section 9); until it does, stage 1 is senior-engineer alone, and the report says so.

| Module | Paths | Owner agents | Or the diff touches |
|---|---|---|---|
| `<module>` | `<path/>`, `<path/>` | `<module>-owner` | `<topics that route here from any path>` |
| example: auth | `src/auth/` | `auth-owner` | sessions, tokens, permissions |

Specs, design decisions and plans go to the owners whose topics they name, using the same table.

Run the stage 1 agents in parallel. Give each one the diff (for a diff too large to pass, the `--stat`, the list
of changed files and the base, so it can read them), the stated intent, why it was picked, and any graphify
output. Give reviewers the code, not your conclusion. For a spec, design decision or plan, add: "Judge this as a
document against the spec, not as code. Check contradictions with the decisions already made, gaps that would
block your module's next work, and scope pulled in from a later milestone. Cite file:line, and rate each item
'decide now', 'decide later' or 'note'."

For code, senior-engineer also checks the PR body's tests, red then green: every new behaviour has a test, the red
is plausible for that test, and no test was weakened, skipped or deleted.

**Tiers.** Every reviewer and QA runs at the default tier, never below. The top tier runs only for a named reason:
invariants that cross modules in money or core data paths, a security boundary with real attack paths, or a
finding two default-tier rounds did not settle. The record gives each agent's tier, and the reason for top.

## 4. Stage 2: lead engineer

Run **lead-engineer** last, with the diff, the stated intent, the brief above when it applies, and every stage 1
report. It reviews the change against the whole codebase and rules where stage 1 reviewers disagree.

- **One lead at a time.** Lead reviews run one after another, never two at once, across all PRs and readiness
  reviews. Two in parallel spend usage faster and can rule differently on the same question.
- **The same lead rechecks.** Every recheck of a PR goes to the lead agent that already reviewed it, as a message
  to that agent, so it keeps its context. A new lead starts only if that context is gone, and then it gets the
  earlier report.
- **Docs-only PRs** run the lead at `medium` effort. Docs-only means the PR changes only README files and pages
  under `docs/`, not design decisions. Specs, design decisions, plans, rule files, scripts and CI keep the lead's
  default effort.

## 5. Follow escalations

If a report names an owner that did not run, run that owner on the named areas with the escalation lines, before
stage 2 when you can. Run each agent at most once per round.

## 6. QA

After both stages approve, a QA agent checks every acceptance criterion against the PR head. QA is read-only
(`tools: Read, Grep, Glob`) and never the agent that built or reviewed the change. You run any command a criterion
needs on that head and give QA the command, its output and the SHA; QA rules on each criterion: pass, fail, or
needs the owner.

- A criterion only a person can check (a device, an account, a judgment call) is labelled `qa:manual` (the name
  is the project's choice), and the owner QAs it. Only the owner's word, quoted in the QA record, clears it.
- A QA failure goes back to the builder that wrote the change, then through the review and QA again.

## 7. Report

- Save each agent's raw report to a file outside the repository and give the paths; do not paste raw reports
  into the reply.
- Return one de-duplicated list. For code, group it by severity. For specs, design decisions and plans, group it
  as "decide now", "decide later" and "note", with the decisions only the owner can make (scope, cost, product)
  first.
- Give the combined verdict: for code, the strictest verdict of any agent that ran; for a document, it depends
  only on "decide now" items.

## 8. Record and merge gate

- **Reviews on the PR.** Post each reviewer's verdict as a GitHub review with event `COMMENT` and `commit_id` set
  to the head SHA (the `github-api` skill has the recipe). Use `COMMENT` whatever the verdict: agents often post
  from the author's account, and GitHub does not let an author approve their own PR. The body starts with the
  signature line, for example `**Agent:** senior-engineer (default tier) · posted by the project manager`, then
  the head SHA and the verdict. Each finding is an inline comment on its line, with its severity and the fix; a
  finding outside the diff goes in the body.
- **Threads.** Every review thread gets a reply and is resolved before merge: fixed (name the commit), ruled out
  (quote the lead's or the owner's ruling), or carried to a named follow-up that is not another open PR.
- **Gate record.** One signed PR comment with one line per agent (agent, tier, verdict, blocking items), the QA
  result and CI, all at the same head SHA.
- **The owner's word.** Before a merge, a second comment quotes the owner's approval word for word, with its
  time. A standing word ("merge these once green") covers only the PRs open when it was said, and "green" means
  this whole gate, not only CI.
- **A new push** resets the gate: CI and QA run again on the new head, and the change is reviewed again. When the
  interdiff leaves the reviewed change as it was (a merge of `main` with no conflicts), that review is the same
  lead's delta check of the interdiff; otherwise the changed hunks go through stage 1 and stage 2 again.

End the report with the merge gate:

- [ ] CI is green on the head SHA: every check the project requires (section 9). No CI configured: say so.
- [ ] Stage 1 approved: senior-engineer and every owner that ran
- [ ] Stage 2 approved: lead-engineer
- [ ] QA passed on the head SHA, and every `qa:manual` item has been QA'd by the owner, quoted on the PR
- [ ] Every review thread has a reply and is resolved
- [ ] The verdicts, the QA result and the gate record are posted on the PR, each signed
- [ ] The owner gave the word to merge, quoted with its time. The merge is a squash pinned to the head SHA.

Do not change code here; fixes go back to the builder that wrote the change.

## 9. Fill in for your project

Keep these in the project's copy of this file, or point to where `AGENTS.md` holds them:

- **Full-gate paths and topics:** the spec, design decisions, the plan, rule files, CI and security config, and
  every money or core-data path.
- **The module table** in section 3: one row per risky module, each with a read-only owner agent.
- **Required CI checks:** the job names that must pass on the head.
- **The merge rule:** who presses merge, and on whose word.
