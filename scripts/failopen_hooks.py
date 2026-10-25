#!/usr/bin/env python3
"""Make graphify hook commands fail-open: skip silently when graphify is not installed.

usage: failopen_hooks.py <settings.json>
Rewrites "<path>/graphify hook-guard X" to
"command -v graphify >/dev/null 2>&1 && exec graphify hook-guard X; exit 0".
All other keys are left alone; the file is re-read afterwards to confirm it is valid JSON.
"""
import json
import re
import sys

PATTERN = re.compile(r"^(?:\S*/)?graphify hook-guard (\S+)$")

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

changed = 0
for entries in data.get("hooks", {}).values():
    for entry in entries:
        for hook in entry.get("hooks", []):
            m = PATTERN.match(hook.get("command", ""))
            if m:
                hook["command"] = (
                    "command -v graphify >/dev/null 2>&1 && "
                    f"exec graphify hook-guard {m.group(1)}; exit 0"
                )
                changed += 1

if changed:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    with open(path, encoding="utf-8") as f:
        json.load(f)  # re-validate

print(f"{path}: {changed} hook(s) made fail-open")
