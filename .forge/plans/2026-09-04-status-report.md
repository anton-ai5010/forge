# План: Отчёт «Что дальше» — Фаза 5 плагина (status-report)

**Задача:** см. `.forge/tasks/2026-09-04-status-report.md`

**Подход:** Новый скилл `status-report` + команда `/forge:status-report`. Данные отчёта — JSON в памяти проекта (`.forge/status-report.json`), страницу из них собирает скрипт `render.py` (только стандартная библиотека Python, без PyYAML — его на Маке нет). Полная сборка: 4 параллельных субагента-аналитика + память `.forge` → синтез в находки с осью «владелец × срочность × усилия» → JSON → HTML → open. Лёгкое обновление: после мержа `finishing` зовёт `render.py merged <slug>`, при старте сессии `session-start.sh` зовёт `render.py summary`. Навигатор перестаёт писать `ROADMAP.md`. Версия 7.7.0, релиз через обычный мерж в master.

**Прототипы** (render.py, тесты, правки хуков, образец данных) переехали в репозиторий при реализации — папка `proto/` удалена, смотри рабочие файлы: `forge-plugin/skills/status-report/`, `forge-plugin/tests/hooks/`. Полные тексты шагов (код, old→new по строкам) — в `design-renderer.md`, `design-skill.md`, `design-docs.md`; сводка стыков — `design-merged.md`. **При расхождении между design-файлами и этим планом — прав план** (в нём учтены правки интегратора и критики; файл `proto/tests/hooks/test-memory-backup-patched.sh` не использовать — он отличается от реального теста только временным путём).

**Что увидишь ты:**
- Говоришь «собери отчёт» — в браузере открывается страница «<Проект>: что доделать…»: наверху «Главное одной фразой», дальше Блок 1 «Кровь из носа — чиню в коде», Блок 2 «Решения — нужны от тебя», Блок 3 «Скоро — усиливает продукт», в футере «Потом» и отложенное с числами. В чате — 3–5 строк с теми же числами.
- «Открой отчёт» / «покажи отчёт» — открывается уже собранный документ без нового аудита (секунды, не минуты).
- На каждой карточке чип **Код / Решение / Решение+код** и бейдж усилий **S/M/L**; если у проекта запущен интерфейс — рядом снимок экрана. Нет интерфейса — одна строка «интерфейс не запущен — отчёт без снимков; нужны — запусти проект и скажи «добавь снимки»».
- Говоришь «бери» на карточке «Код» — она уходит в `/forge:new-task`; после мержа этой задачи карточка сама становится зачёркнутой «Сделано», а в шапке появляется «устарел на N задач». Связь карточки с задачей переживает пересборку отчёта.
- Ответил на открытое решение в любой форме — Клод записывает решение и закрывает карточку; напоминание про него пропадает.
- В начале новой сессии одна строка: «📊 Отчёт «Что дальше»: ждут N решений владельца, отчёт устарел на M задач» — и только когда есть что напомнить.
- «Что дальше по проекту» по-прежнему зовёт навигатор, «статус проекта» — загрузку контекста; отчёт на них не откликается.
- Решения, которые ты, скорее всего, захочешь поправить: заголовки блоков (сейчас «Решения — нужны от тебя», без имени второго человека), порядок блоков, тон футера.

**Открытые вопросы:**
- Для паузы B нужен живой проект с `.forge/` — желательно с запущенным интерфейсом в браузере, иначе ветка со снимками до релиза проверится только формально. Спросим на самой паузе.
- Принято по умолчанию (можно отменить): счётчик «устарел на N задач» растёт при любом мерже, даже если задача не из карточки; заголовок Блока 2 без имени второго человека; `render.py done` не заводим — решение закрывается правкой `status` карточки + пересборкой.

**Блокеры:** нет

**Стыки (единые имена для всех шагов):**
- Данные: `.forge/status-report.json`; HTML: `.forge/status-report.html`; снимки: `.forge/reports/shots/<id>.png`; макет: `.forge/sketches/status-report-mockup.html`; фикстура образца: `forge-plugin/tests/hooks/fixtures/status-report-sample.json`.
- CLI рендерера: `render [json] [html]` · `merged <task-slug>` · `link <finding-id> <task-slug>` · `summary`. Режимов `build` и `sample` нет (образец — фикстура).
- Схема JSON (как в proto/render.py): `project, eyebrow, question, built_at, updated_at, stale_tasks, next_after, sources{analysts, found}, verdict{text, finding_id}, findings[{id, owner: code|decision|both, effort: S|M|L|-, block: crit|biz|imp|pol, status: open|done|deferred, title, what, why, source, task_slug?, screenshot?, done_at?}]`. Поля `lead`, `date`, `stale_merges`, `generated` — не существуют.
- id находок: `f1…fN`, новый = max+1, выданный id не переиспользуется. Жирный в текстах — только `**…**` (сырой `<b>` экранируется).
- Игнор в git: строки `status-report.html` и `reports/shots/` в `.forge/.gitignore` гарантирует **render.py** (функция `ensure_gitignore()` при записи боевого HTML): файла нет → создаёт полный набор из 8 строк, идентичный heredoc backup.sh (`.inject-state`, `.last-backup`, `.migration-declined`, `state.yml`, `.github-*`, `graph.json`, `status-report.html`, `reports/shots/`); файл есть → дописывает только отсутствующие две. Причина: finishing делает `git add -A` до backup.sh — иначе HTML со снимками (до МБ) уедет в историю навсегда.
- Catalog в `index.yml` (и в этом репо, и в проектах владельца): `status-report: {path: .forge/status-report.json, tags: [report, what-next, findings, decisions-pending, owner, effort]}` без note, последней записью в `catalog:`.
- Метка хэндоффа в new-task: `card:<id>` (без скобок), в тексте: `card:f3 <заголовок карточки>`.
- `<task-slug>` в finishing: `<feature-branch>` без префикса `feat/` (или `fix/`) — execute заводит ветку `feat/<slug>`, slug = имя файла `.forge/tasks/YYYY-MM-DD-<slug>.md` без даты и `.md`. Запомнить имя ветки до `git checkout <base-branch>`; если ветка названа иначе — взять из имени task-файла этой задачи; не из `state.yml` (уже `idle`) и не из `now.task`. Вывод «карточки с задачей «…» нет» — норма для задачи не из отчёта.
- Путь к плагину: в скиллах `$CLAUDE_PLUGIN_ROOT`, в `session-start.sh` — переменная `plugin_root`.
- Снимки Playwright MCP: `browser_resize {1280,800}` → `browser_navigate` → `browser_take_screenshot {type:"png", filename:".playwright-mcp/sr-<id>.png", scale:"css"}` → `mkdir -p .forge/reports/shots && mv .playwright-mcp/sr-<id>.png .forge/reports/shots/<id>.png`; после всех — `browser_close` и `rm -rf .playwright-mcp`. Не больше 6. Кандидаты адресов — секция «Адреса интерфейса» Агента 3 + стандартные `http://localhost:3000/5173/8000/8080`; основная сессия файлы заново не читает.
- Служебные строки `FORGE-REPORT:` — для Клода; владельцу показываются числа без префикса.
- `state.yml`: скилл пишет `phase: status-report` только в начале; в конце ничего.
- На GitHub отчёт не отражается: `sync.sh` (лейблы фаз), `validate.md`, `forge-graph.html` — не трогаем.

