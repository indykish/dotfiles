---
name: kishore-spec-new
description: |
  Create a new project specification under docs/v{N}/pending/ using the
  canonical TEMPLATE.md, the project's terminology hierarchy
  (Prototype → Milestone → Workstream → Section → Dimension → Batch),
  and the priority/category file-naming convention. Use when the user says
  "create a spec", "new milestone", "start M{N}_{NNN}", "spec out X", or
  attempts to write a TODO.md (TODO files are forbidden in this project —
  every non-trivial intent becomes a spec instead).

  Cross-agent: works for Claude, Codex, OpenCode, Amp. Self-contained
  markdown — no agent-specific tool invocations.
---

# kishore-spec-new

Create a new milestone/workstream specification end-to-end. The skill
covers the four steps that make spec creation deterministic:

1. **Pick the right ID and category set.**
2. **Copy `docs/TEMPLATE.md` into `docs/v{N}/pending/`.**
3. **Fill every section using project terminology.**
4. **Commit on `main` with `Status: PENDING`.**

A spec is an *instance*; the rules under `AGENTS.md` and
`docs/greptile-learnings/RULES.md` are the *constants*. When the spec
contradicts the rules, amend the spec — never weaken the rules.

## Triggers

- User says: "create a spec", "spec this out", "new milestone",
  "draft M{N}_{NNN}", "start on M{N}", "track this as a milestone".
- The user attempts to create a `TODO.md` or any ad-hoc
  task list — convert it into a spec instead. **`TODO.md` is forbidden.**
- A `plan-eng-review` / `plan-ceo-review` / `plan-design-review` produced
  a plan that should be tracked durably.

## Inputs to gather first

Before writing the spec, surface and confirm:

1. **Milestone number `M{N}`** — sortable; check `docs/v{N}/{pending,active,done}/`
   for the highest existing number and pick the next one. If the user
   provides one, use that.
2. **Workstream `{WS}`** — zero-padded (`001`, `002`, …). New initiative
   under a milestone starts at `001`.
3. **Priority `P{0..3}`** —
   - **P0** critical / blocking
   - **P1** customer- or operator-facing
   - **P2** secondary / tooling
   - **P3** deferrable
4. **Category set `{CATEGORIES}`** — alphabetical, `≥1`:
   - `UI` Next.js dashboard
   - `API` Zig / Go handlers
   - `CLI` zombiectl / Node CLIs
   - `OBS` Grafana / metrics
   - `SKILL` SKILL.md / YAML policy
   - `INFRA` Terraform / deploy
5. **Descriptive name `{NAME}`** — UPPER_SNAKE_CASE, ≤6 words, describes
   the outcome not the action. `BUN_VENDOR_UTILITIES`, not
   `BUMP_BUN_DEPS`.
6. **Prototype tag** — `v1.0.0`, `v2.0.0`, … Drives directory choice
   (`docs/v1/` vs `docs/v2/`).

## File naming

```
docs/v{N}/{pending|active|done}/M{Milestone}_{Workstream}_P{Priority}_{CATEGORIES}_{NAME}.md
```

- Example: `docs/v2/pending/M52_001_P2_API_BUN_VENDOR_UTILITIES.md`.
- Categories are alphabetised: `API_CLI_UI`, never `UI_API_CLI`.
- Legacy forms (`M{N}_{WS}_{NAME}.md`, priority-first
  `P{Priority}_{CATEGORIES}_M{N}_{WS}_{NAME}.md`) exist under `docs/v1/`
  and `docs/v2/done/`. New specs use the form above. Do NOT rename
  existing legacy files.

## Terminology — forbidden substitutes

The vocabulary table is binding for everything that lands in a file
(specs, commits, PRs, handoffs, code comments). Conversational replies
where the user used an industry term are exempt; the moment content
lands in a file, project vocabulary wins.

| Use | Do NOT use |
|---|---|
| Prototype (v1.0.0) | Release, Version train, Program |
| Milestone (M{N}) | Sprint, Phase, Quarter, Release |
| Workstream (M{N}_{WS}) | Ticket, Task, Story, Issue, Subtask |
| Section (§3) | Phase, Step, Chapter, Stage |
| Dimension (3.4) | Acceptance criterion, AC, Subtask, Checkbox |
| Batch (B2) | Wave, Tranche, Iteration, Sprint |

Sequential slices inside a workstream are §1, §2, §3 — never
"Phase 1/2". Slices large enough to stand alone become their own
workstream + Batch designation.

## Directory layout

```
docs/v{N}/
  pending/   created, not started
  active/    agent working (one worktree per spec)
  done/      all dimensions DONE, PR merged
```

A spec only ever lives in one of these three directories. Movement
is always lifecycle-driven:

| Event | Movement |
|---|---|
| New spec created via this skill | Land in `pending/` with `Status: PENDING` |
| Begin implementation | `pending/` → `active/`, `Status: IN_PROGRESS`, set `Branch:` |
| All dimensions DONE, PR opened | `active/` → `done/`, `Status: DONE` |
| Parked midway | Stay in `active/`, mark complete dimensions DONE, leave the rest IN_PROGRESS |

