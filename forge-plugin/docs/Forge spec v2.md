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
│   ├── forge-documenter.md   # НОВЫЙ — документатор на Sonnet
│   └── critique/             # 4 персоны для Phase 3
│       ├── skeptic.md
│       ├── pragmatist.md
│       ├── architect.md
│       └── user-advocate.md
├── commands/
│   ├── new-task.md          # → /forge:new-task     (Phase 1: Understanding)
│   ├── plan.md              # → /forge:plan         (Phase 2: Planning)
│   ├── critique.md          # → /forge:critique     (Phase 3: Critique)
│   ├── execute.md           # → /forge:execute      (Phase 4: Implementation)
│   ├── sync.md              # → /forge:sync
│   └── init.md              # → /forge:init
├── hooks/
│   ├── hooks.json
│   └── session-start.sh      # инжектит using-forge/SKILL.md
├── skills/
│   ├── using-forge/
│   ├── new-task/             # Phase 1
│   ├── plan/                 # Phase 2
│   ├── critique/             # Phase 3
│   ├── execute/              # Phase 4
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
.forge/
├── map.json              # карта проекта + красные зоны
├── conventions.json      # правила проекта
├── state.json            # текущее состояние (перезаписывается при sync)
├── history.log           # лог сессий (append-only, Claude не читает)
├── tasks/                # чистые формулировки задач (Phase 1 output)
├── plans/                # планы с чекпоинтами (Phase 2 output)
├── critiques/            # отчёты 4 персон + Execution Strategy (Phase 3 output)
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

## Пайплайн: 4 фазы

```
┌─────────────────────────┐
│  Phase 1: Understanding │  /forge:new-task
│  raw prompt → clean task│  output: .forge/tasks/<id>.md
│  + success criterion    │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  Phase 2: Planning      │  /forge:plan
│  task → plan with       │  output: .forge/plans/<id>.md
│  checkpoints + recursion│
│  on distant blockers    │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  Phase 3: Critique      │  /forge:critique
│  4 parallel personas    │  output: .forge/critiques/<id>.md
│  tear the plan apart    │  + Execution Strategy appended
│  → Execution Strategy   │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  Phase 4: Implementation│  /forge:execute
│  dirty work in subagents│  output: code + tests + docs
│  stop at checkpoints    │
└─────────────────────────┘
```

### Phase 1 — `/forge:new-task` (Understanding)

**Цель:** превратить сырой промпт в формализованную задачу с критерием успеха.

**Что делает:**
- Читает `.forge/map.json`, `.forge/conventions.json`, `.forge/state.json`.
- Переформулирует пользовательский запрос: WHY → WHAT → DONE-criterion.
- Уточняет ровно одну неясность за раз, не угадывает.
- Сохраняет результат в `.forge/tasks/<id>.md`.

**Скилл:** `skills/new-task/SKILL.md`.

### Phase 2 — `/forge:plan` (Planning)

**Цель:** разложить задачу на пошаговый план с явными чекпоинтами.

**Что делает:**
- Читает `.forge/tasks/<id>.md`.
- Строит план: шаги, ожидаемые артефакты, точки остановки (checkpoints).
- Рекурсия на дальние блокеры: если шаг зависит от непонятной/незавершённой подсистемы — спускается в неё и делает мини-план (или выносит в отдельный `/forge:new-task`).
- Помечает шаги, требующие критики персонами (например, архитектурные развилки).
- Сохраняет в `.forge/plans/<id>.md`.

**Скилл:** `skills/plan/SKILL.md`.

### Phase 3 — `/forge:critique` (Critique)

**Цель:** прогнать план через 4 параллельные персоны и зафиксировать стратегию исполнения.

**Персоны (запускаются параллельно как субагенты):**
1. **Skeptic** — ищет дыры, нереалистичные допущения, незакрытые риски.
2. **Pragmatist** — режет лишнее, требует минимально достаточного решения.
3. **Architect** — проверяет согласованность с `.forge/map.json` и `.forge/library/*/spec.json`, ловит каскадные эффекты, нарушения красных зон.
4. **User Advocate** — смотрит глазами пользователя: понятно ли, ценно ли, не сломает ли существующий UX.

**Что делает команда:**
- Запускает 4 субагента параллельно с планом на вход.
- Собирает их отчёты в `.forge/critiques/<id>.md`.
- На основе сводных правок дописывает в конце документа **Execution Strategy**: какой режим запуска (см. ниже), порядок шагов, чекпоинты, кто отвечает.
- Обновлённый план либо одобряется, либо возвращается в Phase 2 на доработку.

**Скилл:** `skills/critique/SKILL.md`.

### Phase 4 — `/forge:execute` (Implementation)

