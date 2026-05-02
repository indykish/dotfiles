---
name: write-unit-test
description: >
  Generates risk-weighted, failure-injecting tests across 9 stacks (Python, Python SDK,
  OpenAPI, JS/TS CLI, React/TS, Zig, Rust, Go, Shell). Enforces behaviour + failure +
  invariant + integration + regression coverage with explicit anti-patterns and a
  Definition-of-Done gate. Use during implementation, not after.
---

# Write Unit Test

Generate tests that catch bugs before they ship. Tests run *during* implementation, not after.

## Test quality bar

Every test answers three questions. If it answers none, delete it.

1. **What bug would this catch?**
2. **What behaviour does this prove?**
3. **What invariant does this enforce?**

A green test that answers none of these is worse than no test — it's false confidence.

## Truth hierarchy

When sources disagree, trust in this order:

1. **Runtime behaviour** — prod logs, incidents, observed traces
2. **Spec** — `docs/v*/active/M*.md`, PR description, milestone doc
3. **Code** — current implementation

Spec contradicts runtime → surface the conflict before testing. Code contradicts spec → spec wins; test the spec, flag the code as a defect.

## First steps

1. **Read the spec, then the code** — spec defines what to test; code is what gets tested. Don't let code shape expectations.
2. **Read `docs/greptile-learnings/RULES.md`** — every rule is a regression test.
3. **Detect the stack** from project files (`pyproject.toml`, `Cargo.toml`, `go.mod`, `build.zig`, `package.json` + `react`/`bin`, `*.sh`, `openapi.yaml`).
4. **Run the existing suite first** — establish the green baseline before adding tests.
5. **Follow existing naming and fixture conventions.**

## Three execution modes

Pick one. Don't run all categories on every file.

| Mode | When | Required categories |
|---|---|---|
| **Change-set** | Standard PR, isolated fix | Behaviour, Failure, Integration, Regression |
| **Hardening** | Critical paths: auth, money, data integrity, migrations, distributed ops | + Invariant, Concurrency, Fuzz |
| **Deep audit** | Infra/core, dependency upgrade, full release QA, security review | All categories + Performance + Contract |

Auto-detect from diff: auth/payment/migration/concurrency/streaming files → Hardening. Otherwise → Change-set.

## Risk-weighted priority

Within each mode, write tests in this order. Stop when you've covered the surface.

1. **State transitions** — PENDING→RUNNING, idempotent vs not, monotonic
2. **External boundaries** — I/O, network, DB, FS, IPC
3. **Concurrency paths** — races, ordering, double-fire
4. **Error handling branches** — every `catch`, `orelse`, `?`, `Result::Err`, `try/except`
5. **Pure functions** — last; usually low bug density

A string helper does not get the same treatment as a distributed retry loop. Allocate effort by blast radius.

---

## Five test categories

### 1. Behaviour
Input → exact output shape AND side effects. Assert *both*. Asserting only the return value misses DB writes, event emits, log lines, state changes.

### 2. Failure (≥50% of all tests)
- **Specific error contracts** — type + message + structured fields (status code, error code, hint). Bare `expect error` / `assert.throws` is a smell.
- **Boundaries** — empty, null/None/`Option::None`, max (`i64::MAX`, `Number.MAX_SAFE_INTEGER`), overflow, NaN, malformed, truncated, unicode (CJK, emoji, RTL, ZWJ), CRLF/LF, leading/trailing whitespace, embedded newlines.
- **Expected vs fatal distinction** — a function returning null for both timeout (expected) and connection-reset (fatal) causes busy-loops. Test that they take different paths.
- **Auth failures** — no token, expired, wrong role, revoked, rate limited.
- **Downstream errors** — 4xx, 5xx, timeout, DNS, TLS, partial UTF-8, broken pipe.

### 3. Invariant
Properties that must hold across all valid inputs. Use property-based testing (`hypothesis`/`proptest`/`fast-check`/`gopter`) when input domain is large.

