#!/usr/bin/env bash
# Тесты для hooks/session-start.sh — интро плагина в новой сессии.
# Проверяем: таблица фаз (в т.ч. Phase 5), напоминание по гайду по проекту
# (через render.py summary), подсказка про старый отчёт «Что дальше» (миграция)
# и главное — хук ВСЕГДА отдаёт валидный JSON.
#
# ⚠️ Изоляция обязательна: cd в $(command substitution) НЕ переживает подстановку
# (урок git-tests-must-isolate-cwd) — поэтому new_project это обычная функция.

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-start.sh"
PLUGIN_REPO="$(cd "$PLUGIN_ROOT/.." && git rev-parse --show-toplevel 2>/dev/null || true)"
fails=0
# Хук пишет отметки в ~/.claude/forge-state — тесты не должны мусорить в настоящий HOME
REAL_HOME="$HOME"; export HOME="$(mktemp -d)"

guard_isolated() {
    local top
    top=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$PLUGIN_REPO" ] && [ "$top" = "$PLUGIN_REPO" ]; then
        echo "ABORT: тест оказался в реальном репозитории плагина ($top) — изоляция сломана" >&2
        exit 1
    fi
}

check() {
    local desc="$1" ok="$2"
    if [ "$ok" -eq 0 ]; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc"
        fails=$((fails + 1))
    fi
}

WORK=""
new_project() {
    WORK=$(mktemp -d)
    cd "$WORK" || exit 1
    mkdir -p .forge/guide
    guard_isolated
}

