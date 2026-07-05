---
name: github-sync
description: "Internal skill — invoked automatically by forge pipeline skills (new-task, critique, execute, roadmap) to mirror task state to GitHub Issues + Sub-issues + auto-updated README header + Pinned Issue with project map. Enabled by `github_sync: true` in `.forge/index.yml`. NOT for manual use — use /forge:roadmap for goal management. Silently no-ops when no GitHub remote / no gh / no github_sync flag. Loudly warns when flag is on but auth is broken."
---

# GitHub Sync — внутренний скилл

**Role:** Internal pipeline integration. Pushes task and project state to GitHub for visibility, lets Anton see a project map he can't lose track of.

**Stakes:** Silent failure = Anton thinks GitHub is in sync when it's not, makes decisions on stale picture. Always be loud about auth/scope problems.

## Что это

Один централизованный bash-скрипт `sync.sh` инкапсулирует все `gh` CLI вызовы. Существующие скиллы (new-task / critique / execute / roadmap) добавляют в свой процесс однострочный вызов `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh <action> <args>` в нужный момент.

## Slug-контракт (единое правило для всех фаз)

`<task-slug>` — имя файла задачи в `.forge/tasks/` **без датного префикса и без `.md`**:
`.forge/tasks/2026-07-03-search-fix.md` → slug `search-fix`. Тот же slug — в имени файла плана (дата может отличаться, slug совпадает).

Все фазы (plan / critique / execute) передают в `sync.sh` ровно этот slug — иначе lookup маркеров (`.forge/.github-issue-*`, `.forge/.github-substeps-*`) разъезжается и sync перестаёт находить Issue задачи. `sync.sh` подстраховывает: сам срезает дату из входа, а на чтении находит и старые маркеры с датой (с громким предупреждением в stderr) — но это запасной механизм, а не норма.

## Когда вызывается

| Скилл | Когда | Action |
|---|---|---|
| `new-task` | Раздел «После подтверждения» — после сохранения task-файла | `create-task <task-file> [milestone-num]` |
| `plan` | Шаг 7.5 | ничего — sub-issues создаёт критика по финальному плану |
| `critique` | Шаг 4.5 — после применения правок | `add-critique <task-slug> <summary-file>` |
| `critique` | Шаг 5.5 — после Execution Strategy (состав шагов финален) | `add-steps <task-slug> <plan-file>` |
| `execute` | После каждого шага плана | `close-step <task-slug> <step-num>` |
| `execute` | Финал (после критерия готовности) | `close-task <task-slug>` затем `sync-all` |
| `roadmap` | После любого изменения карты | `sync-pinned` и `sync-readme` |
| `forge:start` | Чтение карты для дашборда | inline `gh issue view` (см. commands/start.md) |

Карта (Pinned Issue + README шапка) обновляется на каждой фазе: `create-task` и `add-steps` в конце сами запускают `sync-all` — отдельный вызов из new-task/critique не нужен.

## Доступные actions

- `enabled` — тихая проверка можно ли синкать (yes/no)
- `should-offer` — надо ли предложить включить sync в этом проекте (yes/no)
- `enable` / `disable` — включить/выключить sync (флаг `github_sync` в `.forge/index.yml`)
- `diagnose` — громкая проверка с warnings на stderr если флаг включён но что-то сломано
- `bootstrap-labels` — создать 6 forge-лейблов (идемпотентно)
- `ensure-pinned-map` — создать/найти Pinned Issue "🗺 Карта проекта"
- `roadmap-init-needed` — карта пустая? (yes/no)
- `create-task <task-file> [milestone-num]` — Issue из task-файла, dedup; в конце сам обновляет карту (`sync-all`)
- `add-steps <task-slug> <plan-file>` — sub-issues из шагов плана; повторный вызов НЕ no-op: новые шаги создаёт, убранные закрывает, переименованные переименовывает; в конце сам обновляет карту
- `add-critique <task-slug> <summary-file>` — комментарий + label phase-3
- `close-step <task-slug> <step-num>` — закрыть конкретный sub-issue
- `close-task <task-slug>` — закрыть Issue + journal.yml update
- `reassign-task <task-slug> <new-milestone-num>` — перепривязать к другому milestone
- `sync-readme` — обновить шапку README.md
- `sync-pinned` — обновить тело Pinned Issue
- `sync-all` — sync-readme + sync-pinned (вызывается финалом execute; `create-task` и `add-steps` запускают его сами)

## Процедура для new-task

