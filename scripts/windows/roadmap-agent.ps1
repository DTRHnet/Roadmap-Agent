$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$cmd = if ($args.Count -gt 0) { $args[0].ToLowerInvariant() } else { "menu" }

function Convert-ToBashPath([string]$PathValue) {
    $p = $PathValue.Replace('\', '/')
    if ($p -match '^([A-Za-z]):/(.*)$') {
        return "/mnt/$($matches[1].ToLower())/$($matches[2])"
    }
    return $p
}

function ConvertTo-BashArg([string]$v) {
    return '"' + ($v -replace '"', '\"') + '"'
}

if ($cmd -eq "persistence" -or $cmd -eq "persistance" -or $cmd -eq "persistence-check") {
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
    $runtimeBash = Convert-ToBashPath $unixRuntime
    $cwdBash = Convert-ToBashPath ((Get-Location).Path)
    $argText = ""
    if ($args.Count -gt 0) {
        $argText = ($args | ForEach-Object { ConvertTo-BashArg $_ }) -join " "
    }
    $scriptBlock = "export ROADMAP_AGENT_PROJECT_ROOT=$(ConvertTo-BashArg $cwdBash); bash $(ConvertTo-BashArg $runtimeBash) $argText"
    & $bashCmd.Source -lc $scriptBlock
    exit $LASTEXITCODE
}

Write-Host "Windows fallback mode active." -ForegroundColor Yellow
Write-Host "Run persistence install, or install Git Bash to use full interactive runtime." -ForegroundColor Yellow
Write-Host "Command attempted: $cmd"
exit 0
