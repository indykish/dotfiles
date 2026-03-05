# `pilot` Specification Document

## 1. Overview

**pilot** is a zero-friction agent router that automatically selects the optimal AI coding assistant based on task complexity, quota availability, and context (work vs personal).

**Core Principle:** You express intent, `pilot` executes optimally.

## 2. Goals

- **Invisible:** No flags, no manual agent selection
- **Protective:** Automatically preserve expensive/limited quotas
- **Contextual:** Work repos use work accounts automatically
- **Fast:** <5ms overhead after initial discovery
- **Simple:** No API key management, no complex configuration

## 3. Architecture

### 3.1 High-Level Flow

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│   User      │────→│   pilot     │────→│   Agent      │
│   Input     │     │  (router)   │     │  (opencode/  │
│  "fix bug"  │     │             │     │  claude/etc) │
└─────────────┘     └──────┬──────┘     └──────────────┘
                           │
                    ┌──────┴──────┐
                    │  Config/    │
                    │  State Files│
                    └─────────────┘
```

### 3.2 Components

| Component | Responsibility |
|-----------|----------------|
| **Discovery** | Find installed agents and their configurations |
| **Analyzer** | Classify task complexity from prompt |
| **Router** | Select optimal agent based on rules |
| **Executor** | Spawn agent process via `execv()` |
| **State Manager** | Track quota usage (counters only) |

## 4. Discovery

### 4.1 Agent Detection

**Opencode:**
- Read `~/.config/opencode/opencode.json`
- Parse `provider` section
- Check if `{env:XXX}` variables exist
- Extract available providers

**Other Agents:**
- Check PATH for: `claude`, `codex`, `amp`, `ampcode`
- Verify API keys via env vars or config files
- Detect work vs personal profiles

### 4.2 Discovery Results

```json
{
  "agents": [
    {
      "name": "opencode-moonshot",
      "binary": "opencode",
      "provider": "moonshot",
      "model": "kimi-k2.5",
      "env_var": "MOONSHOT_API_KEY",
      "quota_type": "hourly",
      "quota_limit": 100,
      "complexity": "medium",
      "work_only": false
    },
    {
      "name": "claude-personal",
      "binary": "claude",
      "quota_type": "weekly", 
      "quota_limit": 50,
      "complexity": "complex",
      "work_only": false
    },
    {
      "name": "claude-e2e",
      "binary": "claude",
      "args": ["--profile", "e2e"],
      "quota_type": "unlimited",
      "complexity": "complex",
      "work_only": true
    }
  ]
}
```

### 4.3 Caching Strategy

- Cache discovery results in `~/.config/pilot/cache.json`
- Store file checksums (mtime + hash)
- Re-discover only when source configs change
- Fast path: <1ms to load cached agents

## 5. Task Analysis

### 5.1 Complexity Classification

```rust
enum Complexity {
    Simple,   // Typos, docs, comments
    Medium,   // Bug fixes, small refactors
    Complex,  // Architecture, large refactors
}
```

**Heuristics:**
- Token count: <100 chars = Simple, >2000 = Complex
- Keywords:
  - Simple: "typo", "docs", "comment", "fix typo"
  - Complex: "refactor", "architecture", "design", "plan"
- Context: >10 files changed = Complex
- Work repo: Default to Complex (err on caution)

### 5.2 Token Estimation

```rust
fn estimate_tokens(prompt: &str, files: Option<&[Path]>) -> u32 {
    let mut tokens = prompt.len() / 4;  // ~4 chars per token
    
    if let Some(files) = files {
        for file in files {
            tokens += file_content(file).len() / 4;
        }
    }
    
    tokens * 2  // Assume 2x for response
}
```

## 6. Routing Algorithm

### 6.1 Selection Criteria

1. **Work Context Check**
   - If work repo detected AND work agent available → Use work agent
   - Work detection: git remote contains work domains

2. **Complexity Matching**
   ```rust
   let candidates = match task.complexity {
       Simple => [opencode, codex, claude_personal, ampcode],
       Medium => [codex, claude_personal, ampcode, opencode],
       Complex => [claude_personal, ampcode, claude_e2e, codex],
   };
   ```

3. **Quota Availability**
   - Filter candidates with remaining quota
   - Score = (remaining / limit) * complexity_match
   - Select highest score

4. **Fallback Chain**
   - If primary fails, try next candidate
   - If all fail, wait for quota reset or error

### 6.2 Quota Rules

| Agent | Default Quota | Reset Schedule |
|-------|---------------|----------------|
| opencode (kimi) | 100 requests | Hourly (at :00) |
| opencode (mistral) | 100 requests | Hourly (at :00) |
| claude personal | 50 requests | Weekly (Sunday 00:00 UTC) |
| codex | 200 requests | Weekly (Sunday 00:00 UTC) |
| ampcode | $10.00 | Daily (00:00 UTC) |
| claude e2e | Unlimited | N/A |

## 7. State Management

### 7.1 State File Format

`~/.config/pilot/state.toml`:
```toml
[quotas.opencode-moonshot]
used = 47
reset_at = "2026-03-02T15:00:00Z"
last_pid = 12345

