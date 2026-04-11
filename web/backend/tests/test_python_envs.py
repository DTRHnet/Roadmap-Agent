from pathlib import Path

from app.python_envs import discover_python_envs


def test_discover_empty_project(tmp_path: Path) -> None:
    proj = tmp_path / "app"
    proj.mkdir()
    rows = discover_python_envs(proj)
    assert isinstance(rows, list)
    # PATH pythons may appear on dev machines; at least no crash
    for row in rows:
        assert "executable" in row
        assert "version" in row
        assert "venvDir" in row
