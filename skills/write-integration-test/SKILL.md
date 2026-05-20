---
name: write-integration-test
description: >
  Generates service-layer integration tests that exercise real dependencies (Postgres,
  Redis, full HTTP router + middleware chain) with deterministic failure injection,
  per-test state isolation, drain audits, and leak audits. Proves zero leaks over the
  real request lifecycle (error paths included), correctness + parallelism at >=100
  connections (no hidden global lock), and a complexity/latency budget under load that
  escalates serialization findings to a refactor proposal. Sister skill to
  write-unit-test. Use when adding/changing handlers, repos, services, or any code
  crossing module boundaries with real I/O. Not for browser E2E (use gstack /qa)
  and not for pure logic (use write-unit-test).
---

# Write Integration Test

Service-layer tests that prove real wiring works under real failure modes. Sits between unit tests (`make test`) and browser E2E (gstack `/qa`, `/e2e-qa-playwright`).

> **What this guarantees / what it doesn't.** Integration tests don't prove "zero bugs
> in production" — they prove the *seams* hold under *real* deps and *named* failure
> modes. Three production-safety proofs are gated on **deterministic** evidence
> (counters over clocks · exhaustive injection · barrier-synced contention · pinned
> baselines): **zero leaks over the real request lifecycle (T6), correctness *and*
> parallelism at ≥100 connections (T5), and a complexity/latency budget under load**.
> When a super-linear term or a serialization point (one global lock) shows up, the
> rule is **propose the structural refactor, surface it for decision — never silently
> band-aid** (`AGENTS.md` Decomposition).

## Test quality bar

Every test answers three questions. Delete it if it answers none.

1. **What integration bug would this catch that no unit test could?**
2. **Which real dependency is exercised — and would mocking it hide the bug?**
3. **What failure mode does this prove the system survives?**

If a test answers (1) but mocks the dep, demote it to a unit test.

## What belongs here

A test belongs in the integration suite (`make test-integration` / `pytest -m integration` / `cargo test --test 'integration_*'`) if **any** of:

- **Real Postgres** — schema applied, real connection pool, real extensions if used
- **Real Redis** — actual pub/sub, streams, KV, lease semantics
- **Full HTTP lifecycle** — request enters via router; auth/rate-limit/CORS/logging middleware runs; handler executes; response serialises
- **Cross-module wiring** — handler → service → repo → DB. Mocking any internal layer disqualifies.
- **Real serialiser** — request/response through the actual codec, not constructed structs

A test does **NOT** belong here if it:

- Tests pure logic / codec / parser → `write-unit-test`
- Drives a browser / asserts UI → gstack `/qa` or `/e2e-qa-playwright`
- Mocks the DB or Redis → demote to unit
- Hits a deployed environment (`api-dev.usezombie.com`) → that's a probe/canary

## Truth hierarchy

When sources disagree, trust in this order:

1. **Production runtime behaviour** — logs, incidents, traces
2. **Spec / OpenAPI / API contract**
3. **Code**

Spec asserts "503 on Redis down", code returns 200 → test the spec, flag the code as a defect.

## First steps

1. **Read the spec** — Failure Modes, Error Contracts, Concurrency Contracts, Resource Limits, Streaming Contracts tables are authoritative.
2. **Read `docs/greptile-learnings/RULES.md`** — every rule maps to a regression test.
3. **Bring up real deps** — `make up` (or stack equivalent). Verify health before writing tests.
4. **Run the existing integration suite** — establish green baseline; rule out flakes before adding tests.
5. **Map the request path** — list every dep the request touches and every `catch`/`orelse`/`except`/`Err` in the chain. That list seeds T4.

## Three execution modes

| Mode | When | Required tiers |
|---|---|---|
| **Smoke** | New CRUD endpoint backed by existing patterns; trivial schema add | T1 + T2 + T3 |
| **Standard** | New service method, new Redis stream/key, schema change with logic | + T4 + T5 + T6 |
| **Hardening** | Auth / payment / lease / migration / streaming / anything in the data-loss radius | + T7 (if applicable) + T8 + chaos pass |

