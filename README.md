# dotfiles

Personal opinionated dotfiles and agent configuration powered by [gstack](https://github.com/garrytan/gstack) (Oracle Operating Model in [AGENTS.md](AGENTS.md)).

## Quick Start

```bash
git clone git@github.com:indykish/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
git config core.hooksPath .githooks    # arms pre-commit + pre-push (one-time, per clone)
```

The `core.hooksPath` line wires the AGENTS.md invariance suite into every
commit and push from this clone. Without it, `.githooks/` is just files —
git keeps using `.git/hooks/` (sample stubs only). Re-run on every fresh
clone or worktree. See [audits/agents-md.md](audits/agents-md.md) for the
contract; run `make audit` any time to verify it by hand.

## How the rules work (in plain terms)

[`AGENTS.md`](AGENTS.md) is the rulebook every AI agent follows. Instead of one
giant list, the rules are split by **what you're about to do** — and the agent is
handed only the one page that applies.

Think of it like a front desk: you say "I'm about to write some Zig," and it gives
you exactly the Zig rules — not the whole binder. Each of those pages lives in
[`dispatch/`](dispatch/), and where a rule can be checked by a machine, a small
script runs it automatically.

| If you're about to… | The agent reads… |
|---|---|
| write Zig | `dispatch/write_zig.md` |
| write TypeScript / JavaScript | `dispatch/write_ts_adhere_bun.md` |
| write SQL or a database schema | `dispatch/write_sql.md` |
| write *any* code at all | `dispatch/write_any.md` |
| write a spec / changelog / API / auth code | the matching `dispatch/write_*.md` |
| say "it's done — tests pass" | `dispatch/verify.md` |
| name a stream or design a flow | `dispatch/name_architecture.md` |
| change the rules themselves | `dispatch/edit_rules.md` |

One command — `make audit` — keeps the rulebook honest: it fails loudly if this
list, the files on disk, and the agent's own checklist ever fall out of sync.

> **Want the full story?** The *why* behind this design — the latent/deterministic
> "façade pair" per topic, the 🟢/🔴/🔵/⚪ signal tags, the parity guarantees, and
> the migration that produced it — is written up in detail in
> [`docs/DISPATCH_ARCHITECTURE.md`](docs/DISPATCH_ARCHITECTURE.md). The exact,
> machine-checked list of entries lives in [`audits/data.sh`](audits/data.sh).

The instructions below assume you are in the `~/Projects/dotfiles` directory.

## Install

### macOS Shell
```bash
cp .zshrc ~/.zshrc
```

### macOS process limits (concurrent agents / heavy dev loops)

Two simultaneous coding agents running `zig build` + docker + lint chains
will exhaust the default per-user process cap (`kern.maxprocperuid=2666`)
and trip `fork: resource temporarily unavailable`. Bump the kernel
tunables so multi-agent / multi-worktree workflows have headroom. Survives
reboot via `/etc/sysctl.conf` (read by `com.apple.sysctl.plist` at boot
on macOS 10.13+).

```bash
# Persistent (survives reboot)
echo "kern.maxproc=16384" | sudo tee -a /etc/sysctl.conf
echo "kern.maxprocperuid=8192" | sudo tee -a /etc/sysctl.conf

# Apply now without rebooting
sudo sysctl -w kern.maxproc=16384 kern.maxprocperuid=8192

# Verify
sysctl kern.maxproc kern.maxprocperuid
```

Optional — bump the shell ulimit too so new shells inherit higher caps
without waiting for re-login from a sysctl-only change:

```bash
echo 'ulimit -u 8192'   >> ~/.zshenv
echo 'ulimit -n 65536'  >> ~/.zshenv  # bonus — bumps fd limit (useful for zig/postgres)
```

Existing shells need `exec zsh` (or a new tab) to pick this up.

### Agent profiles
```bash
# Claude
cp .claude/settings.json ~/.claude/settings.json

# Codex
mkdir -p ~/.codex && cp .codex/config.toml ~/.codex/config.toml

# OpenCode — config is linked (not copied) by `update-skills`; see the Skills step below.
# It runs `ln -snf .config/opencode/opencode.json ~/.config/opencode/opencode.json`,
# so edits to the repo file are live immediately. No manual copy needed.

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

### Scripts (symlink the helper binaries into ~/bin)
```bash
mkdir -p ~/bin
ln -sf ~/Projects/dotfiles/bin/link-bin-dotfiles         ~/bin/link-bin-dotfiles
ln -sf ~/Projects/dotfiles/bin/link-agents-md            ~/bin/link-agents-md
ln -sf ~/Projects/dotfiles/bin/update-skills             ~/bin/update-skills
ln -sf ~/Projects/dotfiles/bin/provision-env-1password   ~/bin/provision-env-1password
ln -sf ~/Projects/dotfiles/bin/update-ai-tools           ~/bin/update-ai-tools
# scripts in dotfiles/bin/ are already executable; symlinks inherit that.
```

### Personal dotfiles
```bash
link-bin-dotfiles  # links ~/.tmux.conf and helper commands into ~/bin
```

| Command | What the heck it does |
|---|---|
| `link-bin-dotfiles` | Links `~/.tmux.conf` and the supported helper commands into `~/bin`; removes stale old helper symlinks. |
| `link-agents-md` | Links `AGENTS.md`, dispatch files, audits, and agent instruction files into project repos plus Claude/Codex/OpenCode/Amp homes. |
| `update-skills` | Updates gstack, rebuilds the unified skills overlay, and links it into installed agents. |
| `provision-env-1password` | Creates local environment files from 1Password vaults after prompting before overwrite. |
| `update-ai-tools` | Updates Artificial Intelligence (AI) coding command-line tools, then runs the link/update helpers above. |

Each helper supports `--help` for the short version. `link-bin-dotfiles`,
`link-agents-md`, `update-skills`, and `provision-env-1password` also support
`--doctor` to verify expected state without rewriting it.

### Agent ruleset + skills
```bash
link-agents-md  # links AGENTS.md into ~/.claude, ~/.codex, ~/.opencode, ~/.amp (+ project repos)
update-skills   # updates gstack, then links the unified skills overlay + opencode.json
```

### Secrets (1Password)
Environment files are provisioned by `provision-env-1password` from 1Password vaults:
- `ZMB_LOCAL_ENV` → `~/.config/agentsfleet/.env`
- `E2E_WORK` → `~/.config/e2e/.env`

Bootstrap: set `OP_SERVICE_ACCOUNT_TOKEN` in `~/.config/agentsfleet/.env`, then run `provision-env-1password`.

## License

MIT
