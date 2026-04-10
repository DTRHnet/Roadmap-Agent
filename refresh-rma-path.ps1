# Repo-root helper: refresh PATH in current PowerShell (see scripts/windows/refresh-rma-path.ps1).

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "scripts\windows\refresh-rma-path.ps1") @args
