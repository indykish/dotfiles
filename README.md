# dotfiles

Personal macOS configuration for shells, terminals, Git, coding agents, and
the agent rules that govern work across local repositories.

This repository is opinionated. Its helpers assume the clone lives at
`~/Projects/dotfiles`. Some defaults also name Kishore's project directories.
Read each setup step before running it on another machine or account.

## What you get

- Shell, Git, tmux, Starship, mise, Ghostty, and iTerm2 settings.
- Settings for Claude, Codex, OpenCode, and Amp.
- A shared skill collection built from [gstack](https://github.com/garrytan/gstack)
  and the local [`skills/`](skills/) directory.
- The [`AGENTS.md`](AGENTS.md) operating model, focused rule pages, checks, and
  evaluation fixtures.
- Helper commands to link files, update Artificial Intelligence (AI) coding
  tools, and write local environment files from 1Password.

## Before you begin

You need:

- macOS with Zsh and Git.
- Access to [indykish/dotfiles](https://github.com/indykish/dotfiles).
- A Secure Shell (SSH) key registered with GitHub if you use the SSH clone URL.
- Any coding agents you want to configure already installed.
- Bun for the gstack setup.
- GNU coreutils for a bounded `timeout` or `gtimeout` command during setup.
- Starship before loading the supplied `.zshrc`.
- mise if you want to use the supplied tool-version settings.
- The 1Password command-line tool (`op`) only if you want to write secret files.

Install the command-line prerequisites with [Homebrew](https://brew.sh) if you
do not have them:

```bash
brew install bun coreutils starship mise 1password-cli
```

Homebrew prints each package it installs. Skip this command if you install
these tools another way.

The setup commands can affect files in your home directory and other project
repositories. Back up any existing configuration that you want to keep.

## Set up a new machine

Follow these steps in order on a fresh machine. Each step states its expected
output, so a person or a coding agent can verify progress. Skip optional
settings that you do not use.

### 1. Clone into the expected directory

```bash
mkdir -p ~/Projects
git clone git@github.com:indykish/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
```

Git prints its clone progress. The other commands print nothing when they
succeed.

If you do not use GitHub over SSH, clone with HTTPS instead:

```bash
git clone https://github.com/indykish/dotfiles.git ~/Projects/dotfiles
```

Expected result: Git creates `~/Projects/dotfiles`.

### 2. Enable the repository hooks

```bash
git config core.hooksPath .githooks
```

This command prints nothing. It enables the repository's pre-commit and
pre-push checks for this clone.

Verify the setting:

```bash
git config --get core.hooksPath
```

```text
.githooks
```

Run this step for every fresh clone. A linked Git worktree shares the setting
with its main clone.

### 3. Link tmux and the helper commands

Run the helper directly for the first setup:

```bash
./bin/link-bin-dotfiles
```

The helper links `~/.tmux.conf` and these commands into `~/bin`:

- `link-bin-dotfiles`
- `link-agents-md`
- `update-skills`
- `provision-env-1password`
- `update-ai-tools`

It skips a destination that already exists as a regular file or directory.
Successful output ends with `✔ dotfiles links complete`.

Ensure `~/bin` is on your `PATH`. The supplied [`.zshrc`](.zshrc) does this.

### 4. Install the configuration you want

These commands use `cp -i`, which asks before replacing an existing file.

Review the files before copying them to another account. `.zshrc` contains
Kishore's GNU Privacy Guard (GnuPG) key identifier, `agentsfleet` defaults, and
Fly install path.
`.gitconfig` and `.gitconfig-agentsfleet` contain his Git name and email
addresses. Replace those values with your own.

Install the shell files:

```bash
cp -i .zshrc ~/.zshrc
cp -i .zshenv ~/.zshenv
```

Install Git and npm settings:

```bash
cp -i .gitconfig ~/.gitconfig
cp -i .gitconfig-agentsfleet ~/.gitconfig-agentsfleet
cp -i .gitignore_global ~/.gitignore_global
cp -i .npmrc ~/.npmrc
```

Install Starship and mise settings:

```bash
mkdir -p ~/.config/mise
cp -i .config/starship.toml ~/.config/starship.toml
cp -i .config/mise/config.toml ~/.config/mise/config.toml
```

Install settings only for agents present on the machine:

```bash
mkdir -p ~/.claude ~/.codex ~/.config/amp
cp -i .claude/settings.json ~/.claude/settings.json
cp -i .codex/config.toml ~/.codex/config.toml
cp -i .config/amp/settings.json ~/.config/amp/settings.json
```

These copy commands print nothing after a new file is written. If a destination
exists, `cp -i` asks whether to replace it.

OpenCode is different. `update-skills` links the repository's
`.config/opencode/opencode.json` into `~/.config/opencode/` in the next step.

Install terminal settings if you use Ghostty or iTerm2:

```bash
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
cp -i "Library/Application Support/com.mitchellh.ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
cp -i "Library/Preferences/com.googlecode.iterm2.plist" "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
```

Start a new terminal tab, or reload Zsh:

```bash
exec zsh
```

The current shell is replaced by a new Zsh process.

### 5. Install the shared agent skills

> **Warning:** `update-skills` replaces the instruction file in each installed
> agent home with a link to this repository. Back up an existing `CLAUDE.md` or
> `AGENTS.md` file before continuing.

```bash
update-skills
```

If your shell cannot find `update-skills`, run `./bin/update-skills` from this
repository instead.

This command:

1. Clones or updates gstack at `~/.local/share/gstack`.
2. Installs the gstack package dependencies with Bun.
3. Checks that Playwright Chromium launches, and downloads it with `curl`
   when the check fails.
4. Runs gstack setup for each installed agent it supports, with a 600-second
   cap per agent.
5. Rebuilds `.unified-skills/` from gstack and local skills.
6. Links the shared skills directory into installed agents.
7. Links `AGENTS.md` into each installed agent's home directory.
8. Links the OpenCode settings file.

If an agent already has a real `skills` directory, the helper moves it to a
timestamped backup before creating the link. Successful output reports
`✔ Skills updated!`, then prints the gstack and unified-skills paths.

Verify the links without changing them:

```bash
update-skills --doctor
```

Successful output ends with `✔ Skills doctor passed`.

### 6. Link the rules into project repositories

First inspect the target list:

```bash
link-agents-md --list
```

The list shows the linked files, the target repositories, and the agent home
links. The paths vary by machine.

By default, the helper targets `~/Projects/agentsfleet` and
`~/Projects/cache-kit.rs`, including their unlocked Git worktrees. It links the
rulebook, dispatch pages, selected documentation, and checks into each target.

Run the default setup only if those are the repositories you want to change:

```bash
link-agents-md
```

The helper checks its own links at the end of a run, so successful output ends
with `✔ agents doctor passed`.

To target different repositories, pass their absolute paths through
`KISHORES_TARGETS`:

```bash
KISHORES_TARGETS="$HOME/Projects/<PROJECT_ONE> $HOME/Projects/<PROJECT_TWO>" link-agents-md
```

Replace `<PROJECT_ONE>` and `<PROJECT_TWO>` with directory names under
`~/Projects`. The helper skips missing targets and regular files that it would
otherwise replace. It removes dangling links into this dotfiles clone unless
you pass `--no-prune`.

Verify the selected targets without changing them:

```bash
KISHORES_TARGETS="$HOME/Projects/<PROJECT_ONE> $HOME/Projects/<PROJECT_TWO>" link-agents-md --doctor
```

Successful output ends with `✔ agents doctor passed`.

### 7. Write local secret files (optional)

The secret helper writes:

- `~/.config/agentsfleet/.env` from the `ZMB_LOCAL_ENV` vault.
- `~/.config/e2e/.env` from the `E2E_WORK` vault.

It requires `OP_SERVICE_ACCOUNT_TOKEN`. Export the token in your shell for the
first run, or place it in `~/.config/agentsfleet/.env`. Do not commit or print
the token.

```bash
provision-env-1password
```

The helper lists both destination files and asks before replacing them. It
writes files with mode `600`, then checks the required variable names.
Successful output ends with `✔ Done. Restart shell or: source ~/.zshrc`.

Verify the files later without reading or printing their values:

```bash
provision-env-1password --doctor
```

Successful output ends with `✔ env doctor passed`.

### 8. Verify the repository rules

```bash
make audit
```

The audit checks rule invariants, dispatch coverage, and deterministic dispatch
evaluations. A successful run ends with `ALL CHECKS PASSED` and passing dispatch
evaluation summaries.

## How the agent rules work

[`AGENTS.md`](AGENTS.md) is the root operating model. It defines safety rules,
the development lifecycle, verification requirements, and the dispatch index.

The dispatch index sends an agent to the smallest relevant rule page before an
edit or claim:

| Work | Rule page |
|---|---|
| Zig | [`dispatch/write_zig.md`](dispatch/write_zig.md) |
| TypeScript or JavaScript | [`dispatch/write_ts_adhere_bun.md`](dispatch/write_ts_adhere_bun.md) |
| SQL or database schema | [`dispatch/write_sql.md`](dispatch/write_sql.md) |
| Any source file | [`dispatch/write_any.md`](dispatch/write_any.md) |
| Specs, documentation, API prose, or authentication code | Matching `dispatch/write_*.md` page |
| Verification claims | [`dispatch/verify.md`](dispatch/verify.md) |
| Architecture names and flows | [`dispatch/name_architecture.md`](dispatch/name_architecture.md) |
| Rule changes | [`dispatch/edit_rules.md`](dispatch/edit_rules.md) |

Machine-checkable rules have scripts or fixtures under [`audits/`](audits/) and
[`evals/`](evals/). `make audit` detects missing pages, stale indexes, and rule
checks that no longer match their documentation.

Read [`docs/DISPATCH_ARCHITECTURE.md`](docs/DISPATCH_ARCHITECTURE.md) for the
full dispatch design.

## Repository map

| Path | Contents |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Root operating model for coding agents. |
| [`SOUL.md`](SOUL.md) | Orly's working style and collaboration notes. |
| [`dispatch/`](dispatch/) | Rule pages selected by the work an agent is about to do. |
| [`audits/`](audits/) | Shell checks and review questionnaires. |
| [`evals/`](evals/) | Deterministic fixtures that prove dispatch checks accept and reject the right inputs. |
| [`docs/`](docs/) | Shared standards, templates, architecture notes, and verification guidance. |
| [`skills/`](skills/) | Local agent skills added to the shared skills directory. |
| [`bin/`](bin/) | Setup, linking, update, and doctor commands. |
| [`.claude/`](.claude/), [`.codex/`](.codex/), [`.config/`](.config/) | Agent and command-line tool settings. |
| [`.zshrc`](.zshrc), [`.zshenv`](.zshenv), [`.gitconfig`](.gitconfig), [`.tmux.conf`](.tmux.conf) | Home-directory settings copied or linked during setup. |
| [`Library/`](Library/) | Ghostty and iTerm2 settings stored at their macOS paths. |
| [`.githooks/`](.githooks/) | Pre-commit and pre-push checks for this clone. |
| [`.github/workflows/`](.github/workflows/) | GitHub checks for secret leaks. |
| [`Makefile`](Makefile) | Audit and evaluation entry points. |
| `.unified-skills/` | Generated links to gstack and local skills. Do not edit this directory by hand. |

## Routine maintenance

Update all supported AI coding tools, relink dotfiles, refresh skills, and
relink agent rules:

```bash
update-ai-tools
```

The helper updates `claude`, `opencode`, `amp`, and `@openai/codex` when they
are installed. It then runs `link-bin-dotfiles`, `update-skills`, and
`link-agents-md`, so successful output ends with `✔ agents doctor passed`.

Run all three read-only checks at any time:

```bash
update-ai-tools --doctor
```

You can also run each doctor on its own:

```bash
link-bin-dotfiles --doctor
update-skills --doctor
link-agents-md --doctor
```

The doctors print `✔ dotfiles doctor passed`, `✔ Skills doctor passed`, and
`✔ agents doctor passed`. Each doctor exits with a non-zero status when it
finds a missing or incorrect link.

## Optional macOS process limits

Several coding agents, Docker, and concurrent builds can exhaust the default
per-user process limit. Change these values only if you see
`fork: resource temporarily unavailable`.

Check the current values first:

```bash
sysctl kern.maxproc kern.maxprocperuid
```

Output varies by machine.

The following commands append persistent settings to `/etc/sysctl.conf`.
Repeated runs append duplicate lines, so inspect the file before running them.

```bash
echo "kern.maxproc=16384" | sudo tee -a /etc/sysctl.conf
echo "kern.maxprocperuid=8192" | sudo tee -a /etc/sysctl.conf
sudo sysctl -w kern.maxproc=16384 kern.maxprocperuid=8192
```

Expected final output includes:

```text
kern.maxproc: 16384
kern.maxprocperuid: 8192
```

New shells can also use higher process and file-descriptor limits:

The command appends two lines. Check `~/.zshenv` first to avoid duplicates.

```bash
printf '%s\n' 'ulimit -u 8192' 'ulimit -n 65536' >> ~/.zshenv
exec zsh
```

These commands append two lines to `~/.zshenv`, then replace the current shell.

## Remove or undo the setup

The linking helpers use symbolic links. For example, inspect the tmux link:

```bash
readlink "$HOME/.tmux.conf"
```

Expected output points into `~/Projects/dotfiles`. Only then remove the link:

```bash
unlink "$HOME/.tmux.conf"
```

Use the same inspect-then-remove sequence for another home or project link.
Restore copied configuration from the backup you made before setup. The skills
helper also leaves timestamped `skills.backup.*` directories when it replaces a
real skills directory.

Deleting the clone breaks every remaining link into it. Remove or replace those
links before deleting `~/Projects/dotfiles`.

## License

[MIT](LICENSE)
