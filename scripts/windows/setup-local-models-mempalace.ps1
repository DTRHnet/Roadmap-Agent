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
# Summary: Windows helper — venv under project, pip install mempalace/chromadb, venv Scripts launchers for rma.
# Notes: ROOT_DIR from ROADMAP_AGENT_PROJECT_ROOT when set; TOOLKIT_ROOT from script path. Launchers call scripts/windows/roadmap-agent.ps1 with project cd.
# Last updated: 2026-04-10 | Version: v1.0.0

$ErrorActionPreference = "Continue"

$ToolkitRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
if ($env:ROADMAP_AGENT_PROJECT_ROOT -and (Test-Path -LiteralPath $env:ROADMAP_AGENT_PROJECT_ROOT)) {
    $RootDir = (Resolve-Path -LiteralPath $env:ROADMAP_AGENT_PROJECT_ROOT).Path
} else {
    $RootDir = $ToolkitRoot
}
$LogDir = Join-Path $RootDir ".rma/logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir "setup-local-models.log"

$script:Failures = 0
$script:Warnings = 0

function Write-Log([string]$Level, [string]$Message) {
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format o), $Level, $Message
    Add-Content -Path $LogFile -Value $line
    switch ($Level) {
        "ERROR" { Write-Host $line -ForegroundColor Red }
        "WARN"  { Write-Host $line -ForegroundColor Yellow }
        default { Write-Host $line -ForegroundColor Cyan }
    }
}

