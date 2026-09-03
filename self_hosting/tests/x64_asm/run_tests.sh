#!/bin/bash
# Phase 2 regression suite for the self-hosted x64 assembler+linker.
# For each .asm fixture in this directory: assembles+links via BOTH the
# existing nasm+gcc reference toolchain AND the new PatLang assembler+
# linker (self_hosting/lib/x64_asm.patlang / x64_pe_link.patlang), runs
# both resulting .exe files, and diffs their exit codes.
set -u
cd "$(dirname "$0")"
REPO="F:/PatLang"
PAT="$REPO/rust-runtime/target/release/pat.exe"
NASM="C:/Program Files/NASM/nasm.exe"
FAIL=0
PASS=0

for asm in *.asm; do
  # test_multidll_libm.asm needs a non-default (msvcrt.dll) import and
  # has its own dedicated runner (run_multidll_test.sh) -- skip it here.
  if [ "$asm" == "test_multidll_libm.asm" ]; then
    continue
  fi
  name="${asm%.asm}"
  ref_exe="F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_ref.exe"
  new_exe="F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_new.exe"

  # Reference: nasm + gcc
  "$NASM" -Ox -f win64 -o "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}.obj" "$asm" > "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_nasm.log" 2>&1
  gcc -o "$ref_exe" "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}.obj" -Wl,--subsystem,console -lkernel32 -luser32 -lgdi32 -lws2_32 > "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_gcc.log" 2>&1
  if [ ! -f "$ref_exe" ]; then
    echo "FAIL $name: reference (nasm+gcc) build failed"
    cat "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_nasm.log" "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_gcc.log"
    FAIL=$((FAIL+1))
    continue
  fi
  "$ref_exe"
  ref_code=$?

  # New: self-hosted assembler + linker
  cat > "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_driver.patlang" <<EOF
include "$REPO/self_hosting/lib/x64_pe_link.patlang"
let asm = read_file("$REPO/self_hosting/tests/x64_asm/$asm")
let chunk = x64_assemble_chunk(asm)
let import_spec = [["KERNEL32.DLL", ["ExitProcess"]]]
let result = x64_link([chunk], import_spec, "main", "$new_exe")
print(result)
EOF
  new_link_out=$("$PAT" --ir-run "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_driver.patlang" 2>&1)
  if [ ! -f "$new_exe" ]; then
    echo "FAIL $name: new toolchain build failed: $new_link_out"
    FAIL=$((FAIL+1))
    continue
  fi
  "$new_exe"
  new_code=$?

  if [ "$ref_code" == "$new_code" ]; then
    echo "PASS $name: exit code $new_code (matches reference)"
    PASS=$((PASS+1))
  else
    echo "FAIL $name: reference exit=$ref_code, new toolchain exit=$new_code"
    FAIL=$((FAIL+1))
  fi

  rm -f "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}.obj" "$ref_exe" "$new_exe" "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_nasm.log" "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_gcc.log" "F:/PatLang/self_hosting/tests/x64_asm/tmp_x64test_${name}_driver.patlang"
done

echo ""
echo "=== $PASS passed, $FAIL failed ==="
exit $FAIL
