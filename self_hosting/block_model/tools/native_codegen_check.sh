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
check "names the failing require, the real engine's own wording" "$(cat /tmp/phase19_contract_fail.out)" "precondition failed in start(): 1 > 2"
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

echo "Scenario: BuildList/generic-CallHost (Phase 18's new opcodes) compile through real native codegen as direct passthroughs (Phase 19)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_buildlist.patlang phase18_buildlist 2>&1)
check "list_len(xs) on a real List literal prints 3" "$OUT" "3"
check "indexing xs[1] prints 20" "$OUT" "20"

# Issue #173: Call / ReturnValue / CallDynamic. check_seq is stricter than
# check: it normalizes all whitespace/newlines to single spaces and requires
# the expected values to appear as ONE ADJACENT SEQUENCE, so both the values
# and their ORDER are verified (a substring check would let "1 2" pass "2 1").
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

echo "Scenario: a declared function called as a value, including recursion, runs through real native codegen (issue #173)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_call_value.patlang issue173_call_value 2>&1)
check_seq "double(5) + 1 prints 11, then fact_r(5) prints 120" "$OUT" "11 120"

echo "Scenario: a callee's final globals come back through the native Call and become the caller's (issue #173)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_call_globals.patlang issue173_call_globals 2>&1)
check_seq "the returned value 101 then the caller's own counter 42 (40 + 2 from inside the callee)" "$OUT" "101 42"

echo "Scenario: a callee whose return runs in a synthesized loop-exit block returns that block's own state (issue #173)"
OUT=$(timeout 60 bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_call_loop.patlang issue173_call_loop 2>&1)
check_seq "sum_to(5) prints 10, then the caller continues and prints 99" "$OUT" "10 99"

echo "Scenario: apply() with a runtime name and arguments dispatches natively (issue #173)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_call_dynamic.patlang issue173_call_dynamic 2>&1)
check_seq "apply add2 returns 7, the bare-statement apply prints 10 20, the zero-argument apply returns 0" "$OUT" "7 10 20 0"

echo "Scenario: closures dispatch natively, capturing, returning, passing and nesting exactly as the interpreter does (issue #183)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/closures_basic_reference.patlang issue183_closures_basic 2>&1)
check_seq "captured local 15, returned closure 7, passed closure 21, snapshot 100, closure calling closure 7" "$OUT" "15 7 21 100 7"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/closures_in_loops_reference.patlang issue183_closures_in_loops 2>&1)
check_seq "the loop with a closure created and a closure held in a local totals 309" "$OUT" "309"

echo "Scenario: a function defined twice by a diamond include builds natively with the first definition winning (issue #180)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_duplicate_decls.patlang issue180_dup 2>&1)
check_seq "count_to(10) returns 3 from inside the loop, count_to(2) runs the loop out and returns 2" "$OUT" "3 2"

echo "Scenario: a function that tail-calls one declared earlier starts in its own body (issue #180)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_tail_call_order.patlang issue180_tail 2>&1)
check_seq "app prints [A], tailapp prints [B] and [x, C] instead of garbage" "$OUT" "[A] [B] [x, C]"

echo "Scenario: two sequential top-level while loops both run to completion and the program ends (issue #180)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_sequential_loops.patlang issue180_seq 2>&1)
check_seq "0 1 2 (first loop), 100 101 102 (second loop), done -- not an infinite repeat of the second loop" "$OUT" "0 1 2 100 101 102 done"

echo "Scenario: bitwise Bin operators compile natively (issue #180)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_bitwise_ops.patlang issue180_bitwise 2>&1)
check_seq "band=8, bor=14, bxor=6, shl=48, shr=6" "$OUT" "8 14 6 48 6"

echo "Scenario: a function that never touches globals, directly or transitively, skips the globals wrapper entirely (issue #215)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_call_pure.patlang issue215_pure 2>&1)
check_seq "double(3)+2=8, fact_r(5)=120, relay(1)=142, counter=41" "$OUT" "8 120 142 41"
# Baseline (unoptimized): 23 total `call rt_list_get` -- 3 pure call
# sites (double x1, fact_r x2: direct + self-recursive) each unpacking
# [value, globals] via 2 calls (6 total), plus 17 from genuinely impure
# call sites (relay, bumper) and GlobalGet/GlobalSet's OWN unrelated
# internal use of rt_list_get to walk the globals assoc-list. A function
# that never touches __globals, directly or transitively (checked via
# bm_nc_compute_pure_fns over the real call graph), must skip the
# wrapper at BOTH ends of its own call sites -- exactly 6 fewer calls
# (the 3 pure call sites' own pairs), never the ones belonging to
# GlobalGet/GlobalSet or to the genuinely impure relay/bumper.
TOTAL_UNPACK=$(grep -c "call rt_list_get" self_hosting/build/issue215_pure.asm)
if [ "$TOTAL_UNPACK" -eq 17 ]; then
  echo "  ok: rt_list_get calls dropped from 23 to 17 -- exactly the 3 pure call sites' own pairs removed, nothing else"
  PASS=$((PASS + 1))
