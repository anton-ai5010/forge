# План: фиксы по отзыву второго пользователя

**Задача:** см. `.forge/tasks/2026-10-21-friend-report-fixes.md`

**Подход:** (1) Кто пользователь — в личном файле `~/.claude/forge-user.yml` (имя, уровень, заметки); `session-start.sh` вставляет строку `USER:`, а если файла нет — просьбу один раз спросить и записать. Стиль ответов и скиллы говорят «пользователь / владелец», без имени. (2) Init больше не пишет копию подсказки в проект; новая защита main — встроенной командой, смотрит путь файла. (3) Старые копии в уже настроенных проектах находит и чинит маленький скрипт `hooks/project-hooks-fix.sh` (check / apply / decline) — только то, что совпадает с нашим шаблоном; `session-start.sh` по нему пишет одну строку-предложение. (4) `context-inject.sh` всегда вставляет компактный каталог.

**Что увидишь ты:**
- У тебя — как раньше: «Антон», простой язык, голосовой ввод. Это теперь записано в твоём личном файле, а не в плагине.
- В проектах со старыми копиями при старте чата — одна строка «нашёл старые копии хуков плагина (N) — убрать?»; ответ «да» — убрано (с резервной копией), «нет» — больше не предлагается.
- В основной ветке Claude спокойно пишет память и настройки, а код — по-прежнему только в рабочей ветке.
- Перед чисткой твоих 12 проектов — пауза: покажу список, что где поменяется.
- Другу (и любому новому человеку) Claude в первом чате задаст один вопрос: как звать и объяснять попроще или по-техническому.

**Открытые вопросы:** нет.

**Блокеры:** нет. Ветку `feat/friend-report-fixes` execute заведёт от master (текущая `feat/offload-main-chat` — отдельная задача, её файлы не трогаем).

---

## Шаг 1: Личный файл пользователя и строка USER (TDD)

**Файлы:**
- `forge-plugin/tests/hooks/test-session-start.sh` — сначала тесты (в фейковом HOME): есть `~/.claude/forge-user.yml` (`name: Антон`, `level: simple`, `notes: голосовой ввод — опечатки норма`) → в инжекте `USER: Антон · уровень: simple · голосовой ввод…`; нет файла → строка `USER: не задан — в этом чате один раз спроси …` с точной командой записи; `FORGE_NESTED=1` → ничего.
- `forge-plugin/hooks/session-start.sh` — чтение файла (grep/sed по трём ключам, без PyYAML), строка `user_line` первой в `intro`:
```bash
uf="$HOME/.claude/forge-user.yml"
if [ -f "$uf" ]; then
  u_name=$(sed -n 's/^name:[[:space:]]*//p' "$uf" | head -1); u_level=$(sed -n 's/^level:[[:space:]]*//p' "$uf" | head -1)
  u_notes=$(sed -n 's/^notes:[[:space:]]*//p' "$uf" | head -1)
  user_line="USER: ${u_name:-пользователь} · уровень: ${u_level:-simple}${u_notes:+ · $u_notes} (simple — простой язык без жаргона; technical — термины можно)."
else
  user_line="USER: не задан. В этом чате один раз, коротко спроси: как обращаться и объяснять попроще или по-техническому. Ответ запиши: printf 'name: %s\nlevel: %s\n' '<имя>' '<simple|technical>' > ~/.claude/forge-user.yml — и больше не спрашивай."
fi
```
- Создать: `~/.claude/forge-user.yml` владельца — `name: Антон`, `level: simple`, `notes: голосовой ввод — опечатки норма, не переспрашивать`.

**Как проверим:** `bash forge-plugin/tests/hooks/test-session-start.sh` — новые сначала FAIL, потом PASS.

## Шаг 2: Убрать имя из стиля и скиллов

