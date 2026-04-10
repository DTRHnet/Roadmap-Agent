# -------------------------------------------------------------------------------------------
# ROADMAP-AGENT | A DTRHnet Project (2026 <admin[at]dtrh[dot]net>)
# Summary: Windows persistence installer for global ROADMAP-AGENT access.
# Last updated: 2026-04-10 | Version: v0.1.0
# -------------------------------------------------------------------------------------------

$ErrorActionPreference = "Continue"

function Test-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Add-PathEntryIfMissing([string]$Scope, [string]$Entry) {
    $current = [Environment]::GetEnvironmentVariable("Path", $Scope)
    if (-not $current) { $current = "" }
    $parts = $current -split ";" | Where-Object { $_ -and $_.Trim() -ne "" }
    foreach ($p in $parts) {
        if ($p.TrimEnd('\') -ieq $Entry.TrimEnd('\')) { return $false }
    }
    $newPath = if ($current -and $current.Trim() -ne "") { "$current;$Entry" } else { $Entry }
    [Environment]::SetEnvironmentVariable("Path", $newPath, $Scope)
    return $true
}

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$installRoot = Join-Path ${env:ProgramFiles} "Roadmap-Agent"
$binDir = Join-Path $installRoot "bin"

if (-not (Test-IsAdmin)) {
    Write-Host "ERROR: Administrator privileges are required." -ForegroundColor Red
    Write-Host "Open PowerShell as Administrator, then run:" -ForegroundColor Yellow
    Write-Host "  pwsh -NoProfile -File `"$($MyInvocation.MyCommand.Path)`"" -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
New-Item -ItemType Directory -Path $binDir -Force | Out-Null

Copy-Item (Join-Path $root "scripts/windows/roadmap-agent.ps1") -Destination (Join-Path $installRoot "roadmap-agent.ps1") -Force
if (Test-Path (Join-Path $root "roadmap-agent.cmd")) {
    Copy-Item (Join-Path $root "roadmap-agent.cmd") -Destination (Join-Path $binDir "roadmap-agent.cmd") -Force
}
if (Test-Path (Join-Path $root "rma.cmd")) {
    Copy-Item (Join-Path $root "rma.cmd") -Destination (Join-Path $binDir "rma.cmd") -Force
}

$added = Add-PathEntryIfMissing -Scope "Machine" -Entry $binDir
if ($added) {
    Write-Host "Added to Machine PATH: $binDir" -ForegroundColor Green
} else {
    Write-Host "Machine PATH already contains: $binDir" -ForegroundColor Cyan
}

Write-Host "Persistence install complete." -ForegroundColor Green
Write-Host "Open a new terminal and run: roadmap-agent --help" -ForegroundColor Green
