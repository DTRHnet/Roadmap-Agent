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
from .env_service import apply_masks_for_client, mask_values, merge_env_file, parse_env_blob, parse_env_file
from .mcp_import import (
    delete_server,
    export_cursor_bundle,
    load_store,
    merge_import_text,
    update_server,
)
from .python_envs import discover_python_envs
from .path_display import clip_rma_streams
from .rma_runner import doctor_json, run_rma, tools_manifest
from .settings import get_settings, parse_cors_list
from .web_yaml import read_web_yaml_stack_meta

app = FastAPI(title="ROADMAP-AGENT Web", version="1.1.1-b")
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


class EnvImportBody(BaseModel):
    text: str = Field(default="", description="Pasted .env or KEY=value lines")


class McpImportBody(BaseModel):
    text: str = Field(default="", description="Cursor / Claude style JSON with mcpServers")
    replace_existing: bool = Field(default=False, description="If true, replace all imported entries with this file only")


class McpServerPatchBody(BaseModel):
    enabled: bool | None = None
    label: str | None = Field(default=None, max_length=80)


class AutopilotAgentBody(BaseModel):
    goal: str = Field(..., min_length=1, max_length=8000)
    max_steps: int = Field(15, ge=1, le=100)
    yes: bool = Field(default=True, description="Pass -y (no pause between agent steps)")
    confirm_execute_one: bool = Field(
        default=False,
        description="Allow agent to invoke interactive execute-one (still terminal-limited)",
    )
    require_ollama: bool = Field(default=False, description="Fail fast if Ollama model unreachable")


@app.get("/api/env/keys")
def api_env_keys() -> dict:
    """All variable names whitelisted for project .env (same as CLI load_rma_env_file)."""
    return {"keys": sorted(ENV_FILE_KEYS)}


@app.get("/api/env/service-status")
def api_env_service_status(project: str) -> dict:
    """Aggregated connectivity signals for Env Studio (green/red badges)."""
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    raw = parse_env_file(root / ".env")
    prov = (raw.get("RMA_LLM_PROVIDER") or "ollama").strip().lower()

    def svc(ok: bool, detail: str) -> dict[str, str | bool]:
        return {"ok": ok, "detail": detail}

    out: dict[str, dict[str, str | bool]] = {}

    # Ollama (live probe only when provider is ollama)
    host = (raw.get("RMA_OLLAMA_HOST") or "http://127.0.0.1:11434").rstrip("/")
    model = raw.get("RMA_OLLAMA_MODEL") or "llama3.1:latest"
    if prov != "ollama":
        out["ollama"] = svc(True, "skipped live Ollama probe (set RMA_LLM_PROVIDER=ollama to test)")
    else:
        try:
            with httpx.Client(timeout=6.0) as c:
                r = c.get(f"{host}/api/tags")
                r.raise_for_status()
                data = r.json()
            names = {m.get("name") for m in (data.get("models") or []) if m.get("name")}
            if model in names:
                out["ollama"] = svc(True, f"model {model!r} on {host}")
            else:
                out["ollama"] = svc(False, f"model {model!r} not in /api/tags")
        except Exception as e:
            out["ollama"] = svc(False, str(e))

    # OpenAI-compatible (live GET only when provider is openllama)
    burl = (raw.get("RMA_OPENAI_BASE_URL") or "").strip().rstrip("/")
    if not burl:
        out["openaiCompat"] = svc(False, "RMA_OPENAI_BASE_URL not set")
    elif prov != "openllama":
        out["openaiCompat"] = svc(True, "URL set; live /v1/models test when RMA_LLM_PROVIDER=openllama")
    else:
        try:
            if burl.endswith("/v1"):
                murl = f"{burl}/models"
            else:
                murl = f"{burl}/v1/models"
            headers = {}
            key = raw.get("RMA_OPENAI_API_KEY") or ""
            if key and key not in ("local-no-key", "noop"):
                headers["Authorization"] = f"Bearer {key}"
            with httpx.Client(timeout=8.0) as c:
                r = c.get(murl, headers=headers)
            out["openaiCompat"] = svc(r.status_code < 400, f"GET {murl} → HTTP {r.status_code}")
        except Exception as e:
            out["openaiCompat"] = svc(False, str(e))

    # Claude (live ping only when provider is claude to avoid API calls in ollama-only workflows)
    ak = raw.get("ANTHROPIC_API_KEY") or ""
    if not ak:
        out["claude"] = svc(False, "ANTHROPIC_API_KEY empty in .env")
    elif prov != "claude":
        out["claude"] = svc(True, "key present; live Anthropic test runs when RMA_LLM_PROVIDER=claude")
    else:
        try:
            with httpx.Client(timeout=12.0) as c:
                r = c.post(
                    "https://api.anthropic.com/v1/messages",
                    headers={
                        "x-api-key": ak,
                        "anthropic-version": "2023-06-01",
                        "content-type": "application/json",
                    },
                    json={
                        "model": raw.get("RMA_CLAUDE_MODEL") or "claude-3-5-sonnet-latest",
                        "max_tokens": 1,
                        "messages": [{"role": "user", "content": "ping"}],
                    },
                )
            out["claude"] = svc(r.status_code < 400, f"messages API HTTP {r.status_code}")
        except Exception as e:
            out["claude"] = svc(False, str(e))

    # Project web API (from .env host/port — may differ from this FastAPI process)
    wh = raw.get("RMA_WEB_HOST") or "127.0.0.1"
    if wh in ("0.0.0.0", "::"):
        wh = "127.0.0.1"
    try:
        wp = int(raw.get("RMA_WEB_PORT") or "8765")
    except ValueError:
        wp = 8765
    try:
        with httpx.Client(timeout=3.0) as c:
            r = c.get(f"http://{wh}:{wp}/api/health")
        out["projectWebApi"] = svc(r.status_code < 400, f"http://{wh}:{wp}/api/health → {r.status_code}")
    except Exception as e:
        out["projectWebApi"] = svc(False, str(e))

    # MCP (runtime file + optional HTTP ping)
    rt = root / ".rma" / "mcp" / "runtime.json"
    if rt.is_file():
        try:
            data = json.loads(rt.read_text(encoding="utf-8", errors="replace"))
            url = data.get("url") or data.get("httpUrl")
            if isinstance(url, str) and url.startswith("http"):
                ok_mcp = False
                detail_m = ""
                try:
                    with httpx.Client(timeout=4.0) as c:
                        r = c.get(url.rstrip("/"), follow_redirects=True)
                    ok_mcp = r.status_code < 500
                    detail_m = f"GET {url} → HTTP {r.status_code}"
                except Exception as e:
                    ok_mcp = True
                    detail_m = f"runtime.json; URL set; probe: {e}"
                out["mcp"] = svc(ok_mcp, detail_m)
            else:
                out["mcp"] = svc(True, "runtime.json present (stdio or no HTTP URL)")
        except Exception as e:
            out["mcp"] = svc(True, f"runtime.json present (parse note: {e})")
    else:
        out["mcp"] = svc(False, "no .rma/mcp/runtime.json")

    # Doctor / rma_agent
    try:
        dj = doctor_json(root)
        ra_ok = bool(dj.get("rma_agent_import_ok"))
        out["rmaAgent"] = svc(ra_ok, "rma_agent + pydantic import" if ra_ok else "install requirements-agent.txt")
        out["doctor"] = svc(
            int(dj.get("exitCode") or 0) == 0,
            f"doctor exitCode={dj.get('exitCode')}",
        )
    except Exception as e:
        out["rmaAgent"] = svc(False, str(e))
        out["doctor"] = svc(False, str(e))

    return {"provider": prov, "services": out}


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


