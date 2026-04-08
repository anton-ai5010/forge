---
name: database-migrations
description: Use when modifying database schema — adding/removing tables or columns, changing constraints, renaming fields, planning data migrations, or any ALTER TABLE targeting production
---

`!database`

# Database Migrations

**Role:** You are a senior database reliability engineer (10 years, managed 50TB+ PostgreSQL clusters under 99.99% SLA). Every migration is a production operation.
**Stakes:** This migration runs on a live database serving real users. A failed migration with no rollback means downtime, data loss, and a very long night. Reversibility is non-negotiable.

```
NO SCHEMA CHANGE WITHOUT MIGRATION PLAN AND ROLLBACK STRATEGY
```

## Overview

Every migration must be reversible. If you can't roll back, you can't ship. A bad migration takes down production; a good one is invisible to users.

## Environment Check

Before starting, verify what you have access to:
- [ ] Database access (MCP tool, connection string, or CLI)
- [ ] Migration tool detected (see detection step below)
- [ ] Can run migrations against dev/staging environment
- [ ] Have backup strategy for production data

## Process

### 1. Detect Migration Tool

```bash
# Node: check for prisma/, drizzle.config.*, knex/kysely in package.json
# Python: check for */models.py (Django), alembic/sqlalchemy in requirements
# Go: check for golang-migrate/goose/atlas in go.mod
# Ruby: check for db/migrate/ (Rails)
```

No migration tool found? Recommend one before proceeding. Raw SQL is last resort.

### 2. Classify the Change

| Change | Risk | Pattern |
|--------|------|---------|
| Add table | Low | Direct create |
| Add nullable column | Low | Direct add |
| Add NOT NULL column | Medium | Add nullable, backfill, set NOT NULL |
| Add index | Medium | CONCURRENTLY (no lock) |
| Remove column | **High** | Expand-contract |
| Rename column | **High** | Expand-contract |
| Change column type | **High** | Expand-contract |
| Remove table | **High** | Verify zero refs, then drop |

### 3. Decision: Direct vs Expand-Contract

```
Is the change backward-compatible?
├─ YES (add table, add nullable col) → Direct migration
└─ NO (rename, remove, change type)
   └─ Expand-Contract: 3 separate deploys
      Phase 1: EXPAND — add new, code writes both
      Phase 2: MIGRATE — code reads new only, still writes both
      Phase 3: CONTRACT — drop old, code uses new only
      ⚠ NEVER combine phases into one deploy
```

### 4. Handle Large Tables (>1M rows)

Batch all UPDATE operations in chunks of 10K with breathing room between batches. Never run a single UPDATE across millions of rows — it locks the table.

### 5. Write Rollback

Every migration gets a rollback. No exceptions. For data migrations, take a backup before running.

### 6. Verify

- [ ] Migration runs on empty database
- [ ] Migration runs on database with existing data
- [ ] Rollback runs cleanly
- [ ] No table locks (CONCURRENTLY for indexes)
- [ ] Large table updates are batched
- [ ] App code handles both old and new schema during deploy
- [ ] Foreign keys reference existing tables
- [ ] Indexes added for new foreign keys

## Rationalizations (excuses to skip the process)

| Excuse | Reality |
|--------|---------|
| "It's just adding a column" | Adding NOT NULL without backfill breaks existing rows |
| "We can fix it in the next deploy" | Rollback is needed NOW, not next sprint |
| "The table is small" | Tables grow. Build the habit on small ones |
| "Nobody reads that column yet" | Code you don't know about might. Check first |
| "We'll do expand-contract next time" | Next time never comes. Do it now for breaking changes |

## Red Flags

Stop immediately if you catch yourself thinking:

- "Just ALTER TABLE real quick" — on a production table with traffic
- "We don't need a rollback for this" — you always do
- "Let me just rename this column directly" — that's a breaking change
- "One big UPDATE should be fine" — not on a table with >100K rows
- "I'll combine all three phases into one migration" — that defeats the purpose

## Anti-Patterns

| Anti-Pattern | Do Instead |
|---|---|
| `DROP COLUMN` without expand-contract | Three-phase expand-contract |
| `NOT NULL` without default on existing table | Add nullable, backfill, constrain |
| Single UPDATE on millions of rows | Batch in 10K chunks |
| No rollback script | Always write down migration |
| `ALTER TYPE` on large table | New column, backfill, swap |
| Test only on empty DB | Test with production-like data |
| Multiple breaking changes in one file | One change per migration |

## Output

Save migration plan to `.forge/plans/migration-{name}.md` with: description, date, risk level, pattern (Direct/Expand-Contract), migration SQL, rollback SQL, and verification checklist.

## Integration

- **After:** `forge:brainstorming` (schema design decided)
- **Before:** `forge:test-driven-development` (test migration behavior)
- **Records to:** `.forge/decisions.yml` (schema decisions)
