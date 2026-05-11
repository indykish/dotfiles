# 🚧 UI Component Substitution Gate

**Family:** Frontend design-system discipline. **Source:** `AGENTS.md` (project-side guard). Authoritative primitive set: `ui/packages/design-system/src/index.ts`.

**Triggers** — every `Edit`/`Write` to a `*.tsx` / `*.jsx` under `ui/packages/app/` **or** `ui/packages/website/`. Both packages share the same design-system source of truth (`@usezombie/design-system`), so the same primitive-first standard applies. Tests (`*.test.tsx`) and Playwright specs (`tests/e2e/**`) are exempt — they assert on rendered DOM and frequently use raw selectors.

**Override:** `UI GATE: SKIPPED per user override (reason: ...)` immediately preceding the edit.

## What this gate enforces

The design-system package (`ui/packages/design-system/src/index.ts` exports — `Section`, `Card`, `Badge`, `Button`, `Input`, `Dialog`, `Pagination`, `EmptyState`, `Tooltip`, `List`/`ListItem`, `WakePulse`, `Terminal`, `InstallBlock`, etc.) is the source of truth for visual primitives. Raw HTML in either dashboard or marketing files drifts from those tokens silently.

**Marketing-display typography — primitives now exist.** `<DisplayXL>` (marketing hero `<h1>`, `text-fluid-hero`) and `<DisplayLG>` (section heads `<h2>`, `text-fluid-display-lg`) ship from `@usezombie/design-system` and compose `font-mono` + the fluid text/leading/tracking tokens internally. Use them on marketing-display surfaces. Raw `<h1>+utilities` is no longer the carve-out — UI GATE blocks it. The dashboard's `<PageTitle>` (`text-heading ≈ 18px`) remains the correct primitive for app surfaces.

This gate enforces "use the primitive when one exists" without enumerating the primitives in this rule (so the rule scales as the design-system grows).

## Pre-edit check

1. Read (or recall) the design-system index. Treat its exports as the substitute set.
2. For each raw HTML element your edit adds (`<section>`, `<button>`, `<input>`, `<article>`, `<dialog>`, `<dl>`, `<table>`, `<nav>`, `<header>`, `<form>`, etc.), check the index for a matching primitive. If one exists, use it.
3. Use `asChild` when you need the underlying HTML tag for semantics:

   ```tsx
   <Section asChild>
     <section aria-label="...">…</section>
   </Section>
   ```

## Required output (default — one line)

```
UI GATE: <file> | primitives:<list> | raw-kept:<list with one-word reason each | none>
```

Multi-line block fires only when raw-kept is non-empty:

```
UI GATE: <file>
  Primitives used: <list>
  Raw HTML kept:
    - <element>: <reason>  (e.g. "ul: no DS primitive")
    - ...
```

## Self-audit (end-of-turn)

```bash
git diff -U0 HEAD -- 'ui/packages/app/**/*.tsx' 'ui/packages/website/src/**/*.tsx' \
  | grep -v -E '\.test\.tsx|tests/e2e/' \
  | grep -E '^\+.*<(section|button|input|dialog|article|nav|header|form)\b' \
  | head
```

Non-empty is a violation unless every match has a printed "Raw HTML kept" justification in the corresponding gate block.
