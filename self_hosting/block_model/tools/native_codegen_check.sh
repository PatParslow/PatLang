#!/bin/sh
# Verifies spec_library/block_model/native_codegen.feature's own
# scenarios against real, native-compiled executables (no bi_run, no
# interpretation at all) -- kept as a standalone check, like Phase 1's
# own refcounted_heap_native_check.sh, rather than wired into
# run_block_model_spec_suite.patlang's interpreter-based suite: this
# whole phase's point is proving something the interpreter-based suite
# structurally cannot exercise.
set -u
cd "$(dirname "$0")/../../.." || exit 1
PASS=0
FAIL=0

check() {
  label="$1"
  actual="$2"
  expected="$3"
  if echo "$actual" | grep -qF "$expected"; then
    echo "  ok: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (want \"$expected\" in: $actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo "Scenario: a loop-free, two-block program runs correctly through real native codegen"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_two_block.patlang phase9_two_block 2>&1)
check "combine(10, 20) prints 30" "$OUT" "30"

echo "Scenario: a small loop runs correctly and terminates"
OUT=$(timeout 10 bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_tiny_loop.patlang phase9_tiny_loop 2>&1)
CODE=$?
check "sum(0..2) prints 3" "$OUT" "3"
if [ "$CODE" -eq 0 ]; then
  echo "  ok: process exited cleanly (not killed by the 10s hang-guard)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: process did not exit cleanly (exit $CODE -- possibly still hanging)"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: the same loop shape at a much larger scale still matches the interpreted result"
OUT=$(timeout 30 bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/bench/new_sum_loop_800000.patlang phase9_bench 2>&1)
check "N=800000 sum matches every other execution path (319999600000)" "$OUT" "319999600000"

echo "Scenario: block-to-block control flow compiles to real jumps, never calls"
# self_hosting/build/phase9_tiny_loop.asm was just produced above. The
# actual claim is narrower than "no call instructions at all" -- ordinary
# calls to runtime helpers (rt_bigint_add, print, ...) for computation
# WITHIN a block's own body are expected and fine; what must never exist
# is a `call` whose OWN TARGET is one of this program's own internal
# block labels (L_main_N), which would mean a real call/return between
# blocks -- exactly what Fork A's "no call stack" claim rules out.
INTERNAL_CALLS=$(grep -c "    call L_main" self_hosting/build/phase9_tiny_loop.asm)
if [ "$INTERNAL_CALLS" -eq 0 ]; then
  echo "  ok: no call targets another block's own label (only jmp is used between blocks)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: found $INTERNAL_CALLS call(s) targeting an internal block label (expected 0)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "tests: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
  echo "ALL TESTS PASSED"
  exit 0
else
  echo "TESTS FAILED"
  exit 1
fi
