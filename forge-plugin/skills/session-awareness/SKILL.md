---
name: session-awareness
description: >
  Maintains project context files during work. Use when completing a task step,
  encountering errors, abandoning an approach, or making architectural decisions.
  Updates docs/index.md session state, writes dead-ends on failures,
  logs decisions. Reading context is handled by the UserPromptSubmit hook —
  this skill is only for WRITING.
---

# Session Awareness — Запись контекста

Контекст проекта (index.md, dead-ends, git log) автоматически инжектится
в каждый запрос через hook. Тебе НЕ нужно его читать — он уже в промпте.

**Твоя задача — ОБНОВЛЯТЬ файлы после действий.**

## Когда обновлять

### docs/index.md → секция `## Session (live)`

| Момент | Что обновить |
|---|---|
| Начал задачу | `Session.Goal`, `Session.Now` |
| Завершил шаг | добавь в `Session.Done`, обнови `Now`, `Next` |
| Ошибка решена | добавь в `Session.Errors` |
| Тронул файл | добавь в `Current.Modified` |
| Сменил ветку | обнови `Current.Branch` |

Формат секции Session:
```markdown
## Session (live)
Started: <время>
Goal: <цель сессии>

Done:
- <шаг 1>
- <шаг 2>

Now: <что делаем>
Next: <что дальше>

Errors:
- <ошибка — решение>
```

### docs/dead-ends/<тема>.md — при провале подхода

Когда подход не сработал (2+ попытки или явный тупик):

1. Определи тему: auth, database, ui, api, testing и т.д.
2. Создай или допиши файл `docs/dead-ends/<тема>.md`

Формат:
```markdown
## <краткое название>
Date: <дата>
Approach: <что пробовали>
Why failed: <почему не работает>
Lesson: <что делать вместо>
```

**КРИТИЧНО:** Записывай СРАЗУ при провале. Не жди конца сессии.

### docs/decisions.md — при значимом выборе

Когда выбираешь между подходами и это влияет на архитектуру:

```markdown
## <что решили>
Date: <дата>
Context: <почему встал вопрос>
Considered: <варианты>
Decision: <что выбрали и почему>
Revisit if: <когда пересмотреть>
```

### docs/status.md — при изменении состояния

- Тест прошёл → добавь в `## Working`
- Тест упал → добавь в `## Broken`
- Блокер → добавь в `## Blocked`, обнови index.md `Blocked: да`

### docs/journal.md — в конце сессии

При завершении работы или смене задачи добавь запись В НАЧАЛО файла:

```markdown
## <дата> — <что делали>
Did: <2-4 пункта>
Result: <итог>
Next: <что дальше>
Files: <ключевые файлы>
```

Если записей >7 — перенеси старые в `docs/journal-archive/YYYY-MM.md`.

## Антипаттерны

- НЕ читай index.md для контекста — он уже в промпте через hook
- НЕ откладывай запись dead-ends — "потом" = никогда
- НЕ пиши dead-end после первой неудачи — подожди 2 попытки
- НЕ забывай обновлять Session.Now — это главная защита от потери контекста
