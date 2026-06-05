# 🚧 DOC READ GATE

**Family:** Discipline meta-gate. **Source:** `AGENTS.md` EXECUTE doc-reads table.

**Triggers** — every `Edit`/`Write` whose file pattern matches a row in the EXECUTE doc-reads table. Currently:

| File pattern | Doc to read |
|---|---|
| `*.zig` outside `vendor/`/`third_party/`/`.zig-cache/` | `docs/ZIG_RULES.md` |
| `*.ts`/`*.tsx`/`*.js`/`*.jsx` outside `vendor/`/`node_modules/` | `docs/BUN_RULES.md` |
| Log emit (any language, see `LOGGING GATE` triggers) | `docs/LOGGING_STANDARD.md` |
| Lifecycle method (init/deinit/close/release/etc. in `*.zig`) | `docs/LIFECYCLE_PATTERNS.md` |
| `src/http/handlers/**` or `public/openapi/**` | `docs/REST_API_DESIGN_GUIDELINES.md` |
| Auth-flow files | `docs/AUTH.md` |
| Schema-touching files | (re-print Schema Guard output) |
| Any spec under `docs/v*/{pending,active,done}/` | `docs/TEMPLATE.md` |
| Always (universal) | `docs/greptile-learnings/RULES.md` |

**Override:** `DOC READ: SKIPPED per user override (reason: ...)`. **User-invokable only.** Auto-mode does NOT cover this override. Reason must cite a concrete external constraint (emergency hotfix with doc consulted out-of-band, vendored code immune to internal rules).

## What this gate covers

Promotes the EXECUTE doc-reads table from advisory to enforced. Without this gate, doc-reads silently became "I'll skim if I have token budget" — gates with required printed output (ZIG GATE, LENGTH GATE, etc.) had real enforcement; doc-reads did not. This gate closes the gap.

## Required output (per triggered edit, before the edit happens)

```
📖 DOC READ: docs/<doc>.md (<line-count> lines, last updated <date if known>)
  Trigger: edit to <path>
  Sections checked: <list of §N referenced>
  Citations applied to this edit:
    - §<N>: <how this section's rule shows up in the diff>
    - ...
  Sections deemed not applicable (cited):
    - §<N>: <one-line reason>
```

### Cited-skip variant (read happened; nothing applied)

```
📖 DOC READ: docs/<doc>.md (read; nothing applies)
  Trigger: edit to <path>
  Edit nature: <one-line description, e.g. "single-line typo fix in comment">
  Reason no rule applies: <one-line citation, e.g. "no shape/import/typing change; pure data-literal update">
```

## Required output discipline

- One `📖 DOC READ:` block per triggered doc per edit. If multiple docs trigger (e.g. a `*.zig` log emit triggers both `ZIG_RULES.md` and `LOGGING_STANDARD.md`), print both blocks back-to-back.
- Cite by `§N` — proves the doc was actually consulted, not skimmed.
- Skip-with-cited-reason is a first-class outcome. "Read, nothing applies, here's why" is valid output. Silence is not.

## End-of-turn audit

`audits/doc-reads.sh` runs as part of `make lint`:

1. Read `git diff --name-only origin/main..HEAD`.
2. For each file, look up which doc-read triggers fire.
3. Search the agent's transcript / commit message body / PR description for matching `📖 DOC READ:` lines.
4. Mismatch (file edited but no proof-line for an applicable trigger) → fail.

The audit script does not validate citation correctness — that's reviewer responsibility. It only validates **existence** of the proof-line.

## Family

- `AGENTS.md` — canonical EXECUTE doc-reads table (this gate enforces).
- `audits/agents-md.md` — invariance question pairs with this gate.
- All listed standards docs (`ZIG_RULES.md`, `BUN_RULES.md`, `LOGGING_STANDARD.md`, `LIFECYCLE_PATTERNS.md`, `REST_API_DESIGN_GUIDELINES.md`, `AUTH.md`, `TEMPLATE.md`, `greptile-learnings/RULES.md`).
