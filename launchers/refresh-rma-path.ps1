$LaunchersDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $LaunchersDir "..")).Path
& (Join-Path $RepoRoot "scripts\windows\refresh-rma-path.ps1") @args
