

===== ШАГ 1: D0. Git-состояние перед работой: settings.json — в именованный stash, трей уже влит, task-файлы уедут памятью (~5 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/.claude/settings.json; /Users/mac/Projects/Plugin/plugin/forge-tray/forge-tray-mac.py; /Users/mac/Projects/Plugin/plugin/.forge/tasks/2026-09-06-project-guide.md; /Users/mac/Projects/Plugin/plugin/.forge/tasks/2026-09-06-project-guide/reference-vespera-guide.html
--- ЧТО:
Факты (проверено `git status --short` на ветке feat/project-guide): грязный ТОЛЬКО `.claude/settings.json` (перенос блока permissions наверх + два мусорных allow: `Bash(cat)` и одноразовый `Bash(bash __TRACKED_VAR__/skills/github-sync/sync.sh create-task …confidence-in-memory…)`); `forge-tray/forge-tray-mac.py` ЧИСТ — WIP трея уже влит в master коммитом e739b6f (`feat(tray): фаза 5 и фаза 0 в меню…`, VERSION = "7.7.0"), поэтому в этой задаче трей правим как обычный файл (шаг D5), без stash. Stash пуст, master == origin/master (0 0). Untracked: `.forge/tasks/2026-09-06-project-guide.md` + папка с эталоном (52 КБ) — это память, её заберёт backup.sh первым же `[forge] память:` коммитом (не стешим).

Действие — до любого кода:
```bash
cd /Users/mac/Projects/Plugin/plugin
git stash push -m "wip settings.json: permissions + одноразовый allow" -- .claude/settings.json
bash forge-plugin/skills/memory-backup/backup.sh "задача project-guide + эталон Vespera"
```
Почему: finishing в Option 1 делает `git add -A` (SKILL.md:91-93) — settings.json с мусорным allow ушёл бы в коммит задачи. Итоговое решение по settings.json — в Чекпоинте C (предложить `git checkout -- .claude/settings.json`: deny-список и так в HEAD, allow-строки — одноразовый мусор от кнопки «always allow»).
--- ПРОВЕРКА:
`git status --short` → пусто; `git stash list` → одна строка `wip settings.json…`; `git log --oneline -1` → `[forge] память: задача project-guide + эталон Vespera`; `git diff master --stat` → 2 файла в .forge/tasks; `grep -c 'forge:status-report' forge-tray/forge-tray-mac.py` → 2 (файл чист и ждёт правки в D5)


===== ШАГ 2: D1. Переезд файлов status-report → project-guide/guide через git mv (история сохраняется) (~10 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/render.py; /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/status-report.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-status-report.sh; /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/fixtures/status-report-sample.json; /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/skill-triggering/prompts/status-report.txt; /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/skill-triggering/run-all.sh; /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/criteria/status-report.yml; /Users/mac/Projects/Plugin/plugin/forge-plugin/docs/status-report-format.md
--- ЧТО:
```bash
cd /Users/mac/Projects/Plugin/plugin/forge-plugin
git mv skills/status-report skills/project-guide
git mv commands/status-report.md commands/guide.md
git mv tests/hooks/test-status-report.sh tests/hooks/test-project-guide.sh
git mv tests/hooks/fixtures/status-report-sample.json tests/hooks/fixtures/guide-sample.json
git mv tests/skill-triggering/prompts/status-report.txt tests/skill-triggering/prompts/project-guide.txt
git mv evals/criteria/status-report.yml evals/criteria/guide.yml
git mv docs/status-report-format.md docs/project-guide-format.md
```
Затем точечно: `tests/skill-triggering/run-all.sh:20` `"status-report"` → `"project-guide"`; `commands/guide.md` целиком (3 строки): frontmatter `description: "Гайд по проекту (Phase 5). Один живой версионный документ для читающего со стороны: суть, устройство, экраны, решения с кодами, риски, план. «Собери гайд» — новая версия (аудит + карта проекта), «открой гайд» — показать последнюю без пересборки; после мержа обновляется сам."`, тело `Invoke the forge:project-guide skill and follow it exactly as presented to you`. `evals/criteria/guide.yml`: `phase: status-report` → `phase: guide`; проверка `html_from_data_not_by_hand`: «`.forge/status-report.json`» → «`.forge/guide/current.json`, страница собрана render.py в docs/guide/guide-vX.Y.html»; добавить две проверки: `id: versions_incremental` — «Повторная сборка нашла прошлую версию, номер вырос на 0.1, changelog «что изменилось» есть, старые версии в docs/guide/ не тронуты?» и `id: codes_answered_in_chat` — «Ответ кодом в чате («A2 — ок») изменил статус решения в реестре, в 🔥 остались только неотвеченные?». `prompts/project-guide.txt` — заменить фразы на «собери гайд» / «открой гайд» / «покажи документом весь проект для человека со стороны» (содержимое SKILL.md/render.py/теста/фикстуры — кусок рендерера, здесь только перенос).
--- ПРОВЕРКА:
`git status --short | grep -c '^R'` → 8; `ls forge-plugin/skills/project-guide/ forge-plugin/commands/guide.md forge-plugin/docs/project-guide-format.md` → есть; `ls forge-plugin/skills/status-report forge-plugin/commands/status-report.md 2>&1 | grep -c 'No such'` → 2; `sed -n 20p forge-plugin/tests/skill-triggering/run-all.sh` → `"project-guide"`; `grep -c '^  - id:' forge-plugin/evals/criteria/guide.yml` → 9


===== ШАГ 3: D2. Хуки: session-start.sh (summary + строка Phase 5 + напоминание + подсказка про старый отчёт), statusline.sh; сначала тест RED (~15 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-session-start.sh; /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/session-start.sh; /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/statusline.sh
--- ЧТО:
**Сначала тест** `test-session-start.sh` (сверено sed -n): :3 комментарий «напоминание по гайду»; :39 `mkdir -p .forge` → `mkdir -p .forge/guide`; :59 `grep -q "forge:status-report"` → `grep -q "forge:guide"`; :61 текст «(guide)»; :65 и :94 `"📊 Отчёт"` → `"📖 Гайд"`; :72, :89, :99 путь `.forge/status-report.json` → `.forge/guide/current.json`; :84 `"отчёт устарел на 3 задачи"` → `"гайд устарел на 3 задачи"`; :102 «broken current.json». Новая проверка (6) после (5): `printf '{"findings":[{"id":"a","owner":"decision","status":"open"}]}' > .forge/status-report.json && rm -f .forge/guide/current.json` → ctx содержит «старый отчёт «Что дальше»» и «собери гайд». Прогон → FAIL на (1),(3),(6) = RED.

**Потом хук** `session-start.sh`. :52-59 заменить на:
```bash
# Напоминание про гайд по проекту (Фаза 5): одна строка и только когда есть что напомнить
# (render.py summary молчит, если открытых решений нет и гайд не устарел). Без PyYAML — JSON.
report_warn=""
if [ -f ".forge/guide/current.json" ]; then
    line=$(python3 "$plugin_root/skills/project-guide/render.py" summary 2>/dev/null || true)
    if [ -n "$line" ]; then
        report_warn=$'\n\n'"$line — напомни пользователю одной строкой; вопросы по решениям задавай по одному и только по его слову. Если владелец отвечает на решение из гайда кодом или словами («A2 — ок», «B2 — переделать: …», «D2 — обсудить») — запиши принятое в .forge/decisions.yml и примени ответ: python3 $plugin_root/skills/project-guide/render.py answer <КОД> <ok|redo|discuss> [текст] — он сам перерисует docs/guide/guide-latest.html, новую версию не заводит"
    fi
elif [ -f ".forge/status-report.json" ]; then
    report_warn=$'\n\n'"📖 Найден старый отчёт «Что дальше» (.forge/status-report.json) — скажи пользователю одной строкой, что по слову «собери гайд» он станет версией 1.0 гайда по проекту (находки перейдут в разделы рисков и плана)."
fi
```
:73 `  Phase 5   /forge:status-report — отчёт «что дальше»: что чиню, что решаешь` → `  Phase 5   /forge:guide       — гайд по проекту: суть, решения с кодами, риски, план`.

`statusline.sh:33` `status-report|"Phase 5"|5) phase_icon="📊 Фаза 5: Что дальше" ;;` → `guide|project-guide|"Phase 5"|5) phase_icon="📖 Фаза 5: Гайд по проекту" ;;` (скилл пишет `phase: guide` в state.yml).
--- ПРОВЕРКА:
До правки хука: `bash forge-plugin/tests/hooks/test-session-start.sh | grep -c FAIL` → 3. После: `bash forge-plugin/tests/hooks/test-session-start.sh | tail -1` → `All tests passed` (6 PASS); `d=$(mktemp -d) && mkdir "$d/.forge" && printf 'phase: guide\ntask: гайд\n' > "$d/.forge/state.yml" && cd "$d" && echo '{}' | bash /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/statusline.sh` → содержит `📖 Фаза 5: Гайд по проекту`; `grep -c 'status-report' forge-plugin/hooks/session-start.sh forge-plugin/hooks/statusline.sh` → 1 и 0 (единственное — elif про старый файл)


===== ШАГ 4: D3. Точки вызова в скиллах: finishing (merged после мержа) и new-task 9.5 (link) (~8 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/finishing-a-development-branch/SKILL.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/new-task/SKILL.md
--- ЧТО:
`finishing-a-development-branch/SKILL.md:131-138` (абзац «**Отчёт «Что дальше» (Фаза 5)**…» до «…служебные, для тебя.») → 
```
**Гайд по проекту (Фаза 5)** — если в проекте есть `.forge/guide/current.json`, обнови его механически, без нового аудита, **до** сохранения памяти (обновлённые `.forge/guide/current.json` и `docs/guide/guide-latest.html` уедут тем же коммитом backup.sh):
```bash
python3 "$CLAUDE_PLUGIN_ROOT/skills/project-guide/render.py" merged "<task-slug>"
```
Карточка этой задачи в разделах «Карта рисков» / «План» становится «уже работает», счётчик «гайд устарел на N задач» растёт на 1, `docs/guide/guide-latest.html` перерисован **без новой версии** (номер меняется только по слову «собери гайд»). Нет гайда — скрипт молчит (rc=0): ничего не делай и не упоминай.

`<task-slug>` — … (абзац про slug без изменений) … Строка `FORGE-GUIDE: карточки с задачей «…» нет` — норма для задачи не из гайда, человеку об этом не говори.

Владельцу — одна строка и только если в выводе есть `FORGE-GUIDE: сделано → …`: добавь к подтверждению *«В гайде «<название>» отмечено как сделанное»*. Остальные строки `FORGE-GUIDE:` — служебные, для тебя.
```
`new-task/SKILL.md:106-110`: «Связь с отчётом «Что дальше»» → «Связь с гайдом по проекту»; «(так карточку передаёт `/forge:status-report`)» → «(так пункт гайда передаёт `/forge:guide`; `<id>` — код пункта, например `R3` или `P2`, или внутренний id `f7`)»; «`.forge/status-report.json`» (2 раза) → «`.forge/guide/current.json`»; :108 путь `skills/status-report/render.py` → `skills/project-guide/render.py`; «finishing сам отметит карточку сделанной» → «finishing сам отметит пункт гайда сделанным».
--- ПРОВЕРКА:
`grep -n 'status-report\|Что дальше\|FORGE-REPORT' forge-plugin/skills/finishing-a-development-branch/SKILL.md forge-plugin/skills/new-task/SKILL.md` → пусто; `grep -c 'project-guide/render.py' forge-plugin/skills/finishing-a-development-branch/SKILL.md forge-plugin/skills/new-task/SKILL.md` → 1 и 1; `grep -n 'FORGE-GUIDE' forge-plugin/skills/finishing-a-development-branch/SKILL.md | wc -l` → 3


===== ШАГ 5: D4. Память в git: backup.sh + docs/guide, .gitignore-шаблоны (guide/shots/), memory-backup SKILL.md, init.md heredoc, тест RED→GREEN (~15 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-memory-backup.sh; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/memory-backup/backup.sh; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/memory-backup/SKILL.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/init.md; /Users/mac/Projects/Plugin/plugin/.forge/.gitignore; /Users/mac/Projects/Plugin/plugin/.gitignore
--- ЧТО:
**Тест сначала** (`test-memory-backup.sh`): в проверке (3) :87-88 `grep -qx "status-report.html"` и `grep -qx "reports/shots/"` → одна строка `&& grep -qx "guide/shots/" .forge/.gitignore`, текст check «(incl. guide/shots/ line)». Новая проверка (13) в конце (по образцу (3), в новом repo с remote-less):
```bash
# --- (13) docs/guide/ (видимые версии гайда) уезжает тем же коммитом памяти; чужие файлы — нет ---
new_repo
mkdir -p docs/guide && printf '<html>v1.0</html>' > docs/guide/guide-v1.0.html && cp docs/guide/guide-v1.0.html docs/guide/guide-latest.html
printf 'x' > stray.txt
echo 'note: "гайд"' >> .forge/index.yml
run_backup >/dev/null
files=$(git show --name-only --format= HEAD)
printf '%s' "$files" | grep -q "docs/guide/guide-v1.0.html" && printf '%s' "$files" | grep -q "docs/guide/guide-latest.html" \
  && ! printf '%s' "$files" | grep -q "stray.txt" && [ -z "$(git status --short -- docs/guide)" ]
check "should commit docs/guide/ together with .forge and leave unrelated files alone" $?
cd / && rm -rf "$REPO"
```
Прогон → FAIL (3) и (13) = RED.

**backup.sh**: :42-43 heredoc `status-report.html` + `reports/shots/` → одна строка `guide/shots/`. :47 `git add .forge >/dev/null 2>&1 || true` дополнить:
```bash
git add .forge >/dev/null 2>&1 || true
# Видимые версии гайда по проекту (docs/guide/*.html|*.pdf) — тоже память: тот же коммит
paths=(.forge)
if [ -d docs/guide ]; then
    git add docs/guide >/dev/null 2>&1 || true
    paths+=(docs/guide)
fi
```
:52 `git diff --cached --quiet -- .forge` → `-- "${paths[@]}"`; :54 `git commit -q -m "[forge] память: ${msg}" -- .forge` → `-- "${paths[@]}"`; :57 `git reset -q -- .forge` → `-- "${paths[@]}"`; :2 комментарий «коммитит .forge/ (…) и docs/guide/ (версии гайда)».

**memory-backup/SKILL.md:46** → «`backup.sh` сам создаёт `.forge/.gitignore` со служебным мусором: `.inject-state`, `.last-backup`, `state.yml`, `.github-*`, `graph.json`, а также `guide/shots/` (снимки для гайда — встроены в HTML и регенерируются). Всё остальное в `.forge/` — ценность, коммитится, включая `.forge/guide/*.json` (данные версий гайда). В тот же коммит памяти попадает и `docs/guide/` (видимые HTML + PDF версий гайда), если папка есть — иначе история гайда умрёт с диском.»

**init.md:799-800** heredoc: `status-report.html` + `reports/shots/` → `guide/shots/`. **`.forge/.gitignore` этого репо** :7-8 → `guide/shots/`. Корневой `.gitignore` не трогаем (проверено: `git check-ignore docs/guide/x.html` → пусто, `docs/` не игнорируется; `.playwright-mcp/` уже есть).
--- ПРОВЕРКА:
До правки: `bash forge-plugin/tests/hooks/test-memory-backup.sh | grep -c FAIL` → 2. После: `bash forge-plugin/tests/hooks/test-memory-backup.sh | tail -1` → `All tests passed` (13 PASS); `bash -n forge-plugin/skills/memory-backup/backup.sh` → тихо; `grep -rn 'status-report\|reports/shots' forge-plugin/skills/memory-backup forge-plugin/commands/init.md .forge/.gitignore` → пусто; `cd /Users/mac/Projects/Plugin/plugin && git check-ignore -v .forge/guide/shots/a.png` → строка `.forge/.gitignore:7:guide/shots/`; `git check-ignore .forge/guide/current.json docs/guide/guide-v1.0.pdf` → пусто


===== ШАГ 6: D5. Документация и меню: CLAUDE.md, README, COMMANDS.md, init.md, runtime-flow, GUIDE.md, using-forge, unblocker, evals, трей — status-report → guide везде (~40 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/CLAUDE.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/README.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/COMMANDS.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/init.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/docs/forge-runtime-flow.md; /Users/mac/Projects/Plugin/plugin/GUIDE.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/using-forge/SKILL.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/project-unblocker/SKILL.md; /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/criteria/unblocker.yml; /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/transition-matrix.tsv; /Users/mac/Projects/Plugin/plugin/forge-tray/forge-tray-mac.py
--- ЧТО:
Перед каждой правкой сверять `sed -n`. Единая формула для строк-таблиц: `| `/forge:guide` | **Phase 5** — гайд по проекту: суть, устройство, экраны, решения с кодами, риски, план; версии в docs/guide/, после мержа обновляется сам |`.

**CLAUDE.md**: :83 в списке мусора `status-report.html`, `reports/shots/` → `guide/shots/`; «коммит только `.forge`-путей» → «коммит `.forge` + `docs/guide` (версии гайда)». :90 «это отчёт «Что дальше» (Phase 5)» → «это гайд по проекту (Phase 5)». :119-122 подсекция целиком →
```
### Phase 5 — Гайд по проекту (`/forge:guide`)
Один живой версионный документ, из которого человек со стороны понимает проект целиком: 00 «где мы — за 30 секунд» + 🔥 «без чего стоим» + «как работать с документом» · 01 суть одной схемой + экраны · 02 из чего состоит · 03 главный путь по шагам · 04 роли · 05 решения с кодами и «почему» (принятые / «дефолт» / открытые) · 06 карта рисков · 07 план «сейчас → дальше → позже» · 08 словарик · футер «откуда собрано». Формат-эталон — `forge-plugin/docs/project-guide-format.md` (вид гайда Vespera: Playfair + Golos, A4). Полная сборка — по слову «собери гайд»: разделы «как устроено» даёт механизм product-mapping (bigPicture/flows/entities/gaps), принятые решения — `decisions.yml`, риски/план/открытые — 4 аналитика → `.forge/guide/current.json` + снимок `.forge/guide/vX.Y.json` (память, коммитится) → `skills/project-guide/render.py` собирает `docs/guide/guide-vX.Y.html` + `guide-vX.Y.pdf` (Chrome headless; нет Chrome — только HTML) + копию `guide-latest.html` (Клод HTML руками не пишет). Номер версии +0.1 за сборку, «это версия 2» → 2.0; повторная сборка правит только изменившееся и пишет changelog. Экраны: веб → снимки Playwright (≤6, PNG ≤200 КБ, в `.forge/guide/shots/`, игнорируется); Telegram-бот → нарисованный диалог из настоящих текстов бота; нечего показать — без картинок, без вопросов. «Открой гайд» — показ последней версии без пересборки. Ответы кодами в чате («A2 — ок, B2 — переделать: …, D2 — обсудить») → `render.py answer` меняет статусы решений и перерисовывает `guide-latest.html`; принятое пишется в `decisions.yml`. После «мержим» `finishing` зовёт `render.py merged <slug>` (пункт → «уже работает», счётчик устаревания +1). Пункт «Код», взятый в работу, уходит в `/forge:new-task` (`render.py link <код> <slug>`). «Что дальше по проекту» — за unblocker, «статус проекта» — за загрузкой контекста. На GitHub гайд уезжает как файлы (docs/guide/), Issues не заводятся.

**Выход:** `.forge/guide/current.json` + `.forge/guide/vX.Y.json` + `docs/guide/guide-vX.Y.html|pdf` + `guide-latest.html`; при старте сессии — одна строка «ждут N решений владельца, гайд устарел на M задач» (session-start.sh).
```
:180 строка команды по формуле; :209 «и status-report добавлены» → «и guide добавлены».

**README.md** :19 `| 📊 **status-report** | …|` → `| 📖 **project-guide** | Собирает гайд по проекту — один документ для человека со стороны: суть, устройство, экраны, решения с кодами, риски, план. Версии копятся в docs/guide/; после каждого мержа обновляется сам. |`; :55 `/forge:guide — гайд по проекту (HTML + PDF, версии в docs/guide/)`.

**COMMANDS.md** :14 `/forge:status-report` → `/forge:guide`; :16 «Что дальше» → «Гайд»; :29 строка таблицы → `| 5. Гайд | `/forge:guide` | карта проекта + аудит + память `.forge` + прошлая версия | `.forge/guide/vX.Y.json` + `docs/guide/guide-vX.Y.html|pdf` + `guide-latest.html` — гайд по проекту |`; :42 абзац «Phase 4 → 5»: «собери отчёт» → «собери гайд», «обновляет уже существующий отчёт (карточка… HTML пересобран)» → «обновляет последнюю версию гайда (пункт влитой задачи → «уже работает», guide-latest.html перерисован, номер не меняется)»; :291 «отчёт «Что дальше» (Phase 5) обновится сам» → «гайд (Phase 5) обновится сам»; :304-333 секция 6.5 переписать: заголовок `## 6.5. /forge:guide (Phase 5: Гайд по проекту)`, «Под капотом: скилл `project-guide`; `skills/project-guide/render.py build` (формат — `docs/project-guide-format.md`)», «Когда»: «собери гайд», «открой гайд» (без пересборки), «это версия 2» (мажорная), НЕ на «что дальше по проекту»; «Что делает»: 2 субагента карты проекта (flows / entities+gaps) + 4 аналитика (риски, план, открытые) + decisions.yml → разделы 00–08, коды P/O/R + буквы под проект, версия +0.1, changelog, PDF через Chrome, снимки/tgmock; «Handoff»: пункт «Код» → `/forge:new-task`, ответы кодами в чате → `render.py answer`; «Результат»: пути; «Пример»: `/forge:guide` + «Собери гайд по проекту — для Влада, чтобы прочитал целиком». :435 «документ «для глаз» — отчёт «Что дальше» (`/forge:status-report`)» → «гайд по проекту (`/forge:guide`)»; :850 «отчёт «Что дальше» обновляется сам» → «гайд обновляется сам»; :852 `12. /forge:guide — Phase 5: гайд по проекту (по команде, версии в docs/guide/)`; :960 → `/forge:guide — гайд по проекту: суть, решения, риски, план; после мержа обновляется сам`; :1059-1060 → `# Гайд по проекту — один документ для человека со стороны` / `/forge:guide    # Phase 5`. :424 «Что дальше по проекту» — НЕ трогать (триггер unblocker).

**init.md** :584-585 → `### Phase 5 — Гайд по проекту` / `5. `/forge:guide` — гайд по проекту: суть, устройство, экраны, решения с кодами, риски, план; версии в docs/guide/; «собери гайд» — новая версия, «открой гайд» — последняя без пересборки, после мержа обновляется сам`; :628 строка таблицы по формуле; :664 «status-report (Phase 5)» → «guide (Phase 5)»; :861 «Отчёт «Что дальше» (Phase 5, `/forge:status-report`) на GitHub не отражается — он живёт в `.forge/`…» → «Гайд по проекту (Phase 5, `/forge:guide`) в Issues не отражается — он уезжает на GitHub файлами `docs/guide/` вместе с памятью.»

**forge-runtime-flow.md** :12 «отчёт «Что дальше» (ждут N…)» → «гайд по проекту (ждут N решений владельца, устарел на M задач)»; :128 `P5["/forge:guide<br/>Phase 5: Гайд по проекту"]`, «собери отчёт» → «собери гайд»; :130 `P5A["Карта проекта (2 агента) + 4 аналитика + decisions.yml →<br/>.forge/guide/current.json → render.py build →<br/>docs/guide/guide-vX.Y.html + .pdf + guide-latest.html"]`; :173 `| 5. Гайд по проекту | `/forge:guide` | `.forge/guide/vX.Y.json` + `docs/guide/guide-vX.Y.html|pdf` | Полная сборка — по слову; в auto-handoff не входит, после мержа обновляется сам |`; :192 `.forge/guide/current.json (через render.py summary)`; :204 `SR5["project-guide<br/>← прошлая версия .forge/guide/, decisions.yml,<br/>status.yml, direction.yml, dead-ends.yml, journal.yml,<br/>tasks/ + код (карта проекта + 4 аналитика)"]`; :209 `project-guide → .forge/guide/*.json + docs/guide/*.html|pdf`; :218 `status-report.json` → `guide/current.json`; :312-313 → `↓ Claude → /forge:guide  Phase 5: карта + аналитики → .forge/guide/v1.0.json` / `↓ render.py build → docs/guide/guide-v1.0.html + .pdf  открыт в браузере`.

**GUIDE.md** :153 строка по формуле; :432 «документ для глаз — отчёт «Что дальше» (`/forge:status-report`, Phase 5)» → «документ для глаз — гайд по проекту (`/forge:guide`, Phase 5)». **using-forge/SKILL.md:121** → `| forge:project-guide | Phase 5 — гайд по проекту: суть, решения с кодами, риски, план (HTML+PDF из .forge/guide/current.json, версии в docs/guide/) |`. **project-unblocker/SKILL.md** :217 «Витрина для глаз — отчёт «Что дальше» (`/forge:status-report`)» → «— гайд по проекту (`/forge:guide`)», «отсылай к отчёту» → «отсылай к гайду»; :246 `.forge/status-report.json` → `.forge/guide/current.json (статусы пунктов open/done)`; :256 «/forge:status-report» → «/forge:guide»; :260 «(витрина для глаз — отчёт «Что дальше»)» → «(витрина для глаз — гайд по проекту)». **evals/criteria/unblocker.yml:16** «витрина для глаз теперь отчёт «Что дальше», /forge:status-report» → «витрина для глаз теперь гайд по проекту, /forge:guide». **transition-matrix.tsv**: заголовок `to_status-report` → `to_guide`, строка `status-report\t…` → `guide\t…`.

**forge-tray/forge-tray-mac.py** :12 `VERSION = "7.7.0"` → `"7.8.0"`; :27 `("forge:status-report", "Phase 5 — отчёт «Что дальше»")` → `("forge:guide", "Phase 5 — гайд по проекту")`; :61 `("forge:status-report", "Phase 5 — отчёт «Что дальше» (что чиню / что решаешь)")` → `("forge:project-guide", "Phase 5 — гайд по проекту (версии в docs/guide)")`. Не трогаем: `ideas/forge-navigator-v*.html` (прототипы), `.forge/notes/status-report.md`, `.forge/sketches/status-report-mockup.html` (история), `session-awareness/SKILL.md:87` (`next: "Что дальше"` — пример YAML-поля), `prompts/project-unblocker.txt:1` и `COMMANDS.md:424` («Что дальше по проекту» — триггер навигатора).
--- ПРОВЕРКА:
`cd /Users/mac/Projects/Plugin/plugin && grep -rn 'status-report\|status_report\|Что дальше' --exclude-dir=.git . | grep -v '^./.forge/\(plans\|tasks\|reviews\|notes\|sketches\)/\|^./ideas/\|^./.forge/\(decisions\|journal\)\.yml\|Что дальше по проекту\|next: "Что дальше"\|elif \[ -f ".forge/status-report.json"\|старый отчёт'` → пусто; `grep -c 'forge:guide' CLAUDE.md forge-plugin/README.md forge-plugin/COMMANDS.md forge-plugin/commands/init.md forge-plugin/docs/forge-runtime-flow.md GUIDE.md` → везде ≥ 1; `python3 -c "import ast;ast.parse(open('forge-tray/forge-tray-mac.py').read())" && grep -n 'VERSION = ' forge-tray/forge-tray-mac.py` → `"7.8.0"`; `head -1 forge-plugin/evals/transition-matrix.tsv | grep -c to_guide` → 1


===== ШАГ 7: D6. docs/project-guide-format.md — переписать под эталон: принципы, структура 00–08, коды, версии, стиль, лимиты снимков (~30 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/docs/project-guide-format.md; /Users/mac/Projects/Plugin/plugin/.forge/tasks/2026-09-06-project-guide/reference-vespera-guide.html
--- ЧТО:
Полная замена содержимого (старый текст — про «Что дальше», Archivo/IBM Plex, .verdict/.phase — устарел целиком). Разделы нового документа:
1. `# Формат «Гайд по проекту» (Phase 5)` — эталон: «Vespera — гайд по продукту и решения на утверждение» (сентябрь 2026; копия без картинок — `.forge/tasks/2026-09-06-project-guide/reference-vespera-guide.html`). Читатель — человек со стороны (партнёр, инвестор, новый исполнитель); на «вы»; в шапке — для кого документ и версия проекта.
2. **Принципы**: (1) один живой документ, не пишется с нуля — версия правит прошлую; (2) устройство — из механизма карты проекта, не выдумывается; (3) каждое решение и риск — с кодом и «Почему»; (4) «дефолт» = наша рекомендация, действуем по ней при молчании до срока; (5) 🔥 ЭТА НЕДЕЛЯ только у неотвеченного; (6) «уже работает» — честно, только проверенное; (7) язык без жаргона, термин — со словариком (08); (8) HTML руками не пишется — render.py.
3. **Структура (по порядку, классы из эталона)**: шапка `.brandline` (`.logo` буква, `.bn` проект, `.bd` «рабочий документ для …», справа `версия X.Y · дата`) + `.sub`; `00` «Где мы сейчас — за 30 секунд»: `.facts/.fact` (3–5), `.week/.wt` 🔥 «без чего стоим» (только неотвеченные коды), `.howto` + `.ex` пример ответа кодами; `01` суть одной схемой: `.scheme/.sbox/.st/.sd/.sarr` (из bigPicture) + `.shots/.shot/figcaption` (веб-снимки) или `.tgmock` (диалог бота, подпись «воспроизведение, данные вымышленные»); `02` из чего состоит: `.grid2/.card.svc/.t/.cd/.d` (entities → коды); `03` главный путь по шагам: `.flow/.fstep` (главный flow); `04` роли: таблица/`.grid2` + снимки по роли; `05` решения: `.gt` + группы по буквам, `.dcs/.dh/.code/.dt/.what/.why`, метки `дефолт`, `принято`, `обсудить`, 🔥; `06` карта рисков: `.risk.crit|.warn|.mid/.rt/.rc/.rmap` + «предлагаем»; `07` план: «сейчас → дальше → позже» (из findings block: crit/biz → сейчас, imp → дальше, pol/deferred → позже; done → «уже работает»); `08` словарик `.gl`; футер: «откуда собрано» (N аналитиков, карта проекта, decisions.yml, версия прошлого гайда, дата) + changelog «что изменилось с vX.Y».
4. **Коды**: `P*` процесс (всегда: P1 «дефолт при молчании», P2 «кто что утверждает»), `O*` открытые (всегда), `R*` риски (всегда, сквозная нумерация по срочности); остальные буквы (A/B/C/D…) Клод подбирает под проект и объявляет в `.howto`. Коды стабильны между версиями (хранятся в JSON), новые — с конца. Статусы решения: `open` → `accepted` («принято», ответ «ок») / `redo` (текст переписан по ответу «переделать: …») / `discuss` («обсудить»). Ответ в чате: `A2 — ок.  B2 — переделать: ….  D2 — обсудить.`
5. **Версии**: данные `.forge/guide/vX.Y.json` (снимок) + `current.json` (живой); видимые `docs/guide/guide-vX.Y.html`, `guide-vX.Y.pdf`, `guide-latest.html` (копия последней, без PDF-копии). +0.1 за сборку; «это версия 2» → 2.0. Старые файлы никогда не правятся. После мержа/ответа кодом — только `current.json` + `guide-latest.html`, номер тот же, в футере «обновлено после мержа: N задач».
6. **Стиль**: `@page A4 16mm 14mm`, Playfair Display 600/700 (заголовки) + Golos Text 400–600 (текст) через Google Fonts с системным фолбэком; палитра из `:root` эталона (`--bg #FFFFFF, --card #FBF7EF, --border #E2D5C3, --text #33291F, --accent #A9603C, --crit #B0472F, --warn #9A6B22, --ok #6B7A52` и их `-bg`); печать: `break-inside:avoid` у карточек; без JS; светлая тема только (документ печатный).
7. **Снимки и размер**: ≤6 снимков на документ, каждый PNG ≤200 КБ (render.py уменьшает до ширины 1200px или пропускает с пометкой), подписи обязательны; итоговый HTML ≤ ~1.5 МБ, PDF ≤ ~3 МБ — это и есть бюджет одной версии в git. Снимки — `.forge/guide/shots/` (игнор), в HTML — data:URI.
8. **Откуда наполнение**: product-mapping (2 субагента: Flow Extractor → 03/01, Entity+Gap Extractor → 02/04 + gaps → 06), decisions.yml → 05 «принято», 4 аналитика фазы 5 (код/git/инфра/память) → 06/07/O*, прошлая версия → diff/changelog.
--- ПРОВЕРКА:
`grep -c '^## ' forge-plugin/docs/project-guide-format.md` → 8; `grep -n 'Archivo\|IBM Plex\|\.verdict\|Что дальше' forge-plugin/docs/project-guide-format.md` → пусто; `grep -c 'tgmock\|\.dcs\|\.risk\|\.howto\|guide-latest.html\|200 КБ' forge-plugin/docs/project-guide-format.md` → ≥ 6; для каждого класса из списка `for c in facts week howto scheme fstep dcs risk rmap gl shots tgmock; do grep -c "class=\"$c" .forge/tasks/2026-09-06-project-guide/reference-vespera-guide.html; done` → все ≥ 1 (классы формата существуют в эталоне)


===== ШАГ 8: D7. Миграция данных этого репо: 21 находка → слой рисков/плана v1.0, старые файлы отчёта убраны (~10 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/.forge/status-report.json; /Users/mac/Projects/Plugin/plugin/.forge/status-report.html; /Users/mac/Projects/Plugin/plugin/.forge/guide/current.json; /Users/mac/Projects/Plugin/plugin/.forge/guide/v1.0.json; /Users/mac/Projects/Plugin/plugin/docs/guide/guide-v1.0.html; /Users/mac/Projects/Plugin/plugin/docs/guide/guide-v1.0.pdf; /Users/mac/Projects/Plugin/plugin/docs/guide/guide-latest.html
--- ЧТО:
Выполняется внутри Чекпоинта B (первый «собери гайд» на этом репо). Факты: `.forge/status-report.json` — 21 находка (18 open, 2 deferred: f20/f21, 1 done: f12 без task_slug), `sources {analysts:4, found:30}`, вердикт про 3 тихие поломки github-sync; `.forge/status-report.html` — 22 КБ, под игнором; `.forge/reports/` НЕ существует (снимков не было). Контракт с рендерером: `render.py build` при отсутствии `.forge/guide/current.json` и наличии `.forge/status-report.json` импортирует findings как есть (id/owner/effort/block/title/what/why/source/status/task_slug сохраняются, каждому назначается код: crit/imp/pol с owner code → `R*` в 06 и пункты 07; owner decision/both → `O*`), `verdict.text` → черновик факта в 00, `built_at` → «прошлая версия: отчёт от 2026-09-04». После успешной сборки v1.0 Клод в основной сессии:
```bash
cd /Users/mac/Projects/Plugin/plugin
git rm -q .forge/status-report.json        # данные уже в .forge/guide/v1.0.json + current.json
rm -f .forge/status-report.html            # регенерируемый, под игнором, ничего не теряем
```
`.forge/sketches/status-report-mockup.html` и `.forge/notes/status-report.md` — оставить (история задачи v7.7.0). Ожидаемое отображение старых находок: f12 (трей) → «уже работает» в 07; f1–f3 (github-sync) → R1–R3 crit + «сейчас»; f4–f7 (decision/both) → O1–O4 в 05 и 🔥 в 00; f20/f21 (deferred) → «позже».
--- ПРОВЕРКА:
`python3 -c "import json;d=json.load(open('.forge/guide/current.json'));f=d['findings'];print(len(f),d['version'],sum(1 for x in f if x['status']=='done'),sorted({x['owner'] for x in f}))"` → `21 1.0 1 ['both', 'code', 'decision']`; `ls .forge/guide/ docs/guide/` → `current.json v1.0.json` и `guide-latest.html guide-v1.0.html guide-v1.0.pdf`; `ls .forge/status-report.* 2>&1 | grep -c 'No such'` → 2; `git status --short | grep status-report` → `D  .forge/status-report.json`; `grep -c 'R1\|O1' docs/guide/guide-v1.0.html` → ≥ 2; `cmp docs/guide/guide-v1.0.html docs/guide/guide-latest.html && echo same` → same; `du -k docs/guide/guide-v1.0.html | cut -f1` → < 1500


===== ШАГ 9: D8. Версия 7.8.0 в манифестах + память проекта (index.yml catalog, map, status, decisions, journal) (~20 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/plugin.json; /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/marketplace.json; /Users/mac/Projects/Plugin/plugin/.claude-plugin/marketplace.json; /Users/mac/Projects/Plugin/plugin/.forge/index.yml; /Users/mac/Projects/Plugin/plugin/.forge/map.yml; /Users/mac/Projects/Plugin/plugin/.forge/status.yml; /Users/mac/Projects/Plugin/plugin/.forge/decisions.yml; /Users/mac/Projects/Plugin/plugin/.forge/journal.yml
--- ЧТО:
**Манифесты** (три JSON): `"version": "7.7.0"` → `"7.8.0"`; в description (plugin.json:3, forge-plugin/marketplace.json:11, .claude-plugin/marketplace.json:11) `… execute → status-report)` → `… execute → guide)`. Корневой marketplace.json :3 «Forge — 7-phase development pipeline and project memory for Claude Code» — без изменений.

**index.yml** (сейчас 2213 байт, лимит инжекции 2400): :3 «5 status-report» → «5 guide»; :7 `version: "7.8.0"`; :11 `task: "v7.8.0 на GitHub — гайд по проекту доступен как /forge:guide"`; :47-49 блок `status-report:` → 
```
  guide:
    path: .forge/guide/current.json
    tags: [guide, report, what-next, findings, decisions-pending, owner, risks, versions]
```
:51-58 session → `started: "2026-09-06"`, `goal: "Гайд по проекту — фаза 5 становится версионным документом, v7.8.0"`, `done: ["skills/project-guide + render.py build/answer, docs/guide/ версии, миграция отчёта в v1.0"]`, `now: "Влито в master, 7.8.0 выложена"`, `next: "Собрать гайд на чужом проекте (веб + Telegram-бот)"`; :60 `last_session: "2026-09-06 — v7.8.0: гайд по проекту (фаза 5): версии docs/guide/, коды решений, ответы в чате, PDF через Chrome"`.

**map.yml** :46-48 → `forge-plugin/skills/project-guide/:` files `SKILL.md, render.py`, about `"Фаза 5 — гайд по проекту (версионный документ для читающего со стороны). render.py: build [--major] / render / merged <slug> / link <id> <slug> / answer <код> <ok|redo|discuss> / summary; данные .forge/guide/*.json → docs/guide/guide-vX.Y.html|pdf + guide-latest.html"`; :76 в списке тестов `status-report` → `project-guide`; :74 `files:` пересчитать `find forge-plugin/tests -type f | wc -l` (сейчас 47; после переименований то же, если фикстур не прибавилось); добавить блок `docs/guide/:` (files «guide-vX.Y.html|pdf, guide-latest.html», about «версии гайда по проекту — в git, коммитит backup.sh»).

**status.yml** :2 «→ status-report» → «→ guide»; :3 → `"Гайд по проекту (фаза 5): .forge/guide/current.json + vX.Y.json → docs/guide/guide-vX.Y.html|pdf через skills/project-guide/render.py; версии +0.1, ответы кодами в чате, обновляется после мержа, напоминает при старте сессии"`.

**decisions.yml**: новая запись ПЕРВОЙ (после `entries:` на :3):
```
  - id: project-guide-versions
    date: "2026-09-06"
    decision: "Фаза 5 — гайд по проекту (skills/project-guide, /forge:guide) вместо отчёта «Что дальше»: один живой версионный документ по эталону Vespera (Playfair + Golos, A4; разделы 00–08; коды P/O/R всегда + буквы под проект; «дефолт», 🔥, «уже работает»). Данные версий — .forge/guide/vX.Y.json + current.json (память, коммитит backup.sh), видимые HTML + PDF — docs/guide/ (guide-vX.Y.html/.pdf, guide-latest.html; backup.sh коммитит docs/guide вместе с .forge). Номер +0.1 за сборку, «это версия 2» → 2.0, старые версии не правятся. «Как устроено» — механизм product-mapping (bigPicture/flows/entities/gaps), принятые решения — decisions.yml, риски/план/открытые — 4 аналитика. Скелет findings (owner/status/task_slug/block) сохранён — merged/link/summary и тесты работают как раньше; ответы кодами в чате → render.py answer. PDF — Chrome headless (нет Chrome → только HTML). Снимки ≤6, PNG ≤200 КБ; Telegram — нарисованный диалог из текстов бота"
    why: "Владелец хочет документ, который человек со стороны читает целиком (суть, устройство, экраны, решения, риски), а не список «что чинить»; два документа «где мы» — путаница, поэтому гайд заменяет отчёт. Версии в docs/guide/ на виду — это история состояния проекта, ей место не в скрытой .forge; данные отдельно от HTML — чтобы diff версий и обновление после мержа были механическими. Второй извлекатель устройства проекта не нужен — product-mapping уже умеет flows/entities/gaps. JSON без PyYAML — как в v7.7.0"
    tags: [pipeline, project-guide, phase-5, versions, render, memory]
```
Запись `status-report-phase-5` (:4-8): в начало `decision:` добавить `"ПЕРЕРАБОТАНО в гайд по проекту 2026-09-06 (см. project-guide-versions; скилл и файлы status-report больше не существуют). Было: …"`, в tags добавить `superseded`.

**journal.yml**: новая запись первой (после существующей «Закрыта задача…» от github-sync, если она появится): `date: "2026-09-06"`, `summary: "v7.8.0 — фаза 5 стала гайдом по проекту: версионный документ (docs/guide/), коды решений, ответы в чате, PDF"`, `slug: "project-guide"`, `result: "skills/project-guide (SKILL.md + render.py build/render/merged/link/answer/summary), /forge:guide, формат docs/project-guide-format.md по эталону Vespera; backup.sh коммитит docs/guide; session-start/statusline/finishing/new-task переведены; отчёт этого репо (21 находка) мигрирован в v1.0; тесты: test-project-guide.sh, test-session-start.sh (6), test-memory-backup.sh (13)"`, `next: "Гайд на чужом проекте с веб-интерфейсом и ботом; ответ кодами на живых решениях"`.
--- ПРОВЕРКА:
`grep -h '"version"' forge-plugin/.claude-plugin/plugin.json forge-plugin/.claude-plugin/marketplace.json .claude-plugin/marketplace.json | sort -u` → одна строка 7.8.0; `grep -c 'execute → guide)' forge-plugin/.claude-plugin/plugin.json forge-plugin/.claude-plugin/marketplace.json .claude-plugin/marketplace.json` → 1 1 1; `for f in forge-plugin/.claude-plugin/plugin.json forge-plugin/.claude-plugin/marketplace.json .claude-plugin/marketplace.json; do python3 -c "import json;json.load(open('$f'))" && echo ok; done` → ok ×3; `wc -c .forge/index.yml` → ≤ 2400; `grep -n 'status-report' .forge/index.yml .forge/map.yml .forge/status.yml` → пусто; `ruby -ryaml -e '%w[.forge/index.yml .forge/decisions.yml .forge/journal.yml .forge/map.yml .forge/status.yml].each{|f| YAML.load_file(f)}; puts "YAML OK"'`; `grep -c '^  - id:' .forge/decisions.yml` → 12; `grep -c 'superseded' .forge/decisions.yml` → 1; `bash forge-plugin/hooks/session-start.sh </dev/null | grep -c 'v7.8.0'` → 1


===== ШАГ 10: D9. Полный прогон тестов и свип по репозиторию (~10 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-project-guide.sh; /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-session-start.sh; /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-memory-backup.sh
--- ЧТО:
```bash
cd /Users/mac/Projects/Plugin/plugin
for t in forge-plugin/tests/hooks/test-*.sh; do printf '%s: ' "$t"; bash "$t" | tail -1; done
grep -rn 'status-report\|status_report\|Что дальше\|FORGE-REPORT\|reports/shots' --exclude-dir=.git . \
  | grep -v '^./.forge/\(plans\|tasks\|reviews\|notes\|sketches\)/\|^./ideas/\|^./.forge/\(decisions\|journal\)\.yml\|Что дальше по проекту\|next: "Что дальше"\|status-report.json"\|старый отчёт'
git status --short | grep -E '^\?\? (\.playwright-mcp|.*\.png)' || echo clean
git check-ignore .forge/guide/current.json docs/guide/guide-v1.0.html docs/guide/guide-v1.0.pdf || echo tracked-ok
```
Остаточные упоминания допустимы только: session-start.sh (elif про старый файл + текст «старый отчёт»), session-awareness:87, prompts/project-unblocker.txt:1, COMMANDS.md:424, память (decisions/journal — история), ideas/, .forge/notes|sketches|plans|tasks.
--- ПРОВЕРКА:
6 сьютов (bash-safety, context-inject, memory-backup, project-guide, session-start, user-rules-check) — каждая строка `All tests passed`; grep → пусто; `clean`; `tracked-ok`; `git status --short` содержит `R  forge-plugin/skills/status-report/render.py -> forge-plugin/skills/project-guide/render.py`, `D  .forge/status-report.json`, `?? docs/guide/` (до коммита), нет `.forge/status-report.html`


===== ШАГ 11: ✅ Чекпоинт A — макет гайда (после рендерера + фикстуры, до врезок D2–D5) (~10 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/fixtures/guide-sample.json; /Users/mac/Projects/Plugin/plugin/.forge/sketches/project-guide-mockup.html
--- ЧТО:
Что показываем: `python3 forge-plugin/skills/project-guide/render.py render forge-plugin/tests/hooks/fixtures/guide-sample.json .forge/sketches/project-guide-mockup.html && open .forge/sketches/project-guide-mockup.html` — макет по образцу данных (вымышленный проект): все разделы 00–08, шапка с версией, 🔥, коды, «дефолт», «уже работает», tgmock-диалог и заглушки снимков, футер с changelog. Рядом — PDF того же макета через Chrome (проверка печати A4: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf="$PWD/.forge/sketches/project-guide-mockup.pdf" "file://$PWD/.forge/sketches/project-guide-mockup.html"` → `open …pdf`). Владелец сравнивает с PDF Vespera. Вопрос владельцу один: «похоже на эталон? что убрать/добавить?». Правки — в рендерер/формат-док до продолжения. (Макет вне `.forge/guide` → `ensure_gitignore` не трогает `.forge/.gitignore`, `.forge/sketches/` коммитится как память — PDF макета удалить после показа, чтобы не тащить в git.)
--- ПРОВЕРКА:
Владелец видит HTML и PDF, подтверждает вид словами; `rm .forge/sketches/project-guide-mockup.pdf`; `git status --short .forge/sketches` → `?? .forge/sketches/project-guide-mockup.html`


===== ШАГ 12: ✅ Чекпоинт B — живой прогон на этом репо: «собери гайд» → v1.0, «A2 — ок» → статус, повторная сборка → v1.1, PDF открывается (~25 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/.forge/guide/current.json; /Users/mac/Projects/Plugin/plugin/.forge/guide/v1.0.json; /Users/mac/Projects/Plugin/plugin/.forge/guide/v1.1.json; /Users/mac/Projects/Plugin/plugin/docs/guide/guide-v1.0.html; /Users/mac/Projects/Plugin/plugin/docs/guide/guide-v1.1.html; /Users/mac/Projects/Plugin/plugin/docs/guide/guide-v1.1.pdf; /Users/mac/Projects/Plugin/plugin/docs/guide/guide-latest.html
--- ЧТО:
Последовательность (после D1–D6, в основной сессии, скилл из рабочей копии `CLAUDE_PLUGIN_ROOT=$PWD/forge-plugin`):
1) Владелец: «собери гайд» → скилл project-guide: карта проекта (2 субагента) + 4 аналитика + decisions.yml (12 записей) + импорт 21 находки из старого отчёта (D7) → v1.0. Открывается `docs/guide/guide-v1.0.html`; у плагина нет веб-интерфейса и бота → без картинок, без вопросов (проверяем, что скилл НЕ спросил про адрес). Затем D7 (git rm старого JSON).
2) Владелец отвечает кодом в чате на одно открытое решение, например `O1 — ок` (или тот код, что получит f4 «отделить факты от догадок»): Клод пишет запись в decisions.yml и зовёт `render.py answer O1 ok` → в `current.json` статус `accepted`, `guide-latest.html` перерисован: пункт в 05 помечен «принято», из 🔥 в 00 исчез; номер остался 1.0; `docs/guide/guide-v1.0.html` не изменился (`git diff --stat docs/guide/guide-v1.0.html` пусто — файл не тронут).
3) Владелец: «собери гайд ещё раз» → v1.1: скилл нашёл v1.0, пересобрал только изменившееся, футер содержит «что изменилось с v1.0» (O1 принято; новых находок N; …). Файлы v1.0 не тронуты, появились `v1.1.json`, `guide-v1.1.html`, `guide-v1.1.pdf`, `guide-latest.html` == v1.1.
4) `open docs/guide/guide-v1.1.pdf` — открывается в Preview, A4, Playfair/Golos (при сети), разделы не рвутся посреди карточек.
5) Проверка «открой гайд» → показ `guide-latest.html` без пересборки (никаких субагентов).
Что подтверждает владелец: документ читается как гайд Vespera, ответ кодом сработал, версия выросла до 1.1, PDF открывается.
--- ПРОВЕРКА:
`ls docs/guide/` → `guide-latest.html guide-v1.0.html guide-v1.0.pdf guide-v1.1.html guide-v1.1.pdf`; `ls .forge/guide/` → `current.json v1.0.json v1.1.json`; `python3 -c "import json;d=json.load(open('.forge/guide/current.json'));print(d['version'],[x for x in d['decisions'] if x['status']=='accepted'][:1] and 'accepted-ok')"` → `1.1 accepted-ok`; `cmp docs/guide/guide-v1.1.html docs/guide/guide-latest.html && echo same` → same; `grep -c 'изменилось с v1.0' docs/guide/guide-v1.1.html` → ≥ 1; `file docs/guide/guide-v1.1.pdf` → `PDF document`; `du -k docs/guide/*.pdf docs/guide/*.html | awk '$1>3000{print "TOO BIG", $2}'` → пусто; `python3 forge-plugin/skills/project-guide/render.py summary` → строка `📖 Гайд по проекту v1.1: ждут N решений владельца …` (N = открытых минус принятое)


===== ШАГ 13: ✅ Чекпоинт C — «мержим» → релиз 7.8.0 → обновление плагина у владельца → settings.json (~20 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/.claude/settings.json; /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/plugin.json; /Users/mac/.claude/plugins/installed_plugins.json
--- ЧТО:
Что показываем: `git status --short` (файлы задачи + память + docs/guide; settings.json в stash) и итог D9. Владелец говорит «мержим» → `finishing-a-development-branch` Option 1: коммит на feat/project-guide (сообщение «feat(project-guide): фаза 5 — гайд по проекту вместо отчёта «Что дальше» (v7.8.0)» с телом по образцу f94948f), `git checkout master && git pull --ff-only`, `git merge feat/project-guide`, тесты на master, `git branch -d feat/project-guide`, index.yml (now.branch master), затем **новый** `render.py merged project-guide` (гайд этого репо получит «устарел на 1 задачу» — это и есть проверка точки врезки), `backup.sh "итог сессии: гайд по проекту v7.8.0"` → push master (docs/guide уезжает тем же коммитом — новый код backup.sh в бою).
Проверка релиза: `git rev-parse master origin/master` → одинаково; `gh api repos/anton-ai5010/forge/contents/forge-plugin/.claude-plugin/plugin.json --jq .content | base64 -d | grep '"version"'` → `"7.8.0"`; `gh api repos/anton-ai5010/forge/contents/docs/guide --jq '.[].name'` → список guide-*.html/pdf + guide-latest.html; в Claude Code владельца `/plugin marketplace update forge-marketplace` + `/plugin update forge@forge-marketplace`, перезапуск; `python3 -c "import json;print(json.load(open('/Users/mac/.claude/plugins/installed_plugins.json'))['plugins']['forge@forge-marketplace'][0]['version'])"` → 7.8.0; интро новой сессии — «Forge plugin (v7.8.0) активен.», строка `Phase 5   /forge:guide`, и напоминание `📖 Гайд по проекту v1.1: … гайд устарел на 1 задачу`.
settings.json: `git stash pop` → показать владельцу diff простыми словами («перенос блока разрешений + две одноразовые строки allow, которые Claude Code дописал кнопкой»); рекомендация — сбросить: `git checkout -- .claude/settings.json` (deny-список в HEAD тот же; allow-строки мусорные). Если владелец хочет оставить — оставляем незакоммиченным.
--- ПРОВЕРКА:
`git branch --show-current` → master; `git log --oneline -3` → `[forge] память: итог сессии…`, `merge`/`feat(project-guide)…`; `git stash list` → пусто; `git status --short` → пусто (если settings.json сброшен) или ` M .claude/settings.json`; версия 7.8.0 на GitHub и в installed_plugins.json; владелец видит интро v7.8.0 с `/forge:guide`


===== INTERFACES:
КОНТРАКТ СТЫКОВКИ (то, на что рассчитаны мои шаги; кусок рендерера/скилла должен это выполнить):

Имена:
- Скилл: forge-plugin/skills/project-guide/SKILL.md (name: project-guide; триггеры RU «собери гайд», «открой гайд», «покажи гайд», «это версия 2»; NOT «что дальше по проекту» → unblocker, NOT «статус проекта» → forge-context). Рендерер: forge-plugin/skills/project-guide/render.py (stdlib, JSON, без PyYAML). Команда: forge-plugin/commands/guide.md → /forge:guide. Тесты: forge-plugin/tests/hooks/test-project-guide.sh, фикстура tests/hooks/fixtures/guide-sample.json. Evals: evals/criteria/guide.yml, transition-matrix колонка to_guide / строка guide. Формат: forge-plugin/docs/project-guide-format.md.
- state.yml во время сборки: `phase: guide` / `task: гайд по проекту vX.Y`; в конце `phase: idle` (statusline case: guide|project-guide|"Phase 5"|5).

Файлы данных (память, коммитятся backup.sh):
- .forge/guide/current.json — живой документ (его правят merged/link/answer; читает summary).
- .forge/guide/vX.Y.json — замороженный снимок при каждой сборке (никогда не правится).
- .forge/guide/shots/*.png — снимки (в .forge/.gitignore строкой `guide/shots/`; ensure_gitignore в render.py дописывает именно её; старые строки status-report.html / reports/shots/ не нужны).
Видимые файлы (в git, коммитит backup.sh вместе с .forge — paths=(.forge docs/guide)):
- docs/guide/guide-vX.Y.html (self-contained, снимки data:URI), docs/guide/guide-vX.Y.pdf (Chrome headless; нет /Applications/Google Chrome.app → PDF не делается, HTML есть), docs/guide/guide-latest.html (копия последней; PDF-копии latest нет).

Схема current.json (минимум, что читают мои точки врезки):
{ "project", "audience" («для кого документ»), "version": "1.1", "built_at", "updated_at", "stale_tasks": int, "changelog": [{"from":"1.0","items":[...]}],
  "codes": {"letters": {"P":"процесс","O":"открытые","R":"риски","A":"…"}},
  "decisions": [{"code":"A2","group":"A","title","what","why","status":"open|accepted|redo|discuss","default":bool,"fire":bool,"answer":"текст владельца","source":"decisions.yml:<id>|analyst"}],
  "findings": [{"id":"f1","code":"R1","owner":"code|decision|both","effort":"S|M|L","block":"crit|biz|imp|pol","title","what","why","source","status":"open|done|deferred","task_slug":null}],   ← скелет v1 без изменений + поле code
  "map": {"bigPicture":…, "flows":[…], "entities":[…], "gaps":[…], "roles":[…]},  ← из product-mapping
  "screens": {"web":[{"file":"shots/x.png","caption"}], "tgmock":[{"from":"bot|user","text"}]},
  "glossary": [{"term","meaning"}], "sources": {"analysts":4,"map_agents":2,"decisions":12} }

CLI render.py (cd в корень репо сам, все режимы exit 0 при отсутствии гайда, кроме usage=2):
- build [--major] [--dry-run] — новая версия: читает current.json (или импортирует .forge/status-report.json, если current.json нет — миграция v1), номер +0.1 (--major → X+1.0), пишет vX.Y.json + current.json, docs/guide/guide-vX.Y.html + .pdf + guide-latest.html, stale_tasks=0, changelog. stdout: `FORGE-GUIDE: версия X.Y → docs/guide/guide-vX.Y.html (+pdf)`.
- render [json] [html] — перерисовать HTML из JSON без новой версии (для макета вне .forge и для guide-latest.html); ensure_gitignore только если html внутри .forge/guide.
- merged <slug> — finding с task_slug==slug → status done, stale_tasks+1, updated_at, перерисовать guide-latest.html; stdout `FORGE-GUIDE: сделано → «title»` или `FORGE-GUIDE: карточки с задачей «slug» нет`.
- link <id|код> <slug> — task_slug; stdout `FORGE-GUIDE: f1 → задача slug` / `FORGE-GUIDE: карточки nope нет`.
- answer <КОД> <ok|redo|discuss> [текст] — decisions[code].status = accepted|redo|discuss, answer=текст, fire=false; перерисовать guide-latest.html; stdout `FORGE-GUIDE: A2 → принято`.
- summary — если есть открытые решения (findings owner decision/both + decisions status open) или stale_tasks>0: одна строка `📖 Гайд по проекту vX.Y: ждут N решений владельца, гайд устарел на M задач (docs/guide/guide-latest.html; пересобрать — «собери гайд»)`; иначе пусто. Пути по умолчанию: .forge/guide/current.json. (test-session-start.sh grep-ит «ждут 2 решения владельца», «гайд устарел на 3 задачи», «📖 Гайд».)

Метка передачи пункта в new-task: `card:<код>` (например card:R3), link принимает и код, и id.
Строки для Клода: префикс FORGE-GUIDE: (заменяет FORGE-REPORT:).
Лимиты: ≤6 снимков, PNG ≤200 КБ (render.py уменьшает до 1200px или пропускает с пометкой), HTML ≤ ~1.5 МБ, PDF ≤ ~3 МБ.
PDF-команда: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf="$PWD/docs/guide/guide-vX.Y.pdf" "file://$PWD/docs/guide/guide-vX.Y.html".
Версия плагина: 7.8.0 в forge-plugin/.claude-plugin/plugin.json, forge-plugin/.claude-plugin/marketplace.json, .claude-plugin/marketplace.json, .forge/index.yml, forge-tray VERSION.

===== OPEN:
- Имя команды: /forge:guide (коротко, удобно голосом) при скилле project-guide — или /forge:project-guide для симметрии? В шагах принято /forge:guide.
- Живой файл .forge/guide/current.json + снимки vX.Y.json — или только vX.Y.json, где последний и есть живой? Принято current.json (merged/answer правят его, снимки не трогаются) — подтвердить с куском рендерера.
- После мержа/ответа кодом перерисовывать docs/guide/guide-latest.html без смены номера (принято) — или не трогать docs/ до следующей сборки? Первое даёт «открой гайд» всегда свежий, но guide-latest.html перестаёт быть байт-в-байт копией guide-vX.Y.html.
- Миграция старого .forge/status-report.json: автоматически внутри `render.py build` (принято, только этот репо её и увидит) — или отдельный режим `migrate`? Старый JSON после сборки удаляем `git rm` руками Клода в основной сессии.
- settings.json после релиза: сбросить (`git checkout -- .claude/settings.json`; deny-список и так в HEAD, allow-строки — одноразовый мусор от кнопки «always allow») или оставить незакоммиченным? Рекомендация — сбросить, решает владелец на Чекпоинте C.
- PDF в git на каждую версию — решено; но нужен ли guide-latest.pdf? В плане — нет (только HTML-копия), чтобы не удваивать размер коммита.
- .forge/sketches/status-report-mockup.html и .forge/notes/status-report.md оставляем как историю (не переименовываем) — ок?
- Prompt-тесты триггеров (tests/skill-triggering/run-all.sh) требуют claude CLI и минуты на скилл — гонять на Чекпоинте B только project-guide и project-unblocker (граница «что дальше по проекту» vs «собери гайд») или пропустить?

===== RISKS:
- Порядок в finishing: `git add -A` + коммит задачи идут ДО backup.sh — новые docs/guide/*.html|pdf со снимками попадут в коммит задачи (это ок, папка и так в git), но в чужих проектах ветка задачи может утяжелиться на МБ; лимиты снимков (≤6, ≤200 КБ) — единственный тормоз, render.py должен их реально соблюдать.
- Лимит инжекции index.yml — 2400 байт (сейчас 2213): правки catalog/session в D8 должны укладываться — проверять `wc -c` после каждой правки.
- test-session-start.sh и hooks/session-start.sh завязаны на точный формат строки summary и путь по умолчанию .forge/guide/current.json — если рендерер выберет другой путь/эмодзи, тесты упадут; контракт в interfaces обязателен для обоих кусков.
- Chrome headless тянет Google Fonts из сети: офлайн PDF соберётся на системных шрифтах (вид хуже, но не падение). Первый запуск headless Chrome может показать диалог/занять 5–10 с; аргументы `--headless=new` проверены для v152 только по документации — на Чекпоинте A убедиться командой.
- backup.sh: pathspec `-- .forge docs/guide` при отсутствии docs/guide ронял бы commit («pathspec did not match») — поэтому массив paths строится по `[ -d docs/guide ]`; тест (13) это покрывает, но git старых версий (<2.x) не проверялся.
- У пользователей с установленным 7.7.0 в проектах может лежать .forge/status-report.json без гайда: скилл status-report исчезает после обновления — без подсказки в session-start (elif в D2) напоминание молча пропадёт; подсказка добавлена, но старый HTML/шапка в чужих .forge/.gitignore остаются (безвредно).
- Рост репозитория: каждая версия гайда ~1–3 МБ (HTML + PDF) в истории навсегда; при 50+ версиях — сотни МБ клона. Если станет больно — вынести PDF из git (git-lfs или только latest) отдельной задачей.
- Переименование через git mv с последующей полной перезаписью SKILL.md/формат-дока может не распознаться git как rename (similarity < 50%) — история файла станет «удалён + добавлен»; на работу не влияет.
- На Чекпоинте B гайд собирается по самому плагину (нет веб-интерфейса и бота) — ветки «снимки Playwright» и «tgmock» живым прогоном не проверяются, только фикстурой на Чекпоинте A; первый настоящий прогон с картинками — на чужом проекте (journal.next).
- github-sync (github_sync: true в этом репо) при мерже обновит Pinned Issue/README-шапку — не мешает, но README-шапка может «моргнуть» в коммите задачи; ничего делать не нужно.
