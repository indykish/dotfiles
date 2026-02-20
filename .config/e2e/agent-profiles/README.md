# Agent Profile Configs

This directory stores tracked baselines that `scripts/run.sh` deploys into user-level config homes.

- Codex baseline: `.codex/config.toml` -> `~/.codex/config.toml`
- Agent profile templates/scripts: `.config/e2e/agent-profiles/*` -> `~/.config/e2e/agent-profiles/*`

## Required Values To Validate Per User

- `model`
- `model_reasoning_effort`
- `tool_output_token_limit`
- `model_auto_compact_token_limit`
- `web_search`
- User-specific trust entries (if needed)

## Sensitive Data Rule

Do not commit credential files such as:

- `~/.codex/auth.json`
- API keys in env files

Tracked config files should remain non-secret configuration only.

## Update Procedure

```bash
cp ~/.codex/config.toml .codex/config.toml
git diff .codex/config.toml
```
