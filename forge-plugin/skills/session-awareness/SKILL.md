---
name: session-awareness
description: "Use proactively when work produces a fact future sessions need — a decision made, an approach failed twice, a step finished, a blocker or lesson appeared, session wrap-up. RU: 'запиши решение', 'это тупик', 'добавь в журнал', 'итог сессии', 'зафиксируй', 'не сработало'. EN: 'log this', 'record decision', 'mark as dead-end', 'session summary'. Writes .forge/ memory: index.yml session state, dead-ends.yml, decisions.yml, status.yml, journal.yml. WRITE-only — reading is the hook's job."
---

# Session Awareness — Запись контекста

**Role:** You are a meticulous engineering historian (obsessive about institutional knowledge — the person teams call when "nobody remembers why we did X").
**Stakes:** An unrecorded decision will be reversed. An unrecorded dead-end will be repeated. Future sessions have zero memory — your notes are their only context.

Контекст проекта (index.yml) автоматически инжектится через hook.
Тебе НЕ нужно его читать — он уже в промпте.

**Твоя задача — ОБНОВЛЯТЬ файлы после действий.**

## Формат файлов

Все .forge/ файлы — YAML. Если проект использует legacy .md/.json — пиши в том же формате.

## Когда обновлять

### .forge/index.yml → секция `session:`

| Момент | Что обновить |
|---|---|
| Начал задачу | `session.goal`, `session.now` |
| Завершил шаг | добавь в `session.done`, обнови `now`, `next` |
| Ошибка решена | добавь в `session.errors` |
| Тронул файл | обнови `now.task` если задача сменилась |
| Сменил ветку | обнови `now.branch` |
| Итог сессии («итог сессии», конец работы) | **обязательно:** `last_session` (одна строка «дата — что сделали»), проверь `now.task`/`now.branch`, и `version` — если поднимал версию проекта, подними и тут |

### .forge/dead-ends.yml → при провале подхода

Когда подход не сработал (2+ попытки):

Добавь запись в `entries:` секцию .forge/dead-ends.yml:

```yaml
  - id: short-slug
    date: 2026-04-06
    summary: "Краткое описание что не сработало и почему"
    tags: [relevant, keywords, for, matching]
    detail: .forge/dead-ends/short-slug.md  # если нужен L2
```

Если нужен детальный L2 — создай файл `.forge/dead-ends/{id}.md` с полным описанием.
Если summary достаточно — `detail: null`.

**КРИТИЧНО:** Записывай СРАЗУ при провале. Не жди конца сессии.

### .forge/decisions.yml → при значимом выборе

Добавь в `entries:`:

```yaml
  - id: decision-slug
    date: 2026-04-06
    decision: "Что решили"
    why: "Почему (контекст + обоснование)"
    tags: [architecture, relevant, keywords]
    detail: null  # или путь к L2 если решение сложное
```

### .forge/status.yml → при изменении состояния

```yaml
working:
  - "description of working feature"
broken:
  - "description of broken thing"
blocked:
  - "description of blocker"
```

Также обнови `blocked:` в index.yml если появился/исчез блокер.

### .forge/journal.yml → в конце сессии

Добавь запись В НАЧАЛО `entries:`:

```yaml
entries:
  - date: 2026-04-06
    summary: "Что делали"
    result: "Итог"
    next: "Что дальше"
    files: [key/files/changed]
  # ... старые записи
```

Если записей >7 — удали самые старые (они уже не нужны для контекста).

**Вместе с journal обнови .forge/index.yml** (`last_session`, `now`, `version` — см. таблицу выше). index.yml — единственный файл, который хук инжектит в каждый промпт: протухнет он — все будущие сессии будут получать ложный контекст.

**После записи итога — сохрани память в git** (тихо, по процедуре скилла `memory-backup`):
```bash
bash "$CLAUDE_PLUGIN_ROOT/skills/memory-backup/backup.sh" "итог сессии: <3-5 слов>"
```
Одна строка пользователю только если push не прошёл или удалёнки нет (предложение приватного репозитория — см. SKILL.md memory-backup).

**Правило секретов:** в .forge никогда не пишутся пароли/токены/ключи/приватные адреса — только названия записей Bitwarden.

## Антипаттерны

- НЕ читай .forge/index.yml для контекста — он уже в промпте через hook
- НЕ откладывай запись dead-ends — "потом" = никогда
- НЕ пиши dead-end после первой неудачи — подожди 2 попытки
- НЕ забывай обновлять session.now — главная защита от потери контекста
- НЕ пиши prose в YAML файлах — только key: value, списки, one-liners
