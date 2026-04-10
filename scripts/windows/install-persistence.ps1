# -------------------------------------------------------------------------------------------
# ROADMAP-AGENT | A DTRHnet Project (2026 <admin[at]dtrh[dot]net>)
# Summary: Windows persistence installer for global ROADMAP-AGENT access.
# Last updated: 2026-04-10 | Version: v0.1.0
# -------------------------------------------------------------------------------------------

param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Continue"

function Test-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
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

function Get-VersionFromChangelog([string]$PathValue) {
    if (-not (Test-Path $PathValue)) { return "" }
    $lines = Get-Content $PathValue -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if ($line -match '^## \[([^\]]+)\]') {
            $v = $Matches[1]
            if ($v -ne "Unreleased") { return $v }
        }
    }
    return ""
}

function Normalize-Version([string]$v) {
    if (-not $v) { return "" }
    if ($v.StartsWith("v")) { return $v.Substring(1) }
    return $v
}

function Test-VersionOlder([string]$Installed, [string]$Current) {
    $a = Normalize-Version $Installed
    $b = Normalize-Version $Current
    if (-not $a -or -not $b) { return $false }
    if ($a -eq $b) { return $false }
    try {
        return ([version]$a -lt [version]$b)
    } catch {
        return ($a -lt $b)
    }
}

function Test-FilesInSync([string]$SourceRoot, [string]$InstallRoot) {
    $files = @(
        "scripts\\unix\\roadmap-agent.sh",
        "scripts\\unix\\setup-local-models-mempalace.sh",
        "scripts\\windows\\roadmap-agent.ps1",
        "scripts\\windows\\install-persistence.ps1",
        "scripts\\windows\\setup-local-models-mempalace.ps1",
        "roadmap-agent",
        "roadmap-agent.cmd",
        "rma",
        "rma.cmd",
        "rma.ps1",
        "rma.sh"
    )
    foreach ($rel in $files) {
        $src = Join-Path $SourceRoot $rel
        $dst = Join-Path $InstallRoot $rel
        if (Test-Path $src) {
            if (-not (Test-Path $dst)) { return $false }
            try {
                $h1 = (Get-FileHash -Path $src -Algorithm SHA256).Hash
                $h2 = (Get-FileHash -Path $dst -Algorithm SHA256).Hash
                if ($h1 -ne $h2) { return $false }
            } catch {
                return $false
            }
        }
    }
    return $true
}

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$installRoot = Join-Path ${env:ProgramFiles} "Roadmap-Agent"
$binDir = Join-Path $installRoot "bin"
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$hasBinPath = $false
if ($machinePath) {
    foreach ($part in ($machinePath -split ";")) {
        if ($part.TrimEnd('\') -ieq $binDir.TrimEnd('\')) { $hasBinPath = $true; break }
    }
}
$hasCmd = [bool](Get-Command roadmap-agent.cmd -ErrorAction SilentlyContinue)
$hasAlias = [bool](Get-Command rma.cmd -ErrorAction SilentlyContinue)
$repoVer = Get-VersionFromChangelog (Join-Path $root "CHANGELOG.md")
if (-not $repoVer) { $repoVer = "unknown" }
$installedVer = Get-VersionFromChangelog (Join-Path $installRoot "CHANGELOG.md")
if (-not $installedVer) { $installedVer = "unknown" }
$isOlder = if ($installedVer -ne "unknown" -and $repoVer -ne "unknown") { Test-VersionOlder $installedVer $repoVer } else { $false }
$scriptsInSync = Test-FilesInSync -SourceRoot $root -InstallRoot $installRoot

if ($CheckOnly) {
    Write-Host "Persistence status"
    Write-Host "Expected bin path: $binDir"
    Write-Host "Machine PATH has bin: $hasBinPath"
    Write-Host "roadmap-agent.cmd found: $hasCmd"
    Write-Host "rma.cmd found: $hasAlias"
    Write-Host "Current repo version: $repoVer"
    Write-Host "Installed app version: $installedVer"
    Write-Host "Installed older than current: $isOlder"
    Write-Host "Installed scripts in sync: $scriptsInSync"

    if ($hasBinPath -and $hasCmd -and $hasAlias -and -not $isOlder -and $scriptsInSync) {
        Write-Host "Persistence already present and current." -ForegroundColor Green
        exit 0
    }
    if (-not $scriptsInSync) {
        $prompt = "Installed persistence scripts differ from current app. Upgrade/sync now? (y/N)"
    } elseif ($isOlder) {
        $prompt = "Installed persistence is older than current version. Upgrade now? (y/N)"
    } else {
        $prompt = "Persistence appears missing. Install now? (y/N)"
    }
    $ans = (Read-Host $prompt).Trim().ToLower()
    if ($ans -notmatch "^(y|yes)$") {
        Write-Host "Skipped persistence install."
        exit 0
    }
}

if (-not (Test-IsAdmin)) {
    Write-Host "ERROR: Administrator privileges are required." -ForegroundColor Red
    Write-Host "Open PowerShell as Administrator, then run:" -ForegroundColor Yellow
    Write-Host "  pwsh -NoProfile -File `"$($MyInvocation.MyCommand.Path)`"" -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
New-Item -ItemType Directory -Path $binDir -Force | Out-Null
# Sync full app tree so global launchers never miss dependencies.
# /MIR keeps install current; excludes runtime workspace/state folders.
$null = robocopy $root $installRoot /MIR /R:1 /W:1 /XD ".git" ".rma" ".cursor" /NFL /NDL /NJH /NJS /NC /NS
if ($LASTEXITCODE -ge 8) {
    Write-Host "ERROR: Failed to mirror repository into $installRoot (robocopy exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

# Write deterministic launchers that always point to installed app.
@"
@echo off
setlocal
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$installRoot\scripts\windows\roadmap-agent.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "$installRoot\scripts\windows\roadmap-agent.ps1" %*
)
"@ | Set-Content (Join-Path $binDir "roadmap-agent.cmd")

@"
@echo off
setlocal
call "$binDir\roadmap-agent.cmd" %*
"@ | Set-Content (Join-Path $binDir "rma.cmd")

$added = Add-PathEntryIfMissing -Scope "Machine" -Entry $binDir
if ($added) {
    Write-Host "Added to Machine PATH: $binDir" -ForegroundColor Green
} else {
    Write-Host "Machine PATH already contains: $binDir" -ForegroundColor Cyan
}

Write-Host "Persistence install complete." -ForegroundColor Green
Write-Host "Open a new terminal and run: roadmap-agent --help" -ForegroundColor Green
