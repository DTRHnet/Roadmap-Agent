"""Optional: validate bash script parses (skip when bash missing or Windows path quirks)."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SH = ROOT / "scripts" / "unix" / "roadmap-agent.sh"


@pytest.mark.skipif(sys.platform == "win32", reason="Git Bash path conversion not normalized in test")
@pytest.mark.skipif(not shutil.which("bash"), reason="bash not on PATH")
def test_roadmap_agent_sh_passes_bash_n() -> None:
    r = subprocess.run(
        ["bash", "-n", str(SH)],
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert r.returncode == 0, r.stderr
