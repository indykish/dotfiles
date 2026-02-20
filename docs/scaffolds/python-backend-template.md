# Python Backend Scaffold Template (Django/FastAPI)

Reference projects:

- Python API: `$HOME/Projects/marketplace_api` — or clone git@awakeninggit.e2enetworks.net:cloud/marketplace_api.git
- Python library: `$HOME/Projects/cache_access_layer` — or clone git@awakeninggit.e2enetworks.net:cloud/cache_access_layer.git

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
├── .gitlab-ci.yml
├── VERSION
├── CHANGELOG.md
├── docs/
│   ├── architecture.md
│   └── diagrams/
│       └── system.mmd
├── pyproject.toml
├── src/
└── tests/
```

## Minimum Make Targets

```make
quality: ## lint + format + type checks
	test: ## pytest
build: ## package/container build
push: ## push artifact/image
sonar: ## sonar analysis (optional)
```

## CI Skeleton (`.gitlab-ci.yml`)

```yaml
stages: [quality, test, build, push]

quality:
  stage: quality
  script:
    - make quality

test:
  stage: test
  script:
    - make test

build:
  stage: build
  script:
    - make build

push:
  stage: push
  rules:
    - if: $CI_COMMIT_TAG
  script:
    - make push
```

## Docs Requirements

- Keep architecture diagram in Mermaid (`docs/diagrams/system.mmd`).
- Keep API behavior and runbook notes in `docs/`.
- Update `CHANGELOG.md` for user-visible changes only.

## Verification

```bash
make quality
make test
make build
```
