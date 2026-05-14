# 🚧 Pub Surface & Struct-Shape Gate

**Family:** Zig discipline (sub-gate of ZIG GATE). **Source:** `docs/ZIG_RULES.md`. **Parent:** `docs/gates/zig.md`.

**Triggers — gate fires when:**

1. Creating any new `*.zig` file under `src/` (out-of-scope: `*_test.zig`, `vendor/`, `third_party/`, `node_modules/`, `.zig-cache/`).
2. **Threshold-cross on an existing file:**
   - An Edit adds the file's first `pub` type, OR
   - Adds a `pub fn ... self ...` method to a file currently dominated by `pub` free fns, OR
   - Removes the last pub free fn from a multi-pub-fn file.
3. Any user message saying "rethink the layout of `<file>`" or equivalent.

For all other `*.zig` edits, the full block is skipped with a one-liner: `PUB GATE: skipped — <one-line reason>`. Never produce a `pub` change without either the full gate block OR the skip warning preceding the edit.

**Override:** `PUB GATE: SKIPPED per user override (reason: ...)` immediately preceding the edit (sub-gate override). The umbrella `FILE SHAPE DECISION` override requires user's explicit ask **this turn** — auto-mode does NOT cover it.

## What this gate enforces

Two `docs/ZIG_RULES.md` rules:

1. **`pub` only when an external file imports the symbol** — default private; strip stale `pub`s when touching a file. *Mechanical enforcement is delegated to `zlint`'s `unused-decls: error` rule*, which fails `make lint` for any `pub` without an in-tree consumer. The gate body no longer requires a per-symbol consumer-grep in the proof block.
2. **File-as-struct shape is the default for new behavior-bound-to-state files.** A file *is* a struct in Zig — modeling that shape exposes ownership and testability cheaply. Conventional layout (multi-type modules, parsers/DSLs, constants modules, pub-free-fn-dominant modules, tagged-union dispatch tables, "operations over a passive value") **must be justified at PLAN**, not chosen by inertia.

**Tie-break:** behavior-bound-to-state → file-as-struct; operations-over-value → conventional. **Escape clause:** "I can articulate in one sentence why this is operations-over-value." If you can't, file-as-struct wins.

**No inheritance:** each new pub surface needs its own *shape verdict* — cloning a sibling's "Public for the integration test in …" justification does NOT discharge. Mechanical consumer-grep is `zlint`'s job; the design call is yours, and it does not transfer between symbols.

## File-as-struct layout

```zig
const Foo = @This();

// fields
allocator: std.mem.Allocator,
state: State,

// constructors
pub fn init(...) Foo { ... }
pub fn deinit(self: *Foo) void { ... }

// queries
pub fn isReady(self: Foo) bool { ... }

// mutators
pub fn step(self: *Foo) !void { ... }

// imports at end
const std = @import("std");
const State = @import("state.zig");
```

## FILE SHAPE DECISION (mandatory at PLAN, before first Write/Edit creating or reshaping)

```
FILE SHAPE DECISION: <intended-path>
  Trigger: <new file | existing file crossing threshold: <which>>
  Purpose (one sentence): <what this file's job is>
  Primary type (if any): <Name | none>
  Methods bound to that type: <N> | Pub free fns: <M>
  Verdict: <file-as-struct | conventional>
  Why not the other: <one sentence — required when verdict is conventional>
```

Skipping this block is a PLAN violation, not just an EXECUTE one.

## Pre-edit check (every `*.zig` Edit/Write)

1. Grep new-bytes for new pub surface — any match in *new* bytes (not the existing file) → gate fires:
   - `^pub` — new top-level pub declaration
   - `^\s+pub fn` — new pub method on an existing struct
   - new variant on a pub error union: `ErrorUnion{… NewVariant,`
   - new variant on a pub enum: `= enum { … NewVariant,`
2. Count primary types in the file (struct/union/enum the file is "about"); choose layout: file-as-struct (count = 1, all pub fns take `self`) or conventional (otherwise).
3. List every new `pub` symbol the edit introduces and confirm its shape verdict matches the file's chosen layout. Each new symbol gets its own verdict — do not inherit from a sibling.

Mechanical consumer-grep is no longer part of this checklist: `zlint`'s `unused-decls: error` rule (enabled in `zlint.json`, run by `make lint`) fails the build on any `pub` without an in-tree consumer. The gate body owns the design call (shape verdict + no inheritance); zlint owns "did you forget to strip a dead pub?"

## Required output (when fires)

```
PUB GATE: <file> | types=<0|1|>1> | layout=<file-as-struct|conventional> (<why>)
  New: <sym>, <sym>, …
```

If no new `pub` symbols and the file is not new, the gate is a no-op — skip the printable block.

## Self-audit (end-of-turn)

```bash
git diff -U0 HEAD -- '*.zig' \
  | grep -E '^\+pub |^\+\s+pub fn |^\+\s+[A-Z][a-zA-Z]+,$' \
  | head
```

Non-empty = new pub surface this turn; verify a PUB GATE block (with shape verdict) was printed before each corresponding Edit/Write. The end-of-turn `make lint` run is also load-bearing: if `zlint` reports `unused-decls`, you skipped stripping a dead `pub` and the gate did not fail loud enough.

For new-file FILE SHAPE coverage:

```bash
git diff --diff-filter=A --name-only origin/<base> -- 'src/**/*.zig' \
  | grep -v -E '_test\.zig$|^vendor/|^third_party/'
```

Each path must have had a `FILE SHAPE DECISION` block printed before its first Write.