---

## Шаг 0: Git — чужой WIP в stash, ветка задачи, первый коммит

**Файлы:** ветка `feat/status-report`; коммит `forge-plugin/docs/status-report-format.md`.

**Что делаем:** сейчас ветка `feat/tray-save-command` = master (0 коммитов расхождения) + незакоммиченные правки трея/настроек.
```bash
cd /Users/mac/Projects/Plugin/plugin
git stash push -m "wip tray-save-command: settings.json + forge-tray-mac.py" -- .claude/settings.json forge-tray/forge-tray-mac.py
git checkout -b feat/status-report
git add forge-plugin/docs/status-report-format.md
git commit -m "docs: формат отчёта «Что дальше» (status-report-format.md)"
rm -f .forge/plans/2026-09-04-status-report/proto/tests/hooks/test-memory-backup-patched.sh
```
`.forge/learnings.yml` и task/plan-файлы остаются грязными — это память, `finishing` заберёт их при мерже. Stash вернём после релиза (Чекпоинт C).

**Как проверим:** `git branch --show-current` → `feat/status-report`; `git stash list` → 1 строка; `git status --short` → ` M .forge/learnings.yml`, `?? .forge/tasks/…` (2 файла), `?? .forge/plans/…`; без settings.json/forge-tray.

## Шаг 1: Рендерер + тест (TDD по двум новым проверкам)

**Файлы:** создать `forge-plugin/skills/status-report/render.py` (из `proto/skills/status-report/render.py`), `forge-plugin/tests/hooks/test-status-report.sh` (из `proto/tests/hooks/test-status-report.sh`), `forge-plugin/tests/hooks/fixtures/status-report-sample.json` (= `proto/sample-status-report.json`).

**Что делаем:**
1. Скопировать прототипы и фикстуру, `chmod +x` на оба скрипта. В тесте: путь фикстуры считать абсолютным до `new_project` (рядом с `RENDER`): `FIXTURE="$(cd "$(dirname "$0")/fixtures" && pwd)/status-report-sample.json"`; строку `render sample "$JSON" >/dev/null` → `cp "$FIXTURE" "$JSON"`. Прогон → «All tests passed» (13 PASS, базовая линия).
2. **RED.** В проверке (1): `render render >/dev/null` → `out=$(render render)` и в цепочку `&& printf '%s' "$out" | grep -qF "$total находок → $blocks блока"` (именно «блока» — на образце blocks=4, как в уже существующей HTML-проверке). Новая проверка (14) «real HTML in .forge → .forge/.gitignore gets report lines; mock elsewhere does not»: в mktemp-проекте без `.forge/.gitignore` после `render render` файл создан и содержит ровно 8 строк из стыков (`diff <(printf '%s\n' .inject-state .last-backup .migration-declined state.yml '.github-*' graph.json status-report.html reports/shots/) .forge/.gitignore` → пусто); при существующем `.forge/.gitignore` из одной строки `state.yml` после `render render` — 3 строки, повторный `render render` — по-прежнему 3; рендер в `.forge/sketches/x.html` из `/tmp/x.json` `.forge/.gitignore` не трогает. Прогон → ровно 2 FAIL.
3. **GREEN.** В render.py: (а) удалить константу `SAMPLE` и режим `sample` (данные живут в фикстуре); (б) в `counts()` добавить `"open_code": sum(1 for f in fs if f.get("status") == "open" and f.get("owner") == "code")`; (в) в `do_render()`: `html_text = render_html(data, base)` → запись → после `print(f"FORGE-REPORT: HTML собран → {html_path}")` вторая строка:
```python
c = counts(data)
print(f"FORGE-REPORT: {plural(c['total'],'находка','находки','находок')} → "
      f"{plural(c['blocks'],'блок','блока','блоков')}, чиню я — {c['open_code']}, "
      f"решаешь ты — {c['open_decisions']}, отложено — {len(c['deferred'])}, "
      f"снимков — {html_text.count('class=\"shot\"')}")
```
(г) функция и вызов первой строкой `do_render()`, только когда `Path(html_path).resolve().parent.name == ".forge"`:
```python
FORGE_IGNORE = [".inject-state", ".last-backup", ".migration-declined", "state.yml",
                ".github-*", "graph.json", "status-report.html", "reports/shots/"]

def ensure_gitignore(forge_dir):
    """HTML и снимки регенерируются из JSON — в git им не место. Рождаются они здесь, значит и игнор — здесь."""
    gi = forge_dir / ".gitignore"
    if not gi.is_file():
        gi.write_text("".join(l + "\n" for l in FORGE_IGNORE), encoding="utf-8")
        return
    text = gi.read_text(encoding="utf-8")
    missing = [l for l in ("status-report.html", "reports/shots/") if l not in text.splitlines()]
    if missing:
        with gi.open("a", encoding="utf-8") as fh:
            fh.write(("" if text.endswith("\n") else "\n") + "".join(l + "\n" for l in missing))
```
(д) в `render_html()` футер: `(", потом полиш." if c["pol"] else ".")` → `(", потом косметика." if c["pol"] else ".")`. Вёрстка — строго по `docs/status-report-format.md`, никакого JS, всё через `html.escape`.

