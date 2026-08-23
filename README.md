# dotfiles

[![gitleaks](https://github.com/indykish/dotfiles/actions/workflows/gitleaks.yml/badge.svg?branch=master)](https://github.com/indykish/dotfiles/actions/workflows/gitleaks.yml)

Kishore's personal macOS setup. It covers the shell, Git, tmux, Starship, mise,
Ghostty, iTerm2, and the coding agents' settings.

> [!IMPORTANT]
> **The governance moved to [github.com/agentsfleet/orly](https://github.com/agentsfleet/orly).**
>
> This repository once held two jobs. It was the personal dotfiles. It was also
> the rule source every other repository read from. The second job has ended.
>
> The orly repository now owns the rules, the gate scripts, the dispatch pages,
> the audits, the evals, and the engine. It publishes them as
> `@agentsfleet/orly`.
>
> Run `bunx @agentsfleet/orly init` in a repository to install them. The command
> commits the rules into that repository. A fresh clone then reads its own rules
> and runs its own gates.
>
> Nothing resolves out of this checkout now. There is no `ORLY_ROOT`, no
> agent-home symlink, and no `~/bin/orly`.

## Kishore's machine

Sets up the shell, Git, tmux, Starship, mise, Ghostty, iTerm2, and four coding
agents. Defaults name Kishore's paths, keys, and email, and assume the clone
sits at `~/Projects/dotfiles`.

### Before you begin

```bash
brew install bun coreutils starship mise 1password-cli
```

You also need macOS with Zsh and Git, access to
[indykish/dotfiles](https://github.com/indykish/dotfiles), and any coding
agents already installed. Back up configuration you want to keep.

### Set up a new machine

#### 1. Clone

```bash
git clone git@github.com:indykish/dotfiles.git ~/Projects/dotfiles
```

#### 2. Link the configs

```bash
ln -sfn ~/Projects/dotfiles/.tmux.conf ~/.tmux.conf
ln -sfn ~/Projects/dotfiles/.claude/settings.json ~/.claude/settings.json
ln -sfn ~/Projects/dotfiles/.codex/config.toml ~/.codex/config.toml
ln -sfn ~/Projects/dotfiles/.config/amp/settings.json ~/.config/amp/settings.json
ln -sfn ~/Projects/dotfiles/.config/opencode/opencode.json ~/.config/opencode/opencode.json
ln -sfn ~/Projects/dotfiles/bin/provision-env-1password ~/bin/provision-env-1password
```

Symlinked, not copied: a `/model` switch or a newly trusted Codex directory
lands in this checkout as a change to commit. Back up anything real already at
one of those paths — `ln -sfn` replaces it.

Keep `~/bin` on your `PATH`; the supplied `.zshrc` does. Install orly
separately: `npm install --global @agentsfleet/orly`.

#### 3. Copy the configuration you want

`cp -i` asks before replacing a file. Replace Kishore's name, email, and GNU
Privacy Guard (GnuPG) key with your own first.

There is no `.npmrc` here to copy: npm auth belongs to your machine, via
`npm login`, and publishing runs on Trusted Publishing with no token at all.

```bash
cp -i .zshrc ~/.zshrc && cp -i .zshenv ~/.zshenv
cp -i .gitconfig ~/.gitconfig && cp -i .gitconfig-agentsfleet ~/.gitconfig-agentsfleet
cp -i .gitignore_global ~/.gitignore_global
mkdir -p ~/.config/mise && cp -i .config/starship.toml ~/.config/starship.toml && cp -i .config/mise/config.toml ~/.config/mise/config.toml
```

Ghostty and iTerm2 settings live under [`Library/`](Library/) at their macOS
paths; copy them the same way if you use those terminals. Finish with `exec zsh`.

#### 4. Install the shared skills

```bash
cd ~/.local/share/gstack && ./setup --host auto
```

```text
✔ gstack installed
```

gstack installs its own skills per agent. `--host auto` covers every agent it
finds; name one with `--host claude`, `--host codex`, or `--host opencode`.

Governance skills do not come from here. They ship in orly's `workflow.skills`
pack as `orly-spec-new`, `orly-babysit-prs`, `orly-write-unit-test`, and
`orly-write-integration-test`, and each repository gets the version it pinned.

#### 5. Write secret files (optional)

```bash
provision-env-1password
```

```text
✔ Done. Restart shell or: source ~/.zshrc
```

Writes `~/.config/agentsfleet/.env`, `~/.config/e2e/.env`,
`~/.config/agentsfleet/ui.env.local`, and
`~/.config/agentsfleet/runner.env.local` from 1Password vaults with mode
`600`. The two `*.env.local` files are the machine-level sources that the
agentsfleet repo's `post-checkout` hook symlinks into every worktree — one
copy per machine, zero per checkout. Requires `OP_SERVICE_ACCOUNT_TOKEN`
exported; never commit or print it. Verify with
`provision-env-1password --doctor`.

## macOS process limits (optional)

Only if you see `fork: resource temporarily unavailable`:

```bash
echo "kern.maxproc=16384" | sudo tee -a /etc/sysctl.conf
echo "kern.maxprocperuid=8192" | sudo tee -a /etc/sysctl.conf
sudo sysctl -w kern.maxproc=16384 kern.maxprocperuid=8192
printf '%s\n' 'ulimit -u 8192' 'ulimit -n 65536' >> ~/.zshenv && exec zsh
```

Repeated runs append duplicate lines; inspect both files first.

## Upgrade the agents

```bash
claude upgrade; opencode upgrade; amp update; npm i -g @openai/codex
```

## Undo

Links are symbolic. Inspect, then remove:

```bash
readlink "$HOME/.tmux.conf" && unlink "$HOME/.tmux.conf"
```

Restore copied files from your backup. Deleting the clone breaks every link
into it — remove those links first.

## License

[MIT](LICENSE)

