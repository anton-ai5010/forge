# FORGE: Финальная спецификация v2

## Общая архитектура

### Плагин Forge (устанавливается в Claude Code)
```
forge/
├── .claude-plugin/
│   ├── plugin.json           # name: "forge", version, author
│   └── marketplace.json
├── agents/
│   ├── code-reviewer.md      # от Forge (с изменениями)
│   └── forge-documenter.md   # НОВЫЙ — документатор на Sonnet
├── commands/
│   ├── brainstorm.md         # → /forge:brainstorm
│   ├── execute-plan.md       # → /forge:execute-plan
│   ├── write-plan.md         # → /forge:write-plan
│   ├── sync.md               # НОВЫЙ → /forge:sync
│   └── init.md               # НОВЫЙ → /forge:init
├── hooks/
│   ├── hooks.json
│   └── session-start.sh      # инжектит using-forge/SKILL.md
├── skills/
│   ├── using-forge/                    # переименован из using-forge
│   ├── brainstorming/
│   ├── writing-plans/
│   ├── executing-plans/
│   ├── subagent-driven-development/
│   ├── test-driven-development/
│   ├── systematic-debugging/
│   ├── requesting-code-review/
│   ├── receiving-code-review/
│   ├── dispatching-parallel-agents/
│   ├── finishing-a-development-branch/
│   ├── using-git-worktrees/
│   ├── verification-before-completion/
│   ├── writing-skills/
│   └── forge-context/                  # НОВЫЙ
├── docs/
│   └── windows/
└── README.md
```

### Документация в проекте пользователя (создаётся через /forge:init)
```
docs/
├── map.json              # карта проекта + красные зоны
├── conventions.json      # правила проекта
├── state.json            # текущее состояние (перезаписывается при sync)
├── history.log           # лог сессий (append-only, Claude не читает)
├── plans/                # дизайн-документы (создаются brainstorming → writing-plans)
└── library/              # для Claude (машинночитаемое)
    ├── indicators/
    │   └── spec.json     # для Claude, машинночитаемый
    ├── strategies/
    │   └── spec.json
    └── ml/
        └── spec.json

indicators/               # README.md прямо в папках проекта
├── macd.py
├── rsi.py
└── README.md             # для человека, русский, простым языком

strategies/
├── rsi_strategy.py
└── README.md

ml/
├── model.py
└── README.md
```

---

## Часть 1: Конкретные изменения в каждом скилле

---

### 1. using-forge → using-forge

**Файл:** `skills/using-forge/SKILL.md`

**Что менять:** Добавить в конец файла, перед секцией "Skill Types", новую секцию:

```markdown
## FORGE Project Context

Before any work, check if project has `docs/map.json`. If yes:

1. Read `docs/map.json` — project structure and red zones
2. Read `docs/conventions.json` — project rules
3. Read `docs/state.json` — current state and pending tasks

After completing any task, suggest: "Run /forge:sync to update documentation."

If project has no `docs/map.json`, suggest: "Run /forge:init to set up project documentation."
```

**Глобальная замена:** `forge` → `forge` во всём файле.

---

### 2. brainstorming

**Файл:** `skills/brainstorming/SKILL.md`

**Изменение 1 — чеклист, пункт "Explore project context":**

БЫЛО:
```
Explore project context — check files, documentation, recent commits
```

СТАЛО:
```
Explore project context:
  - Read docs/map.json — project structure and red zones
  - Read docs/conventions.json — project rules
  - Read docs/state.json — current state
  - Only then, if deeper context needed — read specific files from map
```

**Изменение 2 — после "Explore project context", новый пункт:**

```
Confirm understanding of goal — restate in your own words WHY we are doing this
and WHAT the expected outcome is. Get explicit confirmation before proceeding.
```

**Изменение 3 — в секцию "Present design in sections", добавить:**

```
Before presenting design:
- Check docs/map.json for red zones. If design touches red zone files —
  warn user explicitly: "This design modifies [file] which is marked as red zone.
  Confirm before proceeding."
- Check docs/library/[folder]/spec.json for dependencies of affected modules.
  If change cascades to other modules — show this in design:
  "Changing [X] will affect [Y] and [Z] because [dependency]."
```

**Изменение 4 — новое правило перед "Invoke writing-plans":**

```
If design document exceeds 150 lines — propose splitting into
multiple independent designs. Each design = one complete feature
that can be implemented and tested separately.
```