**Как проверим:** `bash forge-plugin/tests/hooks/test-status-report.sh` → «All tests passed» (14 PASS); `grep -c 'SAMPLE\|"sample"' forge-plugin/skills/status-report/render.py` → 0; из корня репо `python3 forge-plugin/skills/status-report/render.py` → «FORGE-REPORT: нет .forge/status-report.json — отчёт ещё не собирали», rc 0, в `.forge/` файлов не появилось и `.forge/.gitignore` не изменился (`git diff --quiet .forge/.gitignore`).

## Шаг 2: Макет на образце данных

**Файлы:** создать `.forge/sketches/status-report-mockup.html`.

**Что делаем:**
```bash
R=forge-plugin/skills/status-report/render.py
python3 $R render forge-plugin/tests/hooks/fixtures/status-report-sample.json .forge/sketches/status-report-mockup.html
open .forge/sketches/status-report-mockup.html
```
Образец — проект «Lumen» (онлайн-запись в салон), 8 находок. **Не** класть образец в `.forge/status-report.json`.

**Как проверим:** в браузере «Lumen: что доделать…», «Главное одной фразой», Блок 1/2/3, футер «Блок 4 «Потом» — 1 находка», «потом косметика»; `grep -c 'class="tag' .forge/sketches/status-report-mockup.html` → 3; `ls .forge/status-report.json` → нет файла; `git diff --quiet .forge/.gitignore` → без изменений (макет не в `.forge/` напрямую).

---

### ✅ Чекпоинт A: реакция на макет

Что показываем: открытый макет (Lumen, 8 находок → 4 блока, 1 отложена) — картинка уже отправлена владельцу на планировании. Вопросы по одному: читается ли порядок и заголовки блоков; понятны ли чипы Код / Решение / Решение+код и бейдж S/M/L; хватает ли футера («потом косметика» вместо «полиш» — владелец вправе вернуть). Словами: после «мержим» карточка станет зачёркнутой с зелёным чипом «Сделано» и уедет в конец блока, в мете появится «обновлён … · устарел на N задач».
Что подтверждает владелец: «вид и порядок ок». Правки макета = правки CSS/BLOCKS в render.py + синхронно ожидания в тесте.

Следующее: скилл и точки вызова.

---

## Шаг 3: Мусор отчёта — в шаблонах игнора

**Файлы:** изменить `.forge/.gitignore` (этот репо), `forge-plugin/skills/memory-backup/backup.sh` (heredoc, +2 строки), `forge-plugin/commands/init.md` (heredoc `.forge/.gitignore`, те же +2), `forge-plugin/skills/memory-backup/SKILL.md:46` (список мусора), корневой `.gitignore` (`.playwright-mcp/`), `forge-plugin/tests/hooks/test-memory-backup.sh` (в существующую проверку создания `.forge/.gitignore` добавить `grep -qx 'status-report.html'` и `grep -qx 'reports/shots/'`).

**Что делаем:** heredoc в backup.sh и init.md — добавить строки `status-report.html` и `reports/shots/` (идемпотентный цикл **не** нужен — старые проекты закрывает `ensure_gitignore()` в render.py). Корень: `grep -qx '.playwright-mcp/' .gitignore || printf '.playwright-mcp/\n' >> .gitignore`.

**Как проверим:** `bash forge-plugin/tests/hooks/test-memory-backup.sh | tail -1` → «All tests passed»; `touch .forge/status-report.html && git check-ignore -q .forge/status-report.html && echo ignored; rm .forge/status-report.html` → ignored; `git check-ignore .playwright-mcp/x.log` → совпадение; heredoc в backup.sh и init.md совпадают построчно и равны `FORGE_IGNORE` из render.py (`python3 -c "import importlib.util as u,sys;s=u.spec_from_file_location('r','forge-plugin/skills/status-report/render.py');m=u.module_from_spec(s);s.loader.exec_module(m);print('\n'.join(m.FORGE_IGNORE))" | diff - <(sed -n '/<<.*EOF/,/^EOF/p' forge-plugin/skills/memory-backup/backup.sh | sed '1d;$d')` → пусто).

## Шаг 4: Скилл status-report (SKILL.md)

