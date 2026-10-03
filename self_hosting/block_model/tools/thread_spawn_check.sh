#!/bin/sh
# Issue #184: builds the thread_spawn-from-block-model-source fixture as a
# real native executable with the self-hosted compiler (./patc1.exe --x64)
# and runs it repeatedly. Races are probabilistic (same reasoning as
# thread_safety_check.sh, issue #176), so a single passing run proves
# little; requires every run to print exactly "42" then "ok".
set -u
cd "$(dirname "$0")/../../.." || exit 1
RUNS="${RUNS:-5}"
SRC=self_hosting/block_model/spec_fixtures/thread_spawn_native.patlang
OUT=self_hosting/build/thread_spawn_native.exe
PASS=0
FAIL=0
rm -f "$OUT"
BUILD=$(./patc1.exe "$SRC" "$OUT" --x64 2>&1)
if [ ! -f "$OUT" ]; then
  echo "  FAIL: the thread_spawn fixture did not build: $BUILD"
  echo ""
  echo "tests: 0 passed, 1 failed"
  echo "TESTS FAILED"
  exit 1
fi
echo "Scenario: thread_spawn/thread_poll/thread_result from block-model source compute the right value and exit cleanly (issue #184)"
i=1
while [ "$i" -le "$RUNS" ]; do
  RESULT=$(timeout 30 "./$OUT" 2>&1 | tr -s '\r\n\t ' ' ')
  if [ "$RESULT" = "42 ok " ] || [ "$RESULT" = "42 ok" ]; then
    echo "  ok: run $i printed 42 then ok"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: run $i printed \"$RESULT\" (want \"42 ok\")"
    FAIL=$((FAIL + 1))
  fi
  i=$((i + 1))
done
echo ""
echo "tests: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
  echo "ALL TESTS PASSED"
  exit 0
else
  echo "TESTS FAILED"
  exit 1
fi