**Глобальная замена:** `forge:` → `forge:` во всех ссылках на скиллы.

---

### 3. writing-plans

**Файл:** `skills/writing-plans/SKILL.md`

**Изменение 1 — секция "Execution Handoff", заменить два варианта на три:**

БЫЛО:
```
**1. Subagent-Driven (this session)**
**2. Parallel Session (separate)**
```

СТАЛО:
```
**1. Subagent-Driven (this session)** — I dispatch fresh subagent per task,
review between tasks, fast iteration. You stay and watch.
- REQUIRED SUB-SKILL: Use forge:subagent-driven-development

**2. Batch execution (separate session)** — Open new terminal, Claude executes
tasks in batches of 3, pauses for your feedback between batches.
- REQUIRED SUB-SKILL: New session uses forge:executing-plans

**3. Autonomous (separate session)** — Open new terminal, Claude executes through
subagents with auto-review. Works as autonomously as possible. You check results when done.
- REQUIRED SUB-SKILL: New session uses forge:subagent-driven-development
- Provide ready-to-copy command for second terminal
```

**Изменение 2 — в заголовке плана:**

БЫЛО:
```
> **For Claude:** REQUIRED SUB-SKILL: Use forge:executing-plans
```

СТАЛО:
```
> **For Claude:** REQUIRED SUB-SKILL: Use forge:executing-plans or forge:subagent-driven-development
```

**Глобальная замена:** `forge:` → `forge:`

---

### 4. subagent-driven-development

**Файл:** `skills/subagent-driven-development/SKILL.md`

**Изменение 1 — в процессе, после "Code quality reviewer subagent approves? → yes", добавить новый шаг перед "Mark task complete":**

```
Dispatch forge-documenter subagent (Sonnet):
  - Receives: implementer's report (files changed, what was done) + git diff
  - Updates: docs/library/[folders]/spec.json for affected folders
  - Updates: docs/library/[folders]/README.md for affected folders
  - Updates: docs/map.json if new files created or files deleted
```

**Изменение 2 — в секцию "Integration", добавить:**

```
**FORGE documentation:**
- **forge:forge-context** — Subagents read docs/library/[folder]/spec.json before work
- **forge:sync** — Manual update for state.json at end of session
- **forge-documenter** agent — Automatic doc update after each task's review
```

**Изменение 3 — в "Prompt Templates", добавить:**

```
- `./forge-documenter-prompt.md` - Dispatch documentation updater subagent
```

**Глобальная замена:** `forge:` → `forge:`

---

### 5. executing-plans

**Файл:** `skills/executing-plans/SKILL.md`

**Изменение — в "Step 3: Report", добавить после "Show verification output":**

```
- Update docs/library/[folders]/spec.json and README.md for files changed in this batch
- Update docs/map.json if new files were created
```

**Глобальная замена:** `forge:` → `forge:`

---

### 6. code-reviewer (agent)

**Файл:** `agents/code-reviewer.md`

**Изменение — в "Review Checklist", добавить новую секцию после "Requirements":**

```markdown
**FORGE Compliance:**
- Does code follow conventions from docs/conventions.json?
- Do changes align with file intent described in docs/library/[folder]/spec.json?
- Are dependent modules (from docs/map.json) not broken by changes?
- Do file naming and structure follow project patterns?
```

---

### 7. finishing-a-development-branch

**Файл:** `skills/finishing-a-development-branch/SKILL.md`

**Изменение — между "Step 1: Verify Tests" и "Step 2: Determine Base Branch", add new step:**

```markdown
### Step 1.5: Update Documentation

Run /forge:sync to ensure documentation is up to date before merge.
Verify docs/map.json, docs/library/ reflect all changes made in this branch.
```

**Глобальная замена:** `forge:` → `forge:`

---

### 8. dispatching-parallel-agents

**Файл:** `skills/dispatching-parallel-agents/SKILL.md`

**Изменение — в "4. Review and Integrate", добавить после "Integrate all changes":**

```
- Update docs/library/ for all folders affected by parallel agents
- Update docs/map.json if any agent created new files
```

**Глобальная замена:** `forge:` → `forge:`

---

### 9. implementer-prompt.md

**Файл:** `skills/subagent-driven-development/implementer-prompt.md`

**Изменение — в секцию "## Context", добавить:**

```
## Project Context

Before starting work, read:
- docs/library/[your-working-folder]/spec.json — file intents and dependencies
- docs/conventions.json — project rules to follow
```