**Файлы:** создать `forge-plugin/skills/status-report/SKILL.md` (тексты A1–A5 в `design-skill.md`, с правками ниже).

**Что делаем:** frontmatter `name: status-report`, description с RU/EN триггерами («собери отчёт», «отчёт „что дальше“», «что чинить, что решать», «покажи документом, где мы», **«открой отчёт», «покажи отчёт»**; EN 'status report', 'what to fix vs decide', 'open/show the report') и явным NOT-for («что дальше по проекту» → project-unblocker, «статус проекта» → forge-context); ≤ 1024 символов. Тело:
0. **Показать или собрать?** «открой/покажи/посмотреть отчёт» и есть `.forge/status-report.json` → `render.py render` + open, одна строка в чат: «Открыл отчёт (собран {built_at}, обновлён {updated_at}, устарел на {stale_tasks} задач; снимков на этой машине может не быть — они не едут через git)». Нет JSON → «отчёт ещё не собирали — собрать?» Полная сборка — только по «собери отчёт» и родственным.
1. Роль + ставки, «Announce at start» («Собираю отчёт «Что дальше» — 4 аналитика пройдут по коду и памяти, это несколько минут»), `state.yml` → `phase: status-report` (только в начале).
2. Память: читать `index.yml`, `status.yml`, `direction.yml`, `decisions.yml`, `dead-ends.yml`, `journal.yml`, `learnings.yml`, открытые `.forge/tasks/*`; существующий `status-report.json`. **Правило переноса:** `done|deferred` переносятся как есть; открытые находки не пересоздаются — старая запись с тем же id остаётся, у неё меняются только `status/what/why/source`, а `task_slug`, `screenshot`, `done_at` сохраняются (открытая карточка с `task_slug` — задача в работе: агенты её только проверяют «актуально/закрыто», в deferred по лимиту не уходит); `screenshot` переносится, если файл `.forge/reports/shots/<id>.png` на месте; id не переиспользуются; `stale_tasks` → 0 при полной сборке.
3. 4 субагента параллельно одним сообщением (Agent tool), промпты из A2: (1) код — TODO/FIXME/заглушки/обработка ошибок на главном пути; (2) git — активность, незакоммиченное, давно не менявшееся; (3) инфраструктура — тесты/Docker/.env/деплой/запускается ли + секция «## Адреса интерфейса» (из infrastructure.yml / README / docker-compose ports / .env PORT / package.json); (4) документация и память — противоречия `.forge` vs код, невыполненные `next`. Формат возврата: список находок `{title, what, why, owner, effort, block, source, evidence, confidence}`; порог confidence 70.
4. Синтез в основной сессии (A3): дедуп, порядок «по боли», лимиты (crit ≤ 6, biz ≤ 6, imp ≤ 8, остальное `pol`/`deferred`), один verdict, правило честности (`owner: decision` только если реально нужно решение владельца — деньги/люди/легал/продукт; код-задачи в «решения» не прятать), тексты «Что/Зачем» на языке последствий, от первого лица на «ты», без жаргона, жирный — `**…**`.
5. Запись JSON по схеме стыков (Write целиком, с учётом правила переноса). Затем catalog: если в `.forge/index.yml` нет `status-report:` в `catalog:` — дописать запись из стыков последней в блоке, с тем же отступом, без note; если после этого `wc -c .forge/index.yml` > 2500 — ничего не ужимать и не спрашивать, одной строкой в чат: «index.yml больше 2500 байт — в авто-инжекцию попадает не весь catalog, при необходимости читай файл целиком».
6. Снимки (A4): кандидаты — секция «Адреса интерфейса» Агента 3 + `http://localhost:3000/5173/8000/8080`; живой — первый с `curl -s -o /dev/null -w '%{http_code}'` 2xx/3xx; последовательность из стыков; нет живого — одной строкой «интерфейс не запущен — отчёт без снимков; если картинки нужны — запусти проект (или попроси меня) и скажи «добавь снимки»», без вопросов. Любой сбой снимка → продолжать без картинки.
7. `python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" render` → `xdg-open .forge/status-report.html 2>/dev/null || open .forge/status-report.html`.
8. В чат 3–5 строк по шаблону A5 Шаг 7: вердикт, строка счётчиков — текст второй строки `FORGE-REPORT:` **без служебного префикса** (числа не пересчитывать руками), при 0 снимков хвост «— интерфейс не запущен; нужны — скажи «добавь снимки» после запуска», путь к файлу, первая карточка «Код» как предложение.
9. Хэндофф-таблица: «бери/давай/ок/первую» → инвокнуть `new-task` с текстом `card:<id> <заголовок>` + what/why контекстом; «давай решения» → по одному, ответ → записать в `decisions.yml` (session-awareness), у карточки `status: done` через Edit + `render.py render`; **ответ на открытое решение в любой форме и в любой сессии — то же самое** (записать + закрыть карточку + пересобрать); «добавь снимки» → повторить п.6 (снимки → у карточек `"screenshot"` через Edit) и п.7 **без нового аудита** — агентов не запускать, находки не менять.
10. Антипаттерны: HTML руками · вопросы владельцу до отчёта · «решение» вместо кода · технический жаргон · снимки без живого адреса · отчёт после каждой задачи · терять `task_slug` открытой карточки при пересборке · показывать владельцу служебные строки `FORGE-*` · полный аудит на «открой отчёт».

