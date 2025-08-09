Param(
  [string]$Mode = ''
)
$ErrorActionPreference = 'Stop'
Write-Host "[local-ci] Starting local CI for rust-runtime (PowerShell)"
${strict} = 0
if ($Mode -eq '--strict') { ${strict} = 1 }

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
  Write-Host "[local-ci] ERROR: cargo not found in PATH. Install Rust (https://rustup.rs)."
  exit 127
}

Set-Location "$root/rust-runtime"

Write-Host "[local-ci] Toolchain: $(rustc --version) | $(cargo --version)"

$fmt = 'SKIP'; $clippy = 'SKIP'; $test = 'OK'

if (${strict} -eq 1) {
  try { cargo fmt -- --check | Out-Null; $fmt = 'OK' } catch { $fmt = 'FAIL' }
  try { cargo clippy -- -D warnings | Out-Null; $clippy = 'OK' } catch { $clippy = 'FAIL' }
}
try { cargo test | Out-Null } catch { $test = 'FAIL' }

Set-Location $root
Write-Host "[local-ci] Summary: fmt=$fmt | clippy=$clippy | test=$test"

if (${strict} -eq 0) {
  if ($test -eq 'OK') { Write-Host "[local-ci] All checks passed ✅"; exit 0 } else { Write-Host "[local-ci] Tests failed ❌"; exit 1 }
}

if ($fmt -eq 'OK' -and $clippy -eq 'OK' -and $test -eq 'OK') {
  Write-Host "[local-ci] All checks passed ✅"
  exit 0
} else {
  Write-Host "[local-ci] One or more checks failed ❌"
  exit 1
}
