# План: Гайд по проекту — фаза 5 становится живым версионным документом (project-guide)

**Задача:** см. `.forge/tasks/2026-09-06-project-guide.md`

**Подход:** Скилл `status-report` переезжает в `skills/project-guide/` (команда `/forge:guide`), рендерер `render.py` вырастает до гайда по эталону Vespera (разделы 00–08, коды решений, версии, PDF), данные — `.forge/guide/vX.Y.json` (память, коммитится), видимые версии — `docs/guide/`. Разделы «как устроено» дают два картографа по образцу product-mapping, принятые решения — `decisions.yml`, риски/план/открытые/решения — 4 аналитика фазы 5. Ответы владельца читает Клод и передаёт рендереру уже разобранный статус по коду (`verdict`), после мержа работает прежний `merged`. Текст скилла пишем через skill-creator (требование владельца).

**Приложения плана** (полные тексты шагов с кодом и old→new): `.forge/plans/2026-09-06-project-guide/design-renderer.md`, `design-skill.md`, `design-integration.md`, `design-integrator.md` (правки интегратора), `critique.md` (правки критики). **При расхождении между приложениями и планом — прав план.**

**Что увидишь ты:**
- Говоришь «собери гайд» — минут через десять открывается `docs/guide/guide-v1.0.html` (и PDF рядом): шапка с версией и «для кого», 00 «за 30 секунд» + 🔥 «без чего стоим» + «как работать с документом» (легенда кодов, что значат 🔥 и «дефолт», куда отвечать), 01 суть одной схемой (+ экраны, если есть), 02 из чего состоит, 03 главный путь по шагам, 04 роли, 05 решения с кодами и «почему» (принятые / «дефолт» / открытые), 06 карта рисков R-кодами с «предлагаем», 07 план «сейчас → дальше → позже», 08 словарик, футер «откуда собрано». Вид — как у гайда Vespera.
- Отвечаешь в чат как удобно — «A2 ок», «B2 — переделать: только по телефону», «O1 — ночью отвечает администратор», «R4 приоритет выше» — Клод разбирает, что ты имел в виду, применяет к каждому коду, страница и PDF перерисованы, 🔥 остаётся только у неотвеченных, номер тот же. Непонятный ответ («ну не знаю») — Клод предложит 2–3 варианта и свою рекомендацию, «не знаю» = его вариант.
- «Собери гайд» ещё раз — рядом `v1.1` с блоком «что изменилось с v1.0» (твои ответы, мержи, новые/закрытые находки); старые файлы не трогаются; `guide-latest.html` — всегда последняя. «Это версия 2» → `v2.0`. Оборванная сборка не портит историю: недособранная версия помечена, следующее «собери гайд» её дособирает, а не плодит номера.
- После «мержим» сделанная задача сама помечается «уже работает»; при старте сессии — «📖 Гайд v1.1: ждут N решений владельца, устарел на M задач» — считаются только открытые, «обсудить» и 🔥, а не каждое «дефолт».
- «Открой гайд» — последняя версия за секунды, без агентов. Решения, которые ты, скорее всего, захочешь поправить: заголовки разделов, текст «как работать с документом», состав 🔥.

**Открытые вопросы:** нет (по умолчанию: «обсудить» остаётся в 🔥 до разговора; после 1.9 идёт 1.10; крупный номер — только по слову).

**Блокеры:** нет (Chrome 152 на маке есть, PDF проверен).

