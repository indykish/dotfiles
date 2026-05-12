# Code / Audit Review Template

> ⚠️ **This is a REVIEW, not a spec. Do not implement directly.**
> Reviews surface many findings. **Each actionable finding becomes its own spec** — don't bundle multiple findings into one spec. To act on a finding, run `/kishore-spec-new` and reference the review row.

Use this template when you've audited existing code or infrastructure and need to capture findings. Lives in `plans/reviews/{topic}_{YYYY_MM_DD}.md`.

**When to use this vs `TEMPLATE.md`:**
- Review — many findings about existing code. Inventory + triage. NOT executable.
- Spec — one executable plan, one outcome.

A review becomes N specs over time as findings are picked up.

---

# {Topic} Review — {YYYY-MM-DD}

**Reviewer:** {name or agent ID}
**Date:** {MMM DD, YYYY}
**Provenance:** human-written | LLM-drafted ({model}, {date}) | agent-generated
**Scope:** {what was reviewed — repo, module, PR, system}
**Methodology:** {how — read codebase, ran benchmarks, security scan, manual exploration}

---

## Findings

> Each finding is a row. Severity drives priority; status tracks conversion to spec or rejection.

| ID | Finding | Severity | Status | Spec |
|---|---|---|---|---|
| F-001 | {one-line description} | P0 / P1 / P2 / Note | OPEN / SPEC'D / REJECTED / OUT_OF_SCOPE | {link to spec, or empty} |

**Severity guide:**
- **P0** — security, correctness, data loss. Must spec before next release.
- **P1** — significant friction, missing capability, or maintainability issue. Spec when capacity allows.
- **P2** — nice-to-have, polish, doc improvement.
- **Note** — observation worth recording; not actionable on its own.

**Status guide:**
- **OPEN** — no spec yet. Default state.
- **SPEC'D** — converted; link the spec in the right column.
- **REJECTED** — reviewed and decided not to act. Add a one-line reason in the finding description.
- **OUT_OF_SCOPE** — belongs to a different system / team / release. Add pointer.

---

## Finding Details

> Expand each row that needs more than a one-liner. Most P0/P1 findings need this section; P2 / Note often don't.

### F-001 — {Finding name}

**Observed:** {what you saw — specific files, behavior, output}
**Impact:** {who hits this, in what conditions, how bad}
**Suggested direction:** {one paragraph — what a fix would look like at the highest level}
**Pointers for the spec author:** {files, prior art, related rules in `docs/`}

> **Do NOT write implementation pseudocode here.** The spec author writes the spec; this section just hands them the inputs they need.

---

## Strengths Observed

> Not just for politeness — capture what's working well so the eventual spec author doesn't accidentally remove it. Two or three bullets is plenty.

- {What's working}
- {What's working}

---

## Out of Scope

> What was NOT reviewed, and why. Prevents "oh you missed X" — you didn't miss it, you scoped it out.

- {Area} — {reason}

---

## Recommended Next Actions

> What should happen with this review, in order. Usually: pick P0s, run `/kishore-spec-new` for each.

1. **For each P0 finding:** create a spec via `/kishore-spec-new`. Link the spec in the Status column.
2. **For each P1 finding:** triage at next planning checkpoint. Spec when capacity allows.
3. **For each P2 finding:** convert to a GitHub issue with the `polish` label, or roll into a future cleanup spec.
4. **For Notes:** no action needed; review the list during the next audit cycle.

---

## Conversion Tracking

> Update as findings are spec'd. The review is "closed" when every P0 and P1 has either a spec or a REJECTED row.

| Finding | Spec | Notes |
|---|---|---|
| F-001 | `docs/v{N}/pending/M{N}_{NNN}_{NAME}.md` | {short status} |
