# '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#  ____   ___    ____  ___    ___ ___   ____  ____          ____   ____    ___  ____   ______ 
# |    \ /   \  /    ||   \  |   |   | /    ||    \        /    | /    |  /  _]|    \ |      |
# |  D  )     ||  o  ||    \ | _   _ ||  o  ||  o  )_____ |  o  ||   __| /  [_ |  _  ||      |
# |    /|  O  ||     ||  D  ||  \_/  ||     ||   _/|     ||     ||  |  ||    _]|  |  ||_|  |_|
# |    \|     ||  _  ||     ||   |   ||  _  ||  |  |_____||  _  ||  |_ ||   [_ |  |  |  |  |  
# |  .  \     ||  |  ||     ||   |   ||  |  ||  |         |  |  ||     ||     ||  |  |  |  |  
# |__|\_|\___/ |__|__||_____||___|___||__|__||__|         |__|__||___,_||_____||__|__|  |__|  
#                                                                                             
# A DTRHnet Project                                              2026 <admin[at]dtrh[dot]net>
# -------------------------------------------------------------------------------------------
# Summary: Convenience wrapper around install-persistence.ps1 plus quiet PATH refresh in this session.
# Notes: Repo root is two levels above this file. Repo-root setup-rma.ps1 forwards here for stable paths.
# Last updated: 2026-04-10 | Version: v1.1.0-beta

param(
    [switch]$CheckOnly,
    [ValidateSet("Auto", "User", "Machine")]
    [string]$Scope = "Auto"
)

$ErrorActionPreference = "Continue"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Installer = Join-Path $RepoRoot "scripts\windows\install-persistence.ps1"

if (-not (Test-Path -LiteralPath $Installer)) {
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

$refresh = Join-Path $PSScriptRoot "refresh-rma-path.ps1"
if (Test-Path -LiteralPath $refresh) {
    & $refresh -Quiet
}

Write-Host ""
Write-Host "Setup completed." -ForegroundColor Green
Write-Host "Try in this shell: rma --help" -ForegroundColor Green
if (-not (Get-Command rma.cmd -ErrorAction SilentlyContinue)) {
    Write-Host "If rma is still not found, run: .\refresh-rma-path.ps1 or .\scripts\windows\refresh-rma-path.ps1" -ForegroundColor Yellow
    Write-Host "Or open a new terminal (PATH is stored; session may need refresh)." -ForegroundColor Yellow
}
