# write — verify.md — verification dispatch (LATENT façade)

This is the prose the AGENT reads **before emitting any message that asserts work
is verified**. Unlike `write_zig` / `write_any`, `verify` has **no deterministic
`.sh` half** — no script can detect the moment an agent is *about to claim done*.
It is a pure **🔵 judgment** dispatch: the agent reads this, runs the canonical
`make` targets, and emits the verdict block. The trigger is a *claim*, not a file
edit. (This is the former Verification gate absorbed into the dispatch model.)

**Signal legend:**

- 🔵 DECIDE — judgment-only; the agent must run the targets below and report
  honestly. No script gates this — it blocks the *turn*, not a commit.
- ⚪ delegated — the `make` targets themselves live in the product repo; dotfiles
  carries only the discipline of *which* targets are canonical and when.

## Trigger

Fires before any user-facing message asserting verification: *"tests pass",
"ready to merge", "shipping", "ready for review", "CHORE(close) ready"* — or any
equivalent.

**Override:** `VERIFY GATE: <target> skipped per environment constraint (reason: ...)`.
Only when a target is genuinely unrunnable (e.g. Docker missing for integration
tests). Surface the limitation in the done message — never dress a skip as "tests
pass".

## Why `make` is canonical

Package-scoped runners (`bun run test`, `vitest <file>`, `zig build test` without
the integration tier) are **not** verification — they skip cross-package lint,
cross-compile, pg-drain, and integration. `make` targets are the canonical gates.

## Required runs

| Target | When |
|---|---|
| `make lint` | Always. |
| `make test` | Always (tier 1, unit-only by definition). |
| `make test-integration` | Tier 2: diff touches HTTP handlers, schema, DB code, Redis code, or any `_integration_test.zig`. Focused subsets: `make test-integration-db` / `make test-integration-redis`. |
| `make test-integration` | Tier 3: at least once per branch before declaring ship-ready, from a clean state (e.g. after `make down`) when tier 2 is intermittent — fresh DB proves no state carry-over. |
| `make memleak` | Server lifecycle (`src/http/**`, `src/cmd/serve.zig`), allocator wiring, cross-thread heap ownership. |
| `make bench` (local) | Diff touches request-path code, allocator wiring, or startup/shutdown sequencing. |
| `API_BENCH_URL=https://api-dev.agentsfleet.net/healthz make bench` | After branch deploys to dev. |
| Cross-compile `x86_64-linux` + `aarch64-linux` | Whenever `*.zig` touched. |
| `make check-pg-drain` | Whenever `*.zig` touched. |

`make test` never substitutes for tier 2/3. Tier 2 passing but tier 3 failing
means state pollution — fix isolation before shipping.

## Memleak evidence rule

Before CHORE(close) reports green, paste the final `make memleak` result line into
the PR Session Notes block OR cite the CI memleak job URL. Branches touching
`src/http/**`, `src/cmd/serve.zig`, or allocator wiring MUST include the last 3
lines verbatim. No "I ran it, trust me."

## Coverage discipline

- **Branch coverage is the goal; line coverage is the floor.** One input "covers" a multi-clause condition while leaving its logic untested (`trimmed === "" || === "y" || === "yes"` passes line coverage with a single `"y"`). Feed varied inputs across the equivalence classes — each OR clause independently, success-retry AND fail-retry paths, every early-return guard, empty/casing/whitespace/garbage for normalizers. bun's lcov emits no branch records, so this is test-design discipline, not a number to chase.
- **Do not chase per-file 97% on declaration-heavy files.** bun marks compiler-erased lines (`import type`, `interface`) as 0-hit — no test can execute them, and restructuring to lift the number backfires (inlined type literals get instrumented as 0-hit too). The enforced gates are **aggregates** (`enforce-coverage.mjs` global row; codecov patch across uploaded packages); a few erased lines dilute to noise there. No codecov `ignore` entries either — gate on the aggregate.

## Bench knobs

`make/test-bench.mk` env vars: `API_BENCH_METHOD`, `API_BENCH_DURATION_SEC`,
`API_BENCH_CONCURRENCY`, `API_BENCH_TIMEOUT_MS`, `API_BENCH_MAX_ERROR_RATE`,
`API_BENCH_MAX_P95_MS`, `API_BENCH_MAX_RSS_GROWTH_MB`.

## Required output (done-message)

**Success:**

```
✅ Verified: 🧪 lint ✓ · 🧪 test ✓ <N>p/<M>s · 🧩 test-integration ✓ (or N/A — no handler/schema/redis) · 🎯 cross-compile ✓ (zig only)
```

**Failure (any required target failed):**

```
🔴 NOT VERIFIED: <target> ✗ — <one-line reason>
```

**Skipped (environment constraint, not a pass):**

```
⚠️ <target> skipped per environment constraint (reason: ...)
```

A skipped target MUST be surfaced — never dressed up as "tests pass".

## Emoji legend

| Glyph | Meaning |
|---|---|
| ✅ | Verified — all required targets passed |
| 🔴 | Verification failed — at least one target failed |
| ⚠️ | Skipped per environment constraint — read the reason |
| 🧪 | Lint / unit / integration test |
| 🧩 | Integration test (cross-process) |
| 🎯 | Cross-compile target |
| 🔆 | Informational note (does not affect verdict) |
