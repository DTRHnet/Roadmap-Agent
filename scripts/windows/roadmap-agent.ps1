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
# Summary: Windows bridge — invokes scripts/unix/roadmap-agent.sh via bash (WSL/Git Bash); persistence and tools subcommands stay native.
# Notes: Resolves repo root two levels above this file; sets ROADMAP_AGENT_PROJECT_ROOT from cwd for WSL. Normalizes CRLF shims when needed.
# Last updated: 2026-04-10 | Version: v1.0.0

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$cmd = if ($args.Count -gt 0) { $args[0].ToLowerInvariant() } else { "menu" }

if ($cmd -eq "tools") {
    $json = ($args.Count -gt 1 -and $args[1] -eq "--json")
    if ($json) {
        '{"commands":["init","status","doctor","plan","analyze","analyze-init","execute-one","agent","run-agent","tools","unlock","menu","persistence","persistence-check","setup-venv","pick-env","web-api","web-backend","web-frontend","release","man","help"],"agent_actions":["plan","analyze","execute-one","status","unlock","shell","reflect","stop"],"env":["RMA_LLM_PROVIDER","RMA_OLLAMA_MODEL","RMA_OLLAMA_HOST","RMA_OPENAI_BASE_URL","RMA_OPENAI_MODEL","RMA_OPENAI_API_KEY","RMA_CLAUDE_MODEL","RMA_REQUIRE_OLLAMA","RMA_REQUIRE_MEMPALACE","RMA_MEMPALACE_BIN","RMA_MEMPALACE_MINE_DIR","RMA_ALLOW_PLAN_FALLBACK","RMA_PLAN_INTERACTIVE","RMA_PLAN_INTERACTIVE_MAX","RMA_PYTHON_VENV_DIR","RMA_DISABLE_FZF","RMA_RELEASE_IMAGE_NAME","ANTHROPIC_API_KEY","OPENAI_API_KEY","GITHUB_TOKEN","ROADMAP_AGENT_PROJECT_ROOT","ROADMAP_AGENT_APP_ROOT"]}'
    } else {
        @"
ROADMAP-AGENT tool manifest (for humans and external agents)

CLI commands:
  init, status, doctor, plan, analyze, analyze-init, execute-one, agent, run-agent,
  tools [--json], unlock, menu, persistence, persistence-check, setup-venv, pick-env,
  web-api | web-backend, web-frontend, man, help

See README.md and scripts/unix/roadmap-agent.sh for full behavior.
"@
    }
    exit 0
}

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

function ConvertTo-WslBashPath([string]$WindowsPath) {
    if ($WindowsPath -match '^([A-Za-z]):[\\/](.*)$') {
        $drive = $Matches[1].ToLower()
        $tail = $Matches[2] -replace '\\', '/'
        return "/mnt/$drive/$tail"
    }
    return ($WindowsPath -replace '\\', '/')
}

$unixRuntime = Join-Path $rootDir "scripts/unix/roadmap-agent.sh"
$bashCmd = Get-Command bash -ErrorAction SilentlyContinue
if ($bashCmd -and (Test-Path $unixRuntime)) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $runtimePath = $unixRuntime
    $tempRuntime = $null
    $scriptText = [IO.File]::ReadAllText($unixRuntime)
    if ($scriptText.IndexOf("`r") -ge 0) {
        $normalized = $scriptText -replace "`r`n", "`n" -replace "`r", "`n"
        $tempRuntime = Join-Path ([IO.Path]::GetTempPath()) ("rma-roadmap-agent-" + $PID + ".sh")
        [IO.File]::WriteAllText($tempRuntime, $normalized, $utf8NoBom)
        $runtimePath = $tempRuntime
        Write-Host "NOTE: roadmap-agent.sh had CRLF line endings; using a normalized copy for bash. Re-run persistence install to fix files under Local/Roadmap-Agent." -ForegroundColor DarkYellow
    }
    $exitCode = 1
    try {
        $runtimeBash = ConvertTo-WslBashPath $runtimePath
        $cwdBash = ConvertTo-WslBashPath (Get-Location).Path
        $argText = ""
        if ($args.Count -gt 0) {
            $argText = ($args | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join " "
        }
        $scriptBlock = "export ROADMAP_AGENT_PROJECT_ROOT=""$cwdBash""; bash ""$runtimeBash"" $argText"
        & $bashCmd.Source -lc $scriptBlock
        $exitCode = $LASTEXITCODE
    } finally {
        if ($null -ne $tempRuntime -and (Test-Path -LiteralPath $tempRuntime)) {
            Remove-Item -LiteralPath $tempRuntime -Force -ErrorAction SilentlyContinue
        }
    }
    exit $exitCode
}

Write-Host "Windows fallback mode active." -ForegroundColor Yellow
Write-Host "Run persistence install, or install Git Bash to use full interactive runtime." -ForegroundColor Yellow
Write-Host "Command attempted: $cmd"
exit 0
