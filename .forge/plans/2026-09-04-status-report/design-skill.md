

===== [skill] ШАГ 1: Шаг A1. SKILL.md status-report — шапка, роль, границы, state, Шаг 1 (память) (~12 мин)
ФАЙЛЫ: Создать: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md
--- ЧТО:
Создать файл с текстом (первая часть; последующие шаги A2–A5 дописывают в конец этого же файла):

---
name: status-report
description: "Use when the user wants the project state as a DOCUMENT for the owner — what Claude fixes in code vs what the owner must decide, in what order and why. Phase 5 of the forge pipeline (whole project, not one task). RU: 'собери отчёт', 'отчёт «что дальше»', 'что чинить, что решать', 'покажи документом, где мы', 'что чинишь ты, что решаю я'. EN: 'status report', 'what to fix vs what to decide', 'show where we are as a document'. NOT for 'что дальше по проекту' / 'куда двигать' / 'застрял' — that is project-unblocker; NOT for 'статус проекта' / 'на чём остановились' — that is forge-context. Audits code + .forge memory with 4 parallel agents, stores findings in .forge/status-report.json, renders .forge/status-report.html via render.py, opens it, offers the first 'Код' card to /forge:new-task."
---

# Отчёт «Что дальше» — Phase 5: итог по всему проекту

**Роль:** Принципал-инженер, который на границе этапа садится и честно пишет владельцу-нетехнарю один документ: в каком состоянии проект, что чинишь ты в коде, что решает он, в каком порядке и почему. Ты не навигатор (не выбираешь направление в диалоге) и не загрузчик контекста — ты автор документа на 3–5 минут чтения.

**Ставки:** Владелец не читает код и не помнит прошлые сессии. Этот документ — единственное место, где он видит всё поле разом и свою часть работы отдельно от твоей. Соврёшь в статусе или спрячешь код-задачу в «решение» — он примет неверное решение или будет ждать тебя там, где ждать нечего.

**Announce at start:** «Собираю отчёт „Что дальше“ — прогоню аудит проекта и соберу документ.» (action-first, без имени скилла)

**Вход:** память `.forge/` + свежий аудит кода 4 агентами + (если есть) прошлый `.forge/status-report.json`.
**Выход:** `.forge/status-report.json` (данные — память проекта, уезжает в git через memory-backup) → `.forge/status-report.html` (собирает `render.py`, ты HTML не пишешь) → открыт в браузере → первая карточка «Код» предложена в `/forge:new-task`.

## Границы (чтобы не перехватывать чужое)

| Слова владельца | Чей это скилл |
|---|---|
| «что дальше по проекту», «куда двигать», «застрял», «с чего начать» | project-unblocker (разговор + выбор направления) |
| «статус проекта», «на чём остановились», «продолжаем» | forge-context (загрузка памяти в начале сессии) |
| «карта проекта», «из чего состоит» | product-mapping |
| «собери отчёт», «что чинить, что решать», «покажи документом, где мы» | **этот скилл** |

Обновление после мержа — не здесь: finishing-a-development-branch сам зовёт `render.py merged <slug>` (карточка задачи → сделано, счётчик устаревания +1, HTML пересобран).

## Process state (для statusline)

В самом начале запиши состояние в `.forge/state.yml` через Bash:

```bash
mkdir -p .forge && cat > .forge/state.yml <<EOF
phase: status-report
task: отчёт «что дальше»
started_at: $(date -Iseconds)
EOF
```

Когда карточка «Код» уйдёт в `/forge:new-task` — тот скилл перезапишет state.yml сам.

## Шаг 1: Память .forge (топливо — читаешь сам, молча)

L0 (`index.yml`) уже в промпте: `project`, `goal`, `stage`, `now.task`. Дальше — только эти файлы, каждый с конкретной целью:

| Файл | Что берёшь |
|---|---|
| `.forge/status-report.json` (если есть) | Прошлые находки: `status: done` и `deferred` сохраняются как есть; `open` — список «проверить, актуально ли» для агентов |
| `.forge/status.yml` | `broken` / `blocked` → кандидаты в блок crit; `working` — чтобы не «находить» то, что работает |
| `.forge/direction.yml` | `directions` / `backlog` → кандидаты в imp / deferred; `map[].status: risk|unknown` → кандидаты в crit |
| `.forge/decisions.yml` | Чего НЕ предлагать: решение уже принято — не заводи «Решение» повторно |
| `.forge/dead-ends.yml` | Чего НЕ предлагать как «Код»: уже пробовали, не сработало |
| `.forge/journal.yml` (последние 5 записей) | `next` → что считалось следующим |
| `.forge/tasks/*.md` + `.forge/plans/*.md` | Открытые задачи (есть task, нет мержа) и секции «Открытые вопросы» планов → кандидаты в `owner: decision` |
| `.forge/infrastructure.yml`, `README.md` | Адреса интерфейса (для Шага 5), где что крутится |

Нет `.forge/` вообще → одна строка в чат: «Проект без памяти — соберу по коду, точность ниже», дальше без вопросов.

--- ПРОВЕРКА:
cd /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report && head -2 SKILL.md | tail -1 → `name: status-report`; python3 -c "s=open('SKILL.md').read().split('---')[1].strip();print(len(s))" → число ≤ 1024 (ожидаем ~832); grep -c 'phase: status-report' SKILL.md → 1