[quotas.claude-personal]
used = 3
reset_at = "2026-03-09T00:00:00Z"

[quotas.ampcode]
spent = 2.30
reset_at = "2026-03-03T00:00:00Z"
```

### 7.2 Update Rules

- **Increment on spawn:** When agent process starts successfully
- **CTRL+C < 3s:** Rollback counter (assume accidental)
- **CTRL+C ≥ 3s:** Keep counter (assume consumption)
- **Atomic updates:** Use file locking (`flock`) for concurrency

### 7.3 Concurrency

```rust
// File-based locking
let fd = open("state.toml", O_RDWR);
flock(fd, LOCK_EX);  // Exclusive lock

// Read → Update → Write
let state = read_state();
state.increment(agent);
write_state(state);

flock(fd, LOCK_UN);
```

## 8. Configuration

### 8.1 User Config

`~/.config/pilot/pilot.toml`:
```toml
# Optional: Override discovered agents
[agents.claude-e2e]
work_only = true
priority = 10

# Optional: Custom work detection
[context]
work_directories = ["~/Projects/e2e", "~/Projects/work"]
work_remotes = ["github.com/e2enetworks", "gitlab.com/e2e"]

# Optional: Override defaults
[defaults]
strategy = "quota_preservation"  # or "cost_minimization", "speed"
```

### 8.2 Auto-Configuration

- First run: Auto-discover agents
- Create default config with discovered agents
- Store in `~/.config/pilot/agents.toml` (auto-managed)
- User can edit `pilot.toml` for overrides

## 9. CLI Interface

### 9.1 Commands

```bash
pilot [OPTIONS] [PROMPT]

Options:
  -e, --estimate      Show token/cost estimate only
  -v, --verbose       Show routing decision
  -f, --file <PATH>   Include file context
  --refresh           Force re-discovery
  --init              Run first-time setup

Examples:
  pilot "fix the auth bug"
  pilot -e "refactor database layer" -f src/db.rs
  pilot --verbose "add tests"
```

### 9.2 Environment Variables

```bash
PILOT_CONFIG_DIR    # Config location (default: ~/.config/pilot)
PILOT_WORK_ONLY     # Force work mode (for scripts)
PILOT_AGENT         # Force specific agent
```

### 9.3 Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | No available agents (quota exhausted) |
| 3 | Agent spawn failed |
| 130 | Interrupted (CTRL+C) |

## 10. Error Handling

### 10.1 Failure Scenarios

1. **Agent not found:** Try next in fallback chain
2. **Quota exceeded:** Try cheaper agent or wait
3. **Spawn fails:** Log error, try fallback
4. **State file corrupt:** Reset to defaults, warn user

### 10.2 Recovery

- Always have at least one "unlimited" fallback
- If all agents fail, show helpful error:
  ```
  Error: All agents unavailable
  - opencode: quota exhausted (resets in 23m)
  - claude: binary not found
  - codex: API key missing
  
  Set OPENAI_API_KEY or wait for quota reset.
  ```

## 11. Performance Requirements

| Metric | Target |
|--------|--------|
| Cold start (discovery) | <500ms |
| Warm start (cached) | <5ms |
| State update | <10ms |
| Memory footprint | <10MB |

## 12. Security

- **No API keys stored:** Only check existence via env vars
- **No network calls:** All local operations
- **State file permissions:** 0600 (user read/write only)
- **No logging of prompts:** Privacy by default

## 13. Future Enhancements (Out of Scope)

- Historical usage analytics
- Machine learning for routing decisions
- Multi-machine sync
- Plugin system for custom agents
- GUI/TUI interface

---

## 14. Implementation Notes

**Language:** Zig (native performance, single binary)

**Key Libraries:**
- TOML parsing
- JSON parsing  
- File locking
- Process spawning

**Build:** Single static binary, no runtime dependencies

**Distribution:**
```bash
git clone <repo>
cd pilot
zig build -Doptimize=ReleaseFast
./install.sh  # Symlinks to ~/.local/bin/pilot
```

---

This specification is ready for implementation.