**Стыки — принятые решения (единые для всех шагов):**
- Имена: `forge-plugin/skills/project-guide/{SKILL.md,render.py}` (git mv из `status-report/`), команда `forge-plugin/commands/guide.md` (`/forge:guide`, git mv; алиаса нет), тест `tests/hooks/test-project-guide.sh`, фикстура `tests/hooks/fixtures/guide-sample.json` (копия, старая `status-report-sample.json` остаётся как LEGACY для теста миграции), промпт `tests/skill-triggering/prompts/project-guide.txt`, `evals/criteria/guide.yml`, `docs/project-guide-format.md`. Имя фазы везде короткое — `guide`: `state.yml: phase: guide`; statusline `guide|"Phase 5"|5) "📖 Фаза 5: Гайд по проекту"`; evals `phase: guide`, матрица `to_guide`.
- Данные: только `.forge/guide/vX.Y.json`; последняя = максимум по имени (`^v(\d+)\.(\d+)\.json$`). Отдельных `current/latest/draft.json` нет. Верхнеуровневое поле `built_at`: `bump` пишет `null`, боевой `render` без аргументов ставит дату — версия «собрана». Ответы, мерж, снимки правят последний `vX.Y.json` на месте. Схема — `design-renderer.md` Шаг 1 **без** полей `since_version`, `logo`, `note`, `deferred_reason` (их никто не читает); плюс у находок `agreed_at?`, `links?`; у решений `was?`, `verdict?{date,text}`.
- Витрина: `docs/guide/guide-vX.Y.html`, `guide-vX.Y.pdf`, `guide-latest.html` (побайтовая копия последней). Снимки — `.forge/guide/shots/` (строка `guide/shots/` в `.forge/.gitignore`), в HTML — data: URI; ≤6 снимков, PNG ≤200 КБ — правило скилла (`browser_resize 1280×800`, `scale: css`, не fullPage), рендерер картинки не уменьшает.
- Игнор: `FORGE_IGNORE` в render.py = heredoc backup.sh = heredoc init.md = 7 строк (`.inject-state .last-backup .migration-declined state.yml .github-* graph.json guide/shots/`); `ensure_gitignore` только дописывает недостающее.
- CLI рендерера (7 режимов, все exit 0, битый JSON → одна человеческая строка «файл гайда повреждён (…) — почини JSON или верни из git: `git checkout -- <файл>`»; префикс служебных строк `FORGE-GUIDE:`):
  - `bump [major]` — нет версий → создаёт `v1.0.json` (скелет с P1 + миграция `.forge/status-report.json`: находки и снимки переезжают, старые файлы убираются; битый легаси → откладывается в `status-report.json.broken`, гайд создаётся пустым); есть → копия последней в `vX.(Y+1)` / `v(X+1).0`, `changelog.insert(0, {version, date, items: pending_changes})`, `pending_changes=[]`, `stale_tasks=0`, `built_at=null`; если последняя ещё не собрана (`built_at` null) — отказ «vX.Y ещё не собрана — дособери (Edit → render)», файл не создаёт.
  - `render [json] [out.html]` — без аргументов: последняя версия → `built_at=today`, `docs/guide/guide-vX.Y.html` + `guide-latest.html`, `ensure_gitignore`; с `out.html` — только этот файл (макет), ничего больше не трогает.
  - `pdf [html] [pdf]` — Chrome headless (Popen + ожидание файла + terminate, флаги из `design-renderer.md` Шаг 7); нет Chrome → «Chrome не найден — PDF пропущен, есть HTML»; `FORGE_CHROME` переопределяет путь.
  - `verdict <код> <статус> [текст]` — один код за вызов (несколько — через `&&`). Код нормализуется (`upper` + кириллица по звуку: Р→R, П→P, Н→N, Б→B, В→V, Д→D, К→K, М→M, Т→T, А→A, О→O, Е→E, С→S; не найден — пробуем по глифу Р→P, Н→H, В→B, С→C). Для решений: `accepted [текст]` (текст → `was`/`what`, `verdict`), `changed <текст>` (без текста — «⚠ переделать — а как? …», ничего не меняется), `discuss` (🔥 остаётся), `works`, `dropped`. Для рисков `R<n>`: `agreed` (предложение принято: `agreed_at`, статус не меняется, 🔥 снят), `done` (сделано: `done_at`), `up`/`down` (block crit/pol), `deferred`, `changed <текст>` (what). Неизвестный код → «⚠ код Z9 не найден в гайде»; неизвестный статус → отказ с перечнем допустимых. Каждый вызов → `pending_changes`, `updated_at`; на несобранной версии — только JSON, «HTML не перерисован, ответ учтён». После изменения — обе HTML, а PDF этой версии — только если он уже существует.
  - `merged <slug>` / `link <id> <slug>` / `summary` — как в v1, на последней версии; `link` принимает и внутренний id (`f7`), и R-код (`R7`); `merged` перерисовывает обе HTML (+ PDF, если есть) и пишет `pending_changes`; `summary` печатает «📖 Гайд по проекту vX.Y: ждут N решений владельца, гайд устарел на M задач (docs/guide/guide-latest.html; ответы — кодами в чат, пересобрать — «собери гайд»)», на несобранной версии — «vX.Y ещё не собрана — скажи «собери гайд»».
- Счётчики: в документе «ждут ответа» = решения `default|open|discuss`; в напоминании session-start `open_decisions` = решения `open|discuss` + `default` с `fire` + находки `open` с owner `decision|both` (P1 и дефолты без 🔥 не нагоняют). Числа в тестах выводить из этого правила по фикстуре, не подгонять.
- Версии: +0.1 за «собери гайд», major по слову, после 1.9 — 1.10. Старые `vX.Y.*` не правятся. PDF пересобирается вместе с HTML при `verdict`/`merged`, если файл уже был; в футере — «обновлён {updated_at}: N изменений после сборки», когда есть `pending_changes` или `stale_tasks`.
- Коды: `R<n>` из id находки (`f7` → `R7`), ярус по block (crit → 🔴, biz → 🟠, imp/pol → 🟡); решения — группы `P` (всегда, только P1 обязателен) … `O` (всегда, открытые) + буквы под проект: одна латинская заглавная, не P/O/R; код `^[A-Z]\d+$`, кириллица в JSON запрещена; рендерер печатает ⚠ при нарушении, не прерываясь. Коды стабильны, новые — с конца; решение, потерявшее смысл → `dropped` (код занят, не печатается).
- Находка с `owner: decision|both`, вынесенная в решение O<n>, получает `links: ["O<n>"]` и `status: deferred`; хелпер `moved_out(f)` исключает такие из «Отложено», счётчиков и summary. Находка, доказанно закрытая агентом → `done` + `done_at`. При `bump` сделанное остаётся `done`.
- Субагенты сборки — 6 одним сообщением: Картограф А (Flow → 01 схема, 03 путь), Картограф Б (Entity+Gap → 02 части, 04 роли, 08 словарь, дыры → находки), Аналитики 1–3 (код / git / инфраструктура + «Адреса интерфейса»), Аналитик 4 «память, документация и решения» (в него влит Секретарь: decisions.yml + direction.yml + открытые задачи → `decisions[]` с кодами, группами, статусами; прошлая версия — для стабильности кодов). Картографы — по образцу product-mapping (то же деление Flow / Entity+Gap и правило «механизм для не-кодера»), но со своим выходом под разделы 01–04, на «вы», с `source`; `.forge/product-map.json` — только подсказка.
- После `bump` Клод через Edit заполняет `meta` (project, audience, eyebrow — состояние проекта простыми словами, built_from — откуда собрано; `project_version` ставит bump из index.yml) и **дописывает** в `changelog[0].items` (не перезаписывая строки ответов/мержей) новые/закрытые/снятые коды — не больше 10 строк, самое важное первым; у v1.0 changelog пустой. В `.forge/index.yml` проекта — заменить старую catalog-запись `status-report:` на `guide: {path: .forge/guide/, tags: [guide, report, what-next, findings, decisions-pending, owner, risks, versions]}` (нет ни той ни другой — дописать последней), затем `wc -c` ≤ 2500 с той же фразой владельцу, что в v1.
- Экраны: веб — Playwright (`.playwright-mcp/sr-<id>.png` → `.forge/guide/shots/<id>.png`); Telegram — `tg_mocks` из настоящих текстов бота (grep `send_message|reply_text|sendMessage|bot.send`) с подписью «воспроизведение, данные вымышленные»; ничего не нашлось — без картинок, без вопросов.
- «Как работать с документом» зашит в рендерер: легенда групп из `groups()` + «Метка 🔥 — нужно на этой неделе, без этого стоим. Метка «дефолт» — наша рекомендация: нет возражений — действуем (см. P1)» + пример ответа + `snapshot.howto_extra` (пусто → «Ответы — владельцу проекта в любом виде: списком кодов, голосом, в переписке; он вносит их в гайд, и следующая версия выйдет с обновлёнными статусами»). Футер без «в чат». Под риском вместо slug — «→ в работе» / «→ уже работает» (slug в атрибуте `title`).
- Текст скилла — через `skill-creator:skill-creator` (бриф = `design-skill.md` с поправками ниже), затем оптимизация описания триггеров; правила `forge:writing-skills`. Руками SKILL.md не пишем.
- backup.sh: `paths=(.forge)`; затем `shopt -s nullglob; for p in docs/guide/guide-v*.html docs/guide/guide-v*.pdf docs/guide/guide-latest.html; do git add -- "$p" && paths+=("$p"); done; shopt -u nullglob` — только свои файлы (чужой `docs/guide/` не трогаем), `diff --cached`/`commit`/`reset` — по `"${paths[@]}"`.
- На GitHub гайд уезжает файлами `docs/guide/`; Issues не заводятся.

