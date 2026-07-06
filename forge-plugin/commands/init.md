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

**Agent 5: Build code knowledge graph** (if graphify installed)
```bash
if which graphify &>/dev/null; then
  graphify update . 2>&1 | tail -3
  mkdir -p .forge
  cp graphify-out/graph.json .forge/graph.json 2>/dev/null
  cp graphify-out/GRAPH_REPORT.md .forge/graph-report.md 2>/dev/null
  echo "Graph: $(python3 -c "import json; d=json.load(open('.forge/graph.json')); print(len(d.get('nodes',d.get('elements',{}).get('nodes',[]))))" 2>/dev/null || echo '?') nodes"
fi
```
If graphify is not installed — skip silently. Graph is optional but recommended for large projects.

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

  direction:
    path: .forge/direction.yml
    tags: [direction, goal, strategy, hypotheses, backlog, navigate, where-to-go]
    note: "Strategic layer — project map (parts by step + honest status), directions/hypotheses toward the goal, deferred backlog, goal-shift history. Read + written by the project-unblocker navigator."

  infrastructure:
    path: .forge/infrastructure.yml
    tags: [docker, server, database, deploy, nginx, ssh, containers, ports, services, api, infra]

  graph:
    path: .forge/graph.json
    tags: [graph, dependencies, architecture, navigate, code-map, imports, calls]
    note: "Code knowledge graph (graphify). Use: graphify query/path/explain --graph .forge/graph.json"

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

## Step 12.5: Generate .forge/direction.yml (L1 — strategic layer)

Strategic navigation layer (machine-readable, for Claude). Goal/stage are NOT duplicated here — they are canonical in `index.yml` (L0). This file holds only strategy that lives nowhere else: directions toward the goal, deferred backlog, and a light goal-shift history. Filled and maintained by the `project-unblocker` navigator skill.

On fresh init, write the empty skeleton — the navigator fills it on first run:

