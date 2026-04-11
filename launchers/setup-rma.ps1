# Forwarder: launchers/setup-rma.ps1 -> scripts/windows/setup-rma.ps1
$ErrorActionPreference = "Stop"
$LaunchersDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $LaunchersDir "..")).Path
$target = Join-Path $RepoRoot "scripts\windows\setup-rma.ps1"
if (-not (Test-Path -LiteralPath $target)) {
    Write-Host "ERROR: Missing $target" -ForegroundColor Red
    exit 1
}
& $target @args
exit $LASTEXITCODE
