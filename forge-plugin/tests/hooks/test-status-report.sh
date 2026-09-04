#!/usr/bin/env bash
# Тесты для skills/status-report/render.py — рендерер отчёта «Что дальше» (Фаза 5).
# JSON → HTML, экранирование, обновление после мержа, привязка к задаче,
# строка-напоминание для session-start. Прогоняется в изолированной tmp-директории
# (cwd = «корень проекта», данные в .forge/ — как в бою).

set -uo pipefail

RENDER="$(cd "$(dirname "$0")/../../skills/status-report" && pwd)/render.py"
FIXTURE="$(cd "$(dirname "$0")/fixtures" && pwd)/status-report-sample.json"
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
    mkdir -p .forge
}

render() { python3 "$RENDER" "$@" 2>&1; }

# JSON-поле через python3 (PyYAML нет, json — стандартная библиотека)
jget() { python3 -c "import json,sys; d=json.load(open('.forge/status-report.json')); print(eval(sys.argv[1]))" "$1"; }

JSON=.forge/status-report.json
HTML=.forge/status-report.html

# --- (1) фикстура → render: файл создан, вердикт на месте, счётчик совпадает с данными (и в HTML, и в stdout) ---

new_project
cp "$FIXTURE" "$JSON"
out=$(render render)
total=$(jget "len(d['findings'])")
deferred=$(jget "sum(1 for f in d['findings'] if f['status']=='deferred')")
blocks=$(jget "len({f['block'] for f in d['findings'] if f['status']!='deferred'})")
[ -f "$HTML" ] \
  && grep -q "Главное одной фразой" "$HTML" \
  && grep -q "$total находок → $blocks блока" "$HTML" \
  && grep -q "$deferred отложена" "$HTML" \
  && grep -q "<title>Lumen · Что дальше</title>" "$HTML" \
  && printf '%s' "$out" | grep -qF "$total находок → $blocks блока"
check "fixture → render creates HTML with verdict and honest counters from data (HTML + stdout line)" $?

# --- (2) блоки по оси block: crit/biz/imp — секции, pol — только в футере ---

grep -q 'class="tag crit">Блок 1' "$HTML" \
  && grep -q 'class="tag biz">Блок 2' "$HTML" \
  && grep -q 'class="tag imp">Блок 3' "$HTML" \
  && ! grep -q 'class="tag pol"' "$HTML" \
  && grep -q "Блок 4 «Потом»" "$HTML" \
  && grep -q '<b>Что решить:</b>' "$HTML" \
  && grep -q '<b>Зачем:</b>' "$HTML"
check "should map block → sections (crit/biz/imp) and send pol to the footer" $?

# --- (3) чипы владельца и бейдж усилий: decision → «—» ---

grep -q '<span class="chip code">Код</span>' "$HTML" \
  && grep -q '<span class="chip biz">Решение</span>' "$HTML" \
  && grep -q '<span class="chip both">Решение+код</span>' "$HTML" \
  && grep -q '<span class="chip biz">Решение</span><h3>[^<]*</h3><span class="eff">—</span>' "$HTML" \
  && ! grep -q '<script' "$HTML"
check "should render owner chips, '—' effort for pure decisions, and no JS" $?

# --- (4) экранирование: <script> в тексте не становится тегом, **жирный** работает ---

python3 - <<'PY'
import json
d = json.load(open('.forge/status-report.json'))
d['findings'][0]['title'] = '<script>alert(1)</script> & "кавычки"'
d['verdict']['text'] = '**главное** и <b>сырой тег</b>'
json.dump(d, open('.forge/status-report.json', 'w'), ensure_ascii=False)
PY
render render >/dev/null
! grep -q '<script>' "$HTML" \
  && grep -q '&lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;кавычки&quot;' "$HTML" \
  && grep -q '<b>главное</b> и &lt;b&gt;сырой тег&lt;/b&gt;' "$HTML"
check "should escape HTML in texts (typo/tag never breaks layout) and keep **bold** markup" $?

# --- (5) отсутствующий скриншот не роняет рендер; существующий — встроен как data: URI ---

render render >/dev/null
rc=$?
[ "$rc" -eq 0 ] && ! grep -q 'class="shot"' "$HTML"
check "should render without image when screenshot file is missing (no error)" $?

