# forge-plugin

Плагин для Claude Code, автоматизирующий рабочие процессы разработки через 4-фазный pipeline + систему скиллов + L0/L1/L2 контекст.

## Technical Stack

- **JavaScript (Node.js)** — `lib/skills-core.js` (используется только в OpenCode тестах, в Claude Code — bash хуки)
- **Bash** — хуки (`hooks/*.sh`)
- **Python** — BM25 поиск для UI/UX дизайна
- **Markdown** — скиллы, команды, документация, output styles
- **Claude Code Plugin System** — runtime

## Project Structure

```
forge-plugin/              — корневая директория плагина
  .claude-plugin/          — manifest (plugin.json, marketplace.json)
  lib/                     — JS утилиты (legacy, для OpenCode)
  hooks/                   — bash хуки (session-start, context-inject, bash-safety, statusline)
  agents/                  — промпт-шаблоны субагентов
  commands/                — slash-команды (MD файлы)
  skills/                  — ~27 скиллов (SKILL.md + поддержка)
  output-styles/           — нативный Output Style "Forge Concise" (auto-activated)
  evals/                   — Hamel-style eval-сетап: корпус, критерии, transition matrix
  sounds/                  — mp3 для Stop / PermissionRequest хуков
  docs/                    — спецификация, архитектура, runtime-flow
  tests/                   — prompt-based тесты + opencode тесты
ideas/                     — идеи и прототипы (pipeline-v2.html и др.)
.forge/                    — FORGE контекст (L0/L1/L2, gitignored)
```

## Running

- **Запуск:** плагин загружается автоматически через Claude Code Plugin System
- **Тесты:** prompt-based в `forge-plugin/tests/skill-triggering/` + bash в `tests/opencode/`
- **Линтер:** нет

## FORGE Context (L0/L1/L2)

Context auto-injected via `hooks/context-inject.sh` (~250 tokens per prompt — только L0 + branch + git log + graph hint).

ROUTING и DOC DISCIPLINE инжектятся **один раз** через `session-start.sh`. STYLE правил больше нет в хуке — они в нативном Output Style.

**L0 (always loaded):** `.forge/index.yml` — goal, stage, task, catalog of all resources

**L1 (load by tags from catalog):**
- `.forge/map.yml` — structure [tags: structure, files, navigate]
- `.forge/conventions.yml` — naming, patterns [tags: naming, format, rules]
- `.forge/status.yml` — working/broken/blocked [tags: working, broken, health]
- `.forge/decisions.yml` — why we chose X [tags: why, architecture, choice]
- `.forge/dead-ends.yml` — failed approaches [tags: failed, tried, avoid]
- `.forge/journal.yml` — session history [tags: history, last-session, resume]
- `.forge/learnings.yml` — project lessons [tags: lesson, learning, insight]

**L2 (load rarely):** `.forge/library/*/spec.yml`, `.forge/dead-ends/*.md`

DO NOT load all L1 files. Match catalog tags to current task.
DO NOT read source code before checking `.forge/library/spec.yml`.

Подробная процедура загрузки контекста — в скилле `forge-context`.

## Development Workflow — 4-фазный pipeline

### Phase 1 — Understanding (`/forge:new-task`)
Сырой промпт → чистая задача + критерий готовности. Логические вопросы пользователю по одному, технические — Claude ищет сам в коде/доках. Опциональный HTML-набросок если пользователь буксует.

**Выход:** `.forge/tasks/YYYY-MM-DD-<slug>.md` с секциями `## Задача` и `## Критерий готовности`.

### Phase 2 — Planning (`/forge:plan`)
Задача → план с обязательными чекпоинтами на смысловых границах. Близкие блокеры становятся шагами плана, дальние выносятся в отдельную сессию через `.forge/blockers/`.

**Выход:** `.forge/plans/YYYY-MM-DD-<slug>.md` с шагами + чекпоинтами.

### Phase 3 — Critique (`/forge:critique`)
4 параллельных субагента-персоны (Skeptic / Pragmatist / Architect / User Advocate) рвут план каждый со своей стороны. Синтез правок + дописывание Execution Strategy (что в субагенты, что параллельно).

**Выход:** обновлённый `.forge/plans/...` с применёнными правками и Execution Strategy.

### Phase 4 — Implementation (`/forge:execute`)
Реализация в текущей сессии. Тяжёлая работа (чтение многих файлов, длинные тесты) делегируется субагентам. Остановка **только на чекпоинтах из плана**, не каждые N шагов.

