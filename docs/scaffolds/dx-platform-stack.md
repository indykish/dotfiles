# DX Platform Stack And Invocation

This document defines who invokes workflow skills and which stack defaults apply per surface.

## Who Invokes What

- `Oracle` is the invoker/orchestrator for skills.
- Scaffold templates in `docs/scaffolds/` are reference material for Oracle; they do not auto-run by themselves.
- `skills/frontend-design/SKILL.md` is invoked during new UI work or intentional UI redesign.
- If a repo already uses Angular or Material UI, do not enforce frontend-design aesthetics; preserve that system and improve quality/accessibility within it.

## Platform Defaults

1. Website
   - React 19+ + TypeScript
   - TailwindCSS + `shadcn/ui`
   - WAI-ARIA + WCAG 2.2 AA + `@axe-core/playwright`
2. CLI
   - TypeScript + Bun
   - `commander` + `zod`
3. Desktop App
   - Tauri 2 + Rust + TypeScript frontend
   - Prefer Tauri over Electron
4. Mobile Android
   - React Native + Expo + TypeScript
5. Mobile iPhone
   - React Native + Expo + TypeScript

## Accessibility Baseline

- Website: automated checks via Playwright + `@axe-core/playwright`.
- Mobile/Desktop simulator workflows: use `axe` CLI when installed; otherwise run platform-native accessibility checks and note the limitation.

## Why This Exists In `ai-jumpstart`

- `agent-scripts` focuses on reusable global skills.
- `ai-jumpstart` adds team-specific scaffold templates so stack defaults are explicit for this org.
- Skills execute workflows; scaffold docs define canonical outputs and verification targets for this repo's training/deployment model.