```yaml
# Стратегический слой для Клода (петля навигатора).
# Цель и стадия НЕ дублируются — канон в index.yml (goal/stage, они в L0).
map: []          # карта проекта: части по шагам со статусом (part, status: known|half|unsure|unknown|todo|risk, note)
directions: []   # все направления к цели, кратко (name, why, kind: hypothesis|blocker|build, priority)
backlog: []      # отложенные направления — банк (name, why_deferred)
goal_shift: []   # лёгкая история смещения цели (date, from, to, why)
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

## Development Workflow (6-фазный pipeline: 0 → 1 → 1.5 → 2 → 3 → 4)

### Phase 0 — Direction
0. `/forge:unblocker` — навигатор направления, когда непонятно КУДА двигать проект или застрял: карта проекта + все направления + рекомендация, первый шаг → `/forge:new-task`

### Phase 1 — Understanding
1. `/forge:new-task` — превратить сырой промпт в чистую задачу + критерий готовности

### Phase 1.5 — Idea Check
1.5. `/forge:refine-idea` — реалити-чек самой идеи до плана: та ли проблема, нет ли пути проще, что сломает; на каждую слабость — конкретная альтернатива

### Phase 2 — Planning
2. `/forge:plan` — построить план с чекпоинтами (рекурсия на дальние блокеры через отдельные сессии)

### Phase 3 — Critique
3. `/forge:critique` — 4 параллельных персоны рвут план + дописывают execution strategy

### Phase 4 — Implementation
4. `/forge:execute` — реализация, грязная работа делегируется субагентам, стоп на чекпоинтах плана

### After completing work
5. `/forge:sync` — update docs
6. `/forge:validate` — verify code vs plan

### Auto-handoff между фазами
По "ОК" пользователя — Claude автоматически переходит в следующую фазу. "Стоп" / "пауза" — останавливает. Между Phase 3 и Phase 4 — если контекст уже большой, рекомендуется открыть свежий чат для `/execute`.

### Эволюция плагина под проект
- `/forge:hookify` — превратить повторное исправление в постоянное правило (`.forge/hookrules/`)
- `/forge:evolve` — раз в 2 недели кластеризовать сквозные боли и предложить автоматизацию

### Hard rules
- NO production code without a finalized plan (`/critique` complete)
- NO implementation without approved task statement (`/new-task` complete)
- NO fixes without root cause analysis
- NO "done" claims without running tests
- NO skipping `/new-task` even for "simple" changes

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
| `/forge:unblocker` | **Phase 0** — навигатор направления: куда двигать проект |
| `/forge:new-task` | **Phase 1** — раскрутить сырую задачу |
| `/forge:refine-idea` | **Phase 1.5** — реалити-чек идеи до плана |
| `/forge:plan` | **Phase 2** — построить план |
| `/forge:critique` | **Phase 3** — 4 персоны рвут план |
| `/forge:execute` | **Phase 4** — реализация |
| `/forge:hookify` | Превратить повторение в правило |
| `/forge:evolve` | Кластеризация сквозных болей |
| `/forge:design` | UI/UX design system |
| `/forge:sync` | After work — update `.forge/*.yml` |
| `/forge:validate` | Before merge — verify code vs plan |
| `/forge:cleanup` | Code quality audit |
| `/forge:investigate` | Problem diagnosis before fixing |
| `/forge:product-map` | Project navigator (HTML) |
| `/forge:explain` | Visual "how does X work?" (HTML) |
| `/forge:roadmap` | Карта целей (milestones) на GitHub — при включённом GitHub sync |

Полезные **встроенные** команды Claude Code:
- `/btw <вопрос>` — side-вопрос, ответ в overlay, не попадает в историю
- `/clear` — очистить контекст
- `/compact` — сжать историю

## Communication

- Russian unless asked otherwise
- Concise — no fluff
- Reference code as `file_path:line_number`
- One clarifying question at a time
```

Строку `/forge:roadmap` включай только если у проекта есть GitHub remote (`git remote -v`) — команда осмысленна лишь при GitHub sync (Step 16). Иначе убери её из таблицы.

### 14e: Self-Check CLAUDE.md (built-in validation)

Before showing to user, verify the generated CLAUDE.md:

1. **Required sections present:** Technical Stack, Project Structure, Running, FORGE Context, Development Workflow, Red Zones, Conventions, Commands Reference
2. **No placeholders left:** No `{curly_braces}`, `TODO`, `TBD`, `описание...`, `???`, or `...` remaining in text
3. **Consistency:** Stack in CLAUDE.md matches `stack:` in index.yml. Red zones match Step 2 list.
4. **Size:** Total < 300 lines (~4000 tokens). If larger — trim verbose sections, keep only essentials.
5. **Correct paths:** All doc references use `.forge/` (not `docs/`)
6. **Commands table complete:** At minimum: start, unblocker (Phase 0), new-task, refine-idea (Phase 1.5), plan, critique, execute, sync, validate, cleanup
7. **No empty sections:** Every section has content. If nothing to put — remove the section entirely.

If any check fails — fix before showing to user. Do not ask about validation — just fix silently.

### 14f: Show and confirm before writing

## Step 15: Configure .claude/ project settings

Set up Claude Code environment: hooks, permissions, rules, gitignore.

### 15a: Find forge plugin path

```bash
FORGE_HOOKS=$(find ~/.claude/plugins -path '*/forge*/hooks/context-inject.sh' 2>/dev/null | head -1)
echo "Found: $FORGE_HOOKS"
```

### 15b: Create/update .claude/settings.json

```bash
mkdir -p .claude
```

Read existing `.claude/settings.json` if exists. MERGE (don't overwrite) these settings:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "bash {FORGE_HOOKS_PATH}"
        }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{
          "type": "command",
          "command": "[ \"$(git branch --show-current)\" != \"main\" ] && [ \"$(git branch --show-current)\" != \"master\" ] || { echo 'BLOCKED: Do not edit files on main/master. Create a feature branch first.' >&2; exit 2; }"
        }]
      }
    ]
  },
  "permissions": {
    "deny": [
      "Bash(rm -rf /)",
      "Bash(git push --force*)",
      "Bash(git reset --hard*)"
    ]
  },
  "language": "ru"
}
```

**Merge rules:**
- If `.claude/settings.json` exists — read first, preserve existing settings
- If `hooks.UserPromptSubmit` already has FORGE hook — don't duplicate
- Append to existing `permissions.deny`, don't replace
- Don't overwrite user's `permissions.allow`
- If `language` already set — keep user's choice

### 15c: Create .claude/rules/ (path-scoped instructions)

Create rules that activate only when working on specific files:

**`.claude/rules/testing.md`** (if project has tests):
```yaml
---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/__tests__/**"
---

Follow TDD: write failing test first, then minimal implementation.
Use descriptive test names: "should [expected] when [condition]".
No mocks unless external dependency. Clean up in afterEach.
```

**`.claude/rules/api-routes.md`** (if project has API routes):
```yaml
---
paths:
  - "src/app/api/**"
  - "src/routes/**"
  - "api/**"
---

Every endpoint: validate input, check auth, handle errors.
Return consistent shape. Use proper HTTP status codes.
Never expose internal errors to client.
```

**`.claude/rules/red-zones.md`** (if red zones identified in Step 2):
```yaml
---
paths:
  - "{red_zone_paths from Step 2}"
---

RED ZONE FILE. Extra care required:
- Read the entire file before any change
- Write tests BEFORE modifying
- Make minimal changes only
- Get explicit user approval before editing
```

Only create rules that are relevant to the detected stack. Don't create rules
for frameworks the project doesn't use.

### 15d: Configure .gitignore

