#!/usr/bin/env pwsh
#Requires -Version 7
# Thin launcher for sysinfo.py (PowerShell 7+). Same args as the Python script.
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Py = Get-Command python -ErrorAction SilentlyContinue
if (-not $Py) {
    $Py = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $Py) {
    Write-Error "sysinfo.ps1: python not on PATH"
    exit 127
}
& $Py.Source (Join-Path $ScriptDir "sysinfo.py") @args
exit $LASTEXITCODE
