

===== ШАГ 1: Шаг 1. Фикстура-образец гайда «Lumen» (все 9 разделов) — ground truth для тестов и макета (~20 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/fixtures/guide-sample.json (создать); /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/fixtures/status-report-sample.json (не трогать — нужна для теста миграции)
--- ЧТО:
Расширить проект «Lumen» из status-report-sample.json до полного гайда. Все 8 находок переносятся 1:1 (id/owner/effort/block/status/title/what/why/source/screenshot), у f2 добавить "links": ["D1"], у f3 — "links": ["D1"]. Каркас файла (значения — по этому образцу, тексты на «вы», для читающего со стороны):

```json
{
  "meta": {"project": "Lumen", "version": "1.0", "project_version": "0.9.2", "date": "2026-09-06",
           "audience": "для владельца сети салонов и управляющей", "eyebrow": "перед подключением второго салона",
           "logo": "L", "built_from": "код проекта, память .forge, созвон 30.08"},
  "updated_at": "2026-09-06", "stale_tasks": 0,
  "sources": {"analysts": 4, "found": 8},
  "snapshot": {
    "facts": [{"lead": "Запись работает", "text": "клиенты записываются сами, мастер видит календарь."},
               {"lead": "Предоплата подключена", "text": "деньги списываются при записи."},
               {"lead": "Напоминаний нет", "text": "треть опозданий — «забыл»."},
               {"lead": "До второго салона", "text": "ваши решения по возвратам и регистрации."}],
    "howto_extra": "После ваших ответов следующая версия гайда выйдет с обновлёнными статусами."
  },
  "about": {
    "text": "**Lumen — онлайн-запись для салонов красоты.** Клиент выбирает мастера и время, вносит предоплату, мастер подтверждает.",
    "after": "Если мастер молчит 10 минут — запись подтверждается сама.",
    "scheme": [{"title": "Клиент", "text": "сайт: выбор мастера, времени, предоплата"},
               {"arrow": "запись", "title": "Lumen", "text": "календарь, оплата, уведомления"},
               {"arrow": "уведомление", "title": "Мастер", "text": "подтверждает или отклоняет в Telegram"}],
    "screens": [{"file": ".forge/guide/shots/calendar-mobile.png", "caption": "Календарь мастера на телефоне", "group": "Мастер · календарь"},
                 {"file": ".forge/guide/shots/booking.png", "caption": "Форма записи", "group": "Клиент · запись"}]
  },
  "parts": [{"icon": "📅", "title": "Запись", "text": "Выбор мастера и времени, подтверждение.", "codes": ["B1"]},
            {"icon": "💳", "title": "Предоплата", "text": "Списание при записи, возврат при отмене.", "codes": ["D1"]},
            {"icon": "🔔", "title": "Уведомления", "text": "Telegram мастеру и клиенту.", "codes": []}],
  "flow": [{"title": "Выбор", "text": "клиент открывает сайт салона, выбирает мастера и слот."},
           {"title": "Предоплата", "text": "списание через банк."},
           {"title": "Подтверждение", "text": "мастер нажимает «принять» в Telegram."},
           {"title": "Визит", "text": "запись в календаре, статус «выполнено»."}],
  "roles": [{"role": "Клиент", "does": "записывается, платит, видит свои записи."},
            {"role": "Мастер", "does": "календарь, подтверждение записей."},
            {"role": "Владелец", "does": "все салоны, статистика, возвраты."}],
  "decisions": [
    {"code": "P1", "group": "P", "group_title": "Процесс", "title": "Правило дефолта", "status": "default", "fire": false, "since_version": "1.0", "source": "плагин",
     "what": "По пунктам с меткой «дефолт» есть рекомендация; нет возражений — действуем по ней.", "why": "Двигает вперёд без бесконечных согласований."},
    {"code": "A1", "group": "A", "group_title": "Рамка", "title": "Запись без регистрации — по телефону", "status": "default", "fire": false, "since_version": "1.0", "source": ".forge/direction.yml",
     "what": "Только номер и код из СМС.", "why": "Половина клиентов уходит на шаге «придумайте пароль»."},
    {"code": "A2", "group": "A", "group_title": "Рамка", "title": "Один аккаунт — много салонов", "status": "accepted", "fire": false, "since_version": "1.0", "source": ".forge/decisions.yml#multi-salon",
     "what": "Владелец видит все салоны в одном кабинете.", "why": "Второй салон — тот же владелец."},
    {"code": "B1", "group": "B", "group_title": "Механика", "title": "Автоподтверждение через 10 минут", "status": "default", "fire": true, "since_version": "1.0", "source": "src/booking/confirm.py:41",
     "what": "Мастер молчит 10 минут — запись подтверждается сама.", "why": "Клиент не ждёт полчаса и не уходит к соседям."},
    {"code": "D1", "group": "D", "group_title": "Деньги", "title": "Кто платит комиссию за возврат", "status": "discuss", "fire": true, "since_version": "1.0", "source": "созвон 2026-08-30",
     "what": "Салон / клиент / пополам / не возвращаем позже чем за 2 часа.", "why": "Пока правила нет, возвраты делаются по-разному."},
    {"code": "O1", "group": "O", "group_title": "Открытые вопросы", "title": "Кто отвечает клиентам ночью", "status": "open", "fire": true, "since_version": "1.0", "source": "аналитик 2",
     "what": "Ночью подтверждать некому; предложений нет."}
  ],
  "findings": [ ...8 находок из status-report-sample.json, f2/f3 с links... ],
  "plan": {"now": ["Ответы по 🔥 (B1, D1, O1)", "Починить предоплату при обрыве (R2)"],
           "next": ["Напоминания за 2 часа (R6)", "Календарь на телефоне (R5)"],
           "later": ["Тёмная тема админки (R8)", "Второй салон"]},
  "glossary": [{"term": "Слот", "text": "Свободный промежуток в календаре мастера."},
               {"term": "Предоплата", "text": "Часть цены, списанная при записи."},
               {"term": "Автоподтверждение", "text": "Запись подтверждается без участия мастера."}],
  "tg_mocks": [{"title": "Мастер · подтверждение записи в боте",
                "bubbles": [{"who": "bot", "text": "Новая запись: 14:00, стрижка, Анна.\nПодтвердить?", "buttons": ["Принять", "Отклонить"]},
                            {"who": "me", "text": "Принять"},
                            {"who": "sys", "text": "Клиенту отправлено «вас ждут»"}]}],
  "changelog": [],
  "pending_changes": []
}
```

Ожидаемые числа фикстуры (для тестов): решений 6, из них ждут ответа 5 (default P1/A1/B1 + discuss D1 + open O1), 🔥 3 (B1, D1, O1); находок 8 (deferred 1, pol 1, both/decision open 3: f2, f3, f4) → summary «ждут 8 решений»; разделов 9; групп решений P/A/B/D/O.
--- ПРОВЕРКА:
python3 -c "import json;d=json.load(open('forge-plugin/tests/hooks/fixtures/guide-sample.json'));print(len(d['decisions']),len(d['findings']),len(d['flow']),len(d['glossary']),d['meta']['version'])" → `6 8 4 3 1.0`


===== ШАГ 2: Шаг 2. TDD RED: test-status-report.sh → test-guide.sh с проверками всех режимов гайда (~35 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-guide.sh (git mv из test-status-report.sh + переписать); /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/fixtures/guide-sample.json; /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/fixtures/status-report-sample.json
--- ЧТО:
`git mv forge-plugin/tests/hooks/test-status-report.sh forge-plugin/tests/hooks/test-guide.sh`. Шапка и хелперы (RENDER → skills/project-guide/render.py, JSON → .forge/guide/v1.0.json, jget читает `$1` как путь):

```bash
RENDER="$(cd "$(dirname "$0")/../../skills/project-guide" && pwd)/render.py"
FIX="$(cd "$(dirname "$0")/fixtures" && pwd)"
GUIDE=$FIX/guide-sample.json; LEGACY=$FIX/status-report-sample.json
JSON=.forge/guide/v1.0.json; HTML=docs/guide/guide-v1.0.html; LATEST=docs/guide/guide-latest.html
new_project() { WORK=$(mktemp -d); cd "$WORK" || exit 1; mkdir -p .forge/guide; }
render() { python3 "$RENDER" "$@" 2>&1; }
jget() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))" "$1" "$2"; }
```

Проверки (каждая — `check "…" $?`):

```bash
# (1) render: обе HTML, 9 разделов по порядку, шапка с версией/аудиторией, счётчики в stdout
new_project; cp "$GUIDE" "$JSON"; out=$(render render)
[ -f "$HTML" ] && [ -f "$LATEST" ] && cmp -s "$HTML" "$LATEST" \
  && [ "$(grep -o '<h2><span class="no">[0-9][0-9]</span>' "$HTML" | wc -l | tr -d ' ')" = "9" ] \
  && grep -q '<span class="no">00</span>Где мы сейчас' "$HTML" && grep -q '<span class="no">08</span>Словарик' "$HTML" \
  && grep -q '<title>Lumen · Гайд по проекту v1.0</title>' "$HTML" \
  && grep -q 'для владельца сети салонов' "$HTML" && grep -q 'версия проекта 0.9.2' "$HTML" \
  && printf '%s' "$out" | grep -q 'решений 6 (ждут ответа 5, 🔥 3), рисков 7'
check "render should write guide-v1.0.html + guide-latest.html with 9 sections, header meta and honest counters" $?

# (2) решения: карточки с кодами, статусы → чипы, 🔥 только у неотвеченных, группы P и O всегда
grep -q '<span class="code">P1</span>' "$HTML" && grep -q '<span class="code o">O1</span>' "$HTML" \
  && grep -q '<span class="code">A2</span>.*<span class="acc">принято</span>' "$HTML" \
  && grep -q '<span class="code">D1</span><span class="fire">🔥 эта неделя</span>.*<span class="dsc">обсудить</span>' "$HTML" \
  && [ "$(grep -o '<span class="fire">' "$HTML" | wc -l | tr -d ' ')" = "3" ] \
  && grep -q '<li><b>B1</b> — Автоподтверждение' "$HTML" && ! grep -q '<li><b>A2</b>' "$HTML" \
  && grep -q '<b>P\*</b> — процесс' "$HTML" && grep -q '<b>R\*</b> — риски' "$HTML"
check "decisions should render codes, status chips, fire only on unanswered, P/O/R legend always" $?

# (3) риски из findings: R<n> по id, ярус по block, «Предлагаем» = what, ссылки на коды, pol в средних, deferred не показан
grep -q '<div class="risk crit"><div class="rt"><span class="rc">R2</span>Предоплата списана.*(→ D1)' "$HTML" \
  && grep -q '<span class="rc">R5</span>' "$HTML" && grep -q 'risk mid.*<span class="rc">R7</span>' "$HTML" \
  && ! grep -q '<span class="rc">R8</span>' "$HTML" && grep -q '<b>Предлагаем:</b> Оплату и создание записи' "$HTML" \
  && grep -q '🔴 Критичные' "$HTML" && grep -q '🟠 Высокие' "$HTML" && grep -q '🟡 Средние' "$HTML"
check "risks should derive R<n> from finding id, tier from block, propose from what" $?

# (4) устройство: схема со стрелками, части с кодами, шаги, роли, план 3 колонки, словарик, tg-диалог, без JS
grep -q '<div class="sarr">→<small>запись</small></div>' "$HTML" && [ "$(grep -o '<div class="sbox">' "$HTML" | wc -l | tr -d ' ')" = "3" ] \
  && grep -q 'class="cd">→ D1</span>' "$HTML" && [ "$(grep -o '<div class="fstep">' "$HTML" | wc -l | tr -d ' ')" = "4" ] \
  && grep -q '<td><b>Мастер</b></td>' "$HTML" \
  && grep -q 'rcol now' "$HTML" && grep -q 'rcol next' "$HTML" && grep -q 'rcol later' "$HTML" \
  && grep -q '<dt>Слот</dt><dd>' "$HTML" \
  && grep -q '<div class="tgb bot">Новая запись' "$HTML" && grep -q '<span class="tgbtn">Принять</span>' "$HTML" && grep -q 'данные вымышленные' "$HTML" \
  && ! grep -q '<script' "$HTML"
check "how-it-works sections should render scheme/parts/flow/roles/plan/glossary/tgmock and no JS" $?

# (5) экранирование + **жирный**
python3 - <<'PY'
import json; p='.forge/guide/v1.0.json'; d=json.load(open(p))
d['decisions'][0]['title']='<script>alert(1)</script> & "кавычки"'; d['about']['text']='**главное** и <b>сырой тег</b>'
json.dump(d, open(p,'w'), ensure_ascii=False)
PY
render render >/dev/null
! grep -q '<script>' "$HTML" && grep -q '&lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;кавычки&quot;' "$HTML" && grep -q '<b>главное</b> и &lt;b&gt;сырой тег&lt;/b&gt;' "$HTML"
check "should escape HTML in every text and keep **bold**" $?

# (6) снимки: нет файла — без картинки и без ошибки; есть — data: URI в figure
render render >/dev/null; rc=$?; [ "$rc" -eq 0 ] && ! grep -q '<figure class="shot"' "$HTML"
check "missing screenshot files should not break render" $?
mkdir -p .forge/guide/shots && python3 -c "import base64,pathlib;pathlib.Path('.forge/guide/shots/booking.png').write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='))"
out=$(render render)
grep -q '<figure class="shot"><img src="data:image/png;base64,iVBOR' "$HTML" && grep -q '<figcaption>Форма записи</figcaption>' "$HTML" && printf '%s' "$out" | grep -q 'снимков — 1'
check "existing screenshot should be embedded as data: URI with caption" $?

# (7) bump: +0.1, major → 2.0, прошлые версии целы, changelog забирает pending_changes
out=$(render bump)
[ -f .forge/guide/v1.1.json ] && [ -f "$JSON" ] && [ "$(jget .forge/guide/v1.1.json "d['meta']['version']")" = "1.1" ] \
  && [ "$(jget .forge/guide/v1.1.json "d['changelog'][0]['version']")" = "1.1" ] && [ "$(jget .forge/guide/v1.1.json "d['meta']['previous']")" = "1.0" ] \
  && printf '%s' "$out" | grep -q 'версия 1.1'
check "bump should create v1.1.json from the latest version and keep v1.0.json" $?
render bump major >/dev/null; [ -f .forge/guide/v2.0.json ] && [ "$(jget .forge/guide/v2.0.json "d['meta']['version']")" = "2.0" ]
check "bump major should create v2.0.json" $?
render render >/dev/null; [ -f docs/guide/guide-v2.0.html ] && cmp -s docs/guide/guide-v2.0.html "$LATEST" && [ -f docs/guide/guide-v1.1.html ] || [ ! -f docs/guide/guide-v1.1.html ]
check "render without args should pick the latest version by file name" $?

# (8) verdicts: статусы, текст, 🔥 снимается, R-приоритет, неизвестный код — предупреждение, кириллица в коде
out=$(render verdicts "A1 — ок. B1 - переделать: подтверждаем только по телефону. D1: обсудить голосом. R4 — приоритет выше. Z9 — ок. О1 — ок")
V=.forge/guide/v2.0.json
[ "$(jget $V "[x['status'] for x in d['decisions'] if x['code']=='A1'][0]")" = "accepted" ] \
  && [ "$(jget $V "[x['status'] for x in d['decisions'] if x['code']=='B1'][0]")" = "changed" ] \
  && [ "$(jget $V "[x['what'] for x in d['decisions'] if x['code']=='B1'][0]")" = "подтверждаем только по телефону" ] \
  && [ "$(jget $V "[x['fire'] for x in d['decisions'] if x['code']=='B1'][0]")" = "False" ] \
  && [ "$(jget $V "[x['status'] for x in d['decisions'] if x['code']=='D1'][0]")" = "discuss" ] \
  && [ "$(jget $V "[x['status'] for x in d['decisions'] if x['code']=='O1'][0]")" = "accepted" ] \
  && [ "$(jget $V "[x['block'] for x in d['findings'] if x['id']=='f4'][0]")" = "crit" ] \
  && [ "$(jget $V "len(d['pending_changes'])")" = "5" ] \
  && printf '%s' "$out" | grep -q 'код Z9 не найден' && printf '%s' "$out" | grep -q 'B1 → переделано' \
  && [ "$(grep -o '<span class="fire">' "$LATEST" | wc -l | tr -d ' ')" = "1" ]
check "verdicts should update statuses/text/fire/priority, accept Cyrillic codes and warn on unknown code" $?
out=$(render verdicts "A1 — ну не знаю"); printf '%s' "$out" | grep -q 'не понял' && [ "$(jget $V "[x['status'] for x in d['decisions'] if x['code']=='A1'][0]")" = "accepted" ]
check "verdicts with an unknown verb should keep status and say so" $?

# (9) link / merged / summary — как в v1, на последней версии
out=$(render link f1 confirm-timeout); [ "$(jget $V "[f['task_slug'] for f in d['findings'] if f['id']=='f1'][0]")" = "confirm-timeout" ] && grep -q 'в работе: confirm-timeout' "$LATEST" && printf '%s' "$out" | grep -q 'f1 → задача confirm-timeout'
check "link should attach task slug to the finding and re-render" $?
printf '%s' "$(render link nope-id x)" | grep -q 'карточки nope-id нет'; check "link should report unknown finding id" $?
out=$(render merged confirm-timeout); [ "$(jget $V "[f['status'] for f in d['findings'] if f['id']=='f1'][0]")" = "done" ] && [ "$(jget $V "d['stale_tasks']")" = "1" ] && grep -q 'risk crit done' "$LATEST" && grep -q 'устарел на 1 задачу' "$LATEST" && printf '%s' "$out" | grep -q 'сделано →'
check "merged should mark finding done, bump stale_tasks and re-render" $?
render merged unknown >/dev/null; [ "$(jget $V "d['stale_tasks']")" = "2" ]; check "merged without a match should still bump stale_tasks" $?
out=$(render summary); printf '%s' "$out" | grep -q 'ждут 4 решения владельца' && printf '%s' "$out" | grep -q 'устарел на 2 задачи' && printf '%s' "$out" | grep -q 'guide-latest.html'
check "summary should count unanswered decisions (default/open/discuss + decision findings) and stale tasks" $?
python3 - <<'PY'
import json; p='.forge/guide/v2.0.json'; d=json.load(open(p))
for x in d['decisions']: x['status']='accepted'
for f in d['findings']:
    if f['owner'] in ('decision','both'): f['status']='done'
d['stale_tasks']=0; json.dump(d, open(p,'w'), ensure_ascii=False)
PY
[ -z "$(render summary)" ]; check "summary should stay silent when nothing waits and guide is fresh" $?
cd / && rm -rf "$WORK"

# (10) без гайда: summary/merged молчат, render честно говорит, exit 0
new_project; rmdir .forge/guide
s=$(render summary); rc1=$?; m=$(render merged x); rc2=$?; r=$(render render); rc3=$?
[ "$rc1" -eq 0 ] && [ -z "$s" ] && [ "$rc2" -eq 0 ] && [ -z "$m" ] && [ "$rc3" -eq 0 ] && printf '%s' "$r" | grep -q 'ещё не собирали' && [ ! -d docs ]
check "should exit 0 quietly when there is no guide yet" $?

# (11) init: миграция старого отчёта → v1.0.json, старые файлы убраны; повторный init отказывается
cp "$LEGACY" .forge/status-report.json; echo x > .forge/status-report.html
out=$(render init)
[ -f "$JSON" ] && [ "$(jget "$JSON" "len(d['findings'])")" = "8" ] && [ "$(jget "$JSON" "d['meta']['project']")" = "Lumen" ] \
  && [ "$(jget "$JSON" "[x['code'] for x in d['decisions']]")" = "['P1']" ] && [ ! -f .forge/status-report.json ] && [ ! -f .forge/status-report.html ] \
  && printf '%s' "$out" | grep -q 'перенёс 8 находок'
check "init should migrate legacy status-report.json into .forge/guide/v1.0.json and remove the old files" $?
printf '%s' "$(render init)" | grep -q 'уже есть'; check "init should refuse when a guide exists (use bump)" $?
cd / && rm -rf "$WORK"

# (12) .forge/.gitignore: боевой рендер создаёт полный набор / дописывает недостающее; макет вне .forge не трогает
new_project; cp "$GUIDE" "$JSON"; render render >/dev/null
diff <(printf '%s\n' .inject-state .last-backup .migration-declined state.yml '.github-*' graph.json status-report.html reports/shots/ guide/shots/) .forge/.gitignore >/dev/null
check "render should create .forge/.gitignore with the full forge set (incl. guide/shots/)" $?
printf 'state.yml\n' > .forge/.gitignore; render render >/dev/null; render render >/dev/null
[ "$(wc -l < .forge/.gitignore | tr -d ' ')" = "4" ] && grep -qx 'guide/shots/' .forge/.gitignore && [ "$(head -1 .forge/.gitignore)" = "state.yml" ]
check "render should append only missing lines to an existing .forge/.gitignore (idempotent)" $?
cp "$GUIDE" "$WORK/mock.json"; render render "$WORK/mock.json" .forge/sketches/mock.html >/dev/null
[ -f .forge/sketches/mock.html ] && [ ! -f .forge/sketches/guide-latest.html ] && [ "$(wc -l < .forge/.gitignore | tr -d ' ')" = "4" ]
check "mockup render to an explicit .html should write only that file and leave .gitignore alone" $?
cd / && rm -rf "$WORK"

# (13) находка с неизвестным блоком не теряется (как v1)
new_project; cp "$GUIDE" "$JSON"
python3 - <<'PY'
import json; p='.forge/guide/v1.0.json'; d=json.load(open(p)); d['findings']=d['findings'][:3]
d['findings'][1]['block']='critical'; d['findings'][2].pop('block',None)
for f in d['findings']: f['status']='open'
json.dump(d, open(p,'w'), ensure_ascii=False)
PY
out=$(render render); [ "$(grep -o '<div class="risk ' "$HTML" | wc -l | tr -d ' ')" = "3" ] && printf '%s' "$out" | grep -q 'блок «critical» неизвестен' && printf '%s' "$out" | grep -q 'блок «None» неизвестен'
check "should never drop a finding with unknown/missing block (mid tier + warning)" $?
cd / && rm -rf "$WORK"

# (14) битый JSON во всех режимах: человеческая строка, exit 0; summary молчит
new_project; printf '{ "decisions": [ обрыв' > "$JSON"; broken_ok=0
for m in "render" "merged some-task" "link f1 some-task" "summary" "bump" "verdicts A1 — ок" "pdf"; do
    out=$(render $m); rc=$?
    [ "$rc" -ne 0 ] && { broken_ok=1; echo "  режим «$m»: rc=$rc" >&2; }
    if [ "$m" = "summary" ]; then [ -z "$out" ] || broken_ok=1; else printf '%s' "$out" | grep -q 'повреждён' || { broken_ok=1; echo "  режим «$m»: нет сообщения" >&2; }; fi
done
[ "$broken_ok" -eq 0 ]; check "should survive a broken guide file in every mode" $?
cd / && rm -rf "$WORK"

# (15) pdf: без Chrome — пропуск с честной строкой, exit 0, HTML на месте; с Chrome — файл %PDF (иначе SKIP)
new_project; cp "$GUIDE" "$JSON"; render render >/dev/null
out=$(FORGE_CHROME=/nonexistent/chrome render pdf); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'Chrome не найден — PDF пропущен' && [ ! -f docs/guide/guide-v1.0.pdf ]
check "pdf should skip politely without Chrome (exit 0, HTML stays)" $?
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ -x "$CHROME" ]; then
    out=$(render pdf); [ "$(head -c 4 docs/guide/guide-v1.0.pdf 2>/dev/null)" = "%PDF" ] && printf '%s' "$out" | grep -q 'PDF собран'
    check "pdf should build guide-v1.0.pdf via Chrome headless" $?
else echo "SKIP: pdf via Chrome (no Chrome on this machine)"; fi
cd / && rm -rf "$WORK"
```
--- ПРОВЕРКА:
`bash forge-plugin/tests/hooks/test-guide.sh | tail -3` → RED: почти все FAIL (render.py ещё по старому пути → `python3: can't open file`), последняя строка `N test(s) FAILED`; `ls forge-plugin/tests/hooks/` → test-guide.sh есть, test-status-report.sh нет


===== ШАГ 3: Шаг 3. Рендерер: переезд в skills/project-guide/, модель данных (версии, latest, init/миграция, загрузка) (~25 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/project-guide/render.py (git mv из skills/status-report/render.py); /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/__pycache__ (удалить, не в git)
--- ЧТО:
`git mv forge-plugin/skills/status-report forge-plugin/skills/project-guide && rm -rf forge-plugin/skills/project-guide/__pycache__` (SKILL.md переписывает другой кусок; имя `render.py` оставляем — точки вызова меняют только сегмент каталога, история git цела). Docstring: «Рендерер гайда по проекту (Фаза 5). Режимы: init · render [json] [out.html] · pdf [html] [pdf] · bump [major] · verdicts <text> · merged <slug> · link <id> <slug> · summary. Всегда exit 0, кроме неверных аргументов».

Константы и модель (заменяют DEFAULT_JSON/DEFAULT_HTML, строки 26-27):

```python
GUIDE_DIR = Path(".forge/guide")
DOCS_DIR = Path("docs/guide")
LEGACY_JSON = Path(".forge/status-report.json")
VER_RE = re.compile(r"^v(\d+)\.(\d+)\.json$")
CHROME_CANDIDATES = ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "google-chrome", "chromium", "chromium-browser"]
FORGE_IGNORE = [".inject-state", ".last-backup", ".migration-declined", "state.yml",
                ".github-*", "graph.json", "status-report.html", "reports/shots/", "guide/shots/"]  # построчно = heredoc backup.sh
GUIDE_LINES = ("status-report.html", "reports/shots/", "guide/shots/")


def versions(d=GUIDE_DIR):
    """[(major, minor, path)] по именам файлов. Отдельного latest.json нет — нечему разъехаться."""
    out = []
    for p in Path(d).glob("v*.json"):
        m = VER_RE.match(p.name)
        if m:
            out.append((int(m.group(1)), int(m.group(2)), p))
    return sorted(out)


def latest_json():
    vs = versions()
    return vs[-1][2] if vs else None


def ver_of(data):
    return str((data.get("meta") or {}).get("version", "1.0"))


def read_index():
    """project и version из .forge/index.yml без PyYAML — две строки regex."""
    try:
        t = Path(".forge/index.yml").read_text(encoding="utf-8")
    except OSError:
        return {}
    g = lambda k: (re.search(rf"^{k}:\s*\"?([^\"\n]+?)\"?\s*$", t, re.M) or [None, ""])[1]
    return {"project": g("project").strip(), "project_version": g("version").strip()}


P1 = {"code": "P1", "group": "P", "group_title": "Процесс", "title": "Правило дефолта", "status": "default", "fire": False,
      "since_version": "1.0", "source": "плагин forge",
      "what": "По каждому пункту с меткой «дефолт» есть наша рекомендация. Если возражений нет — действуем по ней и не стоим; передумать можно позже.",
      "why": "Двигает проект вперёд без бесконечных согласований, и всегда видно, что и когда решили."}


def skeleton(today):
    ix = read_index()
    return {"meta": {"project": ix.get("project") or "Проект", "version": "1.0", "project_version": ix.get("project_version", ""),
                     "date": today, "audience": "для владельца проекта", "eyebrow": "", "logo": "", "built_from": ""},
            "updated_at": today, "stale_tasks": 0, "sources": {"analysts": 0, "found": 0},
            "snapshot": {"facts": [], "howto_extra": ""},
            "about": {"text": "", "after": "", "scheme": [], "screens": []},
            "parts": [], "flow": [], "roles": [], "decisions": [dict(P1)], "findings": [],
            "plan": {"now": [], "next": [], "later": []}, "glossary": [], "tg_mocks": [],
            "changelog": [], "pending_changes": []}


def do_init(today):
    if latest_json():
        print(f"FORGE-GUIDE: гайд уже есть ({latest_json()}) — новая версия через render.py bump")
        return
    data = skeleton(today)
    moved = 0
    if LEGACY_JSON.is_file():
        old = load(LEGACY_JSON)                      # битый → ReportBroken, гайд не создаём
        data["findings"] = old.get("findings", [])
        data["sources"] = old.get("sources", data["sources"])
        data["meta"]["project"] = old.get("project") or data["meta"]["project"]
        data["meta"]["eyebrow"] = old.get("eyebrow", "")
        for f in data["findings"]:                   # снимки переезжают вместе с находками
            if str(f.get("screenshot", "")).startswith(".forge/reports/shots/"):
                f["screenshot"] = f["screenshot"].replace(".forge/reports/shots/", ".forge/guide/shots/", 1)
        moved = len(data["findings"])
    GUIDE_DIR.mkdir(parents=True, exist_ok=True)
    save(GUIDE_DIR / "v1.0.json", data)
    if moved or LEGACY_JSON.is_file():
        LEGACY_JSON.unlink(missing_ok=True)
        Path(".forge/status-report.html").unlink(missing_ok=True)
        shots = Path(".forge/reports/shots")
        if shots.is_dir():
            (GUIDE_DIR / "shots").mkdir(exist_ok=True)
            for p in shots.iterdir():
                p.rename(GUIDE_DIR / "shots" / p.name)
    print(f"FORGE-GUIDE: создан {GUIDE_DIR / 'v1.0.json'} — перенёс {moved} находок из старого отчёта, старый отчёт убран" if moved
          else f"FORGE-GUIDE: создан {GUIDE_DIR / 'v1.0.json'} (пустой каркас, P1 заведён)")
```

`cd_repo_root()`: условие `if GUIDE_DIR.is_dir() or LEGACY_JSON.is_file(): return`. `load()` — как было, но сообщение «FORGE-GUIDE: файл гайда повреждён ({path}: {e}) — скажи «собери гайд», пересоберу»; класс переименовать в `GuideBroken` (поведение то же: печать, exit 0). Для merged/link/summary: `jp = latest_json()`; если None → молча exit 0 (легаси-проектам на 7.7 без гайда режимы молчат — первая же «собери гайд» делает init и переносит их находки).
--- ПРОВЕРКА:
`python3 forge-plugin/skills/project-guide/render.py summary; echo rc=$?` в репо → `rc=0` без вывода (гайда ещё нет); `bash forge-plugin/tests/hooks/test-guide.sh | grep -c PASS` → ≥ 4 (пункты (10), (11), (14) частично зелёные); `git status --short | grep -c '^R'` → 2 (render.py и SKILL.md переехали)


===== ШАГ 4: Шаг 4. Рендерер: CSS эталона 1:1 + render_html для разделов 00–08, футер, счётчики, docs/guide + latest (~60 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/project-guide/render.py; /Users/mac/Projects/Plugin/plugin/.forge/tasks/2026-09-06-project-guide/reference-vespera-guide.html (источник CSS, строки 9-109)
--- ЧТО:
1) `CSS` = содержимое `<style>` эталона (строки 9-109) без изменений + дописать в конец:
```css
.acc{font-size:8pt;font-weight:600;background:var(--ok-bg);color:var(--ok);border-radius:5pt;padding:1pt 6pt}
.dsc{font-size:8pt;font-weight:600;background:var(--warn-bg);color:var(--warn);border-radius:5pt;padding:1pt 6pt}
.dcs .was{font-size:8.8pt;color:var(--muted);text-decoration:line-through;margin:2pt 0}
.dcs .vd{font-size:8.8pt;color:var(--accent-d);margin-top:3pt}
.risk.done{opacity:.55}.risk.done .rt{text-decoration:line-through}
.risk .slug{font-family:ui-monospace,Menlo,monospace;font-size:8pt;color:var(--accent-d)}
.risk .shot img{width:100%;border:1pt solid var(--border);border-radius:8pt;margin-top:4pt}
.changes{background:var(--card);border:1pt solid var(--border);border-radius:10pt;padding:8pt 12pt;margin:10pt 0;font-size:9.5pt;break-inside:avoid}
.changes .ct{font-weight:600;color:var(--accent-d)}
.empty{font-size:9.3pt;color:var(--muted);font-style:italic}
```
Тёмной темы у эталона нет — документ печатный, палитра одна (принято по задаче).

2) Шапка `<head>`: `<title>{project} · Гайд по проекту v{ver}</title>`, ссылка на Google Fonts как в эталоне (`Playfair+Display:wght@600;700&family=Golos+Text:wght@400;500;600`), `<style>{CSS}</style>`. Тело — по эталону (строки 114-116): `.brandline` с `.logo` (meta.logo или первая буква project), `.bn` = project, `.bd` = `{audience} · {date} · версия проекта {project_version}` (project_version пуст → без этого куска), `<h1>Гайд по проекту и решения на утверждение · v{ver}</h1>`, `<p class="sub">` из meta.eyebrow/about.text первой фразы.

3) Ключевые функции (все тексты через `esc`, пустой раздел → `<p class="empty">раздел появится в следующей версии</p>`, но `<h2>` печатается всегда — 9 заголовков по порядку):

```python
SECTIONS = [("00", "Где мы сейчас — за 30 секунд"), ("01", "Что это — одной схемой"), ("02", "Из чего состоит"),
            ("03", "Главный путь — по шагам"), ("04", "Роли"), ("05", "Решения на утверждение"),
            ("06", "Карта рисков"), ("07", "План: сейчас → дальше → позже"), ("08", "Словарик")]
UNANSWERED = {"default", "open", "discuss"}
STATUS_CHIP = {"default": ("dflt", "дефолт"), "accepted": ("acc", "принято"), "changed": ("acc", "переделано"),
               "discuss": ("dsc", "обсудить"), "works": ("dflt", "уже работает")}
TIER = {"crit": "crit", "biz": "warn", "imp": "mid", "pol": "mid"}
TIER_HEAD = [("crit", "🔴 Критичные — закрыть в первую очередь"), ("warn", "🟠 Высокие — ближайший месяц"), ("mid", "🟡 Средние — держать в поле зрения")]
GROUP_BASE = {"P": "Процесс", "O": "Открытые вопросы (наших предложений нет)"}

def h2(no, title): return f'<h2><span class="no">{no}</span>{title}</h2>'

def risk_code(f): return "R" + (re.sub(r"\D", "", str(f.get("id", ""))) or "?")

def groups(decisions):
    """P первой, O последней, остальные буквы по алфавиту. P и O есть всегда, даже пустые."""
    seen = {}
    for d in decisions:
        g = str(d.get("group") or d.get("code", "?")[0]).upper()
        seen.setdefault(g, d.get("group_title") or GROUP_BASE.get(g, g))
    for g, t in GROUP_BASE.items():
        seen.setdefault(g, t)
    order = ["P"] + sorted(g for g in seen if g not in ("P", "O")) + ["O"]
    return [(g, seen[g]) for g in order]

def render_decision(d):
    st = d.get("status", "open")
    head = [f'<span class="code{" o" if st == "open" else ""}">{esc(d.get("code"))}</span>']
    if d.get("fire") and st in UNANSWERED:
        head.append('<span class="fire">🔥 эта неделя</span>')
    head.append(f'<span class="dt">{esc(d.get("title"))}</span>')
    chip = STATUS_CHIP.get(st)
    if chip:
        head.append(f'<span class="{chip[0]}">{chip[1]}</span>')
    out = [f'<div class="dcs {esc(st)}"><div class="dh">{"".join(head)}</div>']
    if d.get("what"):
        out.append(f'<div class="what">{esc(d["what"])}</div>')
    if d.get("was"):
        out.append(f'<div class="was">было: {esc(d["was"])}</div>')
    if d.get("why"):
        out.append(f'<div class="why"><b>Почему:</b> {esc(d["why"])}</div>')
    if d.get("verdict"):
        out.append(f'<div class="vd">Ваш ответ {esc(d["verdict"].get("date"))}: {esc(d["verdict"].get("text"))}</div>')
    return "".join(out) + "</div>"

def render_risk(f, base):
    done = f.get("status") == "done"
    tier = TIER.get(f.get("block"), "mid")
    links = ", ".join(str(x) for x in f.get("links", []) or [])
    title = esc(f.get("title")) + (f" (→ {esc(links)})" if links else "")
    out = [f'<div class="risk {tier}{" done" if done else ""}"><div class="rt"><span class="rc">{risk_code(f)}</span>{title}</div>']
    if not done:
        if f.get("why"):
            out.append(f"<p>{esc(f['why'])}</p>")
        if f.get("what"):
            out.append(f"<p><b>Предлагаем:</b> {esc(f['what'])}</p>")
        out.append(img_tag(f.get("screenshot"), f.get("title"), base, caption=""))
    if f.get("task_slug"):
        out.append(f'<p class="slug">→ {"влито" if done else "в работе"}: {esc(f["task_slug"])}</p>')
    return "".join(out) + "</div>"

def render_scheme(boxes):
    parts = []
    for i, b in enumerate(boxes):
        if i:
            parts.append(f'<div class="sarr">→<small>{esc(b.get("arrow", ""))}</small></div>')
        parts.append(f'<div class="sbox"><div class="st">{esc(b.get("title"))}</div><div class="sd">{esc(b.get("text"))}</div></div>')
    return f'<div class="scheme">{"".join(parts)}</div>' if parts else ""

def render_screens(screens, base):
    """Группы по group; 1 снимок → shotwide, 2 → shots2, 3 → shots3, 4+ → shots. Нет файлов — группы нет."""
    by = {}
    for s in screens:
        tag = img_tag(s.get("file"), s.get("caption"), base, caption=s.get("caption", ""))
        if tag:
            by.setdefault(s.get("group", "Экраны"), []).append(tag)
    out = []
    for g, tags in by.items():
        cls = {1: "shotwide", 2: "shots2", 3: "shots3"}.get(len(tags), "shots")
        out.append(f"<h3>{esc(g)}</h3><div class=\"{cls}\">{''.join(tags)}</div>")
    return "".join(out)

def render_plan(plan):
    cols = [("now", "Сейчас · эта неделя"), ("next", "Дальше · 2–4 недели"), ("later", "Позже")]
    out = ['<div class="rmap">']
    for key, title in cols:
        items = plan.get(key) or []
        lis = "".join(f"<li>{esc(i)}</li>" for i in items) or '<li class="empty">пока пусто</li>'
        out.append(f'<div class="rcol {key}"><div class="rh">{title}</div><ul>{lis}</ul></div>')
    return "".join(out) + "</div>"

def render_glossary(items):
    return '<dl class="gl">' + "".join(f"<dt>{esc(g.get('term'))}</dt><dd>{esc(g.get('text'))}</dd>" for g in items) + "</dl>"

def render_tgmock(m):
    bub = []
    for b in m.get("bubbles", []):
        cls = {"bot": "bot", "me": "me", "sys": "sysnote"}.get(b.get("who"), "bot")
        btn = "".join(f'<span class="tgbtn">{esc(x)}</span>' for x in b.get("buttons", []) or [])
        bub.append(f'<div class="tgb {cls}">{esc(b.get("text"))}{f"<div class=\"tgbtns\">{btn}</div>" if btn else ""}</div>')
    return (f'<h3>{esc(m.get("title"))}</h3><div class="tgmock">{"".join(bub)}</div>'
            '<p class="gt">Воспроизведение сообщений бота, данные вымышленные.</p>')
```
`img_tag(shot, alt, base, caption=None)` — расширить: возвращает `<figure class="shot"><img src="data:…" alt="…"><figcaption>…</figcaption></figure>` (figcaption только если caption не None); кандидаты путей и MIME как в v1 (строки 115-124).

4) `render_html(data, base)` собирает по порядку: brandline/h1/sub → `h2(00)` + `.facts` (`<div class="fact"><b>{lead}</b> — {text}</div>`) + `.week` («🔥 Решения, без которых стоим» — `<li><b>{code}</b> — {title}. {why}</li>` для decisions с fire и status ∈ UNANSWERED, в порядке групп; нет ни одного → блок не печатается) + `.howto` (легенда строится из `groups()`: `<b>P*</b> — процесс, …, <b>O*</b> — открытые вопросы, <b>R*</b> — риски` + пример «A2 — ок. B2 — переделать: …. D2 — обсудить. R4 — приоритет выше» + `snapshot.howto_extra`) + `.changes` («Что изменилось в v{ver}» из `changelog[0].items`, если версия ≠ 1.0 и items не пусты) → `h2(01)` + `<p>{about.text}</p>` + scheme + `<p style="font-size:9.5pt;color:var(--text2)">{about.after}</p>` + screens + tg_mocks → `h2(02)` + `.grid2` из parts (`<div class="card svc"><div class="t">{icon} {title} <span class="cd">→ {codes}</span></div><div class="d">{text}</div></div>`) → `h2(03)` + `.flow` из flow (`<div class="fstep"><b>{title}.</b> {text}</div>`) → `h2(04)` + `<table><tr><th>Роль</th><th>Что видит и делает</th></tr>` … → `h2(05)` + `<p class="gt">Каждое — как заложено сейчас и почему. Ждём по каждому: ок / переделать / обсудить.</p>` + по группам `<h3>{g} — {title}</h3>` + карточки (status `dropped` не печатается; пустая группа → `.empty` «пока нет») → `h2(06)` + `<p class="gt">` + по ярусам TIER_HEAD только непустые (`normalize_blocks` из v1 остаётся, неизвестный блок → mid + предупреждение); active = findings со status ≠ deferred, сортировка done в конец яруса; после ярусов, если есть deferred: `<p class="gt">Отложено — N (…)</p>` → `h2(07)` + render_plan → `h2(08)` + render_glossary → `<footer>{project} · собрано из {meta.built_from} · версия {ver} от {meta.date}{' · обновлён {updated_at}, устарел на N задач' если stale_tasks} · вердикты по кодам — списком в чат</footer>`.