**Файлы** (по списку помощника, 2026-10-21):
- `output-styles/forge-concise.md:10,18,23,38,49,53` — «You are talking to Anton — a non-coder…» → «You are talking to the user described in the `USER:` line of the forge session banner (name, level). Level `simple` (default): non-coder — plain language, no jargon, …; `technical`: terms are fine, still concise.» Голосовой ввод — «если в USER это указано».
- «Антон / Anton» → «владелец» / «пользователь» (смысл тот же): `skills/project-unblocker/SKILL.md:42,61`, `skills/roadmap/SKILL.md` (9 мест), `skills/github-sync/SKILL.md:8,10,65,88`, `skills/github-sync/sync.sh:34`, `skills/hookify/SKILL.md` (9), `skills/evolve/SKILL.md` (9, включая путь `:26` `-run-media-anton-…` → «папка памяти проекта в `~/.claude/projects/`»), `skills/using-forge/SKILL.md:175`.
- «пользователь — не-кодер» как факт → «если уровень пользователя simple (строка USER)»: только там, где это правило поведения (`new-task:19,39`, `plan:45,183`, `refine-idea:15,27`, `critique:164,180,204`, `execute:66`, `finishing:68,83,121`). Не трогаем: авторство в манифестах (`plugin.json`, `marketplace.json` — это автор, а не пользователь), README, данные (шрифт Anton, примеры JSON).

**Как проверим:** `grep -rn -E "Anton|Антон" forge-plugin/{output-styles,skills,hooks,commands,agents} | grep -v -E "ui-ux-design/data|api-patterns"` → пусто; `test-plugin-facts.sh`, `test-codex-review.sh` PASS.

---

### ✅ Чекпоинт A: имя и уровень

Что показываем: строка `USER:` из инжекта для твоего файла и для пустого HOME (что увидит друг), новое начало стиля ответов.
Что подтверждает пользователь: «так ко мне и к другу обращаться».

---

## Шаг 3: Скрипт чистки старых хуков (TDD)

**Файлы:**
- Создать: `forge-plugin/tests/hooks/test-project-hooks-fix.sh` — во временном проекте: (а) `UserPromptSubmit` с `bash …/forge/7.8.0/hooks/context-inject.sh` (рабочий путь и мёртвый) → `check` печатает «копий подсказки: 1»; (б) `PreToolUse` с дословной старой командой защиты (`commands/init.md:718`) → «старая защита: 1»; (в) переделанная защита (другой текст) → не считается; (г) чужие хуки и `permissions` остаются байт-в-байт; (д) `apply` → копия удалена, старая защита заменена на новую, резервная копия `settings.json.bak-forge`, JSON валиден; (е) `decline` → `check` молчит; (ж) нет `.claude/settings*.json` → молча rc=0.
- Создать: `forge-plugin/hooks/project-hooks-fix.sh` — `check|apply|decline [project_dir]`; python3 (stdlib json) по `.claude/settings.json` и `.claude/settings.local.json`; копия подсказки = команда хука UserPromptSubmit содержит `/hooks/context-inject.sh` и `forge`; старая защита = команда ровно равна `OLD_GUARD`; новая = `NEW_GUARD` (шаг 4); отказ — маркер `~/.claude/forge-state/<проект>/hooks-fix-declined`; всегда rc=0.

**Как проверим:** `bash forge-plugin/tests/hooks/test-project-hooks-fix.sh` → сначала FAIL, потом все PASS.

## Шаг 4: Новая защита main + init без копии подсказки

**Файлы:**
- `forge-plugin/commands/init.md` — 15a (поиск `context-inject.sh`) убрать; 15b: из шаблона убрать `UserPromptSubmit`, `PreToolUse` — новая команда (встроенный python3, без путей к плагину):
```bash
python3 -c 'import json,os,subprocess,sys
p=(json.load(sys.stdin).get("tool_input") or {}).get("file_path","")
top=subprocess.run(["git","rev-parse","--show-toplevel"],capture_output=True,text=True).stdout.strip()
br=subprocess.run(["git","branch","--show-current"],capture_output=True,text=True).stdout.strip()
ap=os.path.realpath(p) if p else ""
rel=os.path.relpath(ap,top) if top and ap.startswith(top+os.sep) else None
ok=br not in ("main","master") or rel is None or rel.split(os.sep)[0] in (".forge",".claude") or rel=="CLAUDE.md"
ok or (print("BLOCKED: код на main/master не правим — заведи ветку задачи (память .forge, .claude, CLAUDE.md — можно)",file=sys.stderr),sys.exit(2))'
```
  Правило слияния: «есть копия хука подсказки или старая защита — `bash <plugin>/hooks/project-hooks-fix.sh apply`»; отчёт init (`:894`) — без «UserPromptSubmit hook».
