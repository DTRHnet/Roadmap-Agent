# Stack — Watchdog CLI

## Implementation

| Piece | Choice | Notes |
|-------|--------|--------|
| Language | **Rust** (edition 2021) | `notify` for fs events; `clap` for CLI |
| Config | **TOML** | `serde` + schema tests |
| CI | **GitHub Actions** | matrix: ubuntu, macos, windows |
| Packaging | **cargo-dist** or manual | checksums + brew tap later |

## Testing

- Unit tests for glob/ignore resolution (fixtures in `tests/fixtures/`).
- Integration tests with **tempfile** dirs and synthetic events where possible.

```bash
cargo fmt --check
cargo clippy -- -D warnings
cargo test
```

## Release

- **Semver** for the binary; tag `vX.Y.Z`.
- **Changelog** from conventional commits or manual `CHANGELOG.md`.

## Distribution

- **crates.io** + **GitHub Releases** with prebuilt artifacts per triple.
