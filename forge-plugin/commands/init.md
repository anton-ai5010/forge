---
description: Initialize FORGE project documentation - creates docs/ structure with L0/L1/L2 context system in YAML format
---

# FORGE Initialization

**Purpose:** Create project documentation with L0/L1/L2 tiered context system.

## Pre-Check: Documentation Already Exists?

```bash
ls docs/index.yml docs/index.md 2>/dev/null
```

**If index.yml exists:**
```
FORGE v3 documentation already exists at docs/
Regenerating will overwrite all docs/ files.
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
ls docs/state.json 2>/dev/null
```

**If state.json exists:** Migrate data from v1 → v3 YAML format.

## Pre-Check: Clean Conflicting Configs

```bash
ls -d .kiro/ 2>/dev/null
```

**If .kiro/ exists:** Ask to remove (FORGE and Kiro may conflict).

## Step 1: Scan Project Structure

```bash
find . -type d \
  ! -path "*/node_modules/*" \
  ! -path "*/.git/*" \
  ! -path "*/dist/*" \
  ! -path "*/build/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/venv/*" \
  -print

find . -type f \
  ! -path "*/node_modules/*" \
  ! -path "*/.git/*" \
  ! -path "*/dist/*" \
  ! -path "*/build/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/venv/*" \
  -printf "%h\n" | sort | uniq -c
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
mkdir -p docs/plans docs/library docs/dead-ends docs/journal-archive
```

For each source directory:
```bash
mkdir -p docs/library/{directory_name}
```

## Step 5: Generate docs/map.yml (L1)

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

## Step 6: Generate docs/conventions.yml (L1)

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

## Step 6.5: Generate docs/structure.md

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

Write confirmed structure to `docs/structure.md`.

## Step 7: Ask Project Goal

```
Цель проекта в одно предложение?
Пример: "Магазин цифровых товаров на Yandex Market с автовыдачей ключей"
```

## Step 8: Generate docs/index.yml (L0)

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
    path: docs/map.yml
    tags: [structure, files, dirs, where, create, navigate, red-zone]

  conventions:
    path: docs/conventions.yml
    tags: [naming, format, style, commit, pattern, rules]

  status:
    path: docs/status.yml
    tags: [working, broken, blocked, health, state]

  decisions:
    path: docs/decisions.yml
    tags: [why, architecture, choice, tradeoff, rationale]

  dead-ends:
    path: docs/dead-ends.yml
    tags: [failed, tried, broken, doesnt-work, avoid, mistake]

  journal:
    path: docs/journal.yml
    tags: [history, last-session, previous, yesterday, when, resume]

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

## Step 9: Generate docs/status.yml (L1)

```yaml
working:
  - "FORGE documentation initialized"
broken: []
blocked: []
```

## Step 10: Generate docs/decisions.yml (L1)

```yaml
# Технические решения проекта
# Формат: id, date, decision, why, tags
entries: []
```

## Step 11: Generate docs/dead-ends.yml (L1)

```yaml
# Провальные подходы — чтобы не повторять ошибки
# L1 summary достаточно для большинства случаев
# L2 detail файл создаётся только если нужен полный анализ
entries: []
```

## Step 12: Generate docs/journal.yml (L1)

```yaml
entries:
  - date: {date}
    summary: "Инициализация FORGE"
    result: "docs/ структура создана"
    next: "Начать разработку"
    files: [docs/]
```

## Step 13: Generate library/ Documentation

For each source directory:

**docs/library/{directory}/spec.yml (L2):**
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

L0 (always loaded): `docs/index.yml` — goal, stage, task, catalog of all resources
L1 (load by tags):
- `docs/map.yml` — structure, red zones [tags: structure, files, navigate]
- `docs/conventions.yml` — naming, patterns [tags: naming, format, rules]
- `docs/status.yml` — working/broken/blocked [tags: working, broken, health]
- `docs/decisions.yml` — why we chose X [tags: why, architecture, choice]
- `docs/dead-ends.yml` — failed approaches [tags: failed, tried, avoid]
- `docs/journal.yml` — session history [tags: history, last-session, resume]
L2 (load rarely): `docs/library/*/spec.yml`, `docs/dead-ends/*.md`

DO NOT load all L1 files. Match catalog tags to current task.
DO NOT read source code before checking docs/library/spec.yml.

## Development Workflow

### Before any new work
1. `/forge:brainstorm` — clarify requirements, get approval
2. Plan saved to `docs/plans/`

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

### 14e: Show and confirm before writing

## Step 15: Confirm Completion

```
FORGE initialized (v3 — L0/L1/L2 context system)

Created:
- CLAUDE.md (project instructions)
- docs/index.yml (L0 — auto-injected, ~200 tokens)
- docs/map.yml (L1 — structure, red zones)
- docs/conventions.yml (L1 — naming, patterns)
- docs/status.yml (L1 — working/broken/blocked)
- docs/decisions.yml (L1 — technical decisions)
- docs/dead-ends.yml (L1 — failed approaches index)
- docs/journal.yml (L1 — session history)
- docs/structure.md (expected layout)
- docs/library/ ({N} directories documented as L2)

Context budget: ~200 tok/prompt (L0) + ~500 tok on-demand (L1)
```
