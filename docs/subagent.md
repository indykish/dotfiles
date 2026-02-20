---
summary: 'Multi-agent coordination with tmux. Quick reference for persistent sessions.'
read_when:
  - Starting multiple agent sessions or coordinating parallel work.
  - Setting up persistent development environments.
---

# Subagent Coordination

Use tmux for persistent agent sessions that survive disconnects.

## Essential Commands

```bash
# Create session
tmux new-session -d -s mytask

# Attach to session
tmux attach -t mytask

# Detach (inside tmux): Ctrl+b, then d

# List sessions
tmux list-sessions

# Kill session
tmux kill-session -t mytask
```

## Agent Workflow Patterns

### Pattern 1: One Session Per Task

Each repo has different commands. Use what's defined in your Makefile:

**Your Stack Patterns:**

```bash
# Rust: make up (infra) → make dev (server)
tmux new-session -d -s rust-api -n up 'cd ~/Projects/rust-api && make up'
# Then in same or new session:
tmux new-session -d -s rust-api-dev -n dev 'cd ~/Projects/rust-api && make dev'
# Or: cargo watch -x run

# Python: make up (infra) → make dev (server)
tmux new-session -d -s py-api -n up 'cd ~/Projects/py-api && make up'
tmux new-session -d -s py-api-dev -n dev 'cd ~/Projects/py-api && make dev'

# Go: make dev, or go run main.go, or make build → make install (for CLIs)
tmux new-session -d -s go-api -n dev 'cd ~/Projects/go-api && make dev'
# For CLI dev: make build && make install && ./mycli

# Node/Astro: make dev, make start, npm run dev, bun run dev
tmux new-session -d -s astro-site -n dev 'cd ~/Projects/astro-site && make dev'
# Or: bun run dev, npm run dev
```

**Quick command discovery:**
```bash
cat Makefile | grep -E "^[a-zA-Z_-]+:.*$" | head -20
```

### Pattern 2: Handoff/Pickup Sessions
```bash
# Handoff: Keep session running
tmux list-sessions
tmux capture-pane -p -t mytask -S -100  # last 100 lines

# Pickup: Reattach later
tmux attach -t mytask
```

### Pattern 3: Split Work (Left = Code, Right = Agent)
```bash
tmux new-session -d -s work -n main
tmux split-window -h -t work:0
# Left pane: your editor (vim, zed, code, etc.)
tmux send-keys -t work:0.0 'zed .' Enter
# Right pane: AI agent
tmux send-keys -t work:0.1 'claude' Enter
tmux attach -t work
```

## Quick Reference

| Action | Command |
|--------|---------|
| New session | `tmux new -ds <name>` |
| Attach | `tmux attach -t <name>` |
| Detach | `Ctrl+b d` |
| List | `tmux ls` |
| Capture output | `tmux capture-pane -p -t <name>` |
| Send command | `tmux send-keys -t <name> '<cmd>' Enter` |

## Naming Convention

- `<repo>-<task>`: `api-auth-flow`, `web-login-page`
- `<agent>-<id>`: `claude-shell`, `codex-task-1`
- Keep names short, lowercase, hyphenated

## Concrete Multi-Agent Examples

**Important:** `/handoff` and `/pickup` are documentation prompts you invoke manually - they don't automatically spawn agents. You (the human) coordinate between agents by:
1. Reading the handoff/pickup skill
2. Following the checklist
3. Manually starting the next agent

### Scenario A: Claude → Codex Handoff

**You (Claude) are working on a Rust auth bug:**
```bash
# Start investigation in tmux
tmux new-session -d -s rust-auth-bug -n claude
tmux send-keys -t rust-auth-bug:0 'cd ~/Projects/rust-api && claude' Enter
tmux attach -t rust-auth-bug

# Inside tmux: investigate, find the issue...
# You need to switch to Codex for implementation
```

**You invoke `/handoff` (documentation skill) and follow the checklist:**
```markdown
## Handoff to Codex

### Scope
Found auth bug in src/auth/jwt.rs - token validation fails on expired tokens
- ✅ Located issue (line 47)
- 🔄 Need to implement fix
- ⏳ Add tests for edge cases

### tmux Session
- Session: `rust-auth-bug` (Claude investigating)
- Reattach: `tmux attach -t rust-auth-bug`
- Capture last output: `tmux capture-pane -p -t rust-auth-bug -S -50`

### Next Steps
1. Fix src/auth/jwt.rs line 47
2. Run `make test` to verify
3. Add edge case tests
```

**You manually start Codex and share the handoff notes:**
```bash
# In new terminal, start Codex
cd ~/Projects/rust-api && codex

# Inside Codex, invoke `/pickup` (documentation skill)
# Then follow the checklist:
# 1. Check for existing session
tmux ls
# rust-auth-bug: 1 windows (created Wed Feb 18 14:23:05)

# 2. Capture context without attaching
tmux capture-pane -p -t rust-auth-bug -S -100

# 3. Or attach to see full context
tmux attach -t rust-auth-bug
```

### Scenario B: Parallel Agents (Different Tasks)

**Three agents working simultaneously (you manually start each in separate terminals):**

**Terminal 1 - Claude:**
```bash
tmux new-session -d -s rust-feature -n claude
tmux send-keys -t rust-feature:0 'cd ~/Projects/rust-api && claude' Enter
tmux attach -t rust-feature
# Inside: work on Rust API feature
```

**Terminal 2 - Codex:**
```bash
tmux new-session -d -s py-bugfix -n codex
tmux send-keys -t py-bugfix:0 'cd ~/Projects/py-worker && codex' Enter
tmux attach -t py-bugfix
# Inside: fix Python worker bug
```

**Terminal 3 - OpenCode:**
```bash
tmux new-session -d -s astro-ui -n opencode
tmux send-keys -t astro-ui:0 'cd ~/Projects/astro-site && opencode' Enter
tmux attach -t astro-ui
# Inside: generate Astro components
```

**Monitor all sessions:**
```bash
tmux ls
# rust-feature: 1 windows
# py-bugfix: 1 windows
# astro-ui: 1 windows
```

**Check progress without attaching:**
```bash
# See what each agent is doing
tmux capture-pane -p -t rust-feature -S -20
tmux capture-pane -p -t py-bugfix -S -20
tmux capture-pane -p -t astro-ui -S -20
```

### Scenario C: Long-Running Background Task

**Start a migration that takes hours:**
```bash
tmux new-session -d -s db-migration -n worker
tmux send-keys -t db-migration:0 'cd ~/Projects/rust-api && make migrate' Enter

# Detach and let it run
# Come back hours later:
tmux capture-pane -p -t db-migration -S -100
# Check if done, errors, etc.
```

## Integration with Handoff/Pickup

When running `/handoff`:
1. List all sessions: `tmux ls`
2. Capture output from each: `tmux capture-pane -p -t <name> -S -50`
3. Include attach commands in handoff notes

When running `/pickup`:
1. Check for existing: `tmux ls`
2. Attach to relevant: `tmux attach -t <name>`
3. Or capture without attaching: `tmux capture-pane -p -t <name>`
