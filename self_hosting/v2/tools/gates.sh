#!/usr/bin/env bash
# v2's gates, run on the native v2 compiler and the v2 interpreter.
#
#   self_hosting/v2/tools/gates.sh
#
# When there is no self_hosting/build/v2.exe, the first is built from the
# compiler's IR, bootstrap/v2_compiler.ir, by the IR reader
# (bootstrap/ir_reader.py, docs/spec/ir.md), which needs only Python. The
# language, match and block-model suites run their programs on these two
# engines; no gate starts pat.
#
# Each step's result goes to self_hosting/build/v2_gates/status as it
# finishes, and its output to a log beside it. The previous run's files move
# to v2_gates/previous first, so everything in v2_gates is from this run.
cd "$(dirname "$0")/../../.." || exit 1
B=self_hosting/build
D=$B/v2_gates
rm -rf "$D/previous"
mkdir -p "$D/previous"
find "$D" -maxdepth 1 -type f -exec mv {} "$D/previous/" \;
ST=$D/status
: > "$ST"
st() { echo "$(date +%H:%M:%S) $*" >> "$ST"; }
tests() { tr -d '\000' < "$1" | grep -a '^tests:'; }

# The compiler. v2.exe builds a, a builds b; a and b must be byte identical,
# and b becomes v2.exe, with the key written beside it.
if [ ! -f $B/v2.exe ]; then
  py -3 -I bootstrap/ir_reader.py bootstrap/v2_compiler.ir $B/v2.exe > "$D/boot.log" 2>&1
  st "first compiler, from the IR: exit $?"
fi
$B/v2.exe self_hosting/v2/compile.patlang $B/v2_gen_a.exe --no-cache --workers 8 > "$D/gen_a.log" 2>&1
st "compiler a: exit $?"
$B/v2_gen_a.exe self_hosting/v2/compile.patlang $B/v2_gen_b.exe --no-cache --workers 8 > "$D/gen_b.log" 2>&1
st "compiler b: exit $?"
if cmp -s $B/v2_gen_a.exe $B/v2_gen_b.exe; then
  st "fixpoint: a and b byte identical"
  cp $B/v2_gen_b.exe $B/v2.exe
  # its cache key, the hash of the sources it was built from (#254)
  cp $B/v2_gen_b.exe.key $B/v2.exe.key
else
  st "fixpoint: a and b differ"
  st "stopped"
  exit 1
fi

# The bootstrap (spec 2.6): the compiler's IR, written again, and the
# compiler the reader builds from it, which must build the compiler byte for
# byte as v2.exe does. v2.exe builds itself unchanged, so the chain from the
# reader is a fixpoint too.
$B/v2.exe self_hosting/v2/compile.patlang bootstrap/v2_compiler.ir --ir > "$D/ir.log" 2>&1
st "compiler IR: exit $?"
py -3 -I bootstrap/ir_reader.py bootstrap/v2_compiler.ir $B/v2_read.exe >> "$D/ir.log" 2>&1
st "reader: exit $?"
$B/v2_read.exe self_hosting/v2/compile.patlang $B/v2_read_a.exe --no-cache --workers 8 > "$D/read_a.log" 2>&1
st "reader's compiler builds the compiler: exit $?"
if cmp -s $B/v2_read_a.exe $B/v2.exe; then
  st "bootstrap: identical to v2.exe"
else
  st "bootstrap: differs from v2.exe"
fi

# The WASM form (spec 2.6): the compiler as a WebAssembly module, written by
# v2.exe and by bootstrap/ir_wasm.py from the same IR, must be the same bytes.
$B/v2.exe self_hosting/v2/compile.patlang $B/v2_compiler.wasm --wasm > "$D/wasm.log" 2>&1
st "compiler as WASM: exit $?"
py -3 -I bootstrap/ir_wasm.py bootstrap/v2_compiler.ir $B/v2_compiler_py.wasm >> "$D/wasm.log" 2>&1
st "ir_wasm.py: exit $?"
if cmp -s $B/v2_compiler.wasm $B/v2_compiler_py.wasm; then
  st "wasm: identical to ir_wasm.py's"
else
  st "wasm: differs from ir_wasm.py's"
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
