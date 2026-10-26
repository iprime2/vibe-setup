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
for f in "${files[@]}"; do
  echo "######## $(basename "$f")"
  bash "$f" || status=1
done

if [ "$status" -eq 0 ]; then echo "ALL PASSED"; else echo "SOME FAILED"; fi
exit "$status"
