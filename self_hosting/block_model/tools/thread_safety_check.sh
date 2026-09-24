#!/bin/sh
# Issue #176 (thread-safety half): builds the threaded heap fixture as a real
# native executable with the self-hosted compiler (./patc1.exe --x64) and runs
# it repeatedly. Races are probabilistic, so a single passing run proves little;
# the check runs it RUNS times and requires every run to print exactly
# "1" (the shared block's count) then "0" (wrong read-backs).
set -u
cd "$(dirname "$0")/../../.." || exit 1
RUNS="${RUNS:-5}"
SRC=self_hosting/block_model/spec_fixtures/thread_safety_heap.patlang
OUT=self_hosting/build/thread_safety_heap.exe
PASS=0
FAIL=0
rm -f "$OUT"
BUILD=$(./patc1.exe "$SRC" "$OUT" --x64 2>&1)
if [ ! -f "$OUT" ]; then
  echo "  FAIL: the threaded heap fixture did not build: $BUILD"
  echo ""
  echo "tests: 0 passed, 1 failed"
  echo "TESTS FAILED"
  exit 1
fi
echo "Scenario: real threads hammering the refcounted heap keep every count and every block intact (issue #176)"
i=1
while [ "$i" -le "$RUNS" ]; do
  RESULT=$(timeout 120 "./$OUT" 2>&1 | tr -s '\r\n\t ' ' ')
  if [ "$RESULT" = "1 0 " ] || [ "$RESULT" = "1 0" ]; then
    echo "  ok: run $i printed the shared count 1 and 0 wrong read-backs"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: run $i printed \"$RESULT\" (want \"1 0\")"
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
