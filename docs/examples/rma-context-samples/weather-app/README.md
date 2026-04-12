# Skyline Weather — sample context (fictional app)

This folder holds **reference** `.rma`-style Markdown for the **Skyline Weather** product described in the other files here. It is **not** a runnable Flutter repo. Use this README when you **create** a real project and want a from-scratch checklist aligned with [`stack.md`](stack.md).

---

## 1. Prerequisites (mobile app)

- **Flutter SDK** 3.24+ (stable channel) — [Install Flutter](https://docs.flutter.dev/get-started/install).
- **Dart** 3.x (bundled with Flutter); enable **`flutter doctor`** clean for your targets.
- **Platform toolchains**
  - **Android:** Android Studio, SDK, emulator or device.
  - **iOS (macOS only):** Xcode, CocoaPods if needed, simulator or device.
- **IDE:** VS Code + Flutter extension, or Android Studio.
- **Git** for version control.

Optional **BFF** later: Node or Go + Postgres/Redis per [`stack.md`](stack.md).

---

## 2. Create the project from scratch

```bash
flutter create skyline_weather --org com.example.skyline
cd skyline_weather
flutter pub add dio # example; match your stack choices
flutter analyze
flutter test
flutter run
```

Then align the `lib/` tree with the layout in [`stack.md`](stack.md) (features, `core/api`, etc.).

---

## 3. Configuration and secrets

- Add **`--dart-define`** or **flavors** for API base URLs and keys; **never** commit real keys.
- Copy a template env file for local scripts (e.g. `.env.example` → `.env`) if you use codegen or a small Node BFF.
- Document variable **names** in [`stack.md`](stack.md) / [`other.md`](other.md) only.

---

## 4. ROADMAP-AGENT alongside this repo (Python / `.rma`)

ROADMAP-AGENT uses **Python** for `plan`, MemPalace, and related tooling. Your **Flutter app does not** need Python to build; Python is for the **roadmap workflow** in `.rma/`.

**Typical flow:**

1. Clone or vendor [ROADMAP-AGENT](https://github.com/DTRHnet/Roadmap-Agent) (or install `rma` on PATH — see quick start).
2. From **`skyline_weather`** root (your real app repo):

   ```powershell
   # Windows — MemPalace + venv under .rma\
   & C:\path\to\RoadmapAgent\scripts\windows\setup-local-models-mempalace.ps1
   ```

   On Linux/macOS, use the equivalent setup from the toolkit (venv + `mempalace` / ChromaDB as documented in the main repo).

3. Copy **`.env.example`** from ROADMAP-AGENT to your app root as **`.env`** and set LLM vars (`RMA_LLM_PROVIDER`, `RMA_OLLAMA_*`, etc.).
4. Initialize memory:

   ```powershell
   .\rma.ps1 init
   # or: rma init # if on PATH
   ```

5. Copy the **Markdown** from this sample folder into **`.rma/description.md`**, **`.rma/ui.md`**, **`.rma/stack.md`**, **`.rma/other.md`** (merge with generated stubs).
6. Verify:

   ```powershell
   .\rma.ps1 doctor
   ```

Full OS-specific steps: **[`docs/QUICKSTART.md`](../../../QUICKSTART.md)**. Editorial guidance for the four files: **[`docs/MANUAL.md`](../../../MANUAL.md)** (Writing and maintaining context files).

---

## 5. Related files in this sample

| File | Purpose |
|------|---------|
| [`description.md`](description.md) | Product intent, personas, MVP |
| [`ui.md`](ui.md) | Screens, widgets, a11y |
| [`stack.md`](stack.md) | Flutter stack, build, deploy |
| [`other.md`](other.md) | Security, privacy, provider limits |

Parent index: [`../README.md`](../README.md).
