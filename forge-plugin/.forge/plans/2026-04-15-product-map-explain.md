# /forge:product-map + /forge:explain — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use forge:executing-plans or forge:subagent-driven-development to implement this plan task-by-task.

**Goal:** Две команды визуализации проекта: product-map (полная карта) и explain (ответ на вопрос). Claude генерирует JSON, фиксированный HTML-шаблон рендерит.

**Architecture:** 
- Фиксированный HTML-шаблон с React (пишется один раз, хранится в скилле)
- Claude генерирует только JSON-данные по проекту
- Шаблон читает JSON и рендерит визуализацию в стиле v9
- Graphify граф используется для навигации (опционально)

**Tech Stack:** HTML/React (шаблон), JSON (данные), Markdown (скиллы/команды), Bash (graphify CLI)

---

### Task 1: HTML-шаблон для product-map

**Files:**
- Create: `skills/product-mapping/template-product-map.html`

**Step 1: Создать шаблон**

Шаблон содержит:
- React 18 + Babel (CDN)
- Все UI-компоненты из v9: BigNode, FlowStep, Fork, EntityCard, Sub, InfoBlock, InfoLine, Badge
- CSS стили (тёмная тема)
- 4 таба: Картина, Потоки, Детали, Дыры
- Чтение данных из `<script id="forge-data" type="application/json">`

Шаблон рендерит данные из JSON-блока внутри HTML. Claude при генерации вставляет JSON в этот блок.

Формат данных:
```json
{
  "project": "название",
  "version": "1.0.0",
  "goal": "цель проекта одним предложением",
  "bigPicture": [
    {
      "icon": "💬", "title": "Название шага", "desc": "Описание",
      "color": "#4dd0e1",
      "details": [
        { "text": "Пункт описания" },
        { "text": "Предупреждение", "warn": true },
        { "text": "Под капотом", "pink": true, "infoBlock": {
          "title": "Что Claude видит",
          "lines": [
            { "icon": "📦", "label": "Проект:", "value": "...", "sub": "пояснение" }
          ]
        }}
      ],
      "last": false
    }
  ],
  "flows": [
    {
      "id": "checkout", "icon": "💳", "title": "Оформление заказа",
      "desc": "Корзина → оплата → подтверждение",
      "badge": "основной",
      "steps": [
        { "icon": "🛒", "title": "Добавление в корзину", "desc": "...",
          "details": [
            { "text": "Проверка наличия на складе" },
            { "text": "Под капотом", "pink": true, "infoBlock": { "title": "...", "lines": [...] } }
          ]
        }
      ],
      "forks": [
        { "after": 2, "question": "Оплата прошла?", "options": [
          { "label": "✅ Да", "text": "→ Подтверждение заказа" },
          { "label": "❌ Нет", "text": "→ Повторная попытка или отмена" }
        ]}
      ]
    }
  ],
  "entities": [
    {
      "icon": "📦", "label": "Заказ", "oneLiner": "Что купил пользователь",
      "color": "#58a6ff", "status": "ok",
      "what": "Запись о покупке — товары, сумма, статус доставки",
      "benefit": "Видишь все покупки, можешь отследить статус",
      "howTo": ["Создаётся при оформлении", "Обновляется при оплате и доставке"],
      "inside": [
        { "text": "Содержит список товаров" },
        { "text": "Статусы: создан → оплачен → отправлен → доставлен" },
        { "text": "Отмена не реализована", "warn": true }
      ]
    }
  ],
  "gaps": [
    { "label": "Возврат товара", "desc": "Не реализован", "severity": "high" }
  ]
}
```

**Step 2: Проверить что шаблон рендерит тестовые данные**

Вставить минимальный JSON (1 big picture node, 1 flow, 1 entity, 1 gap) и открыть в браузере.

Expected: выглядит как v9, все табы работают, drill-down открывается.

**Step 3: Commit**

```bash
git add skills/product-mapping/template-product-map.html
git commit -m "feat: add product-map HTML template with React renderer"
```

---

### Task 2: HTML-шаблон для explain

**Files:**
- Create: `skills/product-mapping/template-explain.html`

**Step 1: Создать компактный шаблон**

