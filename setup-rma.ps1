# Thin wrapper — forwards to scripts/windows/setup-rma.ps1 (keeps repo root UX).
# Last updated: 2026-04-10 | Version: v1.0.0

$ErrorActionPreference = "Stop"
$target = Join-Path $PSScriptRoot "scripts\windows\setup-rma.ps1"
if (-not (Test-Path -LiteralPath $target)) {
    Write-Host "ERROR: Missing $target" -ForegroundColor Red
    exit 1
}
& $target @args
exit $LASTEXITCODE
