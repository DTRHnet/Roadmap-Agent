# Stack — Watchdog CLI

## Implementation

| Piece | Choice | Notes |
|-------|--------|--------|
| Language | **Rust** (edition 2021) | MSRV pinned in `Cargo.toml` |
| CLI | **clap** | Derive API; subcommands mirror `ui.md` |
| FS events | **notify** (or **recommended** create backend) | Platform quirks documented in `other.md` |
| Config | **TOML** | **serde**; schema tests + snapshot tests for errors |
| Glob / ignore | **globset** + **ignore** crate | Match `.gitignore` semantics where promised |
| JSON | **serde_json** | JSON Lines: one value per line |
| CI | **GitHub Actions** | Matrix: **ubuntu**, **macos**, **windows** |
| Packaging | **cargo-dist** *or* manual release | Checksums; **Open:** Homebrew tap timeline |

## Repository layout (suggested)

```text
src/
  main.rs
  cli/
  config/
  watcher/
  recipes/
tests/
  fixtures/ # directory trees for ignore tests
  integration/
```

## Local development

```bash
cargo build
cargo run -- run --config ./examples/watchdog.toml
cargo run -- doctor
```

## Build and test

```bash
cargo fmt --check
cargo clippy -- -D warnings
cargo test
```

- **Integration tests**: tempfile directories; simulate events where the OS allows.
- **Open:** **miri** or sanitizer job on nightly — optional stretch goal.

## Release and distribution

- **Semver** for the binary; git tags **`vX.Y.Z`**.
- **Changelog**: `CHANGELOG.md` or **git-cliff** — **Open:** policy.
- **Artifacts**: prebuilt **triple** binaries on GitHub Releases; **crates.io** for library split if any — **Open:** crate split.

## Observability (CLI-appropriate)

- **Tracing** feature flag for internal debug (`RUST_LOG`) — document levels.
- **No** telemetry phoning home in OSS default build — **Open:** if ever added, opt-in only.

## Environment variables (names only)

| Name | Purpose |
|------|---------|
| `RUST_LOG` | Log filter when `tracing` enabled |
| `NO_COLOR` | Disable ANSI |
| `WATCHDOG_CONFIG` | Optional default config path — **Open:** support or not |
| `CI` | Detect CI (suppress TTY UX) — conventional |

## Performance targets

- **Debounce** overhead negligible vs user save patterns; avoid **O(n²)** glob over huge trees — benchmark with **10k** files — **Open:** numbers in CI.

## Deployment

- **Not applicable** (client binary). **Docs** deployed to **docs site** optional — **Open:**
