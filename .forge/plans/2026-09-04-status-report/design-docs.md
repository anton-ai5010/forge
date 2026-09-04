

===== [docs] ШАГ 1: G1. Git: чужие правки в именованный stash, память — в master, ветка feat/status-report от master (~5 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/.claude/settings.json (в stash); /Users/mac/Projects/Plugin/plugin/forge-tray/forge-tray-mac.py (в stash); /Users/mac/Projects/Plugin/plugin/.forge/learnings.yml (коммит памяти в master); /Users/mac/Projects/Plugin/plugin/.forge/tasks/2026-07-07-confidence-in-memory.md (коммит памяти); /Users/mac/Projects/Plugin/plugin/.forge/tasks/2026-09-04-status-report.md (коммит памяти); /Users/mac/Projects/Plugin/plugin/forge-plugin/docs/status-report-format.md (первый коммит ветки)
--- ЧТО:
Факты (проверено): ветка `feat/tray-save-command` не имеет ни одного коммита относительно master (`git log master..HEAD` и обратно — пусто), master == origin/master (2263cbd, `rev-list --left-right --count` → 0 0), stash пуст, тегов 0. Грязные: `.claude/settings.json` (перенос permissions + одноразовый allow), `forge-tray/forge-tray-mac.py` (VERSION 7.1.3→7.6.0 + пункт forge:save — чужой WIP, НЕ трогаем), `.forge/learnings.yml` (+1 урок gh-milestone — это память, не WIP). Untracked: два task-файла + docs/status-report-format.md.

Последовательность — первым шагом execute, ДО любого кода:
```bash
cd /Users/mac/Projects/Plugin/plugin
# 1) чужой WIP — в stash с именем (только 2 файла, память не стешим)
git stash push -m "wip tray-save-command: settings.json + forge-tray-mac.py" -- .claude/settings.json forge-tray/forge-tray-mac.py
# 2) на master, память проекта — штатным механизмом плагина (коммит только .forge-путей + push)
git checkout master && git pull --ff-only
bash forge-plugin/skills/memory-backup/backup.sh "урок gh-milestone + задачи confidence-in-memory и status-report"
# 3) ветка задачи от master, первый коммит — формат-эталон
git checkout -b feat/status-report
git add forge-plugin/docs/status-report-format.md
git commit -m "docs: формат отчёта «Что дальше» (status-report-format.md)"
```
Почему так: finishing-a-development-branch в Option 1 делает `git status --short` + `git add -A` (SKILL.md:91-93) — всё грязное уйдёт в коммит задачи. Stash убирает чужой WIP из этого списка; backup.sh забирает память (learnings + task-файлы) отдельным `[forge] память:` коммитом, как это и так случится при итоге сессии. Старую ветку `feat/tray-save-command` не удаляем (владелец вернётся к ней после `git stash pop`).
--- ПРОВЕРКА:
`git branch --show-current` → `feat/status-report`; `git status --short` → пусто; `git stash list` → одна строка `wip tray-save-command: …`; `git log --oneline -3` → сверху `docs: формат отчёта…`, под ним `[forge] память: урок gh-milestone…`, затем 2263cbd; `git rev-parse master origin/master` → одинаковые хэши (backup.sh запушил master)


===== [docs] ШАГ 2: D1. Мусор отчёта — в .forge/.gitignore, в heredoc backup.sh, в список memory-backup SKILL.md; .playwright-mcp/ — в корневой .gitignore (~5 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/.forge/.gitignore; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/memory-backup/backup.sh; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/memory-backup/SKILL.md; /Users/mac/Projects/Plugin/plugin/.gitignore
--- ЧТО:
1) `.forge/.gitignore` (сейчас 6 строк: `.github-*`, `.inject-state`, `.last-backup`, `.migration-declined`, `graph.json`, `state.yml`) — дописать две строки:
```
reports/shots/
status-report.html
```
2) `backup.sh:35-42` — heredoc, который создаёт `.forge/.gitignore` в новых проектах; после строки `graph.json` (41) добавить те же две строки:
```
graph.json
reports/shots/
status-report.html
EOF
```
(тест (3) в test-memory-backup.sh проверяет только факт создания файла и отсутствие inject-state/state.yml/github-issue в коммите — новые строки его не ломают).
3) `memory-backup/SKILL.md:45` old: «`backup.sh` сам создаёт `.forge/.gitignore` со служебным мусором: `.inject-state`, `.last-backup`, `state.yml`, `.github-*`, `graph.json`. Всё остальное в `.forge/` — ценность, коммитится.» → new: «`backup.sh` сам создаёт `.forge/.gitignore` со служебным мусором: `.inject-state`, `.last-backup`, `state.yml`, `.github-*`, `graph.json`, а также `status-report.html` (регенерируется из `status-report.json`) и `reports/shots/` (снимки экрана для отчёта). Всё остальное в `.forge/` — ценность, коммитится (в том числе `status-report.json`).»
4) `memory-backup/SKILL.md:39-42` список «Когда вызывается автоматически» — добавить строку `- `status-report` — после полной сборки отчёта (JSON — память, уезжает сразу)` ТОЛЬКО если скилл status-report реально зовёт backup.sh (см. open_questions).
5) Корневой `.gitignore`: `grep -qx '.playwright-mcp/' .gitignore || printf '.playwright-mcp/\n' >> .gitignore` — страховка от мусора Playwright MCP в репозитории плагина при отладке скриншотов.
--- ПРОВЕРКА:
`cd /Users/mac/Projects/Plugin/plugin && git check-ignore -v .forge/status-report.html .forge/reports/shots/x.png .playwright-mcp/console.log` → три строки с совпадениями; `bash forge-plugin/tests/hooks/test-memory-backup.sh | tail -1` → `All tests passed`; `git check-ignore .forge/status-report.json` → пусто (JSON коммитится)


