# Design Proposal Template

> ⚠️ **This is a PROPOSAL, not a spec. Do not implement directly.**
> To act on this, run `/kishore-spec-new` and reference this proposal as input. The spec is the executable plan; the proposal is the design rationale.

Use this template when you're exploring a design before committing to scope. Lives in `plans/proposals/{topic}.md`.

**When to use this vs `TEMPLATE.md`:**
- Proposal — "should we do this, and what shape would it take?" Multiple options on the table; trade-offs unresolved.
- Spec — "we're doing this, here's the goal-contract." One plan, executable.

A proposal becomes one or more specs once you've picked a direction.

---

# {Title}

**Author:** {your name}
**Date:** {MMM DD, YYYY}
**Provenance:** human-written | LLM-drafted ({model}, {date})
**Status:** EXPLORING | RECOMMENDED | ADOPTED ({link to spec}) | REJECTED ({one-line reason})

---

## Problem Statement

What's broken or missing today? Observable symptoms only — describe the user-facing outcome, not "we don't have a foo handler."

## Goals

What this proposal aims to achieve. Bulleted, concrete.

## Non-Goals

What this proposal explicitly does NOT cover. Critical for scoping the eventual spec.

---

## Options Considered

> A proposal MUST present at least 2 options. If there's only one option, you're writing a spec, not a proposal — use `TEMPLATE.md` instead.

### Option A — {short name}

**Sketch:** one paragraph. What changes, at what layer.

**Pros:**
- {concrete benefit}

**Cons:**
- {concrete cost or risk}

### Option B — {short name}

Same shape.

### Option C — Do nothing

What happens if we don't act. Always include this option — it's the baseline.

---

## Recommendation

Which option, and why. One paragraph. The agent or human reading this should know exactly what to spec next.

---

## Open Questions

> Things you don't know yet that block writing the spec. Each question must have a way to resolve it (prototype, benchmark, ask user, read spec X).

1. {Question} — {how to resolve}
2. {Question} — {how to resolve}

If all questions are resolved, the proposal is ready to be specced. Open `TEMPLATE.md` and write the spec.

---

## References

- {Prior art — internal specs, external RFCs, library docs}
- {Code locations relevant to the proposal — agent reads these when speccing}

---

## Conversion to Spec

When this proposal is adopted, link the resulting spec(s) here:

- `docs/v{N}/pending/M{N}_{NNN}_{NAME}.md` — covers {scope}

If the proposal spawns more than one spec (common for cross-cutting work), list each.
