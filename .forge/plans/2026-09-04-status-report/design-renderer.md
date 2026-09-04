

===== [renderer] ШАГ 1: Шаг 1. Тест RED — forge-plugin/tests/hooks/test-status-report.sh (рендерера ещё нет) (~5 мин)
ФАЙЛЫ: Создать: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-status-report.sh
--- ЧТО:
Готовый проверенный файл лежит в scratchpad: /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad/proto/tests/hooks/test-status-report.sh — скопировать как есть:

  cp /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad/proto/tests/hooks/test-status-report.sh /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/ && chmod +x /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-status-report.sh

Структура — по образцу test-memory-backup.sh (set -uo pipefail; check(); fails; tmp-директория как «корень проекта» с .forge/; итог «All tests passed»/«N test(s) FAILED»). Шапка и хелперы:

#!/usr/bin/env bash
# Тесты для skills/status-report/render.py — рендерер отчёта «Что дальше» (Фаза 5).
set -uo pipefail
RENDER="$(cd "$(dirname "$0")/../../skills/status-report" && pwd)/render.py"
fails=0
check() { local desc="$1" ok="$2"; if [ "$ok" -eq 0 ]; then echo "PASS: $desc"; else echo "FAIL: $desc"; fails=$((fails + 1)); fi; }
WORK=""
new_project() { WORK=$(mktemp -d); cd "$WORK" || exit 1; mkdir -p .forge; }   # обычная функция, не $() — cd должен пережить вызов
render() { python3 "$RENDER" "$@" 2>&1; }
jget() { python3 -c "import json,sys; d=json.load(open('.forge/status-report.json')); print(eval(sys.argv[1]))" "$1"; }   # JSON вместо PyYAML
JSON=.forge/status-report.json; HTML=.forge/status-report.html

13 проверок (все уже в файле):
(1) sample → render: HTML создан, есть «Главное одной фразой», «<title>Lumen · Что дальше</title>», счётчик «N находок → M блока, K отложена» посчитан из JSON (total=len(findings), blocks=число разных block у status!=deferred, deferred=status==deferred):
  render sample "$JSON" >/dev/null; render render >/dev/null
  total=$(jget "len(d['findings'])"); deferred=$(jget "sum(1 for f in d['findings'] if f['status']=='deferred')"); blocks=$(jget "len({f['block'] for f in d['findings'] if f['status']!='deferred'})")
  [ -f "$HTML" ] && grep -q "Главное одной фразой" "$HTML" && grep -q "$total находок → $blocks блока" "$HTML" && grep -q "$deferred отложена" "$HTML"
(2) блоки: 'class="tag crit">Блок 1', 'tag biz">Блок 2', 'tag imp">Блок 3', тега pol в секциях НЕТ, в футере «Блок 4 «Потом»», лейблы <b>Что решить:</b> и <b>Зачем:</b>.
(3) чипы 'chip code">Код', 'chip biz">Решение', 'chip both">Решение+код'; у Решения бейдж «—»; в HTML нет '<script' (никакого JS).
(4) экранирование: через python3 в title пишется '<script>alert(1)</script> & "кавычки"', в verdict — '**главное** и <b>сырой тег</b>'; после render: нет '<script>', есть '&lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;кавычки&quot;' и '<b>главное</b> и &lt;b&gt;сырой тег&lt;/b&gt;'.
(5) отсутствующий скриншот: render rc=0 и нет class="shot"; затем создаётся 1×1 PNG в .forge/reports/shots/calendar-mobile.png → есть 'class="shot" src="data:image/png;base64,iVBOR'.
(6) link f1 confirm-timeout → в JSON task_slug, в HTML «в работе: confirm-timeout», stdout «f1 → задача confirm-timeout»; link nope-id … → «карточки nope-id нет», rc 0.
(7) merged confirm-timeout → f1.status==done, stale_tasks==1, 'class="card done"', «устарел на 1 задачу», stdout «сделано →»; merged unknown-task → stale_tasks==2 и «карточки с задачей «unknown-task» нет».
(8) summary → «ждут 3 решения владельца» и «устарел на 2 задачи»; после перевода всех decision/both в done и stale_tasks=0 → вывод пустой.
(9) без JSON: summary и merged молчат (rc 0, пустой вывод), render печатает «ещё не собирали», HTML не создаётся.

