# Worktree + tmux Workflow

CLI-first, minimal, deterministic.

## One-Time Setup

```bash
git config --global worktree.guessRemote true
```

## Create Parallel Worktrees

```bash
git worktree add ../skills-oracle oracle
git worktree add ../skills-docs docs
git worktree add ../skills-refactor refactor
```

Rules:

- One worktree per task stream.
- One active branch per worktree.
- No cross-editing.

## tmux Session Layout

```bash
tmux new -s agents
```

Suggested panes:

- Pane 1: Oracle coordinator
- Pane 2: Codex executor
- Pane 3: Claude/OpenCode checker
- Pane 4: Tests/logs

No nested tmux sessions.

## Stage Gates

1. `PLAN`: define scope + assumptions.
2. `EXECUTE`: mutate files in one worktree only.
3. `VERIFY`: run quality/test/build.
4. `DOCUMENT`: update docs/changelog.
5. `COMMIT`: only when requested.

Branch mutation is allowed only after stage transition.

## Merge + Cleanup

- Merge only after `VERIFY` passes.
- Remove completed worktree:

```bash
git worktree remove ../skills-oracle
```

## Recovery Commands

```bash
tmux list-sessions
tmux attach -t agents
git worktree list
```
