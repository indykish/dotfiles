# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] - 2026-02-22

### Added
- **Oracle dual-lens review model** — inline CTO (strategic) and Engineer (tactical) review lenses replace CLI-only workflow; CLI becomes secondary path
- **Behavioral guardrails** — `docs/BEHAVIORAL_GUARDRAILS.md` codifies assumption surfacing, confusion management, simplicity enforcement, scope discipline, and dead code hygiene
- **DX Platform Stack doc** — `docs/STACK.md` extracts stack defaults (Website, CLI, Desktop, Mobile) from AGENTS.md
- **Cognitive discipline section** in AGENTS.md — non-trivial task definition, confusion management, simplicity enforcement, dead code hygiene
- **Dotfiles sync tracking** in AGENTS.md — source/destination table with drift-check and sync commands
- **CMUX icon patcher** — `Applications/cmux/` with optimized icon.png and `patch_cmux.sh` for macOS dock icon customization
- **`.npmrc`** — npm auth token via `${NPM_TOKEN}` env var
- **Review severity levels** — BLOCKER/MAJOR/MINOR/NIT classification in Oracle skill
- **Oracle escalation levels** — 4-tier model (solo → inline lens → CLI cross-model → parallel worktrees)
- **Legacy team lens compatibility** — maps CTO/Senior Engineer shorthand to Oracle execution lenses
- **`.zshrc` credential caching** — pass-cli vault keys cached to `~/.config/clawable/.env_mac` with `chmod 600`
- **New agent keys** — `MINIMAX_API_KEY`, `OPENROUTER_API_KEY`, `NPM_TOKEN` added to vault pull list

### Changed
- **Oracle skill rewritten** — primary path is now inline review (zero CLI, zero cost); `@indykish/oracle` CLI is secondary
- **AGENTS.md** — Oracle tool commands updated to `oracle --help`; escalation levels replace flat defaults; DX stack extracted to `docs/STACK.md`
- **CLAUDE.md** — updated Oracle skill pointer to reflect inline-first model
- **Preflight tooling** — Oracle CLI changed from `@steipete/oracle` to `@indykish/oracle` v0.9.2
- **`.zshrc`** — credential loading refactored from function-based to if/elif with pass-cli → env file caching loop

### Removed
- **DX Platform Stack inline** from AGENTS.md — moved to `docs/STACK.md`
- **Frontend workflow / accessibility sections** from AGENTS.md — consolidated into `docs/STACK.md`

## [2.8.0] - 2026-02-21

### Added
- **E2E Networks internal setup** in preflight-tooling skill — `openfortivpn`, `mysql-client`, VPN launch scripts with LaunchAgent plists
- **VPN env var workflow** — credentials via `~/.env_mac` (no hardcoded passwords); `run.sh` warns to set `VPN_PROD_*` / `VPN_STAGE_*`
- **Tooling inventory** — E2E internal tools section with `openfortivpn`, `mysql-client`, `font-hack-nerd-font`

### Changed
- **Oracle skill rewritten** — defaults to `--engine api --model claude-4.5-sonnet` (Claude-first); browser path optional
- **AGENTS.md** — Oracle tool defaults updated to Claude Sonnet primary, Opus escalation
- **CLAUDE.md** — Added Oracle skill defaults pointer

### Removed
- **`AGENTS_OLD.md`** — legacy CTO/Engineer dual-role model (superseded by Oracle Operating Model)
- **`docs/01-preflight-vpn-localdev.md`** — spec consumed and implemented
- **`docs/00-oracle-claude-browser-feasibility.md`** — spec consumed and implemented

## [2.7.0] - 2026-02-20

### Changed
- **Dotfiles sync standardized** — Tree structure aligned with ai-jumpstart as canonical source of truth
- **Stale files cleaned up** — Removed orphaned `skills/go.md`, `skills/python.md`, `skills/SKILL.md`, root-level `status-line.sh`, `setup-owner.sh`, and duplicate `docs/mac-vm.md` from dotfiles
- **`mise.toml` consolidated** — Removed stale root-level `mise.toml` from dotfiles; authoritative config lives at `.config/mise/config.toml`

## [2.6.0] - 2026-02-20

### Added
- **Pi agent support** — New `.pi/agent/` directory with `auth.json`, `models.json`, and `settings.json` configs
- **Environment-based secrets** — All API keys in configs use environment variables (`$OPENROUTER_API_KEY`, `$ZAI_API_KEY`, `$MINIMAX_API_KEY`, etc.)
- **`scripts/setup-owner.sh`** — Interactive setup script to personalize AGENTS.md and runbooks with user details
- **Git email auto-detection** — Setup script attempts to read email from `git config` before prompting
- **Status line scripts** — `.claude/status-line.sh` and `.claude-e2e/status-line.sh` with emoji-rich output showing project info and costs
- **Version display** — `run.sh` now shows version from `VERSION` file on startup

