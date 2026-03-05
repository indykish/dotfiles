# Website Frontend Scaffold Template

## Required Structure

```text
.
├── src/
│   ├── components/
│   ├── pages/          (or routes/)
│   ├── styles.css      (Tailwind v4 entry: @import "tailwindcss")
│   └── main.tsx
├── tests/
│   └── e2e/
│       └── smoke.spec.ts
├── Makefile            (delegates to make/ targets)
├── make/
│   ├── quality.mk      (lint target)
│   └── test.mk         (test, qa, qa-smoke targets)
├── vite.config.ts
├── package.json
└── README.md
```

## Stack

- React 19+ + TypeScript
- Vite 7+ with `@tailwindcss/vite` plugin (no PostCSS, no `tailwind.config.ts`)
- TailwindCSS v4 — CSS-first (`@import "tailwindcss"`)
- CSS custom properties for brand tokens
- Vitest 4+ with jsdom environment for unit tests
- Playwright 1.58+ for e2e (chromium headless only)
- Form validation: React Hook Form + Zod

## Standard Make Targets

```makefile
make dev          # bun run dev
make lint         # bun run lint && bun run typecheck
make test         # bun run test (vitest)
make build        # bun run build
make qa           # bun run test:e2e (Playwright full suite)
make qa-smoke     # bun run test:e2e:smoke (CI gate)
make _clean       # rm -rf dist coverage node_modules
```

## Verification

```bash
make lint
make test
make build
make qa-smoke
```
