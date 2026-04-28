# Code Rules — Learned from Review

Generic principles from greptile reviews, PR feedback, and production incidents.

**Read this:** at EXECUTE start, during `/review`, when fixing review feedback.
**Ignore a rule:** only when the user explicitly overrides it with a stated reason.

Reference a rule as `RULE NDC`, `RULE OWN`, etc.

---

## RULE NDC — No dead code

**Rule:** Remove unused variables, imports, parameters, and unreachable branches immediately.
**Why:** They mislead readers about real dependencies and are flagged in every review.
**Tags:** zig, js, all
**Ref:** M1_001 unused deps in zombie.js; dead currentObj branch in simpleYamlParse. M30_002 dead CLI variables.

## RULE PSR — Use standard parsers — never hand-roll

**Rule:** Use the language's built-in parser for JSON/YAML/TOML/XML; never use indexOf or regex on structured formats.
**Why:** Hand-rolled parsers silently drop data and are injection-prone.
**Tags:** zig, js, security
**Ref:** M22_001 extractCreatedAt used indexOf on JSON. M1_001 simpleYamlParse silently dropped all arrays.

## RULE OWN — One owner per resource — no double cleanup

**Rule:** Every allocation has exactly one cleanup path — errdefer OR manual free, never both on the same pointer. For multi-step init, use the sequential errdefer chain (see ZIG_RULES.md "Multi-Step Init"). For shared ownership, use `ref()`/`unref()` with an atomic refcount — `unref()` destroys when count hits zero. Raw pointer field = borrowed (caller owns); refcounted field = owned (self manages).
**Why:** Two cleanup paths = double-free on the error path. The bvisor encoding (raw ptr = borrowed, refcount = owned) makes the ownership contract readable from the type alone.
**Tags:** zig, memory
**Ref:** M1_001 manual alloc.free() + errdefer on same pointer = double-free. bvisor Thread.zig, ThreadGroup.zig for ref/unref pattern.

## RULE CTM — Constant-time comparison for secrets

**Rule:** Never use short-circuit equality (==, eql, ===) to compare tokens or passwords; use XOR accumulation.
**Why:** Short-circuit byte comparison leaks secret length via timing side-channel.
**Tags:** zig, security
**Ref:** M1_001 webhook Bearer token compared with std.mem.eql.

## RULE ECL — Distinguish error classes — timeout ≠ fatal ≠ retryable

**Rule:** Never collapse all errors into one return; timeout → retry, fatal → propagate, 4xx → don't retry.
**Why:** Identical handling of 503 and 404 creates busy-loops and misleads callers.
**Tags:** zig, js, reliability
**Ref:** M22_001 readMessage returned null for ConnectionResetByPeer → busy-loop. streamRunWatch treated 503 = 404.

## RULE NSQ — Named constants, schema-qualified SQL

**Rule:** No magic numbers; all SQL in handlers must be schema-qualified (core.table, not table).
**Why:** Unqualified table names fail when search_path differs across environments.
**Tags:** zig, sql
**Ref:** M31_001 unqualified platform_llm_keys in handler query.

## RULE KYS — Composite keyset cursors for pagination

**Rule:** Encode (sort_column, id) in cursors — never a bare timestamp.
**Why:** Multiple rows share the same millisecond; scalar cursor silently skips them.
**Tags:** sql, zig
**Ref:** M1_001 activity_stream cursor was timestamp-only, dropped events at ms boundaries.

## RULE TST-NAM — Test identifiers are milestone-free

**Rule:** Test *filenames* and test *names* (the string passed to `test "…" {}`) must NOT embed milestone IDs, workstream IDs, section numbers, or dimension numbers — e.g. no `M28_001_foo_test.zig`, no `m24_001_cross_workspace_idor_test.zig`, no `test "M28_001 3.3: Jira valid HMAC → .next"`. Use descriptive behavior names instead (`webhook_verify_test.zig`, `test "Jira valid HMAC → .next"`). Specs, PR titles, commit messages, Ripley's Logs, and changelog entries are the durable place for milestone IDs — not test identifiers.
**Why:** Milestones are ephemeral (one-shot delivery units); tests are durable (live for the lifetime of the code they cover). A test named `M28_001 3.3` becomes archaeology the day M28_001 moves to `docs/v*/done/` — future readers don't know what §3.3 was, filters like `-Dtest-filter=M28_001` stop matching after renumbering, and grepping for a behavior pulls in stale milestone noise. The test should describe what it verifies, not when it was written.
**Tags:** zig, testing, naming
**Ref:** Flagged on M28_001 after existing violations `event_loop_m23_integration_test.zig` and `m24_001_cross_workspace_idor_test.zig` surfaced. User directive while writing `test "M28_001 3.3: Jira valid HMAC → .next"` — renamed in the same branch.

## RULE XCC — Cross-compile before commit (Zig)

**Rule:** Run zig build -Dtarget=x86_64-linux && zig build -Dtarget=aarch64-linux before every Zig commit.
**Why:** macOS APIs (client.open, etc.) compile locally but don't exist on Linux; CI cache hides it in dev.
**Tags:** zig, ci
**Ref:** M22_001 client.open compiled on macOS, absent on Linux — 3 rounds to fix. v0.4.0 bare -gnu in CI.

## RULE FLS — Flush all layers — drain all results

**Rule:** After TLS flush, also flush the socket layer. Cast UUID/JSONB to ::text in SELECT. For pg results: use `PgQuery` (see ZIG_RULES.md "Pg Query Wrapper") — `defer q.deinit()` auto-drains. Manual `q.drain() catch {}; q.deinit()` on early-exit paths is eliminated by the wrapper.
**Why:** TLS flush only encrypts into buffer; undrained slices dangle; ::text prevents binary/text divergence across OS.
**Tags:** zig, tls, postgres
**Ref:** M22_001 missing socket flush → infinite hang. M1_001 UUID read as binary on Linux CI, text on macOS. M10_004 PgQuery wraps drain into deinit.

## RULE TIM — Timing invariants must be explicit

**Rule:** Document and enforce heartbeat_interval < socket_timeout < proxy_idle_timeout.
**Why:** Heartbeat > socket_timeout means the first wakeup misses the window and proxy drops at t=30s.
**Tags:** zig, reliability
**Ref:** M22_001 heartbeat 30s > socket timeout 25s → proxy dropped connection.

## RULE STR — Streaming must verify transport, not just parser

**Rule:** Test byte-level incrementality at the transport layer, not just the parser.
**Why:** A correct SSE parser passing feedBytes() does not prove the HTTP layer isn't buffering.
**Tags:** zig, js, testing
**Ref:** M22_001 Zig CLI buffered entire SSE response, printed all events at once.

## RULE PJV — Primitives are pass-by-value in JS

**Rule:** Never pass a mutable boolean/number expecting to observe later changes; use object/closure/AbortController.
**Why:** Primitives are copied on pass; the called function sees a frozen snapshot.
**Tags:** js
**Ref:** M22_001 abortedRef boolean was frozen at false inside called function.

## RULE CAS — Lock-free CAS: never read after failure

**Rule:** After a CAS fails, don't read the slot's fields; use an occupied flag + separate ready flag.
**Why:** The winning thread may still be writing when the loser reads — partial write is visible.
**Tags:** zig, concurrency
**Ref:** M28_001 resolveSlot read partially-written fields after losing CAS.

## RULE TVR — Test only reachable values

**Rule:** Don't insert test values that violate schema CHECK constraints; use independent schema spec for drift tests.
**Why:** Testing invalid values passes in isolation but fails at integration; tautological drift tests catch nothing.
**Tags:** zig, testing, sql
**Ref:** M31_002 tested 0 for a column with CHECK >= 512.

## RULE JCL — CLI JSON contract discipline

**Rule:** Use only stable error codes; UNKNOWN_COMMAND must name the unrecognized token; dual jsonMode guards need a comment.
**Why:** Ad-hoc codes break CLI consumers; usage text as error message is unparseable.
**Tags:** js, cli
**Ref:** M30_002 undocumented AGENT_ERROR/IO_ERROR codes; usage text returned as error message.

## RULE MIG — Migration index assertions track position

**Rule:** When inserting, splitting, or removing migration files, update every index-based assertion in `src/cmd/common.zig`. While `cat VERSION` < 2.0.0, removed files become `SELECT 1;` (see RULE SCH) — their array slot stays but the assertion must match the new content.
**Why:** Stale index silently points at the wrong SQL file with no compile-time error. M10_001 assertions checked for CREATE TABLE in files that were now `SELECT 1;` version markers.
**Tags:** zig, sql
**Ref:** M31_001 migrations[7] pointed at wrong file after a split. M10_001 migrations[14]/[15] asserted dropped table names in version marker files.

