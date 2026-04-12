# UI — Watchdog CLI

This file describes **CLI UX**: commands, flags, output streams, and behavior with or without a TTY. It is the right place for **interaction contracts**; see **`stack.md`** for language and crate choices.

## Command tree (illustrative)

```text
watchdog
  run          Watch paths and run recipes (foreground)
  exec         Run a recipe once or in CI batch mode
  doctor       Validate config, toolchain, and notify backend
  help         Top-level help (also: watchdog help <cmd>)
```

**Open:** whether `watch` is an alias for `run` — document in `--help` only after decision.

## Global flags (suggested)

| Flag | Purpose |
|------|---------|
| `--config <path>` | Explicit config; skip upward search |
| `--cwd <path>` | Resolve relative paths from here |
| `--verbose` | More human diagnostics on stderr |
| `--quiet` | Errors only |
| `--format human` or `--format json` | Output mode; default **human** if TTY |
| `--no-color` | Disable ANSI even on TTY |

## `watchdog run`

- **Purpose**: long-running process; watches globs; runs matching **recipes**.
- **TTY**: show **spinner** or **status line** on stderr; recipe **stdout/stderr** passed through or prefixed — **Open:** prefix policy.
- **Non-TTY**: no spinners; plain **ISO-8601 UTC** timestamps on stderr lines.
- **SIGINT**: cancel in-flight recipe gracefully; emit **shutdown** event in JSON mode; exit **130**.
- **SIGTERM**: same as INT unless platform differs — document.

## `watchdog exec`

- **Purpose**: **one-shot** or **CI** entry: load config, resolve recipes, run **once**, exit.
- **Flags**: `--recipe <name>` required unless default recipe in config — **Open:** default recipe rules.
- **CI**: combine with `--format json` for log ingestion; no watch handles leaked.

## `watchdog doctor`

- **Purpose**: fail fast on bad config (invalid TOML, unknown keys **warn** or **error** — **Open:** strictness).
- Checks: **notify** backend available, **recipe** shell exists, paths readable.
- **Exit**: `0` all ok; `1` user-fixable; `2` internal/unexpected.

## Output contracts

### Human mode (default on TTY)

- **stderr**: diagnostics, debounce summaries, recipe start/end.
- **stdout**: reserved for **recipe** output unless config says **suppress** — **Open:** per-recipe `capture` flag.

### JSON Lines (`--format json`)

- One JSON object per line; **UTF-8**; flush after each event.
- Every record includes **`v`** (integer schema version) and **`kind`** (string).
- **Illustrative kinds**: `trigger`, `recipe_start`, `recipe_end`, `error`, `shutdown`.

Example (illustrative):

```json
{"v":1,"kind":"trigger","recipe":"build","paths":["src/lib.rs"],"ts":"2026-04-11T12:00:00Z"}
```

**Open:** whether **`ts`** is required on all kinds; document migration when **`v`** increments.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | User error (bad args, invalid config) |
| `2` | Internal error |
| `130` | Interrupted (SIGINT) — common convention |

Document these in **`--help`** and in `README` / man page.

## Config discovery

- Walk **up** from `--cwd` for `watchdog.toml` then `.watchdog.toml` — **Open:** final order.
- **First match wins** or **merge** — **Open:** specify; merging surprises users.

## UX principles

- **No silent exec**: first run with new config may print **resolved paths** in verbose mode.
- **Destructive recipes**: require **`force = true`** in recipe or `--force` flag — **Open:** policy.
- **Cross-platform paths**: always display **normalized** paths in JSON (forward slashes or platform — pick one and test).

## Help and documentation

- Every subcommand **`--help`**: **examples** section with copy-paste blocks.
- **Man page** or **Markdown** generated from same source as clap help — **Open:** tooling (`clap_mangen`).

## Accessibility and terminals

- Respect **`NO_COLOR`** environment convention.
- Avoid **flickering** status line faster than readable; throttle updates — **Open:** interval.
