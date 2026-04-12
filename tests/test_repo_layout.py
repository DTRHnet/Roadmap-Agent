"""Repository layout invariants after launchers/docs/img reorganization."""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


def test_only_run_wrappers_at_root_for_scripts() -> None:
    """Only RUN.* should be user-facing script-like files at repo root (plus OS metadata)."""
    allowed_root_scripts = {
        "RUN.sh",
        "RUN.ps1",
        "RUN.cmd",
        "rma_cli.sh",
        "rma_cli.ps1",
        "rma_cli.cmd",
    }
    root_scripts = {
        p.name
        for p in ROOT.iterdir()
        if p.is_file() and p.suffix.lower() in {".sh", ".ps1", ".cmd", ".bat"}
    }
    assert root_scripts == allowed_root_scripts, (
        f"Unexpected root scripts: {root_scripts - allowed_root_scripts} "
        f"(allowed: {allowed_root_scripts})"
    )


def test_launchers_exist() -> None:
    launchers = ROOT / "launchers"
    assert launchers.is_dir()
    for name in (
        "roadmap-agent",
        "rma",
        "rma.sh",
        "rma.ps1",
        "rma.cmd",
        "roadmap-agent.cmd",
        "setup-rma.ps1",
        "setup-rma.cmd",
        "refresh-rma-path.ps1",
    ):
        assert (launchers / name).is_file(), f"missing launchers/{name}"


def test_docs_directory_lowercase_name() -> None:
    """docs/ must exist; on case-insensitive FS, Path('DOCS').exists() is a false positive."""
    assert (ROOT / "docs").is_dir()
    doc_dirs = [p for p in ROOT.iterdir() if p.is_dir() and p.name.lower() == "docs"]
    assert len(doc_dirs) == 1
    assert doc_dirs[0].name == "docs"


def test_manpage_path_in_runtime() -> None:
    sh = (ROOT / "scripts/unix/roadmap-agent.sh").read_text(encoding="utf-8")
    assert "docs/man/roadmap-agent.1" in sh
    assert "DOCS/man" not in sh


def test_persistence_sync_lists_launchers() -> None:
    sh = (ROOT / "scripts/unix/roadmap-agent.sh").read_text(encoding="utf-8")
    m = re.search(
        r'local files=\(\s*((?:"[^"]+"\s*)+)\)',
        sh[sh.find("persistence_scripts_in_sync()") :],
    )
    assert m, "could not find files= array in persistence_scripts_in_sync"
    block = m.group(1)
    assert '"launchers/roadmap-agent"' in block
    assert '"launchers/rma.ps1"' in block
    assert '"RUN.sh"' in block
    assert '"rma_cli.sh"' in block


def test_img_has_diagram() -> None:
    assert (ROOT / "img" / "roadmap-mining-and-loop.svg").is_file()


def test_license_and_notice_at_root() -> None:
    assert (ROOT / "LICENSE").is_file()
    text = (ROOT / "LICENSE").read_text(encoding="utf-8", errors="replace")
    assert "Apache License" in text
    assert (ROOT / "NOTICE").is_file()
    assert "DTRH" in (ROOT / "NOTICE").read_text(encoding="utf-8", errors="replace")


def test_github_ci_workflow_exists() -> None:
    wf = ROOT / ".github" / "workflows" / "ci.yml"
    assert wf.is_file()
    raw = wf.read_text(encoding="utf-8", errors="replace")
    assert "pytest" in raw
    assert "docker" in raw.lower() or "Dockerfile" in raw


def test_github_docker_publish_workflow_exists() -> None:
    wf = ROOT / ".github" / "workflows" / "docker-publish.yml"
    assert wf.is_file()
    raw = wf.read_text(encoding="utf-8", errors="replace")
    assert "ghcr.io" in raw
    assert "Dockerfile.web" in raw or "docker/Dockerfile.web" in raw


def test_product_roadmap_framework_prompt_exists() -> None:
    p = ROOT / "docs" / "prompts" / "PRODUCT_ROADMAP_FRAMEWORK.md"
    assert p.is_file()
    text = p.read_text(encoding="utf-8", errors="replace")
    assert "roadmap" in text.lower()
    assert "anti-pattern" in text.lower() or "Anti-pattern" in text


def test_readme2_and_env_reference_exist() -> None:
    assert (ROOT / "README2.md").is_file()
    assert (ROOT / "docs" / "ENVIRONMENT-VARIABLES.md").is_file()
    r2 = (ROOT / "README2.md").read_text(encoding="utf-8", errors="replace")
    assert "docs/ENVIRONMENT-VARIABLES.md" in r2
    assert "img/rma.png" in r2


def test_readme_documents_persistence_by_os_section() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8", errors="replace")
    assert "persistence-on-path-by-operating-system" in readme
    assert "#### Windows" in readme
    assert "#### Linux" in readme
    assert "#### macOS" in readme


def test_windows_bridge_documents_native_persistence() -> None:
    ps1 = (ROOT / "scripts" / "windows" / "roadmap-agent.ps1").read_text(encoding="utf-8", errors="replace")
    assert "Convert-PersistenceArgsToInstaller" in ps1
    assert '--help' in ps1 and "persistence" in ps1
    assert "LOCALAPPDATA" in ps1 and "Persistence install is PowerShell-only" in ps1


def test_runtime_has_project_root_discovery() -> None:
    sh = (ROOT / "scripts" / "unix" / "roadmap-agent.sh").read_text(encoding="utf-8", errors="replace")
    assert "discover_default_project_root()" in sh
    assert "rebind_rma_paths()" in sh
    assert "init-toolkit-version.txt" in sh
    assert ("persistence --user" in sh) or (
        "--user" in sh and "_persistence_install_unix" in sh
    )


def test_sysinfo_audit_output_not_tracked() -> None:
    """`.sysinfo/` is machine-local; must never be committed (paths, host, user)."""
    if not (ROOT / ".git").is_dir():
        pytest.skip("not a git checkout")
    r = subprocess.run(
        ["git", "ls-files", "--", ".sysinfo"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if r.returncode != 0:
        pytest.skip("git ls-files failed")
    assert not (r.stdout or "").strip(), "remove .sysinfo from git: git rm -r --cached .sysinfo"
