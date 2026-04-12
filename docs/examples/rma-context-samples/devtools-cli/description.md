# Watchdog CLI

## Summary

Watchdog is a **single-binary CLI** for **watching filesystem paths**, **running commands** when files change, and **emitting structured events** (JSON Lines) for **CI** and **local development**. It targets teams who want **file-triggered workflows** without adopting a full monorepo task graph for every small repo.

## Problem statement

Ad-hoc `while true` loops and editor-specific plugins are hard to **reproduce in CI**. Watchdog provides **deterministic ignore rules**, **debouncing**, and **stable output contracts** so the same config works on a laptop and in **GitHub Actions**.

## Users and personas

| Persona | Who they are | What they need |
|---------|--------------|----------------|
| **Backend Blake** | Runs API + codegen on save | **Debounced** triggers; **ignore** `node_modules` and build dirs reliably |
| **Platform Priya** | Wires preview deploys from monorepo signals | **JSON Lines** events for downstream scripts; **exit codes** for CI |
| **Contributor Chris** | First-time clone | **`--help`** parity; **doctor** command; **copy-paste** examples |

### Scenario: Blake (local dev)

Blake runs `watchdog run` in a service repo. Editing `src/**/*.ts` **debounces** to one **trigger** per save burst, runs `pnpm codegen`, and prints a **single status line** in TTY mode. On CI, Blake uses `watchdog exec --once` with the same `watchdog.toml` to verify the recipe **exits 0**.

### Scenario: Priya (automation)

Priya pipes `--format json` output to a deploy script. Each event includes **`v`** (schema version), **`kind`**, and **`paths`**. When Watchdog receives **SIGINT**, it emits a **`shutdown`** event and exits **130**.

## Goals

- **Deterministic** ignore resolution: **gitignore-style** globs + explicit **include** overrides (tested).
- **Debouncing** with configurable window; **one-shot** / **CI** mode without watch loop.
- **JSON Lines** output with **schema version** field for forward compatibility.
- **Cross-platform** behavior documented for **Windows**, **macOS**, **Linux** (path casing, notify backends).
- **Safe defaults**: never execute recipes from **untrusted** config without explicit user action.

## Non-goals

- Replacing **Make**, **Just**, **Nx**, or **Bazel** for **complex dependency graphs**.
- Hosting a **remote** coordination service — **local and CI only**.
- **IDE** replacement — editor integrations may **call** Watchdog but are out of scope.

## MVP vs later

| Phase | Scope |
|-------|--------|
| **MVP** | `run`, `exec` (one-shot), `doctor`, TOML config, human + JSON output, debounce |
| **v1.1** | **Recipe** dependencies (ordered run), **parallel** recipes — **Open:** design |
| **Later** | **Watch** over **network** mounts (best-effort) with warnings |

## Success criteria

- **100%** of documented **exit codes** covered in tests or conformance doc.
- **`cargo test`** (or chosen stack) passes on **ubuntu + macos + windows** in CI.
- **`--help`** for every subcommand includes at least **one** copy-paste example.
- **No** unbounded recursion in glob/ignore fixtures (fuzz or stress test for stack safety).

## Glossary

| Term | Meaning |
|------|---------|
| **Trigger** | One **logical** change batch after debounce merges raw fs events |
| **Recipe** | Named block in config: **command**, **cwd**, **env**, optional **filters** |
| **Event** | One JSON Line record or human log line describing state transition |

## Open:

- **Open:** Config file name precedence: `watchdog.toml` vs `.watchdog.toml` vs `Watchdog.toml` on case-sensitive FS.
- **Open:** Default **debounce** ms (50 vs 100 vs 200) per platform.
- **Open:** Whether **parallel recipes** share one debounce clock or independent — affects semantics.
