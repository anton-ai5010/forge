---
description: Initialize FORGE project documentation - creates .forge/ structure with L0/L1/L2 context system in YAML format
---

# FORGE Initialization

**Purpose:** Create project documentation with L0/L1/L2 tiered context system.

## Pre-Check: Documentation Already Exists?

```bash
ls .forge/index.yml .forge/index.md 2>/dev/null
```

**If index.yml exists:**
```
FORGE v3 documentation already exists at .forge/
Regenerating will overwrite all .forge/ files.
Type 'regenerate' to confirm, or any other key to cancel.
```

**If index.md exists (legacy v2):**
```
Found FORGE v2 documentation (index.md format).
Upgrade to v3 (YAML + L0/L1/L2 context system)?
Type 'upgrade' to migrate, or 'regenerate' for fresh start.
```

If upgrading — read existing files, convert content to YAML format, preserve data.

Wait for user confirmation. If not confirmed, stop.

## Pre-Check: Legacy v1 Structure

```bash
ls .forge/state.json 2>/dev/null
```

**If state.json exists:** Migrate data from v1 → v3 YAML format.

## Pre-Check: Clean Conflicting Configs

```bash
ls -d .kiro/ 2>/dev/null
```

**If .kiro/ exists:** Ask to remove (FORGE and Kiro may conflict).

## Step 1: Scan Project (PARALLEL — dispatch subagents)

Launch 3-4 subagents simultaneously to scan the project. Do NOT scan sequentially — it's too slow.

**Agent 1: Project structure + code analysis**
```bash
find . -type d ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/__pycache__/*" ! -path "*/venv/*" ! -path "*/.next/*" -print
find . -type f ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/__pycache__/*" ! -path "*/venv/*" ! -path "*/.next/*" -printf "%h\n" | sort | uniq -c
```
Read: package.json/requirements.txt/go.mod, README, CLAUDE.md, tsconfig/pyproject.toml.
Detect: language, framework, stack, test runner, linter, build tool.

**Agent 2: Git history + code health**
```bash
git log --oneline -20
git shortlog -sn --all | head -10
grep -rn "TODO\|FIXME\|HACK\|XXX" --include='*.{ts,tsx,js,py,go}' . | head -30
```
Find: recent activity, contributors, TODOs, dead code signals.

**Agent 3: Infrastructure scan** (Step 4.5 content)
Scan: Docker (local + remote), databases, nginx, systemd, cron, external APIs.
See Step 4.5 below for full details.