else
  echo "  FAIL: expected exactly 17 rt_list_get calls after the purity fix (double/fact_r's own 6 removed from the 23 baseline), found $TOTAL_UNPACK"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: a single-block pure function's entry seed is dropped too, not just its external calling convention (issue #216, follow-up to #215)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_call_pure_no_leak.patlang issue216_no_leak 2>&1)
check_seq "2000 calls to a single-block pure function cause exactly zero heap growth" "$OUT" "total= 2000 growth= 0"

echo "Scenario: bm_heap_init runs before main's own entry seed, so the free-list table genuinely lands first (general-refcounting.md Phase 1)"
OUT=$(bash self_hosting/block_model/tools/build_and_run_native.sh self_hosting/block_model/spec_fixtures/native_box_heap_init_order.patlang native_box_heap_init_order 2>&1)
check_seq "the free-list table's own magic marker is set at the heap's base address" "$OUT" "fixed_ready=true value=42"

echo "Scenario: box_new/box_get/box_set now work through the ordinary --x64 CLI, not just block-model's own test tooling (general-refcounting.md Phase 1)"
rm -f self_hosting/build/native_box_ordinary_cli.exe
BUILD_OUT=$(./patc1.exe self_hosting/block_model/spec_fixtures/native_box_ordinary_cli.patlang self_hosting/build/native_box_ordinary_cli.exe --x64 2>&1)
if [ -f self_hosting/build/native_box_ordinary_cli.exe ]; then
  OUT=$(./self_hosting/build/native_box_ordinary_cli.exe 2>&1)
  check_seq "200000 box_set/box_get cycles through the ordinary CLI give the right answer" "$OUT" "final=200000"
else
  echo "  FAIL: box_new via the ordinary --x64 CLI did not build: $BUILD_OUT"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: a string built via a known producer, stored once and never returned, in a branch-free function, gets its refcount decremented and genuinely reclaimed (general-refcounting.md Phase 2, first increment)"
rm -f self_hosting/build/native_string_rc_dec_no_leak.exe
BUILD_OUT=$(./patc1.exe self_hosting/block_model/spec_fixtures/native_string_rc_dec_no_leak.patlang self_hosting/build/native_string_rc_dec_no_leak.exe --x64 2>&1)
if [ -f self_hosting/build/native_string_rc_dec_no_leak.exe ]; then
  OUT=$(./self_hosting/build/native_string_rc_dec_no_leak.exe 2>&1)
  check_seq "50000 build-and-discard cycles after warm-up cause exactly zero heap growth" "$OUT" "total= 0 growth= 0"
else
  echo "  FAIL: the string-rc-dec fixture did not build: $BUILD_OUT"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: a merging if/else (no early return) still has exactly one reachable terminal, so its own eligible local gets decremented too (general-refcounting.md Phase 2, second increment)"
rm -f self_hosting/build/native_string_rc_dec_merging_if.exe
BUILD_OUT=$(./patc1.exe self_hosting/block_model/spec_fixtures/native_string_rc_dec_merging_if.patlang self_hosting/build/native_string_rc_dec_merging_if.exe --x64 2>&1)
if [ -f self_hosting/build/native_string_rc_dec_merging_if.exe ]; then
  OUT=$(./self_hosting/build/native_string_rc_dec_merging_if.exe 2>&1)
  check_seq "50000 cycles through a merging if/else (both branches exercised) cause exactly zero heap growth" "$OUT" "total= 0 growth= 0"
else
  echo "  FAIL: the merging-if fixture did not build: $BUILD_OUT"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: a genuine early return still gets a decrement at every terminal it dominates (general-refcounting.md Phase 2, third increment)"
rm -f self_hosting/build/native_string_rc_dec_early_return.exe
BUILD_OUT=$(./patc1.exe self_hosting/block_model/spec_fixtures/native_string_rc_dec_early_return.patlang self_hosting/build/native_string_rc_dec_early_return.exe --x64 2>&1)
if [ -f self_hosting/build/native_string_rc_dec_early_return.exe ]; then
  OUT=$(./self_hosting/build/native_string_rc_dec_early_return.exe 2>&1)
  check_seq "50000 cycles through a genuine early return (alternating which branch runs) cause exactly zero heap growth" "$OUT" "total= 0 growth= 0"
