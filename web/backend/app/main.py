from __future__ import annotations

import json
import shutil
from pathlib import Path

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
import subprocess
from typing import Iterator

from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from .constants import ENV_FILE_KEYS
from .env_service import apply_masks_for_client, mask_values, merge_env_file, parse_env_file
from .python_envs import discover_python_envs
from .rma_runner import doctor_json, run_rma, tools_manifest
from .settings import get_settings, parse_cors_list
from .web_yaml import read_web_yaml_stack_meta

app = FastAPI(title="ROADMAP-AGENT Web", version="1.0.0")
_settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=parse_cors_list(_settings.cors_origins),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_DIST = Path(__file__).resolve().parents[2] / "frontend" / "dist"


def require_write_token(
    request: Request,
    x_rma_web_token: str | None = Header(default=None, alias="X-RMA-Web-Token"),
) -> None:
    token = get_settings().admin_token
    if not token:
        return
    if request.method in ("GET", "HEAD", "OPTIONS"):
        return
    if x_rma_web_token != token:
        raise HTTPException(status_code=401, detail="Invalid or missing X-RMA-Web-Token")


class ProjectBody(BaseModel):
    path: str = Field(..., description="Absolute project root (ROADMAP_AGENT_PROJECT_ROOT)")


class EnvUpdateBody(BaseModel):
    values: dict[str, str | None] = Field(default_factory=dict)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/manifest")
def api_manifest(project: str) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    try:
        return tools_manifest(root)
    except Exception as e:
        raise HTTPException(502, f"tools --json failed: {e}") from e


@app.get("/api/env")
def api_env_get(project: str) -> dict:
    root = Path(project).expanduser().resolve()
    env_path = root / ".env"
    raw = parse_env_file(env_path)
    return {"path": str(env_path), "values": mask_values(raw)}


@app.put("/api/env")
def api_env_put(
    project: str,
    body: EnvUpdateBody,
    _: None = Depends(require_write_token),
) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    env_path = root / ".env"
    stored = parse_env_file(env_path)
    merged = apply_masks_for_client(stored, body.values)
    to_write = {k: v for k, v in merged.items() if k in ENV_FILE_KEYS}
    merge_env_file(env_path, to_write)
    return {"ok": True, "path": str(env_path), "values": mask_values(parse_env_file(env_path))}


@app.get("/api/project-info")
def api_project_info(project: str) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    rma = root / ".rma"
    return {
        "root": str(root),
        "has_rma_dir": rma.is_dir(),
        "has_env": (root / ".env").is_file(),
    }


_WEB_STACK_KEYS = frozenset(
    {
        "RMA_WEB_HOST",
        "RMA_WEB_PORT",
        "RMA_WEB_VITE_PORT",
        "RMA_WEB_FREE_PORT_ASK",
        "RMA_WEB_VITE_PROXY_TARGET",
    },
)


@app.get("/api/web-stack")
def api_web_stack(project: str) -> dict:
    """Hub VII/VIII-related settings: project .env subset + running API effective bind + YAML paths."""
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    s = get_settings()
    app_root = s.app_root.resolve()
    raw = parse_env_file(root / ".env")
    from_env = {k: raw[k] for k in _WEB_STACK_KEYS if k in raw}
    y_tool = app_root / "web" / "rma-web.yaml"
    y_ex = app_root / "web" / "rma-web.config.example.yaml"
    return {
        "projectRoot": str(root),
        "effectiveApi": {"host": s.host, "port": s.port},
        "fromProjectDotEnv": from_env,
        "fromToolkitYaml": read_web_yaml_stack_meta(app_root),
        "toolkitYamlPath": str(y_tool),
        "toolkitYamlExists": y_tool.is_file(),
        "yamlExamplePath": str(y_ex),
        "yamlExampleExists": y_ex.is_file(),
    }


