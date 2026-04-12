#Requires -Version 5.1
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
# Summary: Windows bootstrap — .env seed, setup-local-models-mempalace.ps1, optional persistence prompt, then roadmap-agent.ps1.
# Notes: TOOLKIT_ROOT beside RUN.ps1; PROJECT_ROOT = Get-Location. #Requires must stay first line.
# Last updated: 2026-04-10 | Version: v1.1.0-beta

$ErrorActionPreference = "Stop"

$RunHelp = $false
$RunYes = $false
$pass = New-Object System.Collections.ArrayList
foreach ($a in $args) {
    if ($a -eq "-h" -or $a -eq "--help") {
        $RunHelp = $true
    } elseif ($a -eq "-y" -or $a -eq "--yes") {
        $RunYes = $true
    } else {
        [void]$pass.Add($a)
    }
}

if ($RunHelp) {
    @"
RUN.ps1 — ROADMAP-AGENT workspace bootstrap

  Prepares the current directory as ROADMAP_AGENT_PROJECT_ROOT:
    - Ensures .env from the toolkit .env.example (if missing)
    - Creates/updates .rma\venv, installs mempalace + chromadb, refreshes venv launchers
    - Optionally prompts if a local persistence install is older than this toolkit

  Then starts roadmap-agent.ps1 with your arguments (default: menu).

Usage:
  .\RUN.ps1 [options] [roadmap-agent arguments...]

Options:
  -h, --help     Show this help
  -y, --yes      Do not prompt for persistence upgrade (non-interactive)

Examples:
  .\RUN.ps1
  .\RUN.ps1 plan
  .\RUN.ps1 doctor
  .\RUN.ps1 mcp-start
  .\RUN.ps1 mcp-start --detach
  .\RUN.ps1 -y menu
"@
    exit 0
}

function Read-VersionLine {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = (Get-Content -LiteralPath $Path -TotalCount 1 -ErrorAction SilentlyContinue) -replace "`r", ""
    if (-not $raw) { return $null }
    return $raw.Trim()
}

function Normalize-VersionToken([string]$v) {
    if (-not $v) { return "" }
    if ($v.StartsWith("v")) { return $v.Substring(1) }
    return $v
}

function Test-VersionFileGreater {
    param([string]$NewerFile, [string]$OlderFile)
    $a = Normalize-VersionToken (Read-VersionLine $NewerFile)
    $b = Normalize-VersionToken (Read-VersionLine $OlderFile)
    if (-not $a -or -not $b) { return $false }
    if ($a -eq $b) { return $false }
    try {
        return ([version]$a -gt [version]$b)
    } catch {
        return ($a -gt $b)
    }
}

$ToolkitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Get-Location).Path

$env:ROADMAP_AGENT_APP_ROOT = $ToolkitRoot
$env:ROADMAP_AGENT_PROJECT_ROOT = $ProjectRoot
if (-not $env:PIP_DEFAULT_TIMEOUT) { $env:PIP_DEFAULT_TIMEOUT = "120" }

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

Write-Section "ROADMAP-AGENT bootstrap"
Write-Host ("  Toolkit:  {0}" -f $ToolkitRoot)
Write-Host ("  Project:  {0}" -f $ProjectRoot)
Write-Host ("  PowerShell: {0}" -f $PSVersionTable.PSVersion)
Write-Host ("  OS: {0}" -f [System.Environment]::OSVersion.VersionString)

if ($ToolkitRoot -eq $ProjectRoot) {
    Write-Host "  Mode: local checkout (toolkit and project are the same directory)." -ForegroundColor DarkGray
} else {
    Write-Host "  Mode: split layout (managing project from a separate ROADMAP-AGENT install)." -ForegroundColor Green
}

$tv = Read-VersionLine (Join-Path $ToolkitRoot "VERSION")
Write-Section "Toolkit version"
Write-Host ("  VERSION -> {0}" -f $(if ($tv) { $tv } else { "unknown" }))

