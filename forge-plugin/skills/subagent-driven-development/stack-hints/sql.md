# SQL / Database Stack Hints

Inject when task involves database work, or `.forge/conventions.yml` mentions PostgreSQL, MySQL, SQLite.

## Query Patterns

- CTEs (`WITH`) for readability over nested subqueries
- Window functions for ranking/running totals: `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`
- `COALESCE(col, default)` over `CASE WHEN col IS NULL`
- `EXISTS` over `IN` for correlated subqueries (usually faster)
- `EXPLAIN ANALYZE` before and after optimization — don't guess

## Index Design

- Index columns used in `WHERE`, `JOIN`, `ORDER BY`
- Composite index: left-to-right column order matters (`(a, b)` helps `WHERE a=? AND b=?` and `WHERE a=?`, NOT `WHERE b=?`)
- Covering index: include all `SELECT` columns to avoid table lookup
- Partial index for filtered queries: `CREATE INDEX ... WHERE status = 'active'`
- Don't index: low-cardinality columns (boolean), frequently updated columns, small tables

## Anti-Patterns

- `SELECT *` in production code — list columns explicitly
- N+1 queries — use `JOIN` or batch `WHERE id IN (...)`
- Missing `LIMIT` on potentially large result sets
- String concatenation in queries — use parameterized queries
- `ORDER BY RANDOM()` on large tables — sample differently
- Missing foreign key indexes (PG doesn't auto-create them)

## PostgreSQL Specific

- `JSONB` for semi-structured data (not `JSON` — `JSONB` is indexed)
- `uuid_generate_v4()` or `gen_random_uuid()` for UUIDs
- `CREATE INDEX CONCURRENTLY` — no table lock
- `LISTEN/NOTIFY` for lightweight pub/sub
- `pg_stat_statements` for query performance analysis
- Row-level security for multi-tenant

## Transactions

- Keep transactions short — don't hold locks during I/O
- `SERIALIZABLE` only when needed — default `READ COMMITTED` is usually fine
- `SELECT ... FOR UPDATE` to prevent concurrent modification
- `ON CONFLICT DO UPDATE` for upserts (not select-then-insert)
- Advisory locks for application-level coordination

## Migration Safety

(See `forge:database-migrations` for full process)
- Add columns nullable, backfill, then constrain
- `CREATE INDEX CONCURRENTLY` — never block reads
- Batch large updates in chunks
- Expand-contract for breaking changes