5) Счётчики:
```python
def counts(data):
    ds = [d for d in data.get("decisions", []) if d.get("status") != "dropped"]
    fs = data.get("findings", [])
    active = [f for f in fs if f.get("status") != "deferred"]
    return {"decisions": len(ds),
            "waiting": sum(1 for d in ds if d.get("status", "open") in UNANSWERED),
            "fire": sum(1 for d in ds if d.get("fire") and d.get("status", "open") in UNANSWERED),
            "risks": len(active), "crit": sum(1 for f in active if f.get("block") == "crit" and f.get("status") != "done"),
            "done": sum(1 for f in fs if f.get("status") == "done"),
            "deferred": [f for f in fs if f.get("status") == "deferred"],
            "open_decisions": sum(1 for d in ds if d.get("status", "open") in UNANSWERED)
                              + sum(1 for f in fs if f.get("status") == "open" and f.get("owner") in ("decision", "both"))}
```

6) `do_render(json_path, html_path=None)`: `data = load`; `base = Path(json_path).resolve().parents[1 if json_path.parent.name == "guide" else 0]` → корень проекта (`.forge/guide/vX.json` → две ступени вверх; для макета — папка json); если `html_path` задан (макет) → пишем только его; иначе `ensure_gitignore(Path('.forge'))` (когда json внутри `.forge/guide`), `DOCS_DIR.mkdir(parents=True)`, пишем `docs/guide/guide-v{ver}.html` и `shutil.copyfile` → `guide-latest.html`. Печать: `FORGE-GUIDE: v{ver} → {html} (+ guide-latest.html)` и `FORGE-GUIDE: решений {decisions} (ждут ответа {waiting}, 🔥 {fire}), рисков {risks} (крит {crit}), сделано {done}, отложено {len(deferred)}, снимков — {html.count('<figure class="shot"')}`; предупреждения normalize_blocks как в v1 (текст «у находки {id} блок «{bad}» неизвестен — показана в средних»).

