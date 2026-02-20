# E2E QA Template (Playwright CLI)

## Required Files

```text
.
├── playwright.config.ts
├── tests/e2e/
│   ├── smoke.spec.ts
│   └── critical-flow.spec.ts
└── Makefile
```

## Install

```bash
bun add -d @playwright/test
bunx playwright install --with-deps
```

## Make Targets

```make
qa:
	bunx playwright test --reporter=line

qa-headed:
	bunx playwright test --headed

qa-smoke:
	bunx playwright test tests/e2e/smoke.spec.ts
```

## CI Command

```bash
bunx playwright test --reporter=line
```

## Policy

- Keep tests deterministic (no AI self-healing assertions in baseline suite).
- Use data-test selectors where possible.
- Treat flake as a bug, not a retry strategy.
