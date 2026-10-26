---
description: Write a handoff so another session, coding agent or person can continue this work - verified state, what did not work, decisions, open questions, the user's rules and one next step - and print a paste-ready block. Uses the agent-memory skill.
argument-hint: "[for whom] [title]"
---

Run the Write procedure of the agent-memory skill. The arguments, if any, name the recipient and the title.

- Take facts from the repo (`git status --short`, branch, `git rev-parse --short HEAD`, recent log) and from
  checks actually run in this session. Anything without evidence goes under "Done but not verified".
- Copy the user's standing rules into "Rules in force" in their words. Keep the closing sentence that says
  the handoff grants no permission.
- Run the skill's checker on the draft, show the full handoff and wait for approval. Then save it under
  `.agent-memory/handoffs/` (unless the user wants only the text) and print the paste-ready block.
- Do not commit unless the user asks.