Auto-detect from diff: `src/auth/**`, `src/zombie/leases/**`, schema migrations, streaming handlers → Hardening. CRUD-only against existing schema → Smoke. Default → Standard.

## Risk-weighted priority

Within a mode, write tests in this order. Stop when the surface is covered.

1. **State-changing happy path with real deps** (T1 + T2 + T3 together)
2. **Each downstream-failure branch** (T4) — every `catch`/`orelse`/`except`/`Err` in handler/service/repo
3. **Concurrency under contention** (T5) — same row, same lease, same idempotency key
4. **Resource lifecycle** (T6) — drain after every query, leak across N requests, pool exhaustion
5. **Edge-of-spec contract checks** (T8) — OpenAPI breaking-change

---

## Eight integration tiers

### T1 — Real-dependency wiring

Prove the seams hold:
- Real PG pool initialised; schema/migrations applied; idempotent on re-run
- Real Redis connected; pub/sub round-trips; streams append/consume
- Real router resolves the route; method matched; path params parsed
- Full middleware chain executes in order — auth → rate-limit → logging → CORS
- Zero internal modules mocked. External edges (Stripe, OpenAI, SES) **may** be mocked at the HTTP boundary, never at the SDK call site

### T2 — Request lifecycle behaviour

Full HTTP request → response, asserting:
- Specific status code (`201`, not "2xx")
- Response headers — `content-type`, `x-request-id`, `cache-control`, custom
- Body shape validated against OpenAPI/protobuf schema (not just `assert response["id"]`)
- Pagination headers / cursors when applicable
- HEAD/OPTIONS behaviour when contract requires

### T3 — State assertions (the part most teams skip)

After the request, assert side-effects:
- **DB rows** — queried back, content matches; `updated_at` advanced; FK rows created; soft-delete flag set
- **Redis events** — published to right stream, payload schema valid, consumer-group lag = 0 after process
- **Lease state** — acquired and released; no orphan keys
- **Outbox** — outgoing event row written if applicable
- **Logs** — structured log line emitted with right level + fields (use a capturing logger; assert structured fields, not string match)
- **Metrics** — counter incremented (where exposed in test mode)

A test asserting only the response body is half-done.

### T4 — Failure injection per dependency

Vague claim "503 on Redis failure" → real test with deterministic injection. Every `catch`/`orelse`/`except`/`Err` in the request path needs ≥1 injection-driven test.

| Failure | Injection technique | What to assert |
|---|---|---|
| PG: connection drop mid-tx | `SELECT pg_terminate_backend(pid)` from sibling conn | 503 (not 500), tx rolled back, no orphan row |
| PG: deadlock | Two concurrent tx grabbing rows in opposite order | One retries, other succeeds, no data loss |
| PG: lock timeout | `SET lock_timeout = '50ms'` on test conn | Specific error code, no busy-loop |
| PG: pool exhausted | `pool_size=1`, hold conn from sibling test | 503 or queue, not crash |
| Redis: down | `toxiproxy` disable, or `docker pause` redis | Fallback executes; no busy-loop on reset |
| Redis: slow | `toxiproxy` latency 5s | Timeout path triggers, request fails fast |
| Redis: partition mid-stream | `toxiproxy` cut after N bytes | Reconnect with `Last-Event-ID`, no duplicate processing |
| External 5xx (Stripe/OpenAI) | Mock HTTP server returns 502 | Retry budget honoured, eventual surface to user |
| External timeout | Mock HTTP server delays past `timeout_ms` | Caller times out, doesn't propagate hang |
| TCP half-open | Raw socket `SO_LINGER 0` close | Detected within `SO_RCVTIMEO`, not silent hang |
| Disk: ENOSPC on tmp | tmpfs with size cap | Surface error, no partial-write corruption |
| Clock skew | Fake clock past lease TTL | Lease re-issued, no stale-holder state |

