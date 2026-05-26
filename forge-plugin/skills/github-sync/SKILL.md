---
name: github-sync
description: "Internal skill — invoked automatically by forge pipeline skills (new-task, plan, critique, execute) to mirror task state to GitHub Issues + Sub-issues + auto-updated README header + Pinned Issue with project map. Enabled by `github_sync: true` in `.forge/index.yml`. Triggers: 'sync to github', 'обнови карту проекта', 'github sync', or any pipeline phase end. NOT for manual use — use /forge:roadmap for goal management. Silently no-ops when no GitHub remote / no gh / no github_sync flag. Loudly warns when flag is on but auth is broken."
---

# GitHub Sync — внутренний скилл

**Role:** Internal pipeline integration. Pushes task and project state to GitHub for visibility, lets Anton see a project map he can't lose track of.

**Stakes:** Silent failure = Anton thinks GitHub is in sync when it's not, makes decisions on stale picture. Always be loud about auth/scope problems.

## Что это

Один централизованный bash-скрипт `sync.sh` инкапсулирует все `gh` CLI вызовы. Существующие скиллы (new-task / plan / critique / execute / forge-context) добавляют в свой процесс однострочный вызов `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh <action> <args>` в нужный момент.

## Когда вызывается

| Скилл | Когда | Action |
|---|---|---|
| `new-task` | Шаг 9.5 — после сохранения task-файла | `create-task <task-file> [milestone-num]` |
| `plan` | Шаг 7.5 — после сохранения плана | `add-steps <task-slug> <plan-file>` |
| `critique` | Шаг 4 — после применения правок | `add-critique <task-slug> <summary-file>` |
| `execute` | После каждого шага плана | `close-step <task-slug> <step-num>` |
| `execute` | Финал (после критерия готовности) | `close-task <task-slug>` затем `sync-all` |
| `roadmap` | После любого изменения карты | `sync-pinned` и `sync-readme` |
| `forge:start` | Чтение карты для дашборда | inline `gh issue view` (см. commands/start.md) |

## Доступные actions

- `enabled` — тихая проверка можно ли синкать (yes/no)
- `diagnose` — громкая проверка с warnings на stderr если флаг включён но что-то сломано
- `bootstrap-labels` — создать 6 forge-лейблов (идемпотентно)
- `ensure-pinned-map` — создать/найти Pinned Issue "🗺 Карта проекта"
- `roadmap-init-needed` — карта пустая? (yes/no)
- `create-task <task-file> [milestone-num]` — Issue из task-файла, dedup
- `add-steps <task-slug> <plan-file>` — sub-issues из шагов плана
- `add-critique <task-slug> <summary-file>` — комментарий + label phase-3
- `close-step <task-slug> <step-num>` — закрыть конкретный sub-issue
- `close-task <task-slug>` — закрыть Issue + journal.yml update
- `reassign-task <task-slug> <new-milestone-num>` — перепривязать к другому milestone
- `sync-readme` — обновить шапку README.md
- `sync-pinned` — обновить тело Pinned Issue
- `sync-all` — sync-readme + sync-pinned (вызывается финалом execute)

## Внутренние артефакты (runtime, в `.forge/`)

- `.forge/.github-pinned-id` — номер закреплённого Issue карты
- `.forge/.github-issue-<slug>` — номер Issue для каждой задачи
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
