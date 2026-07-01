---
name: kishore-spec-new
description: |
  Author a milestone/workstream specification the executing agent (Orly) can
  ship into a deterministic, review-clean (no greptile findings), and reported
  Pull Request. Leads with intent capture and review-readiness — not file
  mechanics. Use when the user says "create a spec", "new milestone",
  "start M{N}_{NNN}", "spec out X", or attempts a TODO.md (forbidden in this
  project — every non-trivial intent becomes a spec instead).

  Cross-agent: works for Claude, Codex, OpenCode, Amp. Self-contained
  markdown — no agent-specific tool invocations.
---

# kishore-spec-new

A spec is the **rulebook** the executing agent (Orly) plans and ships from. This
skill makes me author one whose Pull Request (PR) lands **deterministic, review-clean, and
reported** — without a 20-questions loop. It is written for my reasoning, not as
a file-naming guide: the mechanics (naming, layout) are demoted to the end
because they are the easy part.

> **The trio stays coherent.** This skill (*how to author*) ← `docs/TEMPLATE.md`
> (*the section shape*) → `audits/spec-template.sh` (*the enforcer*). If a
> step here demands something, the template carries the section and the audit
> asserts it. Drift between the three is a bug.

A spec is an *instance*; `AGENTS.md` and `docs/greptile-learnings/RULES.md` are
the *constants*. When the spec contradicts a rule, amend the spec — never weaken
the rule.

## What a good spec guarantees

The three outcomes every step below serves:

- **Deterministic / invariant** — the agent plans and builds with no `[?]`; every claim is a test; every invariant is enforced by code, not review discipline.
- **Review-clean** — the code it produces trips no greptile finding, because the spec pre-commits to the exact `RULES.md` rule IDs and gates the diff touches.
- **Reported** — Discovery (consult log), Verification Evidence, and skill-chain outcomes are populated as the work proceeds.

## Triggers

- User says: "create a spec", "spec this out", "new milestone", "draft M{N}_{NNN}", "start on M{N}", "track this as a milestone".
- The user attempts a `TODO.md` or any ad-hoc task list — convert it into a spec. **`TODO.md` is forbidden.**
- A `plan-eng-review` / `plan-ceo-review` / `plan-design-review` produced a plan that should be tracked durably.

---

## Step 1 — Capture intent (the hard part — do it before any file)

Determinism starts here. Before copying the template:

- **Testable goal** — one sentence that could be a test name. "Implement streaming" is not a goal; "SSE handler streams pubsub as `text/event-stream`, p95 < 200ms" is.
- **PR title + intent** — what the merged PR is called (imperative, ≤72 chars) and the one-sentence user-facing *why*.
- **Comprehension handshake** — restate the intent in my own words and list `ASSUMPTIONS I'M MAKING: …`. If my restatement and the requester's ask diverge, STOP and reconcile before drafting.
- **Golden-path walk** — trace the concrete end-to-end (every lookup, data source, secret store). Any `[?]` left in the walk blocks the spec from leaving `pending/`.

→ Fills the template's **PR Intent & comprehension handshake** and **Overview**.

## Step 2 — Lock review-readiness (so the PR ships clean)

This is the step that prevents greptile findings — the spec becomes a pre-commitment to the rules its code must obey:

- **Applicable Rules** — name the *specific* `docs/greptile-learnings/RULES.md` rule IDs the diff will trip (e.g. NDC, NLR, NLG, UFS), plus the per-surface dispatch façades / rule files: `dispatch/write_zig.md` (`*.zig`), `REST_API_DESIGN_GUIDELINES.md` (`src/http/handlers/**`), `SCHEMA_CONVENTIONS.md` (`schema/*`), `dispatch/write_ts_adhere_bun.md`, `LOGGING_STANDARD.md`, `LIFECYCLE_PATTERNS.md`. Generic "follow RULES.md" earns a greptile finding; named IDs the implementer obeys by construction do not.
- **Applicable Gates** — which Action-Triggered Guards fire (ZIG, PUB, LENGTH, UFS, UI, DESIGN TOKEN, LOGGING, LIFECYCLE, SCHEMA, ERROR REGISTRY) and the satisfaction strategy for each. Rules ≠ gates: rules are knowledge to read; gates fire on edits.
- **Prior-Art / Reference Implementations** — the reference codebase to mirror (CLI → the "7 Pillars" of CLI DX in `docs/TEMPLATE.md` Prior-Art; API → REST guide + nearest handler). No reinventing what a known-good pattern already solves.

→ Fills **Applicable Rules**, **Applicable Gates**, **Prior-Art / Reference Implementations**.

## Step 3 — Make it provable & reported

- Decompose **Sections** into numbered **Dimensions** (3.1, 3.2 …) — the unit of DONE. **Every Dimension → one Test** (tiered: unit/integration/e2e per `/write-unit-test`; any user-facing Category gets a user-centric `test-e2e*` scenario).
- **Every Failure Mode → a negative test.** **Every Invariant → enforced by code** (compiler, lint, comptime assertion, runtime check) — never by review discipline.
- **Every Metrics row → event/test proof.** User-facing or operator-facing specs declare product/operator signals, privacy guards, and analytics/funnel playbook updates; internal-only cleanup explicitly says no signal changed.
- **Reporting spine** — **Discovery (consult log)** carries consults, skill-chain outcomes, and Indy-acked deferral quotes; **Verification Evidence** carries the VERIFY paste-outs. Both empty at creation, populated as work proceeds.