$persistRoots = @()
$local = Join-Path ${env:LOCALAPPDATA} "Roadmap-Agent"
if (Test-Path -LiteralPath $local) { $persistRoots += $local }
$machine = Join-Path ${env:ProgramFiles} "Roadmap-Agent"
if (Test-Path -LiteralPath $machine) { $persistRoots += $machine }

Write-Section "Persistence / global install"
$persistPath = $null
$persistVer = $null
foreach ($pr in $persistRoots) {
    $vf = Join-Path $pr "VERSION"
    if (Test-Path -LiteralPath $vf) {
        $persistPath = $pr
        $persistVer = Read-VersionLine $vf
        break
    }
}

if ($persistPath) {
    Write-Host ("  Found: {0} (version {1})" -f $persistPath, $persistVer)
    $toolkitVerFile = Join-Path $ToolkitRoot "VERSION"
    if ((Test-Path -LiteralPath $toolkitVerFile) -and (Test-VersionFileGreater -NewerFile $toolkitVerFile -OlderFile (Join-Path $persistPath "VERSION"))) {
        Write-Host ("  This toolkit ({0}) is newer than the installed copy ({1})." -f $tv, $persistVer) -ForegroundColor Yellow
        if (-not $RunYes) {
            $ans = Read-Host "Run install-persistence.ps1 from this checkout now? (y/N)"
            if ($ans -eq "y" -or $ans -eq "Y") {
                $installer = Join-Path $ToolkitRoot "scripts\windows\install-persistence.ps1"
                if (Test-Path -LiteralPath $installer) {
                    & $installer
                } else {
                    Write-Host "Installer not found: $installer" -ForegroundColor Red
                }
            } else {
                Write-Host "Skipped. Later: .\scripts\windows\install-persistence.ps1" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  (-y) Skipping persistence upgrade prompt." -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  Persistence is current or newer than this checkout (or versions match)." -ForegroundColor Green
    }
} else {
    Write-Host "  No %LOCALAPPDATA%\Roadmap-Agent or Program Files install detected (optional)." -ForegroundColor DarkGray
}

Write-Section "Project .env"
$envDest = Join-Path $ProjectRoot ".env"
$envSrc = Join-Path $ToolkitRoot ".env.example"
if (Test-Path -LiteralPath $envDest) {
    Write-Host "  .env already exists — not modified." -ForegroundColor Green
} elseif (Test-Path -LiteralPath $envSrc) {
    Copy-Item -LiteralPath $envSrc -Destination $envDest
    Write-Host ("  Created .env from .env.example" ) -ForegroundColor Green
} else {
    Write-Host "  No .env.example in toolkit; create .env manually if needed." -ForegroundColor Yellow
}

Write-Section "Python virtual environment and MemPalace stack"
Write-Host ("  Log: {0}" -f (Join-Path $ProjectRoot ".rma\logs\setup-local-models.log")) -ForegroundColor DarkGray
$setup = Join-Path $ToolkitRoot "scripts\windows\setup-local-models-mempalace.ps1"
if (-not (Test-Path -LiteralPath $setup)) {
    Write-Host "ERROR: Missing $setup" -ForegroundColor Red
    exit 1
}
$ErrorActionPreference = "Continue"
& $setup
$setupExit = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($setupExit -ne 0) {
    Write-Host "Setup reported errors (exit $setupExit). See log under .rma\logs." -ForegroundColor Red
    exit $setupExit
}
Write-Host "  Venv and Python dependencies are ready." -ForegroundColor Green

Write-Section "Handoff"
$main = Join-Path $ToolkitRoot "scripts\windows\roadmap-agent.ps1"
if ($pass.Count -eq 0) {
    Write-Host "  Starting: roadmap-agent menu (default)" -ForegroundColor DarkGray
    & $main menu
} else {
    Write-Host ("  Starting: roadmap-agent {0}" -f ($pass -join " ")) -ForegroundColor DarkGray
    & $main @pass
}
exit $LASTEXITCODE
