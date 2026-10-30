#!/usr/bin/env bash
# Run the regression tests.
#
#   bash tests/run.sh                    all tests
#   bash tests/run.sh tests/test_install.sh
#
# Needs network (PyPI, raw.githubusercontent.com, github.com) because bootstrap.sh fetches the pinned
# sources. Each test uses a throwaway HOME; the real ~/.claude and uv tools are never touched.
# It is not fast: most cases do a real install over the network. Exits non-zero if any check fails.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$#" -gt 0 ]; then files=("$@"); else files=("$HERE"/test_*.sh); fi

status=0
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
for f in "${files[@]}"; do
  echo "######## $(basename "$f")"
  bash "$f" 2>&1 | tee -a "$log"
  [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
done

sum() { grep -oE "^== [0-9]+ passed, [0-9]+ failed" "$log" | awk -v k="$1" '{ s += $k } END { print s + 0 }'; }
echo "TOTAL: $(sum 2) passed, $(sum 4) failed"

if [ "$status" -eq 0 ]; then echo "ALL PASSED"; else echo "SOME FAILED"; fi
exit "$status"
