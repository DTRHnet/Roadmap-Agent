$ErrorActionPreference = "Continue"

$RootDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$RmaDir = Join-Path $RootDir ".rma"
$RoadmapDir = Join-Path $RmaDir "roadmaps"
$StateDir = Join-Path $RmaDir "state"
$LogDir = Join-Path $RmaDir "logs"
$MemPalaceDir = Join-Path $RmaDir "mempalace"
$LockFile = Join-Path $StateDir "locked"
$PlanFile = Join-Path $RoadmapDir "plan.md"
$TasksFile = Join-Path $RoadmapDir "tasks.md"
$ExecLog = Join-Path $LogDir "roadmap-agent-execution.log"

function Initialize-CoreDirs {
    New-Item -ItemType Directory -Path $RoadmapDir -Force | Out-Null
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    New-Item -ItemType Directory -Path $MemPalaceDir -Force | Out-Null
}

function Get-ProjectName { Split-Path -Leaf $RootDir }

function Get-ProjectBranch {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $out = (git -C $RootDir rev-parse --abbrev-ref HEAD 2>$null)
            if ($out -and $out.Trim() -ne "") { return $out.Trim() }
        } catch {}
    }
    return "no-git"
}

function Get-ProjectRemote {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $out = (git -C $RootDir remote get-url origin 2>$null)
            if ($out -and $out.Trim() -ne "") { return $out.Trim() }
        } catch {}
    }
    return "none"
}

function Get-GoalSignal {
    $readme = Get-ChildItem -Path $RootDir -Filter "README*" -ErrorAction SilentlyContinue | Select-Object -First 1
    $changelog = Get-ChildItem -Path $RootDir -Filter "CHANGELOG*" -ErrorAction SilentlyContinue | Select-Object -First 1
    $goal = "No explicit project goal detected yet."
    if ($readme) {
        $first = Get-Content $readme.FullName -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1
        if ($first) { $goal = ($first -replace "^\#\s*", "") }
    }
    if ($changelog) { $goal = "$goal | Changelog detected: $($changelog.Name)" }
    return $goal
}

function Initialize-Fzf {
    if (Get-Command fzf -ErrorAction SilentlyContinue) { return $true }
    Write-Host "WARN: fzf not found. Installing local binary..." -ForegroundColor Magenta
    return Install-Fzf
}

function Install-Fzf {
    try {
        $target = Join-Path $RmaDir "bin"
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        $version = "0.58.0"
        $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "amd64" }
        $zip = "fzf-$version-windows_$arch.zip"
        $url = "https://github.com/junegunn/fzf/releases/download/v$version/$zip"
        $archive = Join-Path $target $zip
        Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
        Expand-Archive -Path $archive -DestinationPath $target -Force
        $env:Path = "$target;$env:Path"
        return [bool](Get-Command fzf -ErrorAction SilentlyContinue)
    } catch {
        return $false
    }
}

function Select-One([string]$Prompt, [string[]]$Options) {
    $inputText = ($Options -join "`n")
    $result = $inputText | fzf --ansi --layout=reverse --border=rounded --height=80% --prompt "$Prompt " --header "Press Enter to continue:" --color "border:blue,pointer:magenta,marker:magenta,header:cyan"
    return $result
}

function Wait-Continue {
    Read-Host "Press Enter to continue"
}

function Test-RmaRequiredFiles {
    $required = @("description.md","ui.md","stack.md","other.md")
    $missing = @()
    foreach ($f in $required) {
        $p = Join-Path $RmaDir $f
        if (-not (Test-Path $p)) { $missing += $f }
    }
    foreach ($m in $missing) { Write-Host "WARN: Missing .rma/$m" -ForegroundColor Magenta }
    if ($missing.Count -gt 0) { Write-Host "WARN: Run 'roadmap-agent init' to bootstrap templates." -ForegroundColor Magenta }
}

function Write-ExampleFiles {
@"
# Fill this section with full product functionality
Example:
- The app lets users create roadmap items, prioritize, and execute one safe task at a time.
- Include critical modules, data flow, and constraints.
"@ | Set-Content (Join-Path $RmaDir "description.example.md")

@"
# Fill this section with expected visual and UX behavior
Example:
- Dark CLI theme using fzf.
- Menu labels follow SUB::ai::X::X format.
- "Press Enter to continue:" should always be visible in prompts.
"@ | Set-Content (Join-Path $RmaDir "ui.example.md")

@"
# Fill this section with tech stack and versions
Example:
- Python 3.11+
- chromadb >= 0.5
- mempalace local runtime
- PowerShell 7+ and bash
"@ | Set-Content (Join-Path $RmaDir "stack.example.md")

@"
# Fill this section with additional context
Example:
- Security constraints
- Deployment targets
- Team conventions and coding guardrails
"@ | Set-Content (Join-Path $RmaDir "other.example.md")
}

