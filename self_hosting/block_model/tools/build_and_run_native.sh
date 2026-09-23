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

# Phase 19: a THIRD chunk, needed for Box* (BoxNew/BoxGet/BoxSet/
# BoxSetUnchecked/BoxShare) to call into heap.patlang's own bm_alloc/
# bm_box_read/etc -- see tools/build_heap_chunk.patlang's own header.
if [ ! -f self_hosting/build/heap_chunk.obj ]; then
  echo "FAIL: self_hosting/build/heap_chunk.obj missing -- run:"
  echo "  $PAT --ir-run self_hosting/block_model/tools/build_heap_chunk.patlang"
  exit 1
fi

"$PAT" --ir-run self_hosting/block_model/tools/build_native.patlang "$SRC" "$OUT" || exit 1
nasm -f win64 -o "$OUT.obj" "$OUT.asm" || exit 1
nasm -f win64 -o "${OUT}_apply.obj" "${OUT}_apply.asm" || exit 1
# Phase 19 found a real, project-wide bug here (not block-model-
# specific): without -Wl,--disable-dynamicbase, Windows can relocate
# this image away from the fixed 0x140000000 base x64_family_code_asm's
# own classification logic hardcodes (see self_hosting/lib/
# x64_build.patlang's own header note on this same fix) -- confirmed
# directly via a hand-instrumented raw address dump showing the
# relocated address far outside [0x140000000, 0x150000000), silently
# misclassifying every string literal and breaking print()'s own
# dispatch for any string constant. Fixed at the shared x64_build
# .patlang level too, for every OTHER caller of x64_build_linked; this
# script's own direct gcc invocation needed the same fix independently
# since it doesn't go through that helper.
gcc -o "$OUT.exe" "$OUT.obj" "${OUT}_apply.obj" self_hosting/build/x64_runtime.obj self_hosting/build/heap_chunk.obj \
  -Wl,--subsystem,console -Wl,--disable-dynamicbase -lkernel32 -luser32 -lgdi32 -lws2_32 || exit 1
"./$OUT.exe"