`ensure_gitignore`: список GUIDE_LINES вместо двух строк (строка 268 v1).
--- ПРОВЕРКА:
`bash forge-plugin/tests/hooks/test-guide.sh | grep -E 'render should|decisions should|risks should|how-it-works|escape|screenshot|gitignore|mockup|unknown/missing block'` → все PASS; `python3 forge-plugin/skills/project-guide/render.py render forge-plugin/tests/hooks/fixtures/guide-sample.json /tmp/x.html && grep -c '<h2><span class="no">' /tmp/x.html` → 9


===== ШАГ 5: Шаг 5. Макет: фикстура «Lumen» → .forge/sketches/project-guide-mockup.html (+ PDF, если Chrome) → ЧЕКПОИНТ A (~10 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/.forge/sketches/project-guide-mockup.html (создать); /Users/mac/Projects/Plugin/plugin/.forge/sketches/project-guide-mockup.pdf (создать, если Chrome; после чекпоинта удалить — не коммитить); /Users/mac/Projects/Plugin/plugin/.forge/sketches/status-report-mockup.html (удалить — старый формат больше не собирается)
--- ЧТО:
```bash
cd /Users/mac/Projects/Plugin/plugin
python3 forge-plugin/skills/project-guide/render.py render forge-plugin/tests/hooks/fixtures/guide-sample.json .forge/sketches/project-guide-mockup.html
git rm -q .forge/sketches/status-report-mockup.html
open .forge/sketches/project-guide-mockup.html
```
PDF макета — после Шага 7 (режим pdf): `python3 …/render.py pdf .forge/sketches/project-guide-mockup.html` → `.forge/sketches/project-guide-mockup.pdf`, `open` его — владелец видит печатный A4-вид с разрывами страниц. Если Шаг 7 ещё не сделан — чекпоинт только по HTML (в Chrome ⌘P показывает то же самое: `@page A4` в CSS).

**ЧЕКПОИНТ A (владельцу):** «Вот как будет выглядеть гайд на выдуманном проекте Lumen — сравни с гайдом Vespera: шапка, 30 секунд, 🔥, легенда кодов, схема, услуги, шаги, роли, решения с чипами «дефолт / принято / обсудить», риски R-кодами, план в три колонки, словарик. Что поправить в виде?» Правки вида → CSS/render_html + при необходимости тест; данные не трогаем. Ход завершить, ждать ответа.
--- ПРОВЕРКА:
`ls .forge/sketches/` → `project-guide-mockup.html` (status-report-mockup.html нет); `grep -c '<h2><span class="no">' .forge/sketches/project-guide-mockup.html` → 9; `grep -c 'class="fire"' …mockup.html` → 3; в браузере — тёплая палитра, Playfair в заголовках, три карточки 🔥 (B1, D1, O1); `git status --short` не содержит `docs/guide` (макет не трогает боевые пути)


===== ШАГ 6: Шаг 6. Рендерер: bump [major] и verdicts <text> (парсер ответов кодами) (~30 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/project-guide/render.py
--- ЧТО:
```python
def do_bump(major, today):
    vs = versions()
    if not vs:
        print("FORGE-GUIDE: гайда ещё нет — сначала render.py init")
        return
    ma, mi, src = vs[-1]
    data = load(src)
    prev = f"{ma}.{mi}"
    ma, mi = (ma + 1, 0) if major else (ma, mi + 1)
    ver = f"{ma}.{mi}"
    items = data.pop("pending_changes", []) or []
    data.setdefault("changelog", []).insert(0, {"version": ver, "date": today, "items": items})
    data["meta"].update({"version": ver, "date": today, "previous": prev})
    data["updated_at"], data["stale_tasks"] = today, 0
    for f in data.get("findings", []):            # сделанное в прошлой версии показали — теперь убираем из карты
        if f.get("status") == "done" and f.get("done_at", today) < today:
            f["status"] = "deferred"; f["deferred_reason"] = "сделано в прошлой версии"
    dst = GUIDE_DIR / f"v{ver}.json"
    save(dst, data)
    print(f"FORGE-GUIDE: версия {ver} → {dst} (прошлая v{prev} не тронута; в changelog {len(items)} записей)")
```
(Строку про перевод старых done в deferred можно убрать, если владелец захочет видеть «сделано» и через версию — открытый вопрос.)

Парсер вердиктов — три разделителя (— – - :), несколько ответов в одной строке или по строкам, кириллические буквы кодов от голосового ввода:

```python
CYR = str.maketrans("АВСДОРПЕНКМТ", "ABCDOPPEHKMT")   # «А2» с русской А → A2
CODE = r"[A-ZА-Я]{1,2}\d{1,3}"
VERDICT_RE = re.compile(rf"(?<![\w])({CODE})\s*[—–\-:]+\s*(.*?)(?=[\s.;,]*(?<![\w]){CODE}\s*[—–\-:]|\s*$)", re.S)
VERBS = [  # порядок важен: «давайте обсудим» не должно стать «да»
    (("переделать", "переделай", "не так", "иначе", "изменить", "поменять"), "changed"),
    (("обсудить", "обсудим", "голосом", "созвон", "поговорим"), "discuss"),
    (("приоритет выше", "сразу", "срочно", "важнее", "в первую очередь"), "up"),
    (("приоритет ниже", "потом", "не срочно", "неважно", "не важно"), "down"),
    (("отложить", "отложим", "не делаем", "снять"), "deferred"),
    (("сделано", "готово", "работает"), "works"),
    (("ок", "ok", "окей", "да", "так", "принято", "принимаю", "согласен", "согласна", "верно", "оставляем", "норм"), "accepted"),
]

def parse_verdicts(text):
    """«A2 — ок.  B2 - переделать: контакт …  D2: обсудить голосом  R4 — приоритет выше» → [(code, verb|None, note)]"""
    out = []
    for m in VERDICT_RE.finditer(text):
        code = m.group(1).upper().translate(CYR)
        rest = m.group(2).strip().strip(".;,").strip()
        low = rest.lower()
        verb, note = None, rest
        for keys, v in VERBS:
            if any(re.match(rf"{re.escape(k)}(?![а-яa-z])", low) for k in keys):
                verb = v
                note = rest.split(":", 1)[1].strip() if ":" in rest else ""
                break
        out.append((code, verb, note))
    return out

LABEL = {"accepted": "принято", "changed": "переделано", "discuss": "обсудить", "works": "уже работает",
         "up": "приоритет выше", "down": "приоритет ниже", "deferred": "отложено"}

def apply_verdicts(data, text, today):
    by_code = {d.get("code"): d for d in data.get("decisions", [])}
    by_risk = {risk_code(f): f for f in data.get("findings", [])}
    said, warn = [], []
    for code, verb, note in parse_verdicts(text):
        if code in by_code:
            d = by_code[code]
            if verb in ("accepted", "changed", "discuss", "works"):
                d["status"] = verb
                if verb == "changed" and note:
                    d["was"], d["what"] = d.get("what", ""), note
                if verb != "discuss":
                    d["fire"] = False                       # в 🔥 остаются только неотвеченные
                d["verdict"] = {"date": today, "text": note or LABEL[verb]}
            elif verb is None:
                d["note"] = note
                warn.append(f"{code}: не понял вердикт «{note}» — записал как заметку, статус не менял")
                continue
            else:
                warn.append(f"{code}: «{LABEL[verb]}» — это про риски (R), для решения не применил")
                continue
        elif code in by_risk:
            f = by_risk[code]
            if verb == "up":
                f["block"] = "crit"
            elif verb == "down":
                f["block"] = "pol"
            elif verb == "deferred":
                f["status"] = "deferred"
            elif verb in ("works", "accepted"):
                f["status"], f["done_at"] = "done", today
            elif verb == "changed" and note:
                f["what"] = note
            else:
                f["note"] = note
                warn.append(f"{code}: не понял вердикт «{note}» — записал как заметку")
                continue
        else:
            warn.append(f"код {code} не найден в гайде")
            continue
        said.append(f"{code} → {LABEL.get(verb, verb)}" + (f": {note}" if note else ""))
        data.setdefault("pending_changes", []).append(f"{today}: {code} — {LABEL.get(verb, verb)}" + (f" ({note})" if note else ""))
    data["updated_at"] = today
    return said, warn
```
В `run()`: `verdicts` берёт текст как `" ".join(argv[2:])` (в кавычках или без), `jp = latest_json()` (нет → «ещё не собирали»), `apply_verdicts` → `save` → `do_render(jp)` → печать `FORGE-GUIDE: ` + `"; ".join(said)` и отдельной строкой каждое `FORGE-GUIDE: ⚠ {warn}`. Примеры для докстринга: `render.py verdicts "A2 — ок. B2 — переделать: контакт раскрываем только после согласия. D2 — обсудить голосом. R4 — приоритет выше"` → `A2 → принято; B2 → переделано: контакт…; D2 → обсудить; R4 → приоритет выше`.
--- ПРОВЕРКА:
`bash forge-plugin/tests/hooks/test-guide.sh | grep -E 'bump|verdicts|latest version'` → 5 PASS; ручная: `python3 -c "import sys; sys.path.insert(0,'forge-plugin/skills/project-guide'); import render as r; print(r.parse_verdicts('A2 — ок.  B2 - переделать: контакт после согласия.  D2: обсудить голосом\nR4 — приоритет выше. О1 — да'))"` → `[('A2','accepted',''), ('B2','changed','контакт после согласия'), ('D2','discuss',''), ('R4','up',''), ('O1','accepted','')]`


===== ШАГ 7: Шаг 7. Рендерер: режим pdf через Chrome headless (Chrome 152 не завершается сам — ждём файл и гасим) (~20 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/project-guide/render.py
--- ЧТО:
Проверено на этом маке (Chrome 152.0.7977.77, и в песочнице, и без): `--headless --disable-gpu --no-pdf-header-footer --print-to-pdf=<out> file://…` пишет корректный PDF (A4 594×842pt, 2 страницы, `%%EOF`) через ~2.3 с, но **процесс не выходит** даже за 40 с (тянет GoogleUpdater). Поэтому не `subprocess.run(timeout=)`, а Popen + ожидание файла + terminate:

```python
def find_chrome():
    env = os.environ.get("FORGE_CHROME")
    if env:                                   # явный путь — только он (тесты подсовывают /nonexistent)
        return env if Path(env).is_file() else None
    for c in CHROME_CANDIDATES:
        if Path(c).is_file():
            return c
        w = shutil.which(c)
        if w:
            return w
    return None

def do_pdf(html_path, pdf_path):
    if not Path(html_path).is_file():
        print(f"FORGE-GUIDE: нет {html_path} — сначала render"); return
    chrome = find_chrome()
    if not chrome:
        print("FORGE-GUIDE: Chrome не найден — PDF пропущен, есть HTML (поставь Google Chrome или укажи FORGE_CHROME=/путь)"); return
    pdf_path = Path(pdf_path); pdf_path.unlink(missing_ok=True)
    profile = tempfile.mkdtemp(prefix="forge-guide-chrome-")
    cmd = [chrome, "--headless", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
           "--disable-component-update", "--disable-background-networking", "--no-pdf-header-footer",
           f"--user-data-dir={profile}", "--virtual-time-budget=5000",      # даём шрифтам Google Fonts подгрузиться
           f"--print-to-pdf={pdf_path.resolve()}", Path(html_path).resolve().as_uri()]
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as e:
        print(f"FORGE-GUIDE: Chrome не запустился ({e}) — PDF пропущен, есть HTML"); return
    deadline, last, stable = time.time() + 60, -1, 0
    while time.time() < deadline and stable < 4:          # файл появился и секунду не растёт → готов
        if p.poll() is not None:
            break
        size = pdf_path.stat().st_size if pdf_path.is_file() else 0
        stable = stable + 1 if size and size == last else 0
        last = size
        time.sleep(0.25)
    if p.poll() is None:
        p.terminate()
        try: p.wait(5)
        except subprocess.TimeoutExpired: p.kill()
    shutil.rmtree(profile, ignore_errors=True)
    ok = pdf_path.is_file() and pdf_path.read_bytes()[:4] == b"%PDF"
    print(f"FORGE-GUIDE: PDF собран → {pdf_path}" if ok else "FORGE-GUIDE: Chrome не отдал PDF за 60 с — пропущен, есть HTML")
```
Импорты: `shutil, tempfile, time`. В `run()`: `pdf [html] [pdf]` — по умолчанию html = `DOCS_DIR/guide-v{ver}.html` последней версии (ver из latest_json), pdf = тот же путь с `.pdf`; для макета `pdf .forge/sketches/project-guide-mockup.html` → рядом `.pdf`. `guide-latest.pdf` не делаем (по задаче — только HTML-latest). Битый JSON при вычислении версии → GuideBroken как в остальных режимах.
--- ПРОВЕРКА:
`bash forge-plugin/tests/hooks/test-guide.sh | grep -E 'pdf'` → `PASS: pdf should skip politely…` и `PASS: pdf should build guide-v1.0.pdf via Chrome headless`; вручную: `cd $(mktemp -d) && mkdir -p .forge/guide && cp <repo>/forge-plugin/tests/hooks/fixtures/guide-sample.json .forge/guide/v1.0.json && python3 <repo>/forge-plugin/skills/project-guide/render.py render && time python3 <repo>/forge-plugin/skills/project-guide/render.py pdf` → «PDF собран → docs/guide/guide-v1.0.pdf», real ≤ 10 с; `python3 -c "import re;b=open('docs/guide/guide-v1.0.pdf','rb').read();print(len(re.findall(rb'/Type\s*/Page[^s]',b)))"` → ≥ 3 страниц; `pgrep -f forge-guide-chrome` → пусто (Chrome погашен)


===== ШАГ 8: Шаг 8. merged / link / summary на последней версии + синхронизация игнора (FORGE_IGNORE ↔ backup.sh) + docs/guide в бэкап (~20 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/project-guide/render.py; /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/memory-backup/backup.sh (строки 35-44 heredoc; 47, 52, 54); /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-memory-backup.sh (строки 86-89); /Users/mac/Projects/Plugin/plugin/.forge/.gitignore
--- ЧТО:
1) `run()` — merged/link: как в v1 (строки 317-358), но `jp = latest_json()` (None → exit 0 молча), после изменения `save(jp)` + `do_render(jp)` (в docs/guide, обе HTML); merged дополнительно `data.setdefault("pending_changes", []).append(f"{today}: R{n} — сделано: {title} (задача {slug})")` для каждой закрытой находки — так следующий bump сам получит запись в changelog. Тексты вывода — с префиксом `FORGE-GUIDE:`, формулировки v1 («сделано → …; гайд устарел на N задач», «карточки {fid} нет», «карточка {fid} → задача {slug}»).

2) summary:
```python
    elif mode == "summary":
        jp = latest_json()
        if not jp: return 0
        try: data = load(jp)
        except Exception: return 0
        c = counts(data); stale = int(data.get("stale_tasks", 0) or 0); bits = []
        if c["open_decisions"]: bits.append(f"ждут {plural(c['open_decisions'], 'решение', 'решения', 'решений')} владельца")
        if stale: bits.append(f"гайд устарел на {plural(stale, 'задачу', 'задачи', 'задач')}")
        if bits:
            print(f"📖 Гайд по проекту v{ver_of(data)}: " + ", ".join(bits) + " (docs/guide/guide-latest.html; ответы — кодами в чат, пересобрать — «собери гайд»)")
```

3) `backup.sh`: heredoc (строки 35-44) — после `reports/shots/` добавить строку `guide/shots/` (список обязан быть построчно равен `FORGE_IGNORE` — тест (12) проверяет diff). Стык с docs/guide (по принятому решению «backup.sh дополнительно добавляет docs/guide/»): строка 47 → `git add .forge >/dev/null 2>&1 || true; [ -d docs/guide ] && git add docs/guide >/dev/null 2>&1 || true`; строка 52 → `git diff --cached --quiet -- .forge docs/guide`; строка 54 → `git commit -q -m "[forge] память: ${msg}" -- .forge docs/guide` (git спокойно принимает несуществующий путь после `--`, если он не в индексе — проверить в тесте memory-backup: проект без docs/ коммитится как раньше). `test-memory-backup.sh:88` добавить `&& grep -qx "guide/shots/" .forge/.gitignore`; новая проверка: `mkdir -p docs/guide && echo x > docs/guide/guide-v1.0.html && bash backup.sh` → `git show --stat HEAD | grep -q docs/guide/guide-v1.0.html`.

4) `.forge/.gitignore` репозитория плагина: дописать `guide/shots/` (render сам допишет при первой боевой сборке, но фиксируем явно).
--- ПРОВЕРКА:
`bash forge-plugin/tests/hooks/test-guide.sh | tail -1` → `All tests passed` (≈ 30 проверок); `bash forge-plugin/tests/hooks/test-memory-backup.sh | tail -1` → `All tests passed`; `diff <(sed -n '36,44p' forge-plugin/skills/memory-backup/backup.sh) <(python3 -c "import sys;sys.path.insert(0,'forge-plugin/skills/project-guide');import render;print('\n'.join(render.FORGE_IGNORE))")` → пусто