===== [docs] ШАГ 3: H1. statusline.sh — фаза 5 в case перед idle (~3 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/statusline.sh
--- ЧТО:
Строки 32-33 сейчас:
```
    execute|"Phase 4"|4) phase_icon="🚀 Фаза 4: Реализация" ;;
    idle) phase_icon="✅ Задача завершена" ;;
```
→
```
    execute|"Phase 4"|4) phase_icon="🚀 Фаза 4: Реализация" ;;
    status-report|"Phase 5"|5) phase_icon="📊 Фаза 5: Что дальше" ;;
    idle) phase_icon="✅ Задача завершена" ;;
```
Скилл status-report в начале фазы пишет `.forge/state.yml` как остальные фазы (образец execute/SKILL.md:40-44): `phase: status-report` + `task: отчёт «Что дальше»`, в конце — `echo "phase: idle" > .forge/state.yml`.
--- ПРОВЕРКА:
`d=$(mktemp -d) && mkdir "$d/.forge" && printf 'phase: status-report\ntask: отчёт\n' > "$d/.forge/state.yml" && cd "$d" && echo '{}' | bash /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/statusline.sh` → `📊 Фаза 5: Что дальше | "отчёт"`


===== [docs] ШАГ 4: H2. session-start.sh — строка Phase 5 в интро + напоминание по отчёту (python3 json, без PyYAML) — сначала bash-тест (RED), потом правка (GREEN) (~15 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-session-start.sh (создать); /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/session-start.sh
--- ЧТО:
**Сначала тест** (образец — test-context-inject.sh / test-memory-backup.sh; tmp-директория не git-репо, поэтому блок mem_warn молчит):
```bash
#!/usr/bin/env bash
# Тесты для hooks/session-start.sh — интро (таблица фаз) и напоминание по отчёту «Что дальше».
set -uo pipefail
HOOK="$(cd "$(dirname "$0")/../../hooks" && pwd)/session-start.sh"
export CLAUDE_PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fails=0
check() { local desc="$1" ok="$2"; if [ "$ok" -eq 0 ]; then echo "PASS: $desc"; else echo "FAIL: $desc"; fails=$((fails + 1)); fi; }
is_json() { printf '%s' "$1" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; }
workdir=$(mktemp -d); cd "$workdir" || exit 1

# (1) интро перечисляет фазу 5
out=$(bash "$HOOK" </dev/null)
printf '%s' "$out" | grep -q "Phase 5" && printf '%s' "$out" | grep -q "forge:status-report"
check "intro lists Phase 5 /forge:status-report" $?

# (2) валидный JSON
is_json "$out"; check "output is valid JSON" $?

# (3) нет .forge/status-report.json → напоминания нет
! printf '%s' "$out" | grep -q "📊 Отчёт"
check "no report reminder without status-report.json" $?

# (4) отчёт есть: 2 открытых решения (decision+both), done и code не считаются, устарел на 3
mkdir -p .forge
cat > .forge/status-report.json <<'EOF'
{"generated":"2026-09-04","stale_merges":3,"findings":[
 {"id":"a","owner":"decision","status":"open"},
 {"id":"b","owner":"both","status":"open"},
 {"id":"c","owner":"decision","status":"done"},
 {"id":"d","owner":"code","status":"open"}]}
EOF
out=$(bash "$HOOK" </dev/null)
printf '%s' "$out" | grep -q "ждут владельца — 2" && printf '%s' "$out" | grep -q "устарел на влитых задач — 3" && is_json "$out"
check "reminder counts pending decisions and stale merges" $?

# (5) всё закрыто и не устарело → тишина
echo '{"stale_merges":0,"findings":[{"owner":"decision","status":"done"}]}' > .forge/status-report.json
out=$(bash "$HOOK" </dev/null)
! printf '%s' "$out" | grep -q "📊 Отчёт"
check "silent when nothing pending and not stale" $?

# (6) битый JSON → хук не падает, JSON валиден
echo '{broken' > .forge/status-report.json
out=$(bash "$HOOK" </dev/null); rc=$?
[ "$rc" -eq 0 ] && is_json "$out"
check "broken report json does not break the hook" $?

cd / && rm -rf "$workdir"
echo "---"
if [ "$fails" -gt 0 ]; then echo "$fails test(s) FAILED"; exit 1; fi
echo "All tests passed"; exit 0
```
**Потом правка хука.** (а) Интро, после строки 62 `  Phase 4   /forge:execute     — реализация` добавить:
```
  Phase 5   /forge:status-report — отчёт «Что дальше»: что чинить, что решать (по команде; после мержа — сам)
```
(б) После блока mem_warn (после строки 41 `fi`) вставить:
```bash
# Напоминание по отчёту «Что дальше» (фаза 5): сколько решений ждут владельца
# и на сколько влитых задач отчёт устарел. Только stdlib python3 — PyYAML у пользователя нет.
report_warn=""
if [ -f ".forge/status-report.json" ]; then
    report_warn=$(python3 - <<'PY' 2>/dev/null || true
import json
d = json.load(open(".forge/status-report.json", encoding="utf-8"))
f = d.get("findings", [])
pending = sum(1 for x in f if x.get("status") == "open" and x.get("owner") in ("decision", "both"))
stale = int(d.get("stale_merges", 0) or 0)
if pending or stale:
    print(f"\n\n📊 Отчёт «Что дальше»: решений ждут владельца — {pending}, устарел на влитых задач — {stale}. Скажи пользователю одной строкой; полная пересборка — по слову «собери отчёт» (скилл status-report), решения спрашивай по одному только по его слову.")
PY
)
fi
```
(в) Строка 71 `$warning$mem_warn` → `$warning$mem_warn$report_warn`.
--- ПРОВЕРКА:
До правки хука: `bash forge-plugin/tests/hooks/test-session-start.sh` → FAIL на (1) и (4) (RED). После: `bash forge-plugin/tests/hooks/test-session-start.sh | tail -1` → `All tests passed`; в репо плагина `bash forge-plugin/hooks/session-start.sh </dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['hookSpecificOutput']['additionalContext'])" | grep -n 'Phase 5'` → одна строка


===== [docs] ШАГ 5: C1. CLAUDE.md (корень): 7 фаз, подсекция Phase 5, ROADMAP.md убран, таблица команд, evals, мусор .forge (~12 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/CLAUDE.md
--- ЧТО:
Точные правки (номера проверены sed):
- :3 «через 6-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4)» → «через 7-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4 → 5)».
- :85 «Служебный мусор (`.inject-state`, `.last-backup`, `state.yml`, `.github-*`, `graph.json`) отсечён» → «Служебный мусор (`.inject-state`, `.last-backup`, `state.yml`, `.github-*`, `graph.json`, `status-report.html`, `reports/shots/`) отсечён».
- :87 «## Development Workflow — 6-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4)» → «## Development Workflow — 7-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4 → 5)».
- :90 «**Память (петля):** пишет `.forge/direction.yml` (для Клода: directions/backlog/goal_shift) + `ROADMAP.md` (для глаз — все направления человекочитаемо). Цикл: …» → «**Память (петля):** пишет `.forge/direction.yml` (для Клода: directions/backlog/goal_shift). Документ «для глаз» отдельно не заводит — это отчёт «Что дальше» (Phase 5). Цикл: …» (хвост без изменений).
- :92 «**Выход:** обновлённые `direction.yml` + `ROADMAP.md`, первый физический шаг подан в `/forge:new-task`.» → «**Выход:** обновлённый `direction.yml`, первый физический шаг подан в `/forge:new-task`.»
- После :118 («Условный handoff: … новый чат для `/execute`.») вставить:
```
### Phase 5 — Итог: что дальше (`/forge:status-report`)
Отчёт «Что дальше» — единственный документ «где мы» для владельца: в каком состоянии проект, что чинит Клод в коде, какие решения нужны от владельца, в каком порядке и почему. Формат-эталон — `forge-plugin/docs/status-report-format.md`. Полная сборка — по команде или словам «собери отчёт», «отчёт „что дальше“», «что чинить, что решать», «покажи документом, где мы»: аудит параллельными субагентами (TODO/FIXME/заглушки, git-активность, инфраструктура, документация/.forge) + память `.forge` → находки с полями owner (code|decision|both), effort (S|M|L|-), block (crit|biz|imp|pol), status (open|done|deferred) → `.forge/status-report.json` (память проекта, коммитится memory-backup) → `skills/status-report/render.py` собирает `.forge/status-report.html` (Клод HTML руками не пишет; файл регенерируется, в `.forge/.gitignore`) → открывается в браузере. Скриншоты интерфейса — только если есть живой http-адрес (Playwright MCP, ≤6 снимков, PNG в `.forge/reports/shots/`, в HTML как data: URI); нет адреса — без картинок, без вопросов. Лёгкое обновление — само после «мержим»: finishing зовёт `render.py merged <task-slug>` — карточка задачи → «сделано», счётчик «устарел на N задач» +1, HTML пересобран. Карточка «Код», взятая в работу, уходит в `/forge:new-task`; после сохранения task-файла new-task пишет slug в карточку (`render.py link <card-id> <slug>`). Слова «что дальше по проекту» и «статус проекта» остаются за unblocker и forge-context. На GitHub отчёт не отражается.

**Выход:** `.forge/status-report.json` + `.forge/status-report.html`; при старте сессии — одна строка «решений ждут владельца — N, устарел на влитых задач — M» (session-start.sh).
```
- :127 (Auto-handoff) дописать в конец абзаца: « Phase 5 в цепочку auto-handoff не входит: полная сборка — только по команде/слову, после мержа отчёт обновляется механически.»
- Commands Reference, после строки `| `/forge:execute` | **Phase 4** — реализация |` (:174) добавить `| `/forge:status-report` | **Phase 5** — отчёт «Что дальше»: что чинить, что решать |`.
- :203 «бинарные критерии по всем 6 фазам (unblocker и refine-idea добавлены)» → «по всем 7 фазам (unblocker, refine-idea и status-report добавлены)»; :204 «пустая матрица на 6 фаз» → «пустая матрица на 7 фаз».
--- ПРОВЕРКА:
`grep -n 'ROADMAP\|6-фазн' /Users/mac/Projects/Plugin/plugin/CLAUDE.md` → пусто; `grep -c 'status-report' CLAUDE.md` → ≥ 8; `grep -n '### Phase 5' CLAUDE.md` → одна строка между Phase 4 и «### Git-модель»


===== [docs] ШАГ 6: C2. forge-plugin/README.md: 7 фаз, строка таблицы, полезная команда, ссылка на pipeline-v2 помечена исторической, как обновиться (~5 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/README.md
--- ЧТО:
- :3 «через **6-фазный пайплайн**» → «через **7-фазный пайплайн**».
- :5 «Визуальная схема пайплайна: [ideas/pipeline-v2.html](../ideas/pipeline-v2.html)» → «Визуальная схема пайплайна (историческая, без фазы 5): [ideas/pipeline-v2.html](../ideas/pipeline-v2.html)» — сам ideas/pipeline-v2.html НЕ трогаем.
- После :18 (строка `| 🚀 **execute** | …`) добавить строку таблицы: `| 📊 **status-report** | Собирает отчёт «Что дальше»: что чинит Клод, что решаешь ты, в каком порядке и почему. По команде — полный аудит проекта; после каждого мержа обновляется сам. |`
- После :38 (`/plugin install forge@forge-marketplace`) блок кода закрывается на :39; после :41 «Перезапусти Claude Code. Плагин активен.» добавить абзац:
```
Обновление до новой версии: `/plugin marketplace update forge-marketplace`, затем `/plugin update forge@forge-marketplace`, перезапусти Claude Code — в интро сессии появится новая версия.
```
- После :53 (`- `/forge:unblocker` — если застрял`) добавить `- `/forge:status-report` — отчёт «Что дальше»: что чинить, что решать (HTML-документ)`.
- :82 «под не-кодера: 6-фазный pipeline, русские триггеры» → «под не-кодера: 7-фазный pipeline, русские триггеры».
--- ПРОВЕРКА:
`grep -n '6-фазн' forge-plugin/README.md` → пусто; `grep -c 'status-report' forge-plugin/README.md` → 2; `grep -n 'plugin update' forge-plugin/README.md` → одна строка


===== [docs] ШАГ 7: C3. forge-plugin/COMMANDS.md: заголовок, ASCII-схема, таблица фаз, абзац «4 → 5 без handoff», новая секция 6.5, handoff execute, результат unblocker, workflow + сценарии, «Команды по этапам», «Быстрая помощь» (~15 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/COMMANDS.md
--- ЧТО:
- :9 «## Сердце плагина: 6-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4)» → «## Сердце плагина: 7-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4 → 5)».
- :11 хвост «дальше фазы идут подряд:» → «дальше фазы идут подряд; Phase 5 — итог по всему проекту, не по одной задаче (по команде, после мержа обновляется сам):».
- :14-16 ASCII-схема — заменить три строки на:
```
/forge:unblocker → /forge:new-task → /forge:refine-idea → /forge:plan → /forge:critique → /forge:execute → /forge:status-report
    Phase 0           Phase 1            Phase 1.5          Phase 2         Phase 3          Phase 4            Phase 5
  Направление        Понимание         Разбор идеи           План           Критика         Реализация        Что дальше
```
- После :28 (`| 4. Реализация | …`) добавить `| 5. Что дальше | `/forge:status-report` | влитые задачи + аудит проекта + память `.forge` | `.forge/status-report.json` + `.forge/status-report.html` — отчёт «Что дальше» (что чинит Клод, что решает владелец) |`.
- После :38 («Это значит: нельзя случайно выйти из критики…») добавить абзац:
```
**Phase 4 → Phase 5 — без auto-handoff:**
Полная сборка отчёта запускается только по команде или слову («собери отчёт», «что чинить, что решать», «покажи документом, где мы»). После «мержим» finishing-a-development-branch сам обновляет уже существующий отчёт (карточка влитой задачи → «сделано», счётчики пересчитаны, HTML пересобран) — без нового аудита. «Что дальше по проекту» — это `/forge:unblocker`, «статус проекта» — загрузка контекста; отчёт на них не откликается.
```
- :287 «**Handoff:** при достижении критерия готовности — передаёт в `/forge:validate` / `/forge:sync`» → «**Handoff:** при достижении критерия готовности — передаёт в `/forge:validate` / `/forge:sync`; после «мержим» отчёт «Что дальше» (Phase 5) обновляется сам».
- После :296 (`---` после примера execute) вставить новую секцию по образцу 3.5 (:180-206):
```
## 6.5. /forge:status-report (Phase 5: Итог — что дальше)

**Назначение:** Отчёт «Что дальше» — единственный документ «где мы» для владельца: что чинит Клод в коде, какие решения нужны от владельца, в каком порядке и почему

**Под капотом:** инвокает skill `status-report`; страницу собирает `skills/status-report/render.py` из `.forge/status-report.json` (формат — `docs/status-report-format.md`)

**Когда использовать:**
- «собери отчёт», «отчёт „что дальше“», «что чинить, что решать», «покажи документом, где мы»
- На границе этапа проекта (перед полишем, перед релизом) — не после каждой задачи
- НЕ на «что дальше по проекту» (это `/forge:unblocker`) и не на «статус проекта» (загрузка контекста)

**Что делает:**
- Параллельные субагенты-аудиторы: TODO/FIXME/заглушки, git-активность, инфраструктура, документация/.forge — плюс память `.forge` (status, direction, decisions, dead-ends)
- Сводит находки: владелец (Код / Решение / Решение+код), усилия S/M/L, блок (критично / решения / скоро / потом), один вердикт «Главное одной фразой»; счётчики футера считает рендерер
- Пишет `.forge/status-report.json` (память проекта, коммитится), собирает `.forge/status-report.html` и открывает в браузере — HTML руками не пишется
- Если у проекта есть запущенный интерфейс (живой http-адрес) — до 6 скриншотов через Playwright MCP, встроены в HTML; нет адреса или снимок не удался — отчёт без картинок, без вопросов; мусор браузера убирается
- После «мержим» обновляется сам: карточка задачи → «сделано», счётчики пересчитаны (без нового аудита)

**Handoff:** карточка «Код», которую владелец берёт в работу → `/forge:new-task` (Phase 1); открытые «Решения» копятся в памяти и напоминаются одной строкой при старте сессии

**Результат:** `.forge/status-report.json` + `.forge/status-report.html` (открыт в браузере)

**Пример:**
```
/forge:status-report

Собери отчёт «что дальше» — что чинить и что мне решать.
```

---
```
- :399 «**Результат:** обновлённые `.forge/direction.yml` (память для Клода) + `ROADMAP.md` (человекочитаемо) + карта проекта» → «**Результат:** обновлённый `.forge/direction.yml` (память для Клода) + карта проекта в чате; документ «для глаз» — отчёт «Что дальше» (`/forge:status-report`), ROADMAP.md не заводится».
- Workflow «Полный цикл» (:791-815): :815 «11. (Pull Request / Merge)» → «11. (Pull Request / Merge)     — после мержа отчёт «Что дальше» обновляется сам» и дописать:
```
   ↓
12. /forge:status-report        — Phase 5: Итог — полный отчёт «Что дальше» на границе этапа (по команде)
```
- Сценарии «API» (:830), «Миграция базы данных» (:846), «Быстрая разработка» (:870, там последняя строка `7. /forge:validate`): в конец каждого блока дописать `   ↓` и `N. «мержим»                     — мерж; отчёт «Что дальше» обновится сам` (N = 7, 7, 8).
- «Команды по этапам» — после блока `### Реализация (Phase 4)` (:916-919) добавить:
```
### Итог — что дальше (Phase 5)
- `/forge:status-report` — отчёт «Что дальше»: что чинит Клод, что решает владелец; после мержа обновляется сам
```
- «Быстрая помощь» (:1000-1016): после `/forge:execute          # Phase 4: Implementation` добавить:
```

# Отчёт «Что дальше» — что чинить, что решать (на границе этапа)
/forge:status-report    # Phase 5: Итог
```
--- ПРОВЕРКА:
`grep -n 'ROADMAP\|6-фазн' forge-plugin/COMMANDS.md` → пусто; `grep -c 'status-report' forge-plugin/COMMANDS.md` → ≥ 14; `grep -n '^## 6.5' forge-plugin/COMMANDS.md` → одна строка между `## 6.` и `## 7.`


===== [docs] ШАГ 8: C4. forge-plugin/commands/init.md — шаблон CLAUDE.md новых проектов: Phase 5, перенумерация After completing work, таблица команд, self-check, строка про GitHub (~8 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/init.md
--- ЧТО:
- :564 «## Development Workflow (6-фазный pipeline: 0 → 1 → 1.5 → 2 → 3 → 4)» → «## Development Workflow (7-фазный pipeline: 0 → 1 → 1.5 → 2 → 3 → 4 → 5)».
- После :582 (`4. `/forge:execute` — реализация, грязная работа делегируется субагентам, стоп на чекпоинтах плана`) и пустой строки вставить:
```
### Phase 5 — Итог: что дальше
5. `/forge:status-report` — отчёт «Что дальше» по всему проекту: что чинит Клод в коде, что решает владелец, в каком порядке; полный аудит — по команде («собери отчёт»), после каждого мержа обновляется сам
```
- :584-586 «### After completing work / 5. `/forge:sync` — update docs / 6. `/forge:validate` — verify code vs plan» → нумерация 6 и 7.
- Таблица команд: после :624 (`| `/forge:execute` | **Phase 4** — реализация |`) добавить `| `/forge:status-report` | **Phase 5** — отчёт «Что дальше»: что чинить, что решать |`.
- :660 «6. **Commands table complete:** At minimum: start, unblocker (Phase 0), new-task, refine-idea (Phase 1.5), plan, critique, execute, sync, validate, cleanup» → «…, critique, execute, status-report (Phase 5), sync, validate, cleanup».
- :855 «After this, the pipeline (new-task → plan → critique → execute) mirrors to GitHub automatically.» → «After this, the pipeline (new-task → plan → critique → execute) mirrors to GitHub automatically. Отчёт «Что дальше» (Phase 5) на GitHub не отражается — он живёт в `.forge/` и уезжает туда с памятью.»
- Catalog-шаблон Step 8 (:352-393) НЕ трогаем: файла `.forge/status-report.json` при init ещё нет; запись в catalog добавляет сам скилл status-report при первой полной сборке (см. interfaces).
--- ПРОВЕРКА:
`grep -n 'status-report' forge-plugin/commands/init.md` → 5 строк (Phase 5, таблица, self-check, :855-абзац, заголовок фазы); `grep -n '6-фазн' forge-plugin/commands/init.md` → пусто; `sed -n '584,590p' forge-plugin/commands/init.md` показывает `6. `/forge:sync`` и `7. `/forge:validate``


===== [docs] ШАГ 9: C5. forge-plugin/docs/forge-runtime-flow.md — 7 фаз в схемах, таблица контрактов, кто читает/пишет, timeline; ROADMAP.md убран (~12 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/docs/forge-runtime-flow.md
--- ЧТО:
- :12 «| `SessionStart` | … | Короткое интро: версия, пайплайн, ROUTING + DOC DISCIPLINE |» → «…ROUTING + DOC DISCIPLINE; напоминания: память не сохранена >24ч, отчёт «Что дальше» (ждут решения / устарел) |».
- :30 «• таблица 6 фаз пайплайна» → «• таблица 7 фаз пайплайна».
- :117 «## 4. The 6-Phase Pipeline (0 → 1 → 1.5 → 2 → 3 → 4)» → «## 4. The 7-Phase Pipeline (0 → 1 → 1.5 → 2 → 3 → 4 → 5)».
- Mermaid (:121-157): после :126 (`B -- "Простой read-only вопрос" --> ANS["Прямой ответ"]`) добавить `    B -- "«собери отчёт» / граница этапа" --> P5["/forge:status-report<br/>Phase 5: Итог — что дальше"]` и `    P5 --> P5A["Аудит субагентами + память .forge →<br/>status-report.json → render.py → status-report.html"]`; после :156 (`P4CHK -- "Всё сделано" --> SYNC[...]`) добавить `    SYNC --> P5U["finishing после мержа:<br/>render.py merged slug → карточка «сделано»,<br/>HTML пересобран (без аудита)"]`.
- :163 «| 0. Direction | `/forge:unblocker` | `direction.yml` + `ROADMAP.md`, первый шаг → new-task | …» → «| 0. Direction | `/forge:unblocker` | `direction.yml`, первый шаг → new-task | …»; после :168 добавить `| 5. Итог — что дальше | `/forge:status-report` | `.forge/status-report.json` + `.forge/status-report.html` | По команде; после мержа обновляется сам (карточка → «сделано») |`.
- :187 `H1["session-start.sh<br/>ЧИТАЕТ: .claude-plugin/plugin.json (версия)"]` → `H1["session-start.sh<br/>ЧИТАЕТ: .claude-plugin/plugin.json (версия),<br/>.forge/.last-backup, .forge/status-report.json"]`.
- :203 `SW2["unblocker → .forge/direction.yml + ROADMAP.md"]` → `SW2["unblocker → .forge/direction.yml<br/>status-report → .forge/status-report.json (+ .html)"]`.
- :213 (D2, список L1) «learnings.yml, direction.yml"]» → «learnings.yml, direction.yml,<br/>status-report.json"]».
- Timeline: после :302 («↓ finishing-a-development-branch       тесты → merge в master → ветка удалена») добавить:
```
        ↓ render.py merged <slug>             отчёт «Что дальше» обновлён сам

t=18    User: "собери отчёт"
        ↓ Claude → /forge:status-report       Phase 5: аудит субагентами → status-report.json
        ↓ render.py → status-report.html      открыт в браузере
```
--- ПРОВЕРКА:
`grep -n 'ROADMAP\|6-Phase\|6 фаз' forge-plugin/docs/forge-runtime-flow.md` → пусто; `grep -c 'status-report' forge-plugin/docs/forge-runtime-flow.md` → ≥ 8


===== [docs] ШАГ 10: C6. GUIDE.md — строка команды и ROADMAP.md → отчёт (строку 1 «v5.0.0» и пример на :313 не трогаем) (~4 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/GUIDE.md
--- ЧТО:
- После :152 (`| `/forge:unblocker` | **Phase 0** — …`) добавить `| `/forge:status-report` | **Phase 5** — отчёт «Что дальше»: что чинит Клод, что решает владелец, в каком порядке; после мержа обновляется сам |`.
- :431 хвост «Память петлёй: `.forge/direction.yml` (для Клода) + `ROADMAP.md` (для глаз).» → «Память петлёй: `.forge/direction.yml` (для Клода); документ для глаз — отчёт «Что дальше» (`/forge:status-report`, Phase 5).»
- :1 «# FORGE v5.0.0 — Руководство пользователя» и :313 «Claude: Phase 4: Implementation» — без изменений: GUIDE целиком устарел (brainstorm/write-plan), поднимать номер версии — врать об актуальности; это отдельная задача.
--- ПРОВЕРКА:
`grep -n 'ROADMAP' GUIDE.md` → пусто; `grep -c 'status-report' GUIDE.md` → 2


===== [docs] ШАГ 11: C7. Скиллы и evals: execute (фраза про мерж), project-unblocker без ROADMAP.md, criteria/unblocker.yml, новый criteria/status-report.yml, transition-matrix, абзац в status-report-format.md (~15 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/execute/SKILL.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/project-unblocker/SKILL.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/criteria/unblocker.yml; /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/criteria/status-report.yml (создать); /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/transition-matrix.tsv; /Users/mac/Projects/Plugin/plugin/forge-plugin/docs/status-report-format.md
--- ЧТО:
1) execute/SKILL.md:236 «…Он сам сохранит несохранённое, вольёт ветку задачи в основную и уберёт её — как в других handoff пайплайна…» → «…вольёт ветку задачи в основную и уберёт её; если в проекте есть отчёт «Что дальше», обновит его сам (карточка задачи → «сделано») — как в других handoff пайплайна…».
2) project-unblocker/SKILL.md: :207 «Карту и направления (direction.yml, ROADMAP.md) можно записать и раньше» → «Карту и направления (direction.yml) можно записать и раньше»; :211 «Два слоя памяти:» → «Слой памяти:»; :217 абзац `**`ROADMAP.md`** (корень, для глаз Антона) — …` целиком → «**Документ «для глаз» отдельно НЕ пишется.** Единственный документ «где мы» для владельца — отчёт «Что дальше» (`/forge:status-report`, фаза 5): он собирается по слову «собери отчёт» и сам обновляется после мержей. Просит «покажи документом» — отсылай туда, ROADMAP.md не заводи.»; :245 «Если есть `direction.yml` и/или `ROADMAP.md`:» → «Если есть `direction.yml`:»; :246 «1. Прочитай оба.» → «1. Прочитай его (и `.forge/status-report.json`, если есть — там статусы находок open/done/deferred).»; :249 «4. Сделанное → в ROADMAP «Выполнено» с датой, убрать из `directions`.» → «4. Сделанное → убрать из `directions` (в отчёте «Что дальше» карточка уже «сделано» после мержа).»; :256 «(new-task → plan → critique → execute)» → «(new-task → plan → critique → execute; итог по проекту — status-report)».
3) evals/criteria/unblocker.yml:16 `question: "Обновлены .forge/direction.yml и ROADMAP.md?"` → `question: "Обновлён .forge/direction.yml (ROADMAP.md не заводится — документ для глаз это отчёт «Что дальше»)?"`.
4) Новый evals/criteria/status-report.yml (шаблон evals/README.md:54-64, binary только):
```yaml
phase: status-report
checks:
  - id: html_from_json_not_by_hand
    question: "Страница собрана render.py из .forge/status-report.json, а не написана Клодом руками?"
    type: binary

  - id: owner_and_effort_on_every_card
    question: "У каждой карточки есть владелец (Код / Решение / Решение+код) и усилия S/M/L (— для чистых решений)?"
    type: binary

  - id: verdict_first
    question: "Наверху один вердикт «Главное одной фразой» с указанием, откуда начинать?"
    type: binary

  - id: honest_counters
    question: "Счётчики (N находок → M блоков, K отложено) сходятся с данными JSON?"
    type: binary

  - id: screenshots_only_when_live
    question: "Скриншоты сняты только при живом http-адресе; без него отчёт собран без картинок, без ошибок и без вопросов владельцу; мусор (.playwright-mcp/, снимки в корне) убран?"
    type: binary

  - id: triggers_not_stolen
    question: "На «что дальше по проекту» / «статус проекта» отчёт НЕ запускался (это unblocker / forge-context)?"
    type: binary

  - id: plain_first_person_language
    question: "Текст от первого лица, на «ты», без жаргона — последствия вместо терминов?"
    type: binary
```
5) transition-matrix.tsv — добавить колонку `to_status-report` перед `to_END` и строку `status-report` (таб-разделитель):
```
from_phase	to_unblocker	to_new-task	to_refine-idea	to_plan	to_critique	to_execute	to_status-report	to_END
unblocker	-	0	0	0	0	0	0	0
new-task	0	-	0	0	0	0	0	0
refine-idea	0	0	-	0	0	0	0	0
plan	0	0	0	-	0	0	0	0
critique	0	0	0	0	-	0	0	0
execute	0	0	0	0	0	-	0	0
status-report	0	0	0	0	0	0	-	0
```
6) docs/status-report-format.md — в конец (после раздела «Чем наполнять (процесс)») добавить:
```
## Как генерируется в плагине

Скилл `skills/status-report/SKILL.md` (`/forge:status-report`, фаза 5) складывает находки аудита в `.forge/status-report.json` (память проекта, коммитится); страницу по этому формату собирает `skills/status-report/render.py` (только стандартная библиотека Python) в `.forge/status-report.html` — Клод HTML руками не пишет, счётчики футера считает рендерер. Скриншоты интерфейса (только при живом http-адресе) — до 6 штук, PNG в `.forge/reports/shots/`, в HTML как data: URI; нет файла — карточка без картинки. После мержа задачи `render.py merged <task-slug>` переводит карточку в «сделано» и пересобирает HTML без нового аудита.
```
--- ПРОВЕРКА:
`grep -rn 'ROADMAP' forge-plugin/ CLAUDE.md GUIDE.md --include=*.md --include=*.yml --include=*.sh` → пусто (в .forge/reviews и .forge/plans упоминания — история, не трогаем); `python3 -c "import csv;r=list(csv.reader(open('forge-plugin/evals/transition-matrix.tsv'),delimiter='\t'));print(len(r),{len(x) for x in r})"` → `8 {9}`; `ruby -ryaml -e 'YAML.load_file("forge-plugin/evals/criteria/status-report.yml"); puts "OK"'` → OK; `ls forge-plugin/evals/criteria/ | wc -l` → 8


