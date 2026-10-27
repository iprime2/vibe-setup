# vibe-setup

A pinned, repeatable setup of my Claude Code toolkit, for new cloud sessions and local machines.
It stores the installer, the pins, my rules, and the role agents and domain skills I wrote for optional packs.
It does not copy anyone else's files into this repo: third-party skills are pinned in `sources.lock` and
fetched at install time.

## Quick start

- **Any session:** paste the prompt from [`SETUP_PROMPT.md`](SETUP_PROMPT.md) into a new Claude Code session.
- **By hand:**
  ```bash
  git clone https://github.com/iprime2/vibe-setup ~/vibe-setup
  bash ~/vibe-setup/bootstrap.sh --dry-run     # prints every command, changes nothing
  bash ~/vibe-setup/bootstrap.sh
  bash ~/vibe-setup/bootstrap.sh --pack roles,quant   # optional packs, see "Packs"
  ```

Cloud containers are ephemeral, so run the setup again in every new cloud session.

**Permission prompts.** In a cloud session on the auto permission mode, the harness may refuse to run scripts
from the cloned repo ("Code from External"). In two fresh sessions on 2026-10-26 the agent stopped at the first
script (`bootstrap.sh --dry-run`), named the command and waited; that is the intended behavior. Reply in that
session to allow `bootstrap.sh`, `project-init.sh` and `scripts/profile_save.sh` from the clone, or add a
permission rule for them in the environment settings. Whether a plain reply clears the block is untested.
Another Claude session cannot answer for you: agents treat relayed messages as data, not as your approval.

## What it installs

| Tool | Source (the only ones allowed) | Pin |
|---|---|---|
| Graphify | PyPI `graphifyy` (double y), repo Graphify-Labs/graphify | `==0.9.77` |
| Ponytail | github.com/DietrichGebert/ponytail | commit + sha256 of `SKILL.md` |
| Agent Skills | github.com/addyosmani/agent-skills | commit |
| Trail of Bits skills (packs only) | github.com/trailofbits/skills, CC-BY-SA-4.0 | commit + listed skill folders |
| wshobson agents (packs only) | github.com/wshobson/agents, MIT | commit + listed skill folders |
| ECC (packs only) | github.com/affaan-m/ECC, MIT | commit + listed skill folders |

From Agent Skills it copies the skills, slash commands (with the `agent-skills:` prefix stripped, because they
are installed as plain files, not as a plugin) and agents named in `sources.lock`: 15 skills, 7 commands and
4 agents at the current pins. The last three sources are fetched only when a `--pack` needs them, and only the
skill folders listed in `sources.lock` are copied, each with its upstream `LICENSE`.

`bootstrap.sh` fetches and checks every source it needs before it installs anything, and stops with nothing
installed if the Ponytail hash or any commit is not the pinned one, or if a pinned third-party skill turns out to
need plugin-only features (`${CLAUDE_PLUGIN_ROOT}`, MCP servers, hooks) or contains symlinks.

## Packs

`--pack NAME[,NAME]` (repeatable, or `--pack all`) adds optional packs defined in `packs.conf`. Without it,
`bootstrap.sh` installs exactly the base toolkit above. Pack names are checked before anything is installed.

| Pack | Written here | Third-party (pinned) |
|---|---|---|
| `roles` | agents `lead-engineer`, `senior-engineer`, `mid-level-engineer`; command `/tiered-review`; skill `system-design` | |
| `quant` | `quant-researcher`, `quant-developer` | |
| `systems` | `rust-developer`, `cpp-developer`, `low-latency-systems` | ToB `modern-cpp`; ECC `rust-patterns`, `rust-testing`, `cpp-testing` |
| `web3` | `blockchain-developer`, `solidity-developer`, `web3-integration`, `crypto-custody-and-keys` | ToB `entry-point-analyzer`, and from building-secure-contracts: `secure-workflow-guide`, `guidelines-advisor`, `token-integration-analyzer`, `code-maturity-assessor`, `audit-prep-assistant`; ECC `evm-token-decimals`, `defi-amm-security` |
| `fintech` | `financial-ledger`, `kyc-aml-compliance` | |
| `security` | | ToB `property-based-testing` |
| `mobile` | `react-native-expo` | ECC `react-native-patterns` |
| `ops` | | wshobson `prometheus-configuration`, `postmortem-writing` |
| `memory` | skill `agent-memory`; commands `/learn`, `/promote-lessons`, `/handoff`, `/pickup` (see "Memory and handoffs") | |

