---
name: create-scaffold
description: Create or normalize repositories to the standard Makefile, CI, docs, and verification contract for any supported stack.
---

# Create Scaffold

Create or normalize a repository to the standard project layout for any supported stack.

## Usage

```
/create-scaffold <stack>
```

Supported stacks: `python`, `rust`, `go`, `typescript`, `javascript-cli`, `tauri`

If `<stack>` is omitted, prompt the user:

```
Which stack?
1. python        — Python backend (Django/FastAPI)
2. rust           — Rust library or API
3. go             — Go project
4. typescript     — TypeScript + Bun
5. javascript-cli — JavaScript/TypeScript CLI tool
6. tauri          — Tauri 2 desktop app (Rust + TypeScript)
```

## Common Inputs

- Repo path
- Forge (`github` or `gitlab`)

Stack-specific inputs are defined in `stacks/<stack>.md`.

## Shared Required Files

Every scaffold must produce:

- `Makefile`
- `make/quality.mk`, `make/test.mk`, `make/build.mk`, `make/push.mk`, `make/sonar.mk`
- CI config (`.gitlab-ci.yml` or `.github/workflows/ci.yml`)
- `VERSION`
- `CHANGELOG.md`
- `docs/diagrams/*.mmd` (Mermaid diagram source)

## Shared Command Workflow

```bash
mkdir -p make docs/diagrams tests
```

Ensure `Makefile` exposes:

- `make dev`
- `make quality`
- `make test`
- `make build`
- `make push`
- `make sonar`

Then follow the stack-specific workflow in `stacks/<stack>.md`.

## Verify

```bash
make dev
make test
make build
```

## Output Contract

Report:

1. Files created/updated.
2. Missing prerequisites.
3. Exact verify command results.
4. Any unresolved blockers.