===== ШАГ 9: Шаг 9. Первая боевая сборка на этом репо: init (миграция 21 находки) → шаблон для скилла → полный прогон тестов (~15 мин)
ФАЙЛЫ: /Users/mac/Projects/Plugin/plugin/.forge/guide/v1.0.json (создаётся init); /Users/mac/Projects/Plugin/plugin/.forge/status-report.json (удаляется init — данные переезжают в v1.0.json); /Users/mac/Projects/Plugin/plugin/.forge/status-report.html (удаляется); /Users/mac/Projects/Plugin/plugin/docs/guide/ (создаётся render)
--- ЧТО:
Это стык с куском «скилл/команда» (наполнение разделов делает скилл через product-mapping + decisions.yml + аналитиков), здесь — только механика на живых данных: `python3 forge-plugin/skills/project-guide/render.py init` → «перенёс 21 находок»; `render` → `docs/guide/guide-v1.0.html` с разделами 06/07 из находок и пустыми «раздел появится в следующей версии»; `pdf`. Затем `git status --short` — убедиться, что `.forge/status-report.json` ушёл как удалённый, `.forge/guide/v1.0.json` и `docs/guide/*.html|pdf` новые, `.forge/guide/shots/` не появился в статусе. Полный прогон:
```bash
for t in forge-plugin/tests/hooks/test-*.sh; do printf '%s: ' "$t"; bash "$t" | tail -1; done
grep -rn 'skills/status-report/render.py' forge-plugin CLAUDE.md GUIDE.md | grep -v '^forge-plugin/docs/' 
```
Второй grep показывает точки вызова, которые обязан переписать другой кусок (session-start.sh:56,58; new-task/SKILL.md:108; finishing/SKILL.md:133) — пока они не переписаны, test-session-start красный по (3)-(5), это ожидаемо и фиксируется в стыках.
--- ПРОВЕРКА:
`ls .forge/guide docs/guide` → `v1.0.json` и `guide-v1.0.html guide-latest.html guide-v1.0.pdf`; `python3 -c "import json;d=json.load(open('.forge/guide/v1.0.json'));print(len(d['findings']),d['meta']['project'],d['meta']['project_version'])"` → `21 forge-plugin 7.7.0`; `python3 forge-plugin/skills/project-guide/render.py summary` → строка «📖 Гайд по проекту v1.0: ждут 5 решений владельца …» (P1 default + 4 decision/both-находки); test-guide.sh и test-memory-backup.sh → `All tests passed`