- **Idempotency** — N calls = 1 effect. Required for webhooks, retries, distributed ops, PUT semantics.
- **Monotonic state** — RUNNING never goes back to PENDING.
- **No duplicate side effects** — same event ID never processes twice.
- **Eventual consistency** — final state converges regardless of order.
- **Conservation** — sum of debits = sum of credits; total events in = total out + dropped.
- **Schema lock** — no silent field add/remove on stored or wire format.

### 4. Integration
End-to-end through real stack. **Mock only at system boundaries** (network, disk, external APIs, clock, randomness). Never mock internal modules — that validates fake behaviour and integration bugs slip through.

- Full middleware chain executes (auth, rate-limit, logging, CORS).
- Real DB, real serializer, real router. Use containers, not in-memory fakes when behaviour differs.
- For spec claims involving "real-time" / "streaming" / "incremental": assert bytes arrive incrementally — not just that the parser handles pre-buffered data.
- Failure modes named in code → integration test with deterministic injection.

### 5. Regression
Pin behaviour that must not silently change.

- Golden output files — diff on change. Agent must explain *why* a snapshot changed; never silently re-bless.
- Public API surface (`__all__`, exports, header signatures, `@sizeOf`, ABI stability).
- Breaking-change detectors (`oasdiff breaking`, `buf breaking`, `cargo public-api`).
- Old test suite passes against new code on dependency upgrades.

---

## Hard rules

- **Mock only at system boundaries.** No mocking internal modules. No asserting on mocks (`expect(mockFn).toHaveBeenCalled()`) without also asserting outcome state.
- **State isolation per test.** Reset globals, DB rows, fixtures, env vars, caches. Tests must pass under randomised execution order. Run `pytest -p randomly` / `cargo test -- --shuffle` / equivalent at least once per branch.
- **Specific error contracts.** Assert error type AND message AND structured fields.
- **≥50% negative-path tests** on changed surface. If success tests outnumber failure tests, you're not done.
- **Test names read as documentation.** `should_reject_empty_user_id`, `should_retry_on_502_from_gateway`, `should_not_duplicate_event_on_retry`. No `test_1`, `test_basic`, `it works`.
- **No testing private functions directly.** Test through the public surface. If a private function needs direct testing, it's actually public — promote it.
- **No duplicating implementation logic in tests.** A test that re-implements the function under test proves nothing.
- **Tests favour clarity over DRY.** Independence and explicitness beat reuse. Extract a helper only when ≥3 tests share non-trivial setup AND the helper has no logic worth hiding.
- **Untestable claims are flagged**, not silently skipped. Mark `needs infra` in the claim-tracing table.

## Anti-patterns (reject in review)

- ❌ Snapshot-only tests with no behavioural assertion
- ❌ Asserting on mocks instead of outcomes
- ❌ Testing private functions directly
- ❌ Duplicating implementation logic in tests
- ❌ Bare `expect error` / `assert.throws` with no type/message contract
- ❌ Tests that pass only when run in a specific order
- ❌ "Minimum N tests per file" filler that asserts the same invariant N times
- ❌ Mocking internal modules
- ❌ Coverage padding — line coverage with no behavioural claim
- ❌ Hand-wavy performance assertions ("not too slow")
- ❌ Silent golden-file re-blessing on snapshot drift

---

## Failure injection toolkit

Vague claim: "handles connection reset". Real test: deterministic injection. If you can't reproduce a failure deterministically, the test is fiction.

| Failure | Tool / technique |
|---|---|
| TCP reset / half-open | `toxiproxy`, `tc netem`, raw socket close from peer |
| Slow / delayed response | `toxiproxy` latency, `respx` delay, fake clock |
| Partial read | `io.LimitedReader`, custom `Read` returning short |
| DB connection drop | `pg_terminate_backend()` mid-transaction |
| Timeout | shrink `SO_RCVTIMEO`, `tokio::time::pause()` |
| Clock skew | freeze/advance fake clock; `chrono` mock; `mock-time` |
| Disk full / EIO | `tmpfs` size limit; mock filesystem |
| OOM | `FixedBufferAllocator` (Zig), small heap caps |
| Concurrency races | `loom` (Rust), `-race` (Go), `std.Thread` + barrier |
| Network partition | `iptables`/`pfctl` block, `toxiproxy` down |