Вызывается из скилла `new-task` (раздел «После подтверждения», после сохранения task-файла). Тихо пропускается целиком, если sync выключен.

а) Проверь надо ли предложить включить sync в этом проекте:
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh should-offer
```
- Если `yes` — спроси Антона **одним вопросом простым языком**: "У тебя в этом проекте есть GitHub репо. Хочешь чтобы плагин писал задачи и карту проекта туда сам? (один раз спрашиваю)"
  - Ответ "да" / "ок" / "давай" → `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh enable`
  - Ответ "нет" / "не надо" → `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh disable` (запомнит явный отказ, больше не спросит)
- Если `no` — пропусти этот пункт молча.

б) Проверь работает ли sync:
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh enabled
```
Если `no` — закончи процедуру молча и возвращайся в new-task (sync выключен или сломан — это нормально).

в) Проверь нужен ли roadmap-init (карта пустая на первом запуске):
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh roadmap-init-needed
```
Если `yes` — **НЕ создавай Issue молча**. Скажи: "У тебя в проекте пока нет крупных целей в карте — нужно их назвать прежде чем привязывать задачи. Запускаю /forge:roadmap." Инвокай skill `roadmap` в режиме init. Дождись завершения.

г) Получи открытые milestones:
```bash
gh api 'repos/{owner}/{repo}/milestones?state=open&per_page=100' --jq '.[] | "\(.number)|\(.title)|\(.description)"'
```
Семантически сматчи задачу к подходящей цели:
- Если есть явный кандидат (одна цель явно подходит по смыслу) — используй её номер
- Если ни одна не подходит ИЛИ есть несколько похожих — **спроси Антона одной фразой**: "Привязываю к цели 'X' — или скажи 'к цели Y', или 'новая цель'."

д) Создай Issue:
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh create-task .forge/tasks/<slug>.md <milestone-num>
```
(milestone-num опциональный — без него Issue создаётся без привязки)

е) Одной строкой в чат: "Привязал к цели **'X'**" (используй человеческое имя цели, не slug).

ж) Карту проекта (Pinned Issue + README шапку) `create-task` обновил сам — новая задача видна на карте сразу, отдельный `sync-all` вызывать не нужно.

## Процедура для plan и critique (sub-issues по шагам)

Состав шагов плана финализируется только ПОСЛЕ критики (она добавляет шаги вида 3.5 и убирает лишние), поэтому вызов `add-steps` идёт после критики:

- **plan (шаг 7.5)** — sub-issues НЕ создаёт: карта не должна показывать черновик.
- **critique (шаг 5.5, после применения правок и Execution Strategy)** — точка создания:
  ```bash
  bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh add-steps <task-slug> .forge/plans/<файл-плана>.md
  ```
- Повторный вызов `add-steps` (план правили ещё раз) — безопасен и НЕ no-op: сверяет план с mapping `.forge/.github-substeps-<slug>`, создаёт sub-issues для новых шагов, закрывает для убранных, переименовывает изменённые.

## Внутренние артефакты (runtime, в `.forge/`)

- `.forge/.github-pinned-id` — номер закреплённого Issue карты
- `.forge/.github-issue-<slug>` — номер Issue для каждой задачи (`<slug>` — без даты, см. Slug-контракт)
- `.forge/.github-substeps-<slug>` — mapping `step_num:issue_num` для close-step

Эти файлы НЕ коммитятся (см. `.forge/.gitignore`).

## Почему не PostToolUse хук

Фаза пайплайна завершается не одним tool-call'ом, а серией (Read → Write → инструкции пользователю → подтверждение). PostToolUse триггерится на каждый tool-call отдельно — невозможно поймать "фаза завершена". Поэтому sync вызывается из инструкции в SKILL.md фазы в правильный момент.

Записано в `.forge/decisions.yml` как `github-sync-via-skill-not-hook`.

## Почему gh CLI а не MCP github

Логика инкапсулирована в bash-скрипте `sync.sh` — оттуда MCP недоступен (MCP вызывается только через Claude tool_use). `gh` CLI даёт единое место с проверяемым синтаксисом.

Записано в `.forge/decisions.yml` как `gh-cli-not-mcp-from-bash`.

## Почему нет Projects v2 board

Дублирует Pinned Issue (та же группировка по приоритетам), требует non-default scope `project` в `gh auth` (отсутствует у большинства), сложный GraphQL setup для Status field. Pinned Issue + README шапка покрывают боль "теряю контекст" без этой сложности.

Записано в `.forge/decisions.yml` как `no-projects-v2-board`.
