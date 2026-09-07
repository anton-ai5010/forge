#!/usr/bin/env bash
# Тесты для skills/project-guide/render.py — рендерер гайда по проекту (Фаза 5).
# JSON (.forge/guide/vX.Y.json) → docs/guide/guide-vX.Y.html + guide-latest.html,
# версии (bump), ответы владельца (verdict), PDF, обновление после мержа (merged),
# привязка к задаче (link), строка-напоминание для session-start (summary).
# Прогоняется в изолированной tmp-директории (cwd = «корень проекта», как в бою).
#
# FORGE_TEST_PDF=1 — дополнительно прогнать сборку PDF живым Chrome (иначе SKIP).

set -uo pipefail

export FORGE_CHROME=/nonexistent   # PDF в тестах не собирается — только по FORGE_TEST_PDF=1

RENDER="$(cd "$(dirname "$0")/../../skills/project-guide" && pwd)/render.py"
FIX="$(cd "$(dirname "$0")/fixtures" && pwd)"
GUIDE=$FIX/guide-sample.json
LEGACY=$FIX/status-report-sample.json    # старый отчёт «Что дальше» (LEGACY) — для теста миграции
fails=0

check() {
    local desc="$1" ok="$2"
    if [ "$ok" -eq 0 ]; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc"
        fails=$((fails + 1))
    fi
}

# Обычная функция (НЕ через $()): cd должен пережить вызов
WORK=""
new_project() {
    WORK=$(mktemp -d)
    cd "$WORK" || exit 1
    mkdir -p .forge/guide
}

render() { python3 "$RENDER" "$@" 2>&1; }

# JSON-поле через python3 (PyYAML нет, json — стандартная библиотека): jget <файл> <выражение над d>
# eval здесь — тестовый хелпер с выражениями, зашитыми в этом файле; пользовательский ввод не попадает.
jget() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))" "$1" "$2"; }
dec() { jget "$1" "[x.get('$3') for x in d['decisions'] if x['code']=='$2'][0]"; }   # dec <json> <код> <поле>
fnd() { jget "$1" "[x.get('$3') for x in d['findings'] if x['id']=='$2'][0]"; }      # fnd <json> <id> <поле>

JSON=.forge/guide/v1.0.json
HTML=docs/guide/guide-v1.0.html
LATEST=docs/guide/guide-latest.html
TODAY=$(date +%F)

# ===== (1) render: обе HTML, 9 разделов по порядку, шапка с версией/аудиторией, счётчики в stdout, built_at =====
# Фикстура: 7 решений, из них A3 dropped (не считается и не печатается) → «решений 6»;
# ждут ответа = default|open|discuss = P1, A1, B1, D1, O1 → 5; 🔥 = B1, D1, O1 → 3;
# рисков = находки кроме deferred (f8) → 7.

new_project; cp "$GUIDE" "$JSON"
out=$(render render)
[ -f "$HTML" ] && [ -f "$LATEST" ] && cmp -s "$HTML" "$LATEST" \
  && [ "$(grep -o '<h2><span class="no">[0-9][0-9]</span>' "$HTML" | wc -l | tr -d ' ')" = "9" ] \
  && grep -q '<span class="no">00</span>Где мы сейчас' "$HTML" && grep -q '<span class="no">08</span>Словарик' "$HTML" \
  && grep -q '<title>Lumen · Гайд по проекту v1.0</title>' "$HTML" \
  && grep -q 'для владельца сети салонов' "$HTML" && grep -q 'версия проекта 0.9.2' "$HTML" \
  && printf '%s' "$out" | grep -q 'решений 6 (ждут ответа 5, 🔥 3), рисков 7' \
  && ! grep -q '<span class="code">A3</span>' "$HTML" \
  && [ "$(jget "$JSON" "d['built_at']")" = "$TODAY" ]
check "render should write guide-v1.0.html + guide-latest.html with 9 sections, header meta, honest counters and today's built_at" $?

