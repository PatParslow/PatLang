#!/bin/sh
# Native parity check for ONE program under a patc1 backend flag (GitHub #180).
# Runs the program under `pat --ir-run` for the expected output, compiles it with
# `./patc1.exe <src> <exe> <flag>`, runs the executable, and compares the two
# outputs line for line. The interpreter echoes a script's final value as a last
# line (`true` after t_report); the native executable does not, so one trailing
# `true` line is dropped from the expected output.
#
# Usage: bm_parity_one.sh <source.patlang> <out_dir> [flag, default --bm]
# Prints one result line: "<name> PASS|FAIL-COMPILE|FAIL-RUN|FAIL-OUTPUT|SKIP-INTERP <detail>"
SRC="$1"; OUT="$2"; FLAG="${3:---bm}"
NAME=$(basename "$SRC" .patlang)
mkdir -p "$OUT"
EXE="$OUT/$NAME.exe"
rm -f "$EXE"
timeout 600 rust-runtime/target/release/pat.exe --ir-run "$SRC" > "$OUT/$NAME.expected" 2>&1
RC=$?
if [ $RC -ne 0 ]; then echo "$NAME SKIP-INTERP interpreter exit $RC"; exit 0; fi
tr -d '' < "$OUT/$NAME.expected" | sed -e '${/^true$/d}' -e '${/^unit$/d}' -e '${/^$/d}' > "$OUT/$NAME.exp"
timeout 1800 ./patc1.exe "$SRC" "$EXE" "$FLAG" > "$OUT/$NAME.compile.log" 2>&1
if [ ! -f "$EXE" ]; then
  echo "$NAME FAIL-COMPILE $(tr '\r\n' '  ' < "$OUT/$NAME.compile.log" | cut -c1-200)"; exit 0
fi
timeout 600 "$EXE" > "$OUT/$NAME.actual" 2>&1
RC=$?
tr -d '\r' < "$OUT/$NAME.actual" > "$OUT/$NAME.act"
if cmp -s "$OUT/$NAME.exp" "$OUT/$NAME.act"; then
  echo "$NAME PASS"
else
  D=$(diff "$OUT/$NAME.exp" "$OUT/$NAME.act" | head -2 | tr '\n' ' ' | cut -c1-160)
  if [ $RC -ne 0 ]; then echo "$NAME FAIL-RUN exit $RC; $D"; else echo "$NAME FAIL-OUTPUT $D"; fi
fi
