# 🚧 ERROR REGISTRY GATE

**Family:** Observability discipline. **Source:** `docs/LOGGING_STANDARD.md` §5; canonical registry in `src/errors/error_registry.zig` (per-project, not in dotfiles).

**Triggers** — every `Edit`/`Write` that:

- Adds or modifies `error_code=UZ-XXX-NNN` in any source file under `src/**` or `zombiectl/**`.
- Edits `src/errors/error_registry.zig`.
- Touches HTTP error responses, executor frames, or CLI error surfaces.

**Override:** `ERROR REGISTRY GATE: SKIPPED per user override (reason: ...)`. **User-invokable only.** Auto-mode does NOT cover this override.

## What this gate covers

Every `err`/`warn` log mapping to a domain failure must carry an `error_code=UZ-XXX-NNN` registered in `src/errors/error_registry.zig`. Every CLI / HTTP / executor error surface must emit codes from the same registry. Drift produces ungreppable error chains across layers — operator can't trace `UZ-EXEC-012` from the CLI back to the executor frame back to the docs.

## Pre-edit check

| Pattern | Rule |
|---|---|
| New `error_code=UZ-XXX-NNN` reference | Registry entry exists in `src/errors/error_registry.zig` in the same commit. **Blocking.** |
| Adding a registry entry | Code follows `UZ-<CATEGORY>-<NNN>` pattern (categories: AUTH, EXEC, HTTP, REDIS, DB, CLI, EXTERNAL, INTERNAL). Hint and docs URL fields populated. |
| Removing a registry entry | All references removed in same commit (RULE ORP — orphan sweep). |
| Registry entry with no references in `src/**` or `zombiectl/**` | Informational — declared-but-unreferenced (dead code). |
| Reference in source with no registry entry | Blocking — used-but-undeclared (orphan). |
| HTTP error response | Body includes `code: "UZ-XXX-NNN"`. |
| `zombiectl` error output | Human format: `error UZ-XXX-NNN: <message> (<context>)`. JSON format: `{ "code": "UZ-XXX-NNN", "message": ..., ... }` per `LOGGING_STANDARD.md` §8. |

## Required output (default — one line)

```
ERROR REGISTRY GATE: <file> | new-codes:<list|none> orphans:<0|N> dead-codes:<0|N informational> hint:<populated|missing>
```

Comment-only edit:

```
ERROR REGISTRY GATE: <file> | comment-only | N/A
```

Full multi-line block fires on violation:

```
ERROR REGISTRY GATE: <file>
  Registry: src/errors/error_registry.zig
  New codes added (this diff): <UZ-XXX-NNN, ...>
  Code references added (this diff): <UZ-XXX-NNN at <file>:<line>, ...>
  Orphan codes (used but not declared): <list — BLOCKING>
  Dead codes (declared but unreferenced): <list — informational>
  Hint/docs populated: <ok ✓ | missing for <code>>
  Audit script: <audit-error-codes.sh on staged diff: 0 findings ✓ | N findings>
```

## Scope (M70)

`audit-error-codes.sh` walks the **full `src/` + `zombiectl/` working tree** via `git ls-files`. The index includes staged-but-not-yet-committed content, so a fix staged in pre-commit satisfies the check on the same hook run. `--staged` is preserved as an opt-in narrowing mode for iterative dev.

## End-of-turn audit

`scripts/audit-error-codes.sh` runs as part of `make lint`. Greps `src/errors/error_registry.zig` for declared codes, then greps `src/**` and `zombiectl/**` for any `UZ-[A-Z]+-[0-9]+` literal that isn't in the registry. Reports orphans (blocking) and dead codes (informational).

## Family

- `docs/LOGGING_STANDARD.md` §5 — error-code embedding rules in log records.
- `docs/gates/logging.md` — pairs with this gate on `error_code=` audits.
- `docs/REST_API_DESIGN_GUIDELINES.md` — HTTP error response shape includes `code`.
- `docs/greptile-learnings/RULES.md` RULE ORP — orphan sweep on rename/delete.