**Distinguish expected vs fatal.** Timeout (expected) and connection-reset (fatal) must take different paths. A function returning null/fallback for both causes busy-loops.

### T5 — Concurrency & isolation

- **Concurrent identical requests** — N callers, same idempotency key → one effect, N OK responses
- **Concurrent conflicting writes** — two callers update same row → one wins cleanly, no corruption
- **Lease contention** — N callers race for same lease → one acquires, others queue or fail predictably
- **Transaction isolation** — assert no dirty reads, no phantom reads at chosen level
- **Randomised execution order** — suite passes under `--shuffle` / `pytest -p randomly` / equivalent. Ordered-only pass = hidden coupling, fix isolation.
- **Per-test isolation is the test's responsibility** — txn rollback, unique IDs, namespaced keys, `TRUNCATE`, or Redis `FLUSHDB` scoped to the test. Suite-level resets (drop+migrate between full runs, schema teardown scripts) are setup hygiene, **not** a substitute for per-test isolation: they only make the *first* run from clean state correct. Tests run inside one process must not see each other's rows.

**Parallelism at scale (≥100 connections) — proves there's no hidden global lock.**
A single global `Thread.Mutex` keeps every correctness test green while serialising
every request; this is the regression that proof exists to catch.
- **≥100 concurrent connections** against real PG + Redis, released together off a
  **barrier** so contention is real and reproducible (not staggered by spawn latency).
- **Correctness invariant (deterministic hard gate):** same row / idempotency key / lease
  under the 100-way race → **exactly one effect**, no lost update.
- **Parallelism assertion (counter, deterministic):** peak simultaneous in-flight ≥ a
  threshold, or pool lock-wait ≈ 0. Wall-clock fallback: 100 concurrent ops finish in
  **< R×** a single op (R≈10 with margin — a global lock blows past ~100×), median-of-K.
- **Verdict invariance:** pass K consecutive runs under randomised order; race detector /
  `loom` (Rust) clean where the stack supports it.
- **A serialization bottleneck is a *structural* finding** — propose the concurrent
  redesign (shard the lock · per-key/per-shard locks · lock-free CAS), surface it; the
  ≥100-connection parallelism counter is the acceptance proof of the redesign. Don't hack
  around the lock.

### T6 — Resource lifecycle

Proofs the system doesn't bleed:
- **Drain audit** — `make check-pg-drain` (or equivalent) green after suite. Every `conn.query()` paired with `.drain()` before `deinit()`.
- **Connection leak** — open count before == after across N requests
- **Memory leak** — Zig: `std.testing.allocator` over full request lifecycle. Rust: `dhat`/`heaptrack` over N iters. Python: `objgraph`/`gc` over N iters.
- **FD leak** — `lsof -p $$ | wc -l` before/after holds
- **Pool sizing** — load N>pool_size concurrent → backpressure works, no crash
- **Graceful shutdown** — SIGTERM mid-request → in-flight completes, new requests rejected with 503

**Zero leaks over the *real* request lifecycle, error paths included (deterministic).**
"0 leaks" means every path frees — including the ones that only run on failure.
- Run the leak audit over the **full** request lifecycle (init → route → middleware →
  handler → deinit / arena reset), not a handler unit, so cross-thread and cross-request
  leaks surface.
- **Zig error-path proof:** wrap allocating handlers/repos under
  `std.testing.checkAllAllocationFailures` (or a `FailingAllocator` loop) — it fails each
  allocation site in turn and asserts no leak on the resulting error return. This is the
  deterministic proof every `errdefer` is correct; exhaustive over alloc sites ⇒ invariant.
- **No cross-request growth:** drive N requests and assert outstanding-bytes / high-water
  does not grow monotonically (a slow leak shows as linear growth).
