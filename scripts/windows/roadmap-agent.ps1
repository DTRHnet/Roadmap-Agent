$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$cmd = if ($args.Count -gt 0) { $args[0].ToLowerInvariant() } else { "menu" }

if ($cmd -eq "persistence-check") {
    $installer = Join-Path $scriptDir "install-persistence.ps1"
    if (Test-Path $installer) {
        & $installer -CheckOnly
        exit $LASTEXITCODE
    }
    Write-Host "Installer not found: $installer" -ForegroundColor Red
    exit 1
}

if ($cmd -eq "persistence" -or $cmd -eq "persistance") {
    $installer = Join-Path $scriptDir "install-persistence.ps1"
    if (Test-Path $installer) {
        & $installer
        exit $LASTEXITCODE
    }
    Write-Host "Installer not found: $installer" -ForegroundColor Red
    exit 1
}

$unixRuntime = Join-Path $rootDir "scripts/unix/roadmap-agent.sh"
$bashCmd = Get-Command bash -ErrorAction SilentlyContinue
if ($bashCmd -and (Test-Path $unixRuntime)) {
    $runtimeBash = "/mnt/" + $unixRuntime.Substring(0,1).ToLower() + "/" + $unixRuntime.Substring(3).Replace('\','/')
    $cwd = (Get-Location).Path
    $cwdBash = "/mnt/" + $cwd.Substring(0,1).ToLower() + "/" + $cwd.Substring(3).Replace('\','/')
    $argText = ""
    if ($args.Count -gt 0) {
        $argText = ($args | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join " "
    }
    $scriptBlock = "export ROADMAP_AGENT_PROJECT_ROOT=""$cwdBash""; bash ""$runtimeBash"" $argText"
    & $bashCmd.Source -lc $scriptBlock
    exit $LASTEXITCODE
}

Write-Host "Windows fallback mode active." -ForegroundColor Yellow
Write-Host "Run persistence install, or install Git Bash to use full interactive runtime." -ForegroundColor Yellow
Write-Host "Command attempted: $cmd"
exit 0