@app.post("/api/env/import-text")
def api_env_import_text(
    project: str,
    body: EnvImportBody,
    _: None = Depends(require_write_token),
) -> dict:
    """Merge pasted or external-file content into project .env (whitelisted keys only)."""
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    incoming = parse_env_blob(body.text)
    if not incoming:
        raise HTTPException(400, "No whitelisted KEY=value pairs found in text")
    env_path = root / ".env"
    stored = parse_env_file(env_path)
    merged = {**stored, **incoming}
    merge_env_file(env_path, {k: merged[k] for k in merged if k in ENV_FILE_KEYS})
    return {
        "ok": True,
        "path": str(env_path),
        "importedKeys": sorted(incoming.keys()),
        "values": mask_values(parse_env_file(env_path)),
    }


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


@app.get("/api/mcp/imported")
def api_mcp_imported(project: str) -> dict:
    """List MCP server definitions stored under .rma/mcp/imported-servers.json (Web UI imports)."""
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    store = load_store(root)
    return {"path": str(root / ".rma" / "mcp" / "imported-servers.json"), "store": json.loads(store.model_dump_json())}


@app.post("/api/mcp/import")
def api_mcp_import(
    project: str,
    body: McpImportBody,
    _: None = Depends(require_write_token),
) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    try:
        store = merge_import_text(root, body.text, replace_existing=body.replace_existing)
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    except json.JSONDecodeError as e:
        raise HTTPException(400, f"Invalid JSON: {e}") from e
    return {"ok": True, "count": len(store.servers), "store": json.loads(store.model_dump_json())}


@app.put("/api/mcp/imported/{server_id}")
def api_mcp_imported_patch(
    project: str,
    server_id: str,
    body: McpServerPatchBody,
    _: None = Depends(require_write_token),
) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    try:
        s = update_server(root, server_id, enabled=body.enabled, label=body.label)
    except KeyError:
        raise HTTPException(404, "server id not found") from None
    return {"ok": True, "server": json.loads(s.model_dump_json())}


@app.delete("/api/mcp/imported/{server_id}")
def api_mcp_imported_delete(
    project: str,
    server_id: str,
    _: None = Depends(require_write_token),
) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    try:
        delete_server(root, server_id)
    except KeyError:
        raise HTTPException(404, "server id not found") from None
    return {"ok": True}


