# dotfiles

[![gitleaks](https://github.com/indykish/dotfiles/actions/workflows/gitleaks.yml/badge.svg?branch=master)](https://github.com/indykish/dotfiles/actions/workflows/gitleaks.yml)
[![orly](https://img.shields.io/npm/v/@agentsfleet/orly?label=orly)](https://www.npmjs.com/package/@agentsfleet/orly)

Kishore's macOS setup. Names, emails, and paths are Kishore's, and the clone
lives at `~/Projects/dotfiles`.

- [Git](https://git-scm.com)
- [tmux](https://github.com/tmux/tmux)
- [Starship](https://starship.rs)
- [mise](https://mise.jdx.dev)
- [iTerm2](https://iterm2.com)
- [Rex](https://www.superlogical.com/updates/public-testing-beginning) (not installed yet)
- Coding agents: [Claude Code](https://claude.com/claude-code),
  [Codex](https://github.com/openai/codex), [Amp](https://ampcode.com),
  [opencode](https://opencode.ai)

> [!IMPORTANT]
> Rules, gates, and agent governance moved to
> [agentsfleet/orly](https://github.com/agentsfleet/orly). Run `orly init` in
> each repository; nothing resolves out of this checkout.

## Before you begin

- Git, with SSH access to GitHub
- [Homebrew](https://brew.sh): `brew install coreutils && brew install --cask iterm2`
- [mise](https://mise.jdx.dev/getting-started.html): `curl https://mise.run | sh`
  (not the Homebrew build; `.zshrc` activates `~/.local/bin/mise`)
- [gstack](https://github.com/garrytan/gstack)
- The coding agents you use

## Set up a new machine

### 1. Clone

```bash
git clone git@github.com:indykish/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
```

### 2. Link the agent and tmux configs

```bash
for f in .tmux.conf .claude/settings.json .codex/config.toml \
  .config/amp/settings.json .config/opencode/opencode.json bin/provision-env-1password; do
  mkdir -p ~/"$(dirname "$f")" && ln -sfn "$PWD/$f" ~/"$f"
done
```

Symlinks, so a setting an agent changes shows up here as a diff to commit.
`ln -sfn` replaces whatever is already at the target; back it up first.

### 3. Copy the rest and install tools

Change the name and emails in `.gitconfig` and `.gitconfig-agentsfleet` first.
`cp -i` asks before overwriting.

```bash
cp -i .zshrc .zshenv .gitconfig .gitconfig-agentsfleet .gitignore_global ~/
mkdir -p ~/.config/mise
cp -i .config/starship.toml ~/.config/
cp -i .config/mise/config.toml ~/.config/mise/
~/.local/bin/mise install
exec zsh
```

Then install orly with `bun add -g @agentsfleet/orly`.

For iTerm2, quit it and run this from Terminal.app:
`defaults import com.googlecode.iterm2 ~/Projects/dotfiles/Library/Preferences/com.googlecode.iterm2.plist`

### 4. Write secret files (optional)

```bash
provision-env-1password            # write
provision-env-1password --doctor   # verify
```

Needs `OP_SERVICE_ACCOUNT_TOKEN` exported; never commit or print it. Writes
these from 1Password, mode `600`:

- `~/.config/agentsfleet/.env`: API keys, the Grafana dev connection
  (`GRAFANA_SERVER` and `GRAFANA_TOKEN` for `gcx`, plus `GRAFANA_DEV_*`
  namespace and datasource UIDs), and paths to the three files below
- `~/.config/agentsfleet/ui.env.local`, `runner.env.local`, `agentsfleetd.env.local`
- `~/.config/e2e/.env`

## macOS process limits (optional)

Only if you see `fork: resource temporarily unavailable`:

```bash
echo "kern.maxproc=16384" | sudo tee -a /etc/sysctl.conf
echo "kern.maxprocperuid=8192" | sudo tee -a /etc/sysctl.conf
sudo sysctl -w kern.maxproc=16384 kern.maxprocperuid=8192
printf '%s\n' 'ulimit -u 8192' 'ulimit -n 65536' >> ~/.zshenv && exec zsh
```

Repeated runs append duplicate lines; inspect both files first.

## License

[MIT](LICENSE)
