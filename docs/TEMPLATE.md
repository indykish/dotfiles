# Milestone Specification Template

> **CANONICAL TEMPLATE** — Copy this when creating a new milestone spec.
> Place the copy in `docs/v{N}/pending/M{N}_{NNN}_{NAME}.md`.
> See `AGENTS.md → Specification Standards → Spec Lifecycle` for the workflow.

---

## ⚠️ This template is for milestone specs only

One demoable, end-to-end capability with an executing-agent contract — a **goal-contract**, not a brainstorming doc, audit, or half-formed idea. If you can't yet say *what success looks like and how a test would prove it*, stop and finish thinking before filling this out.

---

## Spec Registry — Goal Contract, Not Pseudocode

A milestone spec is a **goal contract** between you (writing it) and the agent or human (executing it). It must answer:

- **What does success look like?** (testable goal, acceptance criteria)
- **What's the surface area?** (files touched, interfaces, invariants)
- **How will we know it works?** (tests, evals, verification commands)
- **Where do existing patterns live?** (point at code to mirror, not code to copy)

A spec must NOT answer:

- Which exact allocator, capacity, library version, line-by-line code (the agent figures that out from the repo)
- Which exact SQL DDL syntax (the agent reads existing migrations and conforms)
- Which exact import statements (the agent's lint catches drift)

> **Pseudocode litmus test:** if your spec names a specific library version (`postcard 1.1`), a specific variable name (`var ctx = ...`), or a specific SQL clause (`CREATE TABLE ... DEFAULT 'foo'`), it's pseudocode. Replace with *"use the project's existing serialization library"* and a pointer at where it lives. Pseudocode rots within a sprint.

**The principle:** an executing agent should be able to plan and ship from a spec without playing 20-questions with the spec author. But specs that leak into implementation pseudocode rot fast — implementation drifts and the prose is wrong within a sprint. The middle path is **contract + invariants + tests + pointers to existing patterns**. The agent has agency on the rest.

If you find yourself writing `for (i = 0; i < N; i++)` or naming Zig structs in the spec body, stop. Move that detail into the implementing-agent prologue ("read these files for the pattern") or the test specification ("the test asserts behavior X").

---

## Anti-Patterns (read this BEFORE drafting)

> These are common drifts that conflate goal-contract with implementation pseudocode. Surface-listed here, near the top, because spec authors who find them on line 173 have already drifted.

| # | Anti-pattern | What to do instead | Why |
|---|---|---|---|
| 1 | Code blocks inside section bodies | Describe WHAT this slice delivers. If you must specify behavior precisely, write it as a Test (`test_x asserts foo() returns bar`). | The implementation lives in the codebase, not the spec. Code blocks in prose drift; tests don't. |
| 2 | Listing every variable name | Point at an existing implementation: *"mirror the allocator pattern from `src/http/handlers/zombies/steer.zig`."* | Variable names are the implementing agent's call; they'll match local style. |
| 3 | Specifying SQL DDL line-by-line | Show the table shape and constraints in prose. Don't paste `CREATE TABLE`. | The agent reads existing migrations and conforms. |
| 4 | Pinning library versions in spec body | *"Use the existing Redis client"* + pointer to where it's imported. | The package manifest is the source of truth — not the spec. |
| 5 | Step-by-step ordering ("Step 1: interfaces. Step 2: core.") | Use **Sections** (slices that deliver value). Let the agent sequence within. | Step lists become stale ordering; slices stay coherent. |
| 6 | Writing the test code in the spec | Test Specification names tests + asserts behavior in prose. Agent writes the test in project style. | Inline test code drifts the moment the test framework changes. |

If you've slipped into any of these, the fix is usually to **move detail to the implementing-agent prologue** (point at a file) or **delete it** (the agent figures it out).

---

## How to Use This Template

1. Copy this file to `docs/v{N}/pending/M{N}_{NNN}_{DESCRIPTIVE_NAME}.md`.
2. Replace every `{placeholder}` with real content.
3. Fill **every** section. If a section truly does not apply, write "N/A — {reason}".
4. Set `Status: PENDING` and commit to `main`.
5. When work begins, the spec moves to `active/` per the Spec Lifecycle.

**Length target — hard upper bound 300 lines.** Typical specs are 150–300 lines. Larger specs are usually two specs trying to share one file — split them. If you're past 300 lines and haven't gone into the Verification Evidence section yet, your scope is wrong.

---

## Hierarchy

```
v{N}.0.0 (Prototype)
└── Milestones (M40, M41, M42...)
    └── Workstreams (M40_001, M40_002...)
        └── Sections (§1, §2, §3...)
            └── Tests (named, machine-runnable)
```

**Terminology:**
- **Prototype** — major release (`v2.0.0`)
- **Milestone** — one demoable end-to-end capability with evidence
- **Workstream** — one singular working function inside a milestone (3-digit zero-padded: `001`, `002`)
- **Batch** — parallel execution group (B1, B2, B3...). Workstreams in the same batch run concurrently. Batches are sequential; B2 starts after B1 gates clear.
- **Section** — implementation slice inside a workstream — what gets built, why
- **Test** — verification unit in the Test Specification — proves a claim from Overview/Goal

A milestone is not complete until evidence is captured: commands, logs, screenshots, or recorded walkthrough notes.

---

## Guardrails

### Workstream Count

- Default limit: each milestone defines at most **4 workstreams**.
- A **5th workstream** is allowed when it's a cross-cutting concern feeding multiple existing workstreams that would lose coherence if split out.
- Beyond 5: never. Split into a new milestone.

### Section Count

- Soft target: 3–9 sections per spec. More than 9 = the spec is doing too much.

### File Naming

```
docs/v{N}/{pending|active|done}/M{N}_{NNN}_{DESCRIPTIVE_NAME}.md

Example: docs/v2/pending/M40_001_WORKER_SUBSTRATE.md
```

Priority + categories live in frontmatter (or in the spec header), not in the filename. Filenames optimize for human findability of the milestone number first.

---

## Status Markers

- `PENDING` — not started, awaiting work
- `IN_PROGRESS` — currently being worked on
- `DONE` or `✅` — complete, verified, tested
- `DEFERRED` — implementation attempted (or designed) and explicitly not shipped; spec lives in `done/` as a record. The Discovery section MUST capture the rationale and the reactivation conditions that would warrant revisiting the spec.

---

## Prohibited

- No time estimates ("5 min", "1 hour", "2 days") — meaningless and often wrong
- No effort columns or complexity ratings — use Priority
- No percentage complete — use binary PENDING/DONE
- No assigned owners — use git history and handoff notes
- No implementation dates — use Priority (P0/P1/P2)

Use **Priority** (P0/P1/P2) and **Dependencies** for sequencing.

---

# Spec Body — Copy Everything Below This Line

<!--
SPEC AUTHORING RULES (load-bearing — do not delete):
- No time/effort/hour/day estimates anywhere in this spec.
- No effort columns, complexity ratings, percentage-complete, implementation dates.
- No assigned owners — use git history and handoff notes.
- Priority (P0/P1/P2) is the only sizing signal. Use Dependencies for sequencing.
- If a section below contradicts these rules, the rule wins — delete the section.
- Enforced by SPEC TEMPLATE GATE (`docs/gates/spec-template.md`) and `scripts/audit-spec-template.sh`.
- See docs/TEMPLATE.md "Prohibited" section above for canonical list.
-->

# M{Milestone}_{Workstream}: {Title — must be testable, not vague}

**Prototype:** v{major}.{minor}.{patch}
**Milestone:** M{Number}
**Workstream:** {001-009}
**Date:** {MMM DD, YYYY}
**Status:** PENDING | IN_PROGRESS | DONE
**Priority:** P0 | P1 | P2 — {one-line reason}
**Categories:** {API | CLI | UI | SKILL | DOCS | OBS | INFRA — one or more}
**Batch:** B{1-4} — {parallel execution context}
**Branch:** {feat/mNN-name — added when work begins}
**Depends on:** {M{N}_{NNN} (one-line reason), ...}
**Provenance:** human-written | LLM-drafted ({model}, {date}) | agent-generated (pre-spec, {source doc})

> **Provenance is load-bearing.** The implementing agent calibrates trust based on who wrote the spec. LLM-drafted specs need extra cross-checking against the codebase; human-written specs assume the author has read the relevant code.

**Canonical architecture:** `docs/ARCHITECTURE.md` §{N} ({brief link to relevant section}).

---

## Implementing agent — read these first

> **Required prologue. Minimum 3, maximum 5 pointers.** Fewer than 3 = you haven't done the homework; the agent will end up repeating it. More than 5 = you're writing a tutorial; trim.
>
> Point the executing agent at the existing code/docs they should read BEFORE touching any file. This is where you preserve judgment without writing pseudocode.

1. `path/to/file.ext` — {why this is the right pattern to mirror}
2. `path/to/spec_or_doc.md` — {what canonical knowledge lives there}
3. {External doc URL, if relevant} — {what convention to follow}

If the spec touches well-trodden code, point at the closest existing example. The agent should be able to read these 3–5 references and have enough context to plan the implementation without asking clarifying questions.

If the spec is greenfield (no existing pattern in the repo), say so explicitly and point at the architecture doc section that defines the shape.

---

## Applicable Rules

> List the rule files (and specific rule IDs where applicable) that apply to this spec's scope. The implementing agent MUST re-read these before EXECUTE and verify no violations during VERIFY. This is the spec's bridge to the project's prescriptive content — without it, the agent has no anchored prompt to consult them at the right moment.

Pick from the project's canonical rule sources. Add specific rule IDs where the spec's scope is narrower than "all of this file":

- **`docs/greptile-learnings/RULES.md`** — cross-language repo discipline (always-applicable; list specific rule IDs if the spec's scope intersects narrowly with one or two)
- **`docs/ZIG_RULES.md`** — applicable when the diff touches `*.zig`. Call out specific sections: e.g., "pg-drain lifecycle (line 14-19)", "Tagged Unions for Result Types (M4_001)", "Multi-Step Init: errdefer Chain Pattern", "Cross-Compile Verification (M22_001)"
- **`docs/REST_API_DESIGN_GUIDELINES.md`** — applicable when the diff touches `src/http/handlers/**` or `public/openapi/**`. Call out specific sections: §1 URL design, §7 route registration, §8 handler signature, etc.
- **`docs/SCHEMA_CONVENTIONS.md`** — applicable when the diff touches `schema/*.sql` or `schema/embed.zig`
- **`docs/ARCHITECTURE.md` §{N}** — applicable when the spec implements or constrains an architectural layer named in the architecture doc

If the spec's scope is fully greenfield with no project-specific rules: write "Standard set only — `docs/greptile-learnings/RULES.md` (universal); no other rule files apply."

The implementing agent reads each listed file BEFORE writing any code, and re-checks during VERIFY that nothing violates the listed rules.

---

## Overview

**Goal (testable):** One sentence that could be a test name. Bad: "Implement streaming." Good: "SSE handler streams Redis pubsub messages as text/event-stream with stable ordering and reconnection support, p95 latency under 200ms."

**Problem:** Observable symptoms. What's broken or missing? Avoid implementation language ("we don't have a foo handler") — describe the user-facing outcome ("operators can't see the zombie's tool calls in real time").

**Solution summary:** One paragraph. What changes, at what layer, what the user-visible outcome is. Resist the temptation to outline implementation steps here — that's what Sections is for.

---

## Files Changed (blast radius)

> List every file that will be created, modified, or deleted. This scopes file-length gates, orphan sweeps, and review effort.

| File | Action | Why |
|------|--------|-----|
| `path/to/file.ext` | CREATE / EDIT / DELETE | One line — what changes about this file's role |

> **Anti-pattern**: don't list line numbers or function names you'll touch — those drift. List FILES and ROLES.

---

## Sections (implementation slices)

> Each section describes WHAT one slice of the work delivers and WHY. NOT how. The "how" comes from the agent reading the prologue references and applying judgment.

### §1 — {Slice title}

What this slice delivers, in goal terms. Why it has to exist. What other slices it unblocks.

If a non-obvious decision exists in this slice, name it with **Implementation default**: `<choice>` because `<reason>`. The agent picks the default unless they have evidence to deviate.

### §2 — {Next slice}

Same shape.

> **Good section example:** "§3 — Replay idempotency. The receiver dedupes on `X-GitHub-Delivery` (the UUID GH provides). Implementation default: 24h dedupe window matching GH's retry window. Storage: a Redis key with TTL. The agent picks the key shape from existing dedupe patterns in the repo."

> **Bad section example:** "§3 — Replay idempotency. Use `redis.SET("webhook:dedupe:" + delivery_id, "1", "NX", "EX", 86400)` and check the return value." — That's pseudocode. The agent reads the existing dedupe-cache pattern in the repo and writes the call themselves.

---

## Interfaces

> Lock the contract — public functions, endpoints, data shapes that other code or callers depend on. This is the API surface the implementing agent must NOT change without spec amendment.

```
{HTTP endpoints, request/response shapes, internal API signatures}
```

Specify: input contracts, output contracts, error shapes. Use a real example payload where shape isn't self-evident.

> **Anti-pattern**: don't write the implementation. Write the contract.

---

## Failure Modes

> Enumerate every failure path the agent must handle. For each: trigger, system response, what the user/caller sees.

| Mode | Cause | Handling |
|------|-------|----------|
| {short name} | {what triggers it} | {what the system does + what the caller observes} |

Cover at minimum: timeouts, malformed input, auth failure, network blips, race conditions, replay, exceeded quotas, dependency unavailable.

---

## Invariants

> Each invariant MUST be enforceable by code (compiler, lint, comptime assertion, runtime check) — NOT by documentation or review discipline. If a human can violate it silently, it's not an invariant.

1. {Invariant} — {how it's enforced}
2. {Invariant} — {how it's enforced}

If the spec has no compile-time / runtime guardrails: write "N/A — no invariants."

---

## Test Specification

> **Prose-and-assertions only. No test code in this section.** One row per claim from the Goal. If a test's behavior is hard to describe in prose, that's a sign the Goal is fuzzy — go fix the Goal section, not this one. The implementing agent writes the actual test using the project's test framework conventions.

| Test | Asserts |
|------|---------|
| `test_<short_name>` | {one-line behavioral claim — concrete inputs and expected outputs} |

Include:
- **Happy path** tests for every claim in Overview/Goal
- **Negative tests** — every entry in Failure Modes gets a corresponding test
- **Edge case tests** — empty input, max-length input, boundary values
- **Regression tests** — pre-existing behavior that must NOT change (write "N/A — greenfield" if none)
- **Idempotency / replay tests** — if the spec has any retry or idempotency semantics

Where the input shape isn't self-evident, point at a fixture file: `samples/fixtures/m{N}-fixtures/{name}.json`. The agent reads the fixture; you don't inline the JSON in the spec body.

---

## Acceptance Criteria

> Each criterion verifiable by running a command or inspecting output. Not "works correctly" — `bun test`, `make test-integration`, `curl ... | jq`, etc.

- [ ] {Criterion} — verify: `{command}`
- [ ] {Criterion} — verify: `{command}`
- [ ] {Criterion} — verify: `{command}`

Standard set (apply when relevant; omit if not):

- [ ] `make lint` clean
- [ ] `make test` passes
- [ ] `make test-integration` passes (if HTTP/schema/Redis touched)
- [ ] `make memleak` clean (if allocator wiring touched)
- [ ] Cross-compile clean: `zig build -Dtarget=x86_64-linux && zig build -Dtarget=aarch64-linux` (if Zig touched)
- [ ] `gitleaks detect` clean
- [ ] No file over 350 lines added

---

## Eval Commands (Post-Implementation Verification)

> Executable script. Run after implementation. ALL must pass before opening a PR. Copy-pasteable into a terminal.

```bash
# E1: {short description}
{command} && echo "PASS" || echo "FAIL"

# E2: Build
{build command for the project's primary language}

# E3: Tests
{test command}

# E4: Lint
make lint 2>&1 | grep -E "✓|FAIL"

# E5: Cross-compile (Zig only — omit otherwise)
zig build -Dtarget=x86_64-linux 2>&1 | tail -3

# E6: Gitleaks — no secrets in diff
gitleaks detect 2>&1 | tail -3

# E7: 350-line gate (exempts .md files)
git diff --name-only origin/main | grep -v '\.md$' | xargs wc -l 2>/dev/null | awk '$1 > 350 { print "OVER: " $2 ": " $1 " lines (limit 350)" }'

# E8: Dead code sweep — zero orphaned references to deleted/renamed symbols
grep -rn "{old_symbol}" src/ | head -5
echo "E8: orphan sweep (empty = pass)"
```

Adapt to the spec's primary language (Zig, JS, TS, Python, Rust, Go). Omit checks that don't apply.

---

## Dead Code Sweep

> Mandatory when the spec deletes or replaces files. Two checks:

**1. Orphaned files — must be deleted from disk and git.**

| File to delete | Verify deleted |
|----------------|----------------|
| `path/to/old_file.ext` | `test ! -f path/to/old_file.ext` |

**2. Orphaned references — zero remaining imports or uses.**

For every deleted file and every removed/renamed public symbol, grep the entire repo. Any non-zero result = stale reference.

| Deleted symbol or import | Grep command | Expected |
|--------------------------|--------------|----------|
| `old_symbol` | `grep -rn "old_symbol" src/ \| head` | 0 matches |

If the spec does not delete files: write "N/A — no files deleted."

---

## Skill-Driven Review Chain (mandatory)

> Three skills gate the lifecycle from implementation-complete to PR-merged. They run in order; each one's output is recorded in the Ripley's Log.

| When | Skill | What it does | Required output |
|------|-------|--------------|-----------------|
| After implementation, before CHORE(close) | `/write-unit-test` | Audits test coverage of the diff against this spec's Test Specification. Catches happy-path-only tests, missing negatives, fixture drift. | Skill returns clean. Iteration count + final coverage summary in Ripley's Log. |
| After tests pass, still before CHORE(close) | `/review` | Adversarial diff review against this spec, `docs/ARCHITECTURE.md`, `docs/REST_API_DESIGN_GUIDELINES.md` (if HTTP-touching), `docs/ZIG_RULES.md` (if Zig-touching), Failure Modes, Invariants. | Skill returns clean OR every finding dispositioned (fixed / deferred with reason / rejected with reason). Recorded in Ripley's Log. |
| After `gh pr create` opens the PR | `/review-pr` | Review-comments the open PR against the now-immutable diff. Catches anything the local `/review` missed (squashed commits, race conditions visible only post-rebase, OpenAPI codegen drift). | Comments addressed inline (fixup or amend) BEFORE requesting human review or merging. |

These are not optional. Skipping any one violates CHORE(close). If a skill is unavailable (MCP server down, etc.), document the skip explicitly in the Ripley's Log AND in the PR description with a timestamp and a "rerun before merge" note.

The skill chain is the bridge between this spec's intent and the implementation's actual behavior. The spec describes what should be true; the skills verify it is.

---

## Verification Evidence

> Filled in during VERIFY phase. Proves spec claims are met.

| Check | Command | Result | Pass? |
|-------|---------|--------|-------|
| Unit tests | `make test` | {paste output snippet} | |
| Integration tests | `make test-integration` | {paste output snippet} | |
| Lint | `make lint` | {paste output snippet} | |
| Cross-compile (Zig) | `zig build -Dtarget=x86_64-linux` | {paste output snippet} | |
| Gitleaks | `gitleaks detect` | {paste output snippet} | |
| 350L gate | `wc -l` | {paste output snippet} | |
| Dead code sweep | `grep -rn {symbol} src/` | {paste output snippet} | |

---

## Out of Scope

- {Item explicitly not in this spec — points at follow-up spec or "future work"}
- {Item}
