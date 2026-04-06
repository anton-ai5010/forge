# API Patterns Reference

Supplementary reference for the `api-design` skill. Load when you need specifics.

## HTTP Methods & Status Codes

| Action | Method | URL | Success | Not Found |
|--------|--------|-----|---------|-----------|
| List | GET | /resources | 200 | — |
| Get one | GET | /resources/:id | 200 | 404 |
| Create | POST | /resources | 201 | — |
| Full update | PUT | /resources/:id | 200 | 404 |
| Partial update | PATCH | /resources/:id | 200 | 404 |
| Delete | DELETE | /resources/:id | 204 | 404 |

### Error Status Codes

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

## URL Naming Rules

- Plural nouns: `/users` not `/user`
- kebab-case: `/order-items` not `/orderItems`
- No trailing slashes
- No file extensions: `/users` not `/users.json`
- IDs in URL, filters in query: `/users?role=admin` not `/admin-users`

## Response Envelopes

```jsonc
// Option A: Direct response (simpler, recommended for most APIs)
{"id": "123", "name": "Anton", "email": "anton@example.com"}

// Option B: Envelope (when you need metadata)
{"data": {"id": "123", "name": "Anton"}, "meta": {"request_id": "abc-123"}}
```

Create requests should return the created resource with `201` + `Location` header.

## Filtering & Sorting

```
GET /products?category=electronics&min_price=100&max_price=500
GET /products?sort=-created_at              # descending
GET /products?sort=price                    # ascending
GET /products?sort=-price,name              # multi-field
GET /products?q=keyboard                    # search
```

## Offset Pagination (when needed)

```json
{
  "data": [],
  "pagination": {
    "page": 2,
    "per_page": 20,
    "total": 156,
    "total_pages": 8
  }
}
```

## Versioning

```
# URL prefix (simplest, recommended)
/v1/users
/v2/users

# Header (cleaner URLs, harder to test)
Accept: application/vnd.api+json;version=2
```

When to version: breaking changes to response shape, removed fields, changed semantics.
When NOT to version: adding new fields (backward compatible), new endpoints.

## Rate Limiting Headers

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1620000000

# When exceeded → 429 Too Many Requests
Retry-After: 30
```
