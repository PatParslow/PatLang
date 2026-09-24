#!/bin/sh
# Verifies spec_library/block_model/wasm_codegen.feature's own scenarios
# against real WASM binaries built via self_hosting/block_model/bench/
# build_wasm_check.patlang (emit_program_rs -> rustc --target
# wasm32-wasip1) and run via wasmtime -- kept standalone, like Phase 1's
# and Phase 9's own native checks, rather than wired into
# run_block_model_spec_suite.patlang's interpreter-based suite.
set -u
cd "$(dirname "$0")/../../.." || exit 1
PAT="rust-runtime/target/release/pat.exe"
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

echo "Scenario: a loop-free, two-block program compiles to WASM and runs correctly"
"$PAT" --ir-run self_hosting/block_model/bench/build_wasm_check.patlang self_hosting/block_model/spec_fixtures/native_two_block.patlang self_hosting/build/wasm_two_block.wasm >/dev/null 2>&1
OUT=$(wasmtime run self_hosting/build/wasm_two_block.wasm 2>&1)
check "combine(10, 20) prints 30" "$OUT" "30"

echo "Scenario: a loop also runs correctly and terminates under WASM"
"$PAT" --ir-run self_hosting/block_model/bench/build_wasm_check.patlang self_hosting/block_model/spec_fixtures/native_tiny_loop.patlang self_hosting/build/wasm_tiny_loop.wasm >/dev/null 2>&1
OUT=$(timeout 15 wasmtime run self_hosting/build/wasm_tiny_loop.wasm 2>&1)
CODE=$?
check "sum(0..2) prints 3" "$OUT" "3"
if [ "$CODE" -eq 0 ]; then
  echo "  ok: process exited cleanly (not killed by the 15s hang-guard)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: process did not exit cleanly (exit $CODE -- possibly still hanging)"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: the same large-scale benchmark loop matches every other execution path under WASM too"
"$PAT" --ir-run self_hosting/block_model/bench/build_wasm_check.patlang self_hosting/block_model/bench/new_sum_loop_800000.patlang self_hosting/build/wasm_bench.wasm >/dev/null 2>&1
OUT=$(timeout 30 wasmtime run self_hosting/build/wasm_bench.wasm 2>&1)
check "N=800000 sum matches every other execution path (319999600000)" "$OUT" "319999600000"

# Issues #174/#181. check_seq requires the expected values as ONE ADJACENT
# SEQUENCE (whitespace normalized), so values AND their order are verified.
# wasm_build removes any previous output first: a stale .wasm from an earlier
# run once made a FAILED build look like a passing run of the old binary.
check_seq() {
  label="$1"
  actual=$(echo "$2" | tr -s '\r\n\t ' ' ')
  expected="$3"
  case "$actual" in
    *"$expected"*)
      echo "  ok: $label"
      PASS=$((PASS + 1))
      ;;
    *)
      echo "  FAIL: $label (want the sequence \"$expected\" in: $actual)"
      FAIL=$((FAIL + 1))
      ;;
  esac
}
wasm_build() {
  rm -f "self_hosting/build/$2.wasm"
  "$PAT" --ir-run self_hosting/block_model/bench/build_wasm_check.patlang "self_hosting/block_model/spec_fixtures/$1.patlang" "self_hosting/build/$2.wasm" 2>&1
}

echo "Scenario: Global*/Handler* run under WASM, their assoc-list walks retargeted to host list operations (issue #174)"
wasm_build native_globals wasm174_globals >/dev/null
check_seq "a global set in one block is read three blocks later: 42" "$(timeout 30 wasmtime run self_hosting/build/wasm174_globals.wasm 2>&1)" "42"
wasm_build native_handler wasm174_handler >/dev/null
check_seq "two handler names resolve to their own values: 111 then 222" "$(timeout 30 wasmtime run self_hosting/build/wasm174_handler.wasm 2>&1)" "111 222"

echo "Scenario: Emit's event dispatch runs under WASM (issue #174)"
wasm_build native_emit wasm174_emit >/dev/null
check_seq "both handlers fire in declaration order, the emitter sees the handler's global, control returns: 100 200 42 2 3" "$(timeout 30 wasmtime run self_hosting/build/wasm174_emit.wasm 2>&1)" "100 200 42 2 3"

