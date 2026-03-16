# dotfiles

Personal dotfiles and agent configuration powered by the [Oracle Operating Model](AGENTS.md).

## Install

```bash
git clone <this-repo> ~/Projects/dotfiles
cd ~/Projects/dotfiles
```

### Shell

```bash
cp .zshrc ~/.zshrc
cp .zshenv ~/.zshenv
```

### Agent profiles

```bash
# Claude
cp .claude/settings.json ~/.claude/settings.json
cp .claude-e2e/settings.json ~/.claude-e2e/settings.json

# Codex
mkdir -p ~/.codex
cp .codex/config.toml ~/.codex/config.toml

# OpenCode
mkdir -p ~/.config/opencode
cp .config/opencode/opencode.json ~/.config/opencode/opencode.json

# Amp
mkdir -p ~/.config/amp
cp .config/amp/settings.json ~/.config/amp/settings.json

# Starship prompt
cp .config/starship.toml ~/.config/starship.toml

# mise tool versions
mkdir -p ~/.config/mise
cp .config/mise/config.toml ~/.config/mise/config.toml
```

### Agent instructions (AGENTS.md + skills)

Copy to each agent's home directory:

```bash
for dir in ~/.claude ~/.claude-e2e ~/.codex ~/.config/agents; do
  mkdir -p "$dir/skills"
  cp AGENTS.md "$dir/AGENTS.md"
  cp -R skills/* "$dir/skills/"
done

cp CLAUDE.md ~/.claude/CLAUDE.md
cp CLAUDE.md ~/.claude-e2e/CLAUDE.md
```

### Terminal (Ghostty + iTerm2)

```bash
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
cp "Library/Application Support/com.mitchellh.ghostty/config" \
   "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

# iTerm2 — quit iTerm2 first, then:
cp "Library/Preferences/com.googlecode.iterm2.plist" \
   "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
```

### Git

```bash
cp .gitconfig ~/.gitconfig
cp .gitignore_global ~/.gitignore_global
cp .npmrc ~/.npmrc
```

### Scripts

```bash
cp bin/sync-op ~/bin/sync-op
cp bin/upgrade-ai-tools ~/bin/upgrade-ai-tools
chmod +x ~/bin/sync-op ~/bin/upgrade-ai-tools
```

### Secrets (1Password)

Secrets are stored in 1Password and synced to flat `.env` files via `sync-op`:

| File | Vault | Keys |
|------|-------|------|
| `~/.config/usezombie/.env` | `ZMB_LOCAL_ENV` | `OP_SERVICE_ACCOUNT_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `OPENROUTER_API_KEY`, `FIREWORKS_API_KEY`, `OLLAMA_CLOUD_API_KEY` |
| `~/.config/e2e/.env` | `E2E_WORK` | `GITLAB_PERSONAL_ACCESS_TOKEN`, `DOCKER_USER_*`, `DOCKER_PASSWORD_*` |

Bootstrap: set `OP_SERVICE_ACCOUNT_TOKEN` in `~/.config/usezombie/.env`, then run:

```bash
sync-op
```

## Update

```bash
cd ~/Projects/dotfiles && git pull
```

Then re-copy whichever files changed. No deploy script — just `cp`.

## Structure

```
dotfiles/
├── bin/                    # sync-op, upgrade-ai-tools
├── .claude/                # Claude settings
├── .claude-e2e/            # Claude E2E settings
├── .codex/                 # Codex config
├── .config/
│   ├── amp/                # Amp settings
│   ├── mise/               # Tool versions
│   ├── opencode/           # OpenCode config (Fireworks, OpenRouter, Ollama)
│   └── starship.toml       # Prompt theme
├── docs/                   # Behavioral guardrails, stack, worktree docs
├── Library/                # Ghostty + iTerm2 configs
├── runbooks/               # Mac VM runbook
├── skills/                 # Agent skills (oracle, review, ship, etc.)
├── AGENTS.md               # Oracle Operating Model
├── CLAUDE.md               # Claude pointer to AGENTS.md
├── .zshrc                  # Shell config (sources ~/.config/usezombie/.env + ~/.config/e2e/.env)
└── .zshenv                 # LSCOLORS
```

## License

MIT