===== INTERFACES:
## Файлы и папки
- Рендерер: `forge-plugin/skills/project-guide/render.py` (git mv из `skills/status-report/`; имя файла `render.py` сохранено — точки вызова меняют только сегмент каталога: `session-start.sh:56,58`, `new-task/SKILL.md:108`, `finishing-a-development-branch/SKILL.md:133`, `statusline.sh:33` (case `project-guide|"Phase 5"|5`)). Причина переезда каталога: правило «скилл = директория + SKILL.md», а скилл и команда переименовываются в guide другим куском; каталог `status-report` со скиллом `project-guide` внутри — путаница в `find ~/.claude/plugins -path "*/project-guide/*"`.
- Данные (память, коммитятся backup.sh): `.forge/guide/v1.0.json`, `v1.1.json`, … `v2.0.json`. Последняя версия = максимум (major, minor) по именам файлов `^v(\d+)\.(\d+)\.json$` — отдельного latest.json нет. Снимки: `.forge/guide/shots/*.png|jpg|webp` (в `.forge/.gitignore` строкой `guide/shots/`; в HTML встраиваются data: URI). Легаси `.forge/status-report.json` + `.html` + `reports/shots/` — при `render.py init` находки и снимки переносятся в v1.0.json / guide/shots, старые файлы удаляются (история есть в git).
- Витрина (коммитится): `docs/guide/guide-v{X.Y}.html`, `docs/guide/guide-latest.html` (побайтовая копия последней), `docs/guide/guide-v{X.Y}.pdf`. Макет: `.forge/sketches/project-guide-mockup.html` (режим `render <json> <out.html>` — только этот файл, без latest и без правки .gitignore).

