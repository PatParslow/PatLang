#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
STRICT=0
if [[ "$MODE" == "--strict" ]]; then STRICT=1; fi

echo "[local-ci] Starting local CI for rust-runtime (strict=$STRICT)"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v cargo >/dev/null 2>&1; then
  echo "[local-ci] ERROR: cargo not found in PATH. Install Rust (https://rustup.rs) and ensure cargo is available."
  exit 127
fi

pushd rust-runtime >/dev/null

echo "[local-ci] Rust toolchain: $(rustc --version || true) | Cargo: $(cargo --version || true)"

status_fmt=SKIP
status_clippy=SKIP
status_test=OK

if [[ $STRICT -eq 1 ]]; then
  echo "[local-ci] cargo fmt -- --check"
  if cargo fmt --quiet -- --check; then status_fmt=OK; else status_fmt=FAIL; fi

  echo "[local-ci] cargo clippy -- -D warnings"
  if cargo clippy -q -- -D warnings; then status_clippy=OK; else status_clippy=FAIL; fi
fi

echo "[local-ci] cargo test"
if ! cargo test -q; then
  status_test=FAIL
fi

popd >/dev/null

echo "[local-ci] Summary: fmt=$status_fmt | clippy=$status_clippy | test=$status_test"

if [[ $STRICT -eq 0 ]]; then
  # In non-strict mode, only tests determine pass/fail
  if [[ "$status_test" == OK ]]; then
    echo "[local-ci] All checks passed ✅"
    exit 0
  else
    echo "[local-ci] Tests failed ❌"
    exit 1
  fi
fi

if [[ "$status_fmt" == OK && "$status_clippy" == OK && "$status_test" == OK ]]; then
  echo "[local-ci] All checks passed ✅"
  exit 0
else
  echo "[local-ci] One or more checks failed ❌"
  exit 1
fi
