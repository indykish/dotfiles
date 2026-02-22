---
name: oracle
description: Get a second-model review for debugging, refactors, design checks, or cross-validation. Primary path is inline (in-session) using CTO or Engineer lens. Secondary path uses the @indykish/oracle CLI for bundled one-shot reviews with a separate model.
---

# Oracle — Second-Model Review

A "second-model review" means bringing a fresh analytical lens to work already in progress. Two modes: **Oracle** (strategic) and **Engineer** (tactical). Primary path is inline — no CLI, no API cost, no install required.

---

## Primary path — Inline review (in-session)

Ask the current agent to review inline. Pick the lens based on what you need.

---

### Oracle or CTO Lens (strategic review)

**When to use:** Architecture decisions, trade-off analysis, migration planning, risk/cost assessment.

**How:** Say *"Oracle review: [question]"* or *"CTO review: [question]"* — agent applies this lens when the question involves trade-offs, architecture, or risk.

**What to expect:**
1. Confirm understanding (1–2 sentences).
2. High-level options first — not implementation detail.
3. Options with pros/cons, not just a recommendation.
4. Risks flagged explicitly: security, performance, maintainability, cost.
5. Concise — ~400 words unless deep dive is requested.

**CTO push-back triggers** (reviewer must flag these):

| Issue | Example |
|---|---|
| Security | OWASP Top 10 vulnerability introduced |
| Architecture | Violates system boundaries or creates circular dependencies |
| Technical Debt | Blocks future work or requires significant refactoring later |
| Breaking Change | Lacks migration path for existing users/data |
| Premature Optimization | Performance work without profiling data |
| Cost | Infrastructure cost exceeds business value |

If overridden after push-back: execute the decision and document the risk.

---

### Engineer Lens (tactical review)

**When to use:** Implementation review, correctness check, consistency pass, pre-PR review.

**How:** Say *"Oracle review: [what to check]"* — agent applies this lens when the question involves correctness, implementation, or consistency. Explicitly say *"Engineer review"* if you want to force this lens over CTO.

**Behaviors the reviewer must apply:**

**1. Assumption surfacing (critical)**

Before flagging anything non-trivial, state assumptions explicitly:

```
ASSUMPTIONS I'M MAKING:
1. [assumption]
2. [assumption]
→ Correct me now or I'll proceed with these.
```

Never silently fill in ambiguous requirements.

**2. Confusion management (critical)**

When encountering inconsistencies or conflicting requirements:
1. STOP — do not guess.
2. Name the specific confusion.
3. Present the tradeoff or ask the clarifying question.
4. Wait for resolution.

```
❌ Bad: picking one interpretation and hoping it's right
✅ Good: "I see X in file A but Y in file B. Which takes precedence?"
```

**3. Simplicity enforcement**

Before finishing: ask yourself — can this be done in fewer lines? Are abstractions earning their complexity? Would a senior dev say "why didn't you just…"?

**4. Scope discipline**

Touch only what was asked. Flag — do not silently fix — issues outside scope.

**5. Dead code hygiene**

After reviewing refactors: identify now-unreachable code, list it explicitly, ask before removing.

**Engineer review response template:**

```
CHANGES REVIEWED:
- [file]: [what was checked and finding]

THINGS I DIDN'T EVALUATE:
- [file]: [intentionally skipped because...]

POTENTIAL CONCERNS:
- [risk, inconsistency, or missing step]

ASSUMPTIONS I MADE:
- [any assumptions that affected the review]
```

---

## Decision rubric (inline vs CLI)

| Situation | Use |
|---|---|
| Quick pre-PR review of <10 files in context | *"Oracle review: …"* → agent picks Engineer lens |
| Architecture decision or trade-off needed | *"Oracle review: …"* or *"CTO review: …"* → agent picks CTO lens |
| Need a fresh model with zero session bias | oracle CLI (secondary) |
| API keys not configured or spend undesirable | Inline or `--render --copy` paste |
| Need deterministic multi-file bundle for archival | oracle CLI |
| Cross-model parallel check | oracle CLI `--models` |

---

## Review Severity Levels

Every finding must be classified. No ungraded feedback.

