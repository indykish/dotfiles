# 🚧 DESIGN TOKEN GATE

**Family:** Frontend design-system discipline (paired with the UI Component Substitution Gate). **Source:** `AGENTS.md` (project-side guard). Authoritative token surface: `ui/packages/design-system/src/theme.css` (Layer-2 `@theme inline`).

**Triggers** — every `Edit`/`Write` to `*.tsx` / `*.jsx` under `ui/packages/app/` **or** `ui/packages/website/`. Tests (`*.test.tsx`) and Playwright specs (`tests/e2e/**`) are exempt — they assert on rendered DOM and frequently use raw selectors.

**Override:** `// DESIGN TOKEN: SKIPPED per user override (reason: ...)` immediately preceding the affected line. Reasons must cite a concrete constraint — "bespoke per-surface grid template", "tight UI chrome width with no equivalent token", "external library prop expects px-string" — not "looks the same" / "shorter to write". Auto-mode does NOT cover the override.

## What this gate enforces

The design-system package exposes named Tailwind utilities for every typographic and layout primitive (`text-display-xl`, `text-eyebrow`, `leading-prose`, `max-w-narrow`, `tracking-display-md`, `duration-snap`, etc.). Raw arbitrary values bypass the published scale. Over time that drift dilutes the system; the moment one surface ships `text-[14px] leading-[1.6]`, others copy the pattern.

This gate blocks arbitrary classes **when an equivalent token utility exists**. It does NOT block:

- Tailwind state selectors (`data-[active=true]:bg-accent`)
- Pseudo-element `content-[...]`
- Bespoke `grid-cols-[...]` / `grid-rows-[...]` (per-surface templates)
- `calc(...)` expressions that consume a token (`h-[calc(100vh-var(--header-height))]`)
- Token-using shadows (`shadow-[0_0_0_3px_var(--pulse-glow)]`)

## Pre-edit check

1. Read (or recall) `ui/packages/design-system/src/theme.css` — the Layer-2 `@theme inline { ... }` block is the authoritative utility surface.

2. The available token utilities are exactly the bridged names:

   | Family | Utilities |
   |---|---|
   | Text size | `text-{label,eyebrow,body-sm,body,body-lg,heading,display-md,display-lg,display-xl}` |
   | Fluid text | `text-fluid-{display-md,display-lg,hero}` |
   | Tracking | `tracking-{display-xl,display-lg,display-md,eyebrow,label}` |
   | Line-height | `leading-{display-xl,display-lg,display-md,heading,eyebrow,body-lg,body,body-sm,label,mono,prose}` |
   | Max width | `max-w-{trim,narrow,measure,form,wide,content,tagline,prose}` |
   | Min width | `min-w-{trim,narrow,measure,form,wide,content,tagline,prose}` |
   | Spacing | `{p,m,gap,space-{x,y}}-{xs,sm,md,lg,xl,2xl,3xl,4xl,5xl,6xl}` |
   | Motion | `duration-snap`, `ease-snap` |
   | Radius | `rounded-{sm,md,lg}` |
   | Color | semantic tokens only — `bg-{background,card,popover,primary,secondary,muted,accent,destructive,…}`, `text-{foreground,muted-foreground,text,text-muted,text-subtle,…}`, `border-{border,border-strong,input,ring}`, status tokens `text-{success,warn,error,info,evidence}` / `text-on-pulse` |

3. For every arbitrary `*-[...]` class your edit adds, ask: **does a token utility exist?**
   - If yes, use it.
   - If no, the arbitrary is allowed without an override comment.
   - If close but not exact, prefer the token. The system absorbs ±1–2 px differences; over hundreds of callsites the consistency dominates the per-callsite shift.

## Required output (default — one line)

```
DESIGN TOKEN GATE: <file> | arbitraries-kept: <list with one-word reason each | none>
```

Multi-line block fires only when `arbitraries-kept` is non-empty:

```
DESIGN TOKEN GATE: <file>
  Arbitraries kept:
    - <class>: <reason>  (e.g. "grid-cols-[2fr_1fr_1fr_1fr]: bespoke footer grid")
    - <class>: <reason>
    ...
```

## Scope (M70)

`audit-design-tokens.sh` walks the **full ui/packages working tree** via `git ls-files`. The index includes staged-but-not-yet-committed content, so a fix staged in pre-commit satisfies the check on the same hook run. The previous `--diff` (`BASE...HEAD`) default was retired with M70 — at pre-commit time `HEAD` is the prior commit, leaving the gate blind to the index.

`--all` is accepted as a back-compat alias for the default. `--staged` is preserved as an opt-in narrowing mode for iterative dev loops. `--diff` is rejected with exit 2 + a pointer to this section.

## Self-audit (end-of-turn)

```bash
scripts/audit-design-tokens.sh           # full-codebase scan (default)
scripts/audit-design-tokens.sh --staged  # opt-in narrowing for iterative dev
```

The script lives in the project repo at `scripts/audit-design-tokens.sh` (symlinked from `~/Projects/dotfiles/scripts/`). It prints `file:line` + suggested token utility for every blocking violation and exits 1 on any.

A clean run is required before HARNESS VERIFY can advance.

The project repo is also expected to wire the audit into `make/quality.mk` `_website_lint` and `_app_lint` targets so `make lint` catches regressions:

```make
_website_lint:
	@echo "→ [website] Running Oxlint + TypeScript check..."
	@cd ui/packages/website && bun run lint
	@cd ui/packages/website && bun run typecheck
	@echo "→ [website] Running design-token audit..."
	@scripts/audit-design-tokens.sh
	@echo "✓ [website] Lint passed"
```

## Family rules

This gate composes with the UI Component Substitution Gate. Order of operations on a fresh `.tsx` edit:

1. **UI GATE** — pick the primitive (`<Card>`, `<Section>`, `<Button>`, `<DisplayXL>`, …)
2. **DESIGN TOKEN GATE** — pick the token utility (`text-body`, `leading-body`, `max-w-narrow`)
3. **UFS GATE** — pick a named const for any repeated string literal
4. **LENGTH GATE** — keep the file ≤350 lines

A `.tsx` that passes all four reads as system-conformant without spelunking into the design-system source.

## Why a gate, not a lint rule

Three reasons:

1. **Cross-package coupling.** The token set lives in `ui/packages/design-system`; the consumers live in `ui/packages/{app,website}`. A single oxlint config can't see across the boundary cleanly. The audit script reads the diff and the theme.css utilities — it's the right shape.

2. **Inline override.** Some `-[...]` classes are intentional and irreplaceable (bespoke grids, `calc(...)`, status-dot sizes). The comment-based override fits the existing gate idiom and gives reviewers a paper trail of *why* each arbitrary stayed.

3. **HARNESS VERIFY integration.** Gates are the canonical end-of-turn audit point. Lint rules surface in editor noise but miss the agentic lifecycle. The gate's pre-edit one-liner + end-of-turn self-audit puts the discipline in the model's hot path.

## When tokens are missing

If the arbitrary you want is a legitimate design value that simply has no token yet, **extend the design system in the same commit**:

1. Add `--<family>-<name>` to `ui/packages/design-system/src/tokens.css`
2. Forward to Tailwind via `@theme inline` in `ui/packages/design-system/src/theme.css`
3. Migrate your callsite to the new utility
4. Add the utility to the table above in this gate body (same dotfiles commit — Invariance Suite Gate applies)

This is the path to a system that grows without dilution.