function Write-RequiredStubsIfMissing {
    foreach ($base in @("description","ui","stack","other")) {
        $path = Join-Path $RmaDir "$base.md"
        if (-not (Test-Path $path)) {
@"
# $base

Populate this file with project-specific context used by ROADMAP-AGENT.
"@ | Set-Content $path
        }
    }
}

function Invoke-Init {
    if ((Test-Path $RmaDir) -and ((Get-ChildItem $RmaDir -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)) {
        if (-not (Initialize-Fzf)) { return }
        $choice = Select-One ".rma/ already exists. Overwrite? (y/N)" @("No (default)", "Yes, overwrite")
        if ($choice -ne "Yes, overwrite") {
            Write-Host "Initialization cancelled."
            return
        }
        Remove-Item -Recurse -Force $RmaDir
    }

    Initialize-CoreDirs
    Write-ExampleFiles
    Write-RequiredStubsIfMissing
@"
# Task Ledger

- [ ] Add initial project roadmap tasks.
"@ | Set-Content $TasksFile
@"
# Current Plan (Dry Run)

- [ ] Generate a first planning pass with `roadmap-agent plan`.
"@ | Set-Content $PlanFile
    Write-Host 'ROADMAP-AGENT initialized. Run `roadmap-agent` to open menu.'
}

function Invoke-LocalSetup {
    Initialize-CoreDirs
    $scriptPath = Join-Path $RootDir "scripts/windows/setup-local-models-mempalace.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath
    } else {
        Write-Host "WARN: Missing scripts/windows/setup-local-models-mempalace.ps1. Writing placeholder log." -ForegroundColor Magenta
        Add-Content -Path $ExecLog -Value "$(Get-Date -Format o) setup-local-models placeholder invoked"
    }
}

function Invoke-SafeMine([int]$Limit) {
    Initialize-CoreDirs
    if (Get-Command mempalace -ErrorAction SilentlyContinue) {
        try { mempalace mine --limit $Limit --safe } catch { Write-Host "WARN: mempalace mine failed." -ForegroundColor Magenta }
    } else {
        Write-Host "WARN: mempalace CLI not found. Simulating safe mine (limit=$Limit)." -ForegroundColor Magenta
        Add-Content -Path (Join-Path $MemPalaceDir "mine.log") -Value "$(Get-Date -Format o) safe-mine limit=$Limit simulated"
    }
}

function Invoke-HealthCheck {
    $memp = "not-found"
    $chroma = "not-found"
    if (Get-Command python -ErrorAction SilentlyContinue) {
        try { $memp = python -c "import mempalace; print(getattr(mempalace,'__version__','unknown'))" 2>$null } catch {}
        try { $chroma = python -c "import chromadb; print(getattr(chromadb,'__version__','unknown'))" 2>$null } catch {}
    }
    Write-Host "MemPalace version: $memp"
    Write-Host "ChromaDB version: $chroma"
}

function Invoke-OpenLogs {
    Initialize-CoreDirs
    try { Start-Process explorer.exe $LogDir | Out-Null } catch {}
    Write-Host "Logs folder: $LogDir"
}

function Invoke-ResetStores {
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = Join-Path $RmaDir "backup-$ts"
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    if (Test-Path $MemPalaceDir) { Copy-Item $MemPalaceDir -Destination (Join-Path $backup "mempalace") -Recurse -Force -ErrorAction SilentlyContinue }
    $chromeStore = Join-Path $RmaDir "chrome-store"
    if (Test-Path $chromeStore) { Copy-Item $chromeStore -Destination (Join-Path $backup "chrome-store") -Recurse -Force -ErrorAction SilentlyContinue }
    Remove-Item $MemPalaceDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $chromeStore -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $MemPalaceDir -Force | Out-Null
    New-Item -ItemType Directory -Path $chromeStore -Force | Out-Null
    Write-Host "Stores reset complete. Backup: $backup"
}

function Invoke-Status {
    $done = 0
    $pending = 0
    if (Test-Path $TasksFile) {
        $lines = Get-Content $TasksFile
        $done = ($lines | Where-Object { $_ -match "^- \[x\]" }).Count
        $pending = ($lines | Where-Object { $_ -match "^- \[ \]" }).Count
    }
    $last = "No execution logs yet."
    if (Test-Path $ExecLog) {
        $last = Get-Content $ExecLog | Select-Object -Last 1
    }
    Write-Host "Project: $(Get-ProjectName)"
    Write-Host "Branch: $(Get-ProjectBranch)"
    Write-Host "Completed tasks: $done"
    Write-Host "Pending tasks: $pending"
    Write-Host "Last execution log: $last"
}