@app.get("/api/mcp/export/cursor")
def api_mcp_export_cursor(project: str, include_roadmap_agent: bool = True) -> dict:
    """Merged Cursor-style { mcpServers } for this project + toolkit (paste into client config)."""
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    app_root = get_settings().app_root.resolve()
    store = load_store(root)
    bundle = export_cursor_bundle(root, app_root, store, include_roadmap_agent=include_roadmap_agent)
    return bundle


@app.post("/api/autopilot/agent")
def api_autopilot_agent(
    project: str,
    body: AutopilotAgentBody,
    _: None = Depends(require_write_token),
) -> dict:
    """Run `roadmap-agent agent` with a goal (modular rma_agent loop); long timeout."""
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    args: list[str] = ["agent", "--max-steps", str(body.max_steps)]
    if body.yes:
        args.append("-y")
    if body.confirm_execute_one:
        args.append("--confirm-execute-one")
    if body.require_ollama:
        args.append("--require-ollama")
    args.append(body.goal.strip())
    proc = run_rma(root, args, timeout=3600.0)
    out, err = clip_rma_streams(proc.stdout, proc.stderr)
    return {
        "returncode": proc.returncode,
        "stdout": out,
        "stderr": err,
        "args": args,
    }


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
    timeout_sec: float | None = Field(
        default=None,
        ge=30.0,
        le=3600.0,
        description="Subprocess timeout; default depends on command (plan/analyze-init up to 20 min).",
    )


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
    out, err = clip_rma_streams(proc.stdout, proc.stderr)
    return {
        "returncode": proc.returncode,
        "stdout": out,
        "stderr": err,
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
    out, err = clip_rma_streams(proc.stdout, proc.stderr)
    return {
        "returncode": proc.returncode,
        "stdout": out,
        "stderr": err,
    }


def _default_rma_timeout(args: list[str], override: float | None) -> float:
    if override is not None:
        return float(override)
    if not args:
        return 600.0
    head = args[0].lower()
    long_cmds = frozenset(
        {
            "plan",
            "analyze-init",
            "setup-venv",
            "agent",
            "run-agent",
            "mcp-start",
            "release",
        }
    )
    if head in long_cmds:
        return 1200.0
    return 600.0


@app.get("/api/roadmap/presets")
def api_roadmap_presets() -> dict:
    """Curated CLI invocations for the web console (non-interactive where required)."""
    return {
        "presets": [
            {
                "id": "status",
                "label": "Status",
                "args": ["status"],
                "hint": "Project and roadmap summary",
            },
            {
                "id": "doctor-json",
                "label": "Doctor (JSON)",
                "args": ["doctor", "--json"],
                "hint": "Same as Diagnostics card; useful log snapshot",
            },
            {
                "id": "tools-json",
                "label": "Tools manifest",
                "args": ["tools", "--json"],
                "hint": "Machine-readable command list",
            },
            {
                "id": "plan",
                "label": "Plan (dry-run)",
                "args": ["plan", "--no-interactive"],
                "hint": "Regenerate .rma/roadmaps/plan.md via LLM; may take several minutes",
            },
            {
                "id": "analyze",
                "label": "Analyze",
                "args": ["analyze"],
                "hint": "Sync tasks.md and run.md from the repo",
            },
            {
                "id": "analyze-init-dry",
                "label": "Analyze-init (dry-run)",
                "args": ["analyze-init", "--dry-run"],
                "hint": "Preview proposed .rma context files without writing",
            },
            {
                "id": "unlock",
                "label": "Unlock",
                "args": ["unlock"],
                "hint": "Clear stale roadmap lock",
            },
            {
                "id": "mcp-detach",
                "label": "MCP start (detach)",
                "args": ["mcp-start", "--detach"],
                "hint": "Background MCP HTTP server; see .rma/mcp/runtime.json",
            },
            {
                "id": "agent-autopilot",
                "label": "Agent (autopilot preset)",
                "args": [
                    "agent",
                    "--max-steps",
                    "12",
                    "-y",
                    "Use plan and analyze to align with .rma context; prefer small steps; stop when plan tasks are done or blocked.",
                ],
                "hint": "Modular rma_agent loop (needs working LLM). For custom goals use MCP & Autopilot in the Web UI.",
            },
        ]
    }


@app.post("/api/run/rma")
def api_run_rma(
    project: str,
    body: RunCmdBody,
    _: None = Depends(require_write_token),
) -> dict:
    root = Path(project).expanduser().resolve()
    if not root.is_dir():
        raise HTTPException(400, "Not a directory")
    timeout = _default_rma_timeout(body.args, body.timeout_sec)
    proc = run_rma(root, body.args, timeout=timeout)
    out, err = clip_rma_streams(proc.stdout, proc.stderr)
    return {
        "returncode": proc.returncode,
        "stdout": out,
        "stderr": err,
        "timeout_sec": timeout,
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