===== [docs] ШАГ 12: C8. using-forge/SKILL.md — строка в таблице Available Skills (~3 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/using-forge/SKILL.md
--- ЧТО:
После :117 (`| forge:execute | Run plans with review checkpoints |`) добавить `| forge:status-report | Phase 5 — отчёт «Что дальше»: что чинить, что решать (HTML из .forge/status-report.json) |`. Строки :92 («напомни запустить /forge:sync») и остальное — без изменений. `.forge/library/commands/spec.yml` и `skills/spec.yml` (L2, перечисляют ещё brainstorm/write-plan) не трогаем — они устарели целиком, это не наша задача.
--- ПРОВЕРКА:
`grep -n 'forge:status-report' forge-plugin/skills/using-forge/SKILL.md` → одна строка сразу после forge:execute


===== [docs] ШАГ 13: M1. Версия 7.7.0 и «7-phase … → status-report» в трёх манифестах (~4 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/plugin.json; /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/marketplace.json; /Users/mac/Projects/Plugin/plugin/.claude-plugin/marketplace.json
--- ЧТО:
Сейчас (проверено): plugin.json:3 description «6-phase development pipeline for Claude Code (unblocker → new-task → refine-idea → plan → critique → execute) with tiered…», :4 `"version": "7.6.0"`; forge-plugin/.claude-plugin/marketplace.json:11-12 — то же; корневой .claude-plugin/marketplace.json:3 «Forge — 6-phase development pipeline and project memory for Claude Code», :11-12 — то же. Одной командой:
```bash
cd /Users/mac/Projects/Plugin/plugin
for f in forge-plugin/.claude-plugin/plugin.json forge-plugin/.claude-plugin/marketplace.json .claude-plugin/marketplace.json; do
  sed -i '' \
    -e 's/"version": "7\.6\.0"/"version": "7.7.0"/' \
    -e 's/6-phase development pipeline for Claude Code (unblocker → new-task → refine-idea → plan → critique → execute)/7-phase development pipeline for Claude Code (unblocker → new-task → refine-idea → plan → critique → execute → status-report)/' \
    -e 's/Forge — 6-phase development pipeline/Forge — 7-phase development pipeline/' "$f"
done
```
forge-tray/forge-tray-mac.py (VERSION) — НЕ трогаем (чужой WIP в stash).
--- ПРОВЕРКА:
`grep -h '"version"\|phase' forge-plugin/.claude-plugin/plugin.json forge-plugin/.claude-plugin/marketplace.json .claude-plugin/marketplace.json | sort -u` → только строки с `7.7.0`, `7-phase … → status-report)` и `Forge — 7-phase…`; `for f in …; do python3 -c "import json,sys; json.load(open(sys.argv[1]))" $f; done` → без ошибок; `bash forge-plugin/hooks/session-start.sh </dev/null | grep -o 'v7.7.0'` → `v7.7.0`


===== [docs] ШАГ 14: M2. Память проекта: index.yml (catalog status-report, version, бюджет 2500), map.yml, decisions.yml, journal.yml, status.yml (~12 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/.forge/index.yml; /Users/mac/Projects/Plugin/plugin/.forge/map.yml; /Users/mac/Projects/Plugin/plugin/.forge/decisions.yml; /Users/mac/Projects/Plugin/plugin/.forge/journal.yml; /Users/mac/Projects/Plugin/plugin/.forge/status.yml
--- ЧТО:
**index.yml** (сейчас 2320 байт, лимит хука 2500 — context-inject.sh:17-22; новая запись catalog = 128 байт, плюс «→ 5 status-report» в goal — не влезает; ужимаем: убрать `note:` у direction (:46, −132 байта) и укоротить session-блок). Правки: :3 «6-фазный pipeline (0 unblocker → … → 4 execute)» → «7-фазный pipeline (0 unblocker → 1 new-task → 1.5 refine-idea → 2 plan → 3 critique → 4 execute → 5 status-report)»; :7 `version: "7.7.0"`; :11 `task: "v7.7.0 (отчёт «Что дальше») на GitHub"`; удалить :46 (`note: "Strategic layer: …"`); после блока direction добавить:
```yaml
  status-report:
    path: .forge/status-report.json
    tags: [report, what-next, findings, decisions-pending, owner, effort]
```
session-блок (:48-57) → `started: "2026-09-04"`, `goal: "Отчёт «Что дальше» — фаза 5 (status-report), v7.7.0"`, `done: ["v7.7.0 в master: скилл status-report + render.py, фаза 5 в доках/хуках"]`, `now: "Сессия закрыта, версия на GitHub"`, `next: "Собрать первый отчёт на живом проекте"`, `last_session: "2026-09-04 — v7.7.0: отчёт «Что дальше» (фаза 5): render.py из JSON, аудит агентами, лёгкое обновление после мержа, напоминание при старте"`. Полный кандидат уже собран и измерен: /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad/index-candidate.yml — **2188 байт** (запас 312). finishing/session-awareness потом перепишут now/last_session — держать session.goal/done короткими.

**map.yml**: :22-24 `forge-plugin/commands/: files: 24` → `files: 27` (сейчас реально 26 + status-report.md), about «…, roadmap, status-report, и др.»; :26-28 `forge-plugin/skills/: files: 32` → `files: 35` (сейчас 34 директории + 1), about «~35 скиллов…»; после блока `forge-plugin/skills/roadmap/` (:42-44) добавить:
```yaml
  forge-plugin/skills/status-report/:
    files: "SKILL.md, render.py"
    about: "Фаза 5: отчёт «Что дальше» — render.py собирает .forge/status-report.html из .forge/status-report.json (build / merged <slug> / link <id> <slug>)"
```
:66-68 docs about → «Спецификация, архитектура контекста, runtime-flow, формат отчёта «Что дальше»»; :70-72 tests `files: 25` → пересчитать `find forge-plugin/tests -type f | wc -l` (сейчас 42 + новые тесты).

**decisions.yml** — в конец (формат id/date/decision/why/tags как у forge-memory-in-git :46-50):
```yaml

  - id: status-report-phase-5
    date: "2026-09-04"
    decision: "Фаза 5 «Итог: что дальше» (/forge:status-report): данные отчёта — .forge/status-report.json (память, коммитится memory-backup), HTML собирает skills/status-report/render.py (stdlib Python) в .forge/status-report.html (в .forge/.gitignore, регенерируется). Полная сборка — по команде/слову с аудитом параллельными субагентами; после мержа finishing зовёт render.py merged <slug>. Скриншоты — только при живом http-адресе, ≤6, data: URI, PNG в .forge/reports/shots/ (не в git). ROADMAP.md из навигатора убран. На GitHub отчёт не отражается"
    why: "Один документ «где мы» для не-кодера вместо ROADMAP.md + карты в чате. JSON, а не YAML — на Маке нет PyYAML (python3 -c 'import yaml' падает), json в stdlib. Рендерер вместо ручного HTML — урок карты проекта: данные + шаблон не ломаются от опечатки, а обновление после мержа становится механическим. Полный аудит на каждый мерж — перебор (дорого), лёгкое обновление — дёшево"
    tags: [pipeline, status-report, memory, render, phase-5]
```
**journal.yml** — новая запись первой (после :1 `entries:`); записей станет 7 — лимит session-awareness (>7 → удалять старые) не превышен:
```yaml
  - date: "2026-09-04"
    summary: "v7.7.0 — фаза 5: отчёт «Что дальше» (status-report)"
    result: "Скилл status-report + команда, render.py (JSON → HTML по status-report-format.md, TDD), лёгкое обновление после мержа в finishing, напоминание в session-start (+ тест), фаза 5 в CLAUDE.md/README/COMMANDS/init/runtime-flow/statusline/evals, ROADMAP.md убран из навигатора"
    next: "Собрать первый отчёт на живом проекте; проверить скриншоты через Playwright на запущенном интерфейсе"

```
**status.yml**: :2 «4-фазный pipeline: /forge:new-task → /forge:plan → /forge:critique → /forge:execute» → «7-фазный pipeline: unblocker → new-task → refine-idea → plan → critique → execute → status-report»; после :7 (Statusline) добавить `  - "Отчёт «Что дальше» (status-report): JSON → render.py → HTML, обновление после мержа, напоминание при старте"`.

`forge-plugin/docs/context-system.md` не трогаем: его catalog (:49-79) — общий шаблон, direction.yml туда тоже не добавляли.
--- ПРОВЕРКА:
`wc -c .forge/index.yml` → ≤ 2400 (ожидаемо ~2190); `ruby -ryaml -e '%w[.forge/index.yml .forge/decisions.yml .forge/journal.yml .forge/map.yml .forge/status.yml].each{|f| YAML.load_file(f)}; puts "YAML OK"'` → `YAML OK`; `grep -c 'id:' .forge/decisions.yml` → 11; `bash forge-plugin/tests/hooks/test-context-inject.sh | tail -1` → `All tests passed`


===== [docs] ШАГ 15: R1. Релиз: тесты → «мержим» (finishing Option 1 → push master) → проверка 7.7.0 на GitHub → обновление установленного плагина → вернуть WIP из stash (~12 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin (git: feat/status-report → master); /Users/mac/.claude/plugins/installed_plugins.json (проверка версии); /Users/mac/.claude/plugins/marketplaces/forge-marketplace (клон маркетплейса)
--- ЧТО:
Как выпускали 7.6.0 (проверено): тегов в репо 0, GitHub-релизов нет, `git log -- plugin.json` — версия поднимается обычным коммитом в master (d2833bd «…(v7.6.0)», 70fa98e «…+ v7.5.0»). Маркетплейс `forge-marketplace` подключён как `github: anton-ai5010/forge` (known_marketplaces.json) и тянет default-ветку; установленный плагин лежит в `~/.claude/plugins/cache/forge-marketplace/forge/7.6.0` (installed_plugins.json: version 7.6.0, gitCommitSha a2a4b5d) — путь кэша ключуется ВЕРСИЕЙ из plugin.json, поэтому бамп в plugin.json обязателен, тег/релиз — нет. Достаточно: plugin.json 7.7.0 в master на GitHub.

Последовательность:
```bash
cd /Users/mac/Projects/Plugin/plugin
# 1) все bash-тесты хуков зелёные
for t in forge-plugin/tests/hooks/test-*.sh; do printf '%s: ' "$t"; bash "$t" | tail -1; done
# 2) последний свип по перечислениям (до мержа)
grep -rn '6-фазн\|6-phase\|6 фаз\|ROADMAP' CLAUDE.md GUIDE.md forge-plugin/ .forge/index.yml .forge/status.yml --include=*.md --include=*.yml --include=*.sh --include=*.json
```
3) Владелец говорит «мержим» → finishing-a-development-branch, Option 1: покажет `git status --short` (там должны быть только файлы задачи — settings.json и tray в stash), закоммитит, вольёт в master, обновит index.yml (now/last_session/version — уже 7.7.0), вызовет backup.sh → push master. Отдельного `git push` не нужно.
4) Проверка на GitHub:
```bash
git rev-parse master origin/master            # одинаковые
gh api repos/anton-ai5010/forge/contents/forge-plugin/.claude-plugin/plugin.json --jq .content | base64 -d | grep '"version"'   # "7.7.0"
```
5) Обновить установленный плагин — в Claude Code: `/plugin marketplace update forge-marketplace`, затем `/plugin update forge@forge-marketplace` (из терминала: `claude plugin marketplace update forge-marketplace && claude plugin update forge@forge-marketplace`), перезапустить Claude Code.
6) Вернуть чужой WIP: `git stash pop` (на master, либо `git checkout feat/tray-save-command && git stash pop`) — конфликтов не будет, задача эти файлы не трогает.
--- ПРОВЕРКА:
Шаг 1 → каждая строка `All tests passed`; шаг 2 → пусто; шаг 4 → хэши равны и `"version": "7.7.0"`; после шага 5: `python3 -c "import json;print(json.load(open('/Users/mac/.claude/plugins/installed_plugins.json'))['plugins']['forge@forge-marketplace'][0]['version'])"` → `7.7.0`, `ls ~/.claude/plugins/cache/forge-marketplace/forge/` содержит `7.7.0`, интро новой сессии — «Forge plugin (v7.7.0) активен.» и строка `Phase 5   /forge:status-report`; после шага 6: `git stash list` → пусто, `git status --short` → ` M .claude/settings.json` и ` M forge-tray/forge-tray-mac.py`