**Как проверим:** `sed -n '2p' SKILL.md` → `name: status-report`; длина description ≤ 1024 (`python3 -c "import re;t=open('forge-plugin/skills/status-report/SKILL.md').read();print(len(re.search(r'description: \"(.*)\"',t).group(1)))"`); `grep -c '^### Агент' SKILL.md` → 4; `grep -n 'render.py" render\|card:<id>\|browser_take_screenshot\|phase: status-report' SKILL.md` → по одной строке каждое; `grep -c 'добавь снимки' SKILL.md` → 3; `grep -c 'task_slug' SKILL.md` ≥ 3; `grep -c 'открой отчёт\|покажи отчёт' SKILL.md` ≥ 2.

## Шаг 5: Команда /forge:status-report

**Файлы:** создать `forge-plugin/commands/status-report.md` (по образцу `commands/unblocker.md`).

**Что делаем:** frontmatter `description: "Отчёт «Что дальше» (Phase 5). Аудит проекта 4 агентами + память .forge → HTML: что чинит Клод в коде, какие решения нужны от владельца, в каком порядке. Полная сборка по команде; «открой отчёт» — показать готовый; после мержа обновляется сам."`, `disable-model-invocation: true`; тело — `Invoke the forge:status-report skill and follow it exactly as presented to you`.

**Как проверим:** `tail -1 forge-plugin/commands/status-report.md` → строка Invoke; `grep -c 'disable-model-invocation: true' …` → 1.

## Шаг 6: new-task — пункт 9.5, связь карточки с задачей

**Файлы:** изменить `forge-plugin/skills/new-task/SKILL.md` (после пункта 9 «**Сохрани**», перед 10 «GitHub-sync»).

**Что делаем:** пункт 9.5: если в исходном запросе была метка `card:<id>` (задача пришла из отчёта «Что дальше») и есть `.forge/status-report.json` — `python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" link <id> <slug>`; без метки или без JSON — молча пропустить; метку в текст задачи не переносить.

**Как проверим:** `grep -n 'render.py" link' forge-plugin/skills/new-task/SKILL.md` → одна строка между «9. **Сохрани**» и «10. **GitHub-sync»; функционально: `T=$(mktemp -d) && cd $T && mkdir .forge && R=/Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/render.py && cp /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/fixtures/status-report-sample.json .forge/status-report.json && python3 $R link f3 refund-fee | tail -1` → «FORGE-REPORT: карточка f3 → задача refund-fee».

## Шаг 7: finishing — после мержа render.py merged

**Файлы:** изменить `forge-plugin/skills/finishing-a-development-branch/SKILL.md` (Option 1: после блока про `index.yml`, перед «**Затем сохрани память…**»).

**Что делаем:** блок «Отчёт «Что дальше» (Фаза 5)»: если есть `.forge/status-report.json` — `python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" merged <task-slug>` (карточка задачи → «Сделано», счётчик «устарел» +1, HTML пересобран; без JSON — молчит). Определение `<task-slug>` — дословно из стыков (ветка без `feat/`, запомнить до checkout, иначе имя task-файла; «карточки нет» — норма). Идёт до backup.sh, чтобы JSON уехал тем же коммитом. Владельцу про этот шаг — одна строка только если карточка закрылась: «Карточка «…» в отчёте отмечена сделанной».

**Как проверим:** `grep -n 'render.py" merged' …/finishing-a-development-branch/SKILL.md` → одна строка, номер меньше номера `grep -n 'Затем сохрани память'`; `grep -c 'feat/' …/finishing-a-development-branch/SKILL.md` ≥ 1; в корне репо (отчёта нет) `python3 forge-plugin/skills/status-report/render.py merged x; echo rc=$?` → пустой вывод, rc=0.

## Шаг 8: session-start.sh — строка Phase 5 + напоминание (тест RED → хук GREEN)

**Файлы:** создать `forge-plugin/tests/hooks/test-session-start.sh` (каркас H2 в `design-docs.md`, ожидания под `summary`); изменить `forge-plugin/hooks/session-start.sh` (= `proto/hooks/session-start.sh`: блок `report_warn` после блока версии, строка `  Phase 5   /forge:status-report — отчёт «что дальше»: что чиню, что решаешь` после строки Phase 4, `$warning$mem_warn$report_warn`).

**Что делаем:** тест: (1) интро содержит «Phase 5» и «forge:status-report»; (3) без JSON — нет «📊 Отчёт»; (4) JSON `{"stale_tasks":3,"findings":[{"id":"a","owner":"decision","status":"open"},{"id":"b","owner":"both","status":"open"},{"id":"c","owner":"decision","status":"done"},{"id":"d","owner":"code","status":"open"}]}` → «ждут 2 решения владельца» и «отчёт устарел на 3 задачи»; (5) `{"stale_tasks":0,"findings":[{"owner":"decision","status":"done"}]}` → нет «📊 Отчёт»; (6) битый JSON → rc 0 и валидный JSON на выходе. Тест изолирован в mktemp (урок `git-tests-must-isolate-cwd`). Хук: `report_warn` через `python3 "$plugin_root/skills/status-report/render.py" summary`; хвост текста: «— напомни пользователю одной строкой; вопросы по решениям задавай по одному и только по его слову. Если владелец в любой форме отвечает на открытое решение из отчёта — запиши его в .forge/decisions.yml, поставь этой карточке "status": "done" в .forge/status-report.json (через Edit) и пересобери: python3 $plugin_root/skills/status-report/render.py render».

**Как проверим:** до правки хука — FAIL на (1) и (4); после — `bash forge-plugin/tests/hooks/test-session-start.sh | tail -1` → «All tests passed»; в корне репо `bash forge-plugin/hooks/session-start.sh </dev/null | grep -c 'Phase 5'` → 1, `| grep -c 'ждут'` → 0; `grep -c 'status-report.json' forge-plugin/hooks/session-start.sh` ≥ 2.