## RULE SCM — RESOLVED — SQL comment handling

**Rule:** ~~No semicolons or apostrophes in SQL comments.~~ Fixed in M10_001: `SqlStatementSplitter` now skips `--` line comments before processing. Semicolons and apostrophes in comments are safe. `make test` validates every migration file is parseable (zero-statement files fail).
**Tags:** sql
**Ref:** M1_001 original bug. M10_001 `sql_splitter.zig` + unit test in `common.zig` replaced this rule.

## RULE GLS — Gate dispatcher must not glob itself

**Rule:** Exclude 00_* from 00_gate.sh's own glob; use 0[1-9]_*.sh + [1-9][0-9]_*.sh.
**Why:** Glob matching itself creates a fork bomb.
**Tags:** bash, ci
**Ref:** PR #162 glob matched itself → fork bomb in CI.

## RULE UFS — String literals are always constants

**Rule:** Default: every string literal in source code is a named constant. The literal lives at exactly one declaration site; every other reference imports it. There is no "this one is small," no "this one is just a domain value," no "I'll inline it once and extract later." Adding a literal is the trigger to add (or import) the const.

**Allowed exceptions, narrow:**
- Single-use, throwaway log/error message bodies that are not asserted on by other code (e.g. `log.warn("zombie.claim_fail err={s}", .{...})` — the format string is fine inline).
- Test-fixture human-readable names that have no production counterpart (e.g. `"scrooge-mcduck"` tenant name).
- Single-character separators / `""` / whitespace strings.

Everything else — status values, frame kinds, channel suffixes/prefixes, header names, route paths, error codes, error labels, log *scope* names, env-var names, JSON field discriminants, Redis keys, SQL table/column references, regex patterns, version strings, file paths, content types — gets a const, no exceptions, on first appearance.

**Pre-edit self-audit (mandatory, all languages).** Before saving any source file that adds or modifies a string literal of length ≥4, grep the repo for the literal: `grep -RInF '"<lit>"' src/ ui/ zombiectl/ --include='*.{zig,js,ts,tsx,jsx,py,sh,go,rs,sql}'`. If any prior occurrence exists as a `const` / `pub const` / `export const` / `as const` / `Final[str]` / `readonly` declaration, import it. If the literal is novel, declare it as a const at the appropriate ownership site (the module that "owns" the concept) before using it elsewhere.

**End-of-turn self-audit.** `git diff -U0 HEAD | grep -oE '"[^"]{4,}"' | sort -u` — for each unique literal in the diff, run the pre-edit grep again. Any literal appearing at >1 call site without a shared const is a violation.

**Anti-rationalization clause.** "It's not a domain value" / "it's just a label" / "I'll only use it here" are not exceptions. The rule is mechanical: if it's a string literal and it doesn't fall in the narrow exception list, it's a const. The exceptions are hardcoded above; do not invent new ones.

**Why:** Inline literals across modules drift independently and create silent mismatches. The agent failure mode is matching a spec's prose verbatim instead of grepping for the existing const — discipline must be enforced by the pre-edit grep, not memory or judgment about whether a literal "feels" domain-significant.

**Tags:** zig, js, ts, py, sh, sql, go, rs
**Refs:**
- M1_001 handleReceiveWebhook had 7 inline strings including "Bearer ", status values, and error codes.
- M42_001 slice 11e progress-callbacks test re-stringified `event_received` / `tool_call_started` / `chunk` / `tool_call_completed` / `event_complete` instead of importing `activity_publisher.KIND_*`. Fix: promoted the consts to `pub`, imported them. Caught only at human review — pre-edit grep would have caught it automatically.

## RULE EMS — Error messages follow a standard structure

**Rule:** Always use error_codes.ERR_* + a constant message string; never mix ERR_* constants with inline strings.
**Why:** Inconsistent structure breaks operator tooling and makes error codes unsearchable.
**Tags:** zig
**Ref:** M1_001 webhook handler mixed ERR_* constants with inline message strings.

## RULE PRI — No prompt injection from user input

**Rule:** Never concatenate raw user input into agent prompts; validate, type-check, and length-bound all external input.
**Why:** Unsanitized input enables prompt injection into agent decisions and tool calls.
**Tags:** security, zig, js
**Ref:** Principle — no single incident yet.

## RULE TGU — Tagged unions over optional-field structs

**Rule:** Use union(enum) for mutually-exclusive variants; never represent them with optional struct fields.
**Why:** Optional fields make invalid states representable; tagged unions make them unrepresentable.
**Tags:** zig
**Ref:** M2_002 ZombieTrigger struct with ?source/?schedule — webhook-without-source was valid but semantically wrong.

## RULE VLT — Secrets belong in vault, not in entity tables

**Rule:** Store a vault key_name in entity tables; resolve via crypto_store.load() at runtime.
**Why:** Plaintext secrets appear in query results, backups, and logs.
**Tags:** zig, sql, security
**Ref:** M2_002 webhook_secret TEXT column in core.zombies → refactored to webhook_secret_ref.

## RULE STS — No static strings in SQL schema

**Rule:** Never use DEFAULT or CHECK with hardcoded strings in SQL; enforce value constraints via application constants.
**Why:** SQL can't reference Zig/JS constants, so schema strings drift from code.
**Tags:** sql
**Ref:** M2_002 DEFAULT 'active' and CHECK status IN (...) removed from core.zombies.

## RULE ESC — Escape control characters in JSON string emission

**Rule:** Escape all 0x00-0x1F ASCII control chars per RFC 8259 §7 in any custom JSON encoder.
**Why:** Unescaped \n or null bytes produce malformed JSON and enable key injection.
**Tags:** zig, security
**Ref:** M2_002 writeJsonString only escaped " and \ — \n in YAML value could inject JSON keys.

## RULE CTC — Constant-time comparison must not short-circuit on length

**Rule:** Run XOR loop over min(a.len, b.len) bytes always; fold length mismatch into result after the loop.
**Why:** Early return on length mismatch leaks the expected secret's length.
**Tags:** zig, security
**Ref:** M2_002 constantTimeEq skipped XOR loop entirely on length mismatch.

## RULE NTE — No type erasure when generics suffice