# порядок разделов 00..08
[ "$(grep -o '<h2><span class="no">[0-9][0-9]</span>' "$HTML" | sed 's/.*">//;s/<.*//' | tr '\n' ' ')" = "00 01 02 03 04 05 06 07 08 " ]
check "sections should go 00..08 in order" $?

# ===== (2) решения: карточки с кодами, чипы статусов, 🔥 только у неотвеченных, легенда P/R всегда, howto, футер =====
grep -q '<span class="code">P1</span>' "$HTML" && grep -q '<span class="code o">O1</span>' "$HTML" \
  && grep -q '<span class="code">A2</span>.*<span class="acc">принято</span>' "$HTML" \
  && grep -q '<span class="code">D1</span><span class="fire">🔥 эта неделя</span>.*<span class="dsc">обсудить</span>' "$HTML" \
  && [ "$(grep -o '<span class="fire">' "$HTML" | wc -l | tr -d ' ')" = "3" ] \
  && grep -q '<li><b>B1</b> — Автоподтверждение' "$HTML" && ! grep -q '<li><b>A2</b>' "$HTML" \
  && grep -q '<b>P\*</b> — процесс' "$HTML" && grep -q '<b>R\*</b> — риски' "$HTML" && grep -q '<b>D\*</b> — деньги' "$HTML"
check "decisions should render codes, status chips, fire only on unanswered, P/R legend always" $?

grep -q 'class="howto"' "$HTML" && grep -q 'Метка 🔥' "$HTML" && grep -q 'Метка «дефолт»' "$HTML" \
  && grep -q 'После ваших ответов следующая версия' "$HTML" \
  && ! grep -q 'в чат' "$HTML" \
  && grep -q 'код проекта, память .forge, созвон 30.08' "$HTML" \
  && ! grep -q 'после сборки' "$HTML"
check "howto should explain fire/default/where to answer; footer built_from without «в чат» and without stale note when fresh" $?

# ===== (3) риски из находок: R<n> по id, ярус по block, «Предлагаем» = what, ссылки на коды, pol в средних, deferred не показан =====
grep -q '<div class="risk crit"><div class="rt"><span class="rc">R2</span>Предоплата списана.*(→ D1)' "$HTML" \
  && grep -q '<span class="rc">R5</span>' "$HTML" && grep -q 'risk mid.*<span class="rc">R7</span>' "$HTML" \
  && ! grep -q '<span class="rc">R8</span>' "$HTML" && grep -q '<b>Предлагаем:</b> Оплату и создание записи' "$HTML" \
  && grep -q '🔴 Критичные' "$HTML" && grep -q '🟠 Высокие' "$HTML" && grep -q '🟡 Средние' "$HTML" \
  && grep -q 'Отложено — 1' "$HTML" \
  && ! grep -q 'class="slug"' "$HTML"
check "risks should derive R<n> from finding id, tier from block, propose from what, deferred as a line, no slug when no task" $?

# ===== (4) устройство: схема со стрелками, части с кодами, шаги, роли, план 3 колонки, словарик, tg-диалог, без JS =====
grep -q '<div class="sarr">→<small>запись</small></div>' "$HTML" && [ "$(grep -o '<div class="sbox">' "$HTML" | wc -l | tr -d ' ')" = "3" ] \
  && grep -q 'class="cd">→ D1</span>' "$HTML" && [ "$(grep -o '<div class="fstep">' "$HTML" | wc -l | tr -d ' ')" = "4" ] \
  && grep -q '<td><b>Мастер</b></td>' "$HTML" \
  && grep -q 'rcol now' "$HTML" && grep -q 'rcol next' "$HTML" && grep -q 'rcol later' "$HTML" \
  && grep -q '<dt>Слот</dt><dd>' "$HTML" \
  && grep -q '<div class="tgb bot">Новая запись' "$HTML" && grep -q '<span class="tgbtn">Принять</span>' "$HTML" && grep -q 'данные вымышленные' "$HTML" \
  && ! grep -q '<script' "$HTML"
check "how-it-works sections should render scheme/parts/flow/roles/plan/glossary/tgmock and no JS" $?

# ===== (5) экранирование + **жирный** =====
python3 - <<'PY'
import json; p='.forge/guide/v1.0.json'; d=json.load(open(p))
d['decisions'][0]['title']='<script>alert(1)</script> & "кавычки"'; d['about']['text']='**главное** и <b>сырой тег</b>'
json.dump(d, open(p,'w'), ensure_ascii=False)
PY
render render >/dev/null
! grep -q '<script>' "$HTML" && grep -q '&lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;кавычки&quot;' "$HTML" && grep -q '<b>главное</b> и &lt;b&gt;сырой тег&lt;/b&gt;' "$HTML"
check "should escape HTML in every text and keep **bold**" $?

# ===== (6) снимки: нет файла — без картинки и без ошибки; есть — data: URI в figure; base из поддиректории =====
render render >/dev/null; rc=$?; [ "$rc" -eq 0 ] && ! grep -q '<figure class="shot"' "$HTML"
check "missing screenshot files should not break render" $?
mkdir -p .forge/guide/shots && python3 -c "import base64,pathlib;pathlib.Path('.forge/guide/shots/booking.png').write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='))"
out=$(render render)
grep -q '<figure class="shot"><img src="data:image/png;base64,iVBOR' "$HTML" && grep -q '<figcaption>Форма записи</figcaption>' "$HTML" && printf '%s' "$out" | grep -q 'снимков — 1'
check "existing screenshot should be embedded as data: URI with caption" $?
mkdir -p sub && (cd sub && render render ../.forge/guide/v1.0.json ../mock.html >/dev/null)
[ -f mock.html ] && grep -q '<figure class="shot"><img src="data:image/png;base64,iVBOR' mock.html && [ ! -f sub/mock.html ]
check "render with explicit paths from a subdirectory should find screenshots via the project base" $?
rm -rf sub mock.html

# ===== (7) bump: +0.1, major → 2.0, прошлые версии целы, changelog забирает pending_changes, built_at null, отказ на несобранной =====
python3 - <<'PY'
import json; p='.forge/guide/v1.0.json'; d=json.load(open(p))
d['pending_changes']=['2026-09-06: тест-запись для changelog']
json.dump(d, open(p,'w'), ensure_ascii=False)
PY
out=$(render bump)
V11=.forge/guide/v1.1.json
[ -f "$V11" ] && [ -f "$JSON" ] && [ "$(jget "$V11" "d['meta']['version']")" = "1.1" ] \
  && [ "$(jget "$V11" "d['changelog'][0]['version']")" = "1.1" ] && [ "$(jget "$V11" "d['changelog'][0]['items']")" = "['2026-09-06: тест-запись для changelog']" ] \
  && [ "$(jget "$V11" "d['pending_changes']")" = "[]" ] && [ "$(jget "$V11" "d['meta']['previous']")" = "1.0" ] \
  && [ "$(jget "$V11" "d['built_at']")" = "None" ] && [ "$(jget "$V11" "d['stale_tasks']")" = "0" ] \
  && [ "$(jget "$JSON" "d['pending_changes']")" = "['2026-09-06: тест-запись для changelog']" ] \
  && printf '%s' "$out" | grep -q 'версия 1.1'
check "bump should create v1.1.json (built_at null, changelog from pending_changes) and keep v1.0.json intact" $?
out=$(render bump); [ ! -f .forge/guide/v1.2.json ] && printf '%s' "$out" | grep -q 'v1.1 ещё не собрана'
check "bump should refuse while the latest version is not built yet" $?
# ответ на несобранной версии: только JSON, HTML не трогаем
out=$(render verdict A1 discuss)
[ "$(dec "$V11" A1 status)" = "discuss" ] && [ ! -f docs/guide/guide-v1.1.html ] && printf '%s' "$out" | grep -q 'HTML не перерисован' \
  && [ "$(jget "$V11" "d['built_at']")" = "None" ]
check "verdict on an unbuilt version should update JSON only and say HTML was not re-rendered" $?
out=$(render render)
[ -f docs/guide/guide-v1.1.html ] && cmp -s docs/guide/guide-v1.1.html "$LATEST" && [ "$(jget "$V11" "d['built_at']")" = "$TODAY" ] \
  && grep -q 'class="changes"' docs/guide/guide-v1.1.html && grep -q 'тест-запись для changelog' docs/guide/guide-v1.1.html \
  && grep -q 'v1.0' docs/guide/guide-v1.1.html
check "render without args should build the latest version, set built_at and show «what changed since v1.0»" $?
render bump major >/dev/null; [ -f .forge/guide/v2.0.json ] && [ "$(jget .forge/guide/v2.0.json "d['meta']['version']")" = "2.0" ] && [ "$(jget .forge/guide/v2.0.json "d['meta']['previous']")" = "1.1" ]
check "bump major should create v2.0.json" $?
render render >/dev/null; [ -f docs/guide/guide-v2.0.html ] && cmp -s docs/guide/guide-v2.0.html "$LATEST" && [ -f docs/guide/guide-v1.1.html ] && [ -f "$HTML" ]
check "render without args should pick the latest version by file name and leave older HTML alone" $?

# ===== (8) verdict <код> <статус> [текст]: один код за вызов =====
V=.forge/guide/v2.0.json
out=$(render verdict A1 accepted)
[ "$(dec "$V" A1 status)" = "accepted" ] && [ "$(dec "$V" A1 fire)" = "False" ] && printf '%s' "$out" | grep -q 'A1 → принято' \
  && [ "$(jget "$V" "[x['verdict']['date'] for x in d['decisions'] if x['code']=='A1'][0]")" = "$TODAY" ]
check "verdict accepted should accept a decision, drop fire and stamp verdict date" $?
out=$(render verdict B1 changed "только по телефону")
[ "$(dec "$V" B1 status)" = "changed" ] && [ "$(dec "$V" B1 what)" = "только по телефону" ] \
  && [ "$(dec "$V" B1 was)" = "Мастер молчит 10 минут — запись подтверждается сама." ] && [ "$(dec "$V" B1 fire)" = "False" ] \
  && printf '%s' "$out" | grep -q 'B1 → переделано'
check "verdict changed with text should rewrite what, keep old text in was and drop fire" $?
out=$(render verdict B1 changed)
[ "$(dec "$V" B1 what)" = "только по телефону" ] && printf '%s' "$out" | grep -q '⚠ переделать — а как?'
check "verdict changed without text should change nothing and ask how" $?
out=$(render verdict D1 discuss)
[ "$(dec "$V" D1 status)" = "discuss" ] && [ "$(dec "$V" D1 fire)" = "True" ] && printf '%s' "$out" | grep -q 'D1 → обсудить'
check "verdict discuss should keep fire on" $?
out=$(render verdict O1 accepted "ночью отвечает администратор")
[ "$(dec "$V" O1 status)" = "accepted" ] && [ "$(dec "$V" O1 what)" = "ночью отвечает администратор" ] && [ "$(dec "$V" O1 fire)" = "False" ]
check "verdict accepted with text on an open question should store the answer as what" $?
out=$(render verdict R4 up); [ "$(fnd "$V" f4 block)" = "crit" ] && printf '%s' "$out" | grep -q 'R4 → приоритет выше'
check "verdict up on a risk should raise its block to crit" $?
out=$(render verdict R2 agreed); [ "$(fnd "$V" f2 status)" = "open" ] && [ "$(fnd "$V" f2 agreed_at)" = "$TODAY" ] && printf '%s' "$out" | grep -q 'R2 → предложение принято'
check "verdict agreed on a risk should stamp agreed_at and keep it open" $?
out=$(render verdict R5 done); [ "$(fnd "$V" f5 status)" = "done" ] && [ "$(fnd "$V" f5 done_at)" = "$TODAY" ] && printf '%s' "$out" | grep -q 'R5 → сделано'
check "verdict done on a risk should close it with done_at" $?
out=$(render verdict R7 down); [ "$(fnd "$V" f7 block)" = "pol" ] && printf '%s' "$out" | grep -q 'R7 → приоритет ниже'
check "verdict down on a risk should lower its block to pol" $?
out=$(render verdict R6 deferred); [ "$(fnd "$V" f6 status)" = "deferred" ] && printf '%s' "$out" | grep -q 'R6 → отложено'
check "verdict deferred on a risk should defer it" $?
out=$(render verdict R1 changed "подтверждать через 5 минут"); [ "$(fnd "$V" f1 what)" = "подтверждать через 5 минут" ] && printf '%s' "$out" | grep -q 'R1 → переделано'
check "verdict changed on a risk should rewrite its proposal" $?
out=$(render verdict Р4 up); printf '%s' "$out" | grep -q 'R4 → приоритет выше'          # кириллическая Р → R (по звуку)
check "verdict should normalize Cyrillic code letters (Р4 → R4)" $?
out=$(render verdict в1 works); [ "$(dec "$V" B1 status)" = "works" ] && printf '%s' "$out" | grep -q 'B1 → уже работает'   # в → V нет, по глифу → B
check "verdict should fall back to glyph mapping when sound mapping finds no code (в1 → B1)" $?
out=$(render verdict Z9 accepted); printf '%s' "$out" | grep -q '⚠ код Z9 не найден в гайде'
check "verdict should warn on unknown code" $?
out=$(render verdict A1 fooo); printf '%s' "$out" | grep -q 'fooo' && printf '%s' "$out" | grep -q 'accepted, changed, discuss, works, dropped' && [ "$(dec "$V" A1 status)" = "accepted" ]
check "verdict with unknown status should refuse and list the allowed statuses for decisions" $?
out=$(render verdict R2 fooo); printf '%s' "$out" | grep -q 'agreed, done, up, down, deferred, changed' && [ "$(fnd "$V" f2 status)" = "open" ]
check "verdict with unknown status should list the allowed statuses for risks" $?
out=$(render verdict A2 dropped); [ "$(dec "$V" A2 status)" = "dropped" ] && ! grep -q '<span class="code">A2</span>' "$LATEST"
check "verdict dropped should hide the decision from HTML but keep its code taken" $?
# 12 применённых ответов (A1, B1, D1, O1, R4, R2, R5, R7, R6, R1, Р4, в1, A2 = 13; без B1-без-текста, Z9, fooo×2)
[ "$(jget "$V" "len(d['pending_changes'])")" = "13" ] && [ "$(jget "$V" "d['updated_at']")" = "$TODAY" ] && [ "$(jget "$V" "d['built_at']")" = "$TODAY" ]
check "every applied verdict should land in pending_changes and updated_at, built_at untouched" $?
# после ответов: 🔥 только у D1 (discuss) — обе HTML перерисованы, PDF не трогаем, пока его нет
[ "$(grep -o '<span class="fire">' "$LATEST" | wc -l | tr -d ' ')" = "1" ] && cmp -s docs/guide/guide-v2.0.html "$LATEST" \
  && grep -q '<span class="was">' "$LATEST" && grep -q 'после сборки' "$LATEST" \
  && ! printf '%s' "$out" | grep -q 'PDF'
check "verdicts should re-render both HTML files (fire only on unanswered, «was» shown) and not mention PDF when none exists" $?
touch docs/guide/guide-v2.0.pdf
out=$(render verdict D1 discuss); printf '%s' "$out" | grep -q 'PDF пропущен'
check "verdict should try to rebuild the PDF only when this version's PDF already exists" $?
rm -f docs/guide/guide-v2.0.pdf

# ===== (9) link / merged / summary — как в v1, на последней версии =====
out=$(render link f1 confirm-timeout)
[ "$(fnd "$V" f1 task_slug)" = "confirm-timeout" ] && grep -q 'title="confirm-timeout"' "$LATEST" && grep -q '→ в работе' "$LATEST" \
  && ! grep -q 'в работе: confirm-timeout' "$LATEST" && printf '%s' "$out" | grep -q 'f1 → задача confirm-timeout'
check "link should attach task slug to the finding (slug only in title attr) and re-render" $?
out=$(render link R2 pay-atomic); [ "$(fnd "$V" f2 task_slug)" = "pay-atomic" ] && printf '%s' "$out" | grep -q 'f2 → задача pay-atomic'
check "link should accept an R-code as well as the internal id" $?
printf '%s' "$(render link nope-id x)" | grep -q 'карточки nope-id нет'; check "link should report unknown finding id" $?
out=$(render merged confirm-timeout)
[ "$(fnd "$V" f1 status)" = "done" ] && [ "$(fnd "$V" f1 done_at)" = "$TODAY" ] && [ "$(jget "$V" "d['stale_tasks']")" = "1" ] \
  && grep -q 'risk crit done' "$LATEST" && grep -q 'устарел на 1 задачу' "$LATEST" && grep -q '→ уже работает' "$LATEST" \
  && printf '%s' "$out" | grep -q 'сделано →' && [ "$(jget "$V" "len(d['pending_changes'])")" = "15" ]
check "merged should mark the finding done, bump stale_tasks, note it in pending_changes and re-render" $?
render merged unknown >/dev/null; [ "$(jget "$V" "d['stale_tasks']")" = "2" ]; check "merged without a match should still bump stale_tasks" $?
# summary = решения open|discuss + default с 🔥 + находки open с owner decision|both (не moved_out):
#   D1 discuss → 1; f2 both open → 2; f3 decision open → 3; f4 decision open → 4  (P1 default без 🔥 — не считается)
out=$(render summary); printf '%s' "$out" | grep -q '📖 Гайд по проекту v2.0: ждут 4 решения владельца' && printf '%s' "$out" | grep -q 'устарел на 2 задачи' && printf '%s' "$out" | grep -q 'guide-latest.html'
check "summary should count open/discuss decisions, fired defaults and open decision findings, plus stale tasks" $?
python3 - <<'PY'
import json; p='.forge/guide/v2.0.json'; d=json.load(open(p))
for x in d['decisions']:
    if x['status']!='dropped': x['status']='accepted'
for f in d['findings']:
    if f['owner'] in ('decision','both'): f['status']='done'
d['stale_tasks']=0; json.dump(d, open(p,'w'), ensure_ascii=False)
PY
[ -z "$(render summary)" ]; check "summary should stay silent when nothing waits and guide is fresh" $?
render bump >/dev/null; out=$(render summary); printf '%s' "$out" | grep -q 'v2.1 ещё не собрана'
check "summary on an unbuilt version should ask to finish the build" $?
cd / && rm -rf "$WORK"

# ===== (10) без гайда: summary/merged/link молчат, render/verdict честно говорят, exit 0, docs/ не создаётся =====
new_project; rmdir .forge/guide
s=$(render summary); rc1=$?; m=$(render merged x); rc2=$?; l=$(render link f1 x); rc3=$?; r=$(render render); rc4=$?; v=$(render verdict A1 accepted); rc5=$?
[ "$rc1" -eq 0 ] && [ -z "$s" ] && [ "$rc2" -eq 0 ] && [ -z "$m" ] && [ "$rc3" -eq 0 ] && [ -z "$l" ] \
  && [ "$rc4" -eq 0 ] && printf '%s' "$r" | grep -q 'ещё не собирали' && [ "$rc5" -eq 0 ] && printf '%s' "$v" | grep -q 'ещё не собирали' && [ ! -d docs ]
check "should exit 0 quietly when there is no guide yet" $?
cd / && rm -rf "$WORK"

# ===== (11) bump без версий: v1.0 с P1 + миграция старого отчёта; битый легаси → .broken; index.yml → meta =====
new_project
cp "$LEGACY" .forge/status-report.json; echo x > .forge/status-report.html
mkdir -p .forge/reports/shots && echo png > .forge/reports/shots/calendar-mobile.png
out=$(render bump)
[ -f "$JSON" ] && [ "$(jget "$JSON" "len(d['findings'])")" = "8" ] && [ "$(jget "$JSON" "d['meta']['project']")" = "Lumen" ] \
  && [ "$(jget "$JSON" "[x['code'] for x in d['decisions']]")" = "['P1']" ] && [ "$(jget "$JSON" "d['built_at']")" = "None" ] \
  && [ "$(fnd "$JSON" f5 screenshot)" = ".forge/guide/shots/calendar-mobile.png" ] && [ -f .forge/guide/shots/calendar-mobile.png ] \
  && [ ! -f .forge/status-report.json ] && [ ! -f .forge/status-report.html ] && [ ! -d .forge/reports/shots ] \
  && printf '%s' "$out" | grep -q 'перенёс 8 находок'
check "bump without versions should create v1.0.json, migrate the legacy report (findings + shots) and remove the old files" $?
cd / && rm -rf "$WORK"
new_project; printf '{ "findings": [ обрыв' > .forge/status-report.json
printf 'project: Demo\nversion: "3.1.0"\n' > .forge/index.yml
out=$(render bump)
[ -f "$JSON" ] && [ "$(jget "$JSON" "len(d['findings'])")" = "0" ] && [ "$(jget "$JSON" "d['meta']['project']")" = "Demo" ] \
  && [ "$(jget "$JSON" "d['meta']['project_version']")" = "3.1.0" ] && [ -f .forge/status-report.json.broken ] && [ ! -f .forge/status-report.json ] \
  && printf '%s' "$out" | grep -q 'broken'
check "bump with a broken legacy report should park it as .broken, start an empty v1.0 and read meta from index.yml" $?
cd / && rm -rf "$WORK"

# ===== (12) .forge/.gitignore: боевой рендер создаёт 7 строк / дописывает недостающее; макет вне .forge не трогает =====
new_project; cp "$GUIDE" "$JSON"; render render >/dev/null
diff <(printf '%s\n' .inject-state .last-backup .migration-declined state.yml '.github-*' graph.json guide/shots/) .forge/.gitignore >/dev/null
check "render should create .forge/.gitignore with the 7-line forge set (incl. guide/shots/)" $?
printf '%s\n' .inject-state .last-backup .migration-declined state.yml '.github-*' graph.json > .forge/.gitignore
render render >/dev/null; render render >/dev/null
[ "$(wc -l < .forge/.gitignore | tr -d ' ')" = "7" ] && [ "$(tail -1 .forge/.gitignore)" = "guide/shots/" ] && [ "$(head -1 .forge/.gitignore)" = ".inject-state" ]
check "render should append only the missing guide/shots/ line to an existing .forge/.gitignore (idempotent)" $?
cp "$GUIDE" "$WORK/mock.json"; python3 -c "import json;p='$WORK/mock.json';d=json.load(open(p));d['built_at']=None;json.dump(d,open(p,'w'),ensure_ascii=False)"
render render "$WORK/mock.json" .forge/sketches/mock.html >/dev/null
[ -f .forge/sketches/mock.html ] && [ ! -f .forge/sketches/guide-latest.html ] && [ "$(wc -l < .forge/.gitignore | tr -d ' ')" = "7" ] \
  && [ "$(jget "$WORK/mock.json" "d['built_at']")" = "None" ]
check "mockup render to an explicit .html should write only that file, leave .gitignore and built_at alone" $?
cd / && rm -rf "$WORK"

# ===== (13) находка с неизвестным блоком не теряется (средний ярус + ⚠) =====
new_project; cp "$GUIDE" "$JSON"
python3 - <<'PY'
import json; p='.forge/guide/v1.0.json'; d=json.load(open(p)); d['findings']=d['findings'][:3]
d['findings'][1]['block']='critical'; d['findings'][2].pop('block',None)
for f in d['findings']: f['status']='open'
json.dump(d, open(p,'w'), ensure_ascii=False)
PY
out=$(render render); [ "$(grep -o '<div class="risk ' "$HTML" | wc -l | tr -d ' ')" = "3" ] && printf '%s' "$out" | grep -q 'блок «critical» неизвестен' && printf '%s' "$out" | grep -q 'блок «None» неизвестен'
check "should never drop a finding with unknown/missing block (mid tier + warning)" $?
# код решения не по правилу — печатается, но с ⚠
python3 - <<'PY'
import json; p='.forge/guide/v1.0.json'; d=json.load(open(p))
d['decisions'].append({"code":"R1","group":"R","group_title":"Риски","title":"не та буква","status":"open","fire":False,"what":"","why":""})
d['decisions'].append({"code":"Б2","group":"Б","group_title":"Кириллица","title":"не тот код","status":"open","fire":False,"what":"","why":""})
json.dump(d, open(p,'w'), ensure_ascii=False)
PY
out=$(render render); printf '%s' "$out" | grep -q '⚠.*R1' && printf '%s' "$out" | grep -q '⚠.*Б2' && [ "$(grep -o '<div class="risk ' "$HTML" | wc -l | tr -d ' ')" = "3" ]
check "decision codes outside ^[A-Z]\\d+$ or in group R should warn without breaking the render" $?
cd / && rm -rf "$WORK"

# ===== (14) битый JSON во всех 7 режимах: человеческая строка, exit 0; summary молчит =====
new_project; printf '{ "decisions": [ обрыв' > "$JSON"; broken_ok=0
for m in "render" "merged some-task" "link f1 some-task" "summary" "bump" "verdict A1 accepted" "pdf"; do
    out=$(render $m); rc=$?
    [ "$rc" -ne 0 ] && { broken_ok=1; echo "  режим «${m}»: rc=$rc" >&2; }
    if [ "$m" = "summary" ]; then [ -z "$out" ] || broken_ok=1
    else printf '%s' "$out" | grep -q 'повреждён' && printf '%s' "$out" | grep -q 'git checkout -- ' || { broken_ok=1; echo "  режим «${m}»: нет сообщения" >&2; }; fi
done
[ "$broken_ok" -eq 0 ] && [ ! -f .forge/guide/v1.1.json ]; check "should survive a broken guide file in every mode (exit 0, hint to fix or git checkout)" $?
cd / && rm -rf "$WORK"

# ===== (15) pdf: без Chrome — пропуск с честной строкой, exit 0, HTML на месте; живой Chrome — только по FORGE_TEST_PDF=1 =====
new_project; cp "$GUIDE" "$JSON"; render render >/dev/null
out=$(render pdf); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'Chrome не найден — PDF пропущен' && [ ! -f docs/guide/guide-v1.0.pdf ] && [ -f "$HTML" ]
check "pdf should skip politely without Chrome (exit 0, HTML stays)" $?
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ "${FORGE_TEST_PDF:-}" = "1" ] && [ -x "$CHROME" ]; then
    sed -i '' '/fonts.googleapis.com/d' "$HTML"   # офлайн: без похода за шрифтами
    out=$(FORGE_CHROME="$CHROME" render pdf); [ "$(head -c 4 docs/guide/guide-v1.0.pdf 2>/dev/null)" = "%PDF" ] && printf '%s' "$out" | grep -q 'PDF собран'
    check "pdf should build guide-v1.0.pdf via Chrome headless" $?
else echo "SKIP: pdf via live Chrome (set FORGE_TEST_PDF=1 on a machine with Google Chrome)"; fi
cd / && rm -rf "$WORK"

# ===== (16) moved_out: находка decision, вынесенная в O-вопрос (links O<n> + deferred), не попадает в «Отложено», счётчики и summary =====
new_project; cp "$GUIDE" "$JSON"
python3 - <<'PY'
import json; p='.forge/guide/v1.0.json'; d=json.load(open(p))
f3=[f for f in d['findings'] if f['id']=='f3'][0]; f3['links']=['O1']; f3['status']='deferred'
json.dump(d, open(p,'w'), ensure_ascii=False)
PY
out=$(render render)
grep -q 'Отложено — 1' "$HTML" && ! grep -q 'Отложено — 2' "$HTML" && printf '%s' "$out" | grep -q 'отложено 1' && ! grep -q '<span class="rc">R3</span>' "$HTML"
check "a decision finding moved out into an O-question should not show up in «Отложено» nor in counters" $?
# summary: B1 default+🔥 → 1, D1 discuss → 2, O1 open → 3, f2 both open → 4, f4 decision open → 5; f3 — moved_out
out=$(render summary); printf '%s' "$out" | grep -q 'ждут 5 решений владельца'
check "summary should ignore moved-out findings" $?
cd / && rm -rf "$WORK"

echo ""
if [ "$fails" -eq 0 ]; then
    echo "All tests passed"
else
    echo "$fails test(s) FAILED"
    exit 1
fi