**Цель:** реализовать план, грязную работу делегировать субагентам, останавливаться на чекпоинтах.

**Что делает:**
- Читает `.forge/plans/<id>.md` и `.forge/critiques/<id>.md` (Execution Strategy).
- Идёт по шагам плана; на каждом чекпоинте — стоп, отчёт, ожидание подтверждения.
- Грязные операции (массовые правки, генерация кода, эксперименты, отладка) выносит в субагентов через `subagent-driven-development`.
- После завершения каждого шага вызывает `forge-documenter` для обновления `.forge/library/` и `[folder]/README.md`.

**Скилл:** `skills/execute/SKILL.md`.

---

## Часть 1: Конкретные изменения в каждом скилле

---

### 1. using-forge

**Файл:** `skills/using-forge/SKILL.md`

**Что менять:** Добавить в конец файла, перед секцией "Skill Types", новую секцию:

```markdown
## FORGE Project Context

Before any work, check if project has `.forge/map.json`. If yes:

1. Read `.forge/map.json` — project structure and red zones
2. Read `.forge/conventions.json` — project rules
3. Read `.forge/state.json` — current state and pending tasks

For any non-trivial request, route through the 4-phase pipeline:
`/forge:new-task` → `/forge:plan` → `/forge:critique` → `/forge:execute`.

After completing any task, suggest: "Run /forge:sync to update documentation."

If project has no `.forge/map.json`, suggest: "Run /forge:init to set up project documentation."
```

---

### 2. new-task (Phase 1)

**Файл:** `skills/new-task/SKILL.md`

**Чеклист скилла:**

```
1. Read project context:
   - .forge/map.json — project structure and red zones
   - .forge/conventions.json — project rules
   - .forge/state.json — current state
   Only then, if deeper context needed — read specific files from map.

2. Restate the request in your own words:
   - WHY we are doing this
   - WHAT the expected outcome is
   - DONE-criterion (one testable sentence)
   Get explicit confirmation before proceeding.

3. Surface red-zone collisions:
   - If the request touches files marked red zone in .forge/map.json —
     warn user explicitly and ask to confirm.

4. Save the clean task to .forge/tasks/<id>.md.

5. Suggest next step: /forge:plan <id>.
```

---

### 3. plan (Phase 2)

**Файл:** `skills/plan/SKILL.md`

**Структура плана:**

```
# Plan: <task title>

## Task
Link to .forge/tasks/<id>.md, restated DONE-criterion.

## Steps
1. <step> — artifact: <file/output> — checkpoint: <yes/no>
2. ...

## Distant blockers
- If a step depends on an unfinished / unclear subsystem,
  either embed a mini-plan here, or extract a separate task
  via /forge:new-task and link it.

## Open questions for critique
- <list of architectural forks or risky choices to surface in Phase 3>
```

**Правила:**
- Чекпоинты ставить перед необратимыми шагами и на стыках подсистем.
- Если план превышает ~150 строк или 7 шагов — предложить разбить на несколько независимых задач, каждая со своим `new-task`.
- Указать в конце: `> **For Claude:** REQUIRED SUB-SKILL: Use forge:execute (after forge:critique approves the plan).`

---

### 4. critique (Phase 3)

**Файл:** `skills/critique/SKILL.md`

**Процесс:**
1. Загрузить план из `.forge/plans/<id>.md`.
2. Параллельно запустить 4 субагента (`agents/critique/skeptic.md`, `pragmatist.md`, `architect.md`, `user-advocate.md`). Каждому на вход план + релевантные части `.forge/library/`.
3. Собрать отчёты, агрегировать пересечения, отметить противоречия между персонами.
4. Дописать в `.forge/critiques/<id>.md` секцию **Execution Strategy**:
   - Какие шаги плана корректируются и как.
   - Режим исполнения для Phase 4 (см. ниже).
   - Где обязательны чекпоинты.
   - Какие риски остаются принятыми сознательно.

**Режимы исполнения, выбираемые в Execution Strategy:**

```
1. Subagent-Driven (this session) — main agent dispatches a fresh subagent
   per step, reviews between steps, fast iteration. User stays and watches.
   REQUIRED SUB-SKILL: forge:subagent-driven-development

2. Step-by-step (separate session) — open a new terminal, Claude executes
   steps one by one with explicit checkpoint pauses.
   REQUIRED SUB-SKILL: forge:execute

3. Autonomous (separate session) — open a new terminal, Claude executes
   through subagents with auto-review, stopping only at hard checkpoints.
   REQUIRED SUB-SKILL: forge:subagent-driven-development
   Provide ready-to-copy command for the second terminal.
```

---

### 5. execute (Phase 4)

**Файл:** `skills/execute/SKILL.md`

