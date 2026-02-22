# DX Platform Stack

Default technology choices for this project. Use these unless the user or existing repo constraints require otherwise.

## Website

- React 19+ + TypeScript
- TailwindCSS + `shadcn/ui` primitives
- Brand tokens via CSS variables (e2e-networks palette)
- Accessibility: WAI-ARIA + WCAG 2.2 AA + `@axe-core/playwright`

## CLI

- TypeScript + Bun
- `commander` + `zod`
- Human-readable stdout + machine mode (`--json`) when applicable

## Desktop App

- Tauri 2 + Rust backend + TypeScript frontend
- Prefer Tauri over Electron by default

## Mobile (Android + iPhone)

- React Native + Expo + TypeScript (shared codebase)

## Frontend Workflow

- Apply `skills/frontend-design/SKILL.md` when building new UI or redesigning surfaces.
- Scaffold docs in `docs/scaffolds/` are reference templates; they do not self-execute.
- In repos using Angular or Material UI: preserve existing design system, focus on implementation quality/accessibility.

## Accessibility

- Web baseline: Playwright + `@axe-core/playwright`.
- Simulator/mobile: `axe` CLI when installed (`axe list-simulators`, `axe describe-ui`, `axe tap`).
- If `axe` CLI unavailable: platform-native checks + document the gap.
