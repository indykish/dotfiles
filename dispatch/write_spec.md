# write_spec.md — spec-authoring dispatch (LATENT façade)

This is the prose the AGENT reads **before writing or editing a spec** under
`docs/v*/{pending,active,done}/`. It pairs with the deterministic half
`audits/spec.sh` (named `audits/spec-template.sh` until the Stage-2 rename),
which runs in `make lint`. (This is `docs/gates/spec-template.md` absorbed into
the dispatch model — `docs/TEMPLATE.md` remains the canonical section source.)

**Signal legend:**

- 🟢 / 🔴 — `audits/spec.sh` mechanically passes/fails the prohibited-pattern and
  required-section checks.
- 🔵 DECIDE — whether a required section is *meaningfully filled* (not just
  present) is the agent's judgment at author time.

## Trigger — every Edit/Write to

- Any spec under `docs/v*/{pending,active,done}/**/*.md`.
- `docs/TEMPLATE.md` itself.
- Any `*.md` whose body carries the spec frontmatter pattern (`^**Milestone:** M\d+`).

**Override:** `SPEC TEMPLATE GATE: SKIPPED per user override (reason: ...)`.
**User-invokable only.** Auto-mode does NOT cover it; reasons must cite a concrete
external constraint (vendor doc requirement, regulatory format), never internal
preference.

## What this covers

**Family 1 — prohibited patterns (negative space).** `docs/TEMPLATE.md`
"Prohibited" forbids: time/effort estimates, effort columns, complexity ratings,
percentage-complete fields, assigned owners, implementation dates. Specs created
from the template don't carry the Prohibited section forward — only the body
below the divider gets copied — so without enforcement these drift back in.

**Family 2 — required-present + no-placeholder (positive space).** The
agent-facing template mandates the determinism sections the executing agent reads
to emit invariant output: PR Intent & comprehension handshake, Applicable Rules,
Applicable Gates, Overview, Prior-Art / Reference Implementations, Files Changed,
Decomposition & alternatives, Sections, Interfaces, Failure Modes, Invariants,
Test Specification, Acceptance Criteria, Discovery. A spec missing one — or
leaving template residue (`path/to/file.ext`, `test_<short_name>`,
`{one-line reason}`) — forces the agent to guess intent.

**Scope (no legacy carve-out).** Family 2 fires in `--staged` only — the spec
being authored now (the agent's own output): BLOCK. Bulk scans (`--all` /
`--include-done`, which `make harness-verify` runs) execute Family 1 only, so they
behave identically over the corpus and never break an existing spec.

## Pre-edit check

| Pattern | Rule |
|---|---|
| `## Estimated effort` (any heading variant) | Forbidden. Delete the section. |
| `## Effort` / `## Complexity` / `## Sizing` | Forbidden. Use Priority. |
| `\b\d+\s*[-–]\s*\d+\s*h\b` (hour ranges like "10-14h") | Forbidden. |
| `\b\d+\s*hours?\b` / `\b\d+\s*days?\b` / `\b\d+\s*min(utes?)?\b` | Forbidden. |
| `\b(low|medium|high|small|large)\s*[:|-]\s*(effort|complexity)\b` | Forbidden. |
| `\d+%\s*complete` / `\b\d+/\d+\b\s*tasks` | Forbidden — binary PENDING/IN_PROGRESS/DONE. |
| `**Owner:**` / `**Assigned to:**` | Forbidden — use git history. |
| `**Due:**` / `**Deadline:**` (with date) | Forbidden — use Priority. |
| Missing a required determinism section in a **staged** spec | BLOCK — add it. |
| Unfilled template residue in a **staged** spec | BLOCK — fill the section. |
| Spec without the SPEC AUTHORING RULES banner | Informational — reminds future edits. |

## Required output (default — one line)

```
SPEC TEMPLATE GATE: <file> | prohibited:<0|list> required-sections:<all-present|missing-list — staged only> placeholders:<0|list> banner:<yes|no>
```

Full multi-line block fires on violation (prohibited sections / time estimates /
effort fields / %-complete / owner-date fields, each with line numbers, plus the
`audits/spec.sh` staged-diff finding count).

## Scope (M70)

`audits/spec.sh` walks the **full pending+active spec set** via `git ls-files`;
the index includes staged-but-uncommitted content, so a fix staged in pre-commit
satisfies the check on the same hook run. `--staged` is the opt-in narrowing mode.

## Family

- `docs/TEMPLATE.md` — canonical Prohibited section + required sections.
- `kishore-spec-new` skill — creates specs from the template; inserts the banner.
- `audits/spec.sh` — mechanical regex enforcement, runs in `make lint`.