===== INTERFACES:
Что мой кусок (доки/манифесты/хуки/релиз/git) ожидает от кусков «скилл + команда» и «рендерер»; имена зафиксированы в доках, менять — согласованно:

ФАЙЛЫ
- forge-plugin/skills/status-report/SKILL.md (name: status-report) и forge-plugin/commands/status-report.md (по образцу commands/evolve.md: description + `disable-model-invocation: true` + «Invoke the forge:status-report skill…»). Имя фазы в доках: «Phase 5 — Итог: что дальше»; в COMMANDS.md секция «## 6.5. /forge:status-report (Phase 5: Итог — что дальше)».
- forge-plugin/skills/status-report/render.py — stdlib only; читает /<проект>/.forge/status-report.json, пишет .forge/status-report.html (один живой файл, в .forge/.gitignore — шаг D1).
- .forge/reports/shots/*.png — снимки (в .forge/.gitignore); в JSON — только путь; нет файла → карточка без картинки.
- forge-plugin/tests/hooks/test-session-start.sh (мой, шаг H2) и тест рендерера (кусок рендерера, по образцу test-memory-backup.sh) — оба запускаются `bash forge-plugin/tests/hooks/test-*.sh`, последняя строка «All tests passed».
- forge-plugin/evals/criteria/status-report.yml (мой, шаг C7) — критерии, которым должен соответствовать скилл.

CLI РЕНДЕРЕРА (имена подкоманд упомянуты в CLAUDE.md, COMMANDS.md, runtime-flow.md, map.yml, status-report-format.md)
- `python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" build` — JSON → HTML, сброс `stale_merges` в 0 при полной сборке (или это делает скилл при записи JSON — решить в куске рендерера, но поле должно обнуляться).
- `… render.py merged <task-slug>` — вызывается finishing-a-development-branch (Option 1, после успешного мержа, рядом с обновлением index.yml, SKILL.md:126-130): карточка с этим task_slug → status done, `stale_merges` += 1, HTML пересобран. Нет JSON → тихий no-op, exit 0.
- `… render.py link <card-id> <slug>` — вызывается new-task после шага 9 (сохранение task-файла), когда задача пришла из карточки отчёта: пишет task_slug в карточку.

ПОЛЯ JSON, которые читает session-start.sh (шаг H2) — точные имена и значения:
- `findings`: массив объектов с `owner` ∈ {"code","decision","both"} и `status` ∈ {"open","done","deferred"} (плюс id, what, why, effort, block, source, task_slug?, screenshot? — по принятым решениям).
- `stale_merges`: целое, число влитых задач с момента полной сборки (инкрементирует `render.py merged`, обнуляет полная сборка).
- `generated`: дата "YYYY-MM-DD" (в напоминании не используется, но нужна в мета-строке отчёта).
Формула напоминания: pending = count(status=="open" and owner in {"decision","both"}); печатается только если pending>0 или stale_merges>0; текст: «📊 Отчёт «Что дальше»: решений ждут владельца — N, устарел на влитых задач — M.» Битый JSON → тишина, хук не падает.

STATUSLINE: скилл в начале фазы пишет `.forge/state.yml` (`phase: status-report`, `task: …`) как execute/SKILL.md:40-44, в конце — `phase: idle`; statusline.sh (шаг H1) маппит `status-report|"Phase 5"|5` → «📊 Фаза 5: Что дальше».

CATALOG index.yml: в репозитории плагина запись `status-report: {path: .forge/status-report.json, tags: [report, what-next, findings, decisions-pending, owner, effort]}` добавляю я (шаг M2). В чужих проектах init.md её НЕ создаёт (файла ещё нет) — скилл status-report при первой полной сборке сам дописывает эту запись в catalog, если её нет, и следит за лимитом 2500 байт (context-inject.sh:17-22).

GITIGNORE / BACKUP: `.forge/.gitignore` и heredoc в backup.sh получают `reports/shots/` и `status-report.html` (шаг D1); status-report.json коммитится штатно через `git add .forge`. Если скилл после полной сборки вызывает `bash "$CLAUDE_PLUGIN_ROOT/skills/memory-backup/backup.sh" "отчёт «Что дальше»"` — добавляю его в список вызывающих memory-backup/SKILL.md:39-42.

ТРИГГЕРЫ (описаны в COMMANDS.md/CLAUDE.md): «собери отчёт», «отчёт „что дальше“», «что чинить, что решать», «покажи документом, где мы»; НЕ «что дальше по проекту» (unblocker), НЕ «статус проекта» (forge-context).

GIT/РЕЛИЗ: ветка feat/status-report от master (шаг G1), чужой WIP (.claude/settings.json, forge-tray/forge-tray-mac.py) в stash «wip tray-save-command…», память (.forge/learnings.yml + task-файлы) уходит в master через backup.sh до ветвления. Релиз = plugin.json 7.7.0 в master на GitHub (тегов/релизов в репо нет и не было); установленный плагин обновляется `/plugin marketplace update forge-marketplace` + `/plugin update forge@forge-marketplace` (кэш ключуется версией из plugin.json).

===== OPEN QUESTIONS:
- Кто правит forge-plugin/skills/project-unblocker/SKILL.md (:207, :211, :217, :245-249, :256 — убрать ROADMAP.md): я включил это в шаг C7 как перечисление, но если кусок «скилл» тоже трогает навигатор — оставить одному, чтобы не было двух правок одного файла.
- Зовёт ли скилл status-report backup.sh сразу после полной сборки (рекомендую да: JSON — память, пусть уезжает в git сразу)? От ответа зависит одна строка в memory-backup/SKILL.md:39-42 (шаг D1, п.4).
- Кто обнуляет stale_merges при полной сборке — render.py build или скилл при записи JSON? Для session-start.sh неважно, но должно быть ровно одно место.
- Запись catalog для status-report в чужих проектах: подтвердить, что её добавляет сам скилл при первой сборке (init.md catalog-шаблон я не трогаю, файла при init нет). Если решат добавлять в init — правка init.md:381-384 (рядом с direction) + следить за лимитом L0.
- Сценарии COMMANDS.md «API»/«Миграция»/«Быстрая разработка» (:830/:846/:870): я добавил по одной строке «мержим — отчёт обновится сам». Если критики сочтут шумом — убрать, обязательного там ничего нет (Phase 5 не пофазовый шаг задачи).
- Нужен ли prompt-тест на разведение триггеров (tests/skill-triggering/: «что дальше по проекту» → unblocker, «собери отчёт» → status-report)? Это кусок скилла; в критерии готовности разведение триггеров есть, автоматической проверки сейчас нет.
- GUIDE.md:1 «FORGE v5.0.0» и его таблица команд (:141-157) устарели целиком (brainstorm/write-plan) — я добавляю только строку status-report и снимаю ROADMAP; полная актуализация GUIDE — отдельная задача, подтвердить, что так и оставляем.

===== RISKS:
- Бюджет L0: index.yml после правок ~2190 байт при лимите 2500 (context-inject.sh:17-22) — запас 312 байт. session-awareness/finishing перепишут session.goal/done/last_session в конце сессии: если написать длинно, хук молча обрежет хвост (last_session). Держать session-блок коротким, после каждой записи — `wc -c .forge/index.yml`.
- finishing Option 1 коммитит всё из `git status --short` (`git add -A`, SKILL.md:91-93). Без stash из шага G1 чужие правки settings.json и forge-tray-mac.py уедут в коммит задачи и в master. Если G1 пропустят — перед «мержим» проверить `git status --short` вручную.
- backup.sh на master (шаг G1) делает push — это штатное поведение плагина (memory-backup), но push случится до начала работы над задачей; если владелец против ранних пушей — альтернатива: `git stash push -m … -- .forge/learnings.yml` и `git add -N`-free подход, но тогда learnings уедет в коммит задачи при мерже.
- Обновление установленного плагина: кэш `~/.claude/plugins/cache/forge-marketplace/forge/<version>` ключуется версией из plugin.json — если забыть бамп (шаг M1), `/plugin update` оставит 7.6.0, и владелец не увидит фазу 5 при живой проверке. Проверка — интро «Forge plugin (v7.7.0) активен».
- session-start.sh: python3 heredoc внутри $( ) под `set -euo pipefail` — падение python (нет python3, битый JSON) гасится `|| true`, но результат — тишина без диагностики; тест (6) в test-session-start.sh это фиксирует. Если поле переименуют (stale_merges/owner/status), напоминание молча покажет нули — контракт полей закреплён в interfaces.
- Много перечислений фаз в разных файлах (CLAUDE.md, README, COMMANDS, init.md, runtime-flow, GUIDE, session-start, statusline, evals, index.yml, status.yml) — легко пропустить одно. Страховка — единый grep из шага R1 п.2 (`6-фазн|6-phase|6 фаз|ROADMAP`) до мержа; forge-plugin/.forge/entities.yml, ideas/pipeline-v2.html, .forge/reviews и .forge/plans сознательно не трогаем (история).
- README.md:5 продолжает ссылаться на ideas/pipeline-v2.html — я лишь помечаю ссылку исторической; если владелец ждёт актуальную картинку, это отдельная задача (схему не трогаем по решению).
- `.playwright-mcp/` в корневом .gitignore — страховка для репозитория плагина; в проектах владельца мусор убирает сам скилл (по решению). Если скилл этого не сделает, снимки/логи попадут в `git add -A` при finishing в чужих проектах.
- Ruby используется только в verify (`ruby -ryaml`) — на Маке есть (проверено); на Linux-ПК может не быть, тогда проверять YAML через `python3 -c 'import yaml'` не выйдет (PyYAML нет) — верифицировать глазами или пропустить.
