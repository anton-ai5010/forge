---
name: api-design
description: Use when designing REST API endpoints, creating new routes, or defining API contracts between services — structured approach to URL design, status codes, pagination, error handling, and versioning
---

# API Design

## Overview

Bad API design creates permanent tech debt. Every client that integrates with your API cements the contract. Get it right before the first consumer.

**Core principle:** Design the API from the consumer's perspective, not the database schema.

## The Iron Law

```
NO ENDPOINT IMPLEMENTATION WITHOUT API CONTRACT FIRST
```

Write the contract (URL, method, request/response shapes, status codes) before writing handler code.

## When to Use

- Designing new API endpoints
- Adding endpoints to existing API
- Defining service-to-service communication
- Reviewing API before making it public
- Migrating/versioning existing API

## Workflow

### Step 1: Define Resources (nouns, not verbs)

```
✅ /users, /orders, /products
❌ /getUsers, /createOrder, /deleteProduct
```

Resources are **nouns**. HTTP methods are the verbs:

| Action | Method | URL | Status |
|--------|--------|-----|--------|
| List | GET | /resources | 200 |
| Get one | GET | /resources/:id | 200 / 404 |
| Create | POST | /resources | 201 |
| Full update | PUT | /resources/:id | 200 / 404 |
| Partial update | PATCH | /resources/:id | 200 / 404 |
| Delete | DELETE | /resources/:id | 204 / 404 |

### Step 2: URL Structure

```
# Flat hierarchy — resources at top level
GET    /users
GET    /users/123
POST   /users

# Sub-resources — only when true ownership
GET    /users/123/orders        # Orders BELONG to user
POST   /users/123/orders

# Max 2 levels deep
❌ /users/123/orders/456/items/789/variants
✅ /order-items/789/variants    # Promote to top-level
```

**Naming rules:**
- Plural nouns: `/users` not `/user`
- kebab-case: `/order-items` not `/orderItems`
- No trailing slashes
- No file extensions: `/users` not `/users.json`
- IDs in URL, filters in query: `/users?role=admin` not `/admin-users`

### Step 3: Request/Response Shapes

**Consistent envelope (choose ONE for project):**

```jsonc
// Option A: Direct response (simpler, recommended for most APIs)
{
  "id": "123",
  "name": "Anton",
  "email": "anton@example.com"
}

// Option B: Envelope (when you need metadata)
{
  "data": { "id": "123", "name": "Anton" },
  "meta": { "request_id": "abc-123" }
}
```

**Create request → return created resource:**
```
POST /users
Request:  { "name": "Anton", "email": "anton@example.com" }
Response: { "id": "123", "name": "Anton", "email": "anton@example.com", "created_at": "..." }
Status:   201 Created
Header:   Location: /users/123
```

### Step 4: Pagination

**Two strategies:**

**Offset-based** (simple, good for small datasets):
```
GET /users?page=2&per_page=20

Response:
{
  "data": [...],
  "pagination": {
    "page": 2,
    "per_page": 20,
    "total": 156,
    "total_pages": 8
  }
}
```

**Cursor-based** (performant, good for large/real-time datasets):
```
GET /users?limit=20&cursor=eyJpZCI6MTIzfQ

Response:
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTQzfQ",
    "has_more": true
  }
}
```

**Choose cursor when:** sorting by non-unique fields, real-time data, large datasets (>10K rows), infinite scroll UI.

### Step 5: Filtering & Sorting

```
# Filtering — query params
GET /products?category=electronics&min_price=100&max_price=500

# Sorting — single param
GET /products?sort=-created_at           # descending
GET /products?sort=price                 # ascending
GET /products?sort=-price,name           # multi-field

# Searching — dedicated param
GET /products?q=keyboard
```

### Step 6: Error Handling

**Consistent error format:**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email is required",
    "details": [
      { "field": "email", "message": "must not be empty" },
      { "field": "name", "message": "must be at least 2 characters" }
    ]
  }
}
```

**Status code map:**

| Code | When |
|------|------|
| 400 | Validation error, bad request body |
| 401 | Not authenticated (no/invalid token) |
| 403 | Authenticated but not authorized |
| 404 | Resource not found |
| 409 | Conflict (duplicate, version mismatch) |
| 422 | Semantically invalid (parseable but wrong) |
| 429 | Rate limited |
| 500 | Server error (never intentionally return) |

**Never return 200 with error body.** Status codes exist for a reason.

### Step 7: Versioning (when needed)

```
# URL prefix (simplest, recommended)
/v1/users
/v2/users

# Header (cleaner URLs, harder to test)
Accept: application/vnd.api+json;version=2
```

**When to version:** Breaking changes to response shape, removed fields, changed semantics.
**When NOT to version:** Adding new fields (backward compatible), new endpoints.

### Step 8: Rate Limiting

```
# Response headers (always include)
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1620000000

# When exceeded
Status: 429 Too Many Requests
Retry-After: 30
```

## Output

After designing, produce API contract:

```yaml
# .forge/plans/api-{name}.yml
endpoints:
  - method: GET
    path: /users
    auth: required
    params: {page: int, per_page: int, role: string?}
    response: {data: User[], pagination: Pagination}
    status: [200, 401]

  - method: POST
    path: /users
    auth: required (admin)
    body: {name: string, email: string}
    response: User
    status: [201, 400, 401, 403, 409]
```

Save to `.forge/plans/` for implementation reference.

## Checklist Before Implementation

```
[ ] Resources are nouns (not verbs)
[ ] URLs are max 2 levels deep
[ ] Consistent response shape across all endpoints
[ ] All error cases return proper status codes + error body
[ ] Pagination strategy chosen (offset or cursor)
[ ] Auth required on all non-public endpoints
[ ] Rate limiting defined
[ ] API contract saved to .forge/plans/
```

## Integration

**Called after:** `forge:brainstorming` (requirements defined)
**Called before:** `forge:test-driven-development` (write endpoint tests from contract)
**Output:** API contract in `.forge/plans/api-{name}.yml`