**Процесс:**
1. Загрузить `.forge/plans/<id>.md` и `.forge/critiques/<id>.md` (Execution Strategy).
2. Идти по шагам плана; на каждом чекпоинте — отчёт + ожидание подтверждения.
3. Для грязной работы дёргать субагентов (`subagent-driven-development`).
4. После каждого шага:
   - Update `.forge/library/[folders]/spec.json` and `README.md` for files changed.
   - Update `.forge/map.json` if new files were created or files deleted.
5. По завершении — предложить `/forge:sync`.

---

### 6. subagent-driven-development

**Файл:** `skills/subagent-driven-development/SKILL.md`

**Изменение 1 — в процессе, после "Code quality reviewer subagent approves? → yes", добавить шаг перед "Mark task complete":**

```
Dispatch forge-documenter subagent (Sonnet):
  - Receives: implementer's report (files changed, what was done) + git diff
  - Updates: .forge/library/[folders]/spec.json for affected folders
  - Updates: .forge/library/[folders]/README.md for affected folders
  - Updates: .forge/map.json if new files created or files deleted
```

**Изменение 2 — в секцию "Integration", добавить:**

```
**FORGE pipeline:**
- **forge:forge-context** — Subagents read .forge/library/[folder]/spec.json before work
- **forge:execute** — Driver skill that dispatches subagents step-by-step per plan
- **forge:sync** — Manual update for state.json at end of session
- **forge-documenter** agent — Automatic doc update after each step's review
```

**Изменение 3 — в "Prompt Templates", добавить:**

```
- `./forge-documenter-prompt.md` - Dispatch documentation updater subagent
```

---

### 7. code-reviewer (agent)

**Файл:** `agents/code-reviewer.md`

**Изменение — в "Review Checklist", добавить новую секцию после "Requirements":**

```markdown
**FORGE Compliance:**
- Does code follow conventions from .forge/conventions.json?
- Do changes align with file intent described in .forge/library/[folder]/spec.json?
- Are dependent modules (from .forge/map.json) not broken by changes?
- Do file naming and structure follow project patterns?
- Does the change match the DONE-criterion from .forge/tasks/<id>.md?
```

---

### 8. finishing-a-development-branch

**Файл:** `skills/finishing-a-development-branch/SKILL.md`

**Изменение — между "Step 1: Verify Tests" и "Step 2: Determine Base Branch", add new step:**

```markdown
### Step 1.5: Update Documentation

Run /forge:sync to ensure documentation is up to date before merge.
Verify .forge/map.json, .forge/library/ reflect all changes made in this branch.
```

---

### 9. dispatching-parallel-agents

**Файл:** `skills/dispatching-parallel-agents/SKILL.md`

**Изменение — в "4. Review and Integrate", добавить после "Integrate all changes":**

```
- Update .forge/library/ for all folders affected by parallel agents
- Update .forge/map.json if any agent created new files
```

---

### 10. implementer-prompt.md

**Файл:** `skills/subagent-driven-development/implementer-prompt.md`

**Изменение — в секцию "## Context", добавить:**

```
## Project Context

Before starting work, read:
- .forge/library/[your-working-folder]/spec.json — file intents and dependencies
- .forge/conventions.json — project rules to follow
- .forge/tasks/<id>.md — the DONE-criterion you are working toward
- .forge/plans/<id>.md — the step you are implementing
```

---

### Прочие скиллы: без семантических правок

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
- Сканирует структуру проекта.
- Создаёт `.forge/` с `map.json`, `conventions.json`, `state.json`.
- Создаёт `.forge/library/` с `spec.json` для каждой папки.
- Создаёт `.forge/tasks/`, `.forge/plans/`, `.forge/critiques/` (пустые директории под пайплайн).
- Создаёт `README.md` прямо в папках проекта (для человека).
- Спрашивает: какие файлы отметить как red zone? Какие конвенции уже есть?

### 2. /forge:sync (команда)

**Файл:** `commands/sync.md`

**Что делает:**
- Читает `git diff HEAD~1` (или от последнего sync).
- Обновляет `.forge/library/[папки]/spec.json` для изменённых файлов.
- Обновляет `[папки]/README.md` в папках проекта для изменённых файлов.
- Обновляет `.forge/map.json` если новые файлы или удалённые.
- Перезаписывает `.forge/state.json` с текущим состоянием.
- Добавляет строку в `.forge/history.log`.

### 3. /forge:new-task, /forge:plan, /forge:critique, /forge:execute (команды)

Каждая команда — тонкая обёртка над соответствующим скиллом (`skills/new-task`, `skills/plan`, `skills/critique`, `skills/execute`). Команда подгружает скилл и принимает `<id>` задачи как аргумент (для plan/critique/execute) либо сырой промпт (для new-task).

