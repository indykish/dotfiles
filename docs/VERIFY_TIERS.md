# VERIFY — Tiers, performance, hygiene

> Parent: [`../AGENTS.md`](../AGENTS.md) §VERIFY. Verification Gate (`docs/gates/verification.md`) enforces; `make` targets are canonical.

**FIRST: `/write-unit-test`** — audits diff coverage vs spec's Test Specification (or changed surface when no spec). Iterate until clean. Skipping = CHORE(close) violation.

## Correctness tiers (do not skip)

| Tier | Command | When |
|---|---|---|
| 1 | `make test` | Every EXECUTE iteration; start of VERIFY. Unit-only — never substitutes for 2/3. |
| 2 | `make test-integration` | Diff touches `src/http/**`, `src/db/**`, `src/zombie/**`, `src/observability/**`, `*_integration_test.zig`, schema, migrations. Before COMMIT. |
| 3 | `make test-integration` | ≥1× per branch from clean state (after `make down`) before ship-ready. Mandatory when schema changes pre-v2.0. Tier 2 passing + 3 failing = state pollution; fix isolation. |

## Performance / leak (before PR)

| Gate | Command | When |
|---|---|---|
| Leak | `make memleak` | Server lifecycle (`src/http/**`, `src/cmd/serve.zig`), allocator wiring, cross-thread heap ownership. |
| Bench (local) | `make bench` | When the diff touches request-path code, allocator wiring, or startup/shutdown sequencing. |
| Bench (dev) | `API_BENCH_URL=https://api-dev.usezombie.com/healthz make bench` | After deploy to dev. |

Knobs (`make/test-bench.mk`): `API_BENCH_METHOD`, `_DURATION_SEC`, `_CONCURRENCY`, `_TIMEOUT_MS`, `_MAX_ERROR_RATE`, `_MAX_P95_MS`, `_MAX_RSS_GROWTH_MB`.

**Memleak evidence:** paste final `make memleak` line into PR Session Notes OR cite CI URL. Branches touching `src/http/**`/`src/cmd/serve.zig`/allocator wiring → last 3 lines verbatim. No "trust me".

## Hygiene (always, before PR)

`make lint` (hard); `make check-pg-drain` + cross-compile `x86_64-linux` + `aarch64-linux` (any `*.zig` touched); cross-layer orphan sweep (RULE ORP — every renamed/deleted symbol → 0 hits across schema/Zig/JS/tests/docs in non-historical files); `gitleaks detect` before any Zig-including commit; 350-line / 50-fn-line check via:

```bash
git diff --name-only origin/main \
  | grep -v -E '\.md$|^vendor/|_test\.|\.test\.|\.spec\.|/tests?/' \
  | xargs -I{} sh -c 'wc -l "{}"' \
  | awk '$1 > 350'
```

**Other:** after refactors, list newly dead code before removing — `NEWLY UNREACHABLE: <symbol/file> — <why now dead>. Remove? Confirm.` **Greptile learning capture:** each finding → "Could this recur?" If yes, add compact rule (Rule/Why/Tags/Ref) to RULES.md same commit. Never defer.
