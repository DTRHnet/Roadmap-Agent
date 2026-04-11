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
# Summary: Rebuilds $env:Path in the current PowerShell from Machine + User registry (post-install helper).
# Notes: Does not persist changes; open a new terminal if other shells need the same PATH.
# Last updated: 2026-04-10 | Version: v1.0.0

param(
    [switch]$Quiet
)

$machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
if (-not $machine) { $machine = "" }
$user = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $user) { $user = "" }

$parts = @()
if ($machine.Trim()) { $parts += $machine.TrimEnd(';') }
if ($user.Trim()) { $parts += $user.TrimEnd(';') }
$env:Path = ($parts -join ";")

if (-not $Quiet) {
    Write-Host "PATH refreshed from Machine + User environment (this session)." -ForegroundColor Green
}

$rma = Get-Command rma.cmd -ErrorAction SilentlyContinue
if (-not $Quiet) {
    if ($rma) {
        Write-Host ("rma.cmd -> {0}" -f $rma.Source) -ForegroundColor Cyan
    } else {
        Write-Host "rma.cmd not on PATH yet. Open a new terminal or run persistence setup." -ForegroundColor Yellow
    }
}
