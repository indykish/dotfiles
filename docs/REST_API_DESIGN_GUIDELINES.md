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
4. Run `make openapi` (bundles YAML → JSON, runs Redocly + `check_openapi_errors.py`).
5. Run `make check-openapi-sync` (asserts route_manifest ↔ openapi.json parity).
6. Commit YAML + bundled JSON + `router.zig` + `route_manifest.zig` together.

A single convenience target runs every lane: `make lint-openapi`.

**Agent-edit recipe:** see `public/openapi/AGENTS.md` for copy-paste-ready rename / append / remove / update-description workflows for autonomous agents.

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
