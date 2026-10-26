---
description: Capture lessons from this session (corrections, solved errors, failed approaches, unwritten conventions) into .agent-memory/LESSONS.md, only after you approve the diff. Uses the agent-memory skill.
argument-hint: "[what to focus on]"
---

Run the Capture procedure of the agent-memory skill on this session. If an argument is given, look only at
that part of the session.

- Show each candidate with its verdict (new, merge, amend or retire, drop) and its evidence, then the unified
  diff of `.agent-memory/LESSONS.md`. Write only the hunks the user approves.
- Never write secrets, credentials, personal data or anything the user called confidential; run the skill's
  checker before showing the diff and again after writing.
- Do not commit. If nothing is worth keeping, say so in one line and stop.
