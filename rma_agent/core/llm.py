"""Thin LLM wrapper mirroring scripts/unix/roadmap-agent.sh call_agent_llm paths."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import urllib.error
import urllib.request
from typing import Callable


def clean_llm_output(raw: str) -> str:
    """Strip common markdown fences from model output."""
    lines = raw.strip().splitlines()
    if not lines:
        return ""
    if lines[0].strip().startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip() == "```":
        lines = lines[:-1]
    return "\n".join(lines).strip()


def complete_text(
    prompt: str,
    *,
    provider: str,
    ollama_model: str,
    ollama_host: str,
    openai_base_url: str,
    openai_api_key: str,
    openai_model: str,
    claude_model: str,
    timeout_s: int = 600,
) -> str:
    """Return raw model text (may be JSON string inside)."""
    provider = provider.strip().lower()
    if provider == "ollama":
        return _ollama_complete(prompt, ollama_model, ollama_host, timeout_s)
    if provider == "openllama":
        return clean_llm_output(
            _openai_compatible_chat(prompt, openai_base_url, openai_api_key, openai_model, timeout_s)
        )
    if provider == "claude":
        key = os.environ.get("ANTHROPIC_API_KEY", "")
        if not key:
            return ""
        return clean_llm_output(_claude_messages(prompt, key, claude_model, timeout_s))
    return ""


def _ollama_complete(prompt: str, model: str, host: str, timeout_s: int) -> str:
    if shutil.which("ollama"):
        try:
            r = subprocess.run(
                ["ollama", "run", model, prompt, "--format", "json"],
                capture_output=True,
                text=True,
                timeout=timeout_s,
                env=os.environ.copy(),
            )
            return (r.stdout or "").strip()
        except (subprocess.TimeoutExpired, OSError):
            return ""
    if shutil.which("curl"):
        try:
            body = json.dumps(
                {"model": model, "prompt": prompt, "stream": False, "format": "json"}
            ).encode("utf-8")
            req = urllib.request.Request(
                f"{host}/api/generate",
                data=body,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=timeout_s) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                return str(data.get("response", "")).strip()
        except (urllib.error.URLError, OSError, json.JSONDecodeError, TypeError):
            return ""
    return ""


def _openai_compatible_chat(
    prompt: str, base: str, key: str, model: str, timeout_s: int
) -> str:
    body = json.dumps(
        {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.2,
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        f"{base}/chat/completions",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as r:
            data = json.loads(r.read().decode("utf-8"))
            return str(data["choices"][0]["message"]["content"])
    except (urllib.error.URLError, OSError, KeyError, IndexError, json.JSONDecodeError, TypeError):
        return ""


def _claude_messages(prompt: str, api_key: str, model: str, timeout_s: int) -> str:
    body = json.dumps(
        {
            "model": model,
            "max_tokens": 4096,
            "temperature": 0.2,
            "messages": [{"role": "user", "content": prompt}],
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=body,
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as r:
            data = json.loads(r.read().decode("utf-8"))
            chunks = data.get("content", [])
            return "".join(c.get("text", "") for c in chunks if c.get("type") == "text")
    except (urllib.error.URLError, OSError, KeyError, json.JSONDecodeError, TypeError):
        return ""


def parse_json_object(raw: str, model_cls: Callable[[dict], object]) -> object:
    """Parse JSON from model output; strip fences; validate with model_cls (e.g. AgentStep.model_validate)."""
    text = clean_llm_output(raw)
    if not text:
        raise ValueError("empty LLM output")
    # Handle ollama --format json wrapping content in a string sometimes
    try:
        outer = json.loads(text)
        if isinstance(outer, dict) and "thought" not in outer and "response" in outer:
            inner = outer.get("response")
            if isinstance(inner, str):
                text = inner.strip()
            elif isinstance(inner, dict):
                return model_cls(inner)
    except json.JSONDecodeError:
        pass
    data = json.loads(text)
    return model_cls(data)