```bash
# Personal Claude files — never commit
for pattern in '.claude/settings.local.json' '.claude/agent-memory-local/' 'CLAUDE.local.md'; do
  grep -qF "$pattern" .gitignore 2>/dev/null || echo "$pattern" >> .gitignore
done

# .forge/ (память проекта: задачи, планы, решения, журнал) ИДЁТ в git —
# она должна переживать смерть диска (скилл memory-backup пушит её на удалёнку).
# Игнорируется только служебный runtime-мусор — внутри .forge/.gitignore:
mkdir -p .forge
[ -f .forge/.gitignore ] || cat > .forge/.gitignore <<'EOF'
.inject-state
.last-backup
.migration-declined
state.yml
.github-*
graph.json
EOF
```

Note: `.forge/` — память проекта, её ценность именно в истории и сохранности;
runtime-мусор отсечён через `.forge/.gitignore`. Секреты в `.forge` не пишутся
никогда — только названия записей Bitwarden. `.claude/settings.json` SHOULD be
committed (team hooks/permissions). Only `.claude/settings.local.json` is personal.

### 15e: Verify hook works

```bash
echo '{"input":"test"}' | bash {FORGE_HOOKS_PATH}
```

If output contains `"FORGE L0 CONTEXT"` — hook is configured correctly.

## Step 16: Configure GitHub Sync (optional)

Wire up GitHub integration so the project map, Issues per task, and README header
work out of the box. All `gh` logic lives in one script — just call it.

### 16a: Find sync.sh

```bash
SYNC=$(find ~/.claude/plugins -path '*/forge*/skills/github-sync/sync.sh' 2>/dev/null | head -1)
```

If not found — skip this whole step silently (plugin layout changed; GitHub sync unavailable).

### 16b: Should we even offer it?

```bash
bash "$SYNC" should-offer
```

- Output `no` → project has no GitHub remote, or `gh` missing/not authed. **Skip silently** —
  GitHub sync is optional and the project works fine without it. Do NOT nag.
- Output `yes` → there's a GitHub remote and `gh` is authed but `github_sync` not set yet. Ask:

```
Этот проект на GitHub. Включить синхронизацию?
Тогда forge будет вести карту проекта Issue'ами: задача → Issue, шаги плана → sub-issues,
плюс Pinned Issue «🗺 Карта проекта» и авто-шапка в README.
(да / нет)
```

If user says no → `bash "$SYNC" disable` (writes `github_sync: false`, so we don't ask again). Done.

### 16c: Enable and bootstrap (only if user said yes)

```bash
bash "$SYNC" enable            # github_sync: true в .forge/index.yml
bash "$SYNC" diagnose          # громкая проверка auth/scope — покажи вывод пользователю
bash "$SYNC" bootstrap-labels  # 6 forge-лейблов (идемпотентно)
bash "$SYNC" ensure-pinned-map # создать/найти Pinned Issue «🗺 Карта проекта»
```

If `diagnose` prints warnings (auth expired, no scope) — surface them verbatim and tell the user
to run `gh auth login`, then re-run `/forge:init` or just `/forge:roadmap`. Don't silently continue.

After this, the pipeline (new-task → plan → critique → execute) mirrors to GitHub automatically.

## Step 17: Confirm Completion

```
FORGE initialized (v5 — L0/L1/L2 context system)

Created:
- CLAUDE.md (project instructions)
- .forge/index.yml (L0 — auto-injected, ~200 tokens)
- .forge/map.yml (L1 — structure, red zones)
- .forge/conventions.yml (L1 — naming, patterns)
- .forge/status.yml (L1 — working/broken/blocked)
- .forge/decisions.yml (L1 — technical decisions)
- .forge/dead-ends.yml (L1 — failed approaches index)
- .forge/journal.yml (L1 — session history)
- .forge/direction.yml (L1 — strategic layer: directions, backlog, goal-shift)
- .forge/infrastructure.yml (L1 — Docker, servers, DBs, APIs)
- .forge/graph.json (code knowledge graph — if graphify installed)
- .forge/structure.md (expected layout)
- .forge/library/ ({N} directories documented as L2)

Configured:
- .claude/settings.json — UserPromptSubmit hook (L0 auto-inject)
- GitHub sync — {включён: Issues + Pinned карта + README шапка / пропущен: нет remote или gh / отключён пользователем}

Context budget: ~200 tok/prompt (L0) + ~500 tok on-demand (L1)

Хук настроен — L0 контекст будет инжектиться в каждый промпт автоматически.
```

Replace the GitHub sync line with the actual outcome from Step 16:
- enabled → `GitHub sync — включён: задачи и карта проекта будут зеркалиться в Issues`
- offered but declined → `GitHub sync — отключён (можно включить позже через /forge:roadmap)`
- not applicable → omit the line entirely
