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

echo ""
echo "tests: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
  echo "ALL TESTS PASSED"
  exit 0
else
  echo "TESTS FAILED"
  exit 1
fi
