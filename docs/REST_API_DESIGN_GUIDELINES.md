# REST API Design Guidelines

This document describes best practices for designing **clean, consistent, RESTful APIs**, based on guidance from **Google**, **Microsoft**, **GitHub**, and the **OpenAPI Specification**.

* Well-designed APIs enable **OpenAPI-driven SDK generation**, reducing boilerplate and improving consistency.
* SDK generators:

  * **Stainless** — [https://stainlessapi.com/](https://stainlessapi.com/)
  * **OpenAPI Generator** — [https://openapi-generator.tech/](https://openapi-generator.tech/)
  * **Swagger Codegen** — [https://swagger.io/tools/swagger-codegen/](https://swagger.io/tools/swagger-codegen/)
  * **Speakeasy** — [https://speakeasy.com/](https://speakeasy.com/)
  * **APIMatic** — [https://www.apimatic.io/](https://www.apimatic.io/)

---


## Table of Contents

1. [Resource Naming](#1-resource-naming)
   - [Use Plural Nouns](#-use-plural-nouns)
   - [Microsoft Naming Conventions](#-microsoft-naming-conventions)
2. [Resource Hierarchy and Nesting](#2-resource-hierarchy-and-nesting)
   - [Reflect Hierarchy in the Path](#-reflect-hierarchy-in-the-path)
3. [Resource Identification](#3-resource-identification)
   - [Use Resource IDs in Path](#-use-resource-ids-in-path)
4. [HTTP Method Semantics](#4-http-method-semantics)
5. [Consistent URL Structure](#5-consistent-url-structure)
   - [General URL Pattern](#-general-url-pattern)
   - [Examples](#-examples)
6. [API Versioning](#6-api-versioning)
   - [Use URI or Header Versioning](#-use-uri-or-header-versioning)
7. [Avoid Verbs in URLs](#7-avoid-verbs-in-urls)
8. [Response Structure](#8-response-structure)
   - [Use consistent and predictable JSON structure](#-use-consistent-and-predictable-json-structure)
   - [For list endpoints](#-for-list-endpoints)
9. [Filtering, Sorting, and Pagination](#9-filtering-sorting-and-pagination)
   - [Support query parameters for](#-support-query-parameters-for)
10. [Error Handling](#10-error-handling)
    - [Use standardized HTTP status codes](#-use-standardized-http-status-codes)
    - [Include error details in response body](#-include-error-details-in-response-body)
10a. [Editing the OpenAPI spec](#-10a-editing-the-openapi-spec)
10b. [Handler Signature Contract](#-10b-handler-signature-contract)
10c. [Registering a Route](#-10c-registering-a-route)
10d. [`Hx` Struct Reference](#-10d-hx-struct-reference)
11. [Security Considerations](#11-security-considerations)
    - [Authentication & Service Layer Patterns](#authentication--service-layer-patterns)
12. [Performance Considerations](#12-performance-considerations)
13. [Reference Specifications](#12-reference-specifications)

---

## 📌 1. Resource Naming

### ✅ Use **Plural Nouns**

- **Good**: `/products`, `/users`, `/invoices`
- **Bad**: `/product`, `/createProduct`

> Plural naming indicates a collection of resources and aligns with RESTful conventions.

### ✅ Microsoft Naming Conventions

- **Use clear and simple terms** understandable to developers who aren't domain experts.
- **Avoid generic, throwaway, or redundant words** like `object`, `response`, or `payload`.
- **Avoid synonyms or inconsistent terminology**—pick one word and use it consistently.
- **Use plural nouns** for collections (e.g., `products`).
- **Use singular nouns** for individual resource items (e.g., `product`).
- **Use adjectives before nouns** (`collected_items`, not `items_collected`).
- **Use lower camelCase** for acronyms (`nextUrl`, not `nextURL`).
- **Use `at` suffix** for datetime fields (`created_at`, `deleted_at`).
- **Include units** in field names (`expiration_days`, `size_in_bytes`).
- **Avoid** brand names and uncommon acronyms in names.
- **Avoid reserved words** in major programming languages.
- **Use `Id` suffix** for identifiers (e.g., `product_id`).
- **Avoid `is` prefix** for boolean fields (`enabled`, not `is_enabled`).
- **Avoid redundancy** in nested paths or properties (`/phones/number`, not `/phones/phone_number`).

---

## 📌 2. Resource Hierarchy and Nesting

### ✅ Reflect Hierarchy in the Path

Use nested paths to represent ownership or containment.

**Example:**

```http
GET /customers/{customer_id}/orders/{order_id}
POST /products/{product_id}/versions
```

> Use nesting to clarify relationships between resources.

---

## 📌 3. Resource Identification

### ✅ Use Resource IDs in Path

- Use **path parameters** to identify a specific resource.
- Do **not** repeat the same ID in the request body.

**Example:**

```http
GET /products/123
```

**Avoid:**

```http
POST /products/versions  → body: { "product_id": 123 }
```

> If the parent resource is in the path, there's no need to repeat it in the payload.

---

## 📌 4. HTTP Method Semantics

| Method   | Usage                        |
| -------- | ---------------------------- |
| `GET`    | Retrieve resource(s)         |
| `POST`   | Create new resource          |
| `PUT`    | Update or replace a resource |
| `PATCH`  | Partially update a resource  |
| `DELETE` | Remove a resource            |

> Choose the method that clearly reflects the operation intent.

---

## 📌 5. Consistent URL Structure

### ✅ General URL Pattern

```
/{resource}/{resource_id}/{subresource}/{subresource_id}
```

### ✅ Examples

```http
GET    /products                    → List all products
GET    /products/123                → Get product 123
POST   /products                   → Create a new product
POST   /products/123/versions      → Add a version to product 123
GET    /products/123/versions      → List all versions of product 123
```

---

## 📌 6. API Versioning

### ✅ Use URI or Header Versioning

- URI-based:

  ```
  /v1/products/123
  ```

- Header-based (preferred by GitHub, Microsoft):

  ```
  GET /products/123
  X-API-Version: 2022-11-28
  ```

> Versioning ensures backward compatibility and stable evolution of APIs.

---

## 📌 7. Avoid Verbs in URLs

### ❌ Avoid action verbs in path names

- **Bad**: `/getProducts`, `/createUser`
- **Good**: `/products`, `/users`

> Actions should be expressed through HTTP methods, not the path.

---

## 📌 8. Response Structure

### ✅ Use consistent and predictable JSON structure

```json
{
  "id": 123,
  "name": "Standard VM",
  "created_at": "2025-06-12T12:34:56Z"
}
```

### ✅ For list endpoints:

```json
{
  "items": [
    { "id": 1, "name": "Item A" },
    { "id": 2, "name": "Item B" }
  ],
  "total": 2
}
```

---

## 📌 9. Filtering, Sorting, and Pagination

### ✅ Support query parameters for:

- **Filtering**:

  - `GET /products?status=active` — for enum-like fields (e.g., `status = ['active', 'archived', 'draft']`)
  - `GET /products?enabled=true` — for Boolean fields

    Used widely in production APIs to filter for "enabled", "active", or "archived" states.

    #### 🌍 Real-world references:

    - GitHub: [`GET /repos?archived=false`](https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#list-repositories-for-a-user)
    - Stripe: [`GET /customers?active=true`](https://stripe.com/docs/api/customers/list)
    - Google Cloud: [`GET /projects?enabled=true`](https://cloud.google.com/resource-manager/reference/rest/v1/projects/list)
    - Shopify: [`GET /products?published_status=published`](https://shopify.dev/docs/api/admin-rest/2024-01/resources/product#get-products)

- **Sorting**:

  - `GET /products?sort=created_at`
  - Support descending with `-created_at` if possible (e.g., `ordering=-created_at` in DRF)

- **Pagination**:
  - Page-based: `GET /products?page=2&page_size=20`
  - Cursor-based (if supported): `GET /products?cursor=abc123&limit=50`

> ℹ️ Per [Microsoft REST API guidelines](https://github.com/microsoft/api-guidelines/blob/vNext/Guidelines.md#98-pagination), use:
>
> - `top` and `skip` for client-driven paging
> - `maxpagesize` as a server hint for controlling response size

---

## 📌 10. Error Handling

### ✅ Use standardized HTTP status codes

| Code | Meaning               |
| ---- | --------------------- |
| 200  | OK                    |
| 201  | Created               |
| 400  | Bad Request           |
| 401  | Unauthorized          |
| 403  | Forbidden             |
| 404  | Not Found             |
| 409  | Conflict              |
| 500  | Internal Server Error |

### ✅ Include error details in response body:

```json
{
  "error": "InvalidInput",
  "message": "The 'name' field is required."
}
```

> Microsoft recommends including `x-ms-request-id` in error responses for traceability.
> As part of sre we will add a request-id like x-e2e-request-io for the requests can be traced.

---

## 📌 10a. Editing the OpenAPI spec

**`public/openapi.json` is a build artifact.** Do not edit it directly — edits will be wiped on the next `make openapi` and CI's bundle-in-sync check will fail the PR.

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

**Adding, renaming, or removing an endpoint:**

1. Edit the relevant YAML under `public/openapi/paths/<tag>.yaml`.
2. Add / rename / remove the corresponding `match()` arm in `src/http/router.zig`.
3. Update `src/http/route_manifest.zig` (same (method, path) surface the sync gate asserts).
4. Run `make openapi` — bundles YAML → JSON, runs Redocly lint, runs `check_openapi_errors.py`, asserts router ↔ openapi.json parity. One target, one gate.
5. Commit YAML + bundled JSON + `router.zig` + `route_manifest.zig` together.

**Agent-edit recipe:** see `public/openapi/AGENTS.md` for copy-paste-ready rename / append / remove / update-description workflows for autonomous agents.

---

## 📌 10b. Handler Signature Contract

Every HTTP handler in `zombied` follows a fixed shape. This contract is enforced by `make lint` and by the comptime wrappers in `src/http/handlers/hx.zig`. Keep this section open when writing any new handler.

### The handler signature

```zig
pub fn innerMyEndpoint(hx: Hx, req: *httpz.Request, ...path_params) void {
    // validation
    // db / state work
    // response via hx.ok / hx.fail
}
```

Rules:

- **Name prefix `inner`** (never `handle`). The `invokeXxx` shim in `route_table_invoke.zig` is the only public entry point — your function is the inner implementation it calls after the middleware chain has populated `hx`.
- **First parameter: `hx: Hx`** — never `ctx: *Context`, `res: *Response`, `req_id: []const u8`, or an arena allocator. All of those live inside `hx`.
- **Second parameter: `req: *httpz.Request`** — only if you actually read it (body, query, headers). Drop it if you only need path params.
- **Path params come after `req`** — as declared in the `Route` enum variant in `router.zig`.
- **Return `void`.** Errors are written to the response; never return a Zig error.

### Writing responses

**Success:**

```zig
hx.ok(.ok, .{ .zombie_id = id, .status = "active" });
hx.ok(.created, .{ .agent_id = id, .key = raw_key });
hx.ok(.accepted, .{ .status = "accepted", .event_id = event_id });
```

**Errors from the registry:**

```zig
hx.fail(ec.ERR_INVALID_REQUEST, "workspace_id must be a valid UUIDv7");
hx.fail(ec.ERR_FORBIDDEN, "Workspace access denied");
hx.fail(ec.ERR_ZOMBIE_NOT_FOUND, ec.MSG_ZOMBIE_NOT_FOUND);
```

The error-code registry (`src/errors/error_registry.zig`) owns the HTTP status, RFC 7807 `title`, and `docs_uri`. Your handler only supplies the code and a human-readable `detail`.

**Internal 500s (DB / operation failure):**

```zig
common.internalDbUnavailable(hx.res, hx.req_id);   // pool.acquire failed
common.internalDbError(hx.res, hx.req_id);         // query failed
common.internalOperationError(hx.res, "detail", hx.req_id);
```

These are NOT wrapped on `Hx` — call them directly.

### What NOT to do

- ❌ `handleMyEndpoint(ctx, req, res)` — old signature, don't add new ones.
- ❌ Building an arena inside the handler — `hx.alloc` is already request-scoped.
- ❌ Calling `common.authenticate` — the middleware chain already did this; use `hx.principal`.
- ❌ `common.errorResponse(hx.res, ...)` — use `hx.fail(...)`.
- ❌ `hx.res.json(body, .{})` or `res.status = 200; res.body = "{}"` — use `hx.ok(.ok, body)`. Only acceptable for SSE streams and Slack's "ack-and-drop" pattern.
- ❌ Returning a Zig error from the handler — write to `hx.res` and return void.

**Exception (streaming):** SSE handlers (`agent_relay.zig`, `runs/stream.zig`) write `hx.res.chunk(...)` directly because `hx.ok` is JSON-only.

---

## 📌 10c. Registering a Route

Five places, in order:

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

5. **`public/openapi/paths/<tag>.yaml`** — add the endpoint (see §10a).

### Middleware policy table

Pick the right policy at step 3:

| Policy | When |
|--------|------|
| `auth_mw.MiddlewareRegistry.none` | Public endpoint; no auth, or handler does its own (OAuth callbacks, webhooks) |
| `registry.bearer()` | Standard user-facing endpoint; workspace-scoped |
| `registry.admin()` | Admin-only (internal telemetry, platform keys) |
| `registry.operator()` | Operator role required |
| `registry.webhookHmac()` | Approval webhook (HMAC-signed body) |
| `registry.slack()` | Slack events/interactions (Slack signature) |

Middleware runs BEFORE your handler: token verification, `hx.principal` population, and 401/403 short-circuits are already handled when your `inner*` runs. For `none` policy routes, `hx.principal` is zero-valued — do not read it.

### Reference implementations

- **Simple list/get:** `zombie_api.zig::innerListZombies`
- **POST with body + validation:** `zombie_api.zig::innerCreateZombie`
- **DELETE with idempotency:** `zombie_api.zig::innerDeleteZombie`
- **Admin-only:** `admin_platform_keys_http.zig::innerGetAdminPlatformKeys`
- **Multi-method router (GET/PUT/DELETE on one path):** `workspace_credentials_http.zig`
- **Workspace auth + tenant context:** `zombie_telemetry.zig::innerZombieTelemetry`
- **Webhook with inline auth:** `webhooks.zig::innerReceiveWebhook`
- **Streaming (SSE):** `agent_relay.zig::innerRelay`

### Raw-handler exceptions

Some endpoints bypass `authenticated()` — they must carry an explanatory comment at the top of the file:

- `webhooks.zig` — HMAC-verified, not Bearer auth: `// HMAC-verified — does not use hx.authenticated()`.
- `github_callback.zig` — OAuth callback: `// OAuth callback — does not use hx.authenticated()`.
- `health.zig` — health endpoints (obviously unauthenticated).
- `agent_relay.zig`, `runs/stream.zig` — streaming handlers: `// Streaming handler — does not use hx.authenticated()`.
- `auth_sessions_http.zig` — per-function treatment (login + poll are unauthenticated, complete is authenticated).

---

## 📌 10d. `Hx` Struct Reference

The `Hx` struct (defined in `src/http/handlers/hx.zig`) is the request-scoped context every handler receives. Fields are passed by value — `Hx` is five pointer-sized fields on the stack.

### Struct definition

```zig
pub const Hx = struct {
    alloc:     std.mem.Allocator,       // request-scoped arena
    principal: common.AuthPrincipal,    // set by bearer/admin middleware
    req_id:    []const u8,              // unique request ID
    ctx:       *common.Context,         // pool, queue, oidc, telemetry, app_url
    res:       *httpz.Response,         // response writer

    /// Acquire a Postgres connection from the pool.
    /// Caller must call hx.releaseDb(conn) when done.
    pub fn db(self: Hx) !*pg.Conn;

    /// Release a Postgres connection back to the pool.
    pub fn releaseDb(self: Hx, conn: *pg.Conn) void;

    /// Redis client reference — no allocation.
    pub fn redis(self: Hx) *queue_redis.Client;

    /// Write a successful JSON response (standard envelope).
    pub fn ok(self: Hx, status: std.http.Status, body: anytype) void;

    /// Write a problem+json error response (RFC 7807).
    /// Code owns its HTTP status via the error registry.
    pub fn fail(self: Hx, code: []const u8, detail: []const u8) void;
};
```

### `authenticated()` comptime wrapper

Used by every standard Bearer-authenticated handler with no path params:

```zig
pub fn authenticated(
    comptime inner: fn (hx: Hx, req: *httpz.Request) void,
) fn (*common.Context, *httpz.Request, *httpz.Response) void;
```

The wrapper:
1. Sets up an arena allocator (freed on return).
2. Generates a request ID.
3. Calls `common.authenticate` — returns 401 on failure.
4. Builds `Hx` and calls `inner(hx, req)`.

Zero runtime overhead — a new concrete function is emitted per call site.

### `authenticatedWithParam()` comptime wrapper

For handlers that receive one path param (e.g. `zombie_id`, `workspace_id`):

```zig
pub fn authenticatedWithParam(
    comptime inner: fn (hx: Hx, req: *httpz.Request, param: []const u8) void,
) fn (*common.Context, *httpz.Request, *httpz.Response, []const u8) void;
```

Handlers with two or more path params (e.g. `webhooks.zig`'s `zombie_id` + `url_secret`) do NOT use this wrapper — they stay raw.

### Guardrails

- `hx.zig` must stay ≤ 150 lines. Methods are one-liners that delegate to `common.zig`. No business logic in `hx.zig`.
- A new method on `Hx` is only justified when ≥2 converted handlers need it. One-off helpers stay in the handler file.
- Zero `ArenaAllocator.init` calls in converted handler files. All arena setup lives inside `authenticated()` / `authenticatedWithParam()`.

### Testing checklist

Before opening a PR touching a handler:

- [ ] `zig build` clean
- [ ] `make test-auth` passes (200/200)
- [ ] `zig build test` passes
- [ ] Cross-compile: `zig build -Dtarget=x86_64-linux && zig build -Dtarget=aarch64-linux`
- [ ] `make lint` — all Zig gates pass (RULE FLL 350 lines, check-pg-drain, zlint)
- [ ] Handler file ≤ 350 lines; split if it grows
- [ ] Integration test covers happy path + at least one error path per `hx.fail` call
- [ ] OpenAPI updated — new endpoint + response schema
- [ ] `gitleaks detect` clean

---

## 📌 11. Security Considerations

- Use HTTPS for all endpoints.
- Use OAuth2 or token-based authentication.
- Avoid sending sensitive IDs in the body if they are already part of the path.
- Use [UUID7](https://uuid7.com) for ID
- Avoid sending sensitive tokens in the body but send them as cookie
.

## 📌 12. Performance Considerations

Measure

- P99 Latency < 200 ms
- P95 Latency < 150 ms

---

## 📌 12. Reference Specifications

- [Google API Design Guide](https://cloud.google.com/apis/design)
- [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines)
- [GitHub REST API Docs](https://docs.github.com/en/rest)
- [OpenAPI Specification](https://swagger.io/specification/)
- [Heroku JSON API Style Guide](https://devcemter.heroku.comgithub.com/interagent/http-api-design)
