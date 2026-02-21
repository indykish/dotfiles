# dotfiles

![Version](https://img.shields.io/badge/version-2.8.0-blue)

![This is fine](https://i.imgflip.com/2/1otk96.jpg)
*Me watching my agents edit my dotfiles at 3 AM.*

---

Personal dotfiles powered by the [Oracle Operating Model](AGENTS.md) — a single-role agent contract that makes AI coding agents deterministic and useful.

## Setup

```bash
git clone <this-repo> ~/Projects/dotfiles
cd ~/Projects/dotfiles
./scripts/run.sh
```

## What it does

`run.sh` deploys agent profiles and skills into your local agent config directories. Agents auto-load the profile at session start — zero typing needed.

It also manages `~/.zshrc` from `~/Projects/dotfiles/.zshrc`:

- If `~/.zshrc` is missing, it is copied automatically.
- If `~/.zshrc` already exists, `run.sh` prompts before replacing it because the dotfiles version is opinionated.
- On replacement, the previous file is backed up as `~/.zshrc.bak.<timestamp>`.

The Oracle lifecycle runs on every non-trivial task:

```
PLAN → EXECUTE → VERIFY → DOCUMENT → COMMIT
```

## Update

```bash
cd ~/Projects/dotfiles && git pull && ./scripts/run.sh
```

## Terminal Config Sync

Ghostty and Starship configs are tracked in this repo with the same path structure as your home directory:

- `~/Projects/dotfiles/Library/Application Support/com.mitchellh.ghostty/config`
- `~/Projects/dotfiles/.config/starship.toml`

After pull/update, copy them into place with:

```bash
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty" "$HOME/.config"
cp "$HOME/Projects/dotfiles/Library/Application Support/com.mitchellh.ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
cp "$HOME/Projects/dotfiles/.config/starship.toml" "$HOME/.config/starship.toml"
```

Open a new terminal (or run `exec zsh`) to reload Starship.

## License

MIT
