#!/usr/bin/env bash
# run_benchmarks.sh -- thin wrapper for run_benchmarks.patlang, matching
# verify_patc2.sh's own pattern: the PatLang script can't call os_exit
# (an x64-codegen-only intrinsic, not a host function the plain
# interpreter has access to), so it prints a plain "FAILED"/"OK" marker
# line instead, and this wrapper turns that into a real process exit
# code for CI/scripting purposes.
#
# Run from the repo root:
#   bash self_hosting/run_benchmarks.sh
#
# Requires (build once, separately -- same prerequisites the script
# itself checks and reports on):
#   cargo build --release --manifest-path rust-runtime/Cargo.toml
#   rust-runtime/target/release/pat --ir-run self_hosting/build_patc1.patlang
#   rust-runtime/target/release/pat --ir-run self_hosting/build_x64_runtime.patlang   (optional -- x64 rows skip cleanly if missing)

set -u
cd "$(dirname "$0")/.."   # repo root

mkdir -p self_hosting/build/bench_tmp

OUT=$(rust-runtime/target/release/pat.exe --ir-run self_hosting/run_benchmarks.patlang 2>&1)
echo "$OUT"

if echo "$OUT" | grep -q "^FAILED:"; then
  exit 1
fi
exit 0