else
  echo "  FAIL: the early-return fixture did not build: $BUILD_OUT"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: a local returned at one terminal and discarded at another, in the same function, is handled correctly at each (general-refcounting.md Phase 2, third increment)"
rm -f self_hosting/build/native_string_rc_dec_mixed_exit.exe
BUILD_OUT=$(./patc1.exe self_hosting/block_model/spec_fixtures/native_string_rc_dec_mixed_exit.patlang self_hosting/build/native_string_rc_dec_mixed_exit.exe --x64 2>&1)
if [ -f self_hosting/build/native_string_rc_dec_mixed_exit.exe ]; then
  OUT=$(./self_hosting/build/native_string_rc_dec_mixed_exit.exe 2>&1)
  check_seq "50 cycles alternating 'return the string' and 'discard it' match pat --ir-run exactly, reusing the same freed block repeatedly with no corruption" "$OUT" "65 B 67 D 69 F 71 H 73 J 65 B 67 D 69 F 71 H 73 J 65 B 67 D 69 F 71 H 73 J 65 B 67 D 69 F 71 H 73 J 65 B 67 D 69 F 71 H 73 J"
else
  echo "  FAIL: the mixed-exit fixture did not build: $BUILD_OUT"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: main's own top-level code gets the same string-decrement pass as ordinary callee functions (general-refcounting.md Phase 2, fourth increment)"
rm -f self_hosting/build/native_string_rc_dec_main_toplevel.exe
BUILD_OUT=$(./patc1.exe self_hosting/block_model/spec_fixtures/native_string_rc_dec_main_toplevel.patlang self_hosting/build/native_string_rc_dec_main_toplevel.exe --x64 2>&1)
if [ -f self_hosting/build/native_string_rc_dec_main_toplevel.exe ]; then
  OUT=$(./self_hosting/build/native_string_rc_dec_main_toplevel.exe 2>&1)
  check_seq "main's own top-level string-build-and-discard statements match pat --ir-run exactly" "$OUT" "A B C"
else
  echo "  FAIL: the main-toplevel fixture did not build: $BUILD_OUT"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: a local passed as an argument to another call, well before its own decrement, is still handled correctly (general-refcounting.md Phase 2, verified not just assumed)"
rm -f self_hosting/build/native_string_rc_dec_call_arg.exe
BUILD_OUT=$(./patc1.exe self_hosting/block_model/spec_fixtures/native_string_rc_dec_call_arg.patlang self_hosting/build/native_string_rc_dec_call_arg.exe --x64 2>&1)
if [ -f self_hosting/build/native_string_rc_dec_call_arg.exe ]; then
  OUT=$(./self_hosting/build/native_string_rc_dec_call_arg.exe 2>&1)
  check_seq "20 cycles passing the string to print() as an argument, both the output sequence and zero heap growth" "$OUT" "A A B C D E F G H I J A B C D E F G H I J growth= 0"
else
  echo "  FAIL: the call-arg fixture did not build: $BUILD_OUT"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: a string built and discarded inside a real while loop is decremented at the loop's own back-edge but not its exit (general-refcounting.md Phase 2, loop increment)"
rm -f self_hosting/build/native_string_rc_dec_loop.exe
BUILD_OUT=$(./patc1.exe self_hosting/block_model/spec_fixtures/native_string_rc_dec_loop.patlang self_hosting/build/native_string_rc_dec_loop.exe --x64 2>&1)
if [ -f self_hosting/build/native_string_rc_dec_loop.exe ]; then
  OUT=$(./self_hosting/build/native_string_rc_dec_loop.exe 2>&1)
  check_seq "50000 real while-loop iterations, each building and discarding a string, cause exactly zero heap growth" "$OUT" "result= 50000 growth= 0"
else
  echo "  FAIL: the loop fixture did not build: $BUILD_OUT"
  FAIL=$((FAIL + 1))
fi

echo "Scenario: a string created only on the fall-through side of an earlier, unrelated branch's own early return is decremented at the terminal it dominates (general-refcounting.md Phase 2, single-block dominance retrofit)"
rm -f self_hosting/build/native_string_rc_dec_branch_local.exe
BUILD_OUT=$(./patc1.exe self_hosting/block_model/spec_fixtures/native_string_rc_dec_branch_local.patlang self_hosting/build/native_string_rc_dec_branch_local.exe --x64 2>&1)
if [ -f self_hosting/build/native_string_rc_dec_branch_local.exe ]; then
  OUT=$(./self_hosting/build/native_string_rc_dec_branch_local.exe 2>&1)
  check_seq "50000 cycles alternating early-return and fall-through (string created only on the fall-through side) cause exactly zero heap growth" "$OUT" "total= 0 growth= 0"
else
  echo "  FAIL: the branch-local fixture did not build: $BUILD_OUT"
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