**Agent 4: Source code reading** (if <50 source files)
Read each source file → extract: purpose, exports, imports, key functions.
This data feeds into .forge/library/*/spec.yml generation later.
If >50 source files — skip, will generate spec.yml incrementally.

Wait for all agents to complete. Aggregate results before proceeding.
```

## Step 2: Identify Red Zones

```
Which files are critical (red zones)?
Red zones: production code, complex algorithms, fragile integrations.
List file paths (one per line), or 'none':
```

## Step 3: Identify Language and Conventions

```
Language/framework?
Naming conventions? (default = language defaults)
```

## Step 4: Create Directory Structure

```bash
mkdir -p .forge/plans .forge/library .forge/dead-ends .forge/journal-archive
```

For each source directory:
```bash
mkdir -p .forge/library/{directory_name}
```

## Step 4.5: Scan Infrastructure

This runs as Agent 3 from Step 1 (already launched in parallel).
If Agent 3 hasn't completed yet — wait for it. Do not re-scan.

### Docker (local)

```bash
ls docker-compose.yml docker-compose.yaml Dockerfile 2>/dev/null
docker compose ps 2>/dev/null
docker compose config --services 2>/dev/null
```

If docker-compose found: document services, ports, volumes, health status.

### Docker (remote server)

```bash
# Check if SSH server is available (from ~/.ssh/config or .env)
ssh server "docker compose ls" 2>/dev/null
ssh server "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null
```

If remote containers found: document what runs where, ports, status.

### Database

```bash
# Detect DB type from configs
grep -r "DATABASE_URL\|DB_HOST\|POSTGRES\|MYSQL\|MONGO\|REDIS" .env .env.* docker-compose.yml 2>/dev/null
```

If DB found: try connecting, list tables/collections, document schema overview.
For PostgreSQL: `\dt` (tables), `\d table_name` (schema).
For MongoDB: `show collections`.
For Redis: `INFO keyspace`.

### Web Server / Reverse Proxy

```bash
# Check remote server
ssh server "nginx -T 2>/dev/null | grep -E 'server_name|proxy_pass|listen'" 2>/dev/null
ssh server "systemctl list-units --type=service --state=running" 2>/dev/null
ssh server "crontab -l" 2>/dev/null
```

### External Services

```bash
# Detect from code and configs
grep -rh "api_key\|API_KEY\|webhook\|WEBHOOK\|https://api\." .env .env.* 2>/dev/null | grep -v '#'
```

Document: which APIs, webhooks, external services the project depends on.

### Generate .forge/infrastructure.yml (L1)

```yaml
# Infrastructure detected by /forge:init
# Updated by /forge:sync when infrastructure changes

local:
  docker:
    compose_file: docker-compose.yml  # or null
    services:
      - name: app
        image: "node:20-alpine"
        ports: ["3000:3000"]
        status: running  # or stopped/not-built
        healthcheck: true
      - name: db
        image: "postgres:16"
        ports: ["5432:5432"]
        volumes: ["pgdata:/var/lib/postgresql/data"]
        status: running

remote:
  server:  # SSH alias or null if no server
    host: 192.168.31.183  # from ~/.ssh/config
    containers:
      - name: app
        status: running
        ports: ["3000:3000"]
    nginx:
      sites:
        - domain: app.example.com
          proxy_pass: "http://localhost:3000"
          ssl: true
    systemd:
      - name: app.service
        status: active
    cron:
      - schedule: "0 3 * * *"
        command: "pg_dump mydb > /backups/daily.sql"

databases:
  - type: postgresql  # or mysql, mongodb, redis, sqlite
    host: localhost  # or remote
    port: 5432
    name: mydb
    tables: 12  # count
    key_tables:
      - users (id, email, name, created_at)
      - orders (id, user_id, total, status, created_at)
    migrations: alembic  # or prisma, django, raw-sql, null
    backup: "daily at 03:00 via cron"  # or null

external_services:
  - name: "Yandex Market API"
    env_var: YM_API_KEY
    base_url: "https://api.partner.market.yandex.ru"
  - name: "Telegram Bot"
    env_var: TG_BOT_TOKEN

monitoring:
  uptime: null  # or healthchecks.io, uptimerobot
  logging: journald  # or loki, cloudwatch, file
  metrics: null  # or prometheus, grafana
```

If no infrastructure detected (pure library/CLI tool), skip this file.

Show the generated infrastructure.yml to user: "Вот что я нашёл. Что исправить?"

## Step 5: Generate .forge/map.yml (L1)

```yaml
directories:
  {dir}/:
    files: {count}
    red_zone_files: {count}
    about: "{purpose}"

red_zones:
  - path: {file_path}
    why: "{reason}"
```

## Step 6: Generate .forge/conventions.yml (L1)

```yaml
language: {language}
naming:
  files: {convention}
  classes: {convention}
  functions: {convention}
  constants: {convention}
structure:
  {dir}: "{purpose}"
patterns: {}
```

## Step 6.5: Generate .forge/structure.md

Based on detected language/framework, generate expected project structure.
Show to user and confirm before writing.

```
Рекомендуемая структура для {language/framework} проекта:
{generated structure}
Поправить? (или "ок")
```

**Structure templates by stack:**

**Node.js / TypeScript:**
```markdown
# Project Structure
## Expected Layout
src/               — source code
  components/      — UI components (if frontend)
  lib/             — shared utilities
  services/        — business logic
  types/           — TypeScript types
tests/             — tests (mirror src/)
config/            — configuration
scripts/           — build, deploy scripts
```

**Python:**
```markdown
# Project Structure
## Expected Layout
{package_name}/    — main package
  core/            — business logic
  models/          — data models
  services/        — external integrations
  utils/           — helpers
tests/             — tests (mirror package)
scripts/           — utility scripts
config/            — configuration
```

**Go:**
```markdown
# Project Structure
## Expected Layout
cmd/               — entry points
internal/          — private code
  handlers/        — HTTP/gRPC handlers
  service/         — business logic
  repository/      — data access
pkg/               — public library code
config/            — configuration
```

For other stacks — research conventions and generate accordingly.

Write confirmed structure to `.forge/structure.md`.

## Step 7: Ask Project Goal

```
Цель проекта в одно предложение?
Пример: "Магазин цифровых товаров на Yandex Market с автовыдачей ключей"
```

## Step 8: Generate .forge/index.yml (L0)

This is the CRITICAL file — auto-injected every prompt (~200 tokens).

```yaml
project: {project_name}
goal: "{цель проекта из Step 7}"
stage: init
progress: 0%
blocked: нет
stack: [{detected languages, frameworks}]

now:
  task: "Проект инициализирован, готов к разработке"
  branch: {current git branch}

catalog:
  map:
    path: .forge/map.yml
    tags: [structure, files, dirs, where, create, navigate, red-zone]

  conventions:
    path: .forge/conventions.yml
    tags: [naming, format, style, commit, pattern, rules]

  status:
    path: .forge/status.yml
    tags: [working, broken, blocked, health, state]

  decisions:
    path: .forge/decisions.yml
    tags: [why, architecture, choice, tradeoff, rationale]

  dead-ends:
    path: .forge/dead-ends.yml
    tags: [failed, tried, broken, doesnt-work, avoid, mistake]

  journal:
    path: .forge/journal.yml
    tags: [history, last-session, previous, yesterday, when, resume]

  learnings:
    path: .forge/learnings.yml
    tags: [lesson, learning, pattern, insight, remember, learned]

  infrastructure:
    path: .forge/infrastructure.yml
    tags: [docker, server, database, deploy, nginx, ssh, containers, ports, services, api, infra]

session:
  started: {time}
  goal: "Инициализация FORGE"
  done:
    - "FORGE документация создана"
  now: "Готов к работе"
  next: ""
  errors: []

last_session: "{date} — Инициализация FORGE документации"
```

## Step 9: Generate .forge/status.yml (L1)

```yaml
working:
  - "FORGE documentation initialized"
broken: []
blocked: []
```

## Step 10: Generate .forge/decisions.yml (L1)

```yaml
# Технические решения проекта
# Формат: id, date, decision, why, tags
entries: []
```

## Step 11: Generate .forge/dead-ends.yml (L1)

```yaml
# Провальные подходы — чтобы не повторять ошибки
# L1 summary достаточно для большинства случаев
# L2 detail файл создаётся только если нужен полный анализ
entries: []
```

## Step 12: Generate .forge/journal.yml (L1)

```yaml
entries:
  - date: {date}
    summary: "Инициализация FORGE"
    result: ".forge/ структура создана"
    next: "Начать разработку"
    files: [.forge/]
```

## Step 13: Generate library/ Documentation (PARALLEL)

If Agent 4 from Step 1 already read source files — use its results.
Otherwise, dispatch parallel subagents: one per source directory (max 5 concurrent).

For each source directory:

**.forge/library/{directory}/spec.yml (L2):**
```yaml
purpose: "{what this directory is for}"
files:
  {filename}:
    intent: "{what and why}"
    inputs: [{params}]
    outputs: "{return value}"
    depends_on: [{modules}]
    red_zone: false
```

**{directory}/README.md** (in project folder):
```markdown
# {Directory Name}
{Simple description}
- **{file}** — {что делает}. Получает X, возвращает Y.
```

Read each file to understand purpose, extract signatures, imports.
spec.yml: English, machine-readable.
README.md: Russian, simple language.

## Step 14: Generate CLAUDE.md

If CLAUDE.md exists — preserve user content, merge FORGE sections.

### 14a: Verify auto-detected data

```
Вот что я определил для CLAUDE.md:

**Стек:** {auto-detected}
**Структура:** {dirs with purposes}
**Red zones:** {list}
**Конвенции:** {naming}
**Тесты:** {detected or "не обнаружено"}
**Линтер:** {detected or "не обнаружено"}

Что исправить? (или "ок")
```

### 14b: Ask project-specific rules

```
Есть ли особые правила для проекта?
Примеры: "не трогать миграции", "всё через GraphQL", "Docker обязателен"
(или "нет")
```

### 14c: Ask run/test commands

```
Как запускать проект и тесты?
1. Запуск: {auto or "?"}
2. Тесты: {auto or "?"}
3. Линтер: {auto or "?"}
Исправь или "ок":
```

### 14d: Generate CLAUDE.md

```markdown
# {project_name}

{цель проекта}

## Technical Stack

{verified stack}

## Project Structure

{verified structure}

## Running

{verified commands}

## FORGE Context (L0/L1/L2)

Context is auto-injected via hook (~200 tokens per prompt).

L0 (always loaded): `.forge/index.yml` — goal, stage, task, catalog of all resources
L1 (load by tags):
- `.forge/map.yml` — structure, red zones [tags: structure, files, navigate]
- `.forge/conventions.yml` — naming, patterns [tags: naming, format, rules]
- `.forge/status.yml` — working/broken/blocked [tags: working, broken, health]
- `.forge/decisions.yml` — why we chose X [tags: why, architecture, choice]
- `.forge/dead-ends.yml` — failed approaches [tags: failed, tried, avoid]
- `.forge/journal.yml` — session history [tags: history, last-session, resume]
- `.forge/learnings.yml` — project lessons [tags: lesson, learning, insight]
- `.forge/infrastructure.yml` — Docker, servers, DBs, APIs [tags: docker, server, database, infra]
L2 (load rarely): `.forge/library/*/spec.yml`, `.forge/dead-ends/*.md`

DO NOT load all L1 files. Match catalog tags to current task.
DO NOT read source code before checking .forge/library/spec.yml.

## Development Workflow

### Before any new work
1. `/forge:brainstorm` — clarify requirements, get approval
2. Plan saved to `.forge/plans/`

### During implementation
3. TDD mandatory — failing test FIRST
4. Bite-sized commits
5. Record dead-ends IMMEDIATELY on failure

### After completing work
6. `/forge:sync` — update docs
7. `/forge:validate` — verify code vs plan

### Hard rules
- NO production code without failing test first
- NO implementation without approved brainstorming
- NO fixes without root cause analysis
- NO "done" claims without running tests
- NO skipping brainstorming even for "simple" changes

## Red Zones

{verified list}

## Conventions

{verified conventions}

## Project-Specific Rules

{rules from 14b, or remove section}

## Commands Reference

| Command | When |
|---------|------|
| `/forge:start` | Session start |
| `/forge:brainstorm` | Before features/changes |
| `/forge:design` | UI/UX design system |
| `/forge:sync` | After work — update docs |
| `/forge:validate` | Before merge |
| `/forge:cleanup` | Code quality |

## Communication

- Russian unless asked otherwise
- Concise — no fluff
- Reference code as `file_path:line_number`
- One clarifying question at a time
```

### 14e: Self-Check CLAUDE.md (built-in validation)

Before showing to user, verify the generated CLAUDE.md:

1. **Required sections present:** Technical Stack, Project Structure, Running, FORGE Context, Development Workflow, Red Zones, Conventions, Commands Reference
2. **No placeholders left:** No `{curly_braces}`, `TODO`, `TBD`, `описание...`, `???`, or `...` remaining in text
3. **Consistency:** Stack in CLAUDE.md matches `stack:` in index.yml. Red zones match Step 2 list.
4. **Size:** Total < 300 lines (~4000 tokens). If larger — trim verbose sections, keep only essentials.
5. **Correct paths:** All doc references use `.forge/` (not `docs/`)
6. **Commands table complete:** At minimum: start, brainstorm, sync, validate, cleanup
7. **No empty sections:** Every section has content. If nothing to put — remove the section entirely.

If any check fails — fix before showing to user. Do not ask about validation — just fix silently.

### 14f: Show and confirm before writing

## Step 15: Confirm Completion

```
FORGE initialized (v3 — L0/L1/L2 context system)

Created:
- CLAUDE.md (project instructions)
- .forge/index.yml (L0 — auto-injected, ~200 tokens)
- .forge/map.yml (L1 — structure, red zones)
- .forge/conventions.yml (L1 — naming, patterns)
- .forge/status.yml (L1 — working/broken/blocked)
- .forge/decisions.yml (L1 — technical decisions)
- .forge/dead-ends.yml (L1 — failed approaches index)
- .forge/journal.yml (L1 — session history)
- .forge/structure.md (expected layout)
- .forge/library/ ({N} directories documented as L2)

Context budget: ~200 tok/prompt (L0) + ~500 tok on-demand (L1)
```
