# 🚧 SPEC TEMPLATE GATE

**Family:** Spec authoring discipline. **Source:** `docs/TEMPLATE.md` — the "Prohibited" section (negative space) **and** the agent-facing required sections (positive space).

**Triggers** — every `Edit`/`Write` to:

- Any spec under `docs/v*/{pending,active,done}/**/*.md`.
- `docs/TEMPLATE.md` itself.
- Any file matching `*.md` whose body contains the spec frontmatter pattern (`^**Milestone:** M\d+`).

**Override:** `SPEC TEMPLATE GATE: SKIPPED per user override (reason: ...)`. **User-invokable only.** Auto-mode does NOT cover this override. Reasons must cite a concrete external constraint (vendor doc requirement, regulatory format), never internal preference.

## What this gate covers

**Family 1 — prohibited patterns (negative space).** `docs/TEMPLATE.md` "Prohibited" section forbids: time/effort estimates, effort columns, complexity ratings, percentage-complete fields, assigned owners, implementation dates. Specs created from the template don't carry the Prohibited section forward — only the body below the divider gets copied. Without enforcement, prohibited sections drift back into specs (the original M62_001 spec carried an "Estimated effort" section in violation; this gate prevents recurrence).

**Family 2 — required-present + no-placeholder (positive space).** The agent-facing template mandates the determinism sections the executing agent reads to emit invariant output: PR Intent & comprehension handshake, Applicable Rules, Applicable Gates, Overview, Prior-Art / Reference Implementations, Files Changed, Decomposition & alternatives, Sections, Interfaces, Failure Modes, Invariants, Test Specification, Acceptance Criteria, Discovery. A spec missing one — or leaving template residue (`path/to/file.ext`, `test_<short_name>`, `{one-line reason}`) — forces the agent to guess intent.

**Scope (no legacy carve-out).** Family 2 fires in `--staged` only — the spec being authored/edited now (the agent's own output): BLOCK. The bulk scans (`--all`/`--include-done`, which `make harness-verify` runs) execute Family 1 only, so they behave identically over the whole corpus and never break an existing spec. Existing `usezombie` specs adopt the new sections when migrated later; until a spec is touched (staged), it is not retroactively failed.

## Pre-edit check

| Pattern | Rule |
|---|---|
| `## Estimated effort` (any heading variant) | Forbidden. Delete the section. |
| `## Effort` / `## Complexity` / `## Sizing` | Forbidden. Use Priority. |
| `\b\d+\s*[-–]\s*\d+\s*h\b` (hour ranges like "10-14h") | Forbidden. |
| `\b\d+\s*hours?\b` / `\b\d+\s*days?\b` / `\b\d+\s*min(utes?)?\b` (time estimates) | Forbidden. |
| `\b(low|medium|high|small|large)\s*[:|-]\s*(effort|complexity)\b` | Forbidden. |
| `\d+%\s*complete` / `\b\d+/\d+\b\s*tasks` (percentage / fraction complete) | Forbidden — use binary PENDING/IN_PROGRESS/DONE. |
| `**Owner:**` / `**Assigned to:**` | Forbidden — use git history. |
| `**Due:**` / `**Deadline:**` (with date) | Forbidden — use Priority. |
| Missing a required determinism section in a **staged** spec | BLOCK — add it (PR Intent / Applicable Gates / Prior-Art / Decomposition / …). |
| Unfilled template residue (`path/to/file.ext`, `test_<short_name>`) in a **staged** spec | BLOCK — fill the section. |
| Spec without the SPEC AUTHORING RULES banner (post-template-update) | Informational — banner reminds future edits of the rule. |

## Required output (default — one line)

```
SPEC TEMPLATE GATE: <file> | prohibited:<0|list> required-sections:<all-present|missing-list — staged only> placeholders:<0|list> banner:<yes|no>
```

Full multi-line block fires on violation:

```
SPEC TEMPLATE GATE: <file>
  TEMPLATE.md "Prohibited" section consulted: ✓
  Prohibited sections found: <e.g. "## Estimated effort" at line N>
  Time estimates found: <e.g. "10–14 h" at line N>
  Effort/complexity fields found: <e.g. "**Effort:** medium" at line N>
  Percentage-complete fields found: <e.g. "60% complete" at line N>
  Owner/date fields found: <list>
  Audit script: <spec-template.sh on staged diff: 0 findings ✓ | N findings>
```

## Scope (M70)

`spec-template.sh` walks the **full pending+active spec set** via `git ls-files`. The index includes staged-but-not-yet-committed content, so a fix staged in pre-commit satisfies the check on the same hook run. `--staged` is preserved as an opt-in narrowing mode for iterative dev.

## End-of-turn audit

`audits/spec-template.sh` runs as part of `make lint`. Mechanical regex enforcement against the patterns listed above. Failures block `make lint`.

## Family

- `docs/TEMPLATE.md` — canonical Prohibited section.
- `kishore-spec-new` skill — creates specs from the template; banner is inserted at creation.
- `AGENTS.md` EXECUTE doc-reads table — adds `docs/TEMPLATE.md` for any spec edit.
