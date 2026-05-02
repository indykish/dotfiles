# REST API Design Guidelines — `usezombie/zombied`

**Status:** Canonical instruction set. Read this before adding, modifying, or removing any HTTP endpoint.
**Trigger:** the global instruction `HTTP handler or OpenAPI changes → read docs/REST_API_DESIGN_GUIDELINES.md first` fires when the diff touches `src/http/handlers/**`, `public/openapi/**`, or any `route_*` file. If you're an agent reading this — you got here because that trigger fired. Follow this doc as a checklist, not as background reading.

This is a goal-oriented instruction set. Each rule states the goal it serves so you can apply judgment at the edge cases instead of memorizing exceptions.

---

## Quick checklist — adding an endpoint

Before opening a PR, every box must be checked:

- [ ] **URL design** — plural noun resource, hierarchical path, no verbs (§1)
- [ ] **HTTP method** chosen by semantics (§2)
- [ ] **Request body shape** matches the path (no path-param IDs in body) (§3)
- [ ] **Response envelope** is consistent (single object or `{items, total, next_cursor}`) (§4)
- [ ] **Error responses** use the error registry; no ad-hoc strings (§5)
- [ ] **OpenAPI YAML** edited under `public/openapi/paths/<tag>.yaml` (§6)
- [ ] **Route registered** in all five places (§7)
- [ ] **Handler signature** matches `inner*(hx: Hx, req: *httpz.Request, ...)` (§8)
- [ ] **Middleware policy** picked from the table (§7)
- [ ] **Tests written** covering happy path + at least one error per `hx.fail` call (§10)
- [ ] **`make openapi` clean** — bundle in sync, redocly lint passes (§6)
- [ ] **`make test-auth` 200/200** — auth gate matrix unchanged (§10)
- [ ] **No file over 350 lines** (§10)
- [ ] **`gitleaks detect` clean** (§10)

If you're skimming, the load-bearing sections for handler authoring are §7 (route registration) and §8 (handler signature). Read those carefully every time.

---

## §1 — URL design

### Use plural nouns for resources

```
GET    /products              ← collection
GET    /products/{id}         ← single resource
POST   /products              ← create
PATCH  /products/{id}         ← partial update
DELETE /products/{id}         ← remove
```

NOT `/getProducts`, `/createProduct`, `/product`.

**Goal:** RESTful conventions; OpenAPI generators (Stainless, Speakeasy, OpenAPI Generator) produce clean SDKs from this shape.

### Reflect ownership in the path

```
GET /workspaces/{ws_id}/zombies/{zombie_id}/events
POST /workspaces/{ws_id}/zombies
```

Nested paths express the containment relationship. Don't flatten — `/zombies?workspace_id=...` loses the contract that the zombie belongs to that workspace.

### No verbs in URLs

- Bad: `/users/{id}/activate`, `/zombies/{id}/start`
- Good: `PATCH /users/{id}` body `{status: "active"}`, `POST /zombies/{id}/events` (event resource creation)

**Exception** — operation-style endpoints (sub-resource verbs) are acceptable when the action genuinely is an operation, not a state mutation. Use the colon convention: `POST /v1/.../approvals/{gate_id}:approve`. The `:approve` is the operation noun. Use sparingly.

### Resource ID lives in path, not body

```http
PATCH /products/123
body: { "name": "new name" }    ← do NOT include "id": 123 in body
```

If the parent ID is in the path, never repeat it in the body.

### Field naming (Microsoft-aligned)

- **Plural for collections, singular for items**
- **`Id` suffix** for identifiers (`product_id`, `zombie_id`)
- **`at` suffix** for datetimes (`created_at`, `completed_at`)
- **Adjectives before nouns** (`completed_items`, not `items_completed`)
- **No `is_` prefix** on booleans (`enabled`, not `is_enabled`)
- **Include units** in field names (`expiration_days`, `size_in_bytes`, `wall_ms`)
- **Avoid** `object`, `response`, `payload`, `data` as field names — too generic
- **Avoid** brand names and reserved words

---

## §2 — HTTP method semantics

| Method | Use for | Idempotent |
|--------|---------|------------|
| `GET` | Retrieve resource(s) | Yes |
| `POST` | Create new resource (server assigns ID) OR operation-style endpoint | No |
| `PUT` | Replace a resource fully (or upsert when client supplies the ID) | Yes |
| `PATCH` | Partially update a resource | No (typically) |
| `DELETE` | Remove a resource | Yes (idempotent: 204 on already-deleted) |

**When in doubt:** if the client supplies the ID and the body fully describes the resource, use PUT. If the server assigns the ID, use POST. If only some fields change, use PATCH.

