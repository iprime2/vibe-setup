# Ticket, epic and bug templates

These go with the [working flow](workflow.md). Keep the headings in this order. A heading with nothing to say
keeps one line: "None." To use them as GitHub issue forms, copy each one into `.github/ISSUE_TEMPLATE/` as a
YAML form, with a `textarea` per heading and `checkboxes` for the approvals.

## Ticket (tasks, follow-ups, owner actions)

```
## Description
What and why, in 2-3 sentences. Optional user story: As a …, I want …, so that ….

## Acceptance criteria
- [ ] One testable statement per box.
_Source of truth: `tasks/todo.md`, <ID>. This list mirrors it._   <- only when a task-list row exists

## Technical details
- **Approach:** …
- **Touches:** modules and paths
- **Follows:** specs and architecture decisions (file:line)
- **Tests first (TDD):** the failing tests planned
- **Risks:** …
- **Ask-first areas:** … or "none"
- **Builder:** <level>, <tier> tier, effort <effort> (set by lead-engineer: <link to the verdict>)

## Dependencies
- Depends on: #…
- Blocks: #…

## Reviewers and gate
- Reviewers: …
- Gate: full or standard, and why

## Additional notes
Open questions, the owner's decisions quoted word for word, links, history.

## Approvals (Definition of Ready)
- [ ] lead-engineer approved: <link to the comment>
- [ ] Module owner(s) approved: <who, link>, or "none needed" for a ticket with no module owner
```

## Epic

```
## Description
The goal and why, and its step in the spec's build order if it has one.

## Scope
- In: …
- Out: …

## Success criteria
- [ ] …

## Technical overview
Modules, specs, architecture decisions and the main risks.

## Tickets
Its sub-issues are its tickets. Done so far: … (PR numbers)

## Target sprints
Starts in Iteration N (dates); expected to span …

## Dependencies
- Depends on: #…
- Blocks: #…

## Additional notes
…

## Approvals (Definition of Ready)
- [ ] lead-engineer approved: <link to the comment>
- [ ] Module owner(s) approved: <who, link>, or "none needed"
```

## Bug

Labels: `type:bug` and one of `severity:S1` to `severity:S4`. Board priority: S1 → P0, S2 → P1, S3 and S4 → P2.
An S1 bug starts at once: the PM moves it to In progress and alerts the owner, lead-engineer triages it while the
fix starts, and both approvals are recorded afterwards. The fix still passes the full review and QA before it
merges. S2 to S4 wait for both approvals like any ticket.

```
## Description
What is wrong, in 1-2 sentences.

## Severity
S1 critical: money or data at risk, a security hole, or the product down
S2 high: a main flow broken, no workaround
S3 medium: broken, with a workaround
S4 low: cosmetic or docs

## Environment
local / dev / staging / prod · commit or release tag · service

## Steps to reproduce
1. …

## Expected result

## Actual result

## Impact
Money or data affected? Users affected? Audit trail? Security?

## Evidence
Logs, trace ids, screenshots. No secrets, tokens or personal data.

## Technical details
- Suspected area: modules and paths
- Regression? The last good commit or release
- Root cause and fix approach: filled at triage
- Test first: the failing test that reproduces it
- Builder: <level>, <tier> tier, effort <effort> (set by lead-engineer at triage: <link>)

## Workaround

## Dependencies

## Reviewers and gate

## Additional notes

## Approvals (Definition of Ready)
- [ ] lead-engineer approved (triage): <link to the comment>
- [ ] Module owner(s) approved: <who, link>, or "none needed"
```
