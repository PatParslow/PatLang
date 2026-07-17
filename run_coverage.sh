#!/bin/bash
  set -e
  PAT=./rust-runtime/target/release/pat.exe
  SUITES=(
    self_hosting/patc1_main.patlang
  )
  mkdir -p coverage_reports
  for s in "${SUITES[@]}"; do
    name=$(basename "$s" .patlang)
    echo "=== $s ==="
    $PAT --ir-run self_hosting/tools/coverage_main.patlang "$s" > "coverage_reports/${name}.txt" 2>&1 || echo "  (exited non-zero, see report)"
    head -8 "coverage_reports/${name}.txt"
    echo ""
  done