Проще чем product-map — один поток (ответ на вопрос):
- Заголовок: вопрос + краткий ответ
- Поток: шаги с развилками (FlowStep, Fork)
- Связанные сущности (EntityCard)
- Похожие вопросы (ссылки)

Формат данных:
```json
{
  "question": "Как работает оплата?",
  "summary": "Пользователь нажимает 'оплатить', данные отправляются в Stripe...",
  "flow": [
    { "icon": "💳", "title": "Stripe checkout", "desc": "...", "details": [...] }
  ],
  "forks": [
    { "after": 1, "question": "Оплата прошла?", "options": [...] }
  ],
  "entities": [
    { "icon": "💰", "label": "Платёж", "what": "...", "inside": [...] }
  ],
  "relatedQuestions": [
    "Как работает возврат?",
    "Что если Stripe недоступен?",
    "Где хранятся данные карт?"
  ]
}
```

**Step 2: Проверить с тестовыми данными**

**Step 3: Commit**

```bash
git add skills/product-mapping/template-explain.html
git commit -m "feat: add explain HTML template"
```

---

### Task 3: Скилл product-mapping

**Files:**
- Create: `skills/product-mapping/SKILL.md`

**Step 1: Написать скилл**

```yaml
---
name: product-mapping
description: "Use when user asks for project overview, product map, or wants to understand how the project works as a whole"
---
```

Скилл инструктирует Claude:

1. **Загрузить контекст:**
   - .forge/ (L0 + все L1 файлы)
   - graphify query "main flows" (если граф есть)
   - README.md, CLAUDE.md

2. **Извлечь потоки через субагентов** (параллельно):
   - Субагент 1: определить основные потоки (3-7 штук) — как данные/запросы проходят через систему
   - Субагент 2: определить сущности (5-15 штук) — из чего состоит система
   - Субагент 3: определить дыры — что не реализовано, что сломано

3. **Для каждого потока:** шаги, развилки, что происходит внутри

4. **Для каждой сущности:** что это (человеческим языком), зачем, как пользоваться, что внутри

5. **Собрать big picture:** цепочка из 5-8 блоков показывающая весь механизм

6. **Описания — человеческим языком:**
   - Не "AuthMiddleware validates JWT" а "Проверка авторизации — подтверждает что пользователь тот за кого себя выдаёт"
   - Не "PostgreSQL" а "База данных — где хранится вся информация"
   - Аналогии где уместно

7. **Сформировать JSON** по формату из template-product-map.html

8. **Записать результат:**
   ```
   .forge/product-map.json — данные
   ```
   Скопировать template-product-map.html рядом, вставить JSON внутрь.
   Открыть в браузере.

9. **Правила:**
   - Максимум 20 узлов в big picture
   - Максимум 7 потоков
   - Максимум 15 сущностей
   - Если проект слишком большой — спросить "какую часть визуализировать?"
   - Если graphify нет — работать через .forge/ + grep (медленнее, менее точно)

**Step 2: Commit**

```bash
git add skills/product-mapping/SKILL.md
git commit -m "feat: add product-mapping skill for project visualization"
```

---

### Task 4: Скилл explaining

**Files:**
- Create: `skills/explaining/SKILL.md`

**Step 1: Написать скилл**

```yaml
---
name: explaining
description: "Use when user asks how something specific works in the project and wants a visual explanation"
---
```

Скилл инструктирует Claude:

1. **Получить вопрос** из промпта пользователя

2. **Найти релевантный код:**
   - graphify query "вопрос" (если граф есть) → список модулей
   - graphify path между ключевыми модулями → трассировка
   - graphify explain для ключевых узлов
   - Если графа нет → .forge/map.yml + grep

3. **Прочитать только релевантные файлы** (5-15 файлов, не больше)

4. **Извлечь поток:**
   - Вход: откуда начинается (API запрос? кнопка? cron?)
   - Шаги: что происходит по порядку
   - Развилки: где поведение ветвится
   - Выход: что получается в итоге
   - Ошибки: что может пойти не так

5. **Извлечь связанные сущности** (2-5 штук)

6. **Предложить похожие вопросы** (3-5 штук)

7. **Описания — человеческим языком** (как в product-map)

8. **Сформировать JSON** по формату template-explain.html

9. **Записать результат:**
   - `.forge/explain-{slug}.json` — данные
   - Скопировать template + вставить JSON
   - Открыть в браузере