Every failure mode named in the spec or code (`catch`, `orelse`, retry loop) needs at least one injection-driven test.

---

## Coverage that matters

Line coverage is noise. Track and report:

- **Branch coverage** — every `if`/`match`/`switch` arm hit
- **Error-path coverage** — every `catch`/`orelse`/`Err` constructed in code is exercised by a test
- **Input-class coverage** — empty / single / many / unicode / malformed each appear at least once per public input

Targets on touched code: branch ≥80%, error-path 100%, negative-path ratio ≥50%.

## Spec integration

When a spec exists with these tables, treat them as authoritative test sources:

| Spec table | Generates |
|---|---|
| Test Specification | One test per row, name = `dim X.Y: <name>` |
| Error Contracts | One negative test per row asserting exact error |
| Failure Modes | One integration test per row with deterministic injection |
| Implementation Constraints | Verification command run + result reported |

If the spec has none of these, build a claim-tracing table from spec prose / PR description:

```
| Claim | Test type | Injection mechanism | Test exists? |
|---|---|---|---|
| "gate results print in real time" | integration (streaming) | partial-read reader | ❌ |
| "heartbeat fires within 30s" | integration (timer) | fake clock | ❌ |
| "no busy-loop on Redis reset" | failure (fatal vs timeout) | `pg_terminate_backend` | ❌ |
```

Every claim → ≥1 test. Untestable claims → flag `needs infra`.

---

## Definition of Done

Reject the change if any are missing on touched code:

- [ ] ≥50% negative-path tests for changed surface
- [ ] Boundary tests: empty, null/None, max, malformed
- [ ] Error contract tests: type + message + structured fields
- [ ] Idempotency check where retries / webhooks / distributed ops apply
- [ ] State isolation: tests pass under random execution order
- [ ] Integration test through real stack for any spec claim involving transport/streaming/real-time
- [ ] Failure-injection test for every failure mode named in code
- [ ] Test names read as documentation
- [ ] No mocking of internal modules
- [ ] Golden-file drift, if any, has a written explanation
- [ ] Branch coverage ≥80%, error-path 100% on touched code
- [ ] Performance assertions concrete (fixed input + time budget + threshold)

100% required before declaring done.

## CI execution strategy

| Stage | What runs |
|---|---|
| **PR** | Behaviour + Failure + Regression unit; fast Integration; lint; type-check; randomised order |
| **Pre-merge** | Full Integration; Contract (`oasdiff` / `buf breaking`); coverage delta |
| **Nightly** | Concurrency stress; Fuzz (`schemathesis` / `proptest` / `cargo-fuzz`); Performance benchmarks |
| **Pre-release** | Golden full-suite; cross-platform; memory-leak (`std.testing.allocator`); ABI stability |

A test in the wrong stage either delays PRs or never runs. Place deliberately.

## Performance assertions

Hand-wavy "no O(n²)" doesn't test anything. Make it concrete:

- **Fixed input size** (e.g. 10k rows)
- **Time budget** (e.g. p95 < 50ms)
- **Regression threshold** (fails if 1.5× slower than recorded baseline)
- **Allocation count** (`testing.allocator` leak detection; Go `-benchmem`)
- **Connection / FD leak check** — open count before == after

---

## Stack appendix

Tooling per stack:

| Stack | Runner | Branch coverage | Property | Fuzz | Concurrency |
|---|---|---|---|---|---|
| Python | `pytest` | `pytest-cov --branch` | `hypothesis` | `atheris` | `ThreadPoolExecutor`, `asyncio` |
| Python SDK | `pytest` + `responses`/`respx` | same | `hypothesis` | `schemathesis` | `asyncio.gather` |
| OpenAPI | `schemathesis` | n/a | n/a | `schemathesis run --checks all` | n/a |
| JS/TS CLI | `vitest` + `execa` | `c8` branch | `fast-check` | `fast-check` | `Promise.all` |
| React | `vitest` + `testing-library` | `c8` branch | `fast-check` | n/a | `userEvent` rapid |
| Zig | `zig build test` | manual | manual | manual mutation | `std.Thread.spawn` |
| Rust | `cargo test` | `cargo-llvm-cov` | `proptest` | `cargo-fuzz` | `loom`, `tokio::spawn` |
| Go | `go test` | `-cover -covermode=count` | `gopter` | `go test -fuzz` | `-race`, goroutines |
| Shell | `bats` | `bashcov` | n/a | n/a | `&` + `wait`, `flock` |

Naming convention by stack:

- Python/Go: `test_should_<behaviour>_when_<condition>`
- Rust: `fn should_<behaviour>_when_<condition>()` in `mod tests`
- Zig: `test "should <behaviour> when <condition>"`
- React/TS: `it("should <behaviour> when <condition>")`
- Shell/bats: `@test "should <behaviour> when <condition>"`

Stack-specific must-knows:

- **Zig** — `std.testing.allocator` auto-detects leaks; verify cross-compile (`x86_64-linux`, `aarch64-linux`) since stdlib API may differ from macOS; `conn.query()` requires `.drain()`.
- **Python SDK** — assert API key not in debug output; HTTPS enforced; pagination doesn't load all pages in memory; rate-limit retry honours `Retry-After`.
- **Rust gRPC** — protobuf round-trip; streaming doesn't buffer full response; `tonic::Status` codes assert specific variant.
- **Rust HTTP** — `axum::extract::rejection` paths; payload too large (413); missing `Content-Type`.
- **React** — `axe` accessibility audit; no `dangerouslySetInnerHTML` with unsanitized input; controlled vs uncontrolled input switching.
- **Shell** — all variables quoted (`"$var"`); `set -euo pipefail`; no `eval` with user input; `mktemp` for temp files.
- **OpenAPI** — `schemathesis run --checks all`; `oasdiff breaking` in CI; `spectral lint` for style.

## OWASP for agent-bound data

Code paths sending data to LLMs / tool-calling agents (directly or via queue/DB/API):

- [ ] User-controlled input never concatenated raw into prompts; structured roles only
- [ ] Length-bounded, validated, sanitised against instruction-injection markers (`ignore previous`, role-confusion XML/JSON)
- [ ] Tool permissions scoped per-invocation, not globally granted
- [ ] Secrets/credentials/PII stripped before reaching the agent; opaque references only
- [ ] Agent output validated against allowlist/schema before any side effect; never `eval()` raw output
- [ ] Authorization re-checked at every hop; agent inherits caller's permissions, not service-level
- [ ] Audit log: who, input, tools called, output, side effects — tamper-resistant
- [ ] Fail-closed on any trust check failure — never silently fall back

---

## Output format

For each test write:

1. Name (per stack convention)
2. Category (Behaviour / Failure / Invariant / Integration / Regression)
3. The bug it catches in one line
4. The test code
5. Failure-injection mechanism if applicable

After the suite produce:

```
## Coverage report: <module>
| Metric              | Before | After | Target |
| Branch              | 41%    | 87%   | ≥80%   |
| Error-path          | 60%    | 100%  | 100%   |
| Negative-path ratio | 20%    | 55%   | ≥50%   |
Categories: Behaviour ✅ · Failure ✅ · Invariant ✅ · Integration ✅ · Regression ✅
DoD checklist: 12/12
Mode: Change-set | Hardening | Deep audit
```

## Validation gate

Single command runs all tests in the chosen mode. Report exact command, pass/fail/skip counts, coverage delta, and DoD checklist status. Do not declare done until DoD is 100%.