- **Gate:** `make memleak` → **0 leaks** + `make check-pg-drain` clean, both pasted into PR
  Session Notes; cross-compile both targets before declaring done.

**Complexity / latency budget under load (counters over clocks).**
- **N+1 detector:** assert DB/Redis round-trip count per request is **constant or linear**
  in payload size n — count at n and 10n; multiplicative growth = an N+1 to fix.
- **Complexity ladder:** measure a work counter (round-trips, rows scanned, allocations)
  at n, 2n, 4n, 8n; assert the growth matches the claimed O-bound (noise-free verdict).
- **Latency under the ≥100-conn load:** p95/p99 within budget vs a **pinned baseline file**,
  median-of-K — single samples banned.
- **Super-linear or serialization finding ⇒ propose the structural refactor**, surface it
  for decision (root cause + target design + patch alternative + recommendation); the test
  pins the **target** bound so the refactor is provably met. Don't band-aid.

### T7 — Streaming / transport (only if SSE / chunked / WebSocket / gRPC streaming present)

Spec claim "real-time" → assert *bytes arrive incrementally*, not just that the parser handles pre-buffered data.

- **Incremental delivery** — consumer reads N bytes, asserts more not yet flushed, advances time/clock, reads next chunk
- **Backpressure** — slow consumer → producer pauses, no unbounded buffer growth
- **Reconnect with `Last-Event-ID`** — kill stream mid-flight, reconnect, only missed events replay
- **Heartbeat** — idle stream emits keepalive within SLA (use fake clock to verify)
- **Mid-stream failure** — producer dies mid-frame → consumer sees error, not silent truncation
- **Cancel propagation** — client disconnects → producer stops work within bounded time

### T8 — API contract & schema

- Request and response validated against OpenAPI/protobuf in-test (not just at server startup)
- `oasdiff breaking origin/main..HEAD` exits 0 (PR gate)
- Generated SDK/client compiles against the spec change
- Deprecation headers present for deprecated fields/endpoints
- Versioning: API path/header version matches handler

---

## Hard rules

- **Real deps or it's not integration.** Mocking PG, Redis, or any internal module disqualifies. External-edge HTTP may be mocked at the HTTP boundary, not at the SDK call site.
- **Assert state, not just response.** Body assertion alone is half a test.
- **Per-test isolation is the test's job.** Txn rollback, unique IDs, namespaced keys, or scoped truncation — pick one and apply per test. Suite-level resets (drop+migrate before the run, fixture teardown scripts) are setup hygiene; they don't isolate tests from each other inside one run. Suite passes shuffled.
- **Tier may be env-gated, not binary-gated.** Many projects ship one test binary that runs both unit and integration tests, with env vars / build tags / pytest markers / Zig comptime flags switching the live-deps tier on. That's fine — but the env contract that flips the gate must be documented in the suite README and surfaced in CI, not folklore.
- **Specific error contracts.** Status code + error code + message + structured fields. Bare `expect 500` is a smell.
- **Failure injection is deterministic.** If you can't reproduce a failure on demand, the test is fiction.
- **Drain + leak proofs are required, not optional.** Once per suite, recorded in PR Session Notes.
- **No hitting deployed environments.** Integration tests run against `make up` containers, never `api-dev`/`api`.
- **Test names read as documentation.** `should_503_when_redis_down`, `should_release_lease_on_handler_panic`, `should_not_double_charge_on_idempotency_replay`.

## Anti-patterns (reject in review)

- ❌ Mocking the DB or Redis "for speed" — that's a unit test, label it correctly
- ❌ Asserting only the HTTP response body
- ❌ Tests that pass only when run in a specific order
- ❌ Bare `expect 500` / `assert.throws` with no error-code contract
- ❌ Hand-wavy "handles failure" with no injection mechanism named
- ❌ Sharing state across tests via module-level fixtures
- ❌ Hitting deployed environments from the integration suite
- ❌ Skipping drain/leak audits because "it's just a test"
- ❌ Asserting on log lines via string matching instead of structured fields
- ❌ Calling the handler function directly, bypassing router + middleware