→ Fills **Sections (+ Dimensions)**, **Metrics & Observability**, **Failure Modes**, **Invariants**, **Test Specification (tiered)**, **Acceptance Criteria**, **Discovery**, **Verification Evidence**.

## Step 4 — Mechanics (the easy part)

Now the file. Pick the ID and copy the template:

```bash
# next free M{N}_{WS}
ls docs/v*/pending/ docs/v*/active/ docs/v*/done/ 2>/dev/null \
  | grep -oE 'M[0-9]+_[0-9]+' | sort -u | tail -5
cp docs/TEMPLATE.md docs/v{N}/pending/M{N}_{WS}_P{P}_{CATEGORIES}_{NAME}.md
```

If `docs/TEMPLATE.md` is missing in this repo, fall back to `~/Projects/dotfiles/docs/TEMPLATE.md`.

**Inputs** — Milestone `M{N}` (next free, sortable) · Workstream `{WS}` zero-padded (`001`…) · Priority (**P0** blocking · **P1** customer/operator-facing · **P2** tooling · **P3** deferrable) · Category set alphabetised (`API` Zig/Go · `CLI` agentsfleet/Node · `UI` Next.js · `OBS` Grafana · `SKILL` SKILL.md · `INFRA` Terraform) · Name UPPER_SNAKE_CASE ≤6 words describing the outcome (`BUN_VENDOR_UTILITIES`, not `BUMP_BUN_DEPS`) · Prototype tag (`v1.0.0`, `v2.0.0` — drives `docs/v1/` vs `docs/v2/`).

**File naming:** `docs/v{N}/{pending|active|done}/M{Milestone}_{Workstream}_P{Priority}_{CATEGORIES}_{NAME}.md` (e.g. `docs/v2/pending/M52_001_P2_API_BUN_VENDOR_UTILITIES.md`). Do NOT rename existing legacy-form files under `docs/v1/` or `docs/v2/done/`.

**Terminology — binding for everything that lands in a file** (conversational replies are exempt):

| Use | Do NOT use |
|---|---|
| Prototype (v1.0.0) | Release, Version train, Program |
| Milestone (M{N}) | Sprint, Phase, Quarter |
| Workstream (M{N}_{WS}) | Ticket, Task, Story, Issue |
| Section (§3) | Phase, Step, Chapter |
| Dimension (3.4) | Acceptance criterion, AC, Checkbox |
| Batch (B2) | Wave, Tranche, Iteration |

**Directory movement** is lifecycle-driven: created → `pending/` (`Status: PENDING`); begin implementation → `active/` (CHORE(open)); all Dimensions DONE + PR opened → `done/`; parked → stay in `active/`.

## Step 5 — Self-review gate, then commit

Before the spec leaves `pending/`, it must pass this checklist — the deterministic/invariant guarantee:

- [ ] intent handshake done; golden-path walk has **no `[?]`**
- [ ] **Applicable Rules names specific greptile rule IDs**; Applicable Gates populated with satisfaction strategy
- [ ] **Metrics & Observability declares events or explicitly says no product/operator signal changed**; any analytics/funnel playbook update is listed
- [ ] **every Dimension has a Test**; **every Failure Mode has a negative test**; every Invariant is code-enforceable
- [ ] Prior-Art reference named (or "greenfield — shape in `docs/architecture/`")
- [ ] reporting sections present (Discovery, Verification Evidence)
- [ ] `bash audits/spec-template.sh --staged` is clean (it BLOCKs missing required sections and unfilled `{placeholders}`)

Then commit in the current authoring context:

- If the skill is running inside an existing branch/worktree, author and commit the spec there.
- If there is no branch/worktree context, use the repo's `main` branch as the fallback.

```bash
git add docs/v{N}/pending/M{N}_{WS}_*_{NAME}.md
git commit -m "docs(m{N}): add spec — {short title}"
```

The spec lands in `pending/` on the branch/worktree where the skill was invoked. CHORE(open) moves it to `active/` and creates any needed worktree — handled by the lifecycle, not this skill.

---

## What this skill does NOT do

- It does **not** start coding, create a worktree, or move the spec to `active/`. That's CHORE(open), when implementation begins.
- It does **not** modify any rule file, ARCHITECTURE doc, or changelog.
- It does **not** create a branch just to author a spec. Spec creation uses the current branch/worktree, falling back to `main` only when no branch/worktree exists.

## Failure modes

| Surface | What you do |
|---|---|
| User insists on `TODO.md` | Decline. Convert the intent into a spec via this skill. |
| Spec name collides with a `done/` entry | Pick the next workstream number; never reuse. |
| Spec depends on something still in `pending/` | Allowed — list it in `Depends on:` and surface it. |
| Spec proposes work that violates a rule | Amend the spec text or scope before committing. Rules are the constants. |
| Can't write the goal as a test name | Intent is not understood yet — go back to Step 1; do not draft sections. |

## References

- `docs/TEMPLATE.md` — the section shape this skill fills (per-repo copy; fallback `~/Projects/dotfiles/docs/TEMPLATE.md`).
- `audits/spec-template.sh` — the enforcer (`--staged` BLOCKs an incomplete spec).
- `docs/greptile-learnings/RULES.md` — the rule IDs Step 2 pins for review-cleanliness.
- `~/Projects/dotfiles/AGENTS.md` — lifecycle stages, action-triggered guards, deterministic VERIFY/CHORE sequencing.
