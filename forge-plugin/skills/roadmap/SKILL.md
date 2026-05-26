---
name: roadmap
description: "Use when the user wants to manage project goals/milestones on GitHub map — voice triggers (RU): 'добавь цель', 'новая цель', 'переименуй цель', 'поставь цель в сейчас', 'переcyдь задачу', 'не туда привязал', 'это к другой цели', 'перепривяжи задачу', 'не та цель', 'почисти карту', 'покажи карту проекта', 'удали цель', 'переставь приоритеты', 'roadmap'. EN: 'manage goals', 'add milestone', 'reassign to', 'project map', 'roadmap'. Also use INIT mode when github_sync включён в проекте и в карте 0 целей (вызывается из new-task). The skill talks to the user in human language — no priority numbers, no GraphQL IDs, no slugs. It infers structured data from natural phrasing and shows back human-friendly names."
---

# Roadmap — управление картой целей проекта

**Role:** Карта-менеджер для не-кодера. Все вопросы пользователю — на человеческом языке (без чисел приоритета, без node_id, без slug). Внутри переводишь human-фразы в `gh api` вызовы.

**Stakes:** Если задаёшь технические вопросы ("какой приоритет — 1, 2 или 3?") — нарушаешь главное правило плагина. Пользователь застрянет.

## Вход

- Без аргументов: `/forge:roadmap` — обычный режим управления (показать карту, добавить/изменить/удалить цель)
- Через триггер из new-task при пустой карте: режим **INIT** (см. ниже)
- Через триггер "переcyдь" в любой фазе — режим **REASSIGN**

## Pre-flight

Сначала проверь работает ли sync:
```bash
bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh diagnose
```

Если не `ok` — скажи Антону человеческим языком что не работает (см. вывод stderr) и завершись.

## Режим INIT (карта пустая, вызван из new-task)

1. Скажи Антону простым языком:
   > "У тебя в этом проекте пока нет крупных целей в карте. Назови 2-3 направления одной фразой каждое — например: 'добавить онлайн-оплату', 'почистить старый код', 'мобильная версия'."

2. Дождись ответа. Принимай как угодно: список через запятую, через перенос строки, голосом, "это и это".

3. Для каждого направления — **один короткий вопрос**:
   > "В чём суть **'<название>'** одной фразой? (опишу в карте, поможет потом матчить задачи)"

   Прими human-описание.

4. Распредели приоритеты автоматически по порядку названия:
   - Первое = priority 1 (🔥 Сейчас в фокусе)
   - Второе = priority 2 (⏭️ Следующее)
   - Третье+ = priority 3 (⏭️ Следующее)
   - **НЕ спрашивай "какой приоритет?"** — Антон может потом сказать "переставь приоритеты".

5. Создай milestones через `gh api`:
   ```bash
   gh api -X POST 'repos/{owner}/{repo}/milestones' \
     -f title="<название>" \
     -f description="priority: <N>
   <описание>"
   ```

6. После всех — обнови карту:
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh sync-pinned
   bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh sync-readme
   ```

7. Кратко: "Карта готова: <N> целей. Возвращаюсь к твоей задаче."
   Управление возвращается в new-task (вызывающий скилл продолжает с шага семантического матча).

## Режим REASSIGN (триггер "переcyдь")

1. Получи открытые milestones:
   ```bash
   gh api 'repos/{owner}/{repo}/milestones?state=open' --jq '.[] | "\(.number)|\(.title)"'
   ```
2. Найди номер целевой milestone по имени (если Антон сказал "переcyдь на 'X'") или, если он сказал общо ("не туда привязал"), спроси одной фразой:
   > "На какую цель перепривязать? Сейчас есть: 'Цель A', 'Цель B', 'Цель C'."
3. Определи task_slug — это slug текущей задачи из `.forge/state.yml` (`task:` поле) или из последней записи `.forge/index.yml`.
4. Выполни:
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh reassign-task <task-slug> <new-milestone-num>
   bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh sync-pinned
   ```
5. Одной строкой: "Переcyдил на цель **'X'**".