---

## §3 — Request body shape

### List response envelope

```json
{
  "items": [ {...}, {...} ],
  "total": 42,
  "next_cursor": "eyJ0Ijoi..."
}
```

Always `items` (not `results`, `data`, `entries`). `total` for page-bounded counts when affordable; `next_cursor` for cursor-paginated endpoints; both can coexist.

### Single resource response

The resource itself, no envelope:

```json
{
  "id": "01HZQ...",
  "name": "platform-ops",
  "created_at": "2026-04-25T12:00:00Z"
}
```

NOT `{ "data": { ... } }`.

### Filtering, sorting, pagination

```
GET /products?status=active&sort=-created_at&cursor=abc&limit=50
```

- **Filtering:** flat query params (`status=active`, `enabled=true`).
- **Sorting:** `sort=field` or `sort=-field` for descending.
- **Pagination:** prefer cursor-based (`cursor=` + `limit=`) over page-based (`page=` + `page_size=`). Cursors are stable under writes.

### IDs

- Use **UUID v7** for all internal IDs (sortable, time-encoded). See [uuid7.com](https://uuid7.com).
- Do not expose database serial integers.

---

## §4 — Response shape

### Success — use `hx.ok`

```zig
hx.ok(.ok, .{ .zombie_id = id, .status = "active" });
hx.ok(.created, .{ .agent_id = id, .key = raw_key });
hx.ok(.accepted, .{ .status = "accepted", .event_id = event_id });
```

The `Hx` helper writes the JSON response with the right status code and content-type. Never call `hx.res.json(...)` directly except for SSE streams (and Slack's "ack-and-drop" pattern).

### Status codes

| Code | When |
|------|------|
| `200` | Successful read or update |
| `201` | Resource created |
| `202` | Accepted for async processing |
| `204` | Successful delete or no-content op |
| `400` | Client error in request shape |
| `401` | Missing or invalid authentication |
| `403` | Authenticated but unauthorized |
| `404` | Resource not found |
| `409` | Conflict (precondition failed, idempotent retry on already-resolved gate) |
| `413` | Payload too large |
| `429` | Rate limited |
| `500` | Internal server error |

If you find yourself wanting another status code, check RFC 7231/7807 — don't invent one.

### Datetime fields

ISO 8601 in UTC, suffixed `Z`:

```json
"created_at": "2026-04-25T08:00:00Z"
```

Not Unix timestamps, not local timezones, not `+00:00`.

---

## §5 — Error handling

### Use the error registry

The error-code registry (`src/errors/error_registry.zig`) owns the HTTP status, RFC 7807 `title`, and `docs_uri`. Your handler supplies only the code and a human-readable `detail`:

```zig
hx.fail(ec.ERR_INVALID_REQUEST, "workspace_id must be a valid UUIDv7");
hx.fail(ec.ERR_FORBIDDEN, "Workspace access denied");
hx.fail(ec.ERR_ZOMBIE_NOT_FOUND, ec.MSG_ZOMBIE_NOT_FOUND);
```

NOT `common.errorResponse(hx.res, "...", "...", req_id)`. NOT `hx.res.status = 400; hx.res.body = "{...}"`.

If you need an error code that doesn't exist:

1. Add it to the registry with status, title, docs_uri.
2. Add a corresponding test asserting the registry entry is reachable.
3. Document in your spec's "Error Contracts" table.

### Internal 500s — direct calls

For DB / pool / operation failures, use the helpers directly:

```zig
common.internalDbUnavailable(hx.res, hx.req_id);   // pool.acquire failed
common.internalDbError(hx.res, hx.req_id);         // query failed
common.internalOperationError(hx.res, "detail", hx.req_id);
```

These are NOT wrapped on `Hx`.

### Error response body (RFC 7807)

```json
{
  "type": "https://docs.usezombie.com/errors/invalid-request",
  "title": "Invalid request",
  "status": 400,
  "detail": "workspace_id must be a valid UUIDv7",
  "request_id": "req_01HZQ..."
}
```

`request_id` (carried as `x-e2e-request-id` header on the response) is required for traceability.

---

## §6 — OpenAPI editing

**`public/openapi.json` is a build artifact.** Never edit it directly. Edits get wiped on `make openapi` and CI's bundle-in-sync gate fails the PR.

The source of truth lives under `public/openapi/`:

```
public/openapi/
├── root.yaml                        # info, servers, tags, security, paths map with $refs
├── paths/<tag>.yaml                 # one file per tag (≤ ~400 lines each, advisory)
└── components/
    ├── schemas.yaml
    ├── responses.yaml
    └── security.yaml
```

### Adding, renaming, or removing an endpoint

1. Edit the relevant YAML under `public/openapi/paths/<tag>.yaml`.
2. Add / rename / remove the corresponding `match()` arm in `src/http/router.zig`.
3. Update `src/http/route_manifest.zig` (the (method, path) surface the sync gate asserts).
4. Run `make openapi` — bundles YAML → JSON, runs Redocly lint, runs `check_openapi_errors.py`, asserts router ↔ openapi.json parity. One target, one gate.
5. Commit YAML + bundled JSON + `router.zig` + `route_manifest.zig` together. Splitting these across commits leaves CI red.

**Agent-edit recipe:** see `public/openapi/AGENTS.md` for copy-paste-ready rename / append / remove / update-description workflows.

---

## §7 — Registering a route

Five places, in order. Skip any one and the build or sync gate fails.

1. **`src/http/router.zig`** — add a variant to the `Route` enum (with path params).
2. **`src/http/router.zig::match()`** — add the path parser that returns your variant.
3. **`src/http/route_table.zig::specFor()`** — map the variant to a `RouteSpec`:

   ```zig
   .my_endpoint => .{ .middlewares = registry.bearer(), .invoke = invoke.invokeMyEndpoint },
   ```

4. **`src/http/route_table_invoke.zig`** — add the invoke shim:

   ```zig
   pub fn invokeMyEndpoint(hx: *Hx, req: *httpz.Request, route: router.Route) void {
       if (req.method != .POST) { common.respondMethodNotAllowed(hx.res); return; }
       my_handler.innerMyEndpoint(hx.*, req, route.my_endpoint);
   }
   ```

5. **`public/openapi/paths/<tag>.yaml`** — add the endpoint (§6).

### Matcher style — segment-based, not substring-based

All path matchers in `src/http/route_matchers.zig` operate on a canonical
`Path` view: a stack-allocated array of segments parsed once at the dispatch
boundary. Matchers compare by **segment count + segment[i] equality**.
Disambiguation is shape-driven, not order-driven.

**Pattern (mandatory for any new matcher):**

```zig
pub fn matchMyEndpoint(p: Path) ?MyRoute {
    if (p.segs.len != N) return null;        // exact segment count
    if (!p.eq(0, "literal-1")) return null;  // literal slots
    if (!p.eq(2, "literal-2")) return null;
    const id_a = p.param(1) orelse return null;  // path-param slots: param() rejects empty
    const id_b = p.param(3) orelse return null;
    return .{ .field_a = id_a, .field_b = id_b };
}
```

**Banned in new matchers:**
- `std.mem.startsWith` / `endsWith` / `indexOf` on the path string.
- Suffix-driven dispatch (`if endsWith(path, "/foo")`).
- Implicit segment boundaries via offset arithmetic.
- Reservations encoded as call-site ordering ("must run matcher A before B").

**Required properties of a matcher set:**
- **Mutual exclusivity by structure.** Any two matchers must be reject-incompatible
  by segment count or segment-equality predicates. If two matchers can both
  fire on the same path, one of them needs a tighter predicate (e.g. an explicit
  `if (p.eq(i, RESERVED)) return null` exclusion). Order in `match()` must not
  decide correctness.
- **Empty-segment safety.** `Path.parse` preserves empty segments from `//` and
  trailing slashes. Matchers extract path-parameter slots via `param(idx)`,
  which returns null on empty — empty IDs reject at the matcher, not the
  handler.
- **Semantic-named typed structs.** Each `Route` enum variant gets its own
  struct with semantic field names (`credential_name`, `agent_id`, `grant_id`,
  `memory_key`, `gate_id`, …). Parsing logic may be shared via a private
  helper, but the public surface stays type-distinct.

**Single API-version site.** The dispatcher in `router.zig::match()` calls
`Path.parse(...)` once, checks `segs[0]` against the API version, then hands
`p.tail(1)` to the version-specific matchers (`matchV1`, future `matchV2`).
The string `"v1"` lives in exactly one place — that dispatch line. No matcher
body checks the API version.

### Middleware policy table — pick one at step 3

| Policy | Use for |
|--------|---------|
| `auth_mw.MiddlewareRegistry.none` | Public endpoint; no auth, OR handler does its own (OAuth callbacks, webhook receivers) |
| `registry.bearer()` | Standard user-facing endpoint; workspace-scoped Bearer token |
| `registry.admin()` | Admin-only (internal telemetry, platform keys) |
| `registry.operator()` | Operator role required |
| `registry.webhookHmac()` | Approval webhook (HMAC-signed body) |
| `registry.slack()` | Slack events/interactions (Slack signature) |

Middleware runs BEFORE your handler: token verification, `hx.principal` population, and 401/403 short-circuits are already done when your `inner*` runs. For `none` policy routes, `hx.principal` is zero-valued — do not read it.

### Raw-handler exceptions

Some endpoints bypass `authenticated()`. Each must carry an explanatory comment at the top of the file:

| File | Reason | Comment |
|------|--------|---------|
| `webhooks.zig` | HMAC-verified, not Bearer | `// HMAC-verified — does not use hx.authenticated()` |
| `github_callback.zig` | OAuth callback | `// OAuth callback — does not use hx.authenticated()` |
| `health.zig` | Health endpoints | `// unauthenticated — health` |
| `agent_relay.zig`, `runs/stream.zig` | Streaming | `// Streaming handler — does not use hx.authenticated()` |
| `auth_sessions_http.zig` | Per-function (login/poll public, complete authed) | per-function comments |

If you write a new raw handler, add it to this table.

### Reference implementations

When in doubt, mirror an existing handler:

| Pattern | Look at |
|---------|---------|
| Simple list/get | `zombie_api.zig::innerListZombies` |
| POST with body + validation | `zombie_api.zig::innerCreateZombie` |
| DELETE with idempotency | `zombie_api.zig::innerDeleteZombie` |
| Admin-only | `admin_platform_keys_http.zig::innerGetAdminPlatformKeys` |
| Multi-method on one path (GET/PUT/DELETE) | `workspace_credentials_http.zig` |
| Workspace auth + tenant context | `zombie_telemetry.zig::innerZombieTelemetry` |
| Webhook with inline auth | `webhooks.zig::innerReceiveWebhook` |
| Streaming (SSE) | `agent_relay.zig::innerRelay` |

---

## §8 — Handler signature contract

Every HTTP handler in `zombied` follows this shape. Enforced by `make lint` and the comptime wrappers in `src/http/handlers/hx.zig`.

```zig
pub fn innerMyEndpoint(hx: Hx, req: *httpz.Request, ...path_params) void {
    // 1. validate inputs
    // 2. db / state work (use hx.db()/hx.releaseDb())
    // 3. respond via hx.ok(...) or hx.fail(...)
}
```

### Rules

- **Name prefix `inner`** (never `handle`). The `invokeXxx` shim in `route_table_invoke.zig` is the only public entry — your function is the inner implementation it calls after middleware has populated `hx`.
- **First parameter: `hx: Hx`** — never `ctx: *Context`, `res: *Response`, `req_id: []const u8`, or an arena allocator. All of those live inside `hx`.
- **Second parameter: `req: *httpz.Request`** — only if you actually read it (body, query, headers). Drop it if you only need path params.
- **Path params come after `req`** — order matches the `Route` enum variant in `router.zig`.
- **Return `void`.** Errors are written to the response; never return a Zig error.

### What NOT to do

- ❌ `handleMyEndpoint(ctx, req, res)` — old signature; don't add new ones.
- ❌ Building an `ArenaAllocator` inside the handler — `hx.alloc` is already request-scoped.
- ❌ Calling `common.authenticate` — middleware already did this; use `hx.principal`.
- ❌ `common.errorResponse(hx.res, ...)` — use `hx.fail(...)`.
- ❌ `hx.res.json(body, .{})` or `res.status = 200; res.body = "{}"` — use `hx.ok(.ok, body)`. Acceptable only for SSE streams and Slack ack-and-drop.
- ❌ Returning a Zig error from the handler — write to `hx.res` and return void.

### `Hx` struct reference

`Hx` is defined in `src/http/handlers/hx.zig`. Five pointer-sized fields, passed by value:

```zig
pub const Hx = struct {
    alloc:     std.mem.Allocator,       // request-scoped arena
    principal: common.AuthPrincipal,    // populated by bearer/admin middleware
    req_id:    []const u8,              // unique request ID
    ctx:       *common.Context,         // pool, queue, oidc, telemetry, app_url
    res:       *httpz.Response,         // response writer

    pub fn db(self: Hx) !*pg.Conn;             // acquire from pool; caller must releaseDb
    pub fn releaseDb(self: Hx, conn: *pg.Conn) void;
    pub fn redis(self: Hx) *queue_redis.Client; // no allocation
    pub fn ok(self: Hx, status: std.http.Status, body: anytype) void;
    pub fn fail(self: Hx, code: []const u8, detail: []const u8) void;
};
```

Comptime wrappers used to register handlers:

| Wrapper | When |
|---------|------|
| `authenticated(inner)` | Standard Bearer-authed handler with no path params |
| `authenticatedWithParam(inner)` | Handler with one path param (e.g. `zombie_id`) |

Handlers with two or more path params (e.g. `webhooks.zig`'s `zombie_id` + `url_secret`) do NOT use the wrappers — they stay raw and call `common.authenticate` directly with their own logic.

### Guardrails on `hx.zig`

- `hx.zig` must stay ≤ 150 lines. Methods are one-liners delegating to `common.zig`. No business logic in `hx.zig`.
- A new method on `Hx` is justified only when ≥2 converted handlers need it. One-off helpers stay in the handler file.
- Zero `ArenaAllocator.init` calls in converted handler files. All arena setup lives inside the comptime wrappers.

---

## §9 — Versioning

URI-based: `/v1/...`. All current endpoints sit under `/v1`. Bump to `/v2` only when a breaking change is unavoidable; default to additive evolution within `/v1`.

Header-based versioning (e.g. `X-API-Version: 2026-04-25`) is NOT used in this project. Don't introduce it.

---

## §10 — Pre-PR checklist (testing + ship)

Before opening a PR touching any handler:

- [ ] `zig build` clean
- [ ] `zig build test` passes
- [ ] `make test-auth` passes (200/200) — auth gate matrix unchanged
- [ ] `make test-integration` passes (HTTP + DB + Redis E2E)
- [ ] Cross-compile: `zig build -Dtarget=x86_64-linux && zig build -Dtarget=aarch64-linux`
- [ ] `make lint` — all Zig gates pass (350-line file cap, `check-pg-drain`, zlint)
- [ ] Handler file ≤ 350 lines; split if it grows
- [ ] Integration test covers the happy path AND at least one error path per `hx.fail` call in the handler
- [ ] OpenAPI updated — endpoint definition, request/response schemas, error responses
- [ ] `make openapi` — bundle in sync, redocly lint, router parity
- [ ] `make check-openapi-errors` — every `hx.fail` code is in the OpenAPI's error responses
- [ ] `gitleaks detect` clean
- [ ] No new file over 350 lines

---

## §11 — Security

- Use HTTPS for all endpoints. The Cloudflare Tunnel layer (see `playbooks/ARCHITECHTURE.md`) enforces this for public ingress.
- Bearer tokens for user-facing endpoints. OAuth (Clerk) for the auth-issuance flow.
- Sensitive IDs (workspace_id, zombie_id) live in the path, not the body. Never log them at INFO level.
- Use **UUID v7** for all IDs.
- Never log secret values. Substitution happens at the tool bridge inside the executor sandbox; tokens never enter the agent's context, the event log, or any handler-level log line. (See `docs/ARCHITECHTURE.md` §10 for the substrate guarantees.)
- Webhook receivers verify HMAC signatures using `std.crypto.utils.timingSafeEql`. Never string-compare HMACs.

---

## §12 — Performance

Targets (measured in CI bench under `make bench`):

- p99 latency < 200 ms
- p95 latency < 150 ms
- Zero allocator leaks (`std.testing.allocator` integration tests pass)
- No unbounded query loops; pagination defaults `limit=50`, max `limit=200`

If your endpoint can't meet these in a normal load profile, document why in the spec under "Performance Considerations" and pre-clear with a brief in the PR description.

---

## §13 — Reference specifications

When the project's conventions don't cover a case, defer to (in priority order):

1. **This document** — project-specific overrides everything.
2. [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines) — for naming + pagination semantics.
3. [Google API Design Guide](https://cloud.google.com/apis/design) — for resource modeling.
4. [GitHub REST API Docs](https://docs.github.com/en/rest) — for query-param + filtering patterns.
5. [OpenAPI Specification](https://swagger.io/specification/) — schema validity.
6. [RFC 7807](https://www.rfc-editor.org/rfc/rfc7807) — error response envelope.
7. [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) — newer Problem Details (informational).

If a project rule conflicts with an external guide, the project rule wins; document the conflict in this file.

---

## SDK generation

This API is designed for OpenAPI-driven SDK generation. SDK generators tested against the OpenAPI bundle:

- [Stainless](https://stainlessapi.com/)
- [OpenAPI Generator](https://openapi-generator.tech/)
- [Speakeasy](https://speakeasy.com/)
- [APIMatic](https://www.apimatic.io/)

If you add a non-standard pattern (e.g., a polymorphic response shape) without checking SDK generator output, you risk breaking client codegen on the next bundle. When in doubt, mirror an existing endpoint that's known-clean under codegen.
