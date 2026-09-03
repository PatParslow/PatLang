#!/bin/bash
# Phase 5 full-scale test: assembles and links the REAL, complete
# x64_runtime.patlang output (88,000+ lines -- not a hand-written
# fixture) combined with a real recursive program
# (self_hosting/examples/bench_fib_x64.patlang) entirely through the
# new self-hosted toolchain (x64_asm.patlang + x64_pe_link.patlang),
# and diffs the result against the same combined source built through
# the trusted nasm+gcc reference pipeline.
#
# SLOW: assembling 88,000+ lines of interpreted PatLang takes several
# minutes even on a fast machine (~5-7 minutes as of this writing) --
# not meant for a tight edit/test loop, but the real proof Phase 5's
# own plan calls for ("build the full self-hosted-compiler bundle...
# and confirm it runs correctly"). bench_fib_x64.patlang (fib(32),
# ~7M recursive calls) exercises real function calls, stack-passed
# arguments/locals, and the overflow-checked "DYN" fast-path integer
# arithmetic that dominates x64_runtime.patlang's own code -- the
# exact code shape that exposed the mem-operand push/pop bug (see
# patlang-x64-selfhosted-assembler-phase1 memory for the full story).
set -u
cd "$(dirname "$0")"
REPO="F:/PatLang"
PAT="$REPO/rust-runtime/target/release/pat.exe"
NASM="C:/Program Files/NASM/nasm.exe"
FAIL=0

if [ ! -f "$REPO/self_hosting/build/x64_runtime.asm" ] || [ ! -f "$REPO/self_hosting/build/x64_runtime.funcs" ]; then
  echo "FAIL: self_hosting/build/x64_runtime.asm/.funcs missing -- run:"
  echo "  $PAT --ir-run $REPO/self_hosting/build_x64_runtime.patlang"
  exit 1
fi

echo "=== Building combined program+runtime asm (shared by both pipelines) ==="
cat > tmp_full_driver.patlang <<EOF
include "$REPO/self_hosting/lib/lexer.patlang"
include "$REPO/self_hosting/lib/parser.patlang"
include "$REPO/self_hosting/lib/lower.patlang"
include "$REPO/self_hosting/lib/codegen_x64.patlang"
include "$REPO/self_hosting/lib/x64_build.patlang"

make a function called x64_name_in_list takes names, name returns yes
  let n = names.length
  let i = 0
  while i < n do
    if names[i] == name then
      return true
    end
    let i = i + 1
  end
  return false
end

let prog_src = read_file("$REPO/self_hosting/examples/bench_fib_x64.patlang")
let rt_src = read_file("$REPO/self_hosting/lib/x64_runtime.patlang")
let src = rt_src + chr(10) + prog_src
let toks = tokenize(src)
let ast = parse_program(toks)
let ir = lower_program(ast)
let all_funcs = ir[2]

let rt_names = split_lines(read_file("$REPO/self_hosting/build/x64_runtime.funcs"))
let program_funcs = []
let i = 0
while i < all_funcs.length do
  if not x64_name_in_list(rt_names, all_funcs[i][1]) then
    let program_funcs = list_push(program_funcs, all_funcs[i])
  end
  let i = i + 1
end

let program_ir = ["ProgramIR", "main", program_funcs, ir[3]]
let program_asm = emit_program_x64(program_ir, false, rt_names)
write_file("$REPO/self_hosting/tests/x64_asm/tmp_full_program.asm", program_asm)

let apply_table_asm = x64_emit_apply_table_asm(program_funcs)
write_file("$REPO/self_hosting/tests/x64_asm/tmp_full_apply.asm", apply_table_asm)
print("asm generated")
EOF
"$PAT" --ir-run tmp_full_driver.patlang
if [ ! -f tmp_full_program.asm ] || [ ! -f tmp_full_apply.asm ]; then
  echo "FAIL: asm generation failed"
  rm -f tmp_full_driver.patlang
  exit 1
fi

echo ""
echo "=== Reference: nasm + gcc ==="
"$NASM" -Ox -f win64 -o tmp_full_rt_ref.obj "$REPO/self_hosting/build/x64_runtime.asm"
"$NASM" -Ox -f win64 -o tmp_full_prog_ref.obj tmp_full_program.asm
"$NASM" -Ox -f win64 -o tmp_full_apply_ref.obj tmp_full_apply.asm
gcc -o tmp_full_ref.exe tmp_full_prog_ref.obj tmp_full_apply_ref.obj tmp_full_rt_ref.obj -Wl,--subsystem,console -lkernel32 -luser32 -lgdi32 -lws2_32
./tmp_full_ref.exe
ref_code=$?
echo "reference exit code: $ref_code"

echo ""
echo "=== New toolchain: self-hosted assembler + linker ==="
cat > tmp_full_native_driver.patlang <<EOF
include "$REPO/self_hosting/lib/x64_build.patlang"
let runtime_asm = read_file("$REPO/self_hosting/build/x64_runtime.asm")
let program_asm = read_file("$REPO/self_hosting/tests/x64_asm/tmp_full_program.asm")
let apply_asm = read_file("$REPO/self_hosting/tests/x64_asm/tmp_full_apply.asm")
let rt_chunk = x64_assemble_native(runtime_asm, "$REPO/self_hosting/tests/x64_asm/tmp_full_rt.asm")
let prog_chunk = x64_assemble_native(program_asm, "$REPO/self_hosting/tests/x64_asm/tmp_full_prog.asm")
let apply_chunk = x64_assemble_native(apply_asm, "$REPO/self_hosting/tests/x64_asm/tmp_full_apply2.asm")
let result = x64_link_native_chunks([prog_chunk, rt_chunk, apply_chunk], "$REPO/self_hosting/tests/x64_asm/tmp_full_native.exe")
print(result)
EOF
"$PAT" --ir-run tmp_full_native_driver.patlang
./tmp_full_native.exe
new_code=$?
echo "new toolchain exit code: $new_code"

if [ "$ref_code" == "$new_code" ] && [ "$ref_code" == "0" ]; then
  echo ""
  echo "PASS: full x64_runtime.patlang + bench_fib_x64.patlang assembles, links, and runs via the new toolchain (matches nasm+gcc reference, exit 0)"
else
  echo ""
  echo "FAIL: reference=$ref_code new=$new_code (expected 0, 0)"
  FAIL=1
fi

rm -f tmp_full_driver.patlang tmp_full_native_driver.patlang tmp_full_program.asm tmp_full_apply.asm \
      tmp_full_rt_ref.obj tmp_full_prog_ref.obj tmp_full_apply_ref.obj tmp_full_ref.exe \
      tmp_full_rt.asm tmp_full_prog.asm tmp_full_apply2.asm tmp_full_native.exe
exit $FAIL
