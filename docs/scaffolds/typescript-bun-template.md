# TypeScript + Bun Scaffold Template

Reference project:

- TypeScript: `$HOME/Projects/typescript/branding` — or clone git@awakening.e2enetworks.net/cloud/branding.git

## Required Structure

```text
.
├── Makefile
├── make/
│   ├── quality.mk
│   ├── test.mk
│   ├── build.mk
│   ├── push.mk
│   └── sonar.mk
├── .gitlab-ci.yml or .github/workflows/ci.yml
├── VERSION
├── CHANGELOG.md
├── docs/
│   ├── architecture.md
│   └── diagrams/
│       └── frontend.mmd
├── package.json
├── bun.lock
├── src/
└── tests/
```

## Quality Baseline

```bash
bun run lint
bun run typecheck
bun test
bun run build
```

Expose as:

- `make quality`
- `make test`
- `make build`
- `make push`

## Verification

```bash
make quality
make test
make build
```