| Level | Label | Meaning |
|---|---|---|
| 🔴 | **BLOCKER** | Correctness failure, security risk, or data loss. Must fix before merge. |
| 🟠 | **MAJOR** | Architectural misalignment, broken reference, or missing required step. Fix before merge. |
| 🟡 | **MINOR** | Improvement that reduces risk or drift. Fix recommended but not blocking. |
| ⚪ | **NIT** | Stylistic or cosmetic. Optional. |

Format findings as:
```
🔴 BLOCKER — [file:line] — [what is wrong and why it must be fixed]
🟠 MAJOR   — [file:line] — [what is misaligned and impact]
🟡 MINOR   — [file:line] — [what could be improved]
⚪ NIT      — [file:line] — [optional polish]
```

---

## Failure modes to avoid (reviewer checklist)

1. Making wrong assumptions without surfacing them.
2. Not naming confusion — guessing instead of asking.
3. Not presenting trade-offs on non-obvious decisions.
4. Not pushing back when a push-back trigger is hit.
5. Being sycophantic ("Of course!" to bad ideas).
6. Overcomplicating — flagging complexity that wasn't there.
7. Scope creep — reviewing things not in scope without flagging it.
8. Removing things not fully understood without asking.

---

## Secondary path — `@indykish/oracle` CLI (optional)

Use when you need a bundled one-shot review with a **separate model** and full file context outside the current session — or when session bias is a concern.

> **Status:** Secondary reviewer approach is under active review. Use inline path above until CLI is confirmed working in your environment.

### Installation

```bash
# Use without installing (npx pulls latest)
npx @indykish/oracle --help

# Install globally for persistent use
npm install -g @indykish/oracle

# Verify
oracle --version   # should show 0.9.2
```

### Supported models (Oracle 0.9.2)

| CLI alias         | Engine  | Notes                              |
|-------------------|---------|------------------------------------|
| claude-4.6-sonnet | api     | **Default**. Requires ANTHROPIC_API_KEY. |
| claude-4.6-opus  | api     | Escalation. Deep reasoning.        |
| claude-4.5-sonnet | api     | Previous Claude generation.        |
| claude-4.1-opus  | api     | Previous Claude Opus.              |
| gpt-5.3-pro      | api     | Deep reasoning.                    |
| gpt-5.3          | api     | Faster GPT variant.                |
| gpt-5.2-pro      | api     | Previous GPT Pro generation.       |
| gemini-3.5-pro   | api     | Latest Gemini generation.          |
| grok-4.2         | api     | Latest xAI generation.             |

### Commands

```bash
# Dry-run (check token count, no spend)
npx @indykish/oracle --dry-run summary -p "<task>" --file "src/**"

# API review (requires ANTHROPIC_API_KEY)
npx @indykish/oracle --engine api --model claude-4.6-sonnet -p "<task>" --file "src/**"

# Escalation
npx @indykish/oracle --engine api --model claude-4.6-opus -p "<task>" --file "src/**"

# Manual paste fallback (no API key needed)
npx @indykish/oracle --render --copy -p "<task>" --file "src/**"
# → copies bundle to clipboard → paste into Claude/ChatGPT/Gemini → paste response back here
```

### Cost guardrail

- **Before any paid API run, get explicit user approval in-thread.**
- Approval line: `Approve Oracle API run: model=<model>, scope=<files>, reason=<why>`
- If no approval: stop at `--dry-run` or use `--render --copy`.

### Attaching files (`--file`)

- `--file "src/**"` — glob
- `--file src/index.ts` — literal file
- `--file "src/**" --file "!**/*.test.ts"` — with excludes
- Default-ignored: `node_modules`, `dist`, `.git`, `build`, `tmp`
- Hard cap: files > 1 MB are rejected.

### Sessions

- Stored under `~/.oracle/sessions`.
- If a run detaches: `npx @indykish/oracle session <id> --render` to reattach.
- Use `--slug "<3-5 words>"` for readable session IDs.

---

## Safety

- Never attach secrets (`.env`, key files, tokens).
- Fewer files + better prompt beats whole-repo dumps.

## Optional: Open files in Zed

```bash
open -a Zed /path/to/file
```