@app.get("/api/doctor")
def api_doctor(project: str) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    try:
        return doctor_json(root)
    except json.JSONDecodeError as e:
        raise HTTPException(502, f"doctor JSON parse error: {e}") from e
    except Exception as e:
        raise HTTPException(502, str(e)) from e


class OllamaTagsResponse(BaseModel):
    models: list[str]
    error: str | None = None


@app.get("/api/models/ollama", response_model=OllamaTagsResponse)
def api_models_ollama(host: str) -> OllamaTagsResponse:
    base = host.rstrip("/")
    url = f"{base}/api/tags"
    try:
        with httpx.Client(timeout=10.0) as client:
            r = client.get(url)
            r.raise_for_status()
            data = r.json()
        names: list[str] = []
        for m in data.get("models") or []:
            n = m.get("name")
            if n:
                names.append(n)
        return OllamaTagsResponse(models=sorted(set(names)))
    except Exception as e:
        return OllamaTagsResponse(models=[], error=str(e))


class OpenAIModelsResponse(BaseModel):
    models: list[str]
    error: str | None = None


@app.get("/api/models/openai-compatible", response_model=OpenAIModelsResponse)
def api_models_openai(base_url: str) -> OpenAIModelsResponse:
    b = base_url.rstrip("/")
    if b.endswith("/v1"):
        url = f"{b}/models"
    else:
        url = f"{b}/v1/models"
    try:
        with httpx.Client(timeout=15.0) as client:
            r = client.get(url)
            r.raise_for_status()
            data = r.json()
        ids: list[str] = []
        for m in data.get("data") or []:
            mid = m.get("id")
            if mid:
                ids.append(mid)
        return OpenAIModelsResponse(models=sorted(set(ids)))
    except Exception as e:
        return OpenAIModelsResponse(models=[], error=str(e))


class ConnectionTestBody(BaseModel):
    provider: str  # ollama | openllama | claude
    ollama_host: str | None = None
    ollama_model: str | None = None
    openai_base_url: str | None = None
    openai_model: str | None = None
    openai_api_key: str | None = None
    anthropic_api_key: str | None = None
    claude_model: str | None = None


class OllamaPullBody(BaseModel):
    model: str
    host: str | None = None  # unused; ollama CLI uses local daemon


@app.post("/api/ollama/pull")
def api_ollama_pull(
    body: OllamaPullBody,
    _: None = Depends(require_write_token),
) -> StreamingResponse:
    exe = shutil.which("ollama")
    if not exe:
        raise HTTPException(400, "ollama CLI not on PATH")

    def lines() -> Iterator[bytes]:
        proc = subprocess.Popen(
            [exe, "pull", body.model],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            bufsize=1,
        )
        assert proc.stdout
        for chunk in iter(lambda: proc.stdout.read(256), b""):
            if chunk:
                yield chunk
        proc.wait()

    return StreamingResponse(lines(), media_type="text/plain; charset=utf-8")


