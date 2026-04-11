# '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# Repo-root helpers live in launchers/; only RUN.* stays at clone root.
# Delegates to scripts/windows/roadmap-agent.ps1 with ROADMAP_AGENT_PROJECT_ROOT = cwd.
# Last updated: 2026-04-11
# '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

$LaunchersDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $LaunchersDir "..")).Path
& (Join-Path $RepoRoot "scripts\windows\roadmap-agent.ps1") @args