## CLI render.py (всегда exit 0, кроме неверных аргументов; служебные строки с префиксом `FORGE-GUIDE:` владельцу не показываются)
- `init` — создать `.forge/guide/v1.0.json` (каркас + P1 «Правило дефолта»; project/version из `.forge/index.yml` regex-ом), перенести находки из `.forge/status-report.json`, если есть. Гайд уже есть → отказ «уже есть — bump».
- `render [json] [out.html]` — без аргументов: последняя версия → `docs/guide/guide-v{ver}.html` + `guide-latest.html`, `ensure_gitignore(.forge)`; печатает 2 строки: путь и счётчики `решений N (ждут ответа K, 🔥 F), рисков R (крит C), сделано D, отложено X, снимков — S`.
- `pdf [html] [pdf]` — Chrome headless (`$FORGE_CHROME` → иначе `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` → `which google-chrome|chromium`); флаги `--headless --disable-gpu --no-first-run --no-default-browser-check --disable-component-update --disable-background-networking --no-pdf-header-footer --user-data-dir=<tmp> --virtual-time-budget=5000 --print-to-pdf=<abs> file://<abs>`; Popen + ожидание файла (стабильный размер 1 с, потолок 60 с) + terminate. Нет Chrome → `FORGE-GUIDE: Chrome не найден — PDF пропущен, есть HTML`.
- `bump [major]` — копия последней версии в `v{X.Y+1}.json` (major → `v{X+1}.0.json`), `meta.version/date/previous`, `changelog.insert(0, {version, date, items: pending_changes})`, `pending_changes=[]`, `stale_tasks=0`. Печать «версия X.Y → путь». Наполнение новой версии дальше делает скилл (Edit JSON) → `render` → `pdf`.
- `verdicts <text…>` — парсит «A2 — ок. B2 — переделать: … D2 — обсудить. R4 — приоритет выше» (разделители — – - :, несколько на строке, кириллица в кодах нормализуется); решения: ок/да/принято → accepted (fire=false), переделать: текст → changed (what=новый, was=старый, fire=false), обсудить → discuss (🔥 остаётся), сделано/работает → works; риски R<n>: приоритет выше → block=crit, ниже → pol, отложить → deferred, ок/сделано → done, переделать: → what. Неизвестный код → `FORGE-GUIDE: ⚠ код Z9 не найден в гайде`; неизвестный глагол → заметка в `note`, статус не меняется. Пишет `pending_changes`, `updated_at`, пересобирает HTML.
- `merged <slug>` / `link <id> <slug>` / `summary` — как в v1, на последней версии; merged дописывает `pending_changes`. summary: `📖 Гайд по проекту v1.2: ждут N решений владельца, гайд устарел на M задач (docs/guide/guide-latest.html; ответы — кодами в чат, пересобрать — «собери гайд»)`; молчит, когда нечего; N = decisions со status default|open|discuss + findings status=open с owner decision|both.

