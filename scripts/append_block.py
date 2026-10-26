#!/usr/bin/env python3
"""Append a file to a CLAUDE.md between markers; re-running replaces only that block.

usage: append_block.py <target CLAUDE.md> <source file> [tag]
Markers are <!-- vibe-setup:begin --> / <!-- vibe-setup:end -->, or with a tag
<!-- vibe-setup:begin:TAG --> / <!-- vibe-setup:end:TAG -->, so rules and each profile get their own block.
Anything outside the markers in the target is never touched.
"""
import pathlib
import re
import sys

target, source = (pathlib.Path(p) for p in sys.argv[1:3])
suffix = f":{sys.argv[3]}" if len(sys.argv) > 3 else ""
BEGIN, END = f"<!-- vibe-setup:begin{suffix} -->", f"<!-- vibe-setup:end{suffix} -->"

text = target.read_text(encoding="utf-8") if target.exists() else ""
text = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "", text, flags=re.S)
block = f"{BEGIN}\n{source.read_text(encoding='utf-8').rstrip()}\n{END}\n"

target.parent.mkdir(parents=True, exist_ok=True)
target.write_text((text.rstrip() + "\n\n" if text.strip() else "") + block, encoding="utf-8")
print(f"{target}: block{suffix or ''} written")