## Шаг 9: statusline.sh — Фаза 5

**Файлы:** изменить `forge-plugin/hooks/statusline.sh` (case, после строки `execute|"Phase 4"|4)`).

**Что делаем:** `    status-report|"Phase 5"|5) phase_icon="📊 Фаза 5: Что дальше" ;;`

**Как проверим:** `d=$(mktemp -d) && mkdir "$d/.forge" && printf 'phase: status-report\ntask: отчёт\n' > "$d/.forge/state.yml" && cd "$d" && echo '{}' | bash /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/statusline.sh` → содержит «📊 Фаза 5: Что дальше».

## Шаг 10: Prompt-тесты триггеров

**Файлы:** создать `forge-plugin/tests/skill-triggering/prompts/status-report.txt` (наивный: «Собери мне отчёт документом — что в проекте чинить тебе, а что решать мне, и в каком порядке») и `prompts/project-unblocker.txt` (негативный: «Что дальше по проекту? Куда двигать…» — должен сработать unblocker); изменить `run-all.sh` (`SKILLS=(…)` + `"project-unblocker"` и `"status-report"`).

**Как проверим:** `sed -n '10,21p' forge-plugin/tests/skill-triggering/run-all.sh` содержит оба; `bash -n run-all.sh`. Живой прогон (нужен `claude` CLI, ~2 мин на тест) — на Чекпоинте B: `./run-test.sh project-unblocker prompts/project-unblocker.txt 3` → PASS, и в напечатанном им «Full log: <path>» `grep -c '"skill":"forge:status-report"' <path>` → 0 (путь брать из вывода, не глобом по /tmp).

---

### ✅ Чекпоинт B: прогон на живом проекте

Запуск незарелиженного плагина — как в `tests/skill-triggering/run-test.sh`: в проекте владельца с `.forge/` (спросить, в каком; лучше с запущенным интерфейсом) `claude --plugin-dir /Users/mac/Projects/Plugin/plugin/forge-plugin`.
Что показываем (прогоняет Клод): (1) «собери отчёт» → 4 агента, JSON записан, HTML открыт, в чате числа без префикса; `.forge/.gitignore` проекта получил две строки; при живом http — снимки в карточках, в корне нет `.playwright-mcp/` и PNG (`ls -a` + `git status --short`); (2) «что дальше по проекту» → сработал unblocker, не отчёт (+ prompt-тест из Шага 10); (3) «открой отчёт» → открылся без аудита; (4) «бери» на первой карточке «Код» → new-task, после сохранения task-файла в HTML «→ в работе: <slug>»; (5) повторный «собери отчёт» → карточка сохранила «в работе: <slug>»; (6) имитация мержа `render.py merged <slug>` → карточка зачёркнута «Сделано», мета «устарел на 1 задачу»; (7) новая сессия — интро содержит «📊 Отчёт «Что дальше»: ждут N решений владельца, отчёт устарел на 1 задачу».
Что подтверждает владелец: вердикт и порядок совпадают с его ощущением проекта; карточки «Решение» — действительно его вопросы; язык без жаргона. Если снимать было нечего — фиксируем в journal, что ветка снимков проверится на первом проекте с интерфейсом.

Следующее: навигатор, документация, версия, релиз.

---

## Шаг 11: Навигатор без ROADMAP.md + evals + using-forge

**Файлы:** изменить `forge-plugin/skills/project-unblocker/SKILL.md` (строки 207, 209, 217, 245, 246, 249, 256, 260 — old→new в `design-skill.md`, шаг F; перед правкой сверить `sed -n '207p;209p;217p;245p;246p;249p;256p;260p'`); создать `forge-plugin/evals/criteria/status-report.yml` (7 binary-проверок: 6 из шага E + `card_link_survives_rebuild` «связь карточка→задача пережила полную пересборку?»); изменить `evals/criteria/unblocker.yml:16` → «Обновлён .forge/direction.yml (ROADMAP.md не пишется — витрина для глаз теперь отчёт «Что дальше», /forge:status-report)?»; `evals/transition-matrix.tsv` → 9 столбцов × 8 строк; `skills/using-forge/SKILL.md` — одна строка `| forge:status-report | Phase 5 — отчёт «Что дальше»: что чинит Клод, что решает владелец (HTML из .forge/status-report.json) |` **сразу после строки `| forge:execute | Run plans with review checkpoints |`** (сейчас :120; сверить `grep -n 'forge:execute |'`).

**Как проверим:** `grep -n 'ROADMAP' forge-plugin/skills/project-unblocker/SKILL.md` → ровно 2 строки со словами «не пишет» / «писать ROADMAP.md»; `ruby -ryaml -e 'YAML.load_file("forge-plugin/evals/criteria/status-report.yml"); puts "OK"'` → OK; `grep -c '^  - id:' forge-plugin/evals/criteria/status-report.yml` → 7; `python3 -c "import csv;r=list(csv.reader(open('forge-plugin/evals/transition-matrix.tsv'),delimiter='\t'));print(len(r),{len(x) for x in r})"` → `8 {9}`; `grep -n -A1 'forge:execute |' forge-plugin/skills/using-forge/SKILL.md` → две строки: execute, затем status-report.

## Шаг 12: Документация — 7 фаз везде