## Режим обычный (`/forge:roadmap`)

1. Получи все milestones (open + closed):
   ```bash
   gh api 'repos/{owner}/{repo}/milestones?state=all' --jq '.[] | "\(.number)|\(.title)|\(.state)|\(.description)|\(.open_issues)|\(.closed_issues)"'
   ```

2. Покажи Антону **сводку человеческим языком** (не таблица номеров). Группировка по приоритету:
   ```
   У тебя 5 целей.

   🔥 Сейчас в фокусе:
     • GitHub-sync (3 из 12 задач готово)
     • Mobile statusline (0 из 5 готово)

   ⏭️ Следующее:
     • Voice-input preprocessor (0 из 8)

   📅 Потом:
     • Эвалы корпуса

   ✅ Готово:
     • Output Style refactor (8 из 8)
   ```

3. Спроси одной фразой что делаем:
   > "Что хочешь — добавить новую цель, переименовать, переставить приоритеты, удалить, или почистить старые задачи?"

4. По ответу — действие:

   ### а) "добавь цель X" / "новая цель"
   - Если Антон описал кратко — спроси одну фразу описания
   - Создай milestone с priority 3 по умолчанию (или явно сказанным "в сейчас" → priority 1, "в следующее" → priority 2, "в потом" → priority 4):
     ```bash
     gh api -X POST 'repos/{owner}/{repo}/milestones' -f title="X" -f description="priority: N\n<desc>"
     ```

   ### б) "переименуй X в Y"
   - Найди номер milestone по имени "X"
   - `gh api -X PATCH 'repos/{owner}/{repo}/milestones/<N>' -f title="Y"`

   ### в) "поставь X в сейчас" / "X в следующее" / "X отложить"
   - Mapping: "в сейчас" → priority 1, "в следующее" → priority 2, "потом/отложить" → priority 4
   - Получи description milestone, замени `priority: N` строку, PATCH:
     ```bash
     # Получи existing description
     desc=$(gh api 'repos/{owner}/{repo}/milestones/<N>' --jq .description)
     # Замени priority строку
     new_desc=$(echo "$desc" | sed "s/^priority:.*/priority: $new_priority/")
     # PATCH
     gh api -X PATCH 'repos/{owner}/{repo}/milestones/<N>' -f description="$new_desc"
     ```

   ### г) "удали цель X"
   - Спроси подтверждение: "Точно удалить 'X'? Привязанные задачи не удалятся, но потеряют привязку."
   - `gh api -X DELETE 'repos/{owner}/{repo}/milestones/<N>'`

   ### д) "почисти карту" / "почисти старые задачи"
   - Для каждой open milestone — получи open Issues старше 14 дней:
     ```bash
     gh issue list --milestone "<title>" --state open --search "updated:<$(date -d '14 days ago' -I)" --json number,title
     ```
   - Покажи Антону: "Эти задачи давно не двигались: [список]. Закрыть какие-то?"
   - На ответ "да закрой N, M" — `gh issue close N; gh issue close M`

5. После любого изменения:
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh sync-pinned
   bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh sync-readme
   ```

6. Одной строкой: "Сделано. Карта обновлена." Если Антон хочет ещё — обратно к шагу 3.

## Что НЕ делать

- **Не спрашивай "какой приоритет — 1, 2 или 3?"** — выводи из контекста или из human language ("в сейчас" = 1, "в следующее" = 2, "потом" = 3-4).
- **Не показывай сырые номера milestone** — используй названия. Номера только во внутренних `gh api` вызовах.
- **Не дампи полный список 20 целей** одним сообщением — сначала сводку с группировкой, детали по запросу.
- **Не создавай milestone без description** — иначе семантический матч задач к ним будет шумным.
- **Не предлагай Projects v2 board** — мы его выкинули (нет scope, дублирует Pinned).

## Выход

Обновлённые milestones + актуальная карта в Pinned Issue + актуальная шапка README. Управление возвращается вызывающему скиллу (или ждёт следующего вопроса от Антона).