# Запуск хука так же, как это делает Claude Code: stdin пустой, путь к плагину в env
run_hook() { CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK" </dev/null 2>/dev/null; }

# Текст, который увидит Claude (additionalContext), — из JSON, а не из сырого вывода
context_of() { printf '%s' "$1" | python3 -c "import json,sys; print(json.load(sys.stdin)['hookSpecificOutput']['additionalContext'])"; }

valid_json() { printf '%s' "$1" | python3 -c "import json,sys; json.load(sys.stdin)" >/dev/null 2>&1; }

# Последняя версия гайда = максимум по имени .forge/guide/vX.Y.json; в тестах одна — v1.0
GUIDE=.forge/guide/v1.0.json

# --- (1) таблица фаз: пайплайн целиком, включая Phase 5 ---

new_project
out=$(run_hook); rc=$?
ctx=$(context_of "$out")
[ "$rc" -eq 0 ] \
  && valid_json "$out" \
  && printf '%s' "$ctx" | grep -q "Phase 5" \
  && printf '%s' "$ctx" | grep -q "forge:guide" \
  && printf '%s' "$ctx" | grep -q "forge:execute"
check "intro should list the whole pipeline including Phase 5 (guide)" $?
printf '%s' "$ctx" | grep -q "WORKFLOWS:.*model.*effort.*model-roles.md" && printf '%s' "$ctx" | grep -q "requesting-code-review"
check "intro should carry the workflow rule (model+effort per agent, review scheme) for ultracode" $?
printf '%s' "$ctx" | grep -q "MODELS:.*forge:scout.*Explore"
check "intro should forbid helpers without a model (search via forge:scout, Explore only with model)" $?
printf '%s' "$ctx" | grep -q "ROUTING:"
check "project with .forge should get memory routing rules" $?

# --- без .forge: нет правил памяти, один раз предложить /forge:init ---
NOF=$(mktemp -d); ( cd "$NOF" && git init -q
  out=$(run_hook); c=$(context_of "$out")
  ! printf '%s' "$c" | grep -q "ROUTING:" && ! printf '%s' "$c" | grep -q "DOC DISCIPLINE" && printf '%s' "$c" | grep -q "/forge:init"
  echo "rc1=$?"
  out=$(run_hook); c=$(context_of "$out")
  ! printf '%s' "$c" | grep -q "/forge:init"; echo "rc2=$?" ) > "$NOF/res"
grep -q "rc1=0" "$NOF/res"; check "project without .forge: no memory rules, offers /forge:init" $?
grep -q "rc2=0" "$NOF/res"; check "project without .forge: init offer only once" $?
rm -rf "$NOF"

# --- (2) без гайда — ни слова про него ---

! printf '%s' "$ctx" | grep -q "📖 Гайд"
check "should stay silent about the guide when the project has none" $?
cd / && rm -rf "$WORK"

# --- (3) есть открытые решения и устаревание → одна строка-напоминание ---
# Правило счётчика (render.py counts → open_decisions, то же в плане «Стыки → Счётчики»):
#   решения со статусом open|discuss           → A2 (open), A3 (discuss), O1 (open)   = 3
#   + решения default с fire: true             → A1                                    = 1
#     (P1 default без 🔥 — не считается; A4 accepted и A5 dropped — не считаются)
#   + находки status open с owner decision|both,
#     не вынесенные в O-вопрос (moved_out)     → f1 (decision), f2 (both)              = 2
#     (f3 done, f4 owner code, f5 deferred+links ["O1"] = moved_out — не считаются)
#   итого 6 → «ждут 6 решений владельца»; stale_tasks 3 → «гайд устарел на 3 задачи».
# built_at обязан быть не null — иначе summary скажет «ещё не собрана» вместо счётчиков.

new_project
cat > "$GUIDE" <<'EOF'
{"meta": {"version": "1.0"},
 "built_at": "2026-09-01",
 "stale_tasks": 3,
 "decisions": [{"code": "P1", "group": "P", "status": "default", "fire": false},
               {"code": "A1", "group": "A", "status": "default", "fire": true},
               {"code": "A2", "group": "A", "status": "open"},
               {"code": "A3", "group": "A", "status": "discuss", "fire": true},
               {"code": "A4", "group": "A", "status": "accepted"},
               {"code": "A5", "group": "A", "status": "dropped"},
               {"code": "O1", "group": "O", "status": "open", "fire": true}],
 "findings": [{"id": "f1", "owner": "decision", "status": "open"},
              {"id": "f2", "owner": "both", "status": "open"},
              {"id": "f3", "owner": "decision", "status": "done"},
              {"id": "f4", "owner": "code", "status": "open"},
              {"id": "f5", "owner": "decision", "status": "deferred", "links": ["O1"]}]}
EOF
out=$(run_hook); rc=$?
ctx=$(context_of "$out")
[ "$rc" -eq 0 ] \
  && valid_json "$out" \
  && printf '%s' "$ctx" | grep -q "📖 Гайд по проекту v1.0: ждут 6 решений владельца" \
  && printf '%s' "$ctx" | grep -q "гайд устарел на 3 задачи" \
  && printf '%s' "$ctx" | grep -q "render.py verdict"
check "should remind about open owner decisions and a stale guide in one line" $?

# --- (4) решения закрыты и гайд свежий → тишина ---

cat > "$GUIDE" <<'EOF'
{"meta": {"version": "1.0"}, "built_at": "2026-09-01", "stale_tasks": 0,
 "decisions": [{"code": "P1", "group": "P", "status": "default", "fire": false},
               {"code": "A1", "group": "A", "status": "accepted"}],
 "findings": [{"id": "f1", "owner": "decision", "status": "done"}]}
EOF
out=$(run_hook)
ctx=$(context_of "$out")
valid_json "$out" && ! printf '%s' "$ctx" | grep -q "📖 Гайд"
check "should stay silent when nothing waits for the owner and the guide is fresh" $?

# --- (5) битый JSON гайда не ломает старт сессии ---

printf '{ это не json' > "$GUIDE"
out=$(run_hook); rc=$?
[ "$rc" -eq 0 ] && valid_json "$out" && printf '%s' "$(context_of "$out")" | grep -q "Phase 5"
check "should survive a broken v1.0.json (exit 0, still valid JSON)" $?

# --- (6) гайда нет, но лежит старый отчёт «Что дальше» → подсказка про миграцию («собери гайд») ---

rm -rf .forge/guide
printf '{"findings":[{"id":"a","owner":"decision","status":"open"}]}' > .forge/status-report.json
out=$(run_hook); rc=$?
ctx=$(context_of "$out")
[ "$rc" -eq 0 ] \
  && valid_json "$out" \
  && printf '%s' "$ctx" | grep -q "старый отчёт «Что дальше»" \
  && printf '%s' "$ctx" | grep -q "собери гайд"
check "should hint to migrate a legacy status-report.json into the guide («собери гайд»)" $?
cd / && rm -rf "$WORK"

# --- (7–9) расхождения код/доки (drift-check, раз в сутки, отметка вне репо) — в той же строке, что гайд ---

run_hook_home() { HOME="$1" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK" </dev/null 2>/dev/null; }
FAKE_HOME=$(mktemp -d)

new_project
printf 'structure:\n  app: src/missing.py\n' > .forge/map.yml
cat > "$GUIDE" <<'EOF2'
{"meta": {"version": "1.0"}, "built_at": "2026-09-01", "stale_tasks": 0,
 "decisions": [{"code": "A1", "group": "A", "status": "open"}], "findings": []}
EOF2
out=$(run_hook_home "$FAKE_HOME")
ctx=$(context_of "$out")
valid_json "$out" && printf '%s' "$ctx" | grep "📖 Гайд" | grep -q "доки: 1 расхождение"
check "should merge guide reminder and docs drift into one line" $?
ls "$FAKE_HOME"/.claude/forge-state/*/drift-checked >/dev/null 2>&1
check "should keep the once-a-day drift mark outside the repo (~/.claude/forge-state)" $?

rm -rf .forge/guide
rm -rf "$FAKE_HOME"/.claude/forge-state
out=$(run_hook_home "$FAKE_HOME")
ctx=$(context_of "$out")
valid_json "$out" && printf '%s' "$ctx" | grep -q "📌 Доки: 1 расхождение с кодом"
check "should report docs drift alone when there is no guide" $?

rm -f .forge/map.yml
rm -rf "$FAKE_HOME"/.claude/forge-state
out=$(run_hook_home "$FAKE_HOME")
ctx=$(context_of "$out")
valid_json "$out" && ! printf '%s' "$ctx" | grep -qi "доки:"
check "should stay silent when there is no drift and no guide" $?
cd / && rm -rf "$WORK" "$FAKE_HOME"

# --- (10–14) кто пользователь: строка USER из ~/.claude/forge-user.yml, без файла — один раз спросить ---

new_project
UH=$(mktemp -d); mkdir -p "$UH/.claude"
printf 'name: Антон\nlevel: simple\nnotes: "голосовой ввод — опечатки норма"\n' > "$UH/.claude/forge-user.yml"
ctx=$(context_of "$(run_hook_home "$UH")")
printf '%s' "$ctx" | grep -qx "USER: Антон · уровень: simple · голосовой ввод — опечатки норма"
check "should put the USER line from forge-user.yml (name, level, notes)" $?
printf '%s' "$ctx" | sed -n 2p | grep -q "^USER:"
check "should put the USER line first in the intro" $?
! printf '%s' "$ctx" | grep -q "Как к вам обращаться"
check "should not ask who the user is when forge-user.yml exists" $?

printf 'name: Друг\nlevel: Простой\n' > "$UH/.claude/forge-user.yml"
context_of "$(run_hook_home "$UH")" | grep -qx "USER: Друг · уровень: simple"
check "should normalize a Russian level («Простой») to simple" $?
printf 'name: Друг\nlevel: простой\n' > "$UH/.claude/forge-user.yml"
out=$(LC_ALL=C HOME="$UH" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK" </dev/null 2>/dev/null)
context_of "$out" | grep -qx "USER: Друг · уровень: simple"
check "should normalize a Russian level to simple under LC_ALL=C too" $?
printf 'level: что-то непонятное\n' > "$UH/.claude/forge-user.yml"
context_of "$(run_hook_home "$UH")" | grep -qx "USER: пользователь · уровень: technical"
check "should fall back to a neutral name and technical when level is garbage" $?
printf 'name: "Б\033[0mоб"\nlevel: "simple"\nnotes: a\001b\r\n' > "$UH/.claude/forge-user.yml"
out=$(run_hook_home "$UH")
valid_json "$out" && context_of "$out" | grep -qx "USER: Б\[0mоб · уровень: simple · ab"
check "should drop control characters from forge-user.yml and keep the JSON valid" $?

UH2=$(mktemp -d); mkdir -p "$UH2/.claude"
ctx=$(context_of "$(run_hook_home "$UH2")")
printf '%s' "$ctx" | grep -q "Как к вам обращаться и как объяснять — простыми словами или с терминами" \
  && printf '%s' "$ctx" | grep -q "В конце первого ответа" \
  && printf '%s' "$ctx" | grep -qF "printf 'name: %s\nlevel: %s\n' \"\$FORGE_NAME\" \"\$FORGE_LEVEL\" > ~/.claude/forge-user.yml" \
  && [ -e "$UH2/.claude/forge-state/user-asked" ]
check "should ask once who the user is when there is no forge-user.yml (safe write command, mark set)" $?
ctx=$(context_of "$(run_hook_home "$UH2")")
! printf '%s' "$ctx" | grep -q "Как к вам обращаться" \
  && printf '%s' "$ctx" | grep -q "^USER: пользователь · уровень: не задан (нейтрально: без имени"
check "should not ask again and stay neutral on the second start without forge-user.yml" $?

UH3=$(mktemp -d)
out=$(HOME="$UH3" FORGE_NESTED=1 CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK" </dev/null 2>/dev/null)
[ -z "$out" ] && [ ! -e "$UH3/.claude/forge-state/user-asked" ]
check "should stay silent and not mark the question as asked when FORGE_NESTED=1" $?
cd / && rm -rf "$WORK" "$UH" "$UH2" "$UH3"

# --- (15–17) старая копия подсказки плагина в настройках проекта → строка раз в сутки, после «нет» — тишина ---

new_project
mkdir -p .claude
printf '{\n  "hooks": {\n    "UserPromptSubmit": [\n      {\n        "matcher": "",\n        "hooks": [\n          {\n            "type": "command",\n            "command": "bash /old/forge/hooks/context-inject.sh"\n          }\n        ]\n      }\n    ]\n  }\n}\n' > .claude/settings.json
HH=$(mktemp -d); mkdir -p "$HH/.claude"
ctx=$(context_of "$(run_hook_home "$HH")")
printf '%s' "$ctx" | grep -q "🧹.*лишняя копия подсказки плагина" \
  && printf '%s' "$ctx" | grep -q "project-hooks-fix.sh apply" \
  && printf '%s' "$ctx" | grep -q "project-hooks-fix.sh decline"
check "should offer to clean an old plugin hook copy found in the project settings" $?
ctx=$(context_of "$(run_hook_home "$HH")")
! printf '%s' "$ctx" | grep -q "🧹"
check "should offer the settings cleanup at most once a day" $?
rm -f "$HH"/.claude/forge-state/*/hooks-fix-shown
HOME="$HH" bash "$PLUGIN_ROOT/skills/forge-context/project-hooks-fix.sh" decline "$WORK" >/dev/null
ctx=$(context_of "$(run_hook_home "$HH")")
! printf '%s' "$ctx" | grep -q "🧹"
check "should not offer the settings cleanup after the user declined" $?
cd / && rm -rf "$WORK" "$HH"

# --- (18–21) голос уведомлений: строка только при установленном голосе; имя проекта; выключен / сломался / нет доступа ---

new_project
VHH=$(mktemp -d); mkdir -p "$VHH/.claude"
ctx=$(context_of "$(CLAUDE_PROJECT_DIR="$WORK" run_hook_home "$VHH")")
! printf '%s' "$ctx" | grep -q "🔊"
check "should not mention the voice when it is not installed" $?
VV="$VHH/.claude/forge-voice"; mkdir -p "$VV/venv/bin"; : > "$VV/venv/bin/python"; chmod +x "$VV/venv/bin/python"
printf '{"%s": "Дом"}' "$WORK" > "$VV/names.json"
out=$(CLAUDE_PROJECT_DIR="$WORK" run_hook_home "$VHH"); ctx=$(context_of "$out")
valid_json "$out" && printf '%s' "$ctx" | grep -q "🔊 Голос: работает" && printf '%s' "$ctx" | grep -q "зовёт «Дом»" \
  && printf '%s' "$ctx" | grep -q "voice/notify.py' name 'Y'" && printf '%s' "$ctx" | grep -q "voice/notify.py' volume тише|громче|N" && printf '%s' "$ctx" | grep -q "voice/notify.py' mute"
check "should show the voice line with the spoken project name and the commands" $?
touch "$VV/mute"
ctx=$(context_of "$(CLAUDE_PROJECT_DIR="$WORK" run_hook_home "$VHH")")
printf '%s' "$ctx" | grep -q "🔊 Голос: выключен" && printf '%s' "$ctx" | grep -q "voice/notify.py' unmute"
check "should say the voice is muted" $?
rm -f "$VV/mute"; printf 'голос завис — не отвечает больше минуты\n' > "$VV/broken"
out=$(CLAUDE_PROJECT_DIR="$WORK" run_hook_home "$VHH"); ctx=$(context_of "$out")
valid_json "$out" && printf '%s' "$ctx" | grep -q "🔊 Голос: сломался: голос завис" && printf '%s' "$ctx" | grep -q "почини голос" \
  && printf '%s' "$ctx" | grep -q "voiced.log"
check "should report a broken voice with the reason and how to fix it" $?
rm -f "$VV/broken"; touch "$VV/no-access"
ctx=$(context_of "$(CLAUDE_PROJECT_DIR="$WORK" run_hook_home "$VHH")")
printf '%s' "$ctx" | grep -q "🔊 Голос: не видит окна"
check "should say the voice cannot see windows without accessibility access" $?
cd / && rm -rf "$WORK" "$VHH"

echo "---"
if [ "$fails" -gt 0 ]; then
    echo "$fails test(s) FAILED"
    exit 1
fi
echo "All tests passed"
exit 0
