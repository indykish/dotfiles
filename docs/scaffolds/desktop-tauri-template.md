# Desktop Tauri Scaffold Template

## Required Structure

```text
.
├── src-tauri/
│   ├── Cargo.toml
│   ├── src/main.rs
│   └── tauri.conf.json
├── src/
├── package.json
└── README.md
```

## Stack

- Tauri 2
- Rust
- TypeScript frontend (`react` default)

## Verification

```bash
bun run lint
bun run typecheck
bun test
bunx tauri build --debug
```
