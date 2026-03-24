# dotfiles

Personal dotfiles and agent configuration powered by [gstack](https://github.com/garrytan/gstack) (Oracle Operating Model in [AGENTS.md](AGENTS.md)).

## Quick Start

```bash
git clone <this-repo> ~/Projects/dotfiles
cd ~/Projects/dotfiles
```

## Install

### macOS Shell
```bash
cp .zshrc ~/.zshrc
```

### Agent profiles
```bash
# Claude
cp .claude/settings.json ~/.claude/settings.json
cp .claude-e2e/settings.json ~/.claude-e2e/settings.json

# Codex
mkdir -p ~/.codex && cp .codex/config.toml ~/.codex/config.toml

# OpenCode
mkdir -p ~/.config/opencode && cp .config/opencode/opencode.json ~/.config/opencode/opencode.json

# Amp
mkdir -p ~/.config/amp && cp .config/amp/settings.json ~/.config/amp/settings.json

# Starship + mise
cp .config/starship.toml ~/.config/starship.toml
mkdir -p ~/.config/mise && cp .config/mise/config.toml ~/.config/mise/config.toml
```

### Terminal (Ghostty + iTerm2)
```bash
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
cp "Library/Application Support/com.mitchellh.ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

cp "Library/Preferences/com.googlecode.iterm2.plist" "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
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
cp bin/sync-skills ~/bin/sync-skills
cp bin/upgrade-ai-tools ~/bin/upgrade-ai-tools
chmod +x ~/bin/sync-op ~/bin/sync-skills ~/bin/upgrade-ai-tools
```

### Skills
```bash
echo "gstack/" >> ~/Projects/dotfiles/.gitignore
sync-skills
```

### Secrets (1Password)
Secrets sync via `sync-op` from 1Password vaults:
- `ZMB_LOCAL_ENV` → `~/.config/usezombie/.env`
- `E2E_WORK` → `~/.config/e2e/.env`

Bootstrap: set `OP_SERVICE_ACCOUNT_TOKEN` in `~/.config/usezombie/.env`, then run `sync-op`.

## Update
```bash
cd ~/Projects/dotfiles && git pull
```

Then re-copy changed files. No deploy script — just `cp`.

## Structure

```
dotfiles/
├── bin/                      # sync-op, sync-skills, upgrade-ai-tools
├── gstack/                   # Cloned skills (gitignored)
├── .claude/                  # Claude settings
├── .claude-e2e/              # Claude E2E settings
├── .codex/                   # Codex config
├── .config/
│   ├── amp/
│   ├── mise/
│   ├── opencode/
│   └── starship.toml
├── Library/                  # Ghostty + iTerm2
├── runbooks/
├── skills/
├── AGENTS.md
├── CLAUDE.md
├── .zshrc
└── .zshenv
```

## License

MIT