---

### Скиллы: только глобальная замена forge → forge

- `skills/test-driven-development/SKILL.md`
- `skills/test-driven-development/testing-anti-patterns.md`
- `skills/systematic-debugging/SKILL.md`
- `skills/systematic-debugging/root-cause-tracing.md`
- `skills/systematic-debugging/defense-in-depth.md`
- `skills/requesting-code-review/SKILL.md`
- `skills/receiving-code-review/SKILL.md`
- `skills/verification-before-completion/SKILL.md`
- `skills/using-git-worktrees/SKILL.md`
- `skills/writing-skills/SKILL.md`
- `skills/writing-skills/anthropic-best-practices.md`
- `skills/writing-skills/testing-skills-with-subagents.md`
- `skills/writing-skills/persuasion-principles.md`
- `skills/subagent-driven-development/spec-reviewer-prompt.md`
- `skills/subagent-driven-development/code-quality-reviewer-prompt.md`

---

## Часть 2: Новые компоненты

### 1. /forge:init (команда)

**Файл:** `commands/init.md`

**Что делает:**
- Сканирует структуру проекта
- Создаёт `docs/` с map.json, conventions.json, state.json
- Создаёт `docs/library/` с spec.json для каждой папки
- Создаёт README.md прямо в папках проекта (для человека)
- Спрашивает пользователя: какие файлы отметить как red zone?
- Спрашивает: какие конвенции уже есть? (именование, структура, паттерны)

### 2. /forge:sync (команда)

**Файл:** `commands/sync.md`

**Что делает:**
- Читает `git diff HEAD~1` (или от последнего sync)
- Обновляет docs/library/[папки]/spec.json для изменённых файлов
- Обновляет [папки]/README.md в папках проекта для изменённых файлов
- Обновляет docs/map.json если новые файлы или удалённые
- Перезаписывает docs/state.json с текущим состоянием
- Добавляет строку в docs/history.log

### 3. forge-context (скилл)

**Файл:** `skills/forge-context/SKILL.md`

**Что делает:**
- Загружается при старте сессии (ссылка из using-forge)
- Читает docs/map.json, docs/conventions.json, docs/state.json
- Даёт Claude полный контекст проекта за ~2k токенов

### 4. forge-documenter (агент)

**Файл:** `agents/forge-documenter.md`

```yaml
---
name: forge-documenter
description: Updates project documentation after code changes
model: sonnet
tools: Read, Write, Edit, Bash, Glob, Grep
---
```

**Что делает:**
- Получает отчёт имплементатора + git diff
- Обновляет spec.json в docs/library/ и README.md в папках проекта
- Обновляет map.json
- Работает на Sonnet (дешёво и быстро)

### 5. forge-documenter-prompt.md (шаблон промпта)

**Файл:** `skills/subagent-driven-development/forge-documenter-prompt.md`

**Шаблон:**
```
Task tool (forge:forge-documenter):
  description: "Update documentation for Task N changes"
  prompt: |
    You are updating project documentation after code changes.

    ## What Changed
    [From implementer's report: files created, modified, deleted]

    ## Git Diff
    [Output of git diff for this task's commits]

    ## Your Job
    1. For each CREATED file:
       - Add entry to docs/library/[folder]/spec.json
       - Update [folder]/README.md (in project folder)
       - Add to docs/map.json
    2. For each MODIFIED file:
       - Update description in docs/library/[folder]/spec.json
       - Update [folder]/README.md if behavior changed
    3. For each DELETED file:
       - Remove from docs/library/[folder]/spec.json
       - Remove from [folder]/README.md
       - Remove from docs/map.json

    ## Format for spec.json entries
    {
      "filename.py": {
        "intent": "What this file does and WHY it exists",
        "inputs": ["param: type"],
        "outputs": "What it returns",
        "depends_on": ["modules it imports"],
        "red_zone": false
      }
    }

    ## Format for README.md
    Write in simple language, no code. Explain what each file does
    so a non-technical person understands the folder's purpose.

    ## Report
    - Files documented: [list]
    - map.json updated: yes/no
```

---

## Часть 3: Форматы файлов

