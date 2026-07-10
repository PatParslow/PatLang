#!/bin/bash
# Patlang Self-Host Bootstrap Script
# Attempts to build the Patlang compiler using the Patlang-native build tool

set -e

cd "$(dirname "$0")/../patlang-selfhost/src"

echo "== Bootstrapping Patlang self-hosted compiler =="
echo "Invoking build tool..."
ruby ../../build_tool/patlang_build.rb -f build.patlang compiler

status=$?
if [ $status -eq 0 ]; then
  echo "== Bootstrap build succeeded =="
else
  echo "== Bootstrap build failed with exit code $status =="
fi

exit $status