# Releasing ROADMAP-AGENT

ROADMAP-AGENT is **script-first**: the product is the repository (launchers, `scripts/unix`, `scripts/windows`, docs). There is **no required compiled binary**; optional “binaries” are **packaged archives** or a **Docker image**, not a custom `.exe` built from this repo.

## 1. Prepare the version

1. Set the root **`VERSION`** file to the semver you are shipping (e.g. `1.1.1-b` or `1.0.0`).
2. Update **`CHANGELOG.md`**: move items from `[Unreleased]` into a dated section `[x.y.z] - YYYY-MM-DD`.
3. Align **banner / docs** that cite the current version (README badge, examples if needed).
4. Commit on your release branch (e.g. `release/1.1.1-b`, `main`).

## 2. Tag in Git

```bash
git tag -a v1.1.1-b -m "ROADMAP-AGENT 1.1.1-b"
git push origin v1.1.1-b
```

Tags use the **`v` prefix** so `git describe` and the CLI “last release” hints stay consistent.

### Automated helper (menu + CLI)

From the **hub** choose **“VI — Create release…”** or run:

```bash
roadmap-agent release --help
roadmap-agent release --dry-run
roadmap-agent release -y
```

This runs [`scripts/unix/release-rma.sh`](../scripts/unix/release-rma.sh): reads **`VERSION`**, extracts the matching **`## [x.y.z]`** block from **`CHANGELOG.md`** for the GitHub release body, optionally creates the annotated tag, builds Docker images `roadmap-agent:<ver>` and `:latest`, pushes the tag to **`origin`**, and runs **`gh release create`** when the [GitHub CLI](https://cli.github.com/) is installed and authenticated. Use flags such as `--skip-docker` or `--skip-github-release` as needed. Set **`RMA_RELEASE_IMAGE_NAME`** to override the Docker image basename.

## 3. GitHub Release (recommended)

1. On GitHub: **Releases → Draft a new release**.
2. Choose tag **`v1.1.1-b`** (must match **`VERSION`** / **`CHANGELOG.md`**).
3. Title e.g. `ROADMAP-AGENT 1.1.1-b`.
4. Paste the relevant **`CHANGELOG.md`** section into the description.
5. **Source code**: GitHub auto-attaches **Source code (zip)** and **tar.gz**; that is the normal “artifact” for this project.
6. Optional: attach a **manual** zip of the repo at that tag if you need a fixed bundle outside GitHub.

Users install by **cloning** or **extracting the archive**, then `RUN.sh` / `RUN.ps1` or persistence install — not by running a single magic binary.

## 4. Docker image

### CI publish (GitHub Container Registry)

The workflow **[`.github/workflows/docker-publish.yml`](../.github/workflows/docker-publish.yml)** pushes to **`ghcr.io`** when you push a **`v*`** tag (e.g. **`v1.1.1-b`**):

- **`ghcr.io/<owner-lowercase>/roadmap-agent`** — root **`Dockerfile`** (CLI / toolkit)
- **`ghcr.io/<owner-lowercase>/roadmap-agent-web`** — **`docker/Dockerfile.web`** (FastAPI + built SPA; CI runs **`npm ci && npm run build`** in **`web/frontend`** first)

Tags applied on a version tag: **`:v1.1.1-b`**, **`:1.1.1-b`** (without **`v`**), and **`:latest`** for both images.

**Manual publish** (same images, custom tag): **Actions → Docker publish → Run workflow** and set the tag (default **`edge`**).

Requirements:

- Workflow **`permissions.packages: write`** (already set). The default **`GITHUB_TOKEN`** can push packages for this repo.
- The org or user account may need to allow Actions to create packages. New packages may be **private** until you mark them **public** under **Packages** in GitHub settings.

Pull examples (replace **`owner`** with your GitHub user or org, lowercase):

```bash
docker pull ghcr.io/owner/roadmap-agent:latest
docker pull ghcr.io/owner/roadmap-agent-web:latest
```

### Local build

If you publish a container yourself:

```bash
docker build -t roadmap-agent:1.1.1-b -f Dockerfile .
```

Tag and push to your registry as needed. The Dockerfile copies the tree and sets the entrypoint; version inside the image follows **`VERSION`** at build time.

**Optional web UI image:** **`docker/Dockerfile.web`** builds the FastAPI companion only. To ship a single-port image with the React SPA, run **`npm ci && npm run build`** in **`web/frontend`** before **`docker build -f docker/Dockerfile.web`** so **`web/frontend/dist`** exists in the context. **`docker-compose.yml`** is for local use (**127.0.0.1:8765**); see **[`web/README.md`](../web/README.md)**.

## 5. Windows persistence / “local install”

The **installer** (`scripts/windows/install-persistence.ps1`, or `launchers/setup-rma.ps1`) **mirrors** the repo into `%LOCALAPPDATA%\Roadmap-Agent` (or Program Files for machine scope) and adds `bin` to PATH. That is a **deployment** of the same scripts, not a separate build pipeline.

After changing release layout, run **`install-persistence.ps1`** from the new tag on a test machine and confirm `rma doctor` and `RUN.ps1` behave as expected.

## 6. If you really want a “binary”

The supported model is **scripts + Python venv** (MemPalace). Wrapping with **PyInstaller**, **shc**, or similar is **not** maintained here and would duplicate bash/PowerShell behavior poorly.

For distribution to non-developers, prefer:

- **GitHub Release zip** + one-line README “extract and run `RUN.ps1` / `RUN.sh`”, or  
- **Docker** for a reproducible environment.

## Checklist

- [ ] `VERSION` and `CHANGELOG.md` match the tag  
- [ ] `git tag v…` pushed  
- [ ] GitHub Release created with notes  
- [ ] (Optional) Docker image built and pushed  
- [ ] Smoke test: `RUN.sh doctor` / `.\RUN.ps1 doctor` from a clean project directory  