===== [skill] ШАГ 2: Шаг A2. SKILL.md — Шаг 2: 4 аналитика параллельно (промпты + формат возврата) (~15 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md — дописать в конец
--- ЧТО:
Дописать в конец файла:

## Шаг 2: Аудит — 4 аналитика параллельно

**В одном сообщении** запусти 4 субагента через Agent tool (как в critique). Ждёшь все четыре. Каждому — общий преамбул + свой промпт. Агенты ничего не правят.

### Общий преамбул (вставь в каждый промпт)

```
Ты аналитик проекта «{project из index.yml}». Цель проекта: «{goal}». Стадия: {stage}.
Правила:
- НИЧЕГО не правь. Только читай, запускай read-only команды (grep, git log, ls, cat, тесты) и проверяй.
- Каждую находку подтверждай: путь:строка или вывод команды. Нет доказательства — не находка.
- Пиши по-русски, без жаргона: в поле why — что ломается в жизни у клиента/владельца, не «нет обработки edge case».
- Не оценивай «страшно ли» — оценивай, мешает ли это проекту выполнять главную функцию из цели.
- Прошлые открытые находки — проверь каждую (актуально / закрыто чем / не проверить):
{список open-находок из .forge/status-report.json: id — title — source; или «нет»}

Верни СТРОГО в этом формате:

## Находки
- title: <суть по-человечески, до 80 символов>
  owner: code | decision | both   (decision — только если нужен выбор владельца: деньги, люди, легал, что должен делать продукт)
  effort: S | M | L | -           (S — один файл/одна сессия; M — несколько файлов, 1–2 сессии; L — новая подсистема; «-» для чистых решений)
  block: crit | biz | imp | pol   (crit — без этого не работает главная функция; biz — ждёт решения владельца; imp — усиливает; pol — косметика/потом)
  what: <что сделать или что решить, 1–2 предложения, конкретная механика>
  why: <что ломается без этого — последствия для клиента/бизнеса>
  source: <путь:строка | команда>
  evidence: <цитата строки или вывод команды, 1 строка>
  confidence: <0–100>

## Проверка прошлых находок
- <id>: актуально | закрыто — <чем доказано> | не проверить
```

### Агент 1 — Код: заглушки и дыры

```
{преамбул}
Твоя область — сам код. Найди то, что мешает проекту работать или обманывает владельца, будто «уже сделано»:
1. grep -rn "TODO\|FIXME\|XXX\|HACK\|NotImplemented\|заглушка\|stub\|mock" . --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=venv --exclude-dir=dist
2. Функции/обработчики, которые возвращают фиктивные данные или пустой результат (return [] / return None / pass) на ключевых путях цели.
3. Ключевые пути цели (по goal): есть ли обработка ошибок там, где падение = тихий провал для клиента (сеть, оплата, отправка сообщений, запись в базу).
4. Захардкоженные значения, которые должны быть настройкой (ключи, адреса, лимиты, тексты «тест»).
5. Мёртвый код: файлы/функции, на которые никто не ссылается (grep по имени).
Не больше 12 находок, самые важные первыми.
```

### Агент 2 — Git: что живо, что брошено

```
{преамбул}
Твоя область — история и текущее состояние репозитория:
1. git log --oneline -30; git log --since="60 days ago" --name-only --pretty=format: | sort | uniq -c | sort -rn | head -20 — что менялось, что давно не трогали.
2. git status --short — незакоммиченное; git branch --no-merged — незавершённые ветки.
3. Модули, критичные для цели, которые не менялись дольше всех при том, что вокруг всё менялось (признак брошенной части).
4. Коммиты со словами «временно», «хак», «потом», «wip», «fix fix» — незакрытые хвосты.
5. Есть теги/версии — совпадает ли версия в манифесте/README с последним тегом.
Не больше 10 находок.
```

### Агент 3 — Инфраструктура: запускается ли и где живёт

```
{преамбул}
Твоя область — то, на чём проект стоит:
1. Тесты: найди раннер (pytest / npm test / go test / bash tests/*.sh). Если прогон явно короче 2 минут — запусти и приложи итоговую строку. Падают — находка crit с выводом.
2. Docker / compose / CI (.github/workflows, .gitlab-ci) — есть ли, есть ли health-check.
3. .env.example против реального чтения переменных в коде (grep os.environ / process.env / getenv): чего не хватает в примере, что читается, но нигде не описано.
4. Скрипты запуска/деплоя: можно ли поднять проект одной командой; описано ли в README.
5. Внешние сервисы (API, базы, боты) по коду и .forge/infrastructure.yml — что должно быть живым для главной функции, есть ли проверка «сервис недоступен».
Отдельно верни секцию:

## Адреса интерфейса
- <url> — <откуда: infrastructure.yml:строка | README:строка | docker-compose ports | .env PORT | package.json scripts>
(только http/https; ничего не запускай ради этого; нет адресов — «нет»)
Не больше 10 находок.
```

### Агент 4 — Память и документация: где враньё и где ждут решения

```
{преамбул}
Твоя область — совпадает ли написанное с тем, что есть:
1. README / CLAUDE.md против кода: обещанное, но не реализованное; команды, которых нет; устаревшие инструкции.
2. .forge/status.yml: каждой строке working — есть ли доказательство в коде/тестах; broken/blocked — ещё актуально?
3. .forge/decisions.yml против кода: решения, которые код нарушает.
4. .forge/tasks/*.md без влитого результата (slug не встречается в git log) — открытые задачи; секции «## Открытые вопросы» в .forge/plans/*.md — вопросы, ждущие владельца (owner: decision, block: biz, effort: -).
5. .forge/direction.yml: backlog и map[].status risk/unknown — что из отложенного стало срочным.
Не больше 12 находок; вопросы владельцу — отдельными находками с owner: decision.
```

--- ПРОВЕРКА:
grep -c '^### Агент' /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md → 4; grep -c '## Адреса интерфейса' SKILL.md → 1


===== [skill] ШАГ 3: Шаг A3. SKILL.md — Шаг 3 (синтез) + Шаг 4 (запись JSON, схема id) (~15 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md — дописать в конец
--- ЧТО:
Дописать в конец файла:

## Шаг 3: Синтез (в основной сессии, молча)

1. **Фильтр:** `confidence < 70` — отбрось. Находка без `source`/`evidence` — отбрось.
2. **Прошлые находки:** `done` / `deferred` из старого JSON переносишь без изменений. `open`, которую агент отметил «закрыто — чем доказано», → `status: done`, `source` дополни доказательством. «Не проверить» → остаётся `open`. Новая находка про то же место (тот же файл / та же суть), что и старая `open`, — это та же находка: сохрани старый `id`, обнови `what`/`why`/`source`.
3. **Дедуп:** две находки об одном (тот же файл, та же суть) → одна, confidence = max, `source` — оба через «; ».
4. **Правило честности владельца.** `owner: decision` ставь ТОЛЬКО если без ответа владельца ты не можешь двигаться, а ответ — про деньги, людей, легал или про то, что продукт должен делать для клиента. «Каким способом сделать» — это код, не решение: ставь `owner: code`, свой дефолт пиши в `what` («сделаю X, скажи, если не так»). `both` — когда есть и вопрос владельцу, и код после ответа. Проверка: у каждой карточки `decision`/`both` в `what` есть вопрос, на который может ответить только он. Нет вопроса → это `code`.
5. **Блок и порядок — по боли.** `crit` — без этого проект не выполняет главную функцию из `goal` (и `owner: code`); `biz` — `owner: decision|both`; `imp` — усиливает, но без этого работает; `pol` — косметика и «потом». Внутри блока первым идёт то, что сильнее мешает главной функции, — не то, что заметнее. Лимиты: crit ≤ 6, biz ≤ 6, imp ≤ 8; всё сверх лимита и всё `pol` → `status: deferred` (рендерер сосчитает их в футер). Не выкидывай — переводи в deferred.
6. **Вердикт — один.** Самая опасная дыра (обычно первая карточка crit; не запускается проект — это она). 3–4 предложения простым языком, ключевое жирным через `<b>…</b>`, последняя фраза — откуда начинать: «…начинать надо отсюда».
7. **Текст карточек:** от первого лица, на «ты» («чиню я», «решаешь ты»). `what` — механика: что именно появится/изменится. `why` — что ломается в жизни: «клиент жмёт „оплатить“ и молча ждёт — тихий слив», не «нет обработки таймаута». Термин только с переводом в скобках. `title` — суть по-человечески, без имён функций и путей.
8. **Шапка:** `title` — «{Проект}: {вопрос документа}» (напр. «Vespera: что доделать, прежде чем наводить красоту»); `eyebrow` — позиция в процессе («Дорожная карта · {стадия простыми словами}»); `lead` — 2–3 предложения: откуда данные («четыре аналитика прошли по коду, истории и памяти проекта и нашли N пробелов»), что сделано («свёл в приоритеты»), ось жирным (`<b>что чиню я в коде</b>` и `<b>что решаешь ты</b>`), принцип порядка; `next_after` — что после этого документа.

## Шаг 4: Запись данных

Файл `.forge/status-report.json` — память проекта (в git уезжает через memory-backup). Пиши целиком через Write:

```json
{
  "project": "vespera",
  "date": "2026-09-04",
  "eyebrow": "Дорожная карта · перед визуальным полишем",
  "title": "Vespera: что доделать, прежде чем наводить красоту",
  "lead": "Четыре аналитика прошли по коду, истории и памяти проекта и нашли 23 пробела. Свёл в приоритеты: <b>что чиню я в коде</b> и <b>что решаешь ты</b>. Порядок — по тому, что мешает сервису работать, а не по тому, что заметнее.",
  "next_after": "Полиш интерфейса — после этого",
  "verdict": "Партнёр не может вернуть задачу в пул: <b>клиент молча висит</b>, а ты об этом не узнаёшь. Это перевешивает любой полиш — начинать надо отсюда.",
  "stale_merges": 0,
  "findings": [
    {
      "id": "f-20260904-01",
      "title": "Партнёр может вернуть задачу в пул",
      "owner": "code",
      "effort": "M",
      "block": "crit",
      "status": "open",
      "what": "Добавлю кнопку «вернуть» и уведомление следующему партнёру.",
      "why": "Сейчас задача, от которой отказались, висит навсегда — клиент ждёт и уходит.",
      "source": "src/tasks/service.py:88; агент 1",
      "task_slug": null,
      "screenshot": null,
      "date": "2026-09-04"
    }
  ]
}
```

Правила:
- `id` — `f-<YYYYMMDD>-<NN>`: дата этой сборки, номер по порядку с `01`; если в JSON уже есть id с той же датой — продолжай с максимального +1. Раз выданный id не меняется и не переиспользуется — по нему связаны задача (`task_slug`), снимок (`.forge/reports/shots/<id>.png`) и `render.py link/merged`.
- Обязательные поля находки: `id, title, owner, effort, block, status, what, why, source, date`. `task_slug` и `screenshot` — `null`, пока нет.
- `stale_merges` при полной сборке — `0` (после мержей его крутит `render.py merged`).
- Счётчики (N находок → M блоков, K отложено, «чиню я / решаешь ты») НЕ пишешь — их считает рендерер.
- В `.forge` — никаких секретов (правило memory-backup): адреса, ключи, пароли в `what`/`source` не попадают.
- Проверка сразу: `python3 -c "import json;d=json.load(open('.forge/status-report.json'));print(len(d['findings']))"` — печатает число находок. Ошибка → чинишь JSON, не HTML.

--- ПРОВЕРКА:
grep -c 'f-<YYYYMMDD>-<NN>' /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md → 1; sed -n '/^```json/,/^```$/p' SKILL.md | sed '1d;$d' | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['findings'][0]['id'])" → f-20260904-01


===== [skill] ШАГ 4: Шаг A4. SKILL.md — Шаг 5: снимки экрана (живой адрес, Playwright MCP, уборка мусора) (~10 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md — дописать в конец
--- ЧТО:
Дописать в конец файла:

## Шаг 5: Снимки экрана (по возможности, без вопросов владельцу)

**Есть ли что снимать** — решаешь сам, владельца не спрашиваешь:
1. Кандидаты (в этом порядке): секция «Адреса интерфейса» агента 3 → `.forge/infrastructure.yml` (`url`, `base_url`, `proxy_pass`, `host`+`port`) → `README.md` (`http://localhost:NNNN`, свой домен) → `docker-compose.yml` `ports:` → `.env` / `.env.example` `PORT=` → стандартные `http://localhost:` 3000, 5173, 8000, 8080, 5000, 4200, 8501.
2. Живой — тот, где `curl -s -o /dev/null -m 3 -w '%{http_code}' <url>` даёт 2xx/3xx. Берёшь первый живой. Только http/https — `file:` в браузере заблокирован.
3. Живого нет → шаг пропущен целиком; в чат одна строка «интерфейс не запущен — отчёт без снимков». Приложение сам НЕ запускаешь.

**Что снимать:** только карточки, где `what`/`why` про экран, который владелец видит глазами (форма, кнопка, страница). Не больше 6, в порядке блоков (crit → biz → imp).

**Как снимать (Playwright MCP, инструменты `browser_*`):** один раз `browser_resize` `{width: 1280, height: 800}`; для каждой карточки:
1. `browser_navigate` `{url: <адрес страницы карточки, если знаешь; иначе корень>}`
2. `browser_take_screenshot` `{type: "png", filename: "sr-<id>.png", scale: "css"}` — не `fullPage` («читается за 3–5 минут»)
3. Перенос из папки MCP (файл падает либо в корень проекта, либо в `.playwright-mcp/`):
```bash
mkdir -p .forge/reports/shots
mv ./sr-<id>.png .forge/reports/shots/<id>.png 2>/dev/null || mv .playwright-mcp/sr-<id>.png .forge/reports/shots/<id>.png
```
4. В JSON у находки: `"screenshot": ".forge/reports/shots/<id>.png"` (только путь — рендерер сам встроит картинку как data: URI; нет файла — карточка без картинки).

После всех снимков — `browser_close`, затем уборка мусора, обязательно, даже если ни один снимок не удался:
```bash
rm -rf .playwright-mcp; rm -f ./sr-*.png ./page-*.png
```

**Любой сбой** (нет Playwright MCP, отказ в разрешении, таймаут, пустой файл) → одна строка в чат, карточка остаётся без картинки, остальные пробуешь дальше. Не больше одной повторной попытки на карточку. Отчёт всегда собирается — с картинками или без.

--- ПРОВЕРКА:
grep -c 'rm -rf .playwright-mcp' /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md → 1; grep -c 'Не больше 6' SKILL.md → 1; grep -n 'scale: "css"' SKILL.md → одна строка


===== [skill] ШАГ 5: Шаг A5. SKILL.md — Шаги 6–8 (рендер+open, отчёт в чат, хэндофф), правила языка, антипаттерны (~12 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md — дописать в конец
--- ЧТО:
Дописать в конец файла:

## Шаг 6: Собрать HTML и открыть

```bash
python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" render
xdg-open .forge/status-report.html 2>/dev/null || open .forge/status-report.html 2>/dev/null
```

Рендерер читает `.forge/status-report.json`, встраивает снимки, считает счётчики, пишет `.forge/status-report.html` (один живой файл, перезаписывается, в `.forge/.gitignore`) и печатает строку счётчиков. Упал — читай его ошибку: почти всегда поле JSON. HTML руками не правишь никогда.

## Шаг 7: Отчёт в чат (3–5 строк)

```
Отчёт «Что дальше» готов: .forge/status-report.html — открыл в браузере.
Главное: {вердикт одной фразой}.
{N} находок → {M} блока: чиню я — {a}, решаешь ты — {b}, отложено — {k}. Снимков экрана: {s}.
Первым в код предлагаю: «{title первой карточки crit}». Скажи «бери» — оформлю задачу. Решения разберём, когда скажешь «давай решения».
```

Числа бери из строки, которую напечатал `render.py render`, — не считай руками. **ЗАВЕРШИ ХОД** — дождись реакции (как навигатор перед new-task).

## Шаг 8: Хэндофф

| Владелец говорит | Делаешь |
|---|---|
| «бери» / «давай» / «ок» / «первую» | **Инвокни new-task skill** с текстом `card:<id> <title карточки>` + одной строкой `what` и `why` как контекст. Метка `card:<id>` — служебная: new-task после сохранения task-файла свяжет карточку с задачей (`render.py link <id> <slug>`). Только ОДНА карточка за раз. |
| «вторую» / «не эту, а …» | То же с названной карточкой. |
| «давай решения» | Блок biz, по одной карточке за ход: вопрос из `what` + 2–3 варианта + твоя рекомендация (как навигатор: «не знаю» = твой вариант). Ответ → запись в `.forge/decisions.yml` по правилам session-awareness, у карточки в JSON `"status": "done"`, затем `render.py render` (без нового аудита). Следующая — только после ответа. |
| «стоп» / молчит / другая тема | Ничего не двигаешь. Отчёт лежит в `.forge`; при старте следующей сессии хук напомнит одной строкой («ждут N решений, отчёт устарел на M задач»). |

Решения НЕ спрашивай по одному, пока не прозвучало «давай решения». Карточку в работу сам НЕ берёшь.

## Правила языка (как в формате-эталоне)

- От первого лица, на «ты»: «чиню я», «решаешь ты». Не «рекомендуется», не «необходимо».
- Последствия вместо терминов. Стоп-слова без перевода: эндпоинт, миграция, деплой, коммит, мерж, рефакторинг, таймаут, хэндлер, middleware, edge case, регрессия. Нужен термин — переводи в скобках: «вебхук (сообщение, которое банк шлёт нам после оплаты)».
- `title` — то, что владелец увидит или получит, не то, что ты сделаешь в коде.
- Честно: «не реализовано», а не «в процессе»; «не проверял», а не «должно работать».
- Проверка перед записью: прочитал бы это человек с улицы и понял, что сломано и кто это чинит?

## Антипаттерны

НИКОГДА: писать HTML руками · спрашивать владельца во время сборки (есть ли интерфейс, какой адрес, что важнее) · прятать код-задачу в «Решение» · «Решение» без вопроса, на который отвечает только владелец · больше 6 снимков · запускать приложение владельца ради снимка · ронять отчёт из-за снимка · оставлять `.playwright-mcp/` или PNG в корне проекта · менять `done`/`deferred` прошлых находок молча · считать счётчики руками · спрашивать решения по одному без «давай решения» · брать карточку в работу без слова владельца · откликаться на «что дальше по проекту» / «статус проекта» (это unblocker / forge-context) · жаргон без перевода.

ВСЕГДА: 4 агента параллельно в одном сообщении · каждая находка с `source` · owner по правилу честности · порядок по боли · один вердикт наверху · лимиты блоков, лишнее в deferred · JSON → `render.py render` → open · 3–5 строк в чат · заверши ход и жди слова владельца.

--- ПРОВЕРКА:
grep -c 'render.py" render' /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/SKILL.md → 1; grep -c '^## Шаг' SKILL.md → 8; grep -c 'card:<id>' SKILL.md → ≥ 2; grep -n '^## Антипаттерны' SKILL.md → одна строка


===== [skill] ШАГ 6: Шаг B. Команда /forge:status-report (~3 мин)
ФАЙЛЫ: Создать: /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/status-report.md
--- ЧТО:
Создать файл по образцу commands/unblocker.md:

---
description: "Отчёт «Что дальше» (Phase 5). Аудит проекта 4 параллельными агентами + память .forge → один HTML-документ для владельца: что чинит Клод в коде, какие решения нужны от тебя, в каком порядке и почему. Данные — .forge/status-report.json, страницу собирает render.py, открывается в браузере. После мержей обновляется сам."
disable-model-invocation: true
---

Invoke the forge:status-report skill and follow it exactly as presented to you

--- ПРОВЕРКА:
cat /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/status-report.md | tail -1 → `Invoke the forge:status-report skill and follow it exactly as presented to you`; grep -c 'disable-model-invocation: true' commands/status-report.md → 1


===== [skill] ШАГ 7: Шаг C. new-task: шаг 9.5 — связь карточки отчёта с задачей (render.py link) (~5 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/new-task/SKILL.md — вставить после строки 104 (шаг 9 «Сохрани»)
--- ЧТО:
Проверить точную строку: `sed -n '104p' forge-plugin/skills/new-task/SKILL.md` начинается с `9. **Сохрани** в `.forge/tasks/YYYY-MM-DD-<slug>.md`.`. После неё (перед `10. **GitHub-sync`) вставить абзац:

9.5. **Связь с отчётом «Что дальше»** — только если сырой промпт начинался со служебной метки `card:<id>` (так карточку «Код» передаёт `/forge:status-report`): после сохранения task-файла привяжи карточку к задаче:
   ```bash
   python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" link <card-id> <slug>
   ```
   Метку `card:<id>` в текст задачи и в slug не переноси — это служебное. Промпта без метки или файла `.forge/status-report.json` нет → шаг молча пропусти. (Дальше, когда задачу вольют, finishing сам отметит карточку сделанной по этому slug.)

--- ПРОВЕРКА:
grep -n 'render.py" link' /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/new-task/SKILL.md → одна строка между строками с `9. **Сохрани**` и `10. **GitHub-sync`; sed -n '104,112p' показывает порядок 9 → 9.5 → 10


===== [skill] ШАГ 8: Шаг D. Тесты триггеров: наивный промпт + защита от перехвата «что дальше по проекту» (~8 мин)
ФАЙЛЫ: Создать: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/skill-triggering/prompts/status-report.txt; Создать: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/skill-triggering/prompts/project-unblocker.txt; Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/skill-triggering/run-all.sh — SKILLS=(…) строки 10-19
--- ЧТО:
1) prompts/status-report.txt (наивно, без имени скилла и без слов «что дальше по проекту» / «статус проекта»):

Собери мне отчёт по проекту одним документом: что ты чинишь в коде, что должен решить я, и в каком порядке. Хочу открыть и почитать, где мы.

2) prompts/project-unblocker.txt (негативная защита — эти слова должны уходить навигатору, не отчёту):

Что дальше по проекту? Куда двигать, с чего начать — я подзастрял.

3) run-all.sh: после строки 18 `    "requesting-code-review"` (перед `)` на строке 19) добавить две строки:
    "project-unblocker"
    "status-report"

--- ПРОВЕРКА:
sed -n '10,21p' forge-plugin/tests/skill-triggering/run-all.sh → в массиве SKILLS есть "project-unblocker" и "status-report"; bash -n run-all.sh → без ошибок. Живой прогон (нужен `claude` CLI, ~2 мин): cd forge-plugin/tests/skill-triggering && ./run-test.sh status-report prompts/status-report.txt 3 → `✅ PASS: Skill 'status-report' was triggered`; ./run-test.sh project-unblocker prompts/project-unblocker.txt 3 → `✅ PASS` и grep -c '"skill":"forge:status-report"' /tmp/forge-tests/*/skill-triggering/project-unblocker/claude-output.json → 0


===== [skill] ШАГ 9: Шаг E. Evals: criteria/status-report.yml + правка unblocker.yml:16 + transition-matrix.tsv (~8 мин)
ФАЙЛЫ: Создать: /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/criteria/status-report.yml; Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/criteria/unblocker.yml — строка 16; Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/transition-matrix.tsv — целиком
--- ЧТО:
1) criteria/status-report.yml:

phase: status-report
checks:
  - id: audit_parallel_with_evidence
    question: "Аудит прогнан 4 параллельными субагентами (код, git, инфраструктура, память .forge), и у каждой находки есть source (путь:строка или команда)?"
    type: binary

  - id: owner_axis_honest
    question: "Каждая карточка помечена владельцем (Код / Решение / Решение+код), и в «Решение» попали только вопросы, требующие выбора владельца (деньги, люди, легал, продукт) — код-задачи не спрятаны в «решения»?"
    type: binary

  - id: verdict_and_pain_order
    question: "Наверху один вердикт «Главное одной фразой» с «откуда начинать», блоки упорядочены по тому, что мешает главной функции, а не по заметности?"
    type: binary

  - id: html_from_data_not_by_hand
    question: "HTML не написан Клодом руками: находки записаны в .forge/status-report.json, страница собрана render.py, счётчики футера посчитаны рендерером?"
    type: binary

  - id: screenshots_graceful_and_clean
    question: "Если интерфейс не запущен или снимок не удался — отчёт собран без картинок, без ошибок и без вопросов владельцу; .playwright-mcp/ и PNG в корне проекта не остались?"
    type: binary

  - id: handoff_only_by_owner_word
    question: "Клод предложил первую карточку «Код», но в /new-task ушёл только по слову владельца; решения не спрашивал по одному без «давай решения»?"
    type: binary

2) unblocker.yml строка 16 — old:
    question: "Обновлены .forge/direction.yml и ROADMAP.md?"
new:
    question: "Обновлён .forge/direction.yml (ROADMAP.md не пишется — витрина для глаз теперь отчёт «Что дальше», /forge:status-report)?"

3) transition-matrix.tsv — новый столбец `to_status-report` перед `to_END` и новая строка `status-report` (разделитель — табуляция):

from_phase	to_unblocker	to_new-task	to_refine-idea	to_plan	to_critique	to_execute	to_status-report	to_END
unblocker	-	0	0	0	0	0	0	0
new-task	0	-	0	0	0	0	0	0
refine-idea	0	0	-	0	0	0	0	0
plan	0	0	0	-	0	0	0	0
critique	0	0	0	0	-	0	0	0
execute	0	0	0	0	0	-	0	0
status-report	0	0	0	0	0	0	-	0

--- ПРОВЕРКА:
python3 -c "import yaml" недоступен (нет PyYAML) — проверяем grep: grep -c 'type: binary' forge-plugin/evals/criteria/status-report.yml → 6; grep -c 'ROADMAP' forge-plugin/evals/criteria/unblocker.yml → 1 (только в скобках «не пишется»); awk -F'\t' '{print NF}' forge-plugin/evals/transition-matrix.tsv | sort -u → 9; wc -l transition-matrix.tsv → 8


===== [skill] ШАГ 10: Шаг F. Навигатор project-unblocker: убрать ROADMAP.md, отослать к отчёту (~10 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/project-unblocker/SKILL.md — строки 207, 209, 217, 245, 246, 249, 256, 260
--- ЧТО:
Перед правкой сверить строки: `sed -n '207p;209p;217p;245p;246p;249p;256p;260p' forge-plugin/skills/project-unblocker/SKILL.md`. Правки old → new:

1) строка 207, фрагмент `Карту и направления (direction.yml, ROADMAP.md) можно записать и раньше` → `Карту и направления (direction.yml) можно записать и раньше`

2) строка 209 `Два слоя памяти:` → `Память навигатора:`

3) строка 217 целиком:
old: `**`ROADMAP.md`** (корень, для глаз Антона) — сохрани сюда **всю карту проекта** из Фазы 2 (части по шагам со значками) + список направлений + банк отложенного. Это его главный экран «где мы по всему проекту»: между сессиями статусы меняются (❓→✅), дыры закрываются. Простым языком.`
new: `**Витрина для глаз — отчёт «Что дальше» (`/forge:status-report`).** Навигатор `ROADMAP.md` не пишет: два документа «где мы» для одного человека — путаница. Хочет увидеть картину документом (что чинит Клод, что решает он, в каком порядке) — отсылай к отчёту; карта проекта из Фазы 2 живёт в чате и в `direction.yml`.`

4) строка 245 `Если есть `direction.yml` и/или `ROADMAP.md`:` → `Если есть `direction.yml`:`

5) строка 246 `1. Прочитай оба.` → `1. Прочитай его (и `.forge/status-report.json`, если есть — там статусы находок open/done).`

6) строка 249 `4. Сделанное → в ROADMAP «Выполнено» с датой, убрать из `directions`.` → `4. Сделанное → убрать из `directions` (дата и что сделано — строкой в `journal.yml`).`

7) строка 256, фрагмент `Исполнение — дальше по пайплайну (new-task → plan → critique → execute).` → `Исполнение — дальше по пайплайну (new-task → plan → critique → execute); итог по всему проекту документом — /forge:status-report (Phase 5).`

8) строка 260 (НИКОГДА), после `· технический жаргон без пояснения.` в конце добавить ` · писать ROADMAP.md (витрина для глаз — отчёт «Что дальше»).`
--- ПРОВЕРКА:
grep -n 'ROADMAP' forge-plugin/skills/project-unblocker/SKILL.md → ровно 2 строки, обе со словами «не пишет»/«писать ROADMAP.md» (217 и 260); grep -c 'status-report' forge-plugin/skills/project-unblocker/SKILL.md → 3


===== [skill] ШАГ 11: Шаг G. using-forge: строка status-report в таблице скиллов (~3 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/using-forge/SKILL.md — после строки 137
--- ЧТО:
Сверить: `sed -n '137p'` → `| forge:project-unblocker | Phase 0 — навигатор направления |`. Сразу после неё вставить строку:

| forge:status-report | Phase 5 — отчёт «Что дальше»: что чинит Клод, что решает владелец (HTML из .forge/status-report.json) |

--- ПРОВЕРКА:
grep -n 'forge:status-report' forge-plugin/skills/using-forge/SKILL.md → строка 138; sed -n '137,139p' показывает project-unblocker → status-report → forge-context


===== [skill] ШАГ 12: Шаг H. ROADMAP.md → отчёт в доках (CLAUDE.md, COMMANDS.md, GUIDE.md, runtime-flow) (~8 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/CLAUDE.md — строки 90, 92; Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/COMMANDS.md — строка 399; Изменить: /Users/mac/Projects/Plugin/plugin/GUIDE.md — строка 431 (хвост); Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/docs/forge-runtime-flow.md — строки 163, 203
--- ЧТО:
(Пересекается с куском «Фаза 5 в доках» — согласовать, кто правит; здесь только замена ROADMAP.md.) Сверить строки `grep -rn ROADMAP CLAUDE.md GUIDE.md forge-plugin/COMMANDS.md forge-plugin/docs/forge-runtime-flow.md`. Правки old → new:

1) CLAUDE.md:90
old: `**Память (петля):** пишет `.forge/direction.yml` (для Клода: directions/backlog/goal_shift) + `ROADMAP.md` (для глаз — все направления человекочитаемо). Цикл: разговор → память → навигатор → задачи → результаты → снова память.`
new: `**Память (петля):** пишет `.forge/direction.yml` (для Клода: directions/backlog/goal_shift); витрина для глаз — отчёт «Что дальше» (`/forge:status-report`), `ROADMAP.md` не заводится. Цикл: разговор → память → навигатор → задачи → результаты → снова память.`

2) CLAUDE.md:92
old: `**Выход:** обновлённые `direction.yml` + `ROADMAP.md`, первый физический шаг подан в `/forge:new-task`.`
new: `**Выход:** обновлённый `direction.yml`, первый физический шаг подан в `/forge:new-task`.`

3) COMMANDS.md:399
old: `**Результат:** обновлённые `.forge/direction.yml` (память для Клода) + `ROADMAP.md` (человекочитаемо) + карта проекта`
new: `**Результат:** обновлённый `.forge/direction.yml` (память для Клода) + карта проекта в чате; витрина для глаз — отчёт «Что дальше» (`/forge:status-report`)`

4) GUIDE.md:431, хвост абзаца
old: `Память петлёй: `.forge/direction.yml` (для Клода) + `ROADMAP.md` (для глаз).`
new: `Память петлёй: `.forge/direction.yml` (для Клода); витрина для глаз — отчёт «Что дальше» (`/forge:status-report`).`

5) forge-runtime-flow.md:163
old: `| 0. Direction | `/forge:unblocker` | `direction.yml` + `ROADMAP.md`, первый шаг → new-task | Пользователь выбрал направление |`
new: `| 0. Direction | `/forge:unblocker` | `direction.yml`, первый шаг → new-task | Пользователь выбрал направление |`

6) forge-runtime-flow.md:203
old: `        SW2["unblocker → .forge/direction.yml + ROADMAP.md"]`
new: `        SW2["unblocker → .forge/direction.yml<br/>status-report → .forge/status-report.json (+ .html)"]`
--- ПРОВЕРКА:
grep -rn 'ROADMAP' CLAUDE.md GUIDE.md forge-plugin/ --include='*.md' --include='*.yml' --include='*.sh' | grep -v 'не заводится\|не пишет\|писать ROADMAP.md\|не пишется' → пусто (исторические .forge/plans/*.md не трогаем)


===== INTERFACES:
Контракты на стыке с другими кусками плана (рендерер / хуки / finishing / версия — не в этом куске):

1. render.py CLI (скилл вызывает так, рендерер должен это поддерживать):
   - `python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" render` — cwd = корень проекта; читает `.forge/status-report.json`, пишет `.forge/status-report.html`, встраивает `findings[].screenshot` как data: URI если файл есть (нет — карточка без картинки), считает счётчики; печатает в stdout одну строку счётчиков, из которой скилл берёт числа для чата (предложение формата: `findings=N blocks=M code=a decision=b deferred=k shots=s`); плохой JSON → exit 1 + понятное сообщение с именем поля.
   - `render.py link <card-id> <slug>` — ставит `task_slug` у находки; зовёт new-task (шаг 9.5) при промпте с меткой `card:<id>`.
   - `render.py merged <slug>` — находка с этим `task_slug` → `status: done`, `stale_merges += 1`, HTML пересобран; зовёт finishing-a-development-branch (Option 1, после успешного мержа). В скилле status-report только упоминается.
   - Открытие: скилл сам делает `xdg-open .forge/status-report.html || open ...` после render.

2. Схема `.forge/status-report.json` (пишет скилл целиком через Write, read-модифицируют render.py link/merged, session-start.sh читает через python3 json):
   верхний уровень: `project, date (YYYY-MM-DD), eyebrow, title, lead (допускает <b>), next_after, verdict (допускает <b>), stale_merges (int, 0 при полной сборке), findings[]`.
   находка: `id (f-<YYYYMMDD>-<NN>, стабильный), title, owner (code|decision|both), effort (S|M|L|-), block (crit|biz|imp|pol), status (open|done|deferred), what, why, source, task_slug (string|null), screenshot (path|null), date`.
   Счётчики футера («N находок → M блоков, K отложено», «чиню я / решаешь ты») в JSON НЕ хранятся — считает рендерер. Напоминание session-start: «ждут N решений» = count(owner in {decision,both} and status==open); «устарел на M задач» = stale_merges.

3. Файлы/пути: `.forge/status-report.json` (память, коммитится memory-backup), `.forge/status-report.html` и `.forge/reports/shots/<id>.png` — в `.forge/.gitignore` (добавляет другой кусок). Снимки Playwright MCP: `browser_resize {1280,800}` → `browser_navigate {url}` → `browser_take_screenshot {type:"png", filename:"sr-<id>.png", scale:"css"}` → mv в `.forge/reports/shots/<id>.png` (из корня или `.playwright-mcp/`) → `browser_close` → `rm -rf .playwright-mcp; rm -f ./sr-*.png ./page-*.png`.

4. Хэндофф: status-report → new-task передаёт текст `card:<id> <title>` (+ what/why контекстом); new-task шаг 9.5 после сохранения task-файла зовёт `render.py link <id> <slug>`, метку в задачу не копирует. state.yml: скилл пишет `phase: status-report` (statusline другого куска маппит → «📊 Фаза 5: Что дальше»); new-task перезаписывает при взятии карточки.

5. Тесты/evals: `tests/skill-triggering/run-all.sh` SKILLS += "project-unblocker", "status-report"; prompts/status-report.txt и prompts/project-unblocker.txt; `evals/criteria/status-report.yml` (phase: status-report, 6 binary); `evals/transition-matrix.tsv` — 9 столбцов, 8 строк.

6. Правки навигатора и доков про ROADMAP.md: project-unblocker/SKILL.md:207,209,217,245,246,249,256,260; evals/criteria/unblocker.yml:16; CLAUDE.md:90,92; COMMANDS.md:399; GUIDE.md:431; docs/forge-runtime-flow.md:163,203; using-forge/SKILL.md после :137. Шаг H пересекается с куском «Фаза 5 в доках» — кто-то один вносит.

===== OPEN QUESTIONS:
- Нужна ли render.py подкоманда `done <id>` для карточек-решений (сценарий «давай решения»)? Сейчас в скилле — правка поля `status` в JSON через Edit + `render.py render`; отдельная подкоманда надёжнее для не-кодера, но расширяет контракт рендерера.
- Должна ли полная сборка сразу звать `skills/memory-backup/backup.sh` (список вызывающих в memory-backup/SKILL.md:41 — session-awareness и finishing)? Сейчас JSON уедет в git только на итоге сессии/после мержа; если сессия оборвётся — отчёт останется незакоммиченным.
- Формат строки счётчиков, которую печатает `render.py render` (скилл берёт числа для чата из неё) — согласовать с куском рендерера; предложен `findings=N blocks=M code=a decision=b deferred=k shots=s`.
- Порог confidence для находок агентов: 70 (предложено, чтобы не терять вопросы владельцу из планов) или 80 как в critique?
- Шаг H (ROADMAP.md → отчёт в CLAUDE.md/COMMANDS.md/GUIDE.md/runtime-flow) — вносит этот кусок или кусок «Фаза 5 описана везде»? Нужно выбрать одного, иначе двойная правка одних строк.
- Куда девать `.forge/state.yml` после отчёта, если владелец ничего не взял в работу: оставить `phase: status-report` (statusline показывает Фазу 5) или ставить `idle`? В плане оставлено как есть.

===== RISKS:
- Перехват триггеров: описание status-report содержит явные NOT-for для «что дальше по проекту» и «статус проекта», но Клод в реальной сессии может всё равно выбрать отчёт по смыслу — негативный тест prompts/project-unblocker.txt ловит это только при живом прогоне `claude -p` (нужен CLI и ~2 мин на тест).
- Playwright MCP в интерактивной сессии может просить подтверждение на каждый browser_* вызов (до 6 снимков × 2-3 вызова) — владелец увидит серию запросов; при отказе скилл продолжает без картинок, но опыт «без вопросов» нарушается. Ограничение 6 снимков смягчает.
- Место сохранения снимка MCP (корень проекта vs `.playwright-mcp/`) взято из разведки одного эксперимента; mv с fallback покрывает оба варианта, но если MCP положит файл в третье место — снимок потеряется (карточка без картинки, отчёт не падает).
- 4 агента + чтение памяти — тяжёлая сборка по контексту; в проектах без .forge агент 4 вернёт мало, зато агент 1 может выдать шум (mock в тестах) — фильтр confidence ≥ 70 и лимиты блоков обязательны, иначе отчёт раздувается.
- Стабильность id: совпадение старой open-находки и новой определяет Клод «по смыслу» (тот же файл/суть) — возможны дубли под разными id между сборками; счётчики честные, но история карточки может разорваться.
- Правило честности owner=decision опирается на суждение Клода; риск обратный — всё уйти в «Код» с дефолтами, и владелец не увидит вопросов про деньги/людей. Eval-критерий owner_axis_honest ловит только при ручном прогоне evals (корпус пуст).
- Frontmatter description 832 символа — близко к лимиту 1024; при добавлении триггеров позже легко выйти за предел.
- Шаг H пересекается с другим куском плана (доки про Фазу 5) — без координации возможен конфликт правок в одних строках CLAUDE.md/COMMANDS.md.
