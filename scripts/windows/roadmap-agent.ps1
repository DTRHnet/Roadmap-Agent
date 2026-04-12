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
# Summary: Windows bridge — invokes scripts/unix/roadmap-agent.sh via bash (WSL/Git Bash); persistence* and tools stay native PowerShell.
# Notes: Resolves repo root two levels above this file; sets ROADMAP_AGENT_PROJECT_ROOT from cwd for bash. Persistence install is PowerShell-only (no WSL).
# Last updated: 2026-04-10 | Version: v1.1.1-b

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$cmd = if ($args.Count -gt 0) { $args[0].ToLowerInvariant() } else { "menu" }

if ($cmd -eq "tools") {
    $json = ($args.Count -gt 1 -and $args[1] -eq "--json")
    if ($json) {
        '{"commands":["init","status","doctor","plan","analyze","analyze-init","execute-one","agent","run-agent","tools","unlock","menu","persistence","persistence-check","setup-venv","pick-env","web-api","web-backend","web-frontend","mcp-start","release","man","help"],"agent_actions":["plan","analyze","execute-one","status","unlock","shell","reflect","stop"],"env":["RMA_LLM_PROVIDER","RMA_OLLAMA_MODEL","RMA_OLLAMA_HOST","RMA_OPENAI_BASE_URL","RMA_OPENAI_MODEL","RMA_OPENAI_API_KEY","RMA_CLAUDE_MODEL","RMA_REQUIRE_OLLAMA","RMA_REQUIRE_MEMPALACE","RMA_MEMPALACE_BIN","RMA_MEMPALACE_MINE_DIR","RMA_ALLOW_PLAN_FALLBACK","RMA_PLAN_INTERACTIVE","RMA_PLAN_INTERACTIVE_MAX","RMA_ANALYZE_USE_LLM","RMA_PYTHON_VENV_DIR","RMA_DISABLE_FZF","RMA_RELEASE_IMAGE_NAME","RMA_WEB_HOST","RMA_WEB_PORT","RMA_WEB_VITE_PORT","RMA_WEB_FREE_PORT_ASK","RMA_WEB_VITE_PROXY_TARGET","RMA_MCP_TRANSPORT","RMA_MCP_HOST","RMA_MCP_PORT","RMA_MCP_NAME","RMA_MCP_MAX_STEPS","RMA_MCP_ALLOW_SHELL","RMA_MCP_PROJECT_ROOT","RMA_MCP_LOG","RMA_MCP_DETACH","RMA_MCP_FORCE","RMA_AGENT_LEGACY","RMA_AGENT_SKIP_REFLECT","RMA_AGENT_REFLECT_RETRIES","ANTHROPIC_API_KEY","OPENAI_API_KEY","GITHUB_TOKEN","ROADMAP_AGENT_PROJECT_ROOT","ROADMAP_AGENT_APP_ROOT"]}'
    } else {
        @"
ROADMAP-AGENT tool manifest (for humans and external agents)

CLI commands:
  init, status, doctor, plan, analyze, analyze-init, execute-one, agent, run-agent,
  tools [--json], unlock, menu, persistence, persistence-check, setup-venv, pick-env,
  web-api | web-backend, web-frontend, mcp-start, man, help

See README.md and scripts/unix/roadmap-agent.sh for full behavior.
"@
    }
    exit 0
}

function Convert-PersistenceArgsToInstaller {
    param([object[]]$ArgList)
    $out = [System.Collections.Generic.List[string]]::new()
    $i = 0
    while ($i -lt $ArgList.Count) {
        $a = [string]$ArgList[$i]
        if ($a -eq "--user" -or $a -eq "-u") {
            $out.Add("-Scope"); $out.Add("User")
        } elseif ($a -eq "--system" -or $a -eq "--global") {
            $out.Add("-Scope"); $out.Add("Machine")
        } else {
            $out.Add($a)
        }
        $i++
    }
    return ,$out.ToArray()
}

if ($cmd -eq "persistence-check") {
    $installer = Join-Path $scriptDir "install-persistence.ps1"
    if (Test-Path $installer) {
        $extra = @()
        if ($args.Count -gt 1) {
            $extra = Convert-PersistenceArgsToInstaller -ArgList $args[1..($args.Count - 1)]
        }
        & $installer -CheckOnly @extra
        exit $LASTEXITCODE
    }
    Write-Host "Installer not found: $installer" -ForegroundColor Red
    exit 1
}

if ($cmd -eq "persistence" -or $cmd -eq "persistance") {
    if ($args.Count -gt 1 -and ($args[1] -eq "-h" -or $args[1] -eq "--help")) {
        @"
Windows persistence (PowerShell — no WSL required for install)

  Mirrors the toolkit under your profile and adds launchers to PATH:
    User scope:    %LOCALAPPDATA%\Roadmap-Agent\bin  (no Administrator)
    Machine scope: under Program Files (run elevated; use -Scope Machine)

  Examples (from a clone, or after install from any shell on PATH):
    rma persistence --user
    rma persistence -Scope User
    rma persistence -Scope Machine

  Equivalent convenience script: .\launchers\setup-rma.ps1 -Scope User

  Then: cd to your project and run  rma init

  Note: After install, rma / roadmap-agent still invoke bash (Git Bash or WSL) when
  available for the full hub, plan, analyze, etc. Install persistence does not require bash.
"@
        exit 0
    }
    $installer = Join-Path $scriptDir "install-persistence.ps1"
    if (Test-Path $installer) {
        $extra = @()
        if ($args.Count -gt 1) {
            $extra = Convert-PersistenceArgsToInstaller -ArgList $args[1..($args.Count - 1)]
        }
        & $installer @extra
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
        $rootBash = ConvertTo-WslBashPath $rootDir
        $cwdBash = ConvertTo-WslBashPath (Get-Location).Path
        $argText = ""
        if ($args.Count -gt 0) {
            $argText = ($args | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join " "
        }
        # Always set toolkit root: CRLF normalization uses a temp copy under Local/Temp; inferring APP_DIR
        # from BASH_SOURCE would wrongly resolve to .../AppData. RUN.ps1 / rma_cli.ps1 already export this.
        $scriptBlock = "export RMA_WINDOWS_BRIDGE=1; export ROADMAP_AGENT_APP_ROOT=""$rootBash""; export ROADMAP_AGENT_PROJECT_ROOT=""$cwdBash""; bash ""$runtimeBash"" $argText"
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