**Поправки к приложениям** (исполнитель берёт текст черновика с этими заменами; полный список — `design-integrator.md` и `critique.md`): `test-guide.sh` → `test-project-guide.sh`; `FORGE_IGNORE`/`GUIDE_LINES` — 7 строк / `("guide/shots/",)`; `do_init` + `do_bump` → один `do_bump` (нет версий → v1.0 + миграция, битый легаси → `.broken`); `verdicts "<текст>"` + `parse_verdicts`/`VERBS`/`VERDICT_RE` → `verdict <код> <статус> [текст]` (парсера речи нет); `CYR` — по звуку (Р→R), запасной проход по глифу; `answer`/`build`/`init` → `verdict`/`render`/`bump`; `current.json`/`latest.json`/`draft.json`/`guide-vX.Y.json` → `vX.Y.json`; `phase: project-guide` → `phase: guide`; statusline без `status-report|project-guide`; снимки `.forge/reports/shots/` → `.forge/guide/shots/`; алиаса `commands/status-report.md` нет; `commands/guide.md` — 3 строки; description ≤1024; Секретарь решений влит в Аналитика 4 (6 субагентов, `sources.analysts` = 6); evals — `criteria/guide.yml` с 8 проверками из `design-skill.md` G5 как есть (`phase: guide`, пути под `vX.Y.json`), число не фиксировать; `prompts/product-mapping.txt` не создаём; режим ПОКАЗАТЬ без фразы «снимков на этой машине может не быть»; `base` в `do_render` — `parents[2]` для `.forge/guide/vX.Y.json`; `render_risk` slug → `title`; тест (15) с живым Chrome — только при `FORGE_TEST_PDF=1`, в начале теста `export FORGE_CHROME=/nonexistent`; поля `since_version/logo/note/deferred_reason` убраны.

---

## Шаг 0: Git-состояние и память

**Файлы:** `.claude/settings.json` (в stash), `.forge/tasks/2026-09-06-project-guide.md` + `…/reference-vespera-guide.html` + `.forge/plans/2026-09-06-project-guide*` (в память).

**Что делаем:** ветка `feat/project-guide` уже есть; грязный только `.claude/settings.json` — `git stash push -m "wip settings.json: permissions + одноразовый allow" -- .claude/settings.json`; затем `bash forge-plugin/skills/memory-backup/backup.sh "задача и план project-guide + эталон Vespera"`.

**Как проверим:** `git status --short` → пусто; `git stash list` → 1 строка; `git log --oneline -1` → `[forge] память: …`.

## Шаг 1: Переезд файлов status-report → project-guide (git mv)

**Файлы:** см. `design-integration.md` D1.

**Что делаем:**
```bash
cd forge-plugin
git mv skills/status-report skills/project-guide && rm -rf skills/project-guide/__pycache__
git mv commands/status-report.md commands/guide.md
git mv tests/hooks/test-status-report.sh tests/hooks/test-project-guide.sh
cp tests/hooks/fixtures/status-report-sample.json tests/hooks/fixtures/guide-sample.json   # старая остаётся: LEGACY для теста миграции
git mv tests/skill-triggering/prompts/status-report.txt tests/skill-triggering/prompts/project-guide.txt
git mv evals/criteria/status-report.yml evals/criteria/guide.yml
git mv docs/status-report-format.md docs/project-guide-format.md
```
`run-all.sh`: `"status-report"` → `"project-guide"`. `commands/guide.md` (3 строки): description «Гайд по проекту (Phase 5). Один живой версионный документ для читающего со стороны: суть, устройство, экраны, решения с кодами, риски, план. «Собери гайд» — новая версия (карта проекта + аудит), «открой гайд» — последняя без пересборки; после мержа обновляется сам.», `disable-model-invocation: true`, тело `Invoke the forge:project-guide skill and follow it exactly as presented to you`. `prompts/project-guide.txt` → «Собери мне гайд по проекту — такой документ, чтобы человек со стороны понял, что это, как устроено, какие решения приняты и какие ждут меня».

