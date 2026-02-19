---
name: frontend-design
description: Design and implement distinctive, production-grade web UI with accessibility and responsive behavior built in.
---

# Frontend Design

Create distinctive, production-grade web UI with strong accessibility and clear stack defaults.

## What This Skill Helps With

- Turning product requirements into shippable UI code
- Building pages/components that are visually intentional (not boilerplate)
- Enforcing accessibility and responsive behavior at implementation time
- Providing design rationale + complete code, not mockups

## Invocation Contract

- Primary invoker: `Oracle` (the active coding agent in this repo)
- Triggered when user asks for:
  - New website UI, landing pages, dashboards, or design systems
  - A frontend redesign with implementation code
  - Accessibility-first frontend implementation
- May also be called inside scaffold work when a scaffold includes a web UI surface

## Important Exception

If the target repo already uses Angular + Material UI, do not enforce this skill's visual direction as a restyle mandate.

- Keep existing Angular/Material patterns
- Prioritize accessibility, consistency, and maintainability over aesthetic replacement
- Use this skill only to improve implementation quality within that design system

## Default Website Stack

- React 19+ + TypeScript
- TailwindCSS + `shadcn/ui` primitives
- CSS variables for brand tokens (including e2e-networks color palette)
- React Hook Form + Zod for forms

## Accessibility Contract (Required)

- Semantic HTML landmarks and headings
- WAI-ARIA attributes only where native semantics are insufficient
- WCAG 2.2 AA baseline
- Keyboard-only navigation support
- Minimum touch target: `44x44px`
- Automated web accessibility checks with `@axe-core/playwright`

Example check:

```bash
bun add -d @axe-core/playwright
bunx playwright test --reporter=line
```

## Output Contract

When this skill is used, return:

1. Design intent (concept + visual direction)
2. Complete implementation code (no placeholders)
3. State coverage (default/hover/loading/error/disabled/empty)
4. Usage example
5. Accessibility notes and verification commands

## Anti-Patterns To Avoid

- Generic white-page + blue-button templates
- Inconsistent typography systems
- Hardcoded colors without tokens
- Missing loading/error/empty states
- Non-semantic markup
- Keyboard-inaccessible interactions
