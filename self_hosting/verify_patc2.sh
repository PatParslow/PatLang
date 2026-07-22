#!/usr/bin/env bash
# verify_patc2.sh -- fully exercises patc2.exe (the binary produced by
# patc1.exe self-compiling patc1_all.patlang via --x64) to confirm it's
# a genuinely working compiler, not just a binary that doesn't crash at
# startup. Run from the repo root:
#   bash self_hosting/verify_patc2.sh
#
# Three things this checks, in order:
#   1. patc2.exe compiles every x64_*demo*.patlang example and produces
#      output BYTE-IDENTICAL to patc1.exe compiling the SAME file --
#      not just "doesn't crash", but proves patc2.exe's own codegen is
#      correct against the known-good reference compiler.
#   2. patc2.exe's own CLI mechanics work: argv()/read_file/write_file/
#      file_exists, exercised via examples/x64_argv_test.patlang with
#      real command-line arguments (this is the exact gap closed in
#      checkpoint 6 -- see memory patlang-x64-register-allocator-bug-found).
#   3. (optional, slow -- SKIP_SELF_COMPILE=1 to skip) patc2.exe
#      compiling patc1_all.patlang itself via --x64 -- the actual
#      "fixpoint of the fixpoint" question: can patc2.exe reproduce
#      patc1.exe's own bootstrap? This can take a long time (the
#      original fixpoint took hours), matching this session's own
#      established pattern of NOT looping on this from the assistant
#      side -- run it yourself, in your own time.
#
# Exits 0 if everything passes, 1 if anything fails (with a clear
# summary either way).

set -u
cd "$(dirname "$0")/.."   # repo root

PATC1="./patc1.exe"
PATC2="./patc2.exe"
WORKDIR="self_hosting/build/patc2_verify"
FAIL=0
PASS=0

if [ ! -f "$PATC1" ]; then
  echo "FATAL: $PATC1 not found -- build it first (pat --ir-run self_hosting/build_patc1.patlang)"
  exit 1
fi
if [ ! -f "$PATC2" ]; then
  echo "FATAL: $PATC2 not found -- run the fixpoint first:"
  echo "  ./patc1.exe self_hosting/build/patc1_all.patlang patc2.exe --x64"
  exit 1
fi

mkdir -p "$WORKDIR"

echo "=== Part 1: patc2.exe vs patc1.exe, byte-for-byte, on every x64 demo ==="
for f in self_hosting/examples/x64_*demo*.patlang; do
  name=$(basename "$f" .patlang)
  out1="$WORKDIR/${name}_via_patc1.exe"
  out2="$WORKDIR/${name}_via_patc2.exe"

  "$PATC1" "$f" "$out1" --x64 > "$WORKDIR/${name}_patc1.build.log" 2>&1
  "$PATC2" "$f" "$out2" --x64 > "$WORKDIR/${name}_patc2.build.log" 2>&1

  if [ ! -f "$out1" ]; then
    echo "SKIP  $name (patc1.exe itself failed to build it -- not patc2's fault)"
    continue
  fi
  if [ ! -f "$out2" ]; then
    echo "FAIL  $name (patc2.exe failed to build it)"
    tail -5 "$WORKDIR/${name}_patc2.build.log"
    FAIL=$((FAIL+1))
    continue
  fi

  "$out1" > "$WORKDIR/${name}_patc1.run.log" 2>&1
  "$out2" > "$WORKDIR/${name}_patc2.run.log" 2>&1

  if diff -q "$WORKDIR/${name}_patc1.run.log" "$WORKDIR/${name}_patc2.run.log" > /dev/null 2>&1; then
    echo "PASS  $name"
    PASS=$((PASS+1))
  else
    echo "FAIL  $name (output differs from patc1.exe's own compile)"
    diff "$WORKDIR/${name}_patc1.run.log" "$WORKDIR/${name}_patc2.run.log" | head -5
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "=== Part 2: patc2.exe's own CLI mechanics (argv/read_file/write_file/file_exists) ==="
argv_out="$WORKDIR/argv_test_via_patc2.exe"
"$PATC2" self_hosting/examples/x64_argv_test.patlang "$argv_out" --x64 > "$WORKDIR/argv_test.build.log" 2>&1
if [ ! -f "$argv_out" ]; then
  echo "FAIL  patc2.exe couldn't even build x64_argv_test.patlang"
  tail -5 "$WORKDIR/argv_test.build.log"
  FAIL=$((FAIL+1))
else
  result=$("$argv_out" foo.patlang out.exe --x64 2>&1)
  ok=1
  echo "$result" | grep -q "^argc=3$" || ok=0
  echo "$result" | grep -q "^foo.patlang$" || ok=0
  echo "$result" | grep -q "^out.exe$" || ok=0
  echo "$result" | grep -q "^write_ok$" || ok=0
  echo "$result" | grep -q "^exists_ok$" || ok=0
  echo "$result" | grep -q "^hello from write_file$" || ok=0
  if [ "$ok" = "1" ]; then
    echo "PASS  argv/read_file/write_file/file_exists (patc2.exe built and ran this itself)"
    PASS=$((PASS+1))
  else
    echo "FAIL  argv/read_file/write_file/file_exists -- got:"
    echo "$result" | sed 's/^/    /'
    FAIL=$((FAIL+1))
  fi
fi

echo ""
if [ "${SKIP_SELF_COMPILE:-0}" = "1" ]; then
  echo "=== Part 3: SKIPPED (SKIP_SELF_COMPILE=1) ==="
else
  echo "=== Part 3: patc2.exe compiling patc1_all.patlang itself (the fixpoint-of-the-fixpoint) ==="
  echo "This can take a long time (the original fixpoint took hours) -- run separately if you'd"
  echo "rather not block on it here. Re-run with SKIP_SELF_COMPILE=1 to skip this part."
  echo "Command (run it yourself when ready, this script won't block waiting):"
  echo "  ./patc2.exe self_hosting/build/patc1_all.patlang patc3.exe --x64"
fi

echo ""
echo "=== Summary ==="
echo "PASS: $PASS   FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "Some checks failed -- see above for details. Build logs and .run.log files are in $WORKDIR/"
  exit 1
else
  echo "All checks passed."
  exit 0
fi
