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

Write-Host ""
Write-Host "Setup completed." -ForegroundColor Green
Write-Host "Open a NEW terminal and run: rma --help" -ForegroundColor Green
$UserBin = Join-Path $env:LOCALAPPDATA "Roadmap-Agent\bin"
Write-Host "If command is still missing in current shell, run one-time:" -ForegroundColor Yellow
Write-Host ("  $env:Path += ';{0}'" -f $UserBin)
