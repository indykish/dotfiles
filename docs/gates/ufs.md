# 🚧 UFS Gate — Unified Form for Symbols

**Family:** Constant discipline. **Source:** `AGENTS.md` (HARNESS VERIFY enforcement) + `BUN_RULES.md §2` + `ZIG_RULES.md` "RULE UFS" clauses.

**Triggers** — every `Edit`/`Write` to source files under `src/`, `ui/packages/*/src/`, `ui/packages/*/app/`, `ui/packages/*/lib/`, `ui/packages/*/components/`, `ui/packages/*/pages/`, `ui/packages/*/tests/`, `zombiectl/src/`, `zombiectl/test/` matching `*.zig`, `*.ts`, `*.tsx`, `*.js`, `*.jsx`. Excluded: `vendor/`, `third_party/`, `.zig-cache/`, `node_modules/`, `*.tsbuildinfo`.

**Override:** `UFS GATE: SKIPPED per user override (reason: ...)` immediately preceding the edit. **User-only**; auto-mode does not cover.

**Carve-out:** **Pin tests** keep their literals if and only if the literal IS the contract under test (`expect(formatDollars(4_710_000_000)).toBe("$4.71")`). Each pin must carry an inline `// pin test: literal is the contract` comment on or above the line.

## What this gate enforces

Three discipline points, all part of RULE UFS:

1. **Repeat literals → named constant.** Any string literal appearing ≥2 times in the same file (or in the same module/package — see scope ladder below) becomes a named const. Wire-format enum values (`"platform"`, `"self_managed"`, `"receive"`, `"stage"`, mode strings, posture labels, channel names, queue names, error code categories) are *always* named — even at first use, even in test fixtures.

2. **Semantic numeric literals → named constant.** Numeric literals carrying meaning beyond their digits become named consts even at first use. Includes: conversion factors (powers-of-ten ≥ 1e3 used as multipliers/divisors), thresholds, sub-cent rates, time-unit factors, byte-unit factors, retry caps, sentinel offsets. Bare `1_000_000_000` in `nanos / 1_000_000_000` is a smell — `nanos / NANOS_PER_USD` is the rule.

3. **Cross-runtime parity.** Any constant that exists in more than one runtime (Zig, TS, JS) **must share its identifier verbatim**, modulo case where a language idiom forces it (Zig snake_case → TS/JS SCREAMING_SNAKE is a single-runtime style choice; the *semantic* name is identical). When a literal in runtime A would benefit from a name and a sibling runtime already has that name, reuse it. When introducing a new constant, define it in every runtime that uses the same value, same commit. There is no per-constant carve-out: this applies to every cross-runtime constant, not a curated subset.

The gate exists because RULE UFS is otherwise pure self-policing. Without an audit script, an inline literal in a 800-LOC editing session reliably slips past attention.

## Pre-edit checks

Before saving an edit that introduces or relocates a literal:

1. **Same-file repeat?** Grep within the file for the literal value. If it appears ≥1 time already, define a const at the top of the file (or in the module's `constants.ts`/`constants.zig`) and replace all occurrences.

2. **Same-module repeat?** Grep within the module/package (`ui/packages/app/`, `zombiectl/src/`, `src/`). If repeated, define in the module's canonical types/constants file (`lib/types.ts`, `src/state/<topic>.zig`, `zombiectl/src/constants/<topic>.js`).

3. **Cross-runtime sibling?** When the literal is a wire-format string or unit-conversion numeric, grep all three runtimes for an existing matching name. If found, reuse the name. If not, define in every runtime that uses the same value, same commit.

4. **Carve-out check?** If the literal IS the contract a pin test verifies, write the `// pin test: literal is the contract` comment on or above the line. Otherwise, name it.

## Required output (per Edit/Write — one line by default)

```
UFS GATE: <file> | repeats:<count> | semantic-numerics:<count> | cross-runtime:<status> | pin-test-carve-outs:<count>
```

Multi-line block fires when repeats > 0 OR semantic-numerics > 0 OR cross-runtime status ≠ ok:

```
UFS GATE: <file>
  Repeat string literals named: <list of value → CONSTANT_NAME pairs>
  Repeat string literals KEPT (carve-out): <value> — <reason: pin test / single-use semantically irreducible / etc.>
  Semantic numerics named: <list of value → CONSTANT_NAME pairs>
  Semantic numerics KEPT: <value> — <reason>
  Cross-runtime parity: <status — e.g. "NANOS_PER_USD added to Zig+TS+JS this commit" or "n/a — runtime-internal constant">
```

## Scope (M70)

`audit-ufs.sh` walks the **full working tree** via `git ls-files`. The index includes staged-but-not-yet-committed content, so a fix staged in pre-commit satisfies the check on the same hook run.

The previous `--diff` (`BASE...HEAD`) default was retired with M70. The forcing function was M68 commit `02c1f3cf`: pre-commit's `HEAD` is the prior commit, so `BASE...HEAD` was blind to nine cross-runtime mismatches the agent had staged but not yet committed. The full-codebase scope removes that blindspot.

`--all` is accepted as a back-compat alias for the default. `--diff` is rejected with exit 2 + a pointer to this section.

## Self-audit (end-of-turn / HARNESS VERIFY)

`scripts/audit-ufs.sh` is invoked at HARNESS VERIFY by the agent. Convention follows the sibling audit scripts (`audit-logging.sh`, `audit-error-codes.sh`, `audit-deinit-pairs.sh`, `audit-spec-template.sh`) — none of them wire into `make lint`; the agent runs each as part of the gate ceremony, with the result feeding the HARNESS VERIFY table. The script is generic — no manifest of known literals — so it scales as the codebase grows:

```bash
bash scripts/audit-ufs.sh          # full-codebase scan (default and only mode)
bash scripts/audit-ufs.sh --all    # alias for default
```

The script emits a violations table. Empty table = pass. Each row is one of:

- `string-dup-file <file> "<literal>" <count>` — same string ≥2× in one file
- `string-dup-module <module> "<literal>" <count>` — same string ≥2× across a module/package
- `numeric-suspect <file>:<line> <literal>` — power-of-ten or known unit-factor numeric not bound to a const (excludes anything on a `// pin test: literal is the contract` line)
- `cross-runtime-orphan <const_name> <runtime>` — SCREAMING_SNAKE constant defined in one runtime, missing from a sibling runtime that the same diff touches

Violations resolve by either (1) extracting to a named const + replacing all sites, (2) adding the constant in the missing sibling runtime same-commit, or (3) adding the `// pin test: literal is the contract` comment.

## HARNESS VERIFY row

```
| UFS GATE             | ✅ pass | 🟡 N violations addressed | 🔴 N unresolved |
```

🔴 unresolved → return to EXECUTE; the lifecycle does not advance.

## Failure mode this gate exists to prevent

Indy's M66_001 §3 tail surfaced the failure clearly: `RULE UFS` lived as a single bullet in `BUN_RULES.md §2` with no audit, no HARNESS VERIFY row, and no per-edit ceremony. Across an 800-LOC session the agent introduced ~20 inline literals (`"platform"`, `"self_managed"`, `"receive"`, `"stage"`, `mode: "byok"`, `1e9`, `1_000_000_000`, etc.) that the rule already covered but no mechanism caught. The rule is fine; the enforcement was missing. This gate adds the enforcement.
