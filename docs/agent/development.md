# Modular terminal agent — development

## Layout

- **`rma_agent/orchestrator.py`** — session loop, logging, reflection/replan bounds.
- **`rma_agent/planner.py`** / **`reflector.py`** — LLM prompts; **`rma_agent/core/llm.py`** implements providers.
- **`rma_agent/executor.py`** — single dispatch into **`ToolRegistry`**.
- **`rma_agent/tools/registry.py`** — register and execute tools by name.
- **`rma_agent/tools/roadmap_tools.py`** — subprocess bridge to **`roadmap-agent.sh`**.
- **`rma_agent/memory/`** — short-term deque, JSONL long-term store, `.rma` markdown context loader.

## Tests

```bash
pip install -r requirements-dev.txt
python -m pytest tests/test_rma_agent_registry.py tests/test_rma_agent_orchestrator.py -v
```

Tests mock **`plan_next_step`**, **`execute_step`**, and **`reflect_step`** where needed so CI does not require bash, Ollama, or network.

## Extending tools

1. Add a handler in **`roadmap_tools.py`** (or a new module) that returns **`ExecutionResult`**.
2. **`reg.register("name", "description", handler)`** — the **`description`** is exposed to the planner as tool metadata JSON.
3. Extend **`AgentActionName`** and planner prompt literals in **`schemas.py`** / **`planner.py`** if you add a new top-level action.

Keep handlers thin: prefer delegating to **`roadmap-agent.sh`** until behavior is ported to shared libraries.

## Bash integration

**`cmd_agent`** in **`scripts/unix/roadmap-agent.sh`** exports:

- **`ROADMAP_AGENT_PROJECT_ROOT`** (default **`ROOT_DIR`**)
- **`ROADMAP_AGENT_APP_ROOT`** (default **`APP_DIR`**)
- **`PYTHONPATH`** including **`APP_DIR`**

then runs **`python -m rma_agent run ...`**.