### Changed
- **`run.sh` refactored** — Fully modular with functions: `collect_skills()`, `deploy_configs()`, `deploy_agent()`, etc.
- **`run.sh` moved** — Relocated from `scripts/` to root directory for easier execution
- **AGENTS.md templated** — Owner profile now uses `{{OWNER_NAME}}`, `{{OWNER_HANDLE}}`, `{{DISCORD_HANDLE}}`, `{{OWNER_EMAIL}}`, `{{HARDWARE}}` placeholders
- **mac-vm.md templated** — Account email uses `{{OWNER_EMAIL}}` placeholder
- **Setup notices added** — AGENTS.md and runbooks display "Setup Required" notices until `setup-owner.sh` is run
- **Shellcheck compliance** — All scripts pass shellcheck with proper variable scoping and error handling

### Removed
- **`scripts/run.sh`** — Deleted (moved to root)

## [2.5.0] - 2026-02-20

### Changed
- **Hardcoded `/Users/kishore/` paths removed** — All absolute user paths in `AGENTS.md`, `CLAUDE.md`, `docs/scaffolds/`, and `docs/codex-limits.md` replaced with `$HOME/`
- **`CLAUDE.md` file:// link fixed** — Pointer to `AGENTS.md` now uses a relative path instead of an absolute `file://` URL
- **Zoho skill install steps removed** — `zoho-desk` and `zoho-sprint` SKILL.md files no longer include manual `cp` commands; `run.sh` handles script deployment
- **Scaffold clone hints added** — `skills/create-scaffold/stacks/go.md` and `stacks/python.md` now include fallback clone URLs for missing reference repos
- **`run.sh` reminder block polished** — Replaced raw empty `export` lines with a clean aligned reminder referencing the Proton Pass vault
- **`README.md`** — Removed `Z_AI_API_KEY`; kept `ZAI_API_KEY`

## [2.4.0] - 2026-02-20

### Added
- **KiloCode agent support** — `run.sh` deploys KiloCode config to `~/.config/kilo/opencode.json`
- **OpenCode permissions** — Added `rm` deny, `trash` allow, directory blocks to OpenCode config (was missing entirely)
- **Config file deployment** — `run.sh` now deploys agent configs (OpenCode, KiloCode) via `CONFIG_MAP`
- **Dotfile backup rule** — `AGENTS.md` and `CLAUDE.md` require timestamped backup before editing dotfiles
- **Agent deployment targets** — `run.sh` now deploys to `~/.config/agents` and `~/.pi/agent` in addition to existing agents
- **Claude E2E agent support** — `run.sh` now deploys to `~/.claude-e2e` if directory exists
- **Optional agent deployment** — Agents are only deployed if their home directory exists (prevents creating unused directories)
- **Handoff skill** — Standardized checklist for packaging work state when switching agents
- **Pickup skill** — Standardized checklist for rehydrating context when resuming work
- **Subagent coordination guide** — `docs/subagent.md` documents multi-agent tmux workflows
- **Zoho Desk pull enhancements** — Rate limiting with credit buffer, `--until` date filter, configurable concurrency/delay options
- **Zed editor guidance** — Notes on using `open -a Zed` when CLI not on PATH

### Changed
- **`rm` removed from deny list** across Claude, Claude E2E, KiloCode, and OpenCode configs. `rm` now prompts for approval instead of being hard-blocked. `trash` remains the preferred delete command.
- **Hardcoded paths removed** — Scaffold stacks and Zoho skill docs now use `$HOME/` instead of `/Users/kishore/`
- **OpenCode config format** — Replaced `<ENV:...>` placeholders with `{env:...}` format
- **Agent profile config dir** — Renamed from `~/.config/e2e/agent-profiles` to `~/.config/clawable`
- **`run.sh` formatting** — Normalized indentation from spaces to tabs
- **Zoho Desk thread content** — Fixed to use `plainText` fallback, removed `summary` field
- **Zoho Desk output format** — Pull now writes per-ticket JSONL files in `<YYYY>/<MM>/<DD>_<HHMMSS>_<ticket#>.txt` structure (was batched YAML)
- **Proton Pass vault naming** — Updated from `WORK_E2E_AGENTS` to `AGENTS_BUFFET` with `GITLAB_PERSONAL_ACCESS_TOKEN` item

## [2.0.0] - 2026-02-16

