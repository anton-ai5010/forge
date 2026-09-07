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

echo "---"
if [ "$fails" -gt 0 ]; then
    echo "$fails test(s) FAILED"
    exit 1
fi
echo "All tests passed"
exit 0
