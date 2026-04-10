# Other — Watchdog CLI

## Compatibility

- **Windows:** path casing and drive letters — test notify behavior on NTFS.
- **WSL:** document that host ↔ Linux FS watches differ; recommend native Linux for CI truth.

## Security

- **Recipes** execute shell commands — **never** auto-run untrusted config from internet without explicit user action.
- **Config path:** warn if repo-root config is world-writable.

## Licensing

- **Dependencies:** `cargo deny` or `cargo license` in CI gate.
- **Third-party** notices file in release tarball.

## Project conventions

- **Issues:** use labels `bug`, `feat`, `docs`.
- **MSRV:** pin in `Cargo.toml` and CI; bump in dedicated PR.