**Как проверим:** `git status --short | grep -c '^R'` → 7; `ls forge-plugin/skills/status-report forge-plugin/commands/status-report.md 2>&1 | grep -c 'No such'` → 2; `sed -n 20p forge-plugin/tests/skill-triggering/run-all.sh` → `"project-guide"`.

## Шаг 2: Фикстура-образец гайда «Lumen»

**Файлы:** переписать `forge-plugin/tests/hooks/fixtures/guide-sample.json` по каркасу `design-renderer.md` Шаг 1 с поправками: без `since_version`/`logo`/`deferred_reason`; 7 решений — P1 (default), A1 (default), A2 (accepted), A3 (`dropped`, «Скидка за отзыв» — снято), B1 (default, fire), D1 (discuss, fire), O1 (open, fire); 8 находок v1 1:1, у f2/f3 `links: ["D1"]`; `built_at: "2026-09-06"`; тексты на «вы».

**Как проверим:** `python3 -c "import json;d=json.load(open('forge-plugin/tests/hooks/fixtures/guide-sample.json'));print(len(d['decisions']),len(d['findings']),len(d['flow']),len(d['glossary']),d['meta']['version'],d['built_at'])"` → `7 8 4 3 1.0 2026-09-06`.

## Шаг 3: Тест рендерера гайда (RED)

**Файлы:** переписать `forge-plugin/tests/hooks/test-project-guide.sh` по `design-renderer.md` Шаг 2 с поправками стыков. В начале теста `export FORGE_CHROME=/nonexistent`.

**Что делаем:** группы проверок: (1) render → обе HTML, 9 заголовков по порядку, `<title>Lumen · Гайд по проекту v1.0</title>`, «для владельца сети салонов», «версия проекта 0.9.2», `built_at` в JSON стал сегодняшним, stdout «решений 6 (ждут ответа 5, 🔥 3), рисков 7» (dropped A3 не считается и не печатается: `! grep -q '<span class="code">A3</span>'`); (2) решения — коды, чипы, `<span class="fire">` ровно 3, легенда `P*`/`R*`, текст про 🔥 и «дефолт» в `.howto`, футер без «в чат»; (3) риски — `R2` crit с `(→ D1)`, `Предлагаем:`, ярусы, deferred не показан; (4) схема/части/шаги/роли/план/словарик/tgmock, без `<script`; (5) экранирование + `**жирный**`; (6) снимки: нет файла — без `<figure>`, есть — data: URI + figcaption; вызов из поддиректории с явными путями находит снимок через `base` (`mkdir sub && (cd sub && render render ../.forge/guide/v1.0.json ../mock.html)`); (7) `bump` → v1.1.json (changelog, previous, `built_at` null), `bump major` → v2.0.json, `render` без аргументов берёт последнюю и ставит `built_at`; `bump` на несобранной версии отказывает; (8) `verdict`: `A1 accepted` → accepted, 🔥 снят; `B1 changed "только по телефону"` → changed, what/was; `B1 changed` без текста → ⚠, без изменений; `D1 discuss`; `O1 accepted "ночью отвечает администратор"` → accepted, what обновлён; `R4 up` → block crit; `R2 agreed` → agreed_at, статус open; `R5 done` → done; `Р4 up` (кириллица) → R4; `Z9 accepted` → ⚠ не найден; `A1 fooo` → отказ с перечнем; `pending_changes` растёт; в выводе «PDF пропущен» (FORGE_CHROME несуществующий) только когда PDF-файл версии существует — иначе строки нет; (9) link по `f1` и по `R2`, unknown id → «карточки … нет»; merged → done + stale_tasks + `risk crit done` + «устарел на 1 задачу»; merged без карточки → stale +1; summary — число из правила счётчиков (в тесте — комментарий с расшифровкой); тишина, когда нечего; (10) без гайда — молчат, `render` говорит «ещё не собирали», `docs/` не создаётся; (11) `bump` без версий + легаси `status-report.json` → v1.0 с 8 находками и `[P1]`, старые файлы убраны; битый легаси → `.broken` + пустой v1.0; (12) `.forge/.gitignore` 7 строк / дописка только `guide/shots/` / макет не трогает; (13) неизвестный блок → средний ярус + ⚠; (14) битый JSON во всех 7 режимах — exit 0, «повреждён … git checkout»; summary молчит; (15) pdf без Chrome → «PDF пропущен», HTML на месте; живой Chrome — только при `FORGE_TEST_PDF=1` (с вырезанной ссылкой на Google Fonts), иначе `SKIP`; (16) `moved_out`: находка decision с `links: ["O1"]` и deferred не попадает в «Отложено» и в summary.

**Как проверим:** `bash forge-plugin/tests/hooks/test-project-guide.sh | tail -1` → `N test(s) FAILED` (RED).

## Шаг 4: Рендерер, часть 1 — версии, bump с миграцией, CSS эталона, разделы 00–08