echo "Scenario: call-with-return, including apply(), runs under WASM (issues #173, #174)"
wasm_build native_call_value wasm174_call_value >/dev/null
check_seq "double(5) + 1 then a recursive factorial: 11 120" "$(timeout 30 wasmtime run self_hosting/build/wasm174_call_value.wasm 2>&1)" "11 120"
wasm_build native_call_globals wasm174_call_globals >/dev/null
check_seq "a callee's globals come back to the caller: 101 42" "$(timeout 30 wasmtime run self_hosting/build/wasm174_call_globals.wasm 2>&1)" "101 42"
wasm_build native_call_loop wasm174_call_loop >/dev/null
check_seq "a callee returning from a loop-exit block: 10 99" "$(timeout 30 wasmtime run self_hosting/build/wasm174_call_loop.wasm 2>&1)" "10 99"
wasm_build native_call_dynamic wasm174_call_dynamic >/dev/null
check_seq "apply with a runtime name and arguments: 7 10 20 0" "$(timeout 30 wasmtime run self_hosting/build/wasm174_call_dynamic.wasm 2>&1)" "7 10 20 0"

echo "Scenario: closures run under WASM through the same runtime dispatch (issue #183)"
wasm_build closures_basic_reference wasm183_closures_basic >/dev/null
check_seq "captured local 15, returned closure 7, passed closure 21, snapshot 100, closure calling closure 7" "$(timeout 30 wasmtime run self_hosting/build/wasm183_closures_basic.wasm 2>&1)" "15 7 21 100 7"
wasm_build closures_in_loops_reference wasm183_closures_in_loops >/dev/null
check_seq "a closure created and a closure held in a local inside a loop totals 309" "$(timeout 30 wasmtime run self_hosting/build/wasm183_closures_in_loops.wasm 2>&1)" "309"

echo "Scenario: fact/query/type_of/read_file/write_file run under WASM (issue #174)"
wasm_build native_misc_calls wasm174_misc >/dev/null
# --dir=. grants WASI the directory write_file needs; without it the SANDBOX,
# not the translation, refuses the write.
check_seq "query finds the fact, type_of reports int, read_file reads back what write_file wrote: 1 int native round trip" "$(timeout 30 wasmtime run --dir=. self_hosting/build/wasm174_misc.wasm 2>&1)" "1 int native round trip"

echo "Scenario: Box and FiberYield are native-only BY DESIGN and fail at BUILD time under WASM, naming why (issues #174, #181)"
OUT=$(wasm_build native_box_ops wasm174_box)
check "a Box program is rejected while translating, naming the native heap" "$OUT" "Box instructions need the native refcounted heap"
if [ -f self_hosting/build/wasm174_box.wasm ]; then
  echo "  FAIL: a .wasm was produced for a Box program"
  FAIL=$((FAIL + 1))
else
  echo "  ok: no .wasm is produced for a Box program (it does not fail later, at startup or mid-run)"
  PASS=$((PASS + 1))
fi
OUT=$(wasm_build native_fiber_yield wasm174_fiber)
check "a FiberYield program is rejected while translating, naming the x64 runtime's stack switching" "$OUT" "fibers need the x64 runtime"

echo "Scenario: budgeted blocks are fiber-backed and fail at BUILD time under WASM, naming why (issue #176)"
OUT=$(wasm_build budgeted_basic_reference wasm176_budgeted)
check "a budgeted program is rejected while translating, naming the missing fiber host functions" "$OUT" "the Rust-source backend has no fiber host functions"
if [ -f self_hosting/build/wasm176_budgeted.wasm ]; then
  echo "  FAIL: a .wasm was produced for a budgeted program"
  FAIL=$((FAIL + 1))
else
  echo "  ok: no .wasm is produced for a budgeted program"
  PASS=$((PASS + 1))
fi

echo "Scenario: parallel_map fails at BUILD time under WASM, naming why (issue #176)"
OUT=$(wasm_build parallel_map_reference wasm176_pmap)
check "a parallel_map program is rejected while translating, naming the by-name worker lookup" "$OUT" "looked up by name among the Rust-source program's own functions"
if [ -f self_hosting/build/wasm176_pmap.wasm ]; then
  echo "  FAIL: a .wasm was produced for a parallel_map program"
  FAIL=$((FAIL + 1))
else
  echo "  ok: no .wasm is produced for a parallel_map program"
  PASS=$((PASS + 1))
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
