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

### What moved out

Orly owns these, so this repository no longer carries them.

| Removed | Now lives in |
|---|---|
| `AGENTS.md` | orly packs, rendered per repository |
| `orly/`, `audits/`, `dispatch/`, `evals/` | the orly repository |
| `docs/`, `.oracle/`, `Makefile`, `package.json` | the orly repository |
| `.githooks/`, `harness.yml`, `test.yml`, `release.yml` | the orly repository |
| `skills/kishore-spec-new` | `orly-spec-new` |
| `skills/kishore-babysit-prs` | `orly-babysit-prs` |
| `skills/write-unit-test` | `orly-write-unit-test` |
| `skills/write-integration-test` | `orly-write-integration-test` |

### What stayed

| Path | Why it stayed |
|---|---|
| `SOUL.md`, `SOUL_LOG.md` | The persona pack inlines a section from `SOUL.md`. Each `(log: Pn)` cite resolves in `SOUL_LOG.md`. |
| `skills/release-template.md` | The orly `product.agentsfleet` pack still cites it. It has no orly home yet. |
| `skills/handoff`, `skills/pickup` | Working skills, not governance. Orly has no equivalent. |
| `.github/workflows/gitleaks.yml` | Secret scanning still applies here. |

## Kishore's machine

This checkout configures one laptop. It sets up the shell, Git, tmux, Starship,
mise, Ghostty, iTerm2, and four coding agents' settings. It also installs the
helpers that link, update, and check them.

Helpers assume the clone lives at `~/Projects/dotfiles`. Defaults name
Kishore's directories, keys, and email. Read each step before running it on
another machine.

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
mkdir -p ~/Projects && git clone git@github.com:indykish/dotfiles.git ~/Projects/dotfiles && cd ~/Projects/dotfiles
```

#### 2. Link helpers

```bash
./bin/link-bin-dotfiles
```

```text
✔ dotfiles links complete
```

Links `~/.tmux.conf`, `~/.claude/settings.json`, `~/.codex/config.toml`,
`~/.config/amp/settings.json`, `update-skills`, `update-ai-tools`,
`provision-env-1password`, `link-bin-dotfiles` into `~/bin`. Keep `~/bin` on
your `PATH`; the supplied `.zshrc` does. Install `orly` separately with
`npm install --global @agentsfleet/orly`. Agent settings are symlinked, not
copied. A `/model` switch or a newly trusted Codex project directory lands in
this checkout like an `AGENTS.md` rule edit. On a machine that already has real
content at one of those three paths, `link-bin-dotfiles` skips it with a warning
rather than overwriting. Move the machine's version into this checkout, or back
it up and remove it, then rerun the command.

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
paths; copy them the same way if you use those terminals. OpenCode settings are
linked by `update-skills` in the next step. Finish with `exec zsh`.

#### 4. Install the shared skills

```bash
update-skills
```

```text
✔ Skills updated!
```

Clones gstack to `~/.local/share/gstack`, installs its dependencies, and links
the shared skills into each installed agent. It refuses to replace files it
does not own; a real `skills` directory is moved to a timestamped backup.
Verify anytime with `update-skills --doctor` → `✔ Skills doctor passed`.

It deliberately does **not** link the governance skills. Those ship in orly's `workflow.skills` pack as `orly-spec-new`,
`orly-babysit-prs`, `orly-write-unit-test`, and
`orly-write-integration-test`. Each repository gets the version it pinned.
Linking them here too would register each name twice and let the copies
drift.

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

## Undo

Links are symbolic. Inspect, then remove:

```bash
readlink "$HOME/.tmux.conf" && unlink "$HOME/.tmux.conf"
```

Restore copied files from your backup. Deleting the clone breaks every link
into it — remove those links first.

## License

[MIT](LICENSE)