function Build-ContextBundle {
    $ctx = Join-Path $StateDir "context-bundle.md"
    $content = @(
        "# Project Signals",
        "Project: $(Get-ProjectName)",
        "Branch: $(Get-ProjectBranch)",
        "Remote: $(Get-ProjectRemote)",
        "",
        "# Goal Signal",
        "$(Get-GoalSignal)",
        ""
    )
    foreach ($f in @("description","ui","stack","other")) {
        $path = Join-Path $RmaDir "$f.md"
        if (Test-Path $path) {
            $content += "## .rma/$f.md"
            $content += (Get-Content $path)
            $content += ""
        }
    }
    $content | Set-Content $ctx
    return $ctx
}

function Invoke-PlanDryRun {
    Initialize-CoreDirs
    $ctx = Build-ContextBundle
    if (Get-Command mempalace -ErrorAction SilentlyContinue) {
        try { mempalace plan --input $ctx --dry-run | Set-Content $PlanFile } catch {}
    }
    if (-not (Test-Path $PlanFile) -or ((Get-Item $PlanFile).Length -eq 0)) {
@"
# Current Plan (Dry Run)

- [ ] Review `.rma/description.md` and verify project scope alignment.
- [ ] Compare `.rma/ui.md` against current UX flows and capture gaps.
- [ ] Validate `.rma/stack.md` versions against installed dependencies.
- [ ] Update `.rma/other.md` with operational constraints and risks.
- [ ] Define next implementation task with explicit acceptance criteria.

Context snapshot: $(Get-Date -Format o)
Goal signal: $(Get-GoalSignal)
"@ | Set-Content $PlanFile
    }
    Write-Host "Plan dry run generated at: $PlanFile"
}

function Invoke-ExecuteOneTask {
    Initialize-CoreDirs
    if (Test-Path $LockFile) {
        Write-Host "WARN: Roadmap agent is locked. Run 'roadmap-agent unlock' first." -ForegroundColor Magenta
        return
    }
    if (-not (Test-Path $PlanFile)) {
        Write-Host "WARN: No plan found. Run 'roadmap-agent plan' first." -ForegroundColor Magenta
        return
    }
    if (-not (Initialize-Fzf)) { return }

    $pending = Get-Content $PlanFile | Where-Object { $_ -match "^- \[ \]" } | ForEach-Object { $_.Substring(6).Trim() }
    if ($pending.Count -eq 0) {
        Write-Host "WARN: No pending tasks in plan." -ForegroundColor Magenta
        return
    }

    $selected = ($pending -join "`n") | fzf --layout=reverse --border=rounded --prompt "Select one task to execute > " --header "Press Enter to continue:" --color "border:blue,pointer:magenta,header:cyan"
    if (-not $selected) { return }
    $confirm = Select-One "Execute exactly one task?" @("No", "Yes")
    if ($confirm -ne "Yes") {
        Write-Host "Execution cancelled."
        return
    }

    Set-Content $LockFile "locked"
    $lines = Get-Content $PlanFile
    $updated = @()
    $done = $false
    foreach ($line in $lines) {
        if (-not $done -and $line -eq "- [ ] $selected") {
            $updated += "- [x] $selected"
            $done = $true
        } else {
            $updated += $line
        }
    }
    $updated | Set-Content $PlanFile
    Add-Content $ExecLog "$(Get-Date -Format o) executed: $selected"
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    Write-Host "Executed one task: $selected"
}

function Invoke-Unlock {
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    Write-Host "Roadmap agent unlocked."
}

function Get-ShellContext {
    $hostName = $Host.Name
    $proc = ""
    try {
        $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$pid"
        if ($parent -and $parent.ParentProcessId) {
            $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($parent.ParentProcessId)"
            if ($p) { $proc = $p.Name }
        }
    } catch {}
    if ($proc -match "cmd.exe") { return "cmd" }
    if ($proc -match "pwsh|powershell") { return "powershell" }
    if ($hostName -match "Visual Studio Code") { return "vscode-terminal" }
    return "other"
}

