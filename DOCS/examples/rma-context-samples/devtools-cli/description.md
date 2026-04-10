# Watchdog CLI

## Summary

Watchdog is a **single-binary CLI** for **watching paths**, **running commands** on change, and **emitting structured events** (JSON Lines) for CI and local dev. It targets teams who want **file-triggered workflows** without adopting a full task runner ecosystem for simple repos.

## Users

- Backend devs who need **reload** or **codegen** on save.
- Platform engineers wiring **preview deployments** from monorepo signals.
- Contributors who expect **`--help`** parity, **stable exit codes**, and **scriptable** output.

## Goals

- **Deterministic** ignore rules (gitignore-style + explicit includes).
- **Debouncing** and **one-shot** mode for CI.
- **JSON** output mode with schema version field.

## Non-goals

- Replacing **Make**, **Just**, or **Nx** for complex graphs.
- Hosting a remote service — this is **local/CI only**.

## Glossary

| Term | Meaning |
|------|---------|
| **Trigger** | One logical change batch after debounce. |
| **Recipe** | Named command block in config file. |
