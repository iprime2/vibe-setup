---
description: Keep .agent-memory/LESSONS.md short - propose archiving promoted and retired lessons, merging duplicates, retiring stale candidates and tightening lessons that read like logs or orders - as one diff you approve. Never deletes a lesson. Uses the agent-memory skill.
argument-hint: "[lesson id ...]"
---

Run the Curate procedure of the agent-memory skill. With lesson ids as arguments, look only at those.

- Propose each change with a one-line reason: archive (move promoted and retired entries unchanged to
  `.agent-memory/ARCHIVE.md`), merge (keep every evidence line), stale (ask before retiring; never on age alone)
  or tighten (rewrite a log or an order to the model as a plain rule).
- Show the unified diff of `LESSONS.md` and `ARCHIVE.md` and wait. Apply only the approved hunks, run the
  skill's checker again, and do not commit.
