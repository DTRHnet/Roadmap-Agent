# Watchdog CLI — sample context (fictional app)

This folder holds **reference** `.rma`-style Markdown for the **Watchdog** file-watcher CLI. It is **not** a Rust crate in this repo. Use this README when you **`cargo new`** the real project and align it with [`stack.md`](stack.md).

---

## 1. Prerequisites

- **Rust** toolchain: **rustup** with stable (and same **MSRV** you will pin in `Cargo.toml`).
- **Git**.
- **Platform:** develop on **Linux**, **macOS**, or **Windows**; CI should cover all three if you promise cross-platform behavior (see [`other.md`](other.md)).

Useful:

```bash
rustup update stable
rustc --version
cargo --version
```

---

## 2. Create the project from scratch

```bash
cargo new watchdog-cli --bin
cd watchdog-cli
```

Add dependencies as you implement (see [`stack.md`](stack.md)): **clap**, **notify**, **serde** + **toml**, **globset** / **ignore**, etc.

```bash
cargo add clap --features derive
cargo add notify serde toml serde_json
# ... add globset, ignore, etc. to match your design
cargo fmt
cargo clippy -- -D warnings
cargo test
cargo build --release
```

Add an **`examples/watchdog.toml`** (or similar) for local manual testing of `cargo run -- run --config ...`.

---

## 3. Python?

**Watchdog** itself is **Rust only**. Python is **not** required for the binary.

Use **Python** only if you add **ROADMAP-AGENT** to the same repo for **`.rma/`** roadmap workflow (venv under `.rma/`, MemPalace, `rma plan`, etc.).

---

## 4. ROADMAP-AGENT alongside this repo (Python / `.rma`)

1. From **`watchdog-cli`** root: **`rma init`** (from a ROADMAP-AGENT checkout or global `rma`).
2. Run the toolkit’s **Python/MemPalace** setup so **`.rma/venv`** exists (Windows: **`setup-local-models-mempalace.ps1`**; other OS: see **[`QUICKSTART.md`](../../../QUICKSTART.md)**).
3. Copy **`.env`** for `RMA_LLM_PROVIDER`, Ollama/OpenAI settings, optional MemPalace paths.
4. Replace generated stubs with the four Markdown files from this sample (or merge).
5. **`rma doctor`** before **`rma plan`**.

Rust and Python coexist fine: **cargo** uses `~/.cargo` and project `target/`; **RMA** uses `.rma/venv`.

---

## 5. Related files in this sample

| File | Purpose |
|------|---------|
| [`description.md`](description.md) | CLI goals, triggers, JSON schema |
| [`ui.md`](ui.md) | Commands, flags, exit codes, TTY behavior |
| [`stack.md`](stack.md) | Rust, cargo, CI matrix, release |
| [`other.md`](other.md) | Security (recipe execution), platforms |

Parent index: [`../README.md`](../README.md).