### Added
- **Oracle Operating Model** — `CLAUDE.md` and `AGENTS.md` auto-loaded by every supported agent
- **`scripts/run.sh`** — Idempotent deploy script that syncs profiles and skills to Claude Code, Codex, OpenCode, AmpCode, and KiloCode
- **10 production-ready skills** — `preflight-tooling`, `review-pr`, `create-scaffold`, `create-cli`, `e2e-qa-playwright`, `oracle`, `update-docs-and-commit`, `frontend-design`, `zoho-sprint`, `zoho-desk`
- **Agent profile templates** in `agents/` for all five supported agents
- **Codex config** in `config/codex.config.toml`
- **Operational docs** — `docs/tooling-inventory.md`, `docs/worktree-tmux.md`, `docs/codex-limits.md`, `docs/RELEASE.md`, `docs/install-and-test.md`
- **Scaffold references** in `docs/scaffolds/` for Python, Go, Rust, TypeScript, JavaScript CLI, and Tauri stacks
- **Runbooks** directory for operational playbooks
- **Zoho integration scripts** — `scripts/zoho-sprint.mjs`, `scripts/zoho-desk.mjs`
- **Deterministic forge detection** — `awakeninggit.e2enetworks.net` / `gitlab.com` → `glab`; `github.com` → `gh`

### Removed
- **`agents/` directory** and `--local` flag from `run.sh` — redundant copy of profiles already in repo root

### Changed
- **README.md** rewritten with Getting Started (`run.sh`), deployment matrix, skills catalog, and working-efficiently guide
- **CHANGELOG.md** 1.0.0 entry corrected to reflect repository-local workflow instead of external skills repo
- **`update-docs-and-commit` skill** now includes optional version bumping step
- **Git Forge Policy** updated with explicit host-based routing rules

## [1.0.0] - 2026-02-09

### Changed
- **Transformed repo purpose** from agent installer to learning resource hub
- **Rewrote README.md** as curated collection of AI learning materials:
  - Links to AI Bootcamp presentation series (Week 1-4)
  - Links to MyAccount 2/SRE engineering presentations
  - Links to YouTube videos (PM with AI Tools)
  - Links to team resources (Zoho WorkDrive, internal repos)
  - Design for Agents guidance with Mermaid diagrams
- **Moved skills and scripts** into a separate skills distribution flow (now deprecated)
- **Kept CLAUDE.md** as reference material for understanding agent configuration patterns

### Removed
- `install.sh` — Replaced by repository-local workflow docs
- `skills/` directory — Moved to dedicated skills repository
- `scripts/` directory — Moved to dedicated skills repository
- Agent installation logic — Replaced with standardized `npx skills` workflow

### Migration Notes
Users should use the repository-local assets:
```bash
./scripts/run.sh ~/.config/e2e/agent-profiles
```

Then start from `skills/preflight-tooling.md`.

## [0.9.0] - 2026-02-04

### Added
- **Agent-agnostic configuration system** with `CLAUDE.md` and `AGENTS.md` for vendor-neutral workflows
- **Idempotent installer** (`install.sh`) that detects and configures 8 AI coding agents:
  - Claude Code, Cursor, Zed, AmpCode, OpenCode, KiloCode, Antigravity, Pi
- **Centralized configuration** via `~/.config/e2e/ai-jumpstart/` with symlinked skills
- **11 shared skills** for common engineering workflows:
  - Development workflow: `zoho-setup`, `create-issue`, `create-plan`, `execute`, `explore`, `update-docs-and-commit`
  - Code review: `peer-review`, `frontend-review`, `backend-review`
  - Design & learning: `frontend-design`, `learning-opportunity`
- **Zoho Sprint integration** via `scripts/zoho-sprint.mjs` with OAuth authentication
- **Mermaid diagram standards** for architecture documentation with human verification checkpoints
- **Colored terminal output** in installer (green ✓, red ✗, yellow ⚠)

### Changed
- Migrated from agent-specific configs to centralized symlink-based architecture
- Standardized skill paths across all 8 supported agents

### Documentation
- Added `PROJECT_SPEC.md` with complete Phase 2 specification
- Added `PROJECT_STATUS.md` for progress tracking
- Added `README.md` with Mermaid architecture diagrams and quick start guide
- Added `CHANGELOG.md` (this file)
- **Restructured README.md** for clarity and completeness:
  - Added "What You Get" section highlighting 3 main value propositions
  - Added Troubleshooting section with common issues and solutions
  - Added Configuration Files section explaining CLAUDE.md and skills directory
  - Grouped Available Skills into Workflow Automation and Code Quality
  - Enhanced Typical Workflow diagram with code review and CAL usage example
  - Added skill design principles from Principal Engineer review

[Unreleased]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/compare/v3.0.0...HEAD
[3.0.0]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/compare/v2.8.0...v3.0.0
[2.8.0]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/compare/v2.7.0...v2.8.0
[2.7.0]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/compare/v2.6.0...v2.7.0
[2.6.0]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/compare/v2.5.0...v2.6.0
[2.5.0]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/compare/v2.4.0...v2.5.0
[2.4.0]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/compare/v2.0.0...v2.4.0
[2.0.0]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/compare/v1.0.0...v2.0.0
[1.0.0]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/releases/v1.0.0
[0.9.0]: https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/releases/v0.9.0
