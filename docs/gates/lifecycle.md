# 🚧 LIFECYCLE GATE

**Family:** Zig discipline (sister to ZIG GATE). **Source:** `docs/LIFECYCLE_PATTERNS.md`.

**Triggers** — every `Edit`/`Write` to `*.zig` (incl. `*_test.zig`) outside `vendor/`/`third_party/`/`.zig-cache/` that:

- Adds a `pub fn init(`, `pub fn deinit(`, `pub fn close(`, `pub fn release(`, `pub fn destroy(`, `pub fn shutdown(`, `pub fn dispose(`, `pub fn free(`.
- Adds an `errdefer` or `defer` adjacent to an allocation.
- Adds a struct field holding heap memory (`[]const u8` from a runtime `dupe`/`alloc`), an arena, or an opaque handle (`std.fs.File`, `std.Thread.Mutex`).
- Reshapes any of the above on an existing struct.

**Override:** `LIFECYCLE GATE: SKIPPED per user override (reason: ...)`. **User-invokable only.** Auto-mode does NOT cover this override.

## What this gate covers

`docs/LIFECYCLE_PATTERNS.md` codifies init/deinit pairing, errdefer placement, allocator ownership, defer-vs-errdefer choice, arena/GPA boundaries, and the call-site ownership-transfer convention. Drift produces leaks, double-frees, and use-after-free — caught only by memleak tests run from clean state.

## Carve-out: PUB GATE vs LIFECYCLE GATE

| Gate | Question |
|---|---|
| **PUB GATE** (`docs/gates/pub-surface.md`) | Should this symbol be `pub`? Does the file shape justify it? |
| **LIFECYCLE GATE** (this file) | If `init` exists, does `deinit`? Is `errdefer` placed correctly? Is allocator ownership clear? |

Both gates may fire on the same `pub fn init` edit. Print both blocks. Neither defers to the other.

## Pre-edit check

| Pattern | Rule |
|---|---|
| Struct with heap allocation OR opaque handle | `pub fn init` paired with `pub fn deinit`. No size threshold. |
| `pub fn init` returning `*Self` | `errdefer allocator.destroy(self)` immediately after the `create`. |
| Multiple allocations in init | Either chain-of-`errdefer` per allocation, or single `errdefer` freeing the wrapper that owns them. |
| `errdefer` placement | Must lexically precede the allocation it protects. Last errdefer < last protected alloc. |
| `defer` and `errdefer` on same alloc | Forbidden. Pick one per `LIFECYCLE_PATTERNS.md` §6. |
| Allocator stored in struct | `deinit(self: *Self) void`. |
| Allocator NOT stored | `deinit(self: *Self, allocator: std.mem.Allocator) void`. |
| Arena-allocated slice stored in long-lived struct | Informational flag; reviewer must restructure or acknowledge. |
| `init` body empty AND `deinit` body empty | Informational flag — pair-for-shape, likely unneeded. |
| Renamed `deinit` (e.g. `close`, `release`) | Audit treats all listed names as lifecycle methods. Rename does not bypass. |

## Required output (default — one line)

```
LIFECYCLE GATE: <file> | init/deinit:<ok|missing-deinit|missing-init> errdefer:<ok|batched|missing> defer-mix:<ok|conflict> allocator:<stored|param|n/a> idempotency-test:<present|missing>
```

Comment-only edit:

```
LIFECYCLE GATE: <file> | comment-only | N/A
```

Full multi-line block fires when a sub-rule reports a violation:

```
LIFECYCLE GATE: <file>
  LIFECYCLE_PATTERNS.md sections consulted: §4 (init), §5 (deinit), §6 (defer/errdefer), §7 (ownership), §8 (arena/GPA), §10A (tightenings)
  Init/deinit pair: <both present ✓ | missing deinit on <Struct> | missing init on <Struct>>
  errdefer placement: <immediate ✓ | batched at line <N> | missing for <alloc at line N>>
  defer/errdefer conflict: <none ✓ | both at <line>>
  Allocator ownership: <stored ✓ | param ✓ | ambiguous: <where>>
  Arena leakage risk: <none ✓ | flagged: <field>>
  Idempotency assertion: <test exists ✓ | informational: missing for <Struct>>
  Audit script: <audit-deinit-pairs.sh on staged diff: 0 findings ✓ | N findings>
```

## End-of-turn audit

`scripts/audit-deinit-pairs.sh` runs as part of `make lint`. Mechanical enforcement on init/deinit pairs, errdefer placement, and lifecycle method recognition. Reviewer responsibility for idempotency assertions and arena-leakage acknowledgements.

## Family

- `docs/LIFECYCLE_PATTERNS.md` — full standard, including §10A tightenings.
- `docs/ZIG_RULES.md` — Zig umbrella; ZIG GATE fires alongside.
- `docs/gates/pub-surface.md` — PUB GATE; carve-out above.
- `docs/gates/file-length.md` — LENGTH GATE; init/deinit don't escape file/method caps.