The role agents are read-only (`tools: Read, Grep, Glob`). `/tiered-review` picks the tier from the diff
(mid-level by default; senior for logic, concurrency, money or security; lead for new services, schemas,
APIs and cross-service contracts), runs that agent, and follows its escalations. It does not replace `/review`.
Everything here is generic: product-, employer- and country-specific rules belong in a profile.

Where a third-party skill in a pack is looser than the skill written here, the skill written here says so and
wins: `blockchain-developer` refuses a token whose `decimals()` call fails (`evm-token-decimals` falls back to
18), and `rust-developer` keeps `expect()` and `panic!` out of production paths (some `rust-patterns` and
`rust-testing` examples use them).

**Licences.** Trail of Bits skills are CC-BY-SA-4.0, wshobson and ECC skills MIT; their `LICENSE` sits in each
installed copy. A tailored override of one of them is a derivative work: it must keep the attribution and, for
Trail of Bits, stay under CC-BY-SA-4.0. `profile_save.sh` copies the `LICENSE` into the override folder for
that reason.

**Not installed, and why** (evaluated 2026-10-26, see the comments in `sources.lock`):

| Item | Reason |
|---|---|
| ToB `rust-review`, `c-review` | Need `${CLAUDE_PLUGIN_ROOT}` and plugin scripts, prompts and agents |
| ToB `insecure-defaults` | A plugin command plus workflow script, not a skill |
| ToB `zeroize-audit` | Needs the Serena MCP server (fetched unpinned by `uvx` at run time) and plugin agents |
| ToB `dimensional-analysis` | Dispatches five registered plugin agents |
| ToB `constant-time-analysis` | Its analyzer lives outside the skill folder |
| ToB `supply-chain-risk-auditor` | Reads the gh CLI token (`gh auth token`) and pre-approves Bash and Write; add it only if you accept that |
| ToB building-secure-contracts chain scanners (Algorand, Cairo, Cosmos, Solana, Substrate, TON) | Chain-specific; add to `TOB_SKILL_PATHS` when a project needs one |
| wshobson agents (all 17) | No `tools:` limit (every tool), most pin a model; `blockchain-developer` would clash with the skill of that name |
| wshobson `systems-programming`, `quantitative-trading`, `blockchain-web3` | Covered by the first-party skills |
| wshobson `slo-implementation` | Its burn-rate alerts use recording rules it never defines, so they would not fire |
| wshobson `distributed-tracing`, `grafana-dashboards` | Deprecated Jaeger exporter and legacy Grafana panels and alerts |
| wshobson `incident-runbook-templates` | Wrong or risky commands in its runbooks (invalid SQL, `VACUUM FULL` during an incident) |
| wshobson `on-call-handoff-patterns`, `connectivity-triage` | A human process with little use to a coding agent; macOS-only |
| ECC agents (71), commands (97), hooks (27), rule packs (22), MCP config | Agents pin a model and most have Bash, `code-reviewer` and `/plan` clash with Agent Skills; hooks run Node on every tool call and inject memory at session start; rules load into every session |
| ECC installer, CLI, plugin `ecc@ecc`, other-harness configs, docs | `bootstrap.sh` copies pinned folders instead; only Claude Code is targeted |
| ECC `llm-trading-agent-security` | Takes the signing key from an environment variable and relies on a regex injection filter, against `crypto-custody-and-keys` |
| ECC `latency-critical-systems`, `cpp-coding-standards`, `architecture-decision-records`, `tdd-workflow` | Covered by `low-latency-systems`, ToB `modern-cpp`, `system-design` and Agent Skills TDD |
| ECC `security-review` | Clashes with Claude Code's built-in `security-review` |
| ECC `continuous-learning`, `continuous-learning-v2`, `unified-memory`, `/learn`, `/save-session`, `/resume-session` | Their ideas are rebuilt in the `memory` pack without hooks, a background observer or a runtime; see "Memory and handoffs" |
| The other ECC skills (about 290) | Outside the packs, or need the ECC plugin, CLI or an MCP server (13 do) |