function Install-RmaVenvLaunchers {
    param(
        [string]$ProjectRoot,
        [string]$VenvDir,
        [string]$ToolkitRoot
    )
    $scriptsOut = Join-Path $VenvDir "Scripts"
    if (-not (Test-Path -LiteralPath $scriptsOut)) { return }
    $bridge = Join-Path $ToolkitRoot "scripts\windows\roadmap-agent.ps1"
    if (-not (Test-Path -LiteralPath $bridge)) {
        Write-Log "WARN" "Skipping venv launchers: missing $bridge"
        return
    }
    $root = $ProjectRoot.TrimEnd('\')
    foreach ($name in @("rma", "roadmap-agent")) {
        $cmdPath = Join-Path $scriptsOut ("{0}.cmd" -f $name)
        $cmdBody = @"
@echo off
setlocal
cd /d "$root"
powershell -NoProfile -ExecutionPolicy Bypass -File "$bridge" %*
"@
        Set-Content -LiteralPath $cmdPath -Value $cmdBody -Encoding ASCII
        $ps1Path = Join-Path $scriptsOut ("{0}.ps1" -f $name)
        $ps1Body = @"
Set-Location -LiteralPath '$($root -replace "'", "''")'
& '$($bridge -replace "'", "''")' @args
exit `$LASTEXITCODE
"@
        Set-Content -LiteralPath $ps1Path -Value $ps1Body -Encoding UTF8
    }
    Write-Log "INFO" ("Installed venv launchers in {0}: rma.cmd, roadmap-agent.cmd (+ .ps1)" -f $scriptsOut)
}

function Resolve-PythonCommand {
    if (Get-Command python -ErrorAction SilentlyContinue) { return "python" }
    if (Get-Command python3 -ErrorAction SilentlyContinue) { return "python3" }
    return ""
}

Write-Log "INFO" "Starting local model setup for MemPalace."
Write-Log "INFO" ("Project root: {0}" -f $RootDir)
Write-Log "INFO" ("Log file: {0}" -f $LogFile)

$pythonCmd = Resolve-PythonCommand
if (-not $pythonCmd) {
    Write-Log "ERROR" "Python was not found in PATH. Install Python 3.10+ and rerun."
    $script:Failures++
} else {
    $venvDir = if ($env:RMA_PYTHON_VENV_DIR) {
        if ([System.IO.Path]::IsPathRooted($env:RMA_PYTHON_VENV_DIR)) {
            $env:RMA_PYTHON_VENV_DIR
        } else {
            Join-Path $RootDir $env:RMA_PYTHON_VENV_DIR
        }
    } else {
        Join-Path $RootDir ".rma\venv"
    }
    $venvPython = Join-Path $venvDir "Scripts\python.exe"
    $venvActivate = Join-Path $venvDir "Scripts\Activate.ps1"

    Write-Log "INFO" ("Host Python interpreter: {0}" -f $pythonCmd)
    Write-Log "INFO" ("Virtual environment target: {0}" -f $venvDir)
    if (-not (Test-Path $venvPython)) {
        Write-Log "INFO" "Creating project virtual environment..."
        try {
            & $pythonCmd -m venv $venvDir | Out-Null
        } catch {
            Write-Log "ERROR" ("Failed to create virtual environment at {0}" -f $venvDir)
            $script:Failures++
        }
    } else {
        Write-Log "INFO" "Virtual environment already exists. Reusing it."
    }

    if (Test-Path $venvPython) {
        $pythonCmd = $venvPython
        $venvScripts = Join-Path $venvDir "Scripts"
        $env:VIRTUAL_ENV = $venvDir
        $env:Path = "$venvScripts;$env:Path"
        Write-Log "INFO" "Activated virtual environment context for this setup session."
        if (Test-Path $venvActivate) {
            Write-Log "INFO" ("Manual activation command: & `"{0}`"" -f $venvActivate)
        }
    } else {
        Write-Log "WARN" "Virtual environment python not found; falling back to host python."
        $script:Warnings++
    }

    Write-Log "INFO" ("Using Python interpreter: {0}" -f $pythonCmd)

    $pipOk = $true
    try {
        & $pythonCmd -m pip --version | Out-Null
    } catch {
        $pipOk = $false
    }

    if (-not $pipOk) {
        Write-Log "WARN" "pip not available; attempting ensurepip bootstrap."
        try {
            & $pythonCmd -m ensurepip --upgrade | Out-Null
            $pipOk = $true
        } catch {
            Write-Log "ERROR" "Failed to bootstrap pip via ensurepip."
            $script:Failures++
        }
    }

    if ($pipOk) {
        Write-Log "INFO" "Upgrading pip/setuptools/wheel..."
        try {
            & $pythonCmd -m pip install --upgrade pip setuptools wheel | Out-Null
        } catch {
            Write-Log "WARN" "pip toolchain upgrade failed. Continuing with existing tooling."
            $script:Warnings++
        }

        Write-Log "INFO" "Installing/refreshing required packages: mempalace, chromadb"
        try {
            & $pythonCmd -m pip install --upgrade mempalace chromadb | Out-Null
            Write-Log "INFO" "Package installation completed."
        } catch {
            Write-Log "ERROR" "Failed to install one or more required packages."
            $script:Failures++
        }

        Write-Log "INFO" "Verifying Python imports for mempalace/chromadb..."
        try {
            & $pythonCmd -c "import importlib; importlib.import_module('mempalace'); importlib.import_module('chromadb')" | Out-Null
            Write-Log "INFO" "Import verification passed."
        } catch {
            Write-Log "ERROR" "Import verification failed for one or more modules."
            $script:Failures++
        }
    }

    if (Test-Path -LiteralPath (Join-Path $venvDir "Scripts\python.exe")) {
        Install-RmaVenvLaunchers -ProjectRoot $RootDir -VenvDir $venvDir -ToolkitRoot $ToolkitRoot
    }
}

if (Get-Command ollama -ErrorAction SilentlyContinue) {
    $model = if ($env:RMA_OLLAMA_MODEL) { $env:RMA_OLLAMA_MODEL } else { "llama3.1:latest" }
    Write-Log "INFO" ("Ollama detected. Checking local model: {0}" -f $model)
    try {
        & ollama show $model | Out-Null
        Write-Log "INFO" ("Ollama model '{0}' is available." -f $model)
    } catch {
        Write-Log "WARN" ("Model '{0}' not found locally. Run: ollama pull {0}" -f $model)
        $script:Warnings++
    }
} else {
    Write-Log "WARN" "Ollama not found. Local LLM generation may fall back unless required."
    $script:Warnings++
}

if ($script:Failures -gt 0) {
    Write-Log "ERROR" ("Setup finished with issues. Failures={0} Warnings={1}" -f $script:Failures, $script:Warnings)
    Write-Log "ERROR" ("Review log for remediation: {0}" -f $LogFile)
    exit 1
}

Write-Log "INFO" ("Setup completed successfully. Failures={0} Warnings={1}" -f $script:Failures, $script:Warnings)
exit 0
