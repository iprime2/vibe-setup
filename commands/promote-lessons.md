---
description: Build confirmed lessons from .agent-memory/LESSONS.md into the installed skills, commands or agents (or a project rule), one approved diff at a time. Uses the agent-memory skill.
argument-hint: "[lesson id ...]"
---

Run the Promote procedure of the agent-memory skill. With lesson ids as arguments, take only those; otherwise
take every confirmed lesson that is not promoted or retired.

- Propose the smallest edit per target as a unified diff and wait for approval before applying it.
- Keep the skill's limits: never weaken security, testing, review or verification steps, never rename a skill
  or change its frontmatter, never widen an agent's tools, never edit graphify's skill, never remove a
  third-party `LICENSE` or attribution, and edit nothing outside `.claude/skills`, `.claude/commands`,
  `.claude/agents`, CLAUDE.md and AGENTS.md.
- After applying, mark each lesson `promoted: <path>`, run the skill's checker, and show the record against
  the pristine snapshot if there is one. Do not commit.