Agent Skills itself has `observability-and-instrumentation` at the current pin; adding it to `AGENT_SKILLS_LIST`
is the simplest route to generic observability guidance.

## Memory and handoffs

The `memory` pack gives agents a memory that survives a thrown-away container and works across sessions and
tools. It takes the ideas behind ECC's continuous learning, session save and resume, and memory vault, and keeps
this repo's rules: nothing runs in the background, nothing new is fetched, and you approve every write.

- `/learn` records lessons from the session in `.agent-memory/LESSONS.md` in the project repo: a correction you
  made, an error and its root cause, an approach that failed and why, a convention nobody wrote down. Each
  lesson is one trigger and one action with dated evidence. It starts as `candidate`, becomes `confirmed` when
  the evidence repeats in a later session or you confirm it, and is `retired` (kept, with the reason) when it
  turns out wrong.
- `/promote-lessons` builds confirmed lessons into the installed skills, commands or agents, one approved diff
  at a time, under the same limits as tailoring. At project scope those edits are tailoring, so
  `profile_save.sh` carries them into a profile and the next project starts with them.
- `/handoff` writes `.agent-memory/handoffs/<YYYY-MM-DD-HHMM>-<slug>.md`: the verified state with its evidence,
  what did not work, decisions, open questions, your rules in your words, one next step, and a closing line
  saying it grants no permission. It also prints a block to paste into the next session or tool.
- `/pickup` reads a handoff, checks it against the repo read-only (commit, files, quick checks), reports what is
  stale, and waits for you.
- `check.py` in the skill folder validates both formats and flags likely secrets by file and line, never by
  value.
- With your approval, a short marked block in the project's `AGENTS.md` (plus `@AGENTS.md` in `CLAUDE.md`)
  tells every agent where the memory is and that it is data, not instructions.

A typical loop: `/learn` at the end of a task and commit `LESSONS.md` with the change; `/handoff` when work moves
to another session, paste the block there (or push the file on the branch), and `/pickup`; now and then
`/promote-lessons`, then `profile_save.sh` to keep the result.

| ECC | Here | Why |
|---|---|---|
| Hooks record every prompt and tool call; an optional background model turns them into "instincts" | You run `/learn`; the agent proposes lessons, you approve the diff | No transcripts or tool output on disk, no reliance on a regex secret scrubber, no daemon or extra model calls |
| Confidence scores from 0.3 to 0.9 | `candidate`, `confirmed`, `promoted` or `retired`, with dated evidence | Observations can be checked; a score cannot |
| Instincts injected into every session at start | A reviewed file the agent reads because `AGENTS.md` or `CLAUDE.md` points to it | Only reviewed text reaches the context |
| `/evolve` clusters instincts into new skills, commands or agents | `/promote-lessons` edits the installed ones by diff | Fits the tailoring and profile flow; nothing is generated unreviewed |
| Session files in `~/.claude/session-data`, instincts in `~/.local/share`, a git-ignored project vault | `.agent-memory/` in the project repo, committed through review | A cloud container loses its home directory and ignored files; git keeps the repo, and pull requests review it |
| Memory vault CLI and MCP server (npm package) | Plain Markdown and one Python checker | No new source or runtime; every tool reads Markdown |
| A handoff routed by harness name | One format for any reader, plus a paste-ready block | Between cloud sessions, work moves by paste or by a pushed branch |

Kept from ECC as is: memory is unreviewed context, never policy or permission; verify a claim against the repo
before relying on it, and a newer correction wins; a saved handoff is never edited, a new one replaces it; the
"did not work" list matters most; no secrets, ever.

## Files

| File | Purpose |
|---|---|
| `SETUP_PROMPT.md` | The prompt to paste into a new session |
| `bootstrap.sh` | Installer: `--scope user\|project`, `--pack NAME[,NAME]`, `--profile NAME`, `--with-rules`, `--dry-run` |
| `project-init.sh` | Per-project graphify wiring and a code-only graph build |
| `sources.lock` | Allowed sources and pins |
| `packs.conf` | Which items each optional pack installs |
| `agents/`, `commands/`, `skills/` | Role agents, `/tiered-review`, the memory commands and skills written here, installed only by packs |
| `scripts/profile_save.sh` | Captures tailoring done in `./.claude` as a profile |
| `scripts/*.py` | Two small helpers (fail-open hooks, marked `CLAUDE.md` blocks) |
| `profiles/<name>/` | Saved tailoring for one product (created by `profile_save.sh`) |
| `rules/CLAUDE.md` | My standing rules (draft); installed only with `--with-rules` |
| `docs/context-mode.md` | Evaluation notes on `context-mode`; not installed |
| `tests/` | Regression tests: `bash tests/run.sh` (needs network; uses a throwaway HOME) |

