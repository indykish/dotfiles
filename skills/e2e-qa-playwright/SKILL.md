---
name: e2e-qa-playwright
description: Set up and run Playwright CLI-based end-to-end QA with deterministic selectors and CI-friendly output.
---

# E2E QA Playwright

CLI-first browser QA baseline for this organization.

## Policy

- Use Playwright CLI as default.
- Do not use mabl as baseline.
- Do not use Stagehand as baseline.

## Setup

```bash
bun add -d @playwright/test
bunx playwright install --with-deps
```

## Required Targets

- `make qa`
- `make qa-smoke`
- `make qa-headed` (optional local debug)

## Core Commands

```bash
bunx playwright test --reporter=line
bunx playwright test tests/e2e/smoke.spec.ts
bunx playwright test --headed
```

## CI Rules

- Run headless by default.
- Fail pipeline on test failure.
- Store screenshots/videos/traces as artifacts.

## Output Contract

Return:

1. Test files added/updated.
2. Exact command outputs.
3. Flake analysis and stabilization changes.