### 4. forge-context (скилл)

**Файл:** `skills/forge-context/SKILL.md`

**Что делает:**
- Загружается при старте сессии (ссылка из using-forge).
- Читает `.forge/map.json`, `.forge/conventions.json`, `.forge/state.json`.
- Даёт Claude полный контекст проекта за ~2k токенов.

### 5. forge-documenter (агент)

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
- Получает отчёт имплементатора + git diff.
- Обновляет `spec.json` в `.forge/library/` и `README.md` в папках проекта.
- Обновляет `map.json`.
- Работает на Sonnet (дёшево и быстро).

### 6. critique personas (4 агента)

**Файлы:** `agents/critique/skeptic.md`, `pragmatist.md`, `architect.md`, `user-advocate.md`.

Каждый — отдельный субагент с узкой ролью, см. Phase 3. Запускаются параллельно из `/forge:critique`.

### 7. forge-documenter-prompt.md (шаблон промпта)

**Файл:** `skills/subagent-driven-development/forge-documenter-prompt.md`

**Шаблон:**
```
Task tool (forge:forge-documenter):
  description: "Update documentation for Step N changes"
  prompt: |
    You are updating project documentation after code changes.

    ## What Changed
    [From implementer's report: files created, modified, deleted]

    ## Git Diff
    [Output of git diff for this step's commits]

    ## Your Job
    1. For each CREATED file:
       - Add entry to .forge/library/[folder]/spec.json
       - Update [folder]/README.md (in project folder)
       - Add to .forge/map.json
    2. For each MODIFIED file:
       - Update description in .forge/library/[folder]/spec.json
       - Update [folder]/README.md if behavior changed
    3. For each DELETED file:
       - Remove from .forge/library/[folder]/spec.json
       - Remove from [folder]/README.md
       - Remove from .forge/map.json

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

### .forge/map.json
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

### .forge/conventions.json
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

### .forge/state.json
```json
{
  "current_task": "Add MACD indicator",
  "current_phase": "execute",
  "progress": "step 3/5 done",
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

### .forge/tasks/<id>.md
```markdown
# Task <id>: <title>

## Why
<one paragraph>

## What
<one paragraph>

## DONE-criterion
<one testable sentence>

## Touched red zones
- <file> — <reason>
```

### .forge/plans/<id>.md
```markdown
# Plan <id>: <title>

## Steps
1. <step> — artifact — checkpoint: yes/no
2. ...

## Distant blockers
- ...

## Open questions for critique
- ...
```

### .forge/critiques/<id>.md
```markdown
# Critique <id>: <title>

## Skeptic
...

## Pragmatist
...

## Architect
...

## User Advocate
...

## Execution Strategy
- Mode: subagent-driven / step-by-step / autonomous
- Checkpoints: <list>
- Accepted risks: <list>
- Plan corrections: <list>
```

### .forge/library/[folder]/spec.json
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
- **rsi.py** — считает RSI (индекс относительной силы). Красная зона — от этого расчёта зависит рабочая стратегия.
- **bollinger.py** — считает полосы Боллинджера
```

README.md находится прямо в папке проекта (`indicators/README.md`), а не в `.forge/library/`.

---

## Часть 4: Порядок реализации (задачи для Claude Code)

### Фаза A — Каркас пайплайна
1. Создать `commands/new-task.md`, `plan.md`, `critique.md`, `execute.md`.
2. Создать `skills/new-task/SKILL.md`, `plan/SKILL.md`, `critique/SKILL.md`, `execute/SKILL.md`.
3. Создать `agents/critique/{skeptic,pragmatist,architect,user-advocate}.md`.

### Фаза B — Контекст и документация
4. `skills/using-forge/SKILL.md` — добавить секцию FORGE Project Context и упоминание 4-фазного пайплайна.
5. Создать `commands/init.md`, `commands/sync.md`.
6. Создать `skills/forge-context/SKILL.md`.
7. Создать `agents/forge-documenter.md`.
8. Создать `skills/subagent-driven-development/forge-documenter-prompt.md`.

### Фаза C — Изменения в существующих скиллах
9. `subagent-driven-development` — шаг документатора, интеграция с `forge:execute`.
10. `code-reviewer` — секция FORGE Compliance + проверка DONE-criterion.
11. `finishing-a-development-branch` — шаг 1.5 sync перед мёржем.
12. `dispatching-parallel-agents` — обновление доков после интеграции.
13. `implementer-prompt` — секция Project Context (task + plan).

### Фаза D — Тестирование
14. Протестировать на реальном проекте (Football Predictor): прогнать одну задачу через все 4 фазы.
