# План: миграция плагина на новый 4-фазный пайплайн

**Задача:** Заменить ссылки на старые скиллы/команды (`brainstorming`, `writing-plans`, `executing-plans`, `forge:brainstorm`, `forge:write-plan`, `forge:execute-plan`) на новые из 4-фазного пайплайна (`new-task`, `plan`, `critique`, `execute`). Удалить старые файлы когда никто не ссылается.

**Подход:** Сначала найти все ссылки (28 файлов, сгруппированы в 6 категорий). Заменить по категориям с разной стратегией: простые ссылки → sed-замена; описания пайплайна в доках → переписать секции; историческое → не трогать. Завершить удалением старых файлов и проверкой что ничего не осталось.

**Открытые вопросы:** нет.

**Блокеры:** нет.

---

## Карта замены

| Старое | Новое |
|---|---|
| `forge:brainstorming` (скилл) | `forge:new-task` |
| `forge:writing-plans` (скилл) | `forge:plan` |
| `forge:executing-plans` (скилл) | `forge:execute` |
| `forge:brainstorm` (команда) | `forge:new-task` |
| `forge:write-plan` (команда) | `forge:plan` |
| `forge:execute-plan` (команда) | `forge:execute` |
| `brainstorming` (имя скилла без префикса) | `new-task` |
| `writing-plans` (имя скилла без префикса) | `plan` |
| `executing-plans` (имя скилла без префикса) | `execute` |

---

## Шаг 1: Удалить 3 старые команды

**Файлы (удалить):**
- `forge-plugin/commands/brainstorm.md`
- `forge-plugin/commands/write-plan.md`
- `forge-plugin/commands/execute-plan.md`

**Что делаем:** `rm` этих трёх файлов через Bash.

**Как проверим:** `ls forge-plugin/commands/ | grep -E "^(brainstorm|write-plan|execute-plan)\.md$"` — пусто.

---

## Шаг 2: Заменить ссылки в других скиллах (8 файлов, прямая замена)

**Файлы (изменить):**
- `forge-plugin/skills/subagent-driven-development/SKILL.md`
- `forge-plugin/skills/using-forge/SKILL.md`
- `forge-plugin/skills/api-design/SKILL.md`
- `forge-plugin/skills/ui-ux-design/SKILL.md`
- `forge-plugin/skills/finishing-a-development-branch/SKILL.md`
- `forge-plugin/skills/using-git-worktrees/SKILL.md`
- `forge-plugin/skills/problem-investigation/SKILL.md`
- `forge-plugin/skills/database-migrations/SKILL.md`

**Что делаем:** в каждом файле sed-замена по карте:
- `forge:brainstorming` → `forge:new-task`
- `forge:writing-plans` → `forge:plan`
- `forge:executing-plans` → `forge:execute`
- `forge:brainstorm` → `forge:new-task`
- `forge:write-plan` → `forge:plan`
- `forge:execute-plan` → `forge:execute`
- `brainstorming skill` → `new-task skill`
- `writing-plans skill` → `plan skill`
- `executing-plans skill` → `execute skill`

**Внимание:** после автоматической замены — глазами прочитать каждый изменённый файл. Семантика могла поплыть: `brainstorming` фокусировался на дизайне с DDD, а `new-task` — на ясной задаче без дизайна. Где соседний текст про "domain modeling" / "requirements R1/AC" — упростить или удалить.

**Как проверим:** `grep -l "brainstorming\|writing-plans\|executing-plans" forge-plugin/skills/` (исключая старые скиллы) — пусто.

---

## Шаг 3: Заменить ссылки в командах (4 файла)

**Файлы (изменить):**
- `forge-plugin/commands/discover.md`
- `forge-plugin/commands/init.md`
- `forge-plugin/commands/sync.md`
- `forge-plugin/commands/validate.md`

**Что делаем:** прочитать каждый. Если ссылка на старое — заменить по карте. Если описание workflow с фазами — переписать на новый пайплайн (1→4).

**Как проверим:** `grep -l "brainstorming\|writing-plans\|executing-plans\|forge:brainstorm\|forge:write-plan\|forge:execute-plan" forge-plugin/commands/` — пусто.

---

## Шаг 4: Обновить документацию (4 файла, переписать секции)

**Файлы (изменить):**
- `forge-plugin/README.md`
- `forge-plugin/COMMANDS.md`
- `forge-plugin/docs/context-system.md`
- `forge-plugin/docs/Forge spec v2.md`
- `forge-plugin/docs/forge-runtime-flow.md`
- `forge-plugin/docs/plugin-improvement-proposals.md`

