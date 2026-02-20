# Go Scaffold Template (API/Provider)

Reference project:

- Go: `$HOME/Projects/go/src/github.com/e2eterraformprovider` — or clone https://github.com/indykish/terraform-provider-e2e

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
│       └── flow.mmd
├── go.mod
├── cmd/
├── internal/
└── tests/
```

## Quality Baseline

```bash
go fmt ./...
go vet ./...
go test ./...
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
