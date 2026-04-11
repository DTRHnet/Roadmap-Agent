from pathlib import Path

from app.env_service import merge_env_file, parse_env_file


def test_parse_and_merge_preserves_comments(tmp_path: Path) -> None:
    env = tmp_path / ".env"
    env.write_text(
        "# header\n"
        "RMA_LLM_PROVIDER=ollama\n"
        "FOOBAR=ignored\n"
        "# c2\n"
        "RMA_OLLAMA_MODEL=old\n",
        encoding="utf-8",
    )
    data = parse_env_file(env)
    assert data["RMA_LLM_PROVIDER"] == "ollama"
    assert data["RMA_OLLAMA_MODEL"] == "old"
    merge_env_file(env, {"RMA_OLLAMA_MODEL": "new:latest", "RMA_OLLAMA_HOST": "http://x:11434"})
    text = env.read_text(encoding="utf-8")
    assert "# header" in text
    assert "FOOBAR=ignored" in text
    assert "RMA_OLLAMA_MODEL=new:latest" in text
    assert "RMA_OLLAMA_HOST=http://x:11434" in text
    assert parse_env_file(env)["RMA_OLLAMA_MODEL"] == "new:latest"


def test_delete_key(tmp_path: Path) -> None:
    env = tmp_path / ".env"
    env.write_text("RMA_LLM_PROVIDER=claude\n", encoding="utf-8")
    merge_env_file(env, {"RMA_LLM_PROVIDER": None})
    assert "RMA_LLM_PROVIDER" not in env.read_text()