**Что делаем:** Здесь не sed-замена, а переписывание секций про workflow. В README и COMMANDS будет таблица команд — обновить. В spec/runtime-flow — диаграммы и описания фаз заменить.

Опираться на `ideas/pipeline-v2.html` как на референс новой структуры.

**Как проверим:**
- `grep -c "forge:new-task\|forge:plan\|forge:critique\|forge:execute" forge-plugin/README.md` — > 0
- `grep -c "forge:brainstorm\|forge:write-plan\|forge:execute-plan" forge-plugin/README.md` — = 0

---

## Шаг 5: Обновить `.forge/entities.yml`

**Файлы (изменить):**
- `forge-plugin/.forge/entities.yml` (строки 156, 159, 160)

**Что делаем:** заменить старые ссылки на новые в описании workflow.

**Как проверим:** `grep -n "forge:brainstorm\|forge:write-plan\|forge:execute-plan" forge-plugin/.forge/entities.yml` — пусто.

---

## Шаг 6: Обновить `lib/skills-core.js`

**Файлы (изменить):**
- `forge-plugin/lib/skills-core.js:103` (JSDoc пример с "superpowers:brainstorming")

**Что делаем:** одна правка комментария — пример с "new-task" или нейтральным "example".

**Внимание:** `.claude/rules/core-lib.md` требует read entire file + tests before. Здесь правка в JSDoc, не в логике — read целиком сделать, тестов специальных не нужно (нет тестов для doc-comments). Прочитать файл, поменять одну строку.

**Как проверим:** `grep -c "brainstorming" forge-plugin/lib/skills-core.js` — = 0.

---

### ✅ Чекпоинт A: Все ссылки переехали на новые имена

Что показываем: пользователю — итог по grep'у:
```bash
grep -rln -e "forge:brainstorm\|forge:write-plan\|forge:execute-plan\|brainstorming\|writing-plans\|executing-plans" forge-plugin/ \
  --include="*.md" --include="*.json" --include="*.yml" --include="*.js" \
  | grep -v "^forge-plugin/skills/brainstorming\|^forge-plugin/skills/writing-plans\|^forge-plugin/skills/executing-plans" \
  | grep -v "^forge-plugin/.forge/plans/2026-04-15"
```
Должно вернуть пусто (кроме самих старых скиллов и исторических планов).

Что подтверждает пользователь: "новые имена везде, можно удалять старые скиллы".

Следующее: удаление 3 старых скиллов.

---

## Шаг 7: Удалить 3 старые скилл-директории

**Файлы (удалить):**
- `forge-plugin/skills/brainstorming/`
- `forge-plugin/skills/writing-plans/`
- `forge-plugin/skills/executing-plans/`

**Что делаем:** `rm -rf` директорий.

**Как проверим:** `ls forge-plugin/skills/ | grep -E "^(brainstorming|writing-plans|executing-plans)$"` — пусто.

---

## Шаг 8: Финальный grep — ничего не осталось

**Что делаем:**
```bash
grep -rln -e "forge:brainstorm\|forge:write-plan\|forge:execute-plan\|brainstorming\|writing-plans\|executing-plans" forge-plugin/ \
  --include="*.md" --include="*.json" --include="*.yml" --include="*.js" \
  | grep -v "^forge-plugin/.forge/plans/2026-04-15"
```

**Как проверим:** результат пуст (исторические планы в `.forge/plans/2026-04-15-*.md` оставляем — они описывают историю и не должны вводить в заблуждение пользователей сегодняшнего дня; если найдём что-то ещё — добавляем шаг).

---

## Execution Strategy

(Эта секция дополнится после `/critique`. Предварительно:)

### Параллельно
- Шаг 2 (8 скилл-файлов) — независимые файлы, можно через 8 одновременных субагентов с одинаковым промптом "примени карту замен в этом файле + перечитай результат на семантические сбои".

### Последовательно
- Шаг 1 (удаление команд) → Шаг 2 → Шаг 3 → Шаг 4 → Шаг 5 → Шаг 6 → Чекпоинт A → Шаг 7 → Шаг 8.

### Делегировать субагентам
- Шаги 2, 3, 4 — массовые правки, в субагентов (каждый возвращает diff-сводку).
- Шаг 8 (финальный grep) — простая команда, в основной сессии.

### Делать в основной сессии
- Шаги 1, 5, 6, 7 — простые операции, не нужен субагент.
- Чекпоинт A — диалог с пользователем.

### Чекпоинты
- После шага 6 — Чекпоинт A: проверить что ссылок не осталось ДО удаления старых скиллов. Безопасность от случайной потери ссылки.