Это TDD по правилу плана: рендерер — функциональная логика.
--- ПРОВЕРКА:
bash /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-status-report.sh → 13 строк «FAIL: …» и в конце «13 test(s) FAILED» (python3: can't open file '…/skills/status-report/render.py'). Это RED.


===== [renderer] ШАГ 2: Шаг 2. Рендерер forge-plugin/skills/status-report/render.py (GREEN) (~10 мин)
ФАЙЛЫ: Создать: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/render.py
--- ЧТО:
Проверенный файл (≈300 строк, только stdlib: base64/html/json/os/re/subprocess/sys/datetime/pathlib) лежит в /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad/proto/skills/status-report/render.py — скопировать:

  mkdir -p /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report && cp /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad/proto/skills/status-report/render.py /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/render.py && chmod +x …/render.py

Что внутри (ключевое — кодом):

Константы:
DEFAULT_JSON = Path(".forge/status-report.json"); DEFAULT_HTML = Path(".forge/status-report.html")
BLOCK_ORDER = ["crit", "biz", "imp"]   # pol — в футер
BLOCKS = {"crit": ("Кровь из носа — чиню в коде", "Без этого сервис не выполняет свою главную функцию. Моя работа; где стоит чип «Решение+код» — сначала нужно твоё слово."),
          "biz": ("Решения — нужны от тебя", "Деньги, люди, правила. Я не двигаю это сам — жду ответа, потом делаю."),
          "imp": ("Скоро — усиливает продукт", "Не горит, но заметно улучшает. Делаю после Блока 1.")}
CHIP = {"code": ("code", "Код"), "decision": ("biz", "Решение"), "both": ("both", "Решение+код")}
MIME = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}
SAMPLE = {…}  # проект «Lumen» (онлайн-запись в салон), 8 находок: 2 crit (code M, both L), 2 biz (decision), 2 imp (code S со screenshot-путём, code M), 1 pol (code S), 1 imp deferred
CSS = """…"""  # токены :root (--bg #F4F5F8, --panel #fff, --ink #171B24, --accent #3D5AFE, --crit/--crit-bg, --biz/--biz-bg, --imp/--imp-bg, --pol/--pol-bg …), тёмная тема через @media (prefers-color-scheme: dark) с гардом :root:not([data-theme="light"]) и дублем :root[data-theme="dark"] (фон #0E1017, панели #171A22); .wrap max-width 1080px; h1 clamp(28px,5vw,44px), letter-spacing -.02em; .head p max-width 66ch; классы .head .eyebrow .meta .verdict .phase .phase-head .tag.{crit,biz,imp,pol} .phase-sub .grid .card .card-top .chip.{code,biz,both,done} .eff .why .src .slug .card.done .shot .foot

Экранирование + минимальная разметка (опечатка/тег в тексте вёрстку не ломает):
def esc(s):
    t = html.escape(str(s or ""), quote=True)
    return re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)

Русские числительные для честных счётчиков:
def plural(n, one, few, many):
    n = abs(int(n))
    if n % 10 == 1 and n % 100 != 11: return f"{n} {one}"
    if 2 <= n % 10 <= 4 and not 12 <= n % 100 <= 14: return f"{n} {few}"
    return f"{n} {many}"

Скриншот — data: URI, если файл на месте; нет файла — пустая строка:
def img_tag(shot, alt, base):
    if not shot: return ""
    p = Path(shot)
    for cand in ([p] if p.is_absolute() else [Path.cwd() / p, base / p]):   # base = корень проекта (родитель .forge)
        if cand.is_file() and cand.suffix.lower() in MIME:
            b64 = base64.b64encode(cand.read_bytes()).decode("ascii")
            return f'<img class="shot" src="data:{MIME[cand.suffix.lower()]};base64,{b64}" alt="{esc(alt)}">'
    return ""

Карточка (убывающая детализация по блоку):
def render_card(f, block, base):
    done = f.get("status") == "done"
    chip_cls, chip_txt = ("done", "Сделано") if done else CHIP.get(f.get("owner"), CHIP["code"])
    eff = "—" if f.get("owner") == "decision" or f.get("effort") in (None, "", "-") else f["effort"]
    parts = [f'<div class="card{" done" if done else ""}">',
             f'<div class="card-top"><span class="chip {chip_cls}">{chip_txt}</span><h3>{esc(f.get("title"))}</h3><span class="eff">{esc(eff)}</span></div>']
    if not done:
        what, why = f.get("what", ""), f.get("why", "")
        if block == "crit":
            parts.append(f"<p><b>Что:</b> {esc(what)}</p>")
            if why: parts.append(f'<p class="why"><b>Зачем:</b> {esc(why)}</p>')
        elif block == "biz":
            parts.append(f"<p><b>Что решить:</b> {esc(what)}</p>")
            if why: parts.append(f'<p class="why">{esc(why)}</p>')
        else:
            parts.append(f"<p>{esc(what)}</p>")
            if why: parts.append(f'<p class="why">{esc(why)}</p>')
        parts.append(img_tag(f.get("screenshot"), f.get("title"), base))
    if f.get("task_slug"):
        parts.append(f'<div class="slug">→ {"влито" if done else "в работе"}: {esc(f["task_slug"])}</div>')
    if f.get("source"): parts.append(f'<div class="src">{esc(f["source"])}</div>')
    parts.append("</div>")
    return "\n".join(p for p in parts if p)

Счётчики считает рендерер, не Клод:
def counts(data):
    fs = data.get("findings", [])
    active = [f for f in fs if f.get("status") != "deferred"]
    present = [b for b in BLOCK_ORDER + ["pol"] if any(f.get("block") == b for f in active)]
    return {"total": len(fs), "blocks": len(present), "present": present,
            "deferred": [f for f in fs if f.get("status") == "deferred"],
            "done": sum(1 for f in fs if f.get("status") == "done"),
            "pol": [f for f in active if f.get("block") == "pol"],
            "open_decisions": sum(1 for f in fs if f.get("status") == "open" and f.get("owner") in ("decision", "both"))}

