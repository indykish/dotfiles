# Website Frontend Scaffold Template

## Required Structure

```text
.
├── src/
│   ├── components/
│   ├── pages/ (or routes/)
│   ├── styles/
│   └── lib/
├── tests/
│   └── e2e/
├── package.json
└── README.md
```

## Stack

- React 19+ + TypeScript
- TailwindCSS + `shadcn/ui`
- Form validation: React Hook Form + Zod
- Accessibility checks: Playwright + `@axe-core/playwright`

## Verification

```bash
bun run lint
bun run typecheck
bun test
bunx playwright test --reporter=line
```
