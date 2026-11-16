#!/usr/bin/env bash
# v2's gates (docs/plans/gates.md).
#
#   self_hosting/v2/tools/gates.sh [--all] [--plan] [--cap N] [--only PREFIX]
#
# This script only starts them. When there is no self_hosting/build/v2.exe,
# the first is built from the compiler's IR, bootstrap/v2_compiler.ir, by the
# IR reader (bootstrap/ir_reader.py, docs/spec/ir.md), which needs only
# Python. v2.exe then builds the gates tool (self_hosting/v2/tools/
# gates.patlang), and the tool runs what has changed since it last passed, in
# parallel, within what the machine can spare: the compiler and its fixpoint,
# the bootstrap reader, the WASM writers, the interpreter, and every suite's
# feature files on each engine. Its arguments are this script's.
#
# Progress goes to self_hosting/build/gates/status, each unit's output to
# self_hosting/build/gates/logs/UNIT.log, and what passed, with its key, time
# and peak memory, to self_hosting/build/gates/record.
#
# Stopping a run:
#   gates.sh --status   asks the running tool what it is doing
#   gates.sh --quit     starts no more units; the running ones finish and are
#                       recorded, so the next run takes up the rest
#   gates.sh --kill     stops the tool and every unit it started at once
# Killing the shell that started the tool does not stop the tool: on Windows
# its units go on as orphans. Use --quit or --kill.
cd "$(dirname "$0")/../../.." || exit 1
B=self_hosting/build
case "$1" in
  --status|--quit)
    exec $B/v2_interp.exe self_hosting/v2/tools/gates_signal.patlang "${1#--}" < /dev/null ;;
  --kill)
    # /T takes the tool's whole process tree: the units and what they started
    taskkill //IM v2_gates_tool.exe //T //F
    exit $? ;;
esac
mkdir -p $B/gates
if [ ! -f $B/v2.exe ]; then
  echo "gates: building the first compiler from bootstrap/v2_compiler.ir"
  py -3 -I bootstrap/ir_reader.py bootstrap/v2_compiler.ir $B/v2.exe > $B/gates/boot.log 2>&1 || {
    echo "gates: the IR reader failed (self_hosting/build/gates/boot.log)"
    exit 1
  }
fi
$B/v2.exe self_hosting/v2/tools/gates.patlang $B/v2_gates_tool.exe --workers 4 > $B/gates/tool_build.log 2>&1 || {
  echo "gates: building the gates tool failed (self_hosting/build/gates/tool_build.log)"
  exit 1
}
exec $B/v2_gates_tool.exe "$@"