## CI execution strategy

| Stage | What runs | Why |
|---|---|---|
| **PR** | Smoke mode on changed surface + randomised order | Fast feedback, catches obvious wiring breaks |
| **Pre-merge** | Standard mode on changed module + 1× full suite from clean (`make down && make up && make test-integration`) | Detects state pollution between tests |
| **Nightly** | Hardening mode + chaos pass (random failure injection across deps) | Catches rare-path bugs |
| **Pre-release** | Full Hardening + `make memleak` + `make bench` + cross-platform | Final sign-off |

Suite passes shared but fails clean = state pollution, not a bug. Fix isolation before re-running.

## Spec integration

When the spec has these tables, treat them as authoritative test sources:

| Spec table | Generates |
|---|---|
| Failure Modes | One T4 test per row with deterministic injection |
| Error Contracts | One T2 test per row with specific status + error code |
| Concurrency Contracts | T5 tests for stated isolation level + idempotency keys |
| Resource Limits | T6 tests for pool size, timeout, rate-limit |
| Streaming Contracts | T7 tests for incremental delivery + reconnect |

If no such tables, build a claim-tracing table from spec prose / OpenAPI:

```
| Claim                                  | Tier | Injection            | Test? |
| "503 on Redis down"                    | T4   | toxiproxy disable    | ❌    |
| "lease released on handler panic"      | T6   | force panic in test  | ❌    |
| "idempotency replay returns same id"   | T5   | duplicate request    | ❌    |
| "SSE bytes arrive within 100ms"        | T7   | partial-read reader  | ❌    |
```

Every claim → ≥1 test. Untestable claims → flag `needs infra`, never silently skip.

## Stack appendix

| Stack | Suite runner | Real PG | Real Redis | Drain/leak | Concurrency |
|---|---|---|---|---|---|
| Zig (usezombie) | `make test-integration` | `make up` container | `make up` container | `std.testing.allocator` + `make check-pg-drain` | `std.Thread.spawn` |
| Python | `pytest -m integration` | `testcontainers-python` | `testcontainers-python` | `gc` + `objgraph` over N iters | `asyncio.gather` / `ThreadPoolExecutor` |
| Rust | `cargo test --test 'integration_*'` | `testcontainers-rs` / `sqlx::test` | `testcontainers-rs` | `dhat-rs`; `Drop` checks | `tokio::spawn` + `loom` for races |
| Node/Bun | `bun test --integration` | `testcontainers-node` | `testcontainers-node` | manual handle counting | `Promise.all` |

Cross-stack failure-injection tools:

| Need | Tool |
|---|---|
| HTTP fault between services | `toxiproxy` |
| PG mid-tx kill | `pg_terminate_backend(pid)` from sibling conn |
| Redis down | `toxiproxy` disable; or `docker pause redis` |
| Network partition | `toxiproxy` down; `iptables`/`pfctl` block |
| Slow / latency | `toxiproxy` latency toxic |
| Partial read | wrapper `Reader` returning short |
| Clock skew | fake clock injection at app boundary |

Stack-specific must-knows:

- **Zig** — `conn.query()` paired with `.drain()` in the same fn before `deinit()`; verify with the project's drain-audit target. Per-request arena, not per-app. `std.testing.allocator` over the full request lifecycle, not just handler unit, to catch cross-thread leaks. If integration tests share the binary with unit tests, an env var / build flag should gate live-deps mode — assert that gate is set in CI, not assumed. Cross-compile (`x86_64-linux`, `aarch64-linux`) before declaring done.
- **Python** — `pytest-asyncio` event loop scope = `function`, not `session` (avoid leakage). `respx`/`responses` for external HTTP only.
- **Rust** — `#[sqlx::test]` for per-test schema; `tokio::test(flavor = "multi_thread")` for real concurrency. `loom` for races, not raw threads.
- **Node** — `--isolate` per test if framework supports; otherwise reset module registry.

