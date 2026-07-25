# Timeout wrapper for auto_prober.patlang's subprocess-isolated probing.
# exec_capture (rust-runtime/src/ir/hosts.rs's host_exec_capture) has NO
# timeout at all -- std::process::Command::output() blocks forever if
# the child never exits. Confirmed via a real incident: a guessed
# candidate call hung `pat --ir-run` indefinitely, freezing the whole
# 1064-candidate batch for over 2 hours with no error and no progress.
# This wrapper enforces a hard wall-clock timeout, force-killing the
# child if it doesn't exit in time, so a single bad guess can never
# block the batch again.
param(
  [string]$PatExe,
  [string]$ScriptPath,
  [int]$TimeoutMs
)
$outFile = [System.IO.Path]::GetTempFileName()
$errFile = [System.IO.Path]::GetTempFileName()
try {
  $p = Start-Process -FilePath $PatExe -ArgumentList @('--ir-run', $ScriptPath) -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
  $exited = $p.WaitForExit($TimeoutMs)
  if (-not $exited) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Write-Output "AUTO_PROBE_TIMEOUT"
  }
  Get-Content $outFile -Raw -ErrorAction SilentlyContinue
  Get-Content $errFile -Raw -ErrorAction SilentlyContinue
} finally {
  Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
}
