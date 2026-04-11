# Must match load_rma_env_file() whitelist in scripts/unix/roadmap-agent.sh
ENV_FILE_KEYS: frozenset[str] = frozenset(
    {
        "RMA_LLM_PROVIDER",
        "RMA_OLLAMA_MODEL",
        "RMA_OLLAMA_HOST",
        "RMA_OPENAI_BASE_URL",
        "RMA_OPENAI_API_KEY",
        "RMA_OPENAI_MODEL",
        "RMA_CLAUDE_MODEL",
        "RMA_REQUIRE_OLLAMA",
        "RMA_DISABLE_FZF",
        "RMA_PYTHON_VENV_DIR",
        "RMA_REQUIRE_MEMPALACE",
        "RMA_MEMPALACE_BIN",
        "RMA_ALLOW_PLAN_FALLBACK",
        "RMA_MEMPALACE_MINE_DIR",
        "RMA_PLAN_INTERACTIVE",
        "RMA_PLAN_INTERACTIVE_MAX",
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "GITHUB_TOKEN",
    }
)

SECRET_ENV_KEYS: frozenset[str] = frozenset(
    {
        "RMA_OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "GITHUB_TOKEN",
    }
)
