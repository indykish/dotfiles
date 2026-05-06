# 🚧 LOGGING GATE

**Family:** Observability discipline. **Source:** `docs/LOGGING_STANDARD.md`.

**Triggers** — every `Edit`/`Write` that adds, removes, or changes a log emit:

- `*.zig` outside `vendor/`/`third_party/`/`.zig-cache/`/`*_test.zig` — `std.log.*`, `std.debug.print`, raw stderr writes, calls into `src/observability/logging.zig`.
- `*.ts`/`*.tsx`/`*.js`/`*.jsx` outside `vendor/`/`node_modules/`/`*.test.*`/`*.spec.*` — `console.*`, custom logger calls.
- `*.sh` outside generated dirs — `echo`/`printf` to `&2`.

**Override:** `LOGGING GATE: SKIPPED per user override (reason: ...)`. **User-invokable only.** Auto-mode does NOT cover this override.

## What this gate covers

`docs/LOGGING_STANDARD.md` codifies the wire format (logfmt), severity ladder, error-code embedding, scope discipline, and PII redaction. Drift is silent until incident response hits ungreppable logs at 3 AM.

## Pre-edit check

| Pattern | Rule |
|---|---|
| New `obs.scoped(.tag)` call | Scope must exist in `obs.Scope` enum; `event` must be snake_case `verb_noun` and exist in `obs.Event` enum. |
| New `err`/`warn` log mapping to a domain failure | `error_code=UZ-XXX-NNN` field required. Registry entry must land in same commit. |
| Per-iteration / hot-loop log | Use `debug` (hidden by default), not `info`. |
| `info` level | Event must appear in the `info` allow-list (see `LOGGING_STANDARD.md` §10A.L4). Otherwise downgrade to `debug` or justify. |
| `console.log`/`std.debug.print` in non-test source | Forbidden. Convert to logger or delete before commit. |
| `std.log.scoped` outside `src/observability/` | Forbidden. Only `obs.scoped` is callable from non-observability source. |
| `msg=` field | ≤ 300 chars. Stack traces emit as separate `event=stack_trace` debug record. |
| Multi-line values | Newlines must be `\n` literal (two chars), not raw newline byte. |

Verify each rule applies or is N/A for this edit.

## Required output (default — one line)

```
LOGGING GATE: <file> | scope:<ok|new:.tag> event:<ok|new:.event> error_code:<ok|N/A> severity:<ok|escalation> redaction:<ok|N/A>
```

Comment-only edit:

```
LOGGING GATE: <file> | comment-only | N/A
```

Full multi-line block fires when a sub-rule reports a violation:

```
LOGGING GATE: <file>
  LOGGING_STANDARD.md sections consulted: §3 (wire format), §4 (severity), §5 (error codes), §6 (PII), §7 (zig binding) | §8 (TS binding), §10A (tightenings)
  Wire format: <logfmt ✓ | violation: <where>>
  Required keys: <ts_ms,level,scope,event present ✓ | violation: <missing>>
  Severity choice: <within rules ✓ | violation: <e.g. info on per-iteration path>>
  Error-code embedding: <UZ-XXX-NNN present and registered ✓ | orphan: <code> | missing on err/warn>
  PII discipline: <no secret materials ✓ | violation: <where>>
  Field caps: <≤15 fields, msg≤300 chars ✓ | violation: <count>>
  Newline encoding: <\n literal ✓ | raw newline at <line>>
  Audit script: <audit-logging.sh on staged diff: 0 findings ✓ | N findings>
```

## End-of-turn audit

`scripts/audit-logging.sh` runs as part of `make lint`. Mechanical enforcement; reviewer responsibility for severity-level subjective calls and PII spot-checks (allow-list and msg-length are mechanical).

## Family

- `docs/LOGGING_STANDARD.md` — full standard, including §10A tightenings.
- `docs/ZIG_RULES.md` — Zig discipline umbrella; §7 of the standard depends on it.
- `docs/BUN_RULES.md` §10 — bans `console.log` in TS/JS source. This gate enforces.
- `docs/gates/error-registry.md` — pairs with this gate on `error_code=` audits.