Условный handoff: если контекст уже тяжёлый — рекомендуется новый чат для `/execute`.

### Auto-handoff между фазами
По умолчанию: после "ОК" пользователя — Claude автоматически инвокает следующий skill. Пользователь может остановить словами "стоп" / "пауза" / "погоди". Между Phase 3 и Phase 4 — рекомендация открыть свежий чат если контекст большой.

### Hard rules
- NO production code without finalized plan (`/critique` complete)
- NO implementation without approved task statement (`/new-task` complete)
- NO fixes without root cause analysis
- NO "done" claims without verifying against completion criterion
- NO skipping `/new-task` even for "simple" changes
- NO technical questions to Anton — find in code/docs yourself (он не-кодер)

### TDD — где имеет смысл
Используй для функциональной логики (валидаторы, парсеры, бизнес-правила, утилиты). Не насаждай TDD на HTML-вёрстку, конфиги, миграции БД, регистрацию роутов.

### Coding principles (Karpathy-style)

**Think before coding:** Don't assume — ask. State assumptions explicitly. If unclear — stop and clarify, don't guess.

**Simplicity first:** Minimum code that solves the problem. Nothing speculative. No unrequested features, no single-use abstractions, no error handling for impossible scenarios. Three identical lines are better than a premature abstraction.

**Surgical changes:** Touch only what you must. Don't improve adjacent code, don't fix unrelated issues, don't add docstrings to code you didn't change. Match existing style. Every changed line should trace directly to the request.

**Goal-driven execution:** Transform vague requests into testable objectives. Not "add validation" but "write tests for invalid inputs, then make them pass". Define success criteria, loop until verified.

## Conventions

- **Файлы/директории:** kebab-case
- **JS функции/переменные:** camelCase
- **Python функции/переменные:** snake_case
- **Константы:** UPPER_SNAKE_CASE
- **Скиллы:** директория + SKILL.md внутри
- **Команды:** kebab-case MD файлы

## Native Claude Code features used

- **Output Style "Forge Concise"** (`output-styles/forge-concise.md`) — нативный механизм Claude Code для правил вывода. `force-for-plugin: true` — авто-активация при включении плагина. Заменяет ручной STYLE-блок в хуке.
- **Statusline** (`hooks/statusline.sh`) — показывает фазу пайплайна, ветку, % контекста. Активируется через `~/.claude/settings.json` пользователя.
- **PreToolUse bash safety** (`hooks/bash-safety.sh`) — блокирует опасные паттерны (`rm -rf /`, `git push --force main`, etc.) до выполнения.

## Commands Reference

| Command | When |
|---------|------|
| `/forge:start` | Session start |
| `/forge:new-task` | **Phase 1** — раскрутить сырую задачу |
| `/forge:plan` | **Phase 2** — построить план |
| `/forge:critique` | **Phase 3** — 4 персоны рвут план |
| `/forge:execute` | **Phase 4** — реализация |
| `/forge:sync` | After work — обновить docs |
| `/forge:validate` | Before merge — verify code vs plan |
| `/forge:cleanup` | Code quality audit |
| `/forge:discover` | Search marketplace |
| `/forge:graph` | Code knowledge graph |
| `/forge:product-map` | Project navigator (HTML) |
| `/forge:explain` | Visual "how does X work?" (HTML) |
| `/forge:investigate` | Problem diagnosis before fixing |
| `/forge:session-insights` | Session patterns analysis |

Полезные **встроенные** команды Claude Code (не наши):
- `/btw <вопрос>` — side-вопрос, ответ в overlay, **не попадает в историю**
- `/clear` — очистить контекст
- `/compact` — сжать историю в саммари

## Evals

`forge-plugin/evals/` — Hamel-style error analysis на реальных трейсах Антона (см. `evals/README.md`):
- `corpus/raw/*.jsonl` — реальные сессии
- `error-analysis.tsv` — open coding (первый сбой в каждом трейсе)
- `taxonomy-v1.md` — axial coding (5-8 категорий провалов)
- `criteria/*.yml` — бинарные критерии по фазам и handoff
- `transition-matrix.tsv` — карта где переход между фазами ломается

## Communication

- Russian unless asked otherwise
- Concise — no fluff (правила в Output Style "Forge Concise")
- Reference code as `file_path:line_number`
- One clarifying question at a time
- Anton — не-кодер, голосовой ввод: опечатки норма, не переспрашивать "имел ли ты в виду X"
