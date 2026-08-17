# dotfiles

[![npm](https://img.shields.io/npm/v/@agentsfleet/orly?label=%40agentsfleet%2Forly)](https://www.npmjs.com/package/@agentsfleet/orly)
[![coverage](https://codecov.io/gh/indykish/dotfiles/branch/master/graph/badge.svg)](https://codecov.io/gh/indykish/dotfiles)
[![test](https://github.com/indykish/dotfiles/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/indykish/dotfiles/actions/workflows/test.yml)
[![harness](https://github.com/indykish/dotfiles/actions/workflows/harness.yml/badge.svg?branch=master)](https://github.com/indykish/dotfiles/actions/workflows/harness.yml)

The rules and gates that govern work across Kishore's repositories — packaged
as `@agentsfleet/orly`, installable into any repository — plus, separately, the
personal macOS setup (shells, terminals, Git, four coding agents) Kishore runs
this checkout for.

The npm badge is the released version: a merge to `master` that carries a new
`package.json` version publishes it, tags it, and cuts a GitHub release.
Coverage is gated at a 90% line floor in `test.yml` — the badge reports the
number, the workflow enforces it.

## Install the harness

In the repository you want rules and gates enforced in:

```bash
bunx @agentsfleet/orly init
```

That is the whole install. It materialises the rule pages, the gate scripts,
the skills those rules name, and git hooks — for your languages, read from
your own sources. A Rust crate receives the Rust rules and never the Zig
ones. No checkout of this repository, no prepared `$HOME`; the same command
works on a fresh machine, a Continuous Integration (CI) runner, or a remote
container.

**Everything it writes is meant to be committed.** That is how the rules
reach your teammates: they clone and the rules are already there, with
nothing to install and nothing to remember. The one thing a clone cannot
carry is `core.hooksPath` — it is local git config — so each person runs
`orly init` once to arm the hooks.

### Two files, always

| File | Owner | On `orly update` |
|---|---|---|
| `AGENTS.md` | **yours** | untouched, except one delimited pointer block |
| `AGENTS.orly.md` | orly | rewritten |

If you already had an `AGENTS.md`, it keeps its name and its bytes and gains
the pointer. If you had none, you get a stub with the pointer and room to
write your own rules whenever you want them — the file is yours from the
start, so nothing you add later is ever at risk. Your rules win where the two
disagree.

Nothing you wrote is replaced without you asking. A hook or a rule page orly
did not write is refused, naming `--force` and `--no-hooks` as the ways
forward, and a refused run leaves the repository exactly as it found it.

### Then

`orly init` seeds `.oracle/orly.json` with the gate commands it can find in
your `Makefile` or `package.json`. Complete it, commit it, and every clone
gates identically.

| Command | Does |
|---|---|
| `orly gate` | run work → verify → pr; stop at the first red group |
| `orly update` | re-materialise at a newer engine version |
| `orly update --with <pack>` | take an opt-in pack, recorded for every clone |
| `orly init --dry-run` | show what would be written; change nothing |
| `orly doctor` | compare what is installed against what orly would write today |

## Kishore's own machine (optional)

Nothing below this line is needed to use the harness in another repository.
It sets up *this* checkout as Kishore's personal dotfiles + rule source: shell,
Git, tmux, Starship, mise, Ghostty, iTerm2, and four coding agents' settings,
plus the helpers that link, update, and doctor them.

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

#### 2. Enable hooks

```bash
git config core.hooksPath .githooks
```

Verify with `git config --get core.hooksPath` → `.githooks`. Repeat per fresh
clone.

#### 3. Link helpers

```bash
./bin/link-bin-dotfiles
```

```text
✔ dotfiles links complete
```

Links `~/.tmux.conf`, `~/.claude/settings.json`, `~/.codex/config.toml`,
`~/.config/amp/settings.json`, and `orly`, `update-skills`, `update-ai-tools`,
`provision-env-1password`, `link-bin-dotfiles` into `~/bin`. Keep `~/bin` on
your `PATH`; the supplied `.zshrc` does. Agent settings are symlinked, not
copied — a `/model` switch or a newly-trusted Codex project directory lands in
this checkout the same way an `AGENTS.md` rule edit does. On a machine that
already has real content at one of those three paths, `link-bin-dotfiles`
skips it with a warning rather than overwriting; reconcile by hand (move the
machine's version into this checkout, or back it up and remove it) and
re-run.

#### 4. Copy the configuration you want

`cp -i` asks before replacing a file. Replace Kishore's name, email, and GNU
Privacy Guard (GnuPG) key with your own first.

```bash
cp -i .zshrc ~/.zshrc && cp -i .zshenv ~/.zshenv
cp -i .gitconfig ~/.gitconfig && cp -i .gitconfig-agentsfleet ~/.gitconfig-agentsfleet
cp -i .gitignore_global ~/.gitignore_global && cp -i .npmrc ~/.npmrc
mkdir -p ~/.config/mise && cp -i .config/starship.toml ~/.config/starship.toml && cp -i .config/mise/config.toml ~/.config/mise/config.toml
```

Ghostty and iTerm2 settings live under [`Library/`](Library/) at their macOS
paths; copy them the same way if you use those terminals. OpenCode settings are
linked by `update-skills` in the next step. Finish with `exec zsh`.

#### 5. Install the shared skills

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

It deliberately does **not** link `kishore-spec-new`, `kishore-babysit-prs`,
`write-unit-test`, or `write-integration-test`. Those ship in orly's
`workflow.skills` pack and land in each repository at the version that
repository pinned; linking them here too would register each name twice and
let the two copies drift.

#### 6. Render the rules

Run after any rule edit. This checkout is an `orly` consumer like any other,
so it uses the same verb every repository uses — with `--no-hooks`, because
this checkout wrote its own `.githooks/` and orly refuses to replace hooks it
did not write:

```bash
orly update --no-hooks
```

```text
🟢 0 written, 1 already current (19 packs)
```

The root [`AGENTS.md`](AGENTS.md) is the only generated file here. Pack
sources that already live in this checkout are skipped rather than copied
over themselves, which is why the same command that installs elsewhere also
re-renders here. There are no symlinks into `$HOME`: every repository commits
its own rules, this one included.

Two machine-level helpers sit beside it, and neither is part of `orly` —
they maintain *this* laptop, not any repository:

```bash
update-skills      # clone/refresh gstack, link the shared skills into each agent
update-ai-tools    # upgrade claude, opencode, amp, @openai/codex, then the above
```

`update-ai-tools --doctor` runs the read-only checks. `orly update` is what
touches rules; these two touch tooling. A contributor needs neither — the
skills the rules name are installed into their repository by `orly init`.

#### 7. Install into a repository

```bash
cd ~/Projects/<repo> && orly init --with persona.indy
```

Materialises that repository's rules from its own sources and seeds
`.oracle/orly.json` with the gate commands it finds. Complete that file — the
real `conform`/`verify.*` set, and `surfaces.user`/`surfaces.docs` for the docs
gate — then commit it. Nothing is registered anywhere; the repository carries
its own answer, so a teammate's clone gates identically.

`--with persona.indy` is what replaces the old global `~/.claude/CLAUDE.md`:
opt-in packs never auto-select, so a stranger's repository never renders
them, and naming it once records it for every clone.

#### 8. Gate the work

```bash
orly gate
```

```text
🔆 gate work
   🟢 git.branch: on feat/example
   🟢 git.tree: clean (active spec excluded)
   🟢 repo.config: 6 command(s) declared
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
the Pull Request, dead with the branch. Check what is installed anytime:
`orly doctor` → `🟢 this repository's installed ruleset matches .oracle/orly.json`.

#### 9. Write secret files (optional)

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

#### 10. Verify the rules

```bash
cd orly && bun install --frozen-lockfile && cd .. && make audit
```

```text
✅ ALL CHECKS PASSED
```

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
