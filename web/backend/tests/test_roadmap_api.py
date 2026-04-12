"""Roadmap presets and run/rma API shape."""
from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_roadmap_presets_returns_list() -> None:
    r = client.get("/api/roadmap/presets")
    assert r.status_code == 200
    data = r.json()
    assert "presets" in data
    assert isinstance(data["presets"], list)
    assert len(data["presets"]) >= 5
    first = data["presets"][0]
    assert "id" in first and "label" in first and "args" in first and "hint" in first
    assert isinstance(first["args"], list)
    ids = {p["id"] for p in data["presets"]}
    assert "plan" in ids
    assert "analyze" in ids


def test_health() -> None:
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.json().get("status") == "ok"
