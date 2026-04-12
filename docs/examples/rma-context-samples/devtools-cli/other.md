# Other — Watchdog CLI

## Security

- **Recipes execute shell commands** — configs from **untrusted sources** must **not** auto-run; require explicit `watchdog run` by user who reviewed file.
- **Repo-root config**: **warn** if file permissions are **world-writable** on Unix.
- **Path traversal**: recipes run with **`cwd`** constrained to config or explicit flag — **Open:** sandbox story (none vs `landlock`).

## Compatibility

- **Windows**: drive letters, case-insensitivity, **AV** software delaying notify — document known issues.
- **macOS**: **FSEvents** latency vs **polling** fallback — **Open:** when to poll.
- **WSL**: host ↔ Linux FS **watch** semantics differ; recommend **native** Linux for CI **truth**.
- **Network filesystems**: best-effort only; **doctor** should **warn** when paths look remote — **Open:** detection heuristics.

## Licensing and supply chain

- **`cargo deny`** or **`cargo license`** in CI to block **copyleft** surprises in release — **Open:** policy.
- **`cargo audit`** (or `deny` advisories) on schedule.
- **THIRD_PARTY_NOTICES** in release tarball.

## API stability

- **JSON event schema**: bump **`v`** on breaking changes; keep **changelog** section for consumers.
- **CLI flags**: follow **semver** — additive minor; breaking removals only major.

## Project conventions

- **Issues**: labels `bug`, `feat`, `docs`, `platform-windows`, etc.
- **MSRV**: bump in **dedicated PR** with CI update.
- **Contributing**: `CONTRIBUTING.md` with **build** and **test** commands; **CoC** link — **Open:**

## Error messages

- **Actionable**: include **config path** and **key** that failed validation.
- **No** internal panics exposed to users in release builds — `unwrap` forbidden outside tests — **Open:** `deny(clippy::unwrap_used)` in lib.

## Open:

- **Open:** **Signing** binaries (sigstore, minisign) for releases.
- **Open:** **Shell** for recipes — always `sh -c` vs platform default — security implications.
