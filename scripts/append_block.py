#!/usr/bin/env python3
"""Write a file into a CLAUDE.md between markers; re-running replaces only that block.

usage: append_block.py <target CLAUDE.md> [<source file> [tag]]
Markers are <!-- vibe-setup:begin --> / <!-- vibe-setup:end -->, or with a tag
<!-- vibe-setup:begin:TAG --> / <!-- vibe-setup:end:TAG -->, so rules and each profile get their own block.
Anything outside the markers in the target is never touched.

Blocks are kept above graphify's "# graphify" section (at the end when there is none): `graphify install`
rewrites that section down to the next "# " heading, so a begin marker below it was cut off and the next
run wrote a second copy. With only a target, blocks below that section are moved above it and nothing
else changes; bootstrap.sh does this before it runs `graphify install`.
"""
import pathlib
import re
import sys

BLOCK = re.compile(r"<!-- vibe-setup:begin((?::\S+)?) -->.*?<!-- vibe-setup:end\1 -->\n?", re.S)
MARKER = re.compile(r"<!-- vibe-setup:(?:begin|end)(?::\S+)? -->")
GRAPHIFY = re.compile(r"^[ \t]*# graphify[ \t\r]*$", re.M)


def above_graphify(text, extra=""):
    """Move the blocks below graphify's last heading (graphify uses the last one), then extra, just above it."""
    heads = list(GRAPHIFY.finditer(text))
    at = heads[-1].start() if heads else len(text)
    head, tail = text[:at], text[at:]
    blocks = [m.group(0).strip("\n") for m in BLOCK.finditer(tail)] + ([extra.strip("\n")] if extra else [])
    if not blocks:
        return text
    return "\n\n".join(p for p in (head.rstrip(), *blocks, BLOCK.sub("", tail).strip("\n")) if p) + "\n"


target = pathlib.Path(sys.argv[1])
old = target.read_text(encoding="utf-8") if target.exists() else ""
text = above_graphify(old)
if len(sys.argv) > 2:
    suffix = f":{sys.argv[3]}" if len(sys.argv) > 3 else ""
    BEGIN, END = f"<!-- vibe-setup:begin{suffix} -->", f"<!-- vibe-setup:end{suffix} -->"
    block = f"{BEGIN}\n{pathlib.Path(sys.argv[2]).read_text(encoding='utf-8').rstrip()}\n{END}\n"
    mine = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", re.S)
    m = mine.search(text)
    text = text[:m.start()] + block + mine.sub("", text[m.end():]) if m else above_graphify(text, block)

if MARKER.search(BLOCK.sub("", text)):
    print(f"WARN: {target} has a vibe-setup marker without its pair (an older run's `graphify install` "
          "cut the begin marker off); delete the leftover copy by hand")
if text != old:
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")
if len(sys.argv) > 2:
    print(f"{target}: block{suffix} written")
elif text != old:
    print(f"{target}: blocks moved above graphify's section")
