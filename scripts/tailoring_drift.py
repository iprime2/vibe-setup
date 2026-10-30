#!/usr/bin/env python3
"""List tailoring in a project-scope install that re-running bootstrap.sh would overwrite.

usage: tailoring_drift.py <CLAUDE_DIR> [PROFILE_DIR]
Compares <CLAUDE_DIR>/{skills,commands,agents} with the pristine snapshot in <CLAUDE_DIR>/.vibe-setup/pristine.
With PROFILE_DIR, a file that matches the profile's overrides/ copy, or a path the profile's remove.txt
deletes, is not drift: replaying the same profile puts it back. Prints one relative path per line, with
the reason; prints nothing when a re-run loses nothing. Graphify's generated skill and Python bytecode are
ignored.
"""
import pathlib
import sys

claude = pathlib.Path(sys.argv[1])
profile = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else None
pristine = claude / ".vibe-setup" / "pristine"
overrides = profile / "overrides" if profile else None
removed = []
if profile and (profile / "remove.txt").is_file():
    for line in (profile / "remove.txt").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            removed.append(line.rstrip("/"))


def ignored(rel):
    parts = rel.split("/")
    return rel.startswith("skills/graphify/") or "__pycache__" in parts or rel.endswith(".pyc")


def files(root):
    out = set()
    for d in ("skills", "commands", "agents"):
        base = root / d
        if base.is_dir():
            for p in base.rglob("*"):
                if p.is_file():
                    rel = p.relative_to(root).as_posix()
                    if not ignored(rel):
                        out.add(rel)
    return out


def is_removed(rel):
    return any(rel == r or rel.startswith(r + "/") for r in removed)


installed, snap = files(claude), files(pristine)
drift = []
for rel in sorted(installed):
    if overrides and (overrides / rel).is_file():
        expected = overrides / rel
    elif rel in snap:
        expected = pristine / rel
    else:
        drift.append(f"{rel} (added; not in the snapshot or the profile)")
        continue
    if (claude / rel).read_bytes() != expected.read_bytes():
        drift.append(f"{rel} (changed)")
for rel in sorted(snap - installed):
    if not is_removed(rel):
        drift.append(f"{rel} (deleted)")
print("\n".join(drift))