---

## Output format

For each test write:

1. Name (per stack convention, reads as documentation)
2. Tier(s) it satisfies
3. The integration bug it catches that a unit test could not
4. Failure-injection mechanism (required for T4 / T7)
5. The test code

After the suite, produce:

```
## Integration Coverage Report: <module>
| Tier                           | Required | Met   | Status |
| T1 Real-dependency wiring      | yes      | 4/4   | ✅     |
| T2 Request lifecycle           | yes      | 6/6   | ✅     |
| T3 State assertions            | yes      | 5/5   | ✅     |
| T4 Failure injection           | yes      | 3/8   | 🔴     |
| T5 Concurrency & isolation     | yes      | 2/2   | ✅     |
| T6 Resource lifecycle          | yes      | 1/2   | 🟡     |
| T7 Streaming / transport       | n/a      | —     | ⚪     |
| T8 API contract & schema       | yes      | 1/1   | ✅     |
Mode:        Smoke | Standard | Hardening
DoD:         9/12  — return to EXECUTE before declaring done
Drain audit: ✅ make check-pg-drain clean
Leak audit:  🔴 std.testing.allocator reported 2 leaks across 100 requests
Shuffle:     ✅ pass under --shuffle
Clean run:   ✅ pass after make down && make up
100-conn:    ✅ exactly-once + parallel (peak in-flight 64/100, lock-wait 3ms)
Complexity:  ✅ round-trips constant n→10n; p95 42ms < 50ms budget vs baseline
Refactor proposals surfaced: none (or "1 — <one-line summary>")
```

Legend: `✅` met · `🟡` partially met (specify gaps) · `🔴` missing required (block) · `⚪` not applicable (state why)

## Definition of Done

Block the change if any are missing on touched surface:

- [ ] Every changed handler/service/repo has ≥1 T1+T2+T3 happy-path test
- [ ] Every `catch`/`orelse`/`except`/`Err` in the request path has a T4 injection test
- [ ] Every concurrent-write or idempotency claim has a T5 test
- [ ] Drain audit (`make check-pg-drain`) clean post-suite
- [ ] Leak audit clean post-suite (Zig: `std.testing.allocator`; Rust: `dhat`; Python: `objgraph`)
- [ ] Suite passes under randomised execution order
- [ ] Suite passes from clean state (`make down && make up && make test-integration`)
- [ ] No mocking of DB, Redis, or internal modules
- [ ] Test names read as documentation
- [ ] OpenAPI / protobuf breaking-change check (`oasdiff` / `buf breaking`) clean
- [ ] If streaming touched: T7 incremental-delivery test present
- [ ] Failure-injection mechanism named for every T4/T7 test (no fiction)
- [ ] PR Session Notes paste final `make test-integration` + `make memleak` lines
- [ ] **≥100-connection** test proves exactly-once + parallelism (peak-concurrency/lock-wait counter, or wall-time < R×), passes K runs
- [ ] **Zig error-path leak:** allocating handlers/repos proven by `std.testing.checkAllAllocationFailures`; no cross-request high-water growth over N requests
- [ ] **Complexity under load:** N+1 round-trips ruled out (count at n vs 10n); work-counter ladder asserts the O-bound; p95 within budget vs pinned baseline
- [ ] **Refactor escalation:** any super-linear or serialization finding carries a refactor proposal (root cause + target design + patch alternative + recommendation) surfaced for decision — not silently band-aided

100% required before declaring `make test-integration` done.

## Validation gate

Run `make test-integration` (or stack equivalent) twice — once shared, once from clean (`make down && make up`). Run once more under randomised order. Report pass/fail/skip counts, drain audit, leak audit, the coverage table above, and the DoD checklist. Do not declare done until DoD is 100%.
