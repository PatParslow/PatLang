#!/usr/bin/env bash
# v2's gates, run on the native v2 compiler and the v2 interpreter.
#
#   self_hosting/v2/tools/gates.sh
#
# pat --ir-run is used once, to build the first self_hosting/build/v2.exe
# when there is none, until the IR reader (GitHub #247) takes its place.
# The language and match suites run their programs on these two engines;
# the block-model suite's steps still start pat (GitHub #246).
#
# Each step's result goes to self_hosting/build/v2_gates/status as it
# finishes, and its output to a log beside it.
cd "$(dirname "$0")/../../.." || exit 1
B=self_hosting/build
D=$B/v2_gates
mkdir -p "$D"
ST=$D/status
: > "$ST"
st() { echo "$(date +%H:%M:%S) $*" >> "$ST"; }
tests() { tr -d '\000' < "$1" | grep -a '^tests:'; }

# The compiler. v2.exe builds a, a builds b; a and b must be byte identical,
# and b becomes v2.exe.
if [ ! -f $B/v2.exe ]; then
  PATLANG_MAX_MEM_MB=16000 rust-runtime/target/release/pat.exe --ir-run self_hosting/v2/compile.patlang \
    self_hosting/v2/compile.patlang $B/v2.exe --workers 8 > "$D/boot.log" 2>&1
  st "first compiler, on pat: exit $?"
fi
$B/v2.exe self_hosting/v2/compile.patlang $B/v2_gen_a.exe --no-cache --workers 8 > "$D/gen_a.log" 2>&1
st "compiler a: exit $?"
$B/v2_gen_a.exe self_hosting/v2/compile.patlang $B/v2_gen_b.exe --no-cache --workers 8 > "$D/gen_b.log" 2>&1
st "compiler b: exit $?"
if cmp -s $B/v2_gen_a.exe $B/v2_gen_b.exe; then
  st "fixpoint: a and b byte identical"
  cp $B/v2_gen_b.exe $B/v2.exe
else
  st "fixpoint: a and b differ"
  st "stopped"
  exit 1
fi

# The interpreter, built by that compiler.
$B/v2.exe self_hosting/v2/interp.patlang $B/v2_interp.exe --workers 8 > "$D/interp.log" 2>&1
st "interpreter: exit $?"

I=$B/v2_interp.exe
run() {
  local name=$1; shift
  "$@" > "$D/$name.log" 2>&1
  st "$name: exit $? $(tests "$D/$name.log")"
}
run part1_v2 $I self_hosting/v2/spec/run_values_and_memory.patlang v2
run part1_interp $I self_hosting/v2/spec/run_values_and_memory.patlang interp
run engines_agree $I self_hosting/v2/spec/run_values_and_memory.patlang both
run part2 $I self_hosting/v2/spec/run_runtime.patlang
run language_interp $I self_hosting/tools/run_language_spec_suite.patlang
run match_interp $I self_hosting/tools/run_match_spec_suite.patlang
$B/v2.exe self_hosting/tools/run_language_spec_suite.patlang $B/v2_language_suite.exe --workers 8 > "$D/language_build.log" 2>&1
st "language suite build: exit $?"
run language_v2 $B/v2_language_suite.exe
run block_model_interp $I self_hosting/block_model/run_block_model_spec_suite.patlang
st "all done"