## Схема JSON (`.forge/guide/vX.Y.json`)
```
meta{project, version "1.0", project_version (из index.yml), date, audience, eyebrow, logo, built_from, previous?}
updated_at, stale_tasks, sources{analysts, found}
snapshot{facts[{lead, text}], howto_extra}          # 🔥-список и легенда кодов НЕ хранятся — выводятся из decisions (fire+status) и групп
about{text, after, scheme[{arrow?, title, text}], screens[{file, caption, group}]}
parts[{icon, title, text, codes[]}]  flow[{title, text}]  roles[{role, does}]
decisions[{code "A2", group "A", group_title, title, what, why, status default|accepted|changed|discuss|open|works|dropped, fire bool, since_version, source, was?, verdict{date,text}?, note?}]
findings[ как в v1: id f<n>, owner code|decision|both, effort, block crit|biz|imp|pol, status open|done|deferred, title, what, why, source, task_slug?, screenshot?, done_at?, + links[] коды решений ]
plan{now[], next[], later[]}  glossary[{term, text}]  tg_mocks[{title, bubbles[{who bot|me|sys, text, buttons[]}]}]
changelog[{version, date, items[]}]  pending_changes[]   # накопитель verdicts/merged до следующего bump
```
Рендер рисков из findings: код `R<n>` = число из id (f7 → R7), ярус crit→🔴 crit, biz→🟠 warn, imp/pol→🟡 mid, описание = why, «Предлагаем:» = what, «(→ D1, B2)» = links, done — зачёркнуто в конце яруса, deferred — строкой «Отложено — N» под картой.

