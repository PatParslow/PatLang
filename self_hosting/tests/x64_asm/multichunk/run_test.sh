#!/bin/bash
# Phase 3 multi-chunk regression test: three separately-assembled chunks
# (chunk_a.asm, chunk_b.asm, chunk_main.asm) with real cross-chunk CALL
# and ABS64 data relocations, linked together in ONE final image --
# exactly the shape x64_build_linked_multi/x64_link_objs need for real
# per-function-object-cache builds, just with hand-written chunks
# instead of patc1's own per-function cache.
set -u
cd "$(dirname "$0")"
REPO="F:/PatLang"
PAT="$REPO/rust-runtime/target/release/pat.exe"
NASM="C:/Program Files/NASM/nasm.exe"

echo "=== Reference: nasm + gcc, 3 objects, 1 link ==="
"$NASM" -Ox -f win64 -o ref_a.obj chunk_a.asm
"$NASM" -Ox -f win64 -o ref_b.obj chunk_b.asm
"$NASM" -Ox -f win64 -o ref_main.obj chunk_main.asm
gcc -o ref.exe ref_main.obj ref_a.obj ref_b.obj -Wl,--subsystem,console -lkernel32 -luser32 -lgdi32 -lws2_32
if [ ! -f ref.exe ]; then
  echo "FAIL: reference build failed"
  exit 1
fi
./ref.exe
ref_code=$?
echo "reference exit code: $ref_code"

echo ""
echo "=== New toolchain: self-hosted assembler + linker, 3 chunks, 1 link ==="
cat > driver.patlang <<EOF
include "$REPO/self_hosting/lib/x64_pe_link.patlang"
let chunk_main = x64_assemble_chunk(read_file("$REPO/self_hosting/tests/x64_asm/multichunk/chunk_main.asm"))
let chunk_a = x64_assemble_chunk(read_file("$REPO/self_hosting/tests/x64_asm/multichunk/chunk_a.asm"))
let chunk_b = x64_assemble_chunk(read_file("$REPO/self_hosting/tests/x64_asm/multichunk/chunk_b.asm"))
let import_spec = [["KERNEL32.DLL", ["ExitProcess"]]]
let result = x64_link([chunk_main, chunk_a, chunk_b], import_spec, "main", "new.exe")
print(result)
EOF
new_link_out=$("$PAT" --ir-run driver.patlang 2>&1)
echo "$new_link_out"
if [ ! -f new.exe ]; then
  echo "FAIL: new toolchain build failed"
  exit 1
fi
./new.exe
new_code=$?
echo "new toolchain exit code: $new_code"

echo ""
if [ "$ref_code" == "$new_code" ]; then
  echo "=== PASS: exit codes match ($new_code) ==="
  status=0
else
  echo "=== FAIL: reference=$ref_code, new=$new_code ==="
  status=1
fi

rm -f ref_a.obj ref_b.obj ref_main.obj ref.exe new.exe driver.patlang
exit $status
