#!/usr/bin/env bash
# Shared helpers for the vibe-setup regression tests. Sourced by test_*.sh; not run directly.
#
# Every test runs in a throwaway HOME, so the real ~/.claude and the real uv tools are never touched.
# Only the uv *cache* is shared with the real one, so packages are not downloaded on every run.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

# Resolve the real uv cache before HOME is redirected.
if [ -z "${UV_CACHE_DIR:-}" ] && command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$(uv cache dir 2>/dev/null || true)"
fi
if [ -n "${UV_CACHE_DIR:-}" ]; then export UV_CACHE_DIR; fi

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
export HOME="$W/home"
export UV_TOOL_DIR="$HOME/uvtools"
export UV_TOOL_BIN_DIR="$HOME/bin"
mkdir -p "$HOME/bin"
export PATH="$UV_TOOL_BIN_DIR:$PATH"

# Safety guard: never run with a HOME outside the sandbox.
case "$HOME" in "$W"/*) ;; *) echo "refusing to run: HOME is not sandboxed" >&2; exit 2 ;; esac

ok()  { PASS=$((PASS + 1)); echo "PASS: $*"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

# check "description" command...   (command output is hidden)
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

# capture command...   runs it, stores combined output in $OUT and the exit code in $RC; never aborts.
# Output is captured first and searched afterwards: piping into `grep -q` makes the pipeline's status
# depend on SIGPIPE and on the script's own exit code, which gave false failures before.
capture() { OUT="$("$@" 2>&1)"; RC=$?; }

# expect_out "description" "pattern"   searches $OUT
expect_out() {
  if printf '%s\n' "$OUT" | grep -q -- "$2"; then ok "$1"; else
    bad "$1 (wanted: $2; rc=$RC)"; printf '%s\n' "$OUT" | tail -6 | sed 's/^/    /'
  fi
}

# expect_rc "description" N   checks $RC
expect_rc() { if [ "$RC" -eq "$2" ]; then ok "$1"; else bad "$1 (rc=$RC, wanted $2)"; printf '%s\n' "$OUT" | tail -6 | sed 's/^/    /'; fi; }

# Read one variable from sources.lock without leaking its other assignments.
lockvar() { ( . "$1/sources.lock"; eval "printf '%s' \"\${$2}\"" ); }

sha256_of() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

# copy_repo DEST   a copy of the repo without .git and tests, so a test can change sources.lock or profiles/.
copy_repo() { rm -rf "$1"; mkdir -p "$1"; (cd "$REPO" && tar --exclude=./.git --exclude=./tests -cf - .) | (cd "$1" && tar -xf -); }

finish() { echo "== $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }
