#Requires -Version 5.1
# '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#  ROADMAP-AGENT — rma_cli: status dashboard + delegate to RUN.ps1
#  Toolkit root = this script's directory; project root = Get-Location.
#  Last updated: 2026-04-11
# '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

$ErrorActionPreference = "Stop"

$StatusOnly = $false
$Quiet = $false
$pass = New-Object System.Collections.ArrayList
foreach ($a in $args) {
    if ($a -eq "-h" -or $a -eq "--help") {
        @"
rma_cli.ps1 — show service/toolkit status, then run RUN.ps1 (bootstrap + roadmap-agent).

Usage:
  .\rma_cli.ps1 [options] [RUN.ps1 arguments...]

Options:
  -h, --help       This help
  --status-only    Print dashboard and exit
  --quiet          Skip dashboard; pass arguments to RUN.ps1

With no arguments: print dashboard and usage (does not start the menu).

Examples:
  .\rma_cli.ps1 --status-only
  .\rma_cli.ps1 plan
  .\rma_cli.ps1 agent `"your goal`"
"@
        exit 0
    } elseif ($a -eq "--status-only") {
        $StatusOnly = $true
    } elseif ($a -eq "--quiet") {
        $Quiet = $true
    } else {
        [void]$pass.Add($a)
    }
}

$ToolkitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Get-Location).Path
$env:ROADMAP_AGENT_APP_ROOT = $ToolkitRoot
$env:ROADMAP_AGENT_PROJECT_ROOT = $ProjectRoot

function Import-DotenvKeys {
    $envFile = Join-Path $ProjectRoot ".env"
    if (-not (Test-Path -LiteralPath $envFile)) { return }
    $known = @(
        "RMA_LLM_PROVIDER", "RMA_OLLAMA_MODEL", "RMA_OLLAMA_HOST",
        "RMA_OPENAI_BASE_URL", "RMA_OPENAI_API_KEY", "RMA_OPENAI_MODEL", "RMA_CLAUDE_MODEL",
        "RMA_REQUIRE_OLLAMA", "RMA_WEB_HOST", "RMA_WEB_PORT", "RMA_WEB_VITE_PORT",
        "RMA_MCP_PORT", "RMA_MCP_HOST",
        "RMA_AGENT_LEGACY", "RMA_AGENT_SKIP_REFLECT", "RMA_AGENT_REFLECT_RETRIES"
    )
    Get-Content -LiteralPath $envFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $eq = $line.IndexOf("=")
        if ($eq -lt 1) { return }
        $k = $line.Substring(0, $eq).Trim()
        if ($known -notcontains $k) { return }
        $v = $line.Substring($eq + 1).Trim()
        if ($v.StartsWith("`"") -and $v.EndsWith("`"")) { $v = $v.Substring(1, $v.Length - 2) }
        elseif ($v.StartsWith("'") -and $v.EndsWith("'")) { $v = $v.Substring(1, $v.Length - 2) }
        Set-Item -Path "env:$k" -Value $v
    }
}

Import-DotenvKeys

function Show-RmaCliDashboard {
    Write-Host ""
    Write-Host "=== ROADMAP-AGENT — rma_cli ===" -ForegroundColor Cyan
    Write-Host ("  Project:  {0}" -f $ProjectRoot)
    Write-Host ("  Toolkit:  {0}" -f $ToolkitRoot)

    $prov = if ($env:RMA_LLM_PROVIDER) { $env:RMA_LLM_PROVIDER } else { "ollama" }
    $model = if ($env:RMA_OLLAMA_MODEL) { $env:RMA_OLLAMA_MODEL } else { "llama3.1:latest" }
    Write-Host ("  LLM:      {0} (model {1})" -f $prov, $model)

    $oh = if ($env:RMA_OLLAMA_HOST) { $env:RMA_OLLAMA_HOST.TrimEnd('/') } else { "http://127.0.0.1:11434" }
    try {
        $u = $oh + "/api/tags"
        Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop | Out-Null
        Write-Host "  [ok] Ollama HTTP reachable at $oh" -ForegroundColor Green
    } catch {
        Write-Host "  [--] Ollama HTTP not reachable at $oh (non-fatal)" -ForegroundColor Yellow
    }

    $wh = if ($env:RMA_WEB_HOST) { $env:RMA_WEB_HOST } else { "127.0.0.1" }
    if ($wh -eq "0.0.0.0") { $wh = "127.0.0.1" }
    $wp = if ($env:RMA_WEB_PORT) { $env:RMA_WEB_PORT } else { "8765" }
    try {
        Invoke-WebRequest -Uri "http://${wh}:${wp}/docs" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop | Out-Null
        Write-Host ("  [ok] Web API responding on {0}:{1}" -f $wh, $wp) -ForegroundColor Green
    } catch {
        try {
            Invoke-WebRequest -Uri "http://${wh}:${wp}/api/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop | Out-Null
            Write-Host ("  [ok] Web API health on {0}:{1}" -f $wh, $wp) -ForegroundColor Green
        } catch {
            Write-Host ("  [--] Web API not listening on {0}:{1}" -f $wh, $wp) -ForegroundColor Yellow
        }
    }

    $mcpJson = Join-Path $ProjectRoot ".rma\mcp\runtime.json"
    if (Test-Path -LiteralPath $mcpJson) {
        Write-Host "  [ok] MCP runtime file: $mcpJson" -ForegroundColor Green
    } else {
        Write-Host "  [--] MCP not started (no .rma\mcp\runtime.json)" -ForegroundColor Yellow
    }

    $py = $null
    $venvPy = Join-Path $ProjectRoot ".rma\venv\Scripts\python.exe"
    if (Test-Path -LiteralPath $venvPy) { $py = $venvPy }
    if (-not $py) {
        $venvPy2 = Join-Path $ProjectRoot ".rma\venv\bin\python"
        if (Test-Path -LiteralPath $venvPy2) { $py = $venvPy2 }
    }
    if (-not $py) {
        $py = (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
        if (-not $py) { $py = (Get-Command python3 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source) }
    }
    $env:PYTHONPATH = $ToolkitRoot + $(if ($env:PYTHONPATH) { ";$($env:PYTHONPATH)" } else { "" })
    if ($py) {
        $chk = & $py -c "import pydantic, rma_agent" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [ok] rma_agent + pydantic ($py)" -ForegroundColor Green
        } else {
            Write-Host "  [--] rma_agent not importable — pip install -r $ToolkitRoot\requirements-agent.txt" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [--] Python not found" -ForegroundColor Yellow
    }

    $al = if ($env:RMA_AGENT_LEGACY) { $env:RMA_AGENT_LEGACY } else { "0" }
    $sr = if ($env:RMA_AGENT_SKIP_REFLECT) { $env:RMA_AGENT_SKIP_REFLECT } else { "0" }
    $rr = if ($env:RMA_AGENT_REFLECT_RETRIES) { $env:RMA_AGENT_REFLECT_RETRIES } else { "1" }
    Write-Host ("  Agent env: RMA_AGENT_LEGACY={0} RMA_AGENT_SKIP_REFLECT={1} RMA_AGENT_REFLECT_RETRIES={2}" -f $al, $sr, $rr) -ForegroundColor DarkGray
}

if ($StatusOnly) {
    Show-RmaCliDashboard
    exit 0
}

if ($Quiet) {
    $run = Join-Path $ToolkitRoot "RUN.ps1"
    & $run @pass
    exit $LASTEXITCODE
}

if ($pass.Count -eq 0) {
    Show-RmaCliDashboard
    Write-Host ""
    Write-Host "Usage: .\rma_cli.ps1 [--status-only] [--quiet] [RUN.ps1 args...]"
    Write-Host "Example: .\rma_cli.ps1 plan"
    exit 0
}

Show-RmaCliDashboard
$runPs1 = Join-Path $ToolkitRoot "RUN.ps1"
& $runPs1 @pass
exit $LASTEXITCODE