function Invoke-PersistenceCheck {
    $shellCtx = Get-ShellContext
    $installRoot = Join-Path ${env:ProgramFiles} "Roadmap-Agent"
    $binDir = Join-Path $installRoot "bin"
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $hasBinPath = $false
    if ($machinePath) {
        foreach ($part in ($machinePath -split ";")) {
            if ($part.TrimEnd('\') -ieq $binDir.TrimEnd('\')) { $hasBinPath = $true; break }
        }
    }

    $cmdPath = (Get-Command roadmap-agent.cmd -ErrorAction SilentlyContinue)
    $rmaPath = (Get-Command rma.cmd -ErrorAction SilentlyContinue)
    $installer = Join-Path $RootDir "scripts/windows/install-persistence.ps1"

    Write-Host "Persistence status"
    Write-Host "Shell context: $shellCtx"
    Write-Host "Expected bin path: $binDir"
    Write-Host "Machine PATH has bin: $hasBinPath"
    Write-Host "roadmap-agent.cmd found: $([bool]$cmdPath)"
    Write-Host "rma.cmd found: $([bool]$rmaPath)"

    if ($hasBinPath -and $cmdPath -and $rmaPath) {
        Write-Host "Persistence already present." -ForegroundColor Green
        return
    }

    Write-Host "Persistence appears missing or partial." -ForegroundColor Yellow
    if (-not (Test-Path $installer)) {
        Write-Host "Installer missing: $installer" -ForegroundColor Red
        return
    }

    $choice = "No"
    if (Initialize-Fzf) {
        $choice = Select-One "Run persistence installer now? (admin)" @("No", "Yes")
    } else {
        $ans = (Read-Host "Run persistence installer now? (y/N)").Trim().ToLower()
        if ($ans -match "^(y|yes)$") { $choice = "Yes" }
    }
    if ($choice -ne "Yes") {
        Write-Host "Skipped persistence install."
        return
    }
    & $installer
}

function Show-Menu {
    $esc = [char]27
    $purple = "$esc[38;5;135m"
    $bold = "$esc[1m"
    $ul = "$esc[4m"
    $reset = "$esc[0m"
    $header = @(
        "${bold}${ul}ROADMAP-AGENT :: Local AI Memory Palace${reset}",
        "Project: $(Get-ProjectName)",
        "Branch: $(Get-ProjectBranch)",
        "GitHub: $(Get-ProjectRemote)",
        "Goal: $(Get-GoalSignal)",
        "Roadmaps: $RoadmapDir",
        "Press Enter to continue:"
    ) -join "`n"

    $options = @(
        "I    Local AI setup script",
        "II   Safe mine dry run (limit 200)",
        "III  Safe mine batch (300,800,1500)",
        "IV   Health check (mempalace/chromadb versions)",
        "V    Open MemPalace logs folder",
        "VI   Reset MemPalace/Chrome stores (backup + recreate)",
        "${purple}VII  Roadmap agent status${reset}",
        "${purple}VIII Roadmap agent plan (safe dry run)${reset}",
        "${purple}IX   Roadmap agent execute one task${reset}",
        "${purple}X    Roadmap agent unlock${reset}",
        "XI   Check/add persistence if missing",
        "0    Exit"
    )
    return (($options -join "`n") | fzf --ansi --layout=reverse --height=90% --border=rounded --prompt "Select > " --header $header --color "border:blue,pointer:magenta,marker:magenta,header:cyan")
}

function Invoke-MenuLoop {
    if (-not (Initialize-Fzf)) { return }
    Test-RmaRequiredFiles
    while ($true) {
        $selected = Show-Menu
        if (-not $selected) { break }
        switch -Wildcard ($selected) {
            "I    *" { Invoke-LocalSetup }
            "II   *" { Invoke-SafeMine -Limit 200 }
            "III  *" {
                $batch = Select-One "Choose safe mine batch limit" @("300","800","1500")
                if ($batch) { Invoke-SafeMine -Limit ([int]$batch) }
            }
            "IV   *" { Invoke-HealthCheck }
            "V    *" { Invoke-OpenLogs }
            "VI   *" { Invoke-ResetStores }
            "VII  *" { Invoke-Status }
            "VIII *" { Invoke-PlanDryRun }
            "IX   *" { Invoke-ExecuteOneTask }
            "X    *" { Invoke-Unlock }
            "XI   *" { Invoke-PersistenceCheck }
            "0    *" { break }
        }
        Wait-Continue
    }
}

$cmd = if ($args.Count -gt 0) { $args[0] } else { "menu" }
switch ($cmd) {
    "persistence" { Invoke-PersistenceCheck }
    "persistance" { Invoke-PersistenceCheck }
    "persistence-check" { Invoke-PersistenceCheck }
    "init" { Invoke-Init }
    "status" { Test-RmaRequiredFiles; Invoke-Status }
    "plan" { Initialize-CoreDirs; Test-RmaRequiredFiles; Invoke-PlanDryRun }
    "execute-one" { Initialize-CoreDirs; Test-RmaRequiredFiles; Invoke-ExecuteOneTask }
    "unlock" { Initialize-CoreDirs; Invoke-Unlock }
    default { Invoke-MenuLoop }
}
