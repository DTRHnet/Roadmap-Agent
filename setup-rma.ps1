param(
    [switch]$CheckOnly,
    [ValidateSet("Auto","User","Machine")]
    [string]$Scope = "Auto"
)

$ErrorActionPreference = "Continue"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Installer = Join-Path $RepoRoot "scripts/windows/install-persistence.ps1"

if (-not (Test-Path $Installer)) {
    Write-Host "ERROR: Missing installer script: $Installer" -ForegroundColor Red
    exit 1
}

Write-Host "ROADMAP-AGENT Setup" -ForegroundColor Cyan
Write-Host "Repo root: $RepoRoot"
Write-Host "Scope: $Scope"
Write-Host ""

if ($CheckOnly) {
    & $Installer -CheckOnly -Scope $Scope
    exit $LASTEXITCODE
}

& $Installer -Scope $Scope
$code = $LASTEXITCODE
if ($code -ne 0) { exit $code }

$refresh = Join-Path $RepoRoot "scripts\windows\refresh-rma-path.ps1"
if (Test-Path $refresh) {
    & $refresh -Quiet
}

Write-Host ""
Write-Host "Setup completed." -ForegroundColor Green
Write-Host "Try in this shell: rma --help" -ForegroundColor Green
if (-not (Get-Command rma.cmd -ErrorAction SilentlyContinue)) {
    Write-Host "If rma is still not found, run: .\refresh-rma-path.ps1" -ForegroundColor Yellow
    Write-Host "Or open a new terminal (PATH is stored; session may need refresh)." -ForegroundColor Yellow
}
