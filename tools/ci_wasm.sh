#!/usr/bin/env bash
# The v2 toolchain through WebAssembly, on any machine with Python 3 and Node
# (review, test-suite recommendation 1): no Windows, no Rust.
#
#   bash tools/ci_wasm.sh [SKIP_DEMO...]
#
# 1. bootstrap/ir_wasm.py builds the compiler from bootstrap/v2_compiler.ir.
# 2. That compiler, under Node with the disk as its files (run_node.mjs
#    --real-files), builds each demo in demos/ as WebAssembly.
# 3. Each demo runs under Node, and its output must be demos/expected/NAME.txt.
# A demo named on the command line is skipped (one that needs processes or
# sockets, which the browser's host has none of). Exits 1 when any demo fails.
set -u
cd "$(dirname "$0")/.."
PY=python3
command -v python3 > /dev/null 2>&1 || PY="py -3"
OUT=self_hosting/build/ci_wasm
mkdir -p "$OUT"
# CI_WASM_IR: another IR to build the compiler from (one made from a tree's
# sources with `v2.exe self_hosting/v2/compile.patlang OUT.ir --ir`)
IR=${CI_WASM_IR:-bootstrap/v2_compiler.ir}
$PY -I bootstrap/ir_wasm.py "$IR" "$OUT/v2.wasm" || exit 1
failed=0
passed=0
for src in demos/*.patlang; do
  name=$(basename "$src" .patlang)
  skip=0
  for s in "$@"; do [ "$s" = "$name" ] && skip=1; done
  if [ $skip = 1 ]; then echo "skip $name"; continue; fi
  if ! node self_hosting/v2/wasm/run_node.mjs --real-files "$OUT/v2.wasm" "$src" "$OUT/$name.wasm" --wasm > "$OUT/$name.build.txt" 2>&1; then
    echo "FAIL $name: the WebAssembly compiler could not build it"; cat "$OUT/$name.build.txt"; failed=$((failed+1)); continue
  fi
  node self_hosting/v2/wasm/run_node.mjs --real-files "$OUT/$name.wasm" > "$OUT/$name.txt" 2>&1
  if diff <(tr -d '\r' < "$OUT/$name.txt") <(tr -d '\r' < "demos/expected/$name.txt") > "$OUT/$name.diff"; then
    echo "pass $name"; passed=$((passed+1))
  else
    echo "FAIL $name: its output differs from demos/expected/$name.txt"; head -20 "$OUT/$name.diff"; failed=$((failed+1))
  fi
done
echo "tests: $passed passed, $failed failed"
[ $failed = 0 ]
