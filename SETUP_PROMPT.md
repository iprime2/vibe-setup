# Setup prompt

Paste the block below as the first message of a new Claude Code session (cloud or local).
Everything it installs is pinned in `sources.lock`; the prompt tells the agent to stop rather than improvise.

Optional words you can add to the last line of the prompt:

- `with rules`: also install `rules/CLAUDE.md` into the user `CLAUDE.md` (draft, review it first).
- `project scope`: install into `./.claude` of the working directory instead of `~/.claude`.
- `project init`: also wire graphify into the current git repo and build a code-only graph.

```text
Set up my vibe-coding toolkit in this environment from my setup repo, iprime2/vibe-setup. Work step by step, show each command before you run it, and stop and tell me if anything fails or a source differs from what the repo pins. Use no source other than the ones pinned in sources.lock. Do not commit, push, or edit anything outside what the scripts do. Never print or touch secrets, tokens, or .env files.

1. DETECT (read-only). Tell me: which agent you are, the OS, whether this is a Claude Code cloud session (CLAUDE_CODE_REMOTE=true), the user, the working directory and whether it is a git repo, and the versions of git, uv, node and claude. If uv is missing and this is not a cloud session, ask me before installing it.

2. GET THE REPO. If ~/vibe-setup or /home/user/vibe-setup already exists, use it and tell me its commit (git -C <dir> log -1 --oneline). Otherwise fetch iprime2/vibe-setup: in a cloud session attach it with add_repo (read access) and clone it where that tool says; on a local machine run git clone https://github.com/iprime2/vibe-setup ~/vibe-setup. Clone it outside any project repo. If it cannot be reached, stop and tell me; do not look for another source.

3. READ BEFORE RUNNING. Read sources.lock, bootstrap.sh and the files in scripts/, then tell me in five lines or fewer what bootstrap.sh will do and what it pins.

4. DRY RUN. Run: bash <repo>/bootstrap.sh --dry-run   and summarise it.

5. INSTALL. Run: bash <repo>/bootstrap.sh   Add --with-rules only if I wrote "with rules" below. Add --scope project only if I wrote "project scope" below. If it prints STOP, show me the message and do nothing else; do not work around it. Report WARN lines to me; do not try to fix them.

6. PROJECT WIRING. Only if I wrote "project init" below and the working directory is a git repo: run bash <repo>/project-init.sh --dry-run, show me, then run it without --dry-run.

7. VERIFY AND REPORT. Show graphify --version and the files bootstrap listed. Tell me whether the new skills and slash commands appear in your skill list (they may only appear on your next turn or in a new session). If project init ran, show git status --short and the first 5 lines of graphify-out/GRAPH_REPORT.md. List anything that still needs a restart and anything you could not do. Do not commit.

Options for this run: (write here, or leave empty)
```
