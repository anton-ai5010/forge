# forge-plugin

Плагин для Claude Code, автоматизирующий рабочие процессы разработки через систему скиллов и L0/L1/L2 контекста.

## Technical Stack

- **JavaScript (Node.js)** — ядро плагина (skills-core.js)
- **Python** — BM25 поиск для UI/UX дизайна
- **Markdown** — скиллы, команды, документация
- **Claude Code Plugin System** — runtime

## Project Structure

```
forge-plugin/              — корневая директория плагина
  lib/                     — JS утилиты (skills-core.js)
  hooks/                   — хуки SessionStart + UserPromptSubmit
  agents/                  — промпт-шаблоны субагентов
  commands/                — 20 команд (MD файлы)
  skills/                  — 27 скиллов (SKILL.md + поддержка)
  docs/                    — спецификация, архитектура
  tests/                   — тестовые промпты
ideas/                     — идеи и предложения
.forge/                    — FORGE контекст (L0/L1/L2)
```

## Running

- **Запуск:** плагин загружается автоматически через Claude Code Plugin System
- **Тесты:** prompt-based — субагентные pressure tests в `forge-plugin/tests/`
- **Линтер:** нет

## FORGE Context (L0/L1/L2)

Context is auto-injected via hook (~200 tokens per prompt).

L0 (always loaded): `.forge/index.yml` — goal, stage, task, catalog of all resources
L1 (load by tags):
- `.forge/map.yml` — structure [tags: structure, files, navigate]
- `.forge/conventions.yml` — naming, patterns [tags: naming, format, rules]
- `.forge/status.yml` — working/broken/blocked [tags: working, broken, health]
- `.forge/decisions.yml` — why we chose X [tags: why, architecture, choice]
- `.forge/dead-ends.yml` — failed approaches [tags: failed, tried, avoid]
- `.forge/journal.yml` — session history [tags: history, last-session, resume]
- `.forge/learnings.yml` — project lessons [tags: lesson, learning, insight]
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

### Coding principles (Karpathy-style)

**Think before coding:** Don't assume — ask. State assumptions explicitly. If unclear — stop and clarify, don't guess. Present multiple interpretations when ambiguous.

**Simplicity first:** Minimum code that solves the problem. Nothing speculative. No unrequested features, no single-use abstractions, no unnecessary configurability, no error handling for impossible scenarios. Three identical lines are better than a premature abstraction.

**Surgical changes:** Touch only what you must. Don't improve adjacent code, don't fix unrelated issues, don't add docstrings to code you didn't change. Match existing style. Every changed line should trace directly to the request.

**Goal-driven execution:** Transform vague requests into testable objectives. Not "add validation" but "write tests for invalid inputs, then make them pass". Not "fix the bug" but "write a test reproducing it, then fix it". Define success criteria, loop until verified.

## Conventions

- **Файлы/директории:** kebab-case
- **JS функции/переменные:** camelCase
- **Python функции/переменные:** snake_case
- **Константы:** UPPER_SNAKE_CASE
- **Скиллы:** директория + SKILL.md внутри
- **Команды:** kebab-case MD файлы

## Commands Reference

| Command | When |
|---------|------|
| `/forge:start` | Session start |
| `/forge:brainstorm` | Before features/changes |
| `/forge:sync` | After work — update docs |
| `/forge:validate` | Before merge |
| `/forge:cleanup` | Code quality |
| `/forge:discover` | Search marketplace |
| `/forge:graph` | Code knowledge graph |
| `/forge:product-map` | Project navigator (HTML) |
| `/forge:explain` | Visual "how does X work?" (HTML) |
| `/forge:investigate` | Problem diagnosis before fixing |
| `/forge:session-insights` | Session patterns analysis |

## Communication

- Russian unless asked otherwise
- Concise — no fluff
- Reference code as `file_path:line_number`
- One clarifying question at a time