mkdir -p .forge/reports/shots
python3 -c "
import base64, pathlib
pathlib.Path('.forge/reports/shots/calendar-mobile.png').write_bytes(base64.b64decode(
 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='))"
render render >/dev/null
grep -q 'class="shot" src="data:image/png;base64,iVBOR' "$HTML"
check "should embed existing screenshot as data: URI" $?

# --- (6) link: карточка привязана к задаче, HTML пересобран ---

out=$(render link f1 confirm-timeout)
[ "$(jget "[f['task_slug'] for f in d['findings'] if f['id']=='f1'][0]")" = "confirm-timeout" ] \
  && grep -q "в работе: confirm-timeout" "$HTML" \
  && printf '%s' "$out" | grep -q "f1 → задача confirm-timeout"
check "link should attach task slug to the card and re-render" $?

out=$(render link nope-id some-task)
printf '%s' "$out" | grep -q "карточки nope-id нет"
check "link should report unknown card id without failing" $?

# --- (7) merged: карточка → done, stale_tasks +1, HTML пересобран ---

out=$(render merged confirm-timeout)
[ "$(jget "[f['status'] for f in d['findings'] if f['id']=='f1'][0]")" = "done" ] \
  && [ "$(jget "d['stale_tasks']")" = "1" ] \
  && grep -q 'class="card done"' "$HTML" \
  && grep -q "устарел на 1 задачу" "$HTML" \
  && printf '%s' "$out" | grep -q "сделано →"
check "merged should mark the linked card done, bump stale_tasks and re-render" $?

out=$(render merged unknown-task)
[ "$(jget "d['stale_tasks']")" = "2" ] && printf '%s' "$out" | grep -q "карточки с задачей «unknown-task» нет"
check "merged without matching card should still bump stale_tasks (report is stale anyway)" $?

# --- (8) summary: считает открытые решения и устаревание; пустой — когда нечего напоминать ---

out=$(render summary)
printf '%s' "$out" | grep -q "ждут 3 решения владельца" && printf '%s' "$out" | grep -q "устарел на 2 задачи"
check "summary should report open owner decisions and stale task count in one line" $?

python3 - <<'PY'
import json
d = json.load(open('.forge/status-report.json'))
for f in d['findings']:
    if f['owner'] in ('decision', 'both'):
        f['status'] = 'done'
d['stale_tasks'] = 0
json.dump(d, open('.forge/status-report.json', 'w'), ensure_ascii=False)
PY
out=$(render summary)
[ -z "$out" ]
check "summary should print nothing when no open decisions and report is fresh" $?
cd / && rm -rf "$WORK"

# --- (9) без JSON: summary/merged молчат, render говорит честно, все exit 0 ---

new_project
s=$(render summary); rc1=$?
m=$(render merged x); rc2=$?
r=$(render render); rc3=$?
[ "$rc1" -eq 0 ] && [ -z "$s" ] && [ "$rc2" -eq 0 ] && [ -z "$m" ] \
  && [ "$rc3" -eq 0 ] && printf '%s' "$r" | grep -q "ещё не собирали" && [ ! -f "$HTML" ]
check "should exit 0 quietly when there is no report yet (nothing to remind or update)" $?
cd / && rm -rf "$WORK"

# --- (10) игнор в git: боевой HTML в .forge → .forge/.gitignore получает строки отчёта; макет в другом месте — не трогает ---

new_project
cp "$FIXTURE" "$JSON"
render render >/dev/null
[ -f .forge/.gitignore ] \
  && diff <(printf '%s\n' .inject-state .last-backup .migration-declined state.yml '.github-*' graph.json status-report.html reports/shots/) .forge/.gitignore >/dev/null
check "render into .forge should create .forge/.gitignore with the full forge set when it is missing" $?

printf 'state.yml\n' > .forge/.gitignore
render render >/dev/null
render render >/dev/null
[ "$(wc -l < .forge/.gitignore | tr -d ' ')" = "3" ] \
  && grep -qx 'status-report.html' .forge/.gitignore \
  && grep -qx 'reports/shots/' .forge/.gitignore \
  && [ "$(head -1 .forge/.gitignore)" = "state.yml" ]
check "render into .forge should append only the missing report lines to an existing .forge/.gitignore (idempotent)" $?

cp "$FIXTURE" "$WORK/mock.json"
render render "$WORK/mock.json" .forge/sketches/mock.html >/dev/null
[ -f .forge/sketches/mock.html ] && [ "$(wc -l < .forge/.gitignore | tr -d ' ')" = "3" ]
check "render of a mockup outside .forge root should leave .forge/.gitignore untouched" $?
cd / && rm -rf "$WORK"

# --- (11) ни одна находка не теряется: незнакомый или пустой блок → «Скоро», и об этом сказано вслух ---

new_project
cp "$FIXTURE" "$JSON"
python3 - <<'PYX'
import json
d = json.load(open('.forge/status-report.json'))
d['findings'] = d['findings'][:3]
d['findings'][0]['block'] = 'crit'
d['findings'][1]['block'] = 'critical'   # опечатка
d['findings'][2].pop('block', None)      # блока нет вовсе
for f in d['findings']:
    f['status'] = 'open'
json.dump(d, open('.forge/status-report.json', 'w'), ensure_ascii=False)
PYX
out=$(render render)
cards=$(grep -o '<div class="card[" ]' "$HTML" | wc -l | tr -d ' ')
[ "$cards" = "3" ] \
  && printf '%s' "$out" | grep -q "3 находки" \
  && printf '%s' "$out" | grep -q "блок «critical» неизвестен" \
  && printf '%s' "$out" | grep -q "блок «None» неизвестен"
check "should never drop a finding with an unknown or missing block (show it in imp and say so)" $?
cd / && rm -rf "$WORK"

# --- (12) битый файл отчёта не роняет мерж: понятная строка и exit 0 ---

new_project
printf '{ "findings": [ обрыв' > "$JSON"
broken_ok=0
for m in "render" "merged some-task" "link f1 some-task" "summary"; do
    out=$(render $m); rc=$?
    if [ "$rc" -ne 0 ]; then broken_ok=1; echo "  режим «$m»: rc=$rc" >&2; fi
    if [ "$m" = "summary" ]; then
        [ -z "$out" ] || { broken_ok=1; echo "  summary должен молчать" >&2; }
    else
        printf '%s' "$out" | grep -q "повреждён" || { broken_ok=1; echo "  режим «$m»: нет человеческого сообщения" >&2; }
    fi
done
[ "$broken_ok" -eq 0 ]
check "should survive a broken report file in every mode (clear message, exit 0)" $?
cd / && rm -rf "$WORK"

echo "---"
if [ "$fails" -gt 0 ]; then
    echo "$fails test(s) FAILED"
    exit 1
fi
echo "All tests passed"
exit 0