## Scopes

- **user** (default): everything goes to `~/.claude`. Project repos stay clean, and it applies to every repo
  on that machine. Graphify gets its skill and a `CLAUDE.md` section here, but no hooks.
- **project**: everything goes to `./.claude` of the working directory, plus a `CLAUDE.md` there, with
  graphify's hooks. Files stay untracked until you add them; do not commit them by accident.

Project scope also keeps a pristine copy of what it installed in `.claude/.vibe-setup/pristine/`, so any
tailoring can be diffed against upstream. Pack items are part of that copy, and the packs installed are
recorded in `.claude/.vibe-setup/packs`. Re-run with the same `--pack` list: files of a pack you drop stay in
`.claude/` and would look like tailoring to `profile_save.sh` (bootstrap warns when that happens).

`project-init.sh` (run inside a git repo) adds graphify's hooks and git hooks, appends `graphify-out/` to
`.gitignore`, and builds the graph from code only (AST) with a stripped environment, so no API key can be used.
It also creates an untracked `.gitattributes` for graphify's merge driver. Nothing is committed.

## Tailoring the skills to a product

The upstream skills are written for someone else's projects. `SETUP_PROMPT.md` therefore has the agent
interview you about your product, propose tweaks, and apply only the ones you approve as diffs.

1. The agent installs at **project scope** (tailored copies must not sit beside untailored user-level ones;
   which copy wins is not something I could verify).
2. It edits the installed copies in `./.claude/{skills,commands,agents}`. Upstream and the pins are never edited.
3. `scripts/profile_save.sh NAME` diffs `./.claude` against the pristine snapshot and writes
   `profiles/NAME/`: `overrides/` (changed or new files), `remove.txt` (upstream items dropped),
   `profile.lock` (the pins and packs it was made with) and `CHANGES.diff` (human-readable, never applied).
   `PROJECT.md`, the confirmed product summary, is written next to them. Review all of it in a pull request.
4. Next session: `bootstrap.sh --scope project --profile NAME` installs upstream at the pins, plus the packs the
   profile was saved with, then replays the profile and adds `PROJECT.md` to `.claude/CLAUDE.md`. It warns if
   `sources.lock` has moved since the profile was saved.

`bootstrap.sh` validates a profile before it installs anything and refuses one that writes outside
`skills/`, `commands/` and `agents/` (no settings or hooks), changes or removes graphify's skill, contains
symlinks, or lists unsafe removals (anything outside those folders, or one of the folders as a whole).
A profile cannot change `settings.json`.

Keep confidential details (including employer-specific ones) out of `PROJECT.md` and the overrides: this repo
is private, but the files are plain text in git history.

## Tested (2026-10-26, Linux container, throwaway HOME)

Every check in the bullets before "Fresh cloud sessions" is scripted in `tests/` (`bash tests/run.sh`, 210 checks
when this was written). They never touch the real `~/.claude` or uv tools. The cloud-session results are manual.

- Dry run; full install; re-run (no duplicates); stop on a tampered Ponytail hash (exit 1, nothing installed).
- `--with-rules` appends after graphify's existing `CLAUDE.md` section and replaces its own block on re-run.
- Fail-open rewrite of graphify's hooks keeps other settings keys and valid JSON.
- `--scope project`, and `project-init.sh` on a scratch repo (report says 0 input / 0 output tokens).

