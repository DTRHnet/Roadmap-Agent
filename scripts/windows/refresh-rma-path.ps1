# Refreshes PATH in the current PowerShell session from Machine + User registry values.
# Use after installers (e.g. persistence) update PATH so `rma` works without opening a new terminal.

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