### docs/map.json
```json
{
  "project": "project_name",
  "directories": {
    "indicators/": { "files": 5, "red_zone_files": 1 },
    "strategies/": { "files": 3, "red_zone_files": 2 },
    "ml/": { "files": 8, "red_zone_files": 4 },
    "utils/": { "files": 6, "red_zone_files": 0 }
  },
  "red_zones": [
    "indicators/rsi.py",
    "strategies/rsi_strategy.py",
    "ml/model.py"
  ]
}
```

### docs/conventions.json
```json
{
  "language": "python",
  "naming": {
    "files": "snake_case",
    "classes": "PascalCase",
    "functions": "snake_case",
    "constants": "UPPER_SNAKE_CASE"
  },
  "structure": {
    "indicators": "Each indicator is a pure function in its own file",
    "strategies": "Each strategy inherits BaseStrategy",
    "tests": "Mirror source structure in tests/ folder"
  },
  "patterns": {
    "new_indicator": "Create file in indicators/, add export to __init__.py, add test",
    "new_strategy": "Create file in strategies/, inherit BaseStrategy, add backtest"
  },
  "decisions": {
    "pandas_not_polars": "Existing codebase uses pandas, migration not worth it",
    "websocket_not_rest": "Real-time data feed requires persistent connection"
  }
}
```

### docs/state.json
```json
{
  "current_task": "Add MACD indicator",
  "progress": "3/5 tasks done",
  "last_session": "2026-02-15",
  "last_session_summary": "Added MACD calculation, wrote tests, need to connect to strategy",
  "pending": [
    "Connect MACD to RSI strategy",
    "Add backtest for MACD"
  ],
  "recent_changes": [
    "indicators/macd.py — new file",
    "tests/test_macd.py — new file"
  ]
}
```

### docs/library/[folder]/spec.json
```json
{
  "purpose": "Technical analysis indicators — pure functions calculating indicators from price data",
  "files": {
    "macd.py": {
      "intent": "Calculate MACD indicator (fast EMA - slow EMA + signal line)",
      "inputs": ["df: DataFrame", "fast: int=12", "slow: int=26", "signal: int=9"],
      "outputs": "DataFrame with macd, signal, histogram columns",
      "depends_on": ["pandas"],
      "red_zone": false
    },
    "rsi.py": {
      "intent": "Calculate RSI indicator using Wilder's smoothing method",
      "inputs": ["df: DataFrame", "period: int=14"],
      "outputs": "DataFrame with rsi column",
      "depends_on": ["pandas"],
      "red_zone": true,
      "red_zone_reason": "Production strategy depends on exact calculation"
    }
  }
}
```

### [folder]/README.md (в папке проекта)
```markdown
# Индикаторы

В этой папке лежат индикаторы технического анализа.
Каждый индикатор — отдельная функция в своём файле.

- **macd.py** — считает MACD (схождение-расхождение скользящих средних)
- **rsi.py** — считает RSI (индекс относительной силы). ⚠️ Красная зона — от этого расчёта зависит рабочая стратегия.
- **bollinger.py** — считает полосы Боллинджера
```

README.md находится прямо в папке проекта (indicators/README.md), а не в docs/library/.

---

## Часть 4: Порядок реализации (задачи для Claude Code)

### Фаза 1 — Переименование и очистка
1. Глобальная замена `forge` → `forge` во всех файлах
2. Переименовать `skills/using-forge/` → `skills/using-forge/`
3. Обновить `session-start.sh` — путь к using-forge
4. Обновить `.claude-plugin/plugin.json` — name: "forge"
5. Заменить "the user" / "Jesse" → "user" / "пользователь" где встречается

### Фаза 2 — Изменения в существующих скиллах
6. using-forge — добавить секцию FORGE Project Context
7. brainstorming — 4 изменения (контекст, цель, красные зоны, лимит 150 строк)
8. writing-plans — 3 варианта исполнения
9. subagent-driven-development — четвёртый шаг документатора
10. executing-plans — обновление доков после батча
11. code-reviewer agent — секция FORGE Compliance
12. finishing-a-development-branch — шаг 1.5 sync перед мёржем
13. dispatching-parallel-agents — обновление доков после интеграции
14. implementer-prompt — секция Project Context

### Фаза 3 — Новые компоненты
15. Создать commands/init.md
16. Создать commands/sync.md
17. Создать skills/forge-context/SKILL.md
18. Создать agents/forge-documenter.md
19. Создать skills/subagent-driven-development/forge-documenter-prompt.md

### Фаза 4 — Тестирование
20. Протестировать на реальном проекте (Football Predictor)
