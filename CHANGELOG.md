# Changelog

All notable changes to ROADMAP-AGENT are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses semantic versioning intent.

## [Unreleased]

### Fixed

- AI submenu **II / III** (`mempalace mine`): pass required **project directory** (`mempalace mine <dir>`) and use upstream **`--dry-run`** instead of invalid `--safe`. Optional **`RMA_MEMPALACE_MINE_DIR`** selects the mined tree (default: project root).

## [0.3.0] - 2026-04-10

### Changed (Breaking)

- **MemPalace is required** for real `plan` and **safe mine** operations: removed simulated safe-mine log lines, removed placeholder `EXEC_LOG` entries when the setup script was missing, and removed silent `2>/dev/null` swallowing on `mempalace plan`.
- **`roadmap-agent plan`** now exits with a non-zero status if MemPalace cannot produce a plan, unless **`RMA_ALLOW_PLAN_FALLBACK=1`** is set (writes an explicit markdown template and logs the fallback to `EXEC_LOG`).
- New environment variables (see `.env.example` and `--help`): **`RMA_REQUIRE_MEMPALACE`** (default `1`), **`RMA_MEMPALACE_BIN`**, **`RMA_ALLOW_PLAN_FALLBACK`** (default `0`). `doctor` and the runtime warnings panel include a **[MemPalace]** section when strict mode is on.

### Removed

- [`scripts/windows/_tmp_noheader.ps1`](scripts/windows/_tmp_noheader.ps1) (unused; MemPalace logic lives in the Unix runtime).

### Added

- `resolve_mempalace_cmd`, `mempalace_python_imports_ok`, `mempalace_assert_ready`, and `write_plan_fallback_template` in [`scripts/unix/roadmap-agent.sh`](scripts/unix/roadmap-agent.sh).

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
- `DOCS/examples/MOCK-WORKFLOW-SESSION.md` — illustrative mock transcripts.

### Changed

- `README.md`: refreshed presentation; documentation index and MemPalace notes; linked `DOCS/QUICKSTART.md` and `DOCS/MANUAL.md` from Quick Start and the documentation index.
- Reorganized repository by operating system:
  - Windows runtime/scripts in `scripts/windows/`
  - Linux/macOS runtime/scripts in `scripts/unix/`
  - Docker entrypoint moved to `docker/entrypoint.sh`
- Updated root launchers to route into new OS-specific runtime locations.
- Updated Dockerfile paths and executable targets to match new layout.
- Updated menu display labels from `SUB::...` format to Roman numerals for cleaner UX.
- Added persistence health-check option (`persistence-check`) and menu entry to detect and optionally remediate missing global persistence.
- Implemented a Defender-safe Windows bridge runtime in `scripts/windows/roadmap-agent.ps1` that delegates full CLI execution to `scripts/unix/roadmap-agent.sh` through `bash` while keeping Windows persistence installation local.
- `DOCS/GETTING-STARTED.md`: links to `QUICKSTART.md` / `MANUAL.md`; Windows persistence notes updated for `setup-rma.ps1` user vs machine scope and PATH refresh.

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
