#!/usr/bin/env bash
# Checks self_hosting/templates/budgeted_tool.patlang against its header's
# claims: status answers while busy, pause holds the count still, resume
# carries on, the result matches an uninterrupted run, and quit stops it.
#
#   self_hosting/templates/check_budgeted_tool.sh            (interpreter)
#   TOOL=./tool.exe self_hosting/templates/check_budgeted_tool.sh   (native)
#
# Progress goes to self_hosting/build/check_budgeted_tool.progress.
cd "$(dirname "$0")/../.."
TOOL=${TOOL:-"rust-runtime/target/release/pat.exe --ir-run self_hosting/templates/budgeted_tool.patlang"}
UNITS=${UNITS:-3000}
PROG=self_hosting/build/check_budgeted_tool.progress
OUT=self_hosting/build/check_budgeted_tool.out
: > "$PROG"
pass=0; fail=0
note() { echo "$*" | tee -a "$PROG"; }
check() {  # name, condition result (0 = ok), detail
  if [ "$2" = 0 ]; then pass=$((pass+1)); note "PASS $1"; else fail=$((fail+1)); note "FAIL $1: $3"; fi
}
ms() { date +%s%3N; }
done_of() { echo "$1" | sed -n 's/.*done=\([0-9]*\)\/.*/\1/p'; }
# wait_finish pid: waits for the tool to exit, failing (and killing it) if
# its unit count stops moving while it reports itself running -- judged by
# its own status, not by a deadline.
wait_finish() {
  local last="" same=0 s d
  while kill -0 "$1" 2>/dev/null; do
    s=$($TOOL status 2>/dev/null)
    case "$s" in
      *"state=running"*)
        d=$(done_of "$s")
        if [ "$d" = "$last" ]; then same=$((same+1)); else same=0; last=$d; fi
        if [ $same -ge 10 ]; then note "  no progress: $s"; kill "$1"; return 1; fi ;;
    esac
    sleep 0.5
  done
  wait "$1"
}
pid=""
trap '[ -n "$pid" ] && kill "$pid" 2>/dev/null' EXIT
wait_listening() {  # until a status query gets a phase= reply
  local i=0
  while [ $i -lt 100 ]; do
    case "$($TOOL status 2>/dev/null)" in *phase=*) return 0 ;; esac
    sleep 0.1; i=$((i+1))
  done
  return 1
}

note "baseline: $UNITS units uninterrupted"
base=$($TOOL "$UNITS" | grep '^acc=')
note "  $base"

note "interrupted run"
$TOOL "$UNITS" > "$OUT" 2>&1 &
pid=$!
wait_listening; check "tool answers status once started" $? "no reply"
t0=$(ms); s1=$($TOOL status); t1=$(ms)
note "  status: $s1 ($((t1-t0)) ms)"
case "$s1" in *"state=running"*) r=0 ;; *) r=1 ;; esac
check "status while busy reports running" $r "$s1"
p=$($TOOL pause); note "  pause -> $p"
sleep 0.3; a=$($TOOL status); sleep 0.5; b=$($TOOL status)
note "  paused: $a | $b"
[ "$(done_of "$a")" = "$(done_of "$b")" ] && case "$a" in *"state=paused"*) true ;; *) false ;; esac
check "pause holds the unit count still" $? "$a / $b"
r=$($TOOL resume); note "  resume -> $r"
sleep 0.3; c=$($TOOL status); note "  resumed: $c"
[ "$(done_of "$c")" -gt "$(done_of "$b")" ] 2>/dev/null
check "resume carries on from the same unit" $? "$b -> $c"
wait_finish $pid
got=$(grep '^acc=' "$OUT")
note "  final: $(grep '^done\|^stopped' "$OUT") $got"
[ -n "$base" ] && [ "$got" = "$base" ]
check "interrupted result equals the uninterrupted one" $? "$got vs $base"

note "quit run"
$TOOL "$UNITS" > "$OUT" 2>&1 &
pid=$!
wait_listening
q=$($TOOL quit); note "  quit -> $q"
wait_finish $pid
grep -q '^stopped phase=stopped' "$OUT"
check "quit stops the tool before the end" $? "$(cat "$OUT")"

note "passed $pass failed $fail"
[ $fail = 0 ]
