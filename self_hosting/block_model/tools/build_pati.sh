#!/bin/sh
# Builds pati, the native PatLang interpreter (docs/plans/native-interpreter.md),
# with patc1 --x64. Output: self_hosting/build/pati.exe.
#
# Usage: self_hosting/block_model/tools/build_pati.sh
set -u
cd "$(dirname "$0")/../../.." || exit 1
# The compiler under test; PATC1=self_hosting/build/patc1_x64.exe checks the
# natively built one.
PATC1="${PATC1:-./patc1.exe}"
export PATC1
rm -f self_hosting/build/pati.exe
"$PATC1" self_hosting/block_model/pati_main.patlang self_hosting/build/pati.exe --x64
if [ ! -f self_hosting/build/pati.exe ]; then
  echo "FAIL: pati.exe was not built"
  exit 1
fi
echo "built self_hosting/build/pati.exe"
