# Tooling Inventory

Last checked: 2026-02-16 (local MacBook M2)

## Refresh Command

```bash
for c in gh glab git tmux mise brew bun bunx node npm python go cargo rustc playwright stagehand oracle imageoptim trash; do
  if command -v "$c" >/dev/null 2>&1; then
    printf '%-12s %s\n' "$c" "$(command -v "$c")"
  else
    printf '%-12s %s\n' "$c" "NOT_FOUND"
  fi
done
```

## Current Baseline

| Tool | Status | Source |
|------|--------|--------|
| git | installed | brew |
| gh | installed | mise 2.86.0 |
| glab | installed | mise 1.85.1 |
| tmux | installed | mise 3.6a |
| mise | installed | shell |
| brew | installed | system |
| node | installed | mise 25.6.1 |
| npm | installed | mise (via node) |
| bun | installed | mise 1.3.9 |
| bunx | installed | mise (via bun) |
| python | installed | mise 3.14.3 |
| go | installed | mise 1.26.0 |
| cargo | installed | rustup |
| rustc | installed | rustup |
| oracle | installed | bun global |
| imageoptim | installed | brew |
| trash | installed | brew |
| playwright | not found | install per-project (`bun add -d @playwright/test`) |
| stagehand | not found | install per-project when needed |

### Optional

| Tool | Status | Source |
|------|--------|--------|
| zig | installed | mise 0.15.2 |
| pass-cli | installed | `~/.local/bin` |
| tailscale | installed | brew |

## Notes

- `playwright` is not a global binary; available per-project via `bunx playwright`.
- `stagehand` is a per-project dependency, not a global CLI.
- `pass` (GNU pass) removed from baseline; `pass-cli` is the preferred tool.
- `mabl` and `pnpm` removed from baseline (not required).