render_html(data, base): полный документ (<!DOCTYPE html><html lang="ru">…, <title>{project} · Что дальше</title>, <link> Google Fonts Archivo 500–800 / IBM Plex Sans 400–600 / IBM Plex Mono 400–600, <style>CSS</style>); .head: eyebrow, h1 «{project}: {question}», лид генерируется из sources: «{N аналитика прошли} по коду и памяти проекта и нашли {found пробелов}. Свёл в приоритеты: <b>что чиню я в коде</b> и <b>что решаешь ты</b>. Порядок — по тому, что мешает сервису работать, а не по тому, что заметнее.»; .meta: built_at · «N находок → M блоков[, K отложено]» · next_after · (если stale_tasks>0) «обновлён {updated_at} · устарел на N задач»; .verdict «Главное одной фразой» из verdict.text; секции:
    n = 0
    for b in BLOCK_ORDER:
        cards = [f for f in data.get("findings", []) if f.get("block") == b and f.get("status") != "deferred"]
        if not cards: continue
        n += 1; title, sub = BLOCKS[b]
        cards.sort(key=lambda f: f.get("status") == "done")   # сделанное — в конец блока
        out.append(f'<section class="phase"><div class="phase-head"><span class="tag {b}">Блок {n}</span><h2>{title}</h2></div><p class="phase-sub">{sub}</p><div class="grid">')
        out.extend(render_card(f, b, base) for f in cards); out.append("</div></section>")
.foot (mono): «Блок {n+1} «Потом» — K находок, не срочно (2 примера)»; «Отложено — K находок (примеры)»; «Сделано с момента сборки — K карточек» (если есть); «Порядок: сначала <b>Блок 1 (без него сервис не работает)</b>, <b>параллельно собрать ответы Блока 2</b>, <b>затем Блок 3</b>, потом полиш.»; при stale_tasks>0 — «С момента сборки влито N задач — цифры могли поплыть. Скажи «собери отчёт» — пересоберу с аудитом.»

CLI (main): перед разбором режима — cd_repo_root(): если .forge/status-report.json не в cwd, chdir в `git rev-parse --show-toplevel` (finishing/хуки могут звать из поддиректории). Режимы:
  render [json] [html] — do_render: пишет HTML, печатает «FORGE-REPORT: HTML собран → …»; нет JSON → «FORGE-REPORT: нет .forge/status-report.json — отчёт ещё не собирали», rc 0
  sample <out.json> — save(SAMPLE) (json.dumps ensure_ascii=False, indent=2)
  merged <slug> [json]:
        for f in data["findings"]:
            if f.get("task_slug") == slug and f.get("status") != "done":
                f["status"] = "done"; f["done_at"] = today; hit.append(f["title"])
        data["stale_tasks"] = int(data.get("stale_tasks", 0) or 0) + 1   # всегда: влитая задача = отчёт устарел
        data["updated_at"] = today; save(jp, data); do_render(jp, jp.with_suffix(".html"))
        → «FORGE-REPORT: сделано → {titles}; отчёт устарел на N задач» либо «FORGE-REPORT: карточки с задачей «slug» нет; отчёт устарел на N задач»; нет JSON → молча rc 0
  link <finding-id> <slug> [json] — task_slug на карточке с id, updated_at, пересборка HTML; «FORGE-REPORT: карточка f3 → задача my-slug» / «карточки f3 нет»
  summary [json] — по counts(): bits «ждут N решений владельца» (open_decisions>0) и «отчёт устарел на M задач» (stale_tasks>0); печатает «📊 Отчёт «Что дальше»: …, … (.forge/status-report.html; пересобрать — «собери отчёт»)», иначе НИЧЕГО; нет файла/битый JSON → молча rc 0
  неверные аргументы → docstring в stderr, rc 2. Всё остальное — rc 0.
--- ПРОВЕРКА:
bash /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-status-report.sh → 13× «PASS: …» и «All tests passed». Дополнительно из корня репозитория: python3 forge-plugin/skills/status-report/render.py → «FORGE-REPORT: нет .forge/status-report.json — отчёт ещё не собирали» (rc 0, файлы в .forge не появились).


===== [renderer] ШАГ 3: Шаг 3. Макет: образец данных → .forge/sketches/status-report-mockup.html → open. ЧЕКПОИНТ «реакция на макет» (~5 мин)
ФАЙЛЫ: Создать (генерируется): /Users/mac/Projects/Plugin/plugin/.forge/sketches/status-report-mockup.html; Временный: /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad/status-report-sample.json
--- ЧТО:
Из корня репозитория:

  cd /Users/mac/Projects/Plugin/plugin
  python3 forge-plugin/skills/status-report/render.py sample /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad/status-report-sample.json
  python3 forge-plugin/skills/status-report/render.py render /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad/status-report-sample.json .forge/sketches/status-report-mockup.html
  open .forge/sketches/status-report-mockup.html

(JSON-образец нарочно НЕ кладём в .forge/status-report.json — иначе session-start начнёт напоминать про «3 решения» несуществующего проекта Lumen; макет лежит в .forge/sketches/ по конвенции plan-скилла и коммитится как память.)