**Файлы:** `forge-plugin/skills/project-guide/render.py` — по `design-renderer.md` Шаги 3–4 с поправками: `do_bump` объединяет init+bump (см. стыки), `GuideBroken` с текстом «почини JSON или `git checkout -- <файл>`», `read_index()` без PyYAML; `CSS` = `<style>` эталона (`reference-vespera-guide.html` строки 9–109) + `.acc .dsc .was .vd .risk.done .risk .slug .changes .empty`; `SECTIONS`, `groups()` с проверкой кодов (`^[A-Z]\d+$`, буква ≠ R → ⚠), `moved_out()`, `render_decision/risk/scheme/screens/plan/glossary/tgmock`, `render_html` 00–08 + `.howto` из стыков + футер (`built_from or "код проекта и память .forge"`, «обновлён …: N изменений после сборки»), `counts()` (два множества: `waiting` и `open_decisions`), `do_render()` (`base = jp.parents[2]` для `.forge/guide/vX.Y.json`, иначе папка json; `docs/guide` + latest + `ensure_gitignore` только на боевом пути; `built_at=today` только в CLI `render` без аргументов).

**Как проверим:** `bash forge-plugin/tests/hooks/test-project-guide.sh | grep -E 'render should|decisions should|risks should|how-it-works|escape|screenshot|gitignore|mockup|unknown/missing block|no guide yet|bump.*legacy|moved'` → PASS; `python3 forge-plugin/skills/project-guide/render.py render forge-plugin/tests/hooks/fixtures/guide-sample.json /tmp/x.html && grep -c '<h2><span class="no">' /tmp/x.html` → 9.

## Шаг 5: Рендерер, часть 2 — verdict, pdf, merged/link/summary

**Файлы:** `forge-plugin/skills/project-guide/render.py` — `do_verdict(code, status, text)` по стыкам (≈40 строк: нормализация кода, поиск в decisions/findings, таблица допустимых статусов, `was/what/verdict/agreed_at/done_at/block`, `pending_changes`, `updated_at`, `built_at` не трогать; на несобранной версии — только save); `do_pdf` по `design-renderer.md` Шаг 7; `merged/link/summary` по Шагу 8 с поправками (`link` по id или R-коду; PDF пересобрать, если есть; summary по правилу счётчиков и «ещё не собрана»); `run()` с 7 режимами.

**Как проверим:** `bash forge-plugin/tests/hooks/test-project-guide.sh | tail -1` → `All tests passed`; из корня репо `python3 forge-plugin/skills/project-guide/render.py summary; echo rc=$?` → пусто, `rc=0`; `python3 forge-plugin/skills/project-guide/render.py verdict A1 fooo` в tmp-проекте → отказ с перечнем статусов.

## Шаг 6: Макет на фикстуре «Lumen» (+ PDF)

**Файлы:** создать `.forge/sketches/project-guide-mockup.html`; удалить `.forge/sketches/status-report-mockup.html`.

**Что делаем:**
```bash
python3 forge-plugin/skills/project-guide/render.py render forge-plugin/tests/hooks/fixtures/guide-sample.json .forge/sketches/project-guide-mockup.html
python3 forge-plugin/skills/project-guide/render.py pdf .forge/sketches/project-guide-mockup.html
git rm -q .forge/sketches/status-report-mockup.html
open .forge/sketches/project-guide-mockup.html && open .forge/sketches/project-guide-mockup.pdf
```
PDF макета после показа удалить.

**Как проверим:** `grep -c '<h2><span class="no">' .forge/sketches/project-guide-mockup.html` → 9; `grep -c 'class="fire"'` → 3; `git status --short | grep -c docs/guide` → 0.

---

### ✅ Чекпоинт A: реакция на макет

Что показываем: HTML и PDF макета (Lumen) рядом с гайдом Vespera — шапка, «за 30 секунд», 🔥, «как работать с документом», схема, услуги, шаги, роли, решения с чипами, риски R-кодами, план, словарик, футер.
Что подтверждает владелец: «похоже на эталон, вид ок» — или что убрать/добавить. Правки вида → CSS/`render_html` + ожидания теста.

Следующее: текст скилла и точки вызова.

---

## Шаг 7: SKILL.md через skill-creator + команда

**Файлы:** `forge-plugin/skills/project-guide/SKILL.md` (переписать целиком), `forge-plugin/commands/guide.md` (из Шага 1).

**Что делаем:** инвокнуть `skill-creator:skill-creator` с брифом: «переписать скилл project-guide по черновику `design-skill.md` (G2–G3) с поправками плана: файлы только `vX.Y.json`; режимы `bump/render/pdf/verdict/merged/link/summary`; `state.yml: phase: guide`; 6 субагентов одним сообщением (Секретарь влит в Аналитика 4); Шаг 0 — режимы ПОКАЗАТЬ («открой/покажи гайд»: `open docs/guide/guide-latest.html`, одна строка «Открыл гайд v{version} (собран {meta.date}; {summary без префикса})», без фразы про снимки на другой машине) / СОБРАТЬ (`bump` [major по «это версия N»] → 6 субагентов → Edit JSON: meta, разделы, коды, catalog в index.yml, changelog[0].items дописать → снимки → `render` → `pdf` → open → 3–5 строк в чат) / ОТВЕТЫ (сообщение содержит код `[A-ZА-Я]{1,2}\d+` — тире/двоеточие необязательны; Клод переводит слова в статус: ок/да/норм → `accepted` (для рисков — `agreed`), «переделать: …»/«иначе» с текстом → `changed`, «обсудить»/«голосом»/«нет» → `discuss`, «сделано» → `done`/`works`, «приоритет выше/ниже» → `up`/`down`, «отложить» → `deferred`, свободный ответ на O-вопрос → `accepted "<его слова>"`; по одному `render.py verdict` на код через `&&`; принятое — в decisions.yml; непонятный или смешанный ответ («ну не знаю», «ок, но обсудим») — не применять, дать 2–3 варианта + рекомендацию по одному коду за ход, «не знаю» = вариант Клода; после «повреждён» от рендерера — bump не звать, чинить JSON или `git checkout -- <файл>`, владельцу одна строка без текста ошибки) / «добавь снимки» (Edit JSON + `render`, без агентов); хэндофф «бери» → new-task с `card:<id>` (id или R-код); NOT-for: «что дальше по проекту» → unblocker, «статус проекта» → forge-context, «карта проекта» → product-mapping; description ≤1024 с RU/EN триггерами («собери гайд», «обнови гайд», «открой гайд», «гайд по проекту», «это версия 2»); язык гайда — на «вы»; правила из стыков: находка decision|both ↔ O<n>, `dropped`, `done + done_at`, лимиты снимков, только P1 обязателен, буквы групп латинские не P/O/R; правила `forge:writing-skills`». По завершении — оптимизация описания триггеров средствами skill-creator (наивные фразы + негатив «что дальше по проекту», «покажи карту проекта»).