- Тот же `NEW_GUARD` — константой в `project-hooks-fix.sh` (одна правда: init.md ссылается на скрипт в комментарии).
- Тест защиты (в `test-project-hooks-fix.sh`): JSON на stdin в git-репо на master — `.forge/x.yml` → rc 0; `src/a.py` → rc 2 + текст; `/tmp/x` → rc 0; на ветке `feat/x` `src/a.py` → rc 0.

**Как проверим:** тесты шага 3 + 4 PASS.

## Шаг 5: Строка-предложение при старте сессии

**Файлы:** `forge-plugin/hooks/session-start.sh` — после `init_warn`: `fix=$(bash "$plugin_root/hooks/project-hooks-fix.sh" check)`; непусто → `hooks_warn="FORGE: в настройках проекта старые копии хуков плагина ($fix). Предложи пользователю одной строкой убрать; «да» → bash $plugin_root/hooks/project-hooks-fix.sh apply; «нет» → … decline."`; тест в `test-session-start.sh` (проект с копией → строка есть; после `decline` — нет).

**Как проверим:** `test-session-start.sh` PASS.

## Шаг 6: Каталог памяти в L0 всегда (TDD)

**Файлы:**
- `forge-plugin/tests/hooks/test-context-inject.sh` — новый случай: index.yml с `now.task` на 3 КБ и `catalog:` (2 записи) в конце → в контексте строка `catalog: map(structure,files,…) · conventions(naming,…)`.
- `forge-plugin/hooks/context-inject.sh:20-36` — в том же python: секция `catalog:` → компактно «`catalog: <имя>(<теги через запятую>) · …`» (путь не нужен: `.forge/<имя>.yml`, нестандартный путь — в скобках), идёт сразу за `dont:` и вычитается из бюджета; из основного текста секцию убрать, чтобы не дублировать.

**Как проверим:** `test-context-inject.sh` PASS (старые 9а–9в тоже).

---

### ✅ Чекпоинт B: перед чисткой твоих проектов

Что показываем: `check` по 12 проектам — таблица «проект · копий подсказки · старая защита · переделанная (не трогаем)».
Что подтверждает пользователь: «чисти».

---

## Шаг 7: Чистка проектов владельца и этого репо

**Что делаем:** `apply` по списку из чекпоинта B (резервные копии рядом); в этом репо `.claude/settings.json` — тоже `apply` (там мёртвая копия `/home/anton` и старая защита); несохранённые правки разрешений в нём (с прошлых сессий) не трогаем — скрипт меняет только хуки.

**Как проверим:** `check` по всем 12 → пусто; живой прогон в `Games/zombashnya`: `claude -p "ок" --output-format json` → в основном jsonl одна строка `FORGE L0` на промпт.

## Шаг 8: Выпуск 7.13.1

**Файлы:** версии в `forge-plugin/.claude-plugin/plugin.json`, `forge-plugin/.claude-plugin/marketplace.json`, `.claude-plugin/marketplace.json`, `.forge/index.yml`; `CLAUDE.md` (раздел Native features / FORGE Context) — строка про `~/.claude/forge-user.yml` и `project-hooks-fix.sh`; `.forge/decisions.yml` — DEC; в backlog «Фиксы по отзыву» — 4 пункта отмечены сделанными.

**Как проверим:** все `forge-plugin/tests/hooks/test-*.sh` зелёные.
