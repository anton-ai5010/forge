---
description: Initialize FORGE project documentation - creates docs/ structure with index.md, status.md, decisions.md, dead-ends/, journal.md, and library/ mirror
---

# FORGE Initialization

**Purpose:** Create project documentation structure for context-aware development.

## Pre-Check: Documentation Already Exists?

```bash
ls docs/index.md 2>/dev/null
```

**If exists:**
```
FORGE documentation already exists at docs/

Regenerating will overwrite all docs/ files.

Type 'regenerate' to confirm, or any other key to cancel.
```

Wait for user confirmation. If not confirmed, stop.

## Pre-Check: Legacy Structure

```bash
ls docs/state.json 2>/dev/null
```

**If state.json exists but no index.md** — this is a legacy FORGE project. Migrate:
1. Read state.json, history.log, dead-ends.md
2. Create new structure with data from old files
3. Remove old files after migration
4. Tell user: "Migrated from legacy FORGE structure to v2."

## Pre-Check: Clean Conflicting Configs

```bash
ls -d .kiro/ 2>/dev/null
```

**If .kiro/ exists:**
```
Found .kiro/ directory. FORGE and Kiro may conflict.
Remove .kiro/? (yes/no)
```

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
```

```
Naming conventions? (default = language defaults)
```

## Step 4: Create Directory Structure

```bash
mkdir -p docs/plans
mkdir -p docs/library
mkdir -p docs/dead-ends
mkdir -p docs/journal-archive
```

For each source directory:
```bash
mkdir -p docs/library/{directory_name}
```

## Step 5: Generate map.json

```json
{
  "project": "{project_name}",
  "directories": {
    "{dir}/": { "files": 0, "red_zone_files": 0 }
  },
  "red_zones": []
}
```

## Step 6: Generate conventions.json

```json
{
  "language": "{language}",
  "naming": {
    "files": "{convention}",
    "classes": "{convention}",
    "functions": "{convention}",
    "constants": "{convention}"
  },
  "structure": {},
  "patterns": {},
  "decisions": {}
}
```

## Step 7: Ask Project Goal

```
Цель проекта в одно предложение?
Пример: "Магазин цифровых товаров на Yandex Market с автовыдачей ключей"
```

Wait for input. This goes into index.md.

## Step 8: Generate index.md

```markdown
# Project: {project_name}
{цель проекта из Step 7}

## Stage
Phase: init | Progress: 0%
Blocked: нет

## Current
Task: Проект инициализирован, готов к разработке
Branch: {current git branch}
Modified: -

## Session (live)
Started: {time}
Goal: Инициализация FORGE

Done:
- FORGE документация создана

Now: Готов к работе
Next: -

Errors:
-

## Last Session
{date} — Инициализация FORGE документации

## Docs
- status.md — что работает, что сломано
- decisions.md — технические решения
- dead-ends/ — провальные подходы по темам
- journal.md — последние сессии
```

## Step 9: Generate status.md

```markdown
# Status

## Working
- FORGE documentation initialized

## Broken
-

## Blocked
-
```

## Step 10: Generate decisions.md

```markdown
# Decisions

<!-- Ключевые технические решения. Формат:
## Что решили
Date: дата
Context: почему встал вопрос
Considered: какие варианты
Decision: что выбрали и почему
Revisit if: когда пересмотреть
-->
```

## Step 11: Generate journal.md

```markdown
# Journal

## {date} — Инициализация
Did: Создана FORGE документация для проекта
Result: docs/ структура готова
Next: Начать разработку
```

## Step 12: Generate library/ Documentation

For each source directory:

**{directory}/README.md** (in project folder):
```markdown
# {Directory Name}
{Simple description}
{List files with descriptions}
```

**docs/library/{directory}/spec.json:**
```json
{
  "purpose": "{what this directory is for}",
  "files": {
    "{filename}": {
      "intent": "{what and why}",
      "inputs": [],
      "outputs": "",
      "depends_on": [],
      "red_zone": false
    }
  }
}
```

Read each file to understand purpose, extract signatures, imports.

## Step 13: Create Steering Docs

### docs/product.md

```
Product context questions:
1. Зачем проект? Какую проблему решает?
2. Кто пользователь?
3. Что значит успех?
```

### docs/tech.md

Auto-generate from project analysis: stack, constraints, key decisions.

## Step 14: Configure CLAUDE.md

Add FORGE context block to CLAUDE.md:

```markdown
# FORGE Project Context

This project uses FORGE documentation system. Before any work:

1. Read `docs/index.md` — project goal, stage, current state, session context
2. Read `docs/map.json` — project structure and red zones
3. Read `docs/conventions.json` — project rules
4. Check `ls docs/dead-ends/` — failed approaches by topic
5. Read `docs/library/*/spec.json` — file-level knowledge (on demand)

DO NOT scan the filesystem or read source code before reading docs/. Everything you need is in docs/.

After completing any task, run `/forge:sync` to update documentation.
```

## Step 15: Confirm Completion

```
FORGE documentation initialized

Created:
- docs/index.md (project entry point)
- docs/status.md (what works/broken/blocked)
- docs/decisions.md (technical decisions)
- docs/dead-ends/ (failed approaches by topic)
- docs/journal.md (session history)
- docs/map.json ({N} directories, {M} red zones)
- docs/conventions.json ({language})
- docs/library/ ({N} directories documented)
- docs/product.md, docs/tech.md

Your project now has context documentation.
Claude reads ~400 tokens of index.md instead of ~40k+ source code.
```
