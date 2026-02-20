# RELEASE Checklist

Use this for all repositories that follow the standard `Makefile` workflow.

## Global Release Flow

1. Verify clean tree: `git status`.
2. Run quality + tests + build.
3. Update `CHANGELOG.md` under `[Unreleased]`.
4. Set/confirm `VERSION`.
5. Tag release (`vX.Y.Z`).
6. Push branch + tags.
7. Validate pipeline and artifacts.

## Standard Make Targets

Expected targets across repos:

- `make dev`
- `make test`
- `make build`
- `make push`
- `make sonar` (optional per repo)

If a target is missing, add it or map to an equivalent target in `make/*`.

## Python API/Service (Django/FastAPI)

```bash
make dev
make test
make build
make sonar    # if configured
```

Release actions:

```bash
echo "1.2.3" > VERSION
git add VERSION CHANGELOG.md
git commit -m "chore(release): 1.2.3"
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin HEAD --tags
```

## Rust (API or Library)

```bash
make quality     # should include fmt + clippy
make test
make build
```

Optional publish flow:

```bash
make push
```

## Go (API or Provider)

```bash
make quality     # fmt + vet + lint
make test
make build
```

Optional publish flow:

```bash
make push
```

## TypeScript/Bun

```bash
make quality     # eslint + typecheck
make test
make build
```

Optional publish/deploy flow:

```bash
make push
```

## CI/CD Requirements

- GitHub repos: verify with `gh run list` and `gh run view <id>`.
- GitLab repos: verify with `glab ci status` and `glab pipeline view`.
- Do not release while required checks are red.

## Rollback Stub

- Identify last stable tag.
- Re-deploy artifact from stable tag.
- Open incident note with root cause and fix plan.
