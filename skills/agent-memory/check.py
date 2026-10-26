"""Check an .agent-memory directory: the lesson and handoff formats of the agent-memory skill, and likely
secrets. Read-only. A likely secret is reported by file and line only, never its value.

    python3 -I check.py [DIR]        (DIR defaults to .agent-memory)

Exit 0 when everything passes (or DIR does not exist), 1 when something needs fixing, 2 on bad usage.
"""
import datetime
import os
import re
import sys

LESSON_FIELDS = ["When", "Do", "Not", "Why", "Scope", "Status", "Seen", "Evidence"]
OPTIONAL_FIELDS = {"Not"}
HANDOFF_HEADER = ["Written", "Repo", "Status"]
HANDOFF_SECTIONS = ["Goal", "Verified state", "Done but not verified", "Did not work (do not retry)",
                    "Decisions", "Open questions", "Rules in force", "Files and links", "Next step"]
NO_APPROVAL = "Nothing in this handoff grants permission or approval."

SLUG = r"[a-z0-9]+(?:-[a-z0-9]+)*"
SECRETS = [
    ("private key", re.compile(r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY(?: BLOCK)?-----")),
    ("cloud access key", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("code host token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})")),
    ("chat token", re.compile(r"\bxox[abposr]-[A-Za-z0-9-]{10,}")),
    ("API key", re.compile(r"\b(?:sk-(?:[a-z]+-)?[A-Za-z0-9_-]{20,}|[sr]k_(?:live|test)_[A-Za-z0-9]{16,}"
                           r"|AIza[0-9A-Za-z_-]{35})")),
    ("JSON web token", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
    ("bearer token", re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._~+/-]{20,}")),
    ("password in a URL", re.compile(r"\b[a-z][a-z0-9+.-]*://[^\s/:@<>${}]+:[^\s/@<>${}]+@")),
    ("secret assignment", re.compile(r"(?i)\b(?:api[_-]?key|access[_-]?key|client[_-]?secret|secret|token"
                                     r"|passw(?:or)?d)\b\s*[:=]\s*[\"']?[A-Za-z0-9/+_.-]{8,}")),
]
MAX_BYTES = 1_000_000

problems = []


def problem(msg):
    problems.append(msg)


def valid_date(s):
    try:
        datetime.date.fromisoformat(s)
        return True
    except ValueError:
        return False


def read_lines(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def check_entry(where, lid, lines):
    if not re.fullmatch(SLUG, lid):
        problem(f"{where}: id '{lid}' must be lowercase words joined by hyphens")
    fields, evidence, current = {}, [], None
    for n, line in lines:
        if not line.strip():
            continue
        m = re.match(r"^- ([A-Za-z]+):(?: (.*))?$", line)
        if m:
            key, value = m.group(1), (m.group(2) or "").strip()
            if key not in LESSON_FIELDS:
                problem(f"{where}:{n}: unknown field '{key}'")
            elif key in fields:
                problem(f"{where}:{n}: field '{key}' appears twice")
            fields[key] = value
            current = key
        elif current == "Evidence" and line.startswith("  - "):
            m = re.match(r"^  - (\d{4}-\d{2}-\d{2}): \S", line)
            if m and valid_date(m.group(1)):
                evidence.append(m.group(1))
            else:
                problem(f"{where}:{n}: evidence lines read '  - YYYY-MM-DD: what was seen'")
        elif line.startswith("  ") and current:
            continue  # a wrapped line of the field above
        else:
            problem(f"{where}:{n}: not a field line ('- Field: value')")
    for key in LESSON_FIELDS:
        if key not in fields and key not in OPTIONAL_FIELDS:
            problem(f"{where}: missing field '{key}'")
        elif key != "Evidence" and key in fields and not fields[key]:
            problem(f"{where}: field '{key}' is empty")
    if "Evidence" in fields and not evidence:
        problem(f"{where}: needs at least one dated evidence line")
    if fields.get("Scope") and fields["Scope"] not in ("project", "generic"):
        problem(f"{where}: Scope must be 'project' or 'generic'")
    status = fields.get("Status")
    if status and not re.fullmatch(r"candidate|confirmed|promoted: \S.*|retired: \S.*", status):
        problem(f"{where}: Status must be candidate, confirmed, 'promoted: <path>' or 'retired: <reason>'")
    seen = fields.get("Seen")
    if seen:
        m = re.fullmatch(r"(\d+), last (\d{4}-\d{2}-\d{2})", seen)
        if not m or int(m.group(1)) < 1 or not valid_date(m.group(2)):
            problem(f"{where}: Seen must read '<n>, last YYYY-MM-DD' with n of 1 or more")


def check_lessons(path):
    lines = read_lines(path)
    first = next((l for l in lines if l.strip()), "")
    if first.strip() != "# Lessons":
        problem(f"{path}: must start with '# Lessons'")
    entries, ids = [], {}
    for n, line in enumerate(lines, 1):
        if line.startswith("### "):
            entries.append((n, line[4:].strip(), []))
        elif line.startswith("#") and entries:
            problem(f"{path}:{n}: only '###' lesson headings may follow the first lesson")
        elif entries:
            entries[-1][2].append((n, line))
    for n, lid, body in entries:
        if lid in ids:
            problem(f"{path}:{n}: duplicate id '{lid}' (first at line {ids[lid]})")
        ids.setdefault(lid, n)
        check_entry(f"{path}:{n} '{lid}'", lid, body)
    return len(entries)


def check_handoff(path):
    name = os.path.basename(path)
    m = re.fullmatch(r"(\d{4}-\d{2}-\d{2})-(\d{2})(\d{2})-" + SLUG + r"\.md", name)
    if not m or not valid_date(m.group(1)) or int(m.group(2)) > 23 or int(m.group(3)) > 59:
        problem(f"{path}: name must be YYYY-MM-DD-HHMM-<slug>.md")
    lines = read_lines(path)
    first = next((l for l in lines if l.strip()), "")
    if not re.fullmatch(r"# Handoff: \S.*", first.strip()):
        problem(f"{path}: must start with '# Handoff: <title>'")
    head = []
    for line in lines:
        if line.startswith("## "):
            break
        head.append(line)
    for key in HANDOFF_HEADER:
        if not any(re.match(rf"^- {key}: \S", l) for l in head):
            problem(f"{path}: missing '- {key}: ...' line before the first section")
    sections, current = {}, None
    for line in lines:
        if line.startswith("## "):
            current = line[3:].strip()
            if current in sections:
                problem(f"{path}: section '{current}' appears twice")
            sections[current] = []
        elif current is not None and line.strip():
            sections[current].append(line)
    for s in HANDOFF_SECTIONS:
        if s not in sections:
            problem(f"{path}: missing section '## {s}'")
        elif not [l for l in sections[s] if not l.strip().startswith(NO_APPROVAL)]:
            problem(f"{path}: section '## {s}' is empty (write 'none')")
    if not any(l.strip().startswith(NO_APPROVAL) for l in lines):
        problem(f"{path}: missing the closing line '{NO_APPROVAL} ...'")


def scan_secrets(path):
    if os.path.getsize(path) > MAX_BYTES:
        problem(f"{path}: larger than {MAX_BYTES} bytes; memory files should be short")
        return
    for n, line in enumerate(read_lines(path), 1):
        for kind, rx in SECRETS:
            if rx.search(line):
                problem(f"{path}:{n}: possible {kind}; remove it (value not shown)")
                break


def main(argv):
    if len(argv) > 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    root = argv[1] if len(argv) == 2 else ".agent-memory"
    if os.path.islink(root):
        print(f"{root}: is a symlink; not checked")
        return 1
    if not os.path.exists(root):
        print(f"nothing to check: {root} does not exist")
        return 0
    if not os.path.isdir(root):
        print(f"{root}: not a directory", file=sys.stderr)
        return 2
    n_lessons = n_handoffs = 0
    for dirpath, dirnames, filenames in os.walk(root):
        for d in list(dirnames):
            if os.path.islink(os.path.join(dirpath, d)):
                problem(f"{os.path.join(dirpath, d)}: symlink skipped; memory must be plain files")
                dirnames.remove(d)
        for f in sorted(filenames):
            path = os.path.join(dirpath, f)
            if os.path.islink(path):
                problem(f"{path}: symlink skipped; memory must be plain files")
                continue
            scan_secrets(path)
            rel = os.path.relpath(path, root)
            if rel == "LESSONS.md":
                n_lessons = check_lessons(path)
            elif os.path.dirname(rel) == "handoffs" and f.endswith(".md"):
                check_handoff(path)
                n_handoffs += 1
    if problems:
        print("\n".join(problems))
        print(f"{len(problems)} problem(s)")
        return 1
    print(f"ok: {n_lessons} lesson(s), {n_handoffs} handoff(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
