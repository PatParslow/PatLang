#!/bin/sh
# Issue #198: builds the g_vars_table thread-safety fixture as a real
# native executable with the self-hosted compiler (./patc1.exe --x64) and
# runs it repeatedly. Races are probabilistic (same reasoning as #176's
# thread_safety_check.sh), so a single passing run proves little; requires
# every run to print exactly "1".
set -u
cd "$(dirname "$0")/../../.." || exit 1
RUNS="${RUNS:-5}"
SRC=self_hosting/block_model/spec_fixtures/thread_safety_vars_table.patlang
OUT=self_hosting/build/thread_safety_vars_table.exe
PASS=0
FAIL=0
rm -f "$OUT"
BUILD=$(./patc1.exe "$SRC" "$OUT" --x64 2>&1)
if [ ! -f "$OUT" ]; then
  echo "  FAIL: the g_vars_table thread-safety fixture did not build: $BUILD"
  echo ""
  echo "tests: 0 passed, 1 failed"
  echo "TESTS FAILED"
  exit 1
fi
echo "Scenario: 8 real threads each hammering their own key in the shared vars table leave every read-back correct (issue #198)"
i=1
while [ "$i" -le "$RUNS" ]; do
  RESULT=$(timeout 60 "./$OUT" 2>&1 | tr -s '\r\n\t ' ' ')
  if [ "$RESULT" = "1 " ] || [ "$RESULT" = "1" ]; then
    echo "  ok: run $i printed 1 (every thread's every read-back matched)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: run $i printed \"$RESULT\" (want \"1\")"
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