**Как проверим:** `sed -n 2p forge-plugin/skills/project-guide/SKILL.md` → `name: project-guide`; длина description ≤ 1024; `grep -c '^### Картограф\|^### Аналитик' SKILL.md` → 6; `grep -n 'render.py" verdict\|render.py" bump\|render.py" pdf\|card:<id>\|phase: guide\|built_from\|changelog' SKILL.md` → по ≥1; `grep -c 'current.json\|latest.json\|draft.json\|status-report.json\|verdicts \|render.py" init' SKILL.md` → 0; `tail -1 forge-plugin/commands/guide.md` → строка Invoke.

## Шаг 8: Точки вызова и память в git (тесты RED → GREEN)

**Файлы:** `forge-plugin/hooks/session-start.sh`, `hooks/statusline.sh`, `skills/finishing-a-development-branch/SKILL.md`, `skills/new-task/SKILL.md`, `skills/memory-backup/backup.sh`, `skills/memory-backup/SKILL.md`, `commands/init.md` (heredoc), `.forge/.gitignore`, `tests/hooks/test-session-start.sh`, `tests/hooks/test-memory-backup.sh` — по `design-integration.md` D2–D4 с поправками стыков.

**Что делаем:** (а) test-session-start: условие гайда — `ls .forge/guide/v*.json`; ожидания «📖 Гайд», «forge:guide», «гайд устарел на 3 задачи»; проверка (6): `rm -rf .forge/guide`, только старый `.forge/status-report.json` → подсказка про «собери гайд»; комментарий строки 3 — «напоминание по гайду». Хук: `report_warn` через `python3 "$plugin_root/skills/project-guide/render.py" summary` при наличии `.forge/guide/v*.json`; хвост: «…Если владелец отвечает на решение из гайда (кодом или словами) — разбери, что он имел в виду, и примени по одному коду: `python3 $plugin_root/skills/project-guide/render.py verdict <КОД> <accepted|changed|discuss|works|agreed|done|up|down|deferred> [текст]`; принятое запиши в .forge/decisions.yml; рендерер сам перерисует guide-latest.html, новую версию не заводит»; `elif [ -f .forge/status-report.json ]` → подсказка про миграцию; строка интро `Phase 5   /forge:guide       — гайд по проекту: суть, решения с кодами, риски, план`. (б) statusline: `guide|"Phase 5"|5) phase_icon="📖 Фаза 5: Гайд по проекту" ;;`. (в) finishing: блок «Гайд по проекту (Фаза 5)» — `render.py merged "<task-slug>"` при наличии `.forge/guide/v*.json`, до backup.sh; фраза владельцу «В гайде «…» отмечено как сделанное». (г) new-task 9.5: «Связь с гайдом по проекту», `skills/project-guide/render.py link`, `<id>` — `f7` или `R7`. (д) backup.sh по стыкам (7 строк heredoc; globs docs/guide только своих файлов; `paths`); memory-backup/SKILL.md:46; init.md heredoc — 7 строк; `.forge/.gitignore` этого репо — `guide/shots/` вместо двух старых. test-memory-backup: проверка (3) ждёт `guide/shots/`; новая (13): `docs/guide/guide-v1.0.html` + `guide-latest.html` уезжают тем же коммитом, посторонние `docs/guide/index.md` и `stray.txt` — нет.

**Как проверим:** до правок — session-start FAIL (1),(3),(6), memory-backup FAIL (3),(13); после — оба `All tests passed`; statusline из tmp с `phase: guide` → «📖 Фаза 5: Гайд по проекту»; `grep -n 'status-report\|FORGE-REPORT\|reports/shots\|verdicts ' forge-plugin/hooks/*.sh forge-plugin/skills/finishing-a-development-branch/SKILL.md forge-plugin/skills/new-task/SKILL.md forge-plugin/skills/memory-backup/* forge-plugin/commands/init.md .forge/.gitignore` → только `elif` про старый файл; `git check-ignore -v .forge/guide/shots/a.png` → совпадение; `git check-ignore .forge/guide/v1.0.json docs/guide/x.html` → пусто.

---

### ✅ Чекпоинт B: живой прогон на этом репо