**Rule:** Never use `*anyopaque` for callback contexts or host-supplied pointers when a comptime generic parameter can carry the concrete type. Use `pub fn Middleware(comptime Ctx: type) type` to parameterize on the context type. `*anyopaque` is acceptable only in `chain.Middleware.ptr` (where type erasure is required by the chain runner's homogeneous array) — everywhere else, prefer comptime generics so the compiler catches type mismatches.
**Why:** `*anyopaque` + `@ptrCast` silently accepts any pointer; a typo in the cast target compiles but corrupts memory at runtime. Comptime generics make the lookup callback type-safe at zero runtime cost.
**Tags:** zig, safety
**Ref:** M28_001 `WebhookSig` used `*anyopaque` for lookup context; refactored to `pub fn WebhookSig(comptime LookupCtx: type) type` — the host passes `*pg.Pool` directly with no cast.

## RULE IMS — Use []const u8 for immutable data, not []u8

**Rule:** Declare struct fields as []const u8 for DB results and parsed input; use []u8 only for data you mutate.
**Why:** Mutable slice on immutable data misleads readers and allows accidental mutation.
**Tags:** zig
**Ref:** M2_002 ZombieRow used []u8 for workspace_id, status, token — all immutable DB data.

## RULE ORP — Cross-layer orphan sweep on every rename, delete, or format change

**Rule:** After any rename/delete, grep OLD_NAME across src/, schema/, zombiectl/, docs/ before committing.
**Why:** Stale references in tests, SQL queries, and comments compile fine but fail at runtime.
**Tags:** zig, js, sql, all
**Ref:** M2_002 webhook_secret renamed but stale comments and test fixtures still used the old name.

## RULE CHR — CHORE(close) must include orphan verification gate

**Rule:** Before opening a PR, grep every renamed/deleted symbol and confirm zero non-historical hits.
**Why:** The PR that changes the symbol owns the full cleanup; deferred orphans compound across PRs.
**Tags:** process
**Ref:** M2_002 multiple follow-up fix commits after missing orphan sweep in CHORE(close).

## RULE TST — Test discovery requires explicit import in main.zig

**Rule:** Add _ = @import("path/to/file.zig"); to main.zig test block for every new Zig file with tests.
**Why:** Inline test blocks don't run unless the file is reachable from the test root.
**Tags:** zig, testing
**Ref:** M2_001 router tests existed since M16 but never ran; two pre-existing bugs surfaced on import.

## RULE PTR — ~~Pointer dereference for anytype query params~~ ELIMINATED by PgQuery wrapper

**Rule:** ~~Use q.*.next() and q.*.drain() when a pg query result is passed as &q via anytype.~~
**Status:** Eliminated in M10_004. Use `src/db/pg_query.zig` — helpers take `*PgQuery`, not `anytype`. `q.next()` always works; the `q.*.next()` footgun is structurally impossible.
**Why the old rule existed:** q.next() on a pointer type compiles but calls the wrong dispatch.
**Tags:** zig, postgres
**Ref:** M2_001 original bug. M10_004 PgQuery wrapper eliminates this class.

## RULE ZAL — Zig 0.15 ArrayList API

**Rule:** Use var list: std.ArrayList(T) = .{}; — pass alloc per-operation: append(alloc,), deinit(alloc), toOwnedSlice(alloc).
**Why:** ArrayList.init(alloc) does not compile in Zig 0.15.
**Tags:** zig
**Ref:** Zig 0.15 breaking API change from 0.13.

## RULE DFS — No dead struct fields

**Rule:** Remove struct fields that hold the same value at every construction site; inline the constant.
**Why:** Invariant fields masquerade as configuration and mislead readers.
**Tags:** zig
**Ref:** M4_001 AnomalyRule.behavior was always .auto_kill at every site — field removed.

## RULE NTP — Narrow types at parse boundaries

**Rule:** Parse external input into enums immediately at the boundary; never store raw strings for finite value sets.
**Why:** String validation deferred to business logic silently accepts garbage at the boundary.
**Tags:** zig, js
**Ref:** M4_001 AnomalyRule.pattern was []const u8 with only one valid value; ApprovalPayload.decision validated late.

## RULE CFG — Config-driven over enum-driven for multi-provider patterns

**Rule:** Use a VerifyConfig struct with data fields for multi-provider patterns; avoid enum + per-variant switch arms.
**Why:** Adding a provider requires one new const, not new functions or switch cases.
**Tags:** zig
**Ref:** M3_001 slack_verify.zig Provider enum rewrote as webhook_verify.zig VerifyConfig struct.

## RULE TFX — Test fixtures must use the same constants as production code

**Rule:** Never hardcode string literals in test fixtures for values that have named constants in production code.
**Why:** Three copies of the same value drift independently; only one matches production.
**Tags:** zig, js, testing
**Ref:** M3_001 agentmail domain was .to in prod, .dev in tests, .com in spec docs.

## RULE ERH — ~~Every ERR_* code must have a hint() entry~~ ELIMINATED (M16_001)

**Status:** ELIMINATED by M16_001 — Entry struct requires `.hint` field; comptime asserts `hint.len > 0`.
**Tags:** zig

## RULE DRV — Don't derive values by slicing related fields

**Rule:** Give logically independent values their own struct fields; never derive by string-slicing a sibling field.
**Why:** Derived slice creates invisible coupling that breaks when either field changes independently.
**Tags:** zig
**Ref:** M3_001 HMAC version "v0" derived by slicing "v0=" prefix — fixed with explicit hmac_version field.

## RULE SCH — Pre-v2.0 schema removal: full teardown, no markers, no DROP

**Rule:** While `cat VERSION` < 2.0.0 (teardown-rebuild era), removing tables MUST be a full teardown: (1) delete the SQL file (`rm schema/NNN_foo.sql`), (2) remove the `@embedFile` constant from `schema/embed.zig`, (3) remove the migration array entry from `src/cmd/common.zig` and update its array length + any index-based tests. Never write ALTER TABLE, DROP TABLE, or `SELECT 1;` placeholders. Never keep version-marker files. Migration slot numbers are not sacred pre-v2.0 — the DB is wiped on every rebuild, and gaps in numbering are fine. After VERSION >= 2.0.0, switch to proper ALTER/DROP migrations in new numbered files.
**Why:** Markers accumulate dead code and still force CI to splitter-parse them. Pre-v2.0 there is zero production data to protect; full removal is cleaner and leaves no false grep hits or stale migration slots.
**Tags:** sql, process
**Ref:** M17_001 harness teardown — supersedes prior "replace with `SELECT 1;`" guidance. Under the old rule, M10_001 comment-only markers broke CI (apostrophe in "slots" opened unterminated string in splitter); full deletion avoids the marker problem entirely.

## RULE EP4 — Removed endpoints return 410 Gone, not 404 (post-v2.0 only)

**Rule:** While `cat VERSION` < 2.0.0 (teardown-rebuild era), removed endpoints MAY simply 404 — API drift is allowed because there are no stable external clients. Do NOT write 410 Gone stubs for pre-v2.0 removals; they are ceremony without value. Once VERSION >= 2.0.0, intentionally removed endpoints MUST return HTTP 410 Gone with a named error code — 404 implies a routing error to monitors and clients, 410 signals permanent intentional removal.
**Why:** Pre-v2.0 mirrors the schema teardown policy (RULE SCH) — we tear down DB + APIs freely because nobody downstream is pinned to them. Post-v2.0, 410 becomes load-bearing for client behavior and deprecation signals.
**Tags:** zig, api
**Ref:** M10_001 shipped /v1/runs/* + /v1/specs as 410 stubs before this rule was scoped. M17_001 removed /v1/harness/* and /v1/agents/{id} as bare 404s under the pre-v2.0 carve-out.

## RULE FXS — Fixed-size scan buffers are security bypasses

**Rule:** Scan security-relevant input in overlapping chunks; never silently truncate at a fixed buffer size.
**Why:** Attacker prepends padding larger than the buffer to push payload past the scan window.
**Tags:** zig, security
**Ref:** M6_001 64KB normalization buffer in injection_detector.zig bypassed via 65KB padding.

## RULE RSP — Reject unsupported patterns at parse time, not match time

**Rule:** Validate pattern syntax at parse time with a clear error; never silently fall through to a different match mode.
**Why:** Silent fallthrough makes configuration bugs invisible to operators.
**Tags:** zig
**Ref:** M6_001 globMatch silently treated mid-path wildcards as exact match — fixed in parseEndpointRules.

## RULE OBS — Every observable state must have a log/event entry

**Rule:** Every result variant operators need to know about must emit a log line or activity event; .truncated without an event is a blind spot.
**Why:** Silent state transitions are invisible in dashboards and incident response.
**Tags:** zig
**Ref:** M6_001 content scanner returned .truncated but eventTypeForScan mapped it to null — no event fired.

## RULE BRQ — ~~Large comptime loops need @setEvalBranchQuota~~ ELIMINATED (M16_001)

**Status:** ELIMINATED by M16_001 — no cross-file comptime loop. Validation is inside error_registry.zig with its own quota.
**Tags:** zig, comptime

## RULE EMB — @embedFile cannot cross src/ boundary

**Rule:** Never use `@embedFile` to reach files outside `src/`. For external files (OpenAPI specs, config fixtures), write a Python/shell validator and wire it into a `make` target under `lint-zig`.
**Why:** Zig's embed security model restricts `@embedFile` to the package directory. `@embedFile("../../public/openapi.json")` is a hard compile error, not a runtime failure. There is no workaround except an external script.
**Tags:** zig, comptime, testing
**Ref:** M11_001 §3.1 — OpenAPI ErrorBody validation moved to scripts/check_openapi_errors.py + make check-openapi-errors.

## RULE SNT — ~~Registry sentinels must be distinct from real entries~~ ELIMINATED (M16_001)

**Status:** ELIMINATED by M16_001 — UNKNOWN sentinel is defined outside REGISTRY; comptime assertion prevents collision.
**Tags:** zig, error-handling

## RULE SSM — Use StaticStringMap for O(1) static registry lookup

**Rule:** Use `std.StaticStringMap` for comptime-generated O(1) lookup on static string→value registries. Build the map from the existing TABLE array at comptime with a `const LOOKUP_MAP = blk: { ... }` block.
**Why:** Linear scan over 130+ entries on every error response is unnecessary when the table is known at compile time. `StaticStringMap.initComptime()` generates a perfect hash at zero runtime cost.
**Tags:** zig, performance, comptime
**Ref:** M11_001 error_table.zig — lookup() replaced O(n) for-loop with StaticStringMap(usize) mapping code→TABLE index.

## RULE HLP — Don't ship helpers without a consumer

**Rule:** Do not ship convenience helpers without at least one consumer. Remove dead API surface (unused pub fns) before merge.
**Why:** Unused helpers invite misuse. A `db()`/`releaseDb()` pair with no consumer trains future devs to use it, but without a `defer`-friendly wrapper, they'll leak pool connections.
**Tags:** zig, api-design
**Ref:** M11_001 hx.zig — db()/releaseDb() shipped with zero callers, all handlers used ctx.pool directly. Removed in greptile fix.

## RULE CIV — CI validators must verify $ref targets

**Rule:** CI validators must verify `$ref` targets, not silently skip them. When a response has no inline `content`, check that its `$ref` points to the expected shared response.
**Why:** A `$ref` to `LegacyError` (using `application/json`) passes the validator undetected if the script only checks inline content blocks.
**Tags:** python, ci, openapi
**Ref:** M11_001 check_openapi_errors.py — $ref responses were silently skipped; added target validation.

## RULE TNM — Test names must state what they verify

**Rule:** Test names must state what they verify, not narrate the author's reasoning. No mid-sentence corrections ("does not X — wait, it does").
**Why:** When a test fails, the name is the first thing an engineer reads. A self-contradicting name wastes investigation time.
**Tags:** zig, testing
**Ref:** M11_001 error_registry_test.zig — renamed "does not start with UZ- — wait, it does" to "has sentinel code UZ-UNKNOWN and is 500".

## RULE TXN — Every DELETE in a transaction must ROLLBACK on failure

**Rule:** When multiple `DELETE` (or `UPDATE`) statements share a transaction, every `catch` branch must issue `ROLLBACK` and return. Never log-and-continue — that causes a partial commit where one row is deleted and another is left orphaned.
**Why:** Silent partial commits create vault inconsistencies. For example, deleting the api-key row but leaving the preference row means future GET reports no key while the preference pointer persists.
**Tags:** zig, database, transactions
**Ref:** M11_002 workspace_credentials_http.zig — second DELETE swallowed the error; ROLLBACK was missing. Caught by greptile on PR #189.

## RULE ZIG — Zig struct init/deinit/ownership conventions

**Rule:** Follow this pattern for all Zig structs:
- **`init` signature:** `fn init(allocator: Allocator, ...) !Self` for stack-returned structs that can fail; `fn init(...) !*Self` for heap-allocated. Never return `Self` from `init` when setup is fallible — use `!Self`.
- **`deinit` signature:** Always `pub fn deinit(self: *Self) void` — pointer receiver, no error return. Cleanup must be infallible from the caller's perspective.
- **Multi-step init:** Wrap each allocator.create or sub-init with `errdefer` so partial construction always cleans up. Pattern: `const x = try alloc.create(T); errdefer alloc.destroy(x);` before the next allocating step.
- **Ownership comments:** When a field is borrowed (not owned), say so explicitly: `// owned by caller, not freed here`. Silence implies ownership.
- **Private fields:** No underscore prefix convention. Use Zig visibility (`pub` vs none) and `const`/`var` to control mutability. Helper functions are private by default (no `pub`).
- **Refcounting:** Use `std.atomic.Value(usize)` with `ref()` / `unref()` helpers for shared ownership. `unref()` calls `destroy` when count hits zero.

**Why:** bvisor/src/core shows these patterns consistently. Deviating breaks the ownership contract — missed errdefer means memory leak on partial init; missing ROLLBACK on deinit-equivalent means inconsistent state.
**Tags:** zig, memory, ownership, patterns
**Ref:** bvisor src/core/Supervisor.zig, Thread.zig, ThreadGroup.zig, OverlayRoot.zig, LogBuffer.zig.

## RULE CTX — Cross-tenant data requires a process boundary, not a shared filesystem

**Rule:** Any data that a sandboxed agent must not read across tenant boundaries (zombie, workspace, customer) must live behind a process boundary — a database, a network service, or an authenticated API. A shared filesystem (bind-mounted volume, NFS, host directory) shared between sibling sandboxes is never acceptable, even if the data is "scoped" by path convention.
**Why:** The memory-tool API enforces zombie_id scoping on `memory_recall`. But if the underlying store is a bind-mounted `/var/lib/zombie-memory/{zombie_id}/` directory and the agent has ANY shell or file-read tool (Bash, code execution, Read-file), the agent can bypass the memory API entirely: `cat /var/lib/zombie-memory/zom_other/core/*.md`. This is the classic confused-deputy pattern — the API's scoping checks are bypassed by a different tool that has broader filesystem permissions. Moving the store to a process boundary (Postgres with `memory_runtime` role, different protocol, different credentials) makes cross-tenant access structurally impossible, not just policy-enforced.
**Tags:** security, architecture, multi-tenancy, confused-deputy
**Ref:** M14_001 design review — original draft proposed SQLite on a persistent host volume; rejected because agent shell tools could read sibling zombies' directories. Storage moved to a dedicated Postgres database with a scoped `memory_runtime` role. The rule generalizes: it applies to any future cross-tenant data (per-workspace caches, per-customer artifacts, per-zombie workspaces).

## RULE WAUTH — Every workspace-scoped handler must call authorizeWorkspace after authenticate

**Rule:** Any handler that takes a `workspace_id` URL parameter must (1) capture the principal from `common.authenticate` — never discard with `_ =` — and (2) call `common.authorizeWorkspace(conn, principal, workspace_id)` immediately after acquiring a DB connection. A 403 must be returned before any data is read or written.
**Why:** External agents handlers discarded the principal with `_ = common.authenticate(...)`, so any authenticated workspace owner could enumerate, create, or delete agents in a different workspace just by substituting the workspace_id in the path. Caught by greptile on PR #205 (P0).
**Do:** `const principal = common.authenticate(...) catch |err| { ... }; ... if (!common.authorizeWorkspace(conn, principal, workspace_id)) { return 403; }`
**Don't:** `_ = common.authenticate(...) catch |err| { ... };`
**Tags:** zig, security, IDOR, auth
**Ref:** external_agents.zig — all 3 handlers missing workspace check. Fixed PR #205.

## RULE IDMP — Idempotency checks must not block re-request for terminal statuses

**Rule:** When an idempotency guard queries for an existing row before INSERT, it must distinguish between active statuses (`pending`, `approved`) and terminal statuses (`revoked`, `denied`). Terminal rows must allow re-request via UPDATE back to `pending`, not early-return with the stale status.
**Why:** The UNIQUE constraint on `(zombie_id, service)` makes INSERT impossible after the first row. If the idempotency check returns for ANY status including `revoked`, the zombie can never re-request a grant for that service — it gets `{ "status": "revoked" }` forever. Caught by greptile on PR #205 (P1).
**Do:** Check `is_terminal = eql(status, "revoked") or eql(status, "denied")`. If terminal, UPDATE to pending.
**Don't:** Return early for every existing row regardless of status.
**Tags:** zig, database, idempotency
**Ref:** integration_grants.zig:handleRequestGrant. Fixed PR #205.

## RULE GATDL — Single-use Redis tokens must use Lua compare-then-delete, not GETDEL

**Rule:** When consuming a single-use token from Redis (nonce, gate key, CSRF token), use a Lua `EVAL` script that atomically: GET → compare → DEL only on match → return 1/0. Never use GETDEL (deletes before comparison) or GET+DEL as separate commands.
**Why:** GETDEL atomically deletes the key *before* the comparison happens. An attacker who knows the token ID (e.g., `grant_id` is returned in the API response) can send a request with a fabricated nonce: GETDEL destroys the real nonce, the comparison fails (400), but the legitimate Slack "Approve" button is now broken — the grant is stuck in `pending` indefinitely. This is a targeted DoS that requires only knowing the `grant_id`. With Lua, a wrong nonce returns 0 and leaves the key intact. GET+DEL as two round trips has a separate race condition (two concurrent requests both pass the GET before DEL runs).
**Do:**
```zig
const lua =
    \\local s=redis.call('GET',KEYS[1])
    \\if s==false then return 0 end
    \\if s==ARGV[1] then redis.call('DEL',KEYS[1]) return 1 end
    \\return 0
;
var resp = queue.commandAllowError(&.{ "EVAL", lua, "1", key, nonce }) catch return false;
return switch (resp) { .integer => |n| n == 1, else => false };
```
**Don't:** `GETDEL` (deletes before compare); `GET` + `DEL` as two commands (race).
**Tags:** zig, redis, concurrency, security, nonce
**Ref:** grant_approval_webhook.zig:verifyAndConsumeNonce. Fixed PR #205 (initial GETDEL, second greptile P1 review 4095571471).

## RULE TWF — Timestamp freshness must reject future timestamps

**Rule:** When validating webhook timestamps (Slack `X-Slack-Request-Timestamp`, etc.), reject timestamps that are more than `max_drift` seconds *in the future*, not just in the past. Use `if (ts > now + max_drift) return false;` before the stale check.
**Why:** Accepting future timestamps within the drift window allows an attacker to pre-sign requests with a future timestamp and replay them later, bypassing the anti-replay window.
**Do:** `if (ts > now + max_drift) return false; if (now - ts > max_drift) return false;`
**Don't:** `const diff = if (now > ts) now - ts else ts - now; return diff <= max_drift;` — this accepts future timestamps.
**Tags:** zig, security, webhooks, timing
**Ref:** M8_001 webhook_verify.zig — `isTimestampFresh` accepted future timestamps. Fixed in d07b6de.

## RULE ESO — Error returns must not silently substitute default values on OOM

**Rule:** When a function extracts user-linked data (workspace IDs, user IDs, session tokens) from a trusted input, it must return `!T` and propagate allocation failures, not return a default/empty value with `catch ""` or `catch 0`. A silent default causes the caller to use wrong data (e.g., create a new workspace instead of linking to an existing one).
**Why:** OOM masked by a default value causes silent data corruption — a new entity is created instead of the intended existing one being used. No log entry, no 5xx, no observable failure until the user notices their workspace is gone.
**Do:** `fn extractWorkspaceId(...) ![]const u8 { return alloc.dupe(...); }`
**Don't:** `fn extractWorkspaceId(...) []const u8 { return alloc.dupe(...) catch ""; }`
**Tags:** zig, memory, error-handling, correctness
**Ref:** M8_001 slack_oauth.zig `extractWorkspaceId` — `catch ""` on dupe failure. Fixed in d07b6de.

## RULE SGR — SQL migrations must include GRANT statements for all created tables

**Rule:** Every `CREATE TABLE` migration must end with `GRANT` statements for every role that will query the table. Check which operations the application performs (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) against this table and grant exactly those to `api_runtime` and/or `worker_runtime` as appropriate.
**Why:** PostgreSQL denies all access by default. Without grants, every query against the table fails with `permission denied` in production. This is invisible at migration time and only fails at first runtime use.
**Do:** Follow every `CREATE TABLE` + indices block with grants mirroring the table's callers.
**Don't:** Ship a migration without grants on the assumption that a superuser connection is used in production.
**Tags:** sql, postgres, migrations, security
**Ref:** M8_001 schema/028_workspace_integrations.sql — missing GRANT for api_runtime and worker_runtime. Fixed in this PR.

## RULE OAE — OAuth form bodies must URL-encode all fields including `code`

**Rule:** When building an `application/x-www-form-urlencoded` body for an OAuth token exchange, percent-encode every field value — including the authorization code. Do not assume authorization codes are URL-safe in practice.
**Why:** OAuth codes are URL-safe in most providers today, but the spec allows any character. A code containing `+`, `&`, or `=` would silently corrupt the form body and produce a confusing provider-side error with no local diagnostic.
**Do:** `const code_enc = try urlEncode(alloc, code);` then use `code_enc` in the body template.
**Don't:** Interpolate `code` raw while encoding other fields — the inconsistency signals an oversight and will eventually fail.
**Tags:** zig, oauth, http, security
**Ref:** M8_001 slack_oauth_client.zig `exchangeCode` — `code` interpolated raw. Fixed in this PR.

## RULE CTE — constantTimeEq only hides value timing, not length timing

**Rule:** A constant-time comparison that iterates `min(a.len, b.len)` prevents early-exit on value mismatch but still leaks the shorter input's length via iteration count. Document this limitation in the function comment; do not claim it "prevents timing leaks on secret value or length." For truly fixed-length secrets (e.g. 32-byte hex nonces) the length leak is unexploitable in practice, but the comment must be accurate.
**Why:** Greptile flags the misleading doc comment as a security claim that is stronger than the implementation. A future caller with variable-length inputs would inherit a false guarantee.
**Tags:** zig, security, crypto, constant-time
**Ref:** M18_002 `webhook_url_secret.zig::constantTimeEq` — comment corrected to note that length is still leaked via loop iteration count.

## RULE STL — Remove test fixtures that write stale wire-protocol fields

**Rule:** When a wire-protocol field is removed from the server-side parser (JSON-RPC handler, HTTP body decoder), every test that still writes that field via `object.put("field_name", ...)` must be updated in the same change — not kept as "harmless ignored extra data." Silent ignore is misleading for the next reader and hides schema drift in CI.
**Why:** After a refactor, a test that sends `stage_id` when the handler no longer reads it will pass green even though the test no longer exercises what its name implies. Greptile (and human reviewers) flag these as "stale field silently ignored" — the signal is real: the test is now under-specified or a lie by omission. Same applies to tests writing deleted struct fields via dynamic builders.
**Do:** After the rename/removal, grep for `"<old_field>"` across test files and delete those `object.put(...)` lines in the same commit. If the test was specifically validating that field's handling, delete the whole test case.
**Don't:** Leave `put("<deleted_field>", ...)` because "the handler ignores it." Don't keep symmetric test fixtures "for consistency with sibling tests" when the sibling was also stale.
**Tags:** zig, tests, refactoring, wire-protocol, orphan-sweep
**Ref:** M17_002 — `stage_id`/`role_id`/`skill_id` removed from StartStage; stale `object.put("session_id", ...)` puts in `integration_test.zig`, `handler_edge_test.zig`, `handler_negative_test.zig`, `crash_test.zig` caught by greptile post-merge.

## RULE HXX — Handlers go through Hx, not raw `common.writeJson` / `common.errorResponse`

**Rule:** Every new HTTP handler in `src/http/handlers/*.zig` takes `hx: Hx` as its first parameter and uses `hx.ok(status, body)` and `hx.fail(code, detail)` for responses. Do NOT introduce new call sites of `common.writeJson(res, ...)` or `common.errorResponse(res, code, msg, req_id)` — those are internal implementation details of Hx. Internal-500 helpers (`common.internalDbError`, `common.internalOperationError`, `common.internalDbUnavailable`) stay public because they have fixed codes + messages; call them directly with `hx.res, hx.req_id`.
**Why:** M18_002 completed the sweep from `handleXxx(ctx, req, res, ...)` to `innerXxx(hx, req, ...)`. Re-introducing raw `common.writeJson`/`common.errorResponse` drags back the old signature and bypasses the JSON envelope / RFC 7807 contract that `Hx` enforces. Greptile will flag reviews that do this.
**Do:** `hx.ok(.ok, .{ .field = value })` / `hx.fail(ec.ERR_INVALID_REQUEST, "detail")`. See `docs/nostromo/api_handler_guide.md` for the full style guide.
**Don't:** `common.writeJson(hx.res, .ok, body)` or `common.errorResponse(hx.res, code, msg, hx.req_id)`. If you find yourself writing either, you either need to add a missing method to `Hx` (rare — only `ok` and `fail` earn their place) or the helper should not be public at all.
**Tags:** zig, http, handlers, hx, api-style
**Ref:** M18_002 §5.1–5.2 — full sweep of 18 handler files to inner*/hx. Style guide at `docs/nostromo/api_handler_guide.md`.

## RULE RAD — New HTTP endpoints must pass the REST API Design Guidelines checklist

**Rule:** Before writing any new HTTP handler or adding/modifying an endpoint, read `docs/REST_API_DESIGN_GUIDELINES.md` and verify each of the following:
1. **No verbs in URL** (§7) — use HTTP method for the action. Exception: Google Custom Method colon-action (`resource:verb`) is allowed for RPC-style actions; document the exception in the spec.
2. **Response fields** (§1 + §8) — no `ack` or redundant acknowledgement fields (HTTP 200 is the ack); no `is_` boolean prefix; use `_at` suffix for timestamps; snake_case throughout.
3. **Error shape** (§10) — 400/401/403/404/500 with `{error, message}` JSON body.
4. **Resource ID in path, not body** (§3) — if it's in the URL, don't repeat it in the payload.
5. **Correct HTTP method** (§4) — GET=read, POST=create/action, PUT=replace, PATCH=partial-update, DELETE=remove.
6. **Versioning** (§6) — all routes under `/v1/` (or the current version prefix).

**Why:** M23_001 steer endpoint shipped with `ack: true` (redundant) and `run_steered` (ambiguous dual-semantics). Caught only in post-build audit against REST_API_DESIGN_GUIDELINES.md. A pre-write checklist would have caught both at design time.
**Do:** Paste the six-point checklist into the PLAN surface-area section and tick each item before EXECUTE.
**Don't:** Write the handler and check guidelines afterward — the response shape is the hardest thing to change once tests and OpenAPI are written against it.
**Tags:** zig, http, api-design, rest, naming
**Ref:** M23_001 `zombie_steer_http.zig` — `ack` dropped, `run_steered` split into `message_queued` + `execution_active` after post-build audit. `docs/REST_API_DESIGN_GUIDELINES.md`.

## RULE HGD — Every new handler must follow api_handler_guide.md before writing any code

**Rule:** Before writing any new `inner*` handler function, read `docs/nostromo/api_handler_guide.md` in full and verify:
1. Function named `inner<Resource><Action>` (not `handle*`, not `do*`).
2. First parameter is `hx: Hx` (value, not pointer) — never build your own arena.
3. Responses via `hx.ok(status, body)` and `hx.fail(error_code, detail)` only.
4. DB connection via `hx.ctx.pool.acquire()` with `defer pool.release(conn)`.
5. All `conn.query()` results wrapped in `PgQuery` with `defer q.deinit()` (RULE FLS).
6. No `common.writeJson` or `common.errorResponse` at call sites (RULE HXX).

**Why:** The `api_handler_guide.md` encodes the M18_002 migration contract. New handlers that skip it reintroduce the old `handle*(ctx, req, res)` signature or roll their own arena/response building, breaking middleware propagation and RFC 7807 error shape consistency.
**Do:** Open `docs/nostromo/api_handler_guide.md`, skim the template, then write the handler. Read RULE HXX alongside it.
**Don't:** Copy-paste a handler from before M18_002 (anything that takes `ctx *Context` as first param, or calls `common.writeJson` directly). Those are the old pattern.
**Tags:** zig, http, handlers, hx, api-style
**Ref:** `docs/nostromo/api_handler_guide.md`. RULE HXX (same topic, handler signature). M18_002 full sweep.

## RULE ZWO — Workspace+zombie path routes must verify zombie-to-workspace ownership

**Rule:** Any handler whose URL path contains both `{workspace_id}` and `{zombie_id}` must, after `common.authorizeWorkspace`, also call `common.getZombieWorkspaceId(conn, hx.alloc, zombie_id)` and reject with 404 (not 403) if the zombie does not exist or belongs to a different workspace. Returning 404 avoids leaking zombie existence across workspaces.
**Why:** `authorizeWorkspace` only validates the principal→workspace edge. Without the zombie→workspace check, a caller authenticated for WS_A can read or mutate a zombie owned by WS_B by sending `/v1/workspaces/{WS_A}/zombies/{ZOMBIE_FROM_WS_B}/...`. `zombie_activity_api.zig:innerListActivity` shipped this bug in M24_001; caught by greptile P1 on PR #217 before merge. Every sibling handler (grants list/revoke, steer, delete) already had the check — activity was the outlier.
**Do:**
```zig
if (!common.authorizeWorkspace(conn, hx.principal, workspace_id)) {
    hx.fail(ec.ERR_FORBIDDEN, "Workspace access denied");
    return;
}
const zombie_ws_id = common.getZombieWorkspaceId(conn, hx.alloc, zombie_id) orelse {
    hx.fail(ec.ERR_ZOMBIE_NOT_FOUND, ec.MSG_ZOMBIE_NOT_FOUND);
    return;
};
if (!std.mem.eql(u8, zombie_ws_id, workspace_id)) {
    hx.fail(ec.ERR_ZOMBIE_NOT_FOUND, ec.MSG_ZOMBIE_NOT_FOUND);
    return;
}
```
**Don't:** Assume `authorizeWorkspace` is sufficient when both `{workspace_id}` and `{zombie_id}` are in the path. Don't return 403 on mismatch — that leaks which zombie IDs exist across tenants.
**Test:** Add an IDOR case in `m24_001_cross_workspace_idor_test.zig` (or equivalent) that hits the route with a foreign zombie and asserts 404.
**Tags:** zig, security, IDOR, multi-tenancy, auth
**Ref:** PR #217 greptile comment `3089018810` — `zombie_activity_api.zig:innerListActivity` missing check. Complements RULE WAUTH.

## RULE CNX — Handlers must not hold two pool connections concurrently per request

**Rule:** If a handler has already called `hx.ctx.pool.acquire()` for authorization or another check, any helper invoked from that handler must accept the existing `*pg.Conn` rather than acquiring its own connection from the pool. Helpers that need a conn should offer an `…OnConn` variant that takes one as a parameter, and the pool-based entry point should be a thin wrapper that acquires once and delegates.
**Why:** Holding two connections from a bounded pool for a single request doubles connection pressure under concurrency and can deadlock when the pool is saturated and downstream helpers are waiting for a conn the caller already holds. Greptile P2 flagged `innerListActivity` calling `activity_stream.queryByZombie(pool,…)` (acquires its own conn) while `conn` from `authorizeWorkspace` was still held via `defer`.
**Do:**
```zig
// handler:
const conn = hx.ctx.pool.acquire() catch { ... };
defer hx.ctx.pool.release(conn);
const page = helper.queryByZombieOnConn(conn, alloc, …) catch { ... };

// helper exports both:
pub fn queryByZombie(pool: *pg.Pool, …) !Page {
    const conn = try pool.acquire();
    defer pool.release(conn);
    return queryByZombieOnConn(conn, …);
}
pub fn queryByZombieOnConn(conn: *pg.Conn, …) !Page { … }
```
**Don't:** Keep `defer pool.release(conn)` in the handler and then call a helper that takes `*pg.Pool` — the helper acquires a second conn and both stay live until the handler returns. Also: don't pre-release the first conn before the helper call — you lose the authorization context for post-query RLS/session settings.
**Tags:** zig, database, connection-pool, performance, concurrency
**Ref:** PR #217 greptile comment `3089018915` — `zombie_activity_api.zig` ↔ `activity_stream.zig:queryByZombie`. Fixed by adding `queryByZombieOnConn`.

## RULE BIL — Billing and credential endpoints require operator-minimum role

**Rule:** Every handler that exposes billing data (credit totals, cents figures, invoice fields) or credential material (API keys, vault secrets, OAuth tokens) must gate access with `workspace_guards.enforce(... .minimum_role = .operator)`. Plain `common.authorizeWorkspace` is **not** sufficient — it passes for any workspace member regardless of role, so a `user`-role team member can read data the workspace owner intended to restrict.
**Why:** `authorizeWorkspace` only verifies that the authenticated principal's `workspace_scope_id` (or tenant) matches the path `workspace_id`. It does not consider role. Billing and credential data are privileged by convention across every existing endpoint (`workspaces_billing_summary.zig`, `workspaces_billing.zig`, `workspace_credentials_http.zig` all enforce operator). A new billing endpoint that follows the `authorizeWorkspace`-only pattern silently exposes cent totals to every team member. Greptile P1/security flagged `zombie_billing_summary.zig` for exactly this.
**Do:**
```zig
const actor = hx.principal.user_id orelse API_ACTOR;
const access = workspace_guards.enforce(hx.res, hx.req_id, conn, hx.alloc, hx.principal, workspace_id, actor, .{
    .minimum_role = .operator,
}) orelse return;
defer access.deinit(hx.alloc);
```
**Don't:** Copy `common.authorizeWorkspace` from a non-billing handler into a new billing handler. Role policy is not uniform across endpoints — billing is strictly more sensitive than "list zombies" or "read activity".
**Test:** Add an RBAC case that hits the route with a `user`-role JWT for the correct workspace and asserts 403.
**Tags:** zig, security, rbac, billing, credentials, multi-tenancy
**Ref:** PR #221 greptile comment `3094814139` — `zombie_billing_summary.zig` missing operator guard. Fixed by switching to `workspace_guards.enforce(.minimum_role = .operator)`.

## RULE QPC — Query-param accepted values must match across related endpoints

**Rule:** When two endpoints expose the same semantic filter (e.g. `period_days` on both workspace-scope and per-zombie-scope billing summary), their accepted value sets must be identical. Diverging (e.g. workspace accepts `7|30|90`, zombie accepts only `7|30` and silently clamps 90 to 30) is a UX footgun: callers that work at one scope see unexpectedly-different data at the other.
**Why:** OpenAPI-generated SDKs expose one typed enum per parameter. When enums diverge between sister endpoints, downstream code tries values that "work on the other one" and silently gets wrong data — no 400, no log, just a mis-windowed response. The response carries `period_days: 30` as the only signal, which a caller asking for 90-day data will not read.
**Do:** Extract the accepted set into a shared constant (or at minimum, cross-reference it in both handlers' doc comments) and mirror the OpenAPI `enum:` list. Return 400 `UZ-INVALID-REQUEST` for out-of-set values, OR silently coerce — but pick one and apply identically across sister endpoints.
**Don't:** Silently clamp on one endpoint and reject on another. Don't let one endpoint's enum be a strict subset of another's — either both or neither.
**Test:** Unit-test each accepted value + a rejected value on both endpoints. The enum in OpenAPI must match the accepted set in the handler 1:1.
**Tags:** zig, api-consistency, validation, sdk-ergonomics
**Ref:** PR #221 greptile comment `3094604729` — `zombie_billing_summary.zig::parsePeriodDays` accepted `{7, 30}` while `workspaces_billing_summary.zig::parsePeriodDays` accepted `{7, 30, 90}`. Fixed by adding `90` to the zombie handler and the OpenAPI enum.

## RULE DID — React `id={...}` attributes must use `React.useId()`, never hardcoded strings

**Rule:** Any React component that emits an `id` attribute (`id="foo"`) or references one via `htmlFor` / `aria-describedby` / `aria-labelledby` must obtain the id from `React.useId()` — never a hardcoded string literal.
**Why:** Hardcoded ids collide when two instances of the same component mount on one page. Even with Radix components that unmount on close (e.g. Dialog with `open=false`), calling code can mount multiple instances conditionally, and the *open* one's `aria-describedby` breaks because the closed one also claimed the same id. `React.useId()` generates a stable id per component instance, SSR-safe, collision-free.
**Why this is not academic:** screen readers rely on `aria-describedby` pointing to a unique `id`. When two elements share an id, only the first is announced, and the second's description is silently dropped.
**Do:**
```tsx
const descId = React.useId();
return (
  <div role="alertdialog" aria-describedby={description ? descId : undefined}>
    <DialogDescription id={descId}>{description}</DialogDescription>
  </div>
);
```
**Don't:** Use any static `id="..."` string literal on a component that may be rendered more than once per page. This includes "hidden" siblings — conditional rendering doesn't stop two to-be-rendered trees from colliding during React reconciliation.
**Exception:** top-level singleton elements (the root `<html>` id, a global skip-link target) may use static ids. Anything in `components/` almost certainly cannot.
**Tags:** react, accessibility, a11y, ssr
**Ref:** PR #221 greptile comment `3094604881` — `ConfirmDialog` used `id="confirm-dialog-desc"`. Fixed with `React.useId()`.

## RULE ASE — Async event handlers must catch rejections, not just use `try/finally`

**Rule:** Any async React event handler (`onClick`, `onConfirm`, `onSubmit`, etc.) that `await`s a caller-provided promise must wrap the `await` in `try { ... } catch (err) { ... } finally { ... }` — **not** `try { ... } finally { ... }`. The catch path must either invoke a caller-provided error callback or silently swallow; a bare `try/finally` lets the rejection propagate out of the async function and become an unhandled promise rejection, which React silently drops in production.
**Why:** React does not provide an error-boundary equivalent for async event-handler rejections. `finally` correctly resets pending state, but without `catch` the thrown value escapes into the event loop, surfaces as `unhandledrejection` in dev (logs a warning), and vanishes entirely in production. If the component's JSDoc implies it surfaces the error (e.g. "renders below the description if onConfirm rejects"), that promise is broken.
**Do:**
```tsx
const handleConfirm = useCallback(async () => {
  setPending(true);
  try {
    await onConfirm();
  } catch (err) {
    if (onError) onError(err);
    // No onError: swallow intentionally. Prefer an explicit comment.
  } finally {
    setPending(false);
  }
}, [onConfirm, onError]);
```
**Don't:** Rely on `try/finally` alone for async handlers. Don't promise error-surfacing behaviour in JSDoc when the implementation only does `finally`.
**Expose:** an `onError?: (err: unknown) => void` prop so callers can feed error state into their own UI (which typically then flows back into the component's `errorMessage` prop).
**Tags:** react, async, error-handling, props-api
**Ref:** PR #221 greptile comment `3094605030` — `ConfirmDialog::handleConfirm` used `try/finally` without `catch`, contradicting its JSDoc. Fixed with `catch` + `onError` callback.

## RULE ITF — Integration tests use real schema via `test_fixtures_<name>.zig`

**Rule:** An integration test that exercises any production SQL table must seed rows in the real schema through a shared `src/db/test_fixtures_<testname>.zig` module and assert against the real table. Do **not** create a session-local `CREATE TEMP TABLE` that mocks a production table's shape — the mock drifts from reality, hides schema changes, and lets tests pass against signatures the real query would reject.
**Why:** Every workspace-column migration in M11 broke TEMP-TABLE-based tests silently because the temp shape still matched the old column set. Real-schema fixtures fail loudly when a NOT NULL column is added, which is the correct failure mode. Fixtures also keep auth/scope UUIDs out of production source files so `src/http/**` stays free of test scaffolding.
**Do:**
- One fixture module per test scope, named `src/db/test_fixtures_<scope>.zig` with a **semantic** scope name — e.g. `test_fixtures_prompt_events.zig`, `test_fixtures_http_auth.zig`, `test_fixtures_workspace_credit.zig`. Do **not** use milestone-numbered names (`test_fixtures_uc1.zig`, `test_fixtures_m18.zig`, etc.); those rot as milestones churn and the filename stops describing the scope. Aliases inside test files should also be semantic (`credit_fx`, `billing_fx`, `proposal_fx`), never `uc1`/`uc3`.
- Module exports: `TENANT_ID`/`WORKSPACE_ID` constants, `seed(conn)` / `seedXxx(conn, ...)`, and an idempotent `cleanup(conn)` that deletes in FK-safe order. Reference production seed helpers (`base.seedTenantById`, `base.seedWorkspaceWithTenant`, `base.seedWorkspaceWithCreator`) rather than re-rolling INSERT SQL.
- Tests: `cleanup(conn)` as both pre-seed reset and `defer` bookend, then `seed(conn)` and run assertions against schema-qualified table names (`core.workspaces`, `core.prompt_lifecycle_events`, …).
- Tables with append-only triggers: cleanup wraps DELETEs in `SET session_replication_role = 'replica'` / `origin` (superuser-only; test DB runs as superuser via docker-compose).
**Don't:**
- `CREATE TEMP TABLE <real_table_name>` that shadows a real table. `rls_probe`-style probe tables with no production counterpart are fine; naming an existing table is not.
- Inline test-fixture constants (`GUARD_TENANT_ID`, `SCOPE_WS_PRIMARY`, …) or `cleanupXxxFixtures` helpers inside production source files. Move them to the fixture module.
- Bespoke INSERT SQL inside each test. Use the fixture's seed helper so schema changes ripple through one file, not twenty.
**Tags:** zig, sql, testing
**Ref:** M11_003 step 5D — seven `CREATE TEMP TABLE workspaces` sites in `workspace_guards.zig` + `handlers/common.zig` passed tests while the real `core.workspaces` grew `name NOT NULL`, `uq_workspaces_tenant_name`, FK to tenants. Converted in commits `a50f6ee` (initial conversion) and `7c6fe3a` (relocated fixtures to `test_fixtures_http_auth.zig`). Same pattern found in `src/observability/prompt_events.zig` for `core.prompt_lifecycle_events`.

## RULE TNM — Test naming + problem-oriented comments (no milestone refs in code)

**Rule:**

- **Unit tests** live next to the code they cover and are named `<filename>_test.zig` — one-to-one with the `.zig` file under test. Example: `invites.zig` ⇄ `invites_test.zig`. Unit tests touch no DB; no fixture file needed.
- **Integration tests** live next to the code they cover and are named `<semantic_subject>_integration_test.zig` — the subject is the user flow, endpoint, state-transition, or invariant being exercised (what the test proves), not the milestone that spawned the work. Examples: `approve_credit_integration_test.zig`, `cross_workspace_idor_integration_test.zig`, `clerk_webhook_bootstrap_integration_test.zig`. Fixtures used by the test live at `src/db/test_fixtures_<scope>.zig` per **RULE ITF**.
- **No milestone, workstream, section, sprint, or UC number in filenames or code comments.** Never write `m24_001_<x>.zig`, `UC1`, `M17 §2.1`, `Step 5C`, `batch B5`, etc. in a filename or a persistent source comment. Speak from the **problem** — *why the code exists, what invariant it guards, what user-visible failure it prevents*. Milestone context rotates out of relevance within one cycle; problem statements remain true.
- **Allowed milestone references:** commit messages, PR descriptions, spec files under `docs/v*/`, Ripley's Log entries and handoff files under `docs/nostromo/` (handoff files should actively encode `M{N}_{WKSTRM}` in their filename per the handoff convention in AGENTS.md — filename-embedded milestone tags make `ls docs/nostromo/` scannable), and the **Ref:** line of rules in this file. Those are where milestone numbering *belongs* — they are historical anchors. Durable source code and durable comments are not.

**Why (problem-perspective rationale):** A comment that says `// M17_001 §2.1: max_tokens enforced here` teaches the next reader nothing if M17 shipped, reverted, renumbered, or merged into something else. The same comment as `// Enforce per-month token budget so a runaway agent can't bankrupt the workspace in one unattended loop` still teaches three years later. Filename `m24_001_cross_workspace_idor_test.zig` forces every reader to look up what M24 was; `cross_workspace_idor_integration_test.zig` communicates the scope at glance. Milestone labels are *planning* artifacts — they don't survive contact with codebase drift.

**Verified at:**

- **PLAN:** the plan's test-file list must name files per the convention. Any test file referenced as `m<N>_<WS>_*` in the plan is a bug — amend the plan before EXECUTE. Same for fixture files. State the verification output explicitly in the PLAN message.
- **EXECUTE:** before commit, run
  ```bash
  # Filenames: no m<N>_<WS>_ prefix, no _m<N>_ suffix
  git diff --name-only --diff-filter=A origin/main \
    | grep -E '(^|/)m[0-9]+_[0-9]+_|_m[0-9]+_' && echo "VIOLATION"
  # New/changed comments: no M<N>_<WS> / §<n>.<n> / UC<n>
  git diff origin/main -- 'src/***.zig' \
    | grep -E '^\+.*\b(M[0-9]+(_[0-9]+)?|UC[0-9]+|§ ?[0-9]+\.[0-9]+|Step [0-9]+[A-Z]?)\b' \
    && echo "VIOLATION"
  ```
  Any non-empty output on these greps blocks the commit. Carve-outs: historical comments that were not touched by the diff aren't flagged (the grep is diff-scoped, not tree-scoped).

**Do:**

- `approve_credit_integration_test.zig` with fixture `test_fixtures_workspace_credit.zig`
- `// Serialize the provider upsert — two webhooks racing on the same Heroku name would double-insert otherwise.`
- `invites_test.zig` for unit tests of `invites.zig`.

**Don't:**

- `m24_001_cross_workspace_idor_test.zig` → rename to `cross_workspace_idor_integration_test.zig`
- `metering_m18_test.zig` → `metering_telemetry_integration_test.zig` (or `_test.zig` if genuinely unit-only)
- `event_loop_m23_integration_test.zig` → `event_loop_integration_test.zig`
- `// M17_001 §2.1: ...` in source — describe the invariant instead.

**Tags:** zig, testing, docs, naming, plan, execute
**Ref:** The test-fixture rename pass (`test_fixtures_uc1.zig` → `test_fixtures_workspace_credit.zig` et al.) in the usezombie repo uncovered that milestone-numbered names survive the milestones themselves and stop describing the code. The `metering_m18_test.zig` rename to `metering_telemetry_test.zig` was the immediate precedent. Rule added to prevent regression as future milestones create new test files.

## RULE MKP — Make recipes must not pipe into `tail`, `head`, `grep` without `set -o pipefail`

**Rule:** Inside a Make recipe, do NOT pipe a command whose exit code matters into `tail`, `head`, `grep`, `cat`, or any other filter — Make's default shell (`/bin/sh`) evaluates pipelines with the exit code of the LAST command. A failing test/script piped through `| tail -3` returns 0 because `tail` always succeeds, and the recipe (and the enclosing `make lint` / `make openapi`) falsely succeeds. Either (a) drop the pipe, (b) run the command standalone and let Make's line-level exit-on-error abort on failure, or (c) if a filter is genuinely needed, use `bash -c 'set -o pipefail; cmd | filter'`.
**Why:** Silent test swallow is a class-C outage — the gate claims green while regressions ship. Observed on M28_003 §2 where `@python3 scripts/test_check_openapi_sync.py 2>&1 | tail -3` in `make openapi` passed a failing-test injection without aborting. Greptile P1 caught it before merge; the root cause (Make + default `sh` POSIX pipefail semantics) is the same bug anywhere a recipe uses `|` to tidy long output.
**Tags:** make, ci, testing
**Ref:** usezombie P2_INFRA_M28_003 §2 — `make/quality.mk:161` before fix piped the test runner through `tail -3`; fix in commit 66556e99 dropped the pipe, confirmed with injected `self.fail()` that `make: *** [openapi] Error 1` now fires correctly.

## RULE RES — Reserved route names enforce reservation symmetrically (read AND write)

**Rule:** When a path component (e.g. `/credentials/llm`) is reserved for one handler family but the *parent* collection (`/credentials`) shares storage with another, the reservation MUST be enforced on every write that lands in the shared store, not just on the route matcher. If the matcher excludes `name == "llm"` for the generic DELETE but the POST validator does not reject `{name: "llm"}`, a write under that name lands in the shared backing store under a key the generic delete cannot reach AND the specialized delete does not own — an orphaned, un-deleteable row.

**Why:** `vault.secrets` stores both BYOK rows (`key_name = "llm"`) and zombie credentials (`key_name = "zombie:<name>"`). M45's generic credential POST composed `key_name = "zombie:" ++ body.name` without rejecting `body.name == "llm"`, while `matchWorkspaceCredential` already excluded the `/credentials/llm` *path* (because BYOK owns it). Net result: an operator could POST `{name:"llm",...}` → row at `zombie:llm`; subsequent DELETE `/credentials/llm` routes to the BYOK handler (looks up key `"llm"`, finds nothing, 204) and `matchWorkspaceCredential` returns null on read so the generic DELETE never fires either. Row is un-deleteable through any HTTP route.

**How to apply:**

- For every route matcher that excludes a specific name/suffix, add a write-side validator that rejects the same name with a clear 4xx ("name X is reserved for route Y").
- Anchor the reservation list to a single shared constant — drift between the matcher's exclude-list and the validator's reject-list reintroduces the asymmetry.
- Cover with an integration test that POSTs the reserved name and asserts (a) 4xx response, (b) no row landed in the backing store. The "no row landed" assertion is what distinguishes a real fix from one that only changes the API shape.

**Tags:** zig, http, routing, security, credentials
**Ref:** PR #252 (M45). Greptile P1 finding `3143083466` on `feat/m45-vault-structured`. Fix in commit (this commit) — `validateCredentialName` now rejects `name == "llm"`; integration test asserts both the 400 response and the absence of a `zombie:llm` row.

## RULE CLI-HINT — Renaming or removing a CLI command means sweeping every error message that names the old syntax

**Rule:** When the CLI surface changes (a subcommand renamed, a flag removed, a positional-arg form deprecated), grep every user-visible error message, log line, doc comment, and changelog body for the old syntax — not just the command implementation. Stale syntax in error hints points users at commands that no longer exist; they hit the hint at exactly the moment they're already confused, doubling the failure cost.

**Why:** Error messages are the most expensive place for stale CLI references. A user only reads them when something is already wrong; a hint that says "Run X for help" — where X was deleted last week — turns one failure into two. Compiler can't catch it: error-message strings are opaque text, not symbols. Tests can't catch it without a dedicated string sweep — most tests assert on error *codes*, not message *bodies*.

**Sweep checklist when changing CLI surface:**
- `src/errors/error_entries.zig` — every `e(code, status, summary, "…hint…")` body.
- `src/errors/error_registry.zig` — every `MSG_*` constant.
- Any `log.warn`/`log.err` format string that names a command (those are operator-facing, but operators copy them into runbooks).
- Doc comments at file headers that describe "the user runs X" — they rot the same way.
- The changelog `Update` block being shipped with the rename (the entry is otherwise great place to repeat the new syntax for users to grep).

**Don't:**
- Rely on `make lint` or the type checker — error message bodies are strings, not symbols.
- Rely on `grep -r "<old-command>" src/` finding everything — hints often paraphrase ("the install template…" instead of `install <template>`). Search for the pattern, then read the sentence around each hit.

**Tags:** cli, error-messages, ux, refactor
**Ref:** PR #258 (M44_001). Greptile P1 finding `3145406909` on `feat/m44-install-contract`: UZ-ZMB-008 hint still said `Run 'zombiectl install <template>'` after the legacy positional form was removed in §1 of the same PR. Sweep also caught a stale `// zombiectl up sends both files raw` comment in `config.zig` header. Fix in commit (this commit).
