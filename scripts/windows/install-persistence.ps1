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
# Summary: Mirrors toolkit into LocalAppData/ProgramFiles, updates PATH, normalizes LF on *.sh for WSL.
# Notes: Uses robocopy /MIR; calls refresh-rma-path.ps1 in this folder after success. Scope User vs Machine.
# Last updated: 2026-04-10 | Version: v1.0.0

param(
    [switch]$CheckOnly,
    [ValidateSet("Auto","User","Machine")]
    [string]$Scope = "Auto"
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

function Resolve-InstallScope([string]$RequestedScope) {
    if ($RequestedScope -eq "User") { return "User" }
    if ($RequestedScope -eq "Machine") { return "Machine" }
    if (Test-IsAdmin) { return "Machine" }
    return "User"
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

function Sync-UnixShellScriptsToLf([string]$InstallRoot) {
    # Robocopy from a Windows repo with core.autocrlf=true can copy CRLF into *.sh; bash then fails with $'\r'.
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $unixDir = Join-Path $InstallRoot "scripts\unix"
    if (Test-Path $unixDir) {
        Get-ChildItem -Path $unixDir -Filter "*.sh" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $text = [IO.File]::ReadAllText($_.FullName)
            if ($text.Contains("`r")) {
                $fixed = $text -replace "`r`n", "`n" -replace "`r", "`n"
                [IO.File]::WriteAllText($_.FullName, $fixed, $utf8NoBom)
            }
        }
    }
    $dockerEntry = Join-Path $InstallRoot "docker\entrypoint.sh"
    if (Test-Path $dockerEntry) {
        $text = [IO.File]::ReadAllText($dockerEntry)
        if ($text.Contains("`r")) {
            $fixed = $text -replace "`r`n", "`n" -replace "`r", "`n"
            [IO.File]::WriteAllText($dockerEntry, $fixed, $utf8NoBom)
        }
    }
    foreach ($name in @("launchers\roadmap-agent", "launchers\rma", "launchers\rma.sh", "RUN.sh")) {
        $p = Join-Path $InstallRoot $name
        if (Test-Path $p -PathType Leaf) {
            $text = [IO.File]::ReadAllText($p)
            if ($text.Contains("`r")) {
                $fixed = $text -replace "`r`n", "`n" -replace "`r", "`n"
                [IO.File]::WriteAllText($p, $fixed, $utf8NoBom)
            }
        }
    }
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
        "scripts\\unix\\release-rma.sh",
        "scripts\\windows\\roadmap-agent.ps1",
        "scripts\\windows\\install-persistence.ps1",
        "scripts\\windows\\refresh-rma-path.ps1",
        "scripts\\windows\\setup-rma.ps1",
        "scripts\\windows\\setup-local-models-mempalace.ps1",
        "launchers\\roadmap-agent",
        "launchers\\roadmap-agent.cmd",
        "launchers\\rma",
        "launchers\\rma.cmd",
        "launchers\\rma.ps1",
        "launchers\\rma.sh",
        "launchers\\setup-rma.ps1",
        "launchers\\setup-rma.cmd",
        "launchers\\refresh-rma-path.ps1",
        "RUN.sh",
        "RUN.ps1",
        "RUN.cmd",
        "VERSION"
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

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$effectiveScope = Resolve-InstallScope $Scope
$installRoot = if ($effectiveScope -eq "Machine") { Join-Path ${env:ProgramFiles} "Roadmap-Agent" } else { Join-Path ${env:LOCALAPPDATA} "Roadmap-Agent" }
$binDir = Join-Path $installRoot "bin"
$pathScope = if ($effectiveScope -eq "Machine") { "Machine" } else { "User" }
$scopePath = [Environment]::GetEnvironmentVariable("Path", $pathScope)
$hasBinPath = $false
if ($scopePath) {
    foreach ($part in ($scopePath -split ";")) {
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
    Write-Host "Scope: $effectiveScope"
    Write-Host "Expected bin path: $binDir"
    Write-Host "$pathScope PATH has bin: $hasBinPath"
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
    if ($effectiveScope -eq "Machine") {
        Write-Host "ERROR: Administrator privileges are required for Machine scope." -ForegroundColor Red
        Write-Host "Retry as admin, or run with user scope:" -ForegroundColor Yellow
        Write-Host "  pwsh -NoProfile -File `"$($MyInvocation.MyCommand.Path)`" -Scope User" -ForegroundColor Yellow
        exit 1
    }
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
# Sync full app tree so global launchers never miss dependencies.
# /MIR keeps install current; excludes runtime workspace/state folders.
$null = robocopy $root $installRoot /MIR /R:1 /W:1 /XD ".git" ".rma" ".cursor" /NFL /NDL /NJH /NJS /NC /NS
if ($LASTEXITCODE -ge 8) {
    Write-Host "ERROR: Failed to mirror repository into $installRoot (robocopy exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

Sync-UnixShellScriptsToLf -InstallRoot $installRoot

# Ensure bin dir exists after mirror (robocopy /MIR may remove it).
New-Item -ItemType Directory -Path $binDir -Force | Out-Null

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
if (-not (Test-Path (Join-Path $binDir "roadmap-agent.cmd"))) {
    Write-Host "ERROR: Failed to create launcher: $binDir\roadmap-agent.cmd" -ForegroundColor Red
    exit 1
}

@"
@echo off
setlocal
call "$binDir\roadmap-agent.cmd" %*
"@ | Set-Content (Join-Path $binDir "rma.cmd")
if (-not (Test-Path (Join-Path $binDir "rma.cmd"))) {
    Write-Host "ERROR: Failed to create launcher: $binDir\rma.cmd" -ForegroundColor Red
    exit 1
}

$added = Add-PathEntryIfMissing -Scope $pathScope -Entry $binDir
if ($added) {
    Write-Host "Added to $pathScope PATH: $binDir" -ForegroundColor Green
} else {
    Write-Host "$pathScope PATH already contains: $binDir" -ForegroundColor Cyan
}

Write-Host "Persistence install complete." -ForegroundColor Green
$refresh = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "refresh-rma-path.ps1"
if (Test-Path $refresh) {
    & $refresh -Quiet
    Write-Host "Current session PATH updated — try: rma --help" -ForegroundColor Cyan
} else {
    Write-Host "Open a new terminal and run: roadmap-agent --help" -ForegroundColor Green
}
$global:LASTEXITCODE = 0
