---
name: api-design
description: Use when designing REST API endpoints, creating new routes, defining API contracts between services, or reviewing API surface before making it public
---

# API Design

**Role:** You are a principal API architect (14 years, designed contracts for platforms with 200+ consumer teams). Design for the consumer, not the database.
**Stakes:** Every contract is permanent — once 20 teams integrate, a breaking change triggers cascade failures across the entire platform. Get it right before the first client ships.

## Overview

Bad API design is permanent tech debt — every client that integrates cements the contract. Design from the consumer's perspective, not the database schema.

## The Iron Law

```
NO ENDPOINT IMPLEMENTATION WITHOUT API CONTRACT REVIEWED AND APPROVED
```

Write the contract. Get it reviewed. Then implement.

## Environment Check

```bash
# Detect existing API patterns in project
ls -d **/routes **/controllers **/handlers 2>/dev/null
grep -r "express\|fastify\|koa\|flask\|gin\|echo\|actix" package.json requirements*.txt go.mod Cargo.toml 2>/dev/null

# Detect existing OpenAPI/Swagger specs
ls **/swagger.* **/openapi.* 2>/dev/null

# Check for existing pagination patterns
grep -r "cursor\|page\|offset\|per_page\|limit" --include="*.ts" --include="*.py" -l 2>/dev/null | head -5
```

Match existing project conventions before inventing new ones.

## Process

### Step 1: Define Resources

Resources are nouns. HTTP methods are verbs. Max 2 levels deep.

```
✅ GET /users/123/orders      — orders BELONG to user
❌ GET /users/123/orders/456/items/789  — promote to /order-items/789
❌ GET /getUsers               — verbs belong in HTTP methods
```

### Step 2: Write the Contract

```yaml
# .forge/plans/api-{name}.yml
endpoints:
  - method: GET
    path: /users
    auth: required
    params: {limit: int, cursor: string?, role: string?}
    response: {data: User[], pagination: CursorPagination}
    status: [200, 401]

  - method: POST
    path: /users
    auth: required (admin)
    body: {name: string, email: string}
    response: User
    status: [201, 400, 401, 403, 409]
```

### Step 3: Choose Pagination Strategy

```
Offset or Cursor?

                    ┌─────────────────────┐
                    │ Dataset > 10K rows?  │
                    └────┬───────────┬─────┘
                         │Yes        │No
                         ▼           ▼
                    ┌─────────┐  ┌──────────┐
                    │ Cursor  │  │ Real-time │
                    │         │  │ data?     │
                    └─────────┘  └──┬────┬───┘
                                 Yes│    │No
                                    ▼    ▼
                              ┌────────┐ ┌────────┐
                              │ Cursor │ │ Offset │
                              └────────┘ └────────┘
```

**Cursor-based** (prefer by default):
```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTQzfQ",
    "has_more": true
  }
}
```

Offset is simpler but breaks when data changes between pages. Use offset only for small, stable datasets with "jump to page N" requirement.

### Step 4: Define Error Shape

Pick ONE error format for the entire API:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email is required",
    "details": [
      {"field": "email", "message": "must not be empty"}
    ]
  }
}
```

**Never return 200 with an error body.** Use proper status codes (see `api-patterns.md` for full reference).

### Step 5: Get Contract Reviewed

Before writing any handler code:
- Share contract with consuming team / frontend dev
- Verify naming consistency across existing endpoints
- Confirm auth requirements per endpoint

## Rationalizations (excuses to skip contract-first)

| Excuse | Reality |
|--------|---------|
| "It's just a small internal endpoint" | Internal endpoints become external. Contract takes 5 minutes. |
| "We'll iterate on the API later" | Every consumer locks you in. V2 costs 10x more than getting V1 right. |
| "The frontend dev is me, I'll just adjust" | Future-you in 3 months won't remember why the shape is weird. |
| "We need to ship fast" | Debugging API mismatches costs more than 15 min of contract writing. |
| "It mirrors the database schema exactly" | Consumers don't care about your schema. Design for their use case. |

## Red Flags

Stop if you're thinking:

- "Let me just expose the database model directly" — API shapes serve consumers, not storage
- "We can add pagination later" — retrofitting pagination is a breaking change
- "PUT and PATCH do the same thing here" — pick one, document it, be consistent
- "I'll just return 200 for everything" — clients need status codes for error handling
- "Nobody else will use this API" — they will, and sooner than you think

## Checklist

```
[ ] Resources are nouns, max 2 levels deep
[ ] Consistent response shape across all endpoints
[ ] Error format chosen and consistent
[ ] Pagination strategy chosen (cursor unless small+stable)
[ ] Auth required on all non-public endpoints
[ ] Contract saved to .forge/plans/api-{name}.yml
[ ] Contract reviewed before implementation starts
[ ] Versioning strategy defined (if public API)
```

## Integration

**Called after:** `forge:brainstorming` (requirements defined)
**Called before:** `forge:test-driven-development` (write endpoint tests from contract)
**Reference:** `api-patterns.md` in this directory for status codes, filtering, sorting, rate limiting, versioning details
**Output:** API contract in `.forge/plans/api-{name}.yml`