Скилл — из рабочей копии (`CLAUDE_PLUGIN_ROOT=$PWD/forge-plugin`). (1) «собери гайд» → `bump` создаёт v1.0 с миграцией 21 находки, 6 субагентов, Edit JSON (meta, catalog в index.yml), `render` → `pdf` → открыты; у плагина нет интерфейса и бота → без картинок, и скилл **не спросил** про адрес; (2) владелец отвечает на одно открытое решение как удобно (например «O1 ок» или «O1 — ночью отвечает …») → Клод применяет `verdict`, запись в decisions.yml, 🔥 у него исчез, номер 1.0, PDF пересобран; (3) «собери гайд ещё раз» → v1.1 с блоком «что изменилось с v1.0», v1.0 не тронут, `guide-latest.html` = v1.1; (4) `open docs/guide/guide-v1.1.pdf` — A4, карточки не рвутся; (5) «открой гайд» → без агентов; (6) язык: `grep -Eiow 'ты|тебе|тебя|тобой|твой|твоя|твои|твоё' docs/guide/guide-v1.1.html | wc -l` → 0 (эвристика; допустимы только внутри цитат). Затем `git rm .forge/status-report.json`, `rm -f .forge/status-report.html`.
Что подтверждает владелец: читается как гайд Vespera; ответ сработал; версия выросла; PDF открывается.

Следующее: документация, формат, версия, релиз.

---

## Шаг 9: Документация и меню — status-report → guide везде

**Файлы:** `CLAUDE.md`, `forge-plugin/README.md`, `forge-plugin/COMMANDS.md`, `forge-plugin/commands/init.md`, `forge-plugin/docs/forge-runtime-flow.md`, `GUIDE.md`, `skills/using-forge/SKILL.md`, `skills/project-unblocker/SKILL.md`, `skills/product-mapping/SKILL.md` (одна строка про `/forge:guide`), `evals/criteria/unblocker.yml`, `evals/transition-matrix.tsv` (`to_guide`/`guide`), `evals/criteria/guide.yml` (8 проверок из `design-skill.md` G5 как есть: `phase: guide`, пути под `vX.Y.json`), `forge-tray/forge-tray-mac.py` (VERSION 7.8.0; `forge:guide` / `forge:project-guide`) — old→new по `design-integration.md` D5 с заменами (`current.json` → «последний `.forge/guide/vX.Y.json`», `answer` → `verdict`, `phase: project-guide` → `phase: guide`, «7 субагентов» → 6). Точечно: CLAUDE.md:131 и init.md:592 «отчёт … обновляется сам» → «гайд», runtime-flow:12. Перед каждой правкой сверять строки `sed -n`.

**Как проверим:** свип `grep -rn 'status-report\|status_report\|Что дальше\|FORGE-REPORT\|reports/shots' --exclude-dir=.git . | grep -v '^./.forge/\(plans\|tasks\|reviews\|notes\|sketches\)/\|^./ideas/\|^./.forge/\(decisions\|journal\)\.yml\|Что дальше по проекту\|next: "Что дальше"\|старый отчёт\|LEGACY\|status-report-sample.json\|skills/project-guide/render.py:.*\(unlink\|reports/shots\|LEGACY\|broken\)\|test-project-guide.sh:\|test-session-start.sh:'` → пусто; `grep -c 'forge:guide' CLAUDE.md forge-plugin/README.md forge-plugin/COMMANDS.md forge-plugin/commands/init.md forge-plugin/docs/forge-runtime-flow.md GUIDE.md` → везде ≥1; `python3 -c "import ast;ast.parse(open('forge-tray/forge-tray-mac.py').read())"`; `head -1 forge-plugin/evals/transition-matrix.tsv | grep -c to_guide` → 1; `ruby -ryaml -e 'YAML.load_file("forge-plugin/evals/criteria/guide.yml"); puts "OK"'`; `grep -c 'status-report\|draft.json\|current.json' forge-plugin/evals/criteria/guide.yml` → 0.

## Шаг 10: Формат-документ `docs/project-guide-format.md` — короткая справка

**Файлы:** переписать целиком, ~30–40 строк: (а) что это и для кого (читатель со стороны, на «вы»; эталон — гайд Vespera, копия `.forge/tasks/2026-09-06-project-guide/reference-vespera-guide.html`; канонический CSS живёт в `skills/project-guide/render.py`); (б) данные — `.forge/guide/vX.Y.json`, схема в docstring `render.py` и образец `tests/hooks/fixtures/guide-sample.json`; (в) таблица кодов/статусов/версий строго по стыкам плана; (г) экраны и бюджет (≤6, PNG ≤200 КБ, `.forge/guide/shots/` под игнором); (д) откуда наполнение (картографы, decisions.yml, аналитики, прошлая версия). Без обещаний, которых рендерер не выполняет (уменьшение картинок и т.п.).

**Как проверим:** `grep -n 'Archivo\|IBM Plex\|\.verdict\|Что дальше\|current.json\|1200px' forge-plugin/docs/project-guide-format.md` → пусто; `grep -c 'vX.Y.json\|guide-latest.html\|R<n>\|дефолт' …` → ≥4.

## Шаг 11: Версия 7.8.0 + память проекта

**Файлы:** три манифеста (7.7.0 → 7.8.0; `… → status-report)` → `… → guide)`), `.forge/index.yml` (:3 «5 guide», version, now/session/last_session, catalog `guide:` из стыков, ≤2400 байт), `.forge/map.yml` (skills/project-guide/, docs/guide/, тесты — `files:` пересчитать), `.forge/status.yml`, `.forge/decisions.yml` (запись `project-guide-versions`: текст из `design-integration.md` D8 с правками — «картографы по образцу product-mapping … со своим выходом; `.forge/product-map.json` — подсказка», «ответы владельца читает Клод, рендерер получает `verdict <код> <статус>`», 6 субагентов; запись `status-report-phase-5` помечена `superseded`), `.forge/journal.yml`.

