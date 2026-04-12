"""WSL-style path rewriting for Windows web UI consumers."""

from __future__ import annotations

from app.path_display import normalize_json_for_windows_display, normalize_wsl_paths_in_text


def test_wsl_path_replacement() -> None:
    s = "Project root: /mnt/c/Users/foo/Bar | log: /mnt/d/tmp/x.txt"
    out = normalize_wsl_paths_in_text(s)
    assert "/mnt/" not in out
    assert "C:\\Users\\foo\\Bar" in out
    assert "D:\\tmp\\x.txt" in out


def test_wsl_not_match_wsl_distro_path() -> None:
    s = "see /mnt/wsl/instances/foo"
    assert normalize_wsl_paths_in_text(s) == s


def test_json_normalize_skipped_off_windows(monkeypatch) -> None:
    import app.path_display as pd

    monkeypatch.setattr(pd, "_is_windows_host", lambda: False)
    data = {"project": {"root": "/mnt/c/Users/x"}}
    assert normalize_json_for_windows_display(data) is data


def test_json_normalize_rewrites_on_windows(monkeypatch) -> None:
    import app.path_display as pd

    monkeypatch.setattr(pd, "_is_windows_host", lambda: True)
    data = {"project": {"root": "/mnt/c/Users/x"}}
    out = normalize_json_for_windows_display(data)
    assert out["project"]["root"] == "C:\\Users\\x"