Как выглядит уже отрисованный макет (снимок 1280px, full page): /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad/proto/mock/shot-full.png — eyebrow «ДОРОЖНАЯ КАРТА · ПЕРЕД ЗАПУСКОМ НА ВТОРОЙ САЛОН», H1 «Lumen: что доделать, прежде чем подключать второй салон», лид с жирными осями, мета «2026-09-04 · 8 находок → 4 блока, 1 отложена · Второй салон — после этого», красный вердикт, Блок 1 (2 карточки: чип «Код» M, чип «Решение+код» L, Что/Зачем, mono-источник), Блок 2 (2 карточки «Решение», бейдж «—», «Что решить:»), Блок 3 (2 карточки одним абзацем), футер «Блок 4 «Потом» — 1 находка… / Отложено — 1 находка… / Порядок: сначала Блок 1…».

ЧЕКПОИНТ — вопросы владельцу (по одному): 1) читается ли порядок и заголовки блоков («Кровь из носа — чиню в коде» / «Решения — нужны от тебя» / «Скоро — усиливает продукт»); 2) понятны ли чипы Код/Решение/Решение+код и бейдж S/M/L; 3) достаточно ли футера для «Потом»/отложенного. Показать словами, чего на макете нет: после мержа карточка задачи станет зачёркнутой с зелёным чипом «Сделано» и уедет в конец блока, в мете появится «устарел на N задач». Реального кода дальше по плану (session-start / finishing / new-task) до одобрения макета не трогаем.
--- ПРОВЕРКА:
open .forge/sketches/status-report-mockup.html — в браузере видны «Lumen: что доделать…», карточка «Главное одной фразой», три блока «Блок 1/2/3», футер с «Блок 4 «Потом» — 1 находка». grep -c 'class="tag' .forge/sketches/status-report-mockup.html → 3. ls .forge/ — файла status-report.json НЕТ (образец остался в scratchpad).


===== [renderer] ШАГ 4: Шаг 4. HTML и снимки — не в git: .forge/.gitignore здесь + шаблоны в backup.sh и init.md (~10 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/.forge/.gitignore (добавить 2 строки); Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/memory-backup/backup.sh (heredoc строки 35-42 + цикл после строки 42); Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/init.md (heredoc строки 788-795); Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/memory-backup/SKILL.md:46 (список мусора); Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-memory-backup.sh (новый тест 13 перед тестом (8))
--- ЧТО:
1) /Users/mac/Projects/Plugin/plugin/.forge/.gitignore — сейчас 6 строк (.github-*, .inject-state, .last-backup, .migration-declined, graph.json, state.yml). Дописать:

status-report.html
reports/shots/

(JSON .forge/status-report.json НЕ игнорируется — это память, backup.sh делает git add .forge, строка 45.)

2) backup.sh создаёт .forge/.gitignore только если его нет (строка 34: `if [ ! -f .forge/.gitignore ]; then`) — у всех проектов на v7.6.0 файл уже есть, и без дописывания HTML с шестью снимками (~1 МБ) уедет в git-память. Поэтому два изменения. В heredoc (строки 35-42) после `graph.json` добавить две строки `status-report.html` и `reports/shots/`. Сразу после закрывающего `fi` (строка 42), перед `git add .forge` (строка 45) — идемпотентное дописывание:

# Отчёт «Что дальше» (v7.7.0): HTML и снимки регенерируются из JSON — в старый .gitignore дописываем
for junk in status-report.html reports/shots/; do
    grep -qxF "$junk" .forge/.gitignore 2>/dev/null || echo "$junk" >> .forge/.gitignore
done

(Проверено на копии: существующий сьют test-memory-backup.sh — все PASS; во второй прогон строки не дублируются.)

3) commands/init.md строки 788-795 — тот же heredoc-шаблон `[ -f .forge/.gitignore ] || cat > .forge/.gitignore <<'EOF'`: добавить те же две строки после `graph.json`.

4) skills/memory-backup/SKILL.md:46 — строка «`backup.sh` сам создаёт `.forge/.gitignore` со служебным мусором: `.inject-state`, `.last-backup`, `state.yml`, `.github-*`, `graph.json`.» → дописать «, `status-report.html`, `reports/shots/` (отчёт «Что дальше» регенерируется из `status-report.json`)».

5) test-memory-backup.sh — вставить перед блоком «# --- (8) не git-репозиторий → тихий exit 0 ---» (строка 182):

# --- (13) старый .forge/.gitignore без строк отчёта → дописывает; HTML/снимки отчёта не коммитятся, JSON — да ---

new_repo
printf '.inject-state\nstate.yml\n' > .forge/.gitignore
echo "<html>" > .forge/status-report.html
mkdir -p .forge/reports/shots && echo x > .forge/reports/shots/a.png
echo '{"findings":[]}' > .forge/status-report.json
run_backup >/dev/null
files=$(git show --name-only --format= HEAD)
run_backup >/dev/null
grep -qxF "status-report.html" .forge/.gitignore \
  && [ "$(grep -c 'status-report.html' .forge/.gitignore)" -eq 1 ] \
  && ! printf '%s' "$files" | grep -qE "status-report.html|reports/shots" \
  && printf '%s' "$files" | grep -q "status-report.json"
check "should append report junk to an existing .forge/.gitignore (idempotent) and commit JSON but never the HTML" $?
cd / && rm -rf "$REPO"
--- ПРОВЕРКА:
bash /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-memory-backup.sh → «All tests passed» (14 PASS, включая новый «should append report junk…»). В корне репозитория: touch .forge/status-report.html && git check-ignore -q .forge/status-report.html && echo ignored && rm .forge/status-report.html → «ignored». diff heredoc'ов: diff <(sed -n '36,43p' forge-plugin/skills/memory-backup/backup.sh) <(sed -n '789,796p' forge-plugin/commands/init.md) → пусто.


