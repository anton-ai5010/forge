---
name: database-migrations
description: Use when modifying database schema, adding tables/columns, changing constraints, or planning data migrations — ensures zero-downtime changes and safe rollback
---

# Database Migrations

## Overview

A bad migration takes down production. A good migration is invisible to users. The difference is planning.

**Core principle:** Every migration must be reversible. If you can't roll back, you can't ship.

## The Iron Law

```
NO SCHEMA CHANGE WITHOUT MIGRATION PLAN AND ROLLBACK STRATEGY
```

## When to Use

- Adding/removing/modifying tables or columns
- Changing indexes or constraints
- Migrating data between schemas
- Renaming fields (requires expand-contract)
- Any `ALTER TABLE` in production

## Step 1: Detect Migration Tool

Check project for ORM/migration tool:

```bash
# Node.js
ls prisma/schema.prisma 2>/dev/null   # Prisma
ls drizzle.config.* 2>/dev/null        # Drizzle
grep "knex\|kysely" package.json 2>/dev/null

# Python
ls */models.py 2>/dev/null             # Django
grep "alembic\|sqlalchemy" requirements*.txt 2>/dev/null

# Go
grep "golang-migrate\|goose\|atlas" go.mod 2>/dev/null

# Ruby
ls db/migrate/ 2>/dev/null             # Rails
```

If no migration tool — recommend one before proceeding. Raw SQL migrations are a last resort.

## Step 2: Classify the Change

| Change | Risk | Pattern |
|--------|------|---------|
| Add table | Low | Direct create |
| Add nullable column | Low | Direct add |
| Add NOT NULL column | Medium | Add nullable → backfill → set NOT NULL |
| Add index | Medium | CREATE INDEX CONCURRENTLY (Postgres) |
| Remove column | High | Expand-contract |
| Rename column | High | Expand-contract |
| Change column type | High | Expand-contract |
| Remove table | High | Verify zero references → drop |

## Step 3: Write Migration

### Safe patterns (deploy directly):

**Add table:**
```sql
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_orders_user_id ON orders(user_id);
```

**Add nullable column:**
```sql
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
```

**Add index without locking (Postgres):**
```sql
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
-- CONCURRENTLY = no table lock, but slower
```

### Expand-Contract pattern (for breaking changes):

**Rename column** (`name` → `full_name`):

```
Phase 1: EXPAND (deploy)
  - Add new column: ALTER TABLE users ADD COLUMN full_name VARCHAR(255);
  - Code writes BOTH columns
  - Backfill: UPDATE users SET full_name = name WHERE full_name IS NULL;

Phase 2: MIGRATE (deploy)
  - Code reads from full_name only
  - Code still writes both (for rollback safety)

Phase 3: CONTRACT (deploy after Phase 2 is stable)
  - Remove old column: ALTER TABLE users DROP COLUMN name;
  - Code stops writing to old column
```

**Each phase = separate deployment.** Never combine phases.

### Adding NOT NULL column:

```sql
-- Step 1: Add as nullable
ALTER TABLE users ADD COLUMN role VARCHAR(20);

-- Step 2: Backfill with default
UPDATE users SET role = 'user' WHERE role IS NULL;
-- For large tables, batch:
-- UPDATE users SET role = 'user' WHERE role IS NULL AND id IN (SELECT id FROM users WHERE role IS NULL LIMIT 10000);

-- Step 3: Set constraint (after backfill complete)
ALTER TABLE users ALTER COLUMN role SET NOT NULL;
ALTER TABLE users ALTER COLUMN role SET DEFAULT 'user';
```

## Step 4: Write Rollback

**Every migration gets a rollback.** No exceptions.

```sql
-- migrate up
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

-- migrate down (rollback)
ALTER TABLE users DROP COLUMN phone;
```

For data migrations, rollback may need a backup:
```bash
# Before data migration
pg_dump -t users --data-only > users_backup_$(date +%Y%m%d).sql

# Rollback
psql < users_backup_20260406.sql
```

## Step 5: Verify

```
[ ] Migration runs cleanly on empty database
[ ] Migration runs cleanly on database with existing data
[ ] Rollback runs cleanly
[ ] No table locks during migration (use CONCURRENTLY for indexes)
[ ] Large table? Batched updates (not single UPDATE for millions of rows)
[ ] Application code handles both old and new schema during deploy
[ ] Foreign keys point to existing tables
[ ] Indexes added for new foreign keys
```

## Anti-Patterns

| Anti-Pattern | Why Bad | Do Instead |
|---|---|---|
| `DROP COLUMN` without expand-contract | Running code still reads it → errors | Three-phase expand-contract |
| `NOT NULL` without default | Existing rows fail constraint | Add nullable → backfill → set NOT NULL |
| `UPDATE` millions of rows in one tx | Locks table, blocks reads | Batch in chunks of 10K |
| No rollback script | Can't undo if broken | Always write down migration |
| `ALTER TYPE` on large table | Full table rewrite, lock | Add new column, backfill, swap |
| Test only on empty DB | Migration fails on real data | Test with production-like data |
| Multiple breaking changes in one migration | Can't rollback partially | One change per migration file |

## Large Table Migrations

For tables with >1M rows:

```sql
-- BAD: locks entire table
UPDATE users SET status = 'active' WHERE status IS NULL;

-- GOOD: batch processing
DO $$
DECLARE
  batch_size INT := 10000;
  rows_updated INT;
BEGIN
  LOOP
    UPDATE users SET status = 'active'
    WHERE id IN (
      SELECT id FROM users WHERE status IS NULL LIMIT batch_size
    );
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    EXIT WHEN rows_updated = 0;
    PERFORM pg_sleep(0.1);  -- breathing room
  END LOOP;
END $$;
```

## Output

Save migration plan to `.forge/plans/migration-{name}.md`:

```markdown
## Migration: {description}
Date: {date}
Risk: Low / Medium / High
Pattern: Direct / Expand-Contract

### Changes
1. {change description}

### Migration SQL
{forward migration}

### Rollback SQL
{reverse migration}

### Verification
- [ ] Tested on empty DB
- [ ] Tested on data copy
- [ ] Rollback tested
- [ ] No locks on large tables
```

## Integration

**Called after:** `forge:brainstorming` (schema design decided)
**Called before:** `forge:test-driven-development` (test migration behavior)
**Records to:** `.forge/decisions.yml` (schema decisions)