## Step-by-step

### 1. Confirm inputs and pick the path

Run:

```bash
ls docs/v*/pending/ docs/v*/active/ docs/v*/done/ 2>/dev/null \
  | grep -oE 'M[0-9]+_[0-9]+' | sort -u | tail -5
```

Pick the next free `M{N}_{WS}` from the trailing list. Confirm with the
user if there's any ambiguity (e.g., new milestone vs. extending an
existing one with `_002`).

### 2. Copy the template

```bash
cp docs/TEMPLATE.md docs/v{N}/pending/M{N}_{WS}_P{P}_{CATEGORIES}_{NAME}.md
```

If `docs/TEMPLATE.md` is missing in this repo, fall back to
`~/Projects/dotfiles/docs/TEMPLATE.md`.

### 3. Fill every section

Open the new file and fill **every** section. Empty sections block the
spec from leaving `pending/`. Use the terminology table above.

Required header block:

```markdown
**Prototype:** v{N}.0.0
**Milestone:** M{N}
**Workstream:** {WS}
**Date:** {MMM DD, YYYY}
**Status:** PENDING
**Priority:** P{0..3} — {one-line justification}
**Categories:** {alphabetised list}
**Batch:** B{N}
**Branch:** feat/m{N}-{kebab-name} (to be created)
**Depends on:** {list of M{N}_{WS} this requires DONE first}
**Canonical architecture:** docs/architecture/{relevant-doc}.md §{N}
```

Required body sections — `scripts/audit-spec-template.sh --staged` BLOCKs a new
spec missing any of these, or one still carrying template `{placeholders}`:

- `## Implementing agent — read these first` — 3–5 pointers to existing code/docs to mirror before any edit.
- `## PR Intent & comprehension handshake` — eventual PR title, one-sentence intent, and the PLAN-stage restatement the agent produces before EXECUTE.
- `## Applicable Rules` — rule files (RULES.md, ZIG_RULES.md, REST_API_DESIGN_GUIDELINES.md, AUTH.md, SCHEMA_CONVENTIONS.md, …) to read before code. Missing → standard floor + surface the omission.
- `## Applicable Gates` — which Action-Triggered Guards fire + the satisfaction strategy (rules ≠ gates).
- `## Overview` — problem, goal (testable), solution summary.
- `## Prior-Art / Reference Implementations` — the reference codebase to mirror (CLI → supabase effects pillars; API → REST guide; …) + alignment/divergence note.
- `## Files Changed (blast radius)` — every file + action + reason. The EXECUTE scope contract; the agent edits only these without explicit override.
- `## Decomposition & alternatives (patch vs refactor)` — chosen shape, ≥1 alternative, and the patch-vs-refactor verdict surfaced to Indy.
- `## Sections (implementation slices)` — `§1`, `§2`, … each with numbered **Dimensions** (3.1, 3.2 …) mapping 1:1 to a Test + Acceptance Criterion — the unit of DONE.
- `## Interfaces` — exact HTTP/CLI/RPC signatures the spec adds or changes.
- `## Failure Modes` — table of failure → cause → handling.
- `## Invariants` — code-enforceable properties that stay true.
- `## Test Specification (tiered)` — one row per Dimension; tier (unit/integration/e2e) bound to `/write-unit-test`; user-facing categories get a user-centric `test-e2e*` scenario.
- `## Acceptance Criteria` — every line a verifiable command.
- `## Discovery (consult log)` — empty at creation; consults, skill outcomes, and Indy-acked deferral quotes land here.

### 4. Commit on main

```bash
git add docs/v{N}/pending/M{N}_{WS}_*_{NAME}.md
git commit -m "docs(m{N}): add spec — {short title}"
```

The spec lands on `main` in `pending/`. The CHORE(open) lifecycle step
moves it to `active/` and creates the worktree — handled separately by
the lifecycle, not by this skill.

## What this skill does NOT do

- It does **not** start coding, create a worktree, or move the spec to
  `active/`. That's CHORE(open), which fires when implementation
  begins.
- It does **not** modify any rule file, ARCHITECTURE doc, or
  changelog.
- It does **not** branch off main. Spec creation is a `main` commit.

## Failure modes

| Surface | What you do |
|---|---|
| User insists on writing `TODO.md` | Decline. Convert the intent into a spec via this skill. |
| Spec name collides with a `done/` entry | Pick the next workstream number; never reuse. |
| Spec depends on something still in `pending/` | Allowed, but list the dependency in `Depends on:` and surface to the user. |
| Spec proposes work that violates a rule | Amend the spec text (or scope) before committing. The rules are the constants. |

## References

- `docs/TEMPLATE.md` — canonical spec template (per-repo copy).
- `~/Projects/dotfiles/docs/TEMPLATE.md` — fallback if the repo lacks
  one.
- `~/Projects/dotfiles/AGENTS.md` — lifecycle phases, action-triggered
  guards, deterministic VERIFY/CHORE sequencing.
- `docs/greptile-learnings/RULES.md` — universal coding rules cited in
  every spec's "Applicable Rules" section.