===== [renderer] ШАГ 5: Шаг 5. session-start.sh: одна строка «ждут N решений, отчёт устарел на M задач» (~5 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/session-start.sh (вставка перед строкой 52, правка строки 71; строка Phase 5 в таблице 56-62 — см. интерфейсы); Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-status-report.sh (добавить тест 10)
--- ЧТО:
Фрагмент вставить ПОСЛЕ блока версии (строки 43-50, там определяется `plugin_root`) и ПЕРЕД строкой 52 `# Короткое введение — что есть forge и как им пользоваться` (mem_warn выше, строки 15-41, — образец: пустая строка-переменная, заполняется только когда есть что сказать):

# Напоминание про отчёт «Что дальше» (Фаза 5): одна строка и только когда есть что напомнить
# (render.py summary молчит, если открытых решений нет и отчёт не устарел). Без PyYAML — JSON.
report_warn=""
if [ -f ".forge/status-report.json" ]; then
    line=$(python3 "$plugin_root/skills/status-report/render.py" summary 2>/dev/null || true)
    if [ -n "$line" ]; then
        report_warn=$'\n\n'"$line — напомни пользователю одной строкой; вопросы по решениям задавай по одному и только по его слову."
    fi
fi

Строка 71 `$warning$mem_warn` → `$warning$mem_warn$report_warn`.

Таблица фаз (строки 56-62): после `  Phase 4   /forge:execute     — реализация` добавить `  Phase 5   /forge:status-report — отчёт «что дальше»: что чиню, что решаешь` — ЕСЛИ это не делает кусок «документация/фазы» (см. интерфейсы; править одно место один раз).

(Проверено на патченной копии хука: с образцом → в additionalContext появляется «📊 Отчёт «Что дальше»: ждут 3 решения владельца, отчёт устарел на 2 задачи (…)»; без файла — строки нет; JSON-экранирование эмодзи и «» проходит; set -euo pipefail не роняет — `|| true` и if.)

Тест 10 — дописать в test-status-report.sh перед `echo "---"`:

# --- (10) session-start.sh: одна строка про отчёт — только когда он есть ---

HOOK="$(cd "$(dirname "$0")/../../hooks" && pwd)/session-start.sh"
new_project
out=$(bash "$HOOK" 2>/dev/null)
! printf '%s' "$out" | grep -q "Отчёт «Что дальше»"
check "session-start should stay silent about the report when there is none" $?
render sample "$JSON" >/dev/null
out=$(bash "$HOOK" 2>/dev/null)
printf '%s' "$out" | grep -q "ждут 3 решения владельца"
check "session-start should remind about open owner decisions in one line" $?
cd / && rm -rf "$WORK"
--- ПРОВЕРКА:
bash /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-status-report.sh → 15 PASS, «All tests passed». Ручная: T=$(mktemp -d) && cd "$T" && mkdir .forge && python3 /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/render.py sample .forge/status-report.json >/dev/null && bash /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/session-start.sh | grep -o 'ждут 3 решения владельца' → «ждут 3 решения владельца». В корне репозитория плагина (отчёта нет): bash forge-plugin/hooks/session-start.sh | grep -c 'Что дальше' → 0 (или 1, если добавлена строка Phase 5 в таблицу — тогда grep -c 'ждут' → 0).


===== [renderer] ШАГ 6: Шаг 6. finishing-a-development-branch: после мержа — render.py merged <slug> (~5 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/finishing-a-development-branch/SKILL.md (вставка перед строкой 131)
--- ЧТО:
Option 1 (влить локально). Якорь — строка 131: `**Затем сохрани память и результат в облако** (тихо, по процедуре скилла `memory-backup`):`. Вставить ПЕРЕД ней (после блока про index.yml, строки 126-129), чтобы изменённый JSON уехал тем же коммитом backup.sh:

**Отчёт «Что дальше» (Фаза 5)** — если в проекте есть `.forge/status-report.json`, обнови его механически, без нового аудита, **до** сохранения памяти (обновлённые данные уедут тем же коммитом):
```bash
python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" merged "<task-slug>"
```
Карточка с этой задачей уходит в «сделано», счётчик «устарел на N задач» растёт на 1, `.forge/status-report.html` пересобран. Нет отчёта — скрипт молчит, ничего не делай и не упоминай. Если в выводе `FORGE-REPORT: сделано → …` — добавь к подтверждению одну фразу: *«В отчёте „Что дальше“ отметил задачу сделанной»*. Полная пересборка с аудитом — только по слову «собери отчёт».

`<task-slug>` — тот же slug задачи (без даты и .md), что идёт в github-sync и в `backup.sh` («память отменённой задачи: <slug>», строка 183 этого же файла).
--- ПРОВЕРКА:
grep -n 'render.py" merged' /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/finishing-a-development-branch/SKILL.md → одна строка, номер между 129 и строкой «Затем сохрани память» (grep -n 'Затем сохрани память' → номер больше). Функционально: в корне репозитория (отчёта нет) python3 forge-plugin/skills/status-report/render.py merged x; echo rc=$? → пустой вывод, «rc=0».


===== [renderer] ШАГ 7: Шаг 7. new-task шаг 9: привязка карточки к задаче через метку [card:<id>] (~5 мин)
ФАЙЛЫ: Изменить: /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/new-task/SKILL.md (после абзаца шага 9, строка 104)
--- ЧТО:
Механизм связки карточка↔задача: скилл status-report, отдавая карточку «Код» в работу, пишет в хэндофф-тексте метку `[card:<id>]` (например: «Беру карточку [card:f1] «Клиент не получает подтверждение…» в работу. Запускаю /forge:new-task на это.»). Пользователь может и сам написать `/forge:new-task card:f1`. new-task ищет метку в тексте, с которого начался запуск (хэндофф или аргумент команды).

В new-task/SKILL.md после шага 9 (строка 104 заканчивается «…sync молча перестанет находить Issue задачи.») добавить абзац:

   **Если задача пришла из отчёта «Что дальше»** — в тексте, с которого начался запуск (хэндофф скилла status-report или аргумент команды), стоит метка `[card:<id>]` / `card:<id>`, например `[card:f3]`. Сразу после сохранения файла привяжи карточку к задаче — HTML пересоберётся сам, в карточке появится «→ в работе: <slug>», а после мержа finishing по этому же slug отметит её сделанной:
   ```bash
   python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" link <id> <slug>
   ```
   Метки нет — шаг молча пропусти. Метку в текст задачи не переноси.
--- ПРОВЕРКА:
grep -n 'render.py" link' /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/new-task/SKILL.md → одна строка сразу после шага 9 (между «9. **Сохрани**» и «10. **GitHub-sync**»). Функционально: T=$(mktemp -d) && cd "$T" && mkdir .forge && R=/Users/mac/Projects/Plugin/plugin/forge-plugin/skills/status-report/render.py && python3 $R sample .forge/status-report.json >/dev/null && python3 $R link f3 refund-fee | tail -1 → «FORGE-REPORT: карточка f3 → задача refund-fee»; grep -o 'в работе: refund-fee' .forge/status-report.html → найдено.


===== [renderer] ШАГ 8: Шаг 8. Полный прогон bash-тестов хуков и чистота репозитория (~3 мин)
ФАЙЛЫ: Проверка: /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/*.sh
--- ЧТО:
Прогнать все четыре существующих сьюта + новый и убедиться, что в корне проекта не осталось мусора от макета/снимков:

  cd /Users/mac/Projects/Plugin/plugin
  for t in forge-plugin/tests/hooks/test-*.sh; do printf '%s: ' "$t"; bash "$t" | tail -1; done
  git status --short | grep -E '^\?\? (\.playwright-mcp|.*\.png|status-report)' || echo clean
--- ПРОВЕРКА:
Каждая строка вывода цикла заканчивается «All tests passed» (test-bash-safety, test-context-inject, test-memory-backup, test-status-report, test-user-rules-check). Вторая команда печатает «clean». `git status --short` содержит .forge/sketches/status-report-mockup.html как новый файл (память, коммитится), но НЕ содержит .forge/status-report.json/.html.


===== INTERFACES:
ФАЙЛЫ
- Данные (память, коммитится backup.sh через `git add .forge`): /Users/mac/Projects/Plugin/plugin/.forge/status-report.json (в проектах пользователя — `.forge/status-report.json` от корня репозитория).
- HTML (живой, перезаписывается, в .forge/.gitignore): .forge/status-report.html — всегда рядом с JSON (`jp.with_suffix(".html")`).
- Снимки (в .forge/.gitignore): .forge/reports/shots/<id>.png; в JSON — только путь от корня проекта.
- Макет: .forge/sketches/status-report-mockup.html (коммитится как память). Образец данных для макета — в scratchpad, НЕ в .forge/status-report.json (иначе session-start начнёт напоминать про Lumen).
- Рендерер: forge-plugin/skills/status-report/render.py — из скиллов зовётся `python3 "$CLAUDE_PLUGIN_ROOT/skills/status-report/render.py" …`, из session-start.sh — `python3 "$plugin_root/skills/status-report/render.py" summary` (plugin_root определён в строке 44 хука).
- Проверенные прототипы (та же сессия, копировать 1:1): …/scratchpad/proto/skills/status-report/render.py, …/scratchpad/proto/tests/hooks/test-status-report.sh, патченные копии …/proto/hooks/session-start.sh и …/proto/skills/memory-backup/backup.sh, снимок макета …/proto/mock/shot-full.png, образец JSON …/proto/mock/.forge/status-report.json (префикс: /private/tmp/claude-501/-Users-mac-Projects-Plugin-plugin/aea62bdd-df53-4c7c-8f72-7f21aee7a52a/scratchpad).

JSON-СХЕМА .forge/status-report.json (пишет скилл status-report при полной сборке; render.py меняет только status/done_at/task_slug/stale_tasks/updated_at)
{
  "project": "Lumen",                          — в <title> «{project} · Что дальше» и H1
  "eyebrow": "Дорожная карта · перед запуском на второй салон",   — mono uppercase над H1
  "question": "что доделать, прежде чем подключать второй салон", — хвост H1: «{project}: {question}»
  "built_at": "2026-09-04",                    — дата полной сборки (в мете)
  "updated_at": "2026-09-04",                  — последнее механическое обновление (merged/link ставят сами)
  "stale_tasks": 0,                            — влито задач после сборки; merged → +1 всегда; полная сборка → 0
  "next_after": "Второй салон — после этого",  — мета «что идёт после документа»
  "sources": {"analysts": 4, "found": 8},      — лид: «4 аналитика прошли по коду и памяти проекта и нашли 8 пробелов…» (генерирует рендерер; found по умолчанию = len(findings))
  "verdict": {"text": "… **жирное** … начинать надо отсюда.", "finding_id": "f2"},   — блок «Главное одной фразой»; finding_id хранится для скилла, в HTML не рисуется
  "findings": [{
    "id": "f1",                                — уникальный; для link и verdict.finding_id
    "owner": "code" | "decision" | "both",     — чип Код (красный) / Решение (фиолетовый) / Решение+код (контурный)
    "effort": "S" | "M" | "L" | "-",           — бейдж; для owner=decision всегда «—»
    "block": "crit" | "biz" | "imp" | "pol",   — crit → «Блок N · Кровь из носа — чиню в коде» (Что:/Зачем:), biz → «Решения — нужны от тебя» (Что решить:), imp → «Скоро — усиливает продукт» (абзац без лейблов), pol → только в футер («Блок N «Потом» — K находок, не срочно (2 примера)»)
    "status": "open" | "done" | "deferred",    — deferred: вне блоков, считается в мете («K отложено») и футере; done: карточка зачёркнута, зелёный чип «Сделано», в конце блока, тело скрыто
    "title": "…", "what": "…", "why": "…",     — why может быть "" (тогда абзац «Зачем» не рисуется)
    "source": "src/booking/confirm.py:41" | "созвон 2026-08-30" | ".forge/direction.yml",   — mono-строка внизу карточки
    "task_slug": "confirm-timeout",            — опц.; ставит `link`; по нему `merged` находит карточку; в HTML «→ в работе: slug» / «→ влито: slug»
    "screenshot": ".forge/reports/shots/calendar-mobile.png",   — опц.; путь от корня проекта (или абсолютный); нет файла → карточка без картинки, без ошибки
    "done_at": "2026-09-05"                    — ставит `merged`
  }]
}
Разметка в text/what/why/title: только `**жирный**` → <b>; всё остальное html.escape (quote=True). Опечатка/тег в тексте вёрстку не ломает.
Счётчики (считает рендерер, Клод не пишет): total = len(findings); blocks = число разных block среди status≠deferred (pol — тоже блок); deferred = status==deferred; done = status==done; open_decisions = status==open и owner∈{decision,both}. Мета: «{total} находок → {blocks} блоков[, {deferred} отложено]»; при stale_tasks>0 добавляется «обновлён {updated_at} · устарел на {stale_tasks} задач».

CLI render.py (всегда rc 0, кроме неверных аргументов → rc 2; перед любым режимом: если .forge/status-report.json не в cwd — chdir в `git rev-parse --show-toplevel`)
- `render [json] [html]` — по умолчанию .forge/status-report.json → .forge/status-report.html; stdout «FORGE-REPORT: HTML собран → <html>»; нет JSON → «FORGE-REPORT: нет .forge/status-report.json — отчёт ещё не собирали».
- `sample <out.json>` — образец (проект Lumen, 8 находок) для макета/тестов.
- `merged <task-slug> [json]` — карточки с task_slug==slug и status≠done → done + done_at; stale_tasks+1 (всегда, даже без совпадения); updated_at=today; HTML пересобран; stdout «FORGE-REPORT: сделано → <titles>; отчёт устарел на N задач» либо «FORGE-REPORT: карточки с задачей «slug» нет; отчёт устарел на N задач»; нет JSON → молча.
- `link <finding-id> <task-slug> [json]` — task_slug на карточке, updated_at, HTML пересобран; «FORGE-REPORT: карточка f3 → задача slug» / «FORGE-REPORT: карточки f3 нет».
- `summary [json]` — одна строка «📊 Отчёт «Что дальше»: ждут N решений владельца, отчёт устарел на M задач (.forge/status-report.html; пересобрать — «собери отчёт»)»; части опускаются при нуле; при обоих нулях / нет файла / битый JSON — пустой вывод.

ТОЧКИ ВЫЗОВА
- session-start.sh (SessionStart, hooks.json): фрагмент `report_warn` перед строкой 52, `$warning$mem_warn$report_warn` в строке 71. Инжектируется в additionalContext; Клод пересказывает одной строкой, вопросы по решениям — по одному и только по слову владельца.
- finishing-a-development-branch/SKILL.md Option 1: `render.py merged "<task-slug>"` между блоком index.yml (126-129) и «Затем сохрани память» (131) — ДО backup.sh, чтобы JSON уехал тем же коммитом.
- new-task/SKILL.md шаг 9: после сохранения task-файла — `render.py link <id> <slug>`, если в тексте запуска есть метка `[card:<id>]` или `card:<id>`.
- Скилл status-report (другой кусок): полная сборка пишет JSON целиком (stale_tasks=0, built_at=today) и зовёт `render.py render`, затем `open .forge/status-report.html`; хэндофф карточки «Код» в new-task обязан содержать `[card:<id>]`; снимки: Playwright MCP сохраняет ТОЛЬКО в корень проекта или `.playwright-mcp/` (проверено: «File access denied: … is outside allowed roots. Allowed roots: <проект>/.playwright-mcp, <проект>») → `browser_take_screenshot` с `filename: ".playwright-mcp/shot-<id>.png"`, `scale: "css"`, потом `mkdir -p .forge/reports/shots && mv .playwright-mcp/shot-<id>.png .forge/reports/shots/<id>.png && rm -rf .playwright-mcp`; в JSON — путь `.forge/reports/shots/<id>.png`. Ошибка favicon 404 в консоли Playwright — шум, не ошибка страницы.
- statusline.sh (кусок «фазы»): `status-report) phase_icon="📊 Фаза 5: Что дальше"` в case (строки 26-36); скилл пишет `.forge/state.yml` с `phase: status-report`.
- Таблица фаз в session-start.sh (строки 56-62) — строка Phase 5 добавляется ОДНИМ куском (здесь шаг 5 или кусок «документация»), не дважды.
- .forge/.gitignore: `status-report.html`, `reports/shots/` — в этом репо руками, в проектах пользователя — heredoc backup.sh/init.md + идемпотентный цикл в backup.sh.
- .forge/index.yml catalog (кусок «память/фазы»): запись `status-report: {path: .forge/status-report.json, tags: [report, what-next, findings, decisions, owner]}` БЕЗ note — бюджет инжекции 2500 байт (сейчас 2320, context-inject.sh:17-22).

===== OPEN QUESTIONS:
- Порядок «макет первым»: у меня макет — шаги 1-3 одним блоком (тест RED → render.py → макет → чекпоинт). Если нужен буквально один первый шаг — слить 1-3 в «Шаг 1. Макет» с тем же чекпоинтом; TDD внутри него сохраняется.
- Сделанная карточка: сейчас остаётся в своём блоке зачёркнутой с чипом «Сделано» и тело скрыто; в макете такой карточки нет (образец без done). Показать владельцу словами на чекпоинте или добавить в SAMPLE одну done-карточку (тогда счётчик в мете станет «8 находок → 4 блока, 1 отложена» + футер «Сделано с момента сборки — 1 карточка»)?
- `merged` увеличивает stale_tasks даже если карточки с таким slug нет (влитая задача = отчёт устарел). Оставить так или считать только по совпавшим карточкам?
- Заголовки блоков зашиты константами (BLOCKS) — «Решения — нужны от тебя» без имени второго человека («…и Влада» в эталоне). Достаточно на первую версию или нужен опциональный override `blocks: {biz: {title, sub}}` в JSON?
- Кто добавляет строку `Phase 5   /forge:status-report` в таблицу session-start.sh (строки 56-62) и запись в catalog index.yml — мой шаг 5 или кусок «документация/фазы»? Сейчас в шаге 5 помечено «если не делает другой кусок».
- В `biz`-карточках why рисуется отдельным приглушённым абзацем без лейбла (формат говорит «один абзац»). Оставить как на макете или склеивать what+why в один абзац?

===== RISKS:
- Playwright MCP пишет файлы только в корень проекта и .playwright-mcp/ (проверено вживую в этой сессии): без `mv` в .forge/reports/shots/ и `rm -rf .playwright-mcp` в скилле снимки и логи останутся мусором в корне; корневой .gitignore их не исключает.
- В проектах на v7.6.0 .forge/.gitignore уже существует, backup.sh создаёт его только при отсутствии — без идемпотентного цикла (шаг 4) HTML со снимками (~1 МБ за 6 снимков) уедет в git-память при первом же «сохрани».
- Снимки не в git → после смерти диска рендер из JSON даёт карточки без картинок (путь есть, файла нет). Приемлемо по решению «скриншоты — только путь», но владельцу об этом стоит сказать один раз.
- Google Fonts требуют сеть: офлайн страница откроется на системных шрифтах (fallback-стек прописан), вёрстка не ломается, но выглядит иначе.
- session-start.sh зовёт python3 на каждый старт при наличии JSON (~40 мс) — при отсутствии python3 `|| true` гасит ошибку, напоминания просто не будет; хук не падает (проверено на копии).
- Образец данных «Lumen» нельзя класть в .forge/status-report.json репозитория плагина — иначе каждая сессия будет напоминать про «3 решения» несуществующего проекта; шаг 3 держит образец в scratchpad.
- render.py при вызове из поддиректории делает chdir в git toplevel; вне git-репозитория и не из корня — пути по умолчанию не найдутся и merged/summary молча промолчат (rc 0). Для скиллов это норма (они работают от корня), но диагностика тихая.
- Верхняя граница: HTML с 6 снимками 1280×800 ≈ 1.2 МБ — файл локальный, лимитов нет; но если владелец попросит снимать fullPage длинные страницы, размер растёт быстро — лимит «не больше 6» держать в скилле.
- Тесты test-status-report.sh опираются на конкретные русские строки («8 находок → 4 блока», «ждут 3 решения владельца»): любая правка текстов/склонений в render.py после реакции на макет требует синхронной правки ожиданий в тесте.
