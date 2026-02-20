# Install And Test Guide

Use this after reviewing `AGENTS.md`, `skills/`, and `agents/`.

## 1. Review Package

- Core contract: `AGENTS.md`
- Claude variant: `CLAUDE.md`
- Agent bundle: `agents/`
- Sync helper: `scripts/run.sh`
- Skill set: `skills/`
- Flow guide: `docs/worktree-tmux.md`
- QA baseline: `AGENTS.md` -> `QA Testing Decision`

## 2. Install Profiles

```bash
git clone git@awakeninggit.e2enetworks.net:engineering/ai-jumpstart.git ~/Projects/ai-jumpstart
cd ~/Projects/ai-jumpstart
./scripts/run.sh
```

This deploys profiles and skills to `~/.claude`, `~/.codex`, `~/.opencode`, `~/.ampcode`, `~/.kilocode`.

It also bootstraps:

- `~/.codex/config.toml` (only if missing)
- `~/.config/e2e/agent-profiles/.env.example` (only if missing)
- `~/.config/e2e/agent-profiles/zoho.json.example` (only if missing)
- `~/.config/e2e/agent-profiles/zoho-desk.mjs`
- `~/.config/e2e/agent-profiles/zoho-sprint.mjs`

To clean and resync:

```bash
./scripts/run.sh --clean
```

## 3. Preflight

Run `/preflight-tooling` in any agent to detect and install missing tools (`mise` first, `brew` fallback).

## 4. Smoke Test Prompt

Use this same prompt in each agent:

```text
Run PLAN -> EXECUTE -> VERIFY -> DOCUMENT on a docs-only change in this repository.
Do not commit.
Show assumptions first.
```

Pass criteria:

- Assumptions listed first.
- Explicit stage transitions.
- Deterministic command usage.
- No unexpected file scope expansion.

## 5. QA Baseline Test

In a JS/TS repo with Playwright configured:

```bash
bunx playwright test --reporter=line
```

Pass criteria:

- Headless CLI run succeeds locally.
- Same command succeeds in CI.

## 6. PR Review Test

Open a PR/MR in any repo and run `/review-pr`. Verify it:

- Detects the correct forge (GitHub or GitLab)
- Pulls the diff
- Reviews changed code with structured output
- Produces a verdict (APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION)

## 7. Worktree + tmux Test

```bash
git worktree add ../skills-test test-flow
tmux new -s agents-test
```

Pass criteria:

- Work remains isolated to worktree.
- No cross-worktree edits.