## Стабильность кодов между версиями
- Код никогда не переиспользуется. Новое решение = max номер в группе (включая status dropped) + 1. Убранное решение не удаляется из JSON, а получает `status: dropped` (в HTML не печатается) — номер остаётся занятым. `since_version` фиксирует, в какой версии появилось.
- R-коды привязаны к id находки, а id f<n> по правилу v1 не меняется и не переиспользуется → R<n> стабилен автоматически; закрытая находка остаётся с `done`, её R-номер никому не достаётся.
- Группы: P и O печатаются всегда (в порядке P, буквы A..Z без O по алфавиту, O последней; R — это раздел 06, не группа решений). Буквы под проект — `group` + `group_title` в decisions.

## Стыки с другими кусками (они должны сделать)
- session-start.sh:55-58: условие `[ -d .forge/guide ]`, вызов `skills/project-guide/render.py summary`, текст напоминания про «ответы кодами в чат → render.py verdicts "…"» вместо Edit статуса; test-session-start.sh (3)-(5): данные в `.forge/guide/v1.0.json`, grep «ждут 2 решения владельца» / «гайд устарел на 3 задачи» / тишина по «📖 Гайд».
- finishing SKILL.md:131-135 и new-task SKILL.md:106-110: путь `skills/project-guide/render.py`, слова «гайд» вместо «отчёт»; finishing: после merged в коммит задачи попадёт и `docs/guide/*.html` (git add -A) — это по замыслу.
- backup.sh: heredoc +`guide/shots/`; `git add docs/guide`, `--quiet -- .forge docs/guide`, `commit -- .forge docs/guide` (Шаг 8 здесь, но SKILL.md memory-backup:46 — текст про guide/shots и docs/guide — у куска документации).
- Скилл guide: последовательность `init` (первый раз) или `bump` → Edit JSON (product-mapping → about/parts/flow/roles; decisions.yml → decisions; аналитики → findings/plan/O-группа) → снимки в `.forge/guide/shots/` → `render` → `pdf` → `open docs/guide/guide-latest.html`. Ответы кодами → `render.py verdicts "<текст владельца>"` + запись в decisions.yml.
- statusline.sh:33 — `project-guide|status-report|"Phase 5"|5) phase_icon="📖 Фаза 5: Гайд"`.


===== OPEN:
- Статус «обсудить» — оставлять в 🔥 или считать ответом? В плане: остаётся в 🔥 (стоим, пока не поговорили), но fire снимается у accepted/changed/works. Если владелец хочет иначе — одна строка в apply_verdicts.
- Считать ли «дефолт»-решения ждущими ответа в напоминании session-start («ждут N решений»)? По брифу — да (open|default|discuss); на живом репо это даст «ждут 5» сразу после первой сборки из-за P1.
- bump переводит находки со status done из прошлой версии в deferred (чтобы «сделано» не висело в карте рисков вечно) — или показывать «сделано» ещё одну версию? В плане переводятся; убрать — 3 строки в do_bump.
- Легаси-проекты на v7.7 без гайда: merged/link/summary молчат до первой «собери гайд» (init). Альтернатива — fallback на старый status-report.json в этих режимах (+5 строк), но тогда напоминание ссылалось бы на несуществующий docs/guide.
- docs/guide/*.html со встроенными снимками (data: URI) коммитится в каждой версии — рост репозитория ~0.2–1 МБ на версию при 4–6 снимках. Ограничить снимки ≤ 6 и шириной 1280 (как в v1) — достаточно? Или хранить в HTML ссылки на .forge/guide/shots, а data: URI встраивать только в PDF?
- Тёмной темы у эталона нет (печатный документ) — план оставляет одну светлую палитру. Подтвердить, что гайд в браузере тёмную тему не обязан поддерживать.

===== RISKS:
- Chrome 152 на маке владельца после --print-to-pdf НЕ завершается (проверено: PDF готов через 2.3 с, процесс висит >40 с, и в песочнице, и без). Любой subprocess.run(timeout) без ожидания файла либо повиснет, либо сочтёт сборку провалом — режим pdf обязан ждать файл и гасить процесс (Шаг 7).
- FORGE_IGNORE в render.py и heredoc в backup.sh должны совпадать построчно — тест (12) сравнивает diff. Правятся в разных шагах/кусках; рассинхрон = красный тест.
- test-session-start.sh (3)-(5) и test-memory-backup.sh:87-88 завязаны на .forge/status-report.json и «📊 Отчёт» — пока кусок хуков не переписан, сьют session-start красный по трём проверкам; в Шаге 9 это ожидаемо и должно быть закрыто до мержа.
- Парсер вердиктов на голосовом вводе: «А2» с русской А, «Р4» вместо R4, «окей/норм/давай» — покрыто нормализацией и списком глаголов, но неизвестные формулировки уходят в note без смены статуса; владелец увидит ⚠-строку только если скилл её покажет.
- Двойной учёт «ждут решений»: находка с owner decision и решение из decisions[] про то же самое считаются дважды; правило для скилла — при переносе находки в O-группу ставить находке status done (или deferred), иначе summary завышает.
- Google Fonts в PDF: без сети Chrome напечатает системными шрифтами (Playfair/Golos не встроены) — вид PDF офлайн отличается от HTML в браузере с кэшем; --virtual-time-budget=5000 даёт шрифтам время, но не гарантирует.
- docs/guide попадает в коммит задачи при finishing (git add -A) и в коммит памяти (backup.sh) — при одновременных правках возможны два коммита с одним HTML; безвредно, но история шумнее.
- Удаление .forge/status-report.json при init необратимо для проектов без git — данные внутри v1.0.json сохранены, но если init упадёт после unlink (порядок: сначала save v1.0.json, потом unlink — падение между ними маловероятно), старый файл потерян.
