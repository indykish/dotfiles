---
name: preflight-tooling
description: Detect and install missing local developer tooling using mise-first and brew fallback before implementation work.
---

# Preflight Tooling

Detect missing tooling and install it before editing code.

## Policy

- Use `mise` first for language/runtime tooling.
- Use `brew` as fallback for non-runtime CLIs or when `mise` cannot install.
- Do not stop at detection only; install missing prerequisites when possible.
- Prefer `bun` to `node` when available.

## Required Tool Set

- Core: `git`, `gh`, `glab`, `tmux`
- Runtime/build: `mise`, `node`, `npm`, `bun`, `bunx`,`python`, `go`, `cargo`, `rustc`
- Containers: `docker` (Docker Desktop)
- Orchestration: `temporal`
- QA/automation: `playwright`, `stagehand`
- Ops/helpers: `oracle`, `imageoptim`, `trash`
- Optional: `zig`, `pass-cli`, `tailscale`, `zed`

## Command Workflow

```bash
# Runtime tools via mise first
mise use -g python@3.14
mise use -g node@latest
mise use -g bun@latest
mise use -g go@latest
mise use -g rust@stable
# CLI tools via brew fallback
brew install gh glab tmux imageoptim-cli trash

# Docker Desktop (brew cask)
brew install --cask docker

# Temporal CLI (mise first, brew fallback)
mise use -g aqua:temporalio/cli@latest
# fallback: brew install temporal

# Oracle CLI (second-model review tool)
bun add -g @steipete/oracle

# Optional (install only if needed)
# mise use -g zig@latest
# brew install tailscale
# brew install --cask zed
```

Then verify each required command with `command -v <tool>`.

Verification examples:

```bash
docker --version
temporal --version
playwright --version
stagehand --version
oracle --version
```

## Rules

- If a package name differs from the command name, resolve it and continue.
- If installation fails, report exact command + error and the next fallback.
- Update `docs/tooling-inventory.md` when the baseline changes.
