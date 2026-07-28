# dotfiles

macOS setup for shells, terminals, Git, and four coding agents — plus the
rules and gates that govern work across Kishore's repositories.

Helpers assume the clone lives at `~/Projects/dotfiles`. Defaults name
Kishore's directories, keys, and email. Read each step before running it on
another machine.

## What you get

- Shell, Git, tmux, Starship, mise, Ghostty, and iTerm2 settings.
- Settings for Claude, Codex, OpenCode, and Amp.
- Shared skills from [gstack](https://github.com/garrytan/gstack) plus [`skills/`](skills/).
- The [`AGENTS.md`](AGENTS.md) operating model, rule pages, gates, and checks.
- Helpers to link files, update agent tools, and write secrets from 1Password.

## Before you begin

```bash
brew install bun coreutils starship mise 1password-cli
```

You also need macOS with Zsh and Git, access to
[indykish/dotfiles](https://github.com/indykish/dotfiles), and any coding
agents already installed. Back up configuration you want to keep.

## Set up a new machine

### 1. Clone

```bash
mkdir -p ~/Projects && git clone git@github.com:indykish/dotfiles.git ~/Projects/dotfiles && cd ~/Projects/dotfiles
```

### 2. Enable hooks

```bash
git config core.hooksPath .githooks
```

Verify with `git config --get core.hooksPath` → `.githooks`. Repeat per fresh
clone.

### 3. Link helpers

```bash
./bin/link-bin-dotfiles
```

```text
✔ dotfiles links complete
```

Links `~/.tmux.conf` and `orly`, `update-skills`, `update-ai-tools`,
`provision-env-1password`, `link-bin-dotfiles` into `~/bin`. Keep `~/bin` on
your `PATH`; the supplied `.zshrc` does.

### 4. Copy the configuration you want

`cp -i` asks before replacing a file. Replace Kishore's name, email, and GNU
Privacy Guard (GnuPG) key with your own first.

```bash
cp -i .zshrc ~/.zshrc && cp -i .zshenv ~/.zshenv
cp -i .gitconfig ~/.gitconfig && cp -i .gitconfig-agentsfleet ~/.gitconfig-agentsfleet
cp -i .gitignore_global ~/.gitignore_global && cp -i .npmrc ~/.npmrc
mkdir -p ~/.config/mise && cp -i .config/starship.toml ~/.config/starship.toml && cp -i .config/mise/config.toml ~/.config/mise/config.toml
mkdir -p ~/.claude ~/.codex ~/.config/amp
cp -i .claude/settings.json ~/.claude/settings.json && cp -i .codex/config.toml ~/.codex/config.toml && cp -i .config/amp/settings.json ~/.config/amp/settings.json
```

Ghostty and iTerm2 settings live under [`Library/`](Library/) at their macOS
paths; copy them the same way if you use those terminals. OpenCode settings are
linked by `update-skills` in the next step. Finish with `exec zsh`.

### 5. Install the shared skills

```bash
update-skills
```

```text
✔ Skills updated!
```

Clones gstack to `~/.local/share/gstack`, installs its dependencies, links the
shared skills into each installed agent, renders the root rules, and links the
agent homes. It refuses to replace files it does not own; a real `skills`
directory is moved to a timestamped backup. Verify anytime with
`update-skills --doctor` → `✔ Skills doctor passed`.

### 6. Render the rules

Run after any rule edit:

```bash
orly sync
```

```text
🟢 rules rendered to AGENTS.md; 4 agent-home links current
```

The root [`AGENTS.md`](AGENTS.md) is the only generated file.
`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, OpenCode, and Amp all symlink to
it. A rule edit is one commit here — every agent session in every repository
reads it immediately.

### 7. Register a repository

Add its path and profile to `orly/repositories.json`. The profile declares the
repository's commands (`conform`, `verify.*`) and optional `surfaces{user,docs}`
prefixes for the docs gate. The repository keeps one hand-written `AGENTS.md`
with project facts. No generated copies, no `.oracle/` directory.

### 8. Gate the work

```bash
orly gate
```

```text
🔆 gate work
   🟢 git.branch: on feat/example
   🟢 git.tree: clean (active spec excluded)
   🟢 repo.profile: agentsfleet -> agentsfleet
...
🟢 PR boundary open — CHORE(close) is the next motion
```

`orly gate` runs work → verify → pr and stops at the first red group. Every
criterion is mechanical. No spec → spec checks skip; quality gates still run.
Slow suites run only when the branch carries code. A user-surface change with
no docs change blocks the PR gate. The recorded way out:

```bash
orly override <CRITERION> --reason <REASON>
```

The override is an empty commit with an `Orly-Override` trailer — visible in
the Pull Request, dead with the branch. Check the carrier anytime:
`orly doctor` → `🟢 root AGENTS.md is current and every agent home links to it`.

### 9. Write secret files (optional)

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

### 10. Verify the rules

```bash
cd orly && bun install --frozen-lockfile && cd .. && make audit
```

```text
✅ ALL CHECKS PASSED
```

## How the rules work

[`orly/core/operating-model.md`](orly/core/operating-model.md) is the source.
The renderer produces one artifact — the root [`AGENTS.md`](AGENTS.md) — and
every agent home symlinks to it. Consumer repositories carry no copies; gates
and rule pages resolve from this checkout, cited everywhere through the
`~/Projects/dotfiles/` anchor. Sessions in any repository read them without a
prompt: `.claude/settings.json` ships the allow-rule
`Read(~/Projects/dotfiles/**)` (propagated to `~/.claude/settings.json` by the
copy step above), and `make audit` (`audits/rule-paths.sh`) fails when the
grant or an anchored citation drifts.

The dispatch index sends an agent to the smallest relevant rule page before an
edit or claim:

| Work | Rule page |
|---|---|
| Zig | [`dispatch/write_zig.md`](dispatch/write_zig.md) |
| TypeScript or JavaScript | [`dispatch/write_ts_adhere_bun.md`](dispatch/write_ts_adhere_bun.md) |
| SQL or schema | [`dispatch/write_sql.md`](dispatch/write_sql.md) |
| Any source file | [`dispatch/write_any.md`](dispatch/write_any.md) |
| Specs, docs, API prose, auth | matching `dispatch/write_*.md` |
| Verification claims | [`dispatch/verify.md`](dispatch/verify.md) |
| Architecture names and flows | [`dispatch/name_architecture.md`](dispatch/name_architecture.md) |
| Rule changes | [`dispatch/edit_rules.md`](dispatch/edit_rules.md) |

`make audit` proves the registry, rendering, rule invariants, and dispatch
fixtures. Design detail: [`docs/ORLY_ARCHITECTURE.md`](docs/ORLY_ARCHITECTURE.md)
and [`docs/DISPATCH_ARCHITECTURE.md`](docs/DISPATCH_ARCHITECTURE.md).

## Repository map

| Path | Contents |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Generated rules — the file every agent home links to. |
| [`orly/`](orly/) | The gate engine, renderer, profiles, and fixtures (Bun + TypeScript). |
| [`SOUL.md`](SOUL.md) | Orly's judgment layer — precedent log of Kishore's verbatim calls, reply-shape rules, pre-send checklist. Each rule once; `AGENTS.md` holds the gates. |
| [`dispatch/`](dispatch/) | Rule pages keyed to the work at hand. |
| [`audits/`](audits/), [`evals/`](evals/) | Deterministic checks and their fixtures. |
| [`docs/`](docs/) | Standards, templates, architecture notes, specs under `docs/v*/`. |
| [`skills/`](skills/), `.unified-skills/` | Local skills and the generated shared set. |
| [`bin/`](bin/) | Setup, linking, update, and doctor helpers. |
| [`.githooks/`](.githooks/) | Pre-commit and pre-push checks. |
| dotfiles proper | `.zshrc`, `.gitconfig`, `.tmux.conf`, agent settings, `Library/`. |

## Maintenance

```bash
update-ai-tools
```

Updates `claude`, `opencode`, `amp`, and `@openai/codex`, relinks dotfiles,
refreshes skills, renders the root rules, and verifies the links.
`update-ai-tools --doctor` runs the read-only checks; non-zero exit means a
missing link or stale root `AGENTS.md`.

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
