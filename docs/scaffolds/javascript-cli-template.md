# JavaScript CLI Scaffold Template

## Required Structure

```text
.
├── package.json
├── src/
│   ├── cli.ts
│   ├── commands/
│   └── lib/
├── tests/
└── README.md
```

## Stack

- TypeScript + Bun
- `commander`
- `zod`

## Verification

```bash
bun run lint
bun run typecheck
bun test
bun run build
```
