"""Environment-backed settings for the modular agent."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class AgentConfig:
    """Subset of ROADMAP-AGENT .env relevant to the terminal agent."""

    project_root: Path
    app_root: Path
    llm_provider: str
    ollama_model: str
    ollama_host: str
    openai_base_url: str
    openai_api_key: str
    openai_model: str
    claude_model: str
    skip_reflect: bool
    max_reflection_retries: int

    @classmethod
    def from_environ(cls, cwd: Path | None = None) -> AgentConfig:
        root = os.environ.get("ROADMAP_AGENT_PROJECT_ROOT") or os.environ.get("RMA_MCP_PROJECT_ROOT")
        proj = Path(root).expanduser().resolve() if root else (cwd or Path.cwd()).resolve()
        app = os.environ.get("ROADMAP_AGENT_APP_ROOT")
        app_p = Path(app).expanduser().resolve() if app else proj
        skip = os.environ.get("RMA_AGENT_SKIP_REFLECT", "0").strip().lower() in ("1", "true", "yes", "on")
        try:
            max_r = int(os.environ.get("RMA_AGENT_REFLECT_RETRIES", "1"))
        except ValueError:
            max_r = 1
        return cls(
            project_root=proj,
            app_root=app_p,
            llm_provider=os.environ.get("RMA_LLM_PROVIDER", "ollama").strip().lower(),
            ollama_model=os.environ.get("RMA_OLLAMA_MODEL", "llama3.1:latest").strip(),
            ollama_host=os.environ.get("RMA_OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/"),
            openai_base_url=os.environ.get("RMA_OPENAI_BASE_URL", "http://127.0.0.1:11434/v1").rstrip("/"),
            openai_api_key=os.environ.get("RMA_OPENAI_API_KEY", "local-no-key"),
            openai_model=os.environ.get("RMA_OPENAI_MODEL", "openllama").strip(),
            claude_model=os.environ.get("RMA_CLAUDE_MODEL", "claude-3-5-sonnet-latest").strip(),
            skip_reflect=skip,
            max_reflection_retries=max(0, min(max_r, 3)),
        )