**Как проверим:** `grep -h '"version"' …три манифеста | sort -u` → одна строка 7.8.0; JSON валидны; `wc -c .forge/index.yml` ≤ 2400; `ruby -ryaml …` → YAML OK; `grep -c '^  - id:' .forge/decisions.yml` → 12; `bash forge-plugin/hooks/session-start.sh </dev/null | grep -c 'v7.8.0'` → 1.

## Шаг 12: Полный прогон тестов и свип

**Что делаем:** все `forge-plugin/tests/hooks/test-*.sh`; свип из Шага 9; `git status --short | grep -E '^\?\? (\.playwright-mcp|.*\.png)' || echo clean`; `git check-ignore .forge/guide/v1.0.json docs/guide/guide-v1.0.html docs/guide/guide-v1.0.pdf || echo tracked-ok`; живой прогон триггера `./run-test.sh project-guide prompts/project-guide.txt 3` → PASS и в логе нет `forge:product-mapping`/`forge:project-unblocker`.

**Как проверим:** 6 сьютов — «All tests passed»; свип пуст; `clean`; `tracked-ok`; prompt-тест PASS.

---

### ✅ Чекпоинт C: «мержим» → релиз 7.8.0 → обновление плагина → settings.json

Что показываем: `git status --short` (файлы задачи + память + `docs/guide/`; `settings.json` — в stash) и итог тестов. «Мержим» → finishing Option 1 (коммит, merge в master, index.yml, `render.py merged` через блок finishing, backup.sh → push). Проверка: `gh api repos/anton-ai5010/forge/contents/forge-plugin/.claude-plugin/plugin.json --jq .content | base64 -d | grep version` → 7.8.0; `gh api repos/anton-ai5010/forge/contents/docs/guide --jq '.[].name'` → `guide-v1.0.html …`; у владельца `/plugin marketplace update forge-marketplace` + `/plugin update forge@forge-marketplace`, перезапуск → интро «Forge plugin (v7.8.0)» + строка `Phase 5   /forge:guide` + напоминание про гайд. Затем `git stash pop` и вопрос владельцу одной строкой про `git checkout -- .claude/settings.json`.
Что подтверждает владелец: версия видна, гайд лежит на GitHub, трей показывает «Phase 5 — гайд по проекту».

---

## Критика — что применено

- **Ответы владельца:** вместо разбора живой речи в скрипте (тире обязательно, глагол только в начале, кириллическая «Р» превращалась в «P», ответ на открытый вопрос не закрывал его, «ок» на риск помечал его сделанным) — Клод понимает слова, рендерер получает `verdict <код> <статус> [текст]`; для рисков «ок» = «предложение принято», не «сделано». Непонятный ответ → варианты и рекомендация.
- **Версии:** оборванная сборка не плодит номера (`built_at`), `init` слит в `bump`, битый файл не заводит в тупик (подсказка «почини или верни из git», битый легаси — в `.broken`), PDF пересобирается вместе с HTML после ответов и мержей.
- **Напоминание:** дефолты без 🔥 (в т.ч. P1) не нагоняют «ждут N решений» каждую сессию.
- **Память и git:** backup.sh добавляет только свои файлы в `docs/guide/`, пустая папка не роняет коммит; у пользователей 7.7.0 catalog в index.yml переезжает на гайд.
- **Документ:** «как работать с документом» объясняет 🔥, «дефолт» и куда отвечать; slug задачи не печатается для читателя; «Отложено» не показывает вынесенные в O-вопросы находки; changelog наполняется и без ответов; коды групп — только латинские, не P/O/R.
- **Проще:** 6 субагентов вместо 7, один `bump`, формат-док — короткая справка, evals — 8 проверок как есть, живой Chrome в тестах — только по флагу, лишние поля схемы убраны, имя фазы — `guide` везде.

## Execution Strategy

### Последовательно (в основной сессии)
- Шаг 0 → Шаг 1 → Шаг 2 → Шаг 3 (RED) → Шаг 4 → Шаг 5 (GREEN) → Шаг 6 → **Чекпоинт A**.

### Делегировать субагентам (грязная работа)
- Шаг 4 и Шаг 5 — по одному субагенту (переписать `render.py` по приложению с поправками; вернуть итог теста и `git diff --stat`). Основная сессия прогоняет тест и смотрит расхождения.
- Шаг 7 — skill-creator (сам скилл-процесс) + его trigger-eval.
- Шаг 8 — параллельно два субагента: (а) session-start + statusline + тест session-start; (б) finishing + new-task + backup.sh + memory-backup/SKILL.md + init.md heredoc + тест memory-backup. Разные файлы.
- Шаг 9 — параллельно три субагента по файлам: (а) CLAUDE.md + README + GUIDE + using-forge + unblocker + product-mapping; (б) COMMANDS.md + init.md + runtime-flow; (в) evals + трей. После них — верификатор свипа.
- Шаг 10 — один субагент (короткая справка).
- Чекпоинт B п.(1)–(6) — субагенты внутри скилла; проверки — основная сессия.

### Делать в основной сессии
- Шаги 0, 1, 2, 3, 6, 11, 12; стыковка результатов; чекпоинты; Шаг 7 — вызов skill-creator и приём результата; «мержим» и релиз.

### Чекпоинты
- После Шага 6 — **A** (макет: HTML + PDF, сравнение с Vespera).
- После Шага 8 — **B** (живой прогон на этом репо: v1.0 → ответ → v1.1 → PDF → «открой гайд»).
- После Шага 12 — **C** («мержим» → релиз 7.8.0 → обновление плагина → settings.json).
