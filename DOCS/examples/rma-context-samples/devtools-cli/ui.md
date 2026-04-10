# UI — Watchdog CLI

## Command surface

- **`watchdog run`** — foreground watch with TTY-friendly status line.
- **`watchdog exec`** — one-shot: run recipe once and exit (CI).
- **`watchdog doctor`** — verify config, paths, and binary deps.

## Output contracts

- **Default:** human text, **stderr** for diagnostics, **stdout** for recipe output passthrough.
- **`--format json`:** JSON Lines events: `{"v":1,"kind":"trigger","paths":[...]}`.
- **Exit codes:** `0` success, `1` user error, `2` internal error, `130` SIGINT — document in `--help`.

## UX principles

- **No TTY:** suppress spinners; print plain timestamps (ISO-8601 UTC).
- **Confirmation:** destructive recipes require `--force` or explicit config flag.
- **Config discovery:** walk up from cwd for `watchdog.toml` / `.watchdog.toml` (document order).

## Help and docs

- Every subcommand has **examples** in `--help` (copy-pasteable).
- Man page or generated Markdown from same source as `--help` text.
