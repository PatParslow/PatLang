#!/bin/sh
# Block Ownership Model, Phase 1 (Fork D): builds and runs
# refcounted_heap_native_check.patlang against spec_library/block_model/
# refcounted_heap.feature's scenarios, native x64 only -- see that file's
# own header for why this can't run through the ordinary interpreter-based
# Gherkin suite. Mirrors self_hosting/tools/zs_native_check.sh's own
# build-then-run-then-grep pattern.
cd /d/PatLang || exit 1
./patc1.exe self_hosting/block_model/refcounted_heap_native_check.patlang self_hosting/build/refcounted_heap_native_check.exe --x64
if [ ! -x self_hosting/build/refcounted_heap_native_check.exe ]; then
  echo "FAIL: build did not produce an executable"
  exit 1
fi
./self_hosting/build/refcounted_heap_native_check.exe