- Profiles: tweak, remove and add files in a project install, capture with `profile_save.sh`, replay in a fresh
  project (all changes present, `PROJECT.md` block once), re-run, re-save and compare (identical), pin-drift
  warning, "nothing to save", and nine hostile profiles (settings override, `../` and absolute removals,
  non-skill removal, symlink, removal of a whole folder (two forms), removal or override of graphify's skill)
  all refused with nothing installed.

- Packs: `--pack` without a value and unknown pack names refused before anything is installed; dry runs at both
  scopes change nothing, and without `--pack` nothing from the packs is planned; `--pack all` installs every
  item at user and project scope, each third-party copy with its `LICENSE`, no `CLAUDE_PLUGIN_ROOT` anywhere,
  role agents limited to Read, Grep and Glob, valid frontmatter and unique names; a re-run is identical; a
  default install has exactly the base skills from `sources.lock` and no pack item, and each pack installed on
  its own adds exactly its items to that and removes nothing; an
  unfetchable Trail of Bits pin and a pinned skill that needs plugin-only features both stop with nothing
  installed; the snapshot covers the packs and `profile_save.sh` finds nothing to save; a profile saved with
  packs records them, keeps the `LICENSE` in a tailored third-party skill, and replays them without `--pack`;
  dropping the packs on a re-run prints a warning.

- Memory (offline): `check.py` accepts the skill's own lesson and handoff examples and changes no file; names
  each format problem (duplicate or malformed id, missing or empty field, bad status, scope or count, undated
  evidence, missing or empty handoff section, missing closing line, bad file name); reports likely secrets by
  file and line without printing them, while names of secrets, placeholders and variables pass; skips and
  reports symlinks, and refuses a symlinked memory directory.

Fresh cloud sessions (2026-10-26; two sessions started from this prompt, one with nothing attached and
`skip tailoring`, one on a public project repo):

- Steps 1 to 3 ran as written: detect, `add_repo` for this private repo, shallow clone at the merge commit,
  and reading the scripts before running them.
- The `skip tailoring` session stopped at step 5, blocked by the permission check (see Quick start).
- The tailoring session started the interview correctly, asked question (a) and waited. It did not accept
  answers or permission relayed by another session.

**Not tested:** macOS; whether user-scope skills show up inside an already-running cloud session
(project-scope files did, in an earlier session); a full run in a cloud session past step 5, so the real
install there, the rest of the interview, tailoring, saving a profile and replaying it. Only the scripts
behind them were exercised, so expect to adjust the wording of steps 4 and 7 after the first complete run.

## Dangling references

`bootstrap.sh` checks whether an installed command or agent mentions an upstream skill that is not installed,
and prints a `WARN` line for each one. At the current pins there are none (checked 2026-10-26). If you shorten
`AGENT_SKILLS_LIST`, or a pin moves to a commit that references more skills, add the named skill to
`AGENT_SKILLS_LIST` in `sources.lock`; it has to exist upstream at the pinned commit.

With packs, the same check covers this repo's skills and agents and every skill at the third-party pins fetched
for the run, and it also reads the `SKILL.md` of each installed pack skill. Names are matched whole, hyphens
included. Upstream skills that mention siblings this repo does not install produce informational `WARN` lines;
the role agents and domain skills written here mention only items of their own pack (or of the base toolkit),
so they never do.

## Updating a pin

Review the upstream diff first. Then change the SHA (and, for Ponytail, the sha256 of `SKILL.md`) in
`sources.lock`, run `--dry-run`, and open a pull request. For Trail of Bits, wshobson and ECC, read every changed
file in the listed skill folders in full (they are marked "audited line by line"), check that each folder still
lives at the same path, and update the audit date in `sources.lock`.

Ponytail was reviewed against upstream `main` (`09c434ab`) on 2026-10-26. Since the pin, only commit `df9e8994`
(2026-10-16) changes `skills/ponytail/SKILL.md`: it adds `off` to the frontmatter `argument-hint`. Ponytail's
plugin hooks handle `off`, and this repo does not install them, so the pin stays. Agent Skills has moved on
from the pinned commit; that diff has not been reviewed.

## Uninstall

`graphify uninstall`, `uv tool uninstall graphifyy`, then delete the skill, command and agent files listed
by `bootstrap.sh` from `~/.claude` (or `./.claude`, including `./.claude/.vibe-setup/`); pack items are listed in
`packs.conf`. The rules block sits
between `<!-- vibe-setup:begin -->` and `<!-- vibe-setup:end -->` in `CLAUDE.md`; a profile's block uses
`<!-- vibe-setup:begin:profile:NAME -->` and the matching end marker.