10. **Правила:**
    - Максимум 15 шагов в потоке
    - Максимум 5 сущностей
    - Если вопрос слишком широкий → уточнить: "Какой аспект? Оплата, доставка, авторизация?"
    - Если вопрос слишком узкий (одна функция) → текстовый ответ вместо HTML

**Step 2: Commit**

```bash
git add skills/explaining/SKILL.md
git commit -m "feat: add explaining skill for per-question visualization"
```

---

### Task 5: Команды /forge:product-map и /forge:explain

**Files:**
- Create: `commands/product-map.md`
- Create: `commands/explain.md`

**Step 1: Команда product-map**

```markdown
---
description: Generate interactive HTML navigator showing project's business logic — flows, entities, and gaps
---

Invoke the forge:product-mapping skill and follow it exactly as presented to you
```

**Step 2: Команда explain**

```markdown
---
description: Generate interactive HTML visualization answering a specific question about how something works in the project
---

Invoke the forge:explaining skill and follow it exactly as presented to you
```

**Step 3: Commit**

```bash
git add commands/product-map.md commands/explain.md
git commit -m "feat: add /forge:product-map and /forge:explain commands"
```

---

### Task 6: Обновить context-inject.sh + using-forge + COMMANDS.md

**Files:**
- Modify: `hooks/context-inject.sh` — добавить keyword matching для explain
- Modify: `skills/using-forge/SKILL.md` — добавить product-map и explain в таблицу скиллов
- Modify: `COMMANDS.md` — документация новых команд

**Step 1: context-inject.sh — добавить keywords**

После существующих keyword matches добавить:
```bash
elif printf '%s' "$user_prompt" | grep -qiE 'как работает|как устроен|объясни|покажи как|визуализируй|explain'; then
    skill_hint="forge:explaining"
elif printf '%s' "$user_prompt" | grep -qiE 'карта проекта|обзор проекта|product.?map|из чего состоит|полная картина'; then
    skill_hint="forge:product-mapping"
fi
```

**Step 2: using-forge — добавить в таблицу**

```markdown
| forge:product-mapping | Full project visualization — flows, entities, gaps → HTML |
| forge:explaining | Per-question visualization — "how does X work?" → HTML |
```

**Step 3: COMMANDS.md — добавить описания**

Добавить команды 17 (/forge:product-map) и 18 (/forge:explain) с полным описанием.

**Step 4: Commit**

```bash
git add hooks/context-inject.sh skills/using-forge/SKILL.md COMMANDS.md
git commit -m "feat: integrate product-map and explain into hooks, using-forge, docs"
```

---

### Task 7: Тестирование на forge-plugin

**Step 1: Запустить product-map на самом forge-plugin**

```
/forge:product-map
```

Проверить что:
- JSON сгенерирован в .forge/product-map.json
- HTML открывается в браузере
- Все 4 таба работают
- Drill-down раскрывается
- Описания на русском, человеческим языком

**Step 2: Запустить explain**

```
/forge:explain "как работает автоподбор скиллов?"
```

Проверить что:
- HTML открывается
- Поток показывает шаги keyword matching
- Связанные сущности показаны
- Похожие вопросы предложены

**Step 3: Исправить найденные проблемы**

**Step 4: Commit финальных правок**

---

## Summary

| Task | Что | Файл | Время |
|------|-----|------|-------|
| 1 | HTML-шаблон product-map | template-product-map.html (новый) | 5 мин |
| 2 | HTML-шаблон explain | template-explain.html (новый) | 3 мин |
| 3 | Скилл product-mapping | skills/product-mapping/SKILL.md (новый) | 5 мин |
| 4 | Скилл explaining | skills/explaining/SKILL.md (новый) | 5 мин |
| 5 | Команды | commands/product-map.md + explain.md (новые) | 2 мин |
| 6 | Интеграция | context-inject.sh + using-forge + COMMANDS.md | 3 мин |
| 7 | Тестирование | запуск на forge-plugin | 5 мин |

**Итого: ~28 минут, 7 задач, 6 коммитов**

Ключевое решение: Claude генерирует **только JSON**, фиксированный шаблон рендерит. Это устраняет проблему чёрных экранов из-за ошибок в HTML.
