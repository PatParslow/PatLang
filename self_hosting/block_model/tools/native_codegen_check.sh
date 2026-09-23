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

echo "Scenario: fact/query/type_of/read_file/write_file compile through real native codegen (Phase 19)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_misc_calls.patlang phase19_misc 2>&1)
check "query finds the just-asserted fact (1 match)" "$OUT" "1"
check "type_of(42) reports int" "$OUT" "int"
check "read_file reads back exactly what write_file wrote" "$OUT" "native round trip"

echo "Scenario: a failing require aborts through real native codegen, exiting with a nonzero code (Phase 19)"
bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_contract_fail.patlang phase19_contract_fail >/tmp/phase19_contract_fail.out 2>&1
CONTRACT_CODE=$?
check "names the failing require, matching the interpreter's own message" "$(cat /tmp/phase19_contract_fail.out)" "require failed: 1 > 2"
if [ "$CONTRACT_CODE" -ne 0 ]; then
  echo "  ok: exits with a nonzero code (contract violation), not a silent success"
  PASS=$((PASS + 1))
else
  echo "  FAIL: exited 0 despite a failing require (expected nonzero)"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: Global*/Handler* compile through real native codegen, as hand-emitted assoc-list loops (Phase 19)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_globals.patlang phase19_globals 2>&1)
check "a global set in one block, read back two jumps later, prints 42" "$OUT" "42"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_handler.patlang phase19_handler 2>&1)
check "\"alice\" resolves to 111" "$OUT" "111"
check "\"bob\" resolves to 222" "$OUT" "222"

echo "Scenario: Box* compiles through real native codegen, linked against a THIRD heap_chunk.obj chunk (Phase 19)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_box_ops.patlang phase19_box 2>&1)
check "a straight-line box_set chain (patched to BoxSetUnchecked) ends at 30" "$OUT" "30"
check "box_set after box_share clones instead of mutating in place: the mutated box reads 999" "$OUT" "999"
check "...and the box shared BEFORE the mutation still reads the ORIGINAL 100, proving real COW" "$OUT" "100"

echo "Scenario: Emit compiles through real native codegen, each handler as its own separate FuncIR (Phase 19)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_emit.patlang phase19_emit 2>&1)
check "two handlers registered for the same event both fire, first one (100)" "$OUT" "100"
check "...and the second, in declaration order (200)" "$OUT" "200"
check "a handler's own set_global is visible in the emitting block right after emit() returns (41+1)" "$OUT" "42"
check "emit() genuinely returns control: the statement after it still runs" "$OUT" "2"
check "...and the function emit() was called from still returns to ITS OWN caller afterward" "$OUT" "3"
if [ "$(echo "$OUT" | grep -n '^100$')" ] && [ "$(echo "$OUT" | grep -n '^200$')" ]; then
  L100=$(echo "$OUT" | grep -n '^100$' | head -1 | cut -d: -f1)
  L200=$(echo "$OUT" | grep -n '^200$' | head -1 | cut -d: -f1)
  if [ "$L100" -lt "$L200" ]; then
    echo "  ok: 100 prints before 200 (real declaration order, not coincidental)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: 200 printed before 100 (wrong handler order)"
    FAIL=$((FAIL + 1))
  fi
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