**Файлы:** изменить `CLAUDE.md` (корень), `forge-plugin/README.md`, `forge-plugin/COMMANDS.md`, `forge-plugin/commands/init.md`, `forge-plugin/docs/forge-runtime-flow.md`, `GUIDE.md`. Точные old→new — `design-docs.md` C1–C6 с поправками интегратора (`design-merged.md`, «WRONG FRAGMENTS»): CLAUDE.md — Phase 5 после :117, Development Workflow на :85, мусор на :83, Auto-handoff на :126; COMMANDS.md — секция 6.5 после :298. Перед каждой правкой сверять строки `sed -n`.

**Что делаем:** CLAUDE.md: «7-фазный (0 → 1 → 1.5 → 2 → 3 → 4 → 5)» в :3 и :85; в :83 к мусору `status-report.html`, `reports/shots/`; :90/:92 без ROADMAP.md; подсекция «### Phase 5 — Итог: что дальше (`/forge:status-report`)» с «Выход» (упомянуть «открой отчёт» и закрытие решений); в Auto-handoff — «Phase 5 в цепочку не входит: полная сборка по слову, после мержа — обновление само»; строка в Commands Reference; Evals «7 фазам / 7 фаз». README: :3, :5 (пометка «историческая схема»), строка таблицы `| 📊 **status-report** | …|`, строка в «Полезных командах», :82. COMMANDS.md: заголовок/ASCII-схема/таблица, абзац «4 → 5 без auto-handoff», handoff execute :287, секция 6.5 по шаблону 180-206, :399, workflow (+ пункт), «Команды по этапам», «Быстрая помощь»; строки в сценариях API/Миграция/Быстрая — **не** добавлять. init.md: :564, Phase 5 после :582, перенумерация «After completing work» (5→6, 6→7), строка таблицы, self-check :660, :855. runtime-flow: 7 фаз в схемах/таблице контрактов/timeline, ROADMAP.md → отчёт. GUIDE.md: строка команды после :152, :431. `docs/status-report-format.md` и `ideas/pipeline-v2.html` — не трогаем.

**Как проверим:** `grep -rn '6-фазн\|6-phase\|6 фаз\|6-Phase\|ROADMAP' CLAUDE.md GUIDE.md forge-plugin/README.md forge-plugin/COMMANDS.md forge-plugin/commands/init.md forge-plugin/docs/forge-runtime-flow.md forge-plugin/evals | grep -v 'не заводится\|не пишет\|не пишется\|историческ'` → пусто; `grep -c 'status-report' CLAUDE.md forge-plugin/README.md forge-plugin/COMMANDS.md forge-plugin/commands/init.md forge-plugin/docs/forge-runtime-flow.md GUIDE.md` → везде ≥ 1.

## Шаг 13: Версия 7.7.0 + память проекта

**Файлы:** изменить `forge-plugin/.claude-plugin/plugin.json`, `forge-plugin/.claude-plugin/marketplace.json`, `.claude-plugin/marketplace.json` (7.6.0 → 7.7.0; «6-phase … execute)» → «7-phase … execute → status-report)»; «Forge — 6-phase» → «Forge — 7-phase»); `.forge/index.yml` (из `proto/index-candidate.yml`: :3 «7-фазный … → 5 status-report», version 7.7.0, catalog `status-report` с тегами из стыков без note, note у direction убран, session-блок коротко — ≤ 2400 байт); `.forge/map.yml` (skills 35, commands 27, блок `skills/status-report/` с about «render / merged <slug> / link <id> <slug> / summary», tests по `find forge-plugin/tests -type f | wc -l`); `.forge/decisions.yml` (запись `status-report-phase-5`: JSON вместо YAML из-за PyYAML, рендерер вместо HTML руками, игнор HTML/снимков гарантирует render.py, файл в .forge, ROADMAP.md убран — why по образцу); `.forge/journal.yml` (запись 2026-09-04 первой); `.forge/status.yml:2` → «7-фазный pipeline: unblocker → … → status-report» + строка про отчёт. `forge-tray/forge-tray-mac.py` не трогать (в stash).

**Как проверим:** `grep -h '"version"\|phase' forge-plugin/.claude-plugin/plugin.json forge-plugin/.claude-plugin/marketplace.json .claude-plugin/marketplace.json | sort -u` → только 7.7.0 / 7-phase; все три JSON валидны (`python3 -c "import json;json.load(open(f))"`); `wc -c .forge/index.yml` ≤ 2400; `ruby -ryaml -e '%w[.forge/index.yml .forge/decisions.yml .forge/journal.yml .forge/map.yml .forge/status.yml].each{|f| YAML.load_file(f)}; puts "YAML OK"'`; `grep -c '^  - id:' .forge/decisions.yml` → 11; `bash forge-plugin/hooks/session-start.sh </dev/null | grep -c 'v7.7.0'` → 1.

## Шаг 14: Полный прогон тестов и свип

**Что делаем:**
```bash
cd /Users/mac/Projects/Plugin/plugin
for t in forge-plugin/tests/hooks/test-*.sh; do printf '%s: ' "$t"; bash "$t" | tail -1; done
grep -rn '6-фазн\|6-phase\|6 фаз\|ROADMAP' CLAUDE.md GUIDE.md forge-plugin/ .forge/index.yml .forge/status.yml --include=*.md --include=*.yml --include=*.sh --include=*.json | grep -v 'не заводится\|не пишет\|писать ROADMAP.md\|не пишется\|историческ'
git status --short | grep -E '^\?\? (\.playwright-mcp|.*\.png)' || echo clean
```

**Как проверим:** 6 сьютов (bash-safety, context-inject, memory-backup, session-start, status-report, user-rules-check) — каждая строка «All tests passed»; grep → пусто; «clean»; в `git status --short` есть `.forge/sketches/status-report-mockup.html`, нет `.forge/status-report.json/.html`.

---

