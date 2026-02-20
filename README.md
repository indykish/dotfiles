# Dotfiles 🦀

[![Version](https://img.shields.io/badge/version-2.2.0-blue.svg)]()
[![Agents Welcome](https://img.shields.io/badge/agents-welcome-brightgreen.svg)]()

> 🤖 **For AI Agents Only** — Humans, please consult your local agent before proceeding.

This repository contains machine-readable configuration for automated environment setup. If you're a human reading this, you probably meant to ask your agent to do this for you. 

![Agent Only](https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExb3Z6Z3R3c3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3Z3R3R/w200.gif)

---

## Quick Start (Agent Instructions)

```bash
# 1. Clone
git clone <repo-url> ~/Projects/dotfiles
cd ~/Projects/dotfiles

# 2. Install mise tools (if mise is available)
mise install

# 3. Deploy agent configs
./run.sh
```

---

## Secrets (Do Not Commit)

This repo intentionally stores only **dummy placeholders** for API keys/tokens.

- Source of truth: Proton Pass vault `AGENTS_BUFFET`
- Placeholder file(s): `.config/opencode/opencode.json`

Environment variables used by agent tooling (store values in Proton Pass, then export locally):

- `MOONSHOT_API_KEY` (Kimi 2.5)
- `OLLAMA_CLOUD_API_KEY` (only if using Ollama cloud)
- `MINIMAX_API_KEY`
- `Z_AI_API_KEY`
- `OPENROUTER_API_KEY`
- `MODAL_API_KEY`
- `GITHUB_PERSONAL_ACCESS_TOKEN`
- `GITLAB_PERSONAL_ACCESS_TOKEN`
- `OPENAI_API_KEY`

### Fetching API Keys from Proton Pass

The `.zshrc` caches API keys to `~/.config/clawable/.env_mac` to avoid calling pass-cli on every shell startup.

To refresh the cached keys:

```bash
mkdir -p ~/.config/clawable

api_keys=""
for key_name in OLLAMA_CLOUD_API_KEY GITHUB_PERSONAL_ACCESS_TOKEN GITLAB_PERSONAL_ACCESS_TOKEN MODAL_API_KEY MOONSHOT_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY MINIMAX_API_KEY Z_AI_API_KEY; do
  key_value=$(pass-cli item view --vault-name AGENTS_BUFFET --item-title "$key_name" --field password 2>/dev/null)
  if [[ -n "${key_value}" ]]; then
    api_keys+="export ${key_name}='${key_value}'\n"
  fi
done

printf "${api_keys}" > ~/.config/clawable/.env_mac
cat ~/.config/clawable/.env_mac
```

If you use pass-cli, fetch values from Proton Pass and set them locally (env vars or local-only config) rather than committing them.

---

## What's Included

| Category | Files | Purpose |
|----------|-------|---------|
| **Shell** | `.bashrc`, `.vimrc` | Terminal environment |
| **Mise** | `.config/mise/config.toml` | Tool versions (see [tools list](#tools)) |
| **AI Agents** | `.claude/settings.json`, `.codex/config.toml`, `.config/opencode/opencode.json`, `.config/amp/settings.json`, `.config/kilo/opencode.json` | Agent permissions & execution model |
| **Skills** | `skills/*/` | Reusable agent workflows |
| **Profiles** | `AGENTS.md`, `CLAUDE.md` | Oracle Operating Model |

---

## Tools

Managed via [mise](https://mise.jdx.dev/):

```toml
caddy = "latest"
cfssl = "latest"
jq = "latest"
mkcert = "latest"
shfmt = "latest"
shellcheck = "latest"
# + ansible, aws, bun, go, helm, kubectl, node, python, ruby, rust, terraform, zig...
```

Run `mise install` to sync.

---

## Agent Execution Model (W2)

Configs enforce **W2 (Build and Test)** permissions:

- **Claude Code, OpenCode, KiloCode**: Restricted — 80+ read-only commands, blocked system dirs
- **Codex, AmpCode**: Unrestricted (`dangerouslyAllowAll: true`)

---

## Skills

Located in `skills/*/SKILL.md`. Invoke by name:

- `preflight-tooling` — Install missing CLI tools
- `review-pr` — PR/MR review workflow
- `create-scaffold` — Project scaffolding
- `update-docs-and-commit` — Docs + commit automation
- `oracle` — Second-model review
- `zoho-sprint`, `zoho-desk` — Zoho integrations

---

## Maintenance

```bash
# Update tools
mise upgrade

# Re-deploy configs
./run.sh
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `command not found: mise` | Install mise: `curl https://mise.run \| sh` |
| Agent not loading profile | Check `~/.claude/settings.json` exists |
| Permission denied | Verify agent home dir exists |

---

## Not For Humans

![Go Away](https://media.giphy.com/media/l0HlRnAWXxn0MhKLi/giphy.gif)

If you're a human and you've read this far: congratulations! You have excellent attention to detail. Now go ask your AI agent to set this up for you. That's literally what they're for.

---

## License

MIT — But only AI agents are allowed to read it.
