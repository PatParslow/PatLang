#!/bin/sh
# Block Ownership Model, Phase 9: build (via build_native.patlang) then
# assemble/link/run a block-model-compatible source file as a REAL,
# fully native executable -- no bi_run, no interpretation of the
# block-model IR at runtime at all. Mirrors the project's own established
# two-chunk convention (self_hosting/build_x64_runtime.patlang +
# self_hosting/lib/x64_build.patlang), linking against the already-built
# self_hosting/build/x64_runtime.obj rather than re-lowering it.
#
# Usage: self_hosting/block_model/tools/build_and_run_native.sh <source.patlang> <out_name>
set -u
cd "$(dirname "$0")/../../.." || exit 1
SRC="$1"
OUT="self_hosting/build/$2"
PAT="rust-runtime/target/release/pat.exe"

if [ ! -f self_hosting/build/x64_runtime.obj ]; then
  echo "FAIL: self_hosting/build/x64_runtime.obj missing -- run:"
  echo "  $PAT --ir-run self_hosting/build_x64_runtime.patlang"
  exit 1
fi

"$PAT" --ir-run self_hosting/block_model/tools/build_native.patlang "$SRC" "$OUT" || exit 1
nasm -f win64 -o "$OUT.obj" "$OUT.asm" || exit 1
nasm -f win64 -o "${OUT}_apply.obj" "${OUT}_apply.asm" || exit 1
gcc -o "$OUT.exe" "$OUT.obj" "${OUT}_apply.obj" self_hosting/build/x64_runtime.obj \
  -Wl,--subsystem,console -lkernel32 -luser32 -lgdi32 -lws2_32 || exit 1
"./$OUT.exe"