@app.post("/api/test-connection")
def api_test_connection(body: ConnectionTestBody) -> dict:
    """Lightweight reachability check (no full rma invoke)."""
    try:
        if body.provider == "ollama":
            host = (body.ollama_host or "http://127.0.0.1:11434").rstrip("/")
            model = body.ollama_model or "llama3.1:latest"
            tags_url = f"{host}/api/tags"
            with httpx.Client(timeout=10.0) as c:
                r = c.get(tags_url)
                r.raise_for_status()
                data = r.json()
            names = {m.get("name") for m in (data.get("models") or []) if m.get("name")}
            ok = model in names
            return {"ok": ok, "detail": "model in tags" if ok else f"model {model!r} not in /api/tags"}
        if body.provider == "openllama":
            b = (body.openai_base_url or "").rstrip("/")
            if not b:
                return {"ok": False, "detail": "missing base url"}
            if b.endswith("/v1"):
                chat = f"{b}/chat/completions"
            else:
                chat = f"{b}/v1/chat/completions"
            headers = {"Content-Type": "application/json"}
            key = body.openai_api_key or "noop"
            if key and key != "noop":
                headers["Authorization"] = f"Bearer {key}"
            payload = {
                "model": body.openai_model or "default",
                "messages": [{"role": "user", "content": "ping"}],
                "max_tokens": 1,
            }
            with httpx.Client(timeout=20.0) as c:
                r = c.post(chat, json=payload, headers=headers)
            if r.status_code < 400:
                return {"ok": True, "detail": "chat/completions accepted"}
            return {"ok": False, "detail": f"HTTP {r.status_code}: {r.text[:200]}"}
        if body.provider == "claude":
            key = body.anthropic_api_key or ""
            if not key:
                return {"ok": False, "detail": "missing ANTHROPIC_API_KEY"}
            model = body.claude_model or "claude-3-5-sonnet-latest"
            with httpx.Client(timeout=20.0) as c:
                r = c.post(
                    "https://api.anthropic.com/v1/messages",
                    headers={
                        "x-api-key": key,
                        "anthropic-version": "2023-06-01",
                        "content-type": "application/json",
                    },
                    json={
                        "model": model,
                        "max_tokens": 1,
                        "messages": [{"role": "user", "content": "ping"}],
                    },
                )
            if r.status_code < 400:
                return {"ok": True, "detail": "messages accepted"}
            return {"ok": False, "detail": f"HTTP {r.status_code}: {r.text[:200]}"}
        return {"ok": False, "detail": f"unknown provider {body.provider}"}
    except Exception as e:
        return {"ok": False, "detail": str(e)}


class RunCmdBody(BaseModel):
    args: list[str]


class InitBody(BaseModel):
    """Flags passed to `rma init` (non-interactive UI uses -y)."""

    flags: list[str] = Field(default_factory=lambda: ["-y"])


@app.get("/api/python-envs")
def api_python_envs(project: str) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    return {"project": str(root), "envs": discover_python_envs(root)}


@app.post("/api/project/init")
def api_project_init(
    project: str,
    body: InitBody | None = None,
    _: None = Depends(require_write_token),
) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    flags = list(body.flags) if body else ["-y"]
    proc = run_rma(root, ["init", *flags], timeout=600.0)
    return {
        "returncode": proc.returncode,
        "stdout": proc.stdout[-24000:] if proc.stdout else "",
        "stderr": proc.stderr[-24000:] if proc.stderr else "",
    }


@app.post("/api/project/setup-venv")
def api_project_setup_venv(
    project: str,
    _: None = Depends(require_write_token),
) -> dict:
    """Run `rma setup-venv` (MemPalace / chromadb in project venv). Long-running."""
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    proc = run_rma(root, ["setup-venv"], timeout=900.0)
    return {
        "returncode": proc.returncode,
        "stdout": proc.stdout[-24000:] if proc.stdout else "",
        "stderr": proc.stderr[-24000:] if proc.stderr else "",
    }


@app.post("/api/run/rma")
def api_run_rma(
    project: str,
    body: RunCmdBody,
    _: None = Depends(require_write_token),
) -> dict:
    root = Path(project).expanduser().resolve()
    proc = run_rma(root, body.args, timeout=600.0)
    return {
        "returncode": proc.returncode,
        "stdout": proc.stdout[-12000:] if proc.stdout else "",
        "stderr": proc.stderr[-12000:] if proc.stderr else "",
    }


# Optional: serve built SPA
if _DIST.is_dir():
    app.mount("/assets", StaticFiles(directory=_DIST / "assets"), name="assets")

    @app.get("/")
    def spa_index() -> FileResponse:
        return FileResponse(_DIST / "index.html")

    @app.get("/{full_path:path}")
    def spa_fallback(full_path: str) -> FileResponse:
        if full_path.startswith("api"):
            raise HTTPException(404, "Not found")
        target = _DIST / full_path
        if target.is_file():
            return FileResponse(target)
        return FileResponse(_DIST / "index.html")

