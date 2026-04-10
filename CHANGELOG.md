# Changelog

All notable changes to ROADMAP-AGENT are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses semantic versioning intent.

## [Unreleased]

## [0.2.0] - 2026-04-10

### Added

- `scripts/windows/refresh-rma-path.ps1` and repo-root `refresh-rma-path.ps1` to rebuild `PATH` in the current PowerShell session from Machine + User registry values (so `rma` works in the same window after persistence install).
- Windows `install-persistence.ps1` and `setup-rma.ps1` call the PATH refresh helper after a successful install.
- `VERSION` file at the repository root; `app_version` in the Unix runtime reads it first (then git tag, then dev snapshot).
- Expanded documentation set with practical usage guides in `DOCS/`.
- `DOCS/QUICKSTART.md` — per-OS quick start (Windows, Linux, macOS, Docker).
- Rewrote `DOCS/MANUAL.md` as a detailed operator manual (table of contents, commands, interactive mode, `.rma` authoring, LLM/env/persistence, security).
- Manual command support via `roadmap-agent man`.
- Unix manpage source at `DOCS/man/roadmap-agent.1`.
- Windows persistence installer script at `scripts/windows/install-persistence.ps1`.
- GitHub-oriented banner image `roadmap-agent-github-banner.png`.

### Changed

- `README.md`: refreshed presentation; linked documentation; removed placeholder clone URLs; linked `DOCS/QUICKSTART.md` and `DOCS/MANUAL.md` from Quick Start and the documentation index.
- Reorganized repository by operating system:
  - Windows runtime/scripts in `scripts/windows/`
  - Linux/macOS runtime/scripts in `scripts/unix/`
  - Docker entrypoint moved to `docker/entrypoint.sh`
- Updated root launchers to route into new OS-specific runtime locations.
- Updated Dockerfile paths and executable targets to match new layout.
- Updated menu display labels from `SUB::...` format to Roman numerals for cleaner UX.
- Added persistence health-check option (`persistence-check`) and menu entry to detect and optionally remediate missing global persistence.
- Implemented a Defender-safe Windows bridge runtime in `scripts/windows/roadmap-agent.ps1` that delegates full CLI execution to `scripts/unix/roadmap-agent.sh` through `bash` while keeping Windows persistence installation local.

## [0.1.0] - 2026-04-10

### Added

- Cross-platform launchers for Windows, Linux/macOS, and Docker.
- Core ROADMAP-AGENT runtime scripts:
  - `roadmap-agent.ps1`
  - `roadmap-agent.sh`
- Alias launchers:
  - `rma`, `rma.cmd`, `rma.ps1`, `rma.sh`
- Interactive `fzf`-driven menu with Local AI Memory Palace actions.
- `.rma/` initialization and required-file validation.
- Roadmap status, plan (dry run), execute-one, and unlock commands.
- MemPalace helper scripts:
  - `scripts/setup-local-models-mempalace.ps1`
  - `scripts/setup-local-models-mempalace.sh`
- Menu header project awareness:
  - project/branch/remote/goal signal/roadmap path
- Compact initial banner with:
  - app version auto-detection
  - last release version
  - release date
- Hub + AI submenu navigation flow.

### Notes

- Interactive behavior requires `fzf` and attempts local auto-install when missing.
- Some actions run in best-effort mode when external dependencies are unavailable.