### ✅ Чекпоинт C: «мержим» → релиз 7.7.0 → обновление плагина → вернуть WIP

Что показываем: список файлов из `git status --short` (только файлы задачи + память; settings.json и forge-tray — в stash) и итог тестов.
Владелец говорит «мержим» → `finishing-a-development-branch` Option 1 (коммит, merge в master, index.yml, backup.sh → push master). Затем проверка релиза: `git rev-parse master origin/master` → одинаково; `gh api repos/anton-ai5010/forge/contents/forge-plugin/.claude-plugin/plugin.json --jq .content | base64 -d | grep '"version"'` → "7.7.0"; в Claude Code владельца `/plugin marketplace update forge-marketplace` + `/plugin update forge@forge-marketplace`, перезапуск; `python3 -c "import json;print(json.load(open('/Users/mac/.claude/plugins/installed_plugins.json'))['plugins']['forge@forge-marketplace'][0]['version'])"` → 7.7.0; интро новой сессии — «Forge plugin (v7.7.0) активен.» и строка `Phase 5   /forge:status-report`. Затем `git stash pop` → `git stash list` пусто, `git status --short` → ` M .claude/settings.json`, ` M forge-tray/forge-tray-mac.py`.
Что подтверждает владелец: версия 7.7.0 видна в интро, правки трея вернулись.

---

## Критика — что применено

- **Блокер:** HTML со снимками и PNG утекали бы в git у проектов на v7.6.0 (finishing делает `git add -A` до backup.sh). Теперь игнор гарантирует сам рендерер при записи боевого HTML (`ensure_gitignore()`, Шаг 1) + тест; цикл в backup.sh и «тест 13» убраны.
- **Важное:** ожидание теста «блока», не «блоков» (Шаг 1); Шаги 1+2 слиты в один TDD-шаг с наблюдаемым RED; источник теста для memory-backup исправлен; `<task-slug>` в finishing определён явно (Шаг 7, стыки); связь карточки с задачей и снимок переживают пересборку (Шаг 4 п.2); единые теги catalog + поведение при переполнении index.yml (стыки, Шаг 4 п.5); режим «открой отчёт» без аудита (Шаг 4 п.0); ответ на решение в любой форме закрывает карточку (Шаг 4 п.9, Шаг 8).
- **Мелкое:** негативный prompt-тест проверяет, что status-report не сработал (Шаг 10); образец данных вынесен в фикстуру, режим `sample` убран (Шаг 1–2); кандидаты адресов только из Агента 3 (Шаг 4 п.6); префикс `FORGE-REPORT` владельцу не показывается; строка using-forge вставляется по якорю, не по номеру; «полиш» → «косметика»; путь «добавь снимки».
- **Опровергнуто (не применяем):** «ок/давай» уводят в new-task — это единая конвенция плагина; «открыл в браузере» при закрытом браузере — не воспроизводится; лишние проверки в test-session-start — часть из них и есть RED; «бери» на карточке «Решение» — таблица хэндоффа предлагает только «Код».

## Execution Strategy

### Последовательно (в основной сессии)
- Шаг 0 (git) → Шаг 1 (рендерер + тест, TDD) → Шаг 2 (макет) → **Чекпоинт A** → Шаг 3 (игнор-шаблоны).
- После Чекпоинта A: Шаг 4 (SKILL.md — в субагент, см. ниже) → Шаг 5 (команда, основная сессия).

### Параллельно (одновременно через субагентов, после Шага 4)
- Группа П1: Шаг 6 (new-task 9.5), Шаг 7 (finishing merged), Шаг 9 (statusline), Шаг 10 (prompt-тесты) — независимые правки разных файлов; каждый субагент возвращает diff-сводку + вывод своей проверки.
- Шаг 8 (session-start: тест + хук) — отдельный субагент параллельно с П1 (TDD внутри: тест RED → хук GREEN).
- После **Чекпоинта B**: группа П2: Шаг 11 (навигатор + evals + using-forge) и Шаг 12 (документация 6 файлов) — параллельно, разные файлы. Шаг 13 (версия + память) — после П2, в основной сессии (index.yml — L0, правится вручную по кандидату).

### Делегировать субагентам (грязная работа)
- Шаг 4: написать SKILL.md по A1–A5 из `design-skill.md` с правками плана (длинный текст, много чтения) → вернуть путь + вывод проверок из «Как проверим».
- Шаг 12: правки 6 файлов документации по `design-docs.md` C1–C6 со сверкой строк → вернуть список «файл: что изменено» + вывод grep-проверки.
- Шаг 11: навигатор/evals/using-forge → то же.
- Шаг 14: полный прогон тестов и свип → вернуть только итоговые строки сьютов и результат grep.
- Чекпоинт B п.(1)–(7): прогон на живом проекте — субагент запускает `claude --plugin-dir …` с нужными промптами и возвращает наблюдения (что открылось, что в JSON/HTML, вывод `ls -a`/`git status`).

### Делать в основной сессии
- Шаг 0, Шаг 1 (маленькие точные правки прототипа + наблюдение RED/GREEN), Шаг 2, Шаг 3, Шаг 5, Шаг 13, стыковка результатов субагентов, диалог на чекпоинтах, «мержим» (finishing) и релиз на Чекпоинте C.

### Чекпоинты
- После Шага 2 — **A**: реакция на макет (картинка уже у владельца; правки → render.py + тест).
- После Шага 10 — **B**: прогон на живом проекте владельца (спросить, на каком; снимки — если есть интерфейс).
- После Шага 14 — **C**: «мержим» → релиз 7.7.0 → обновление плагина → `git stash pop`.
