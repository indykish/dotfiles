# Rust Scaffold Template (API + Library)

Reference projects:

- Rust API: `$HOME/Projects/sre/e2e-logging-platform/rust` — or clone git@awakeninggit.e2enetworks.net:infra/e2e-logging-platform.git
- Rust library: `$HOME/Projects/manager/cache-kit.rs` — or clone https://github.com/indykish/cache-kit.rs

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
│       └── dataflow.mmd
├── Cargo.toml
├── src/
└── tests/
```

## Quality Baseline

```bash
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all
```

Expose as:

- `make quality`
- `make test`
- `make build`
- `make push`

## Docs Requirements

- Keep Mermaid diagrams under `docs/diagrams/`.
- Keep release notes in `CHANGELOG.md`.

## Verification

```bash
make quality
make test
make build
```
