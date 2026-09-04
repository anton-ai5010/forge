#!/usr/bin/env bash
# Тесты для hooks/session-start.sh — интро плагина в новой сессии.
# Проверяем: таблица фаз (в т.ч. Phase 5), напоминание по отчёту «Что дальше»
# (через render.py summary) и главное — хук ВСЕГДА отдаёт валидный JSON.
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
    mkdir -p .forge
    guard_isolated
}

# Запуск хука так же, как это делает Claude Code: stdin пустой, путь к плагину в env
run_hook() { CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK" </dev/null 2>/dev/null; }

# Текст, который увидит Claude (additionalContext), — из JSON, а не из сырого вывода
context_of() { printf '%s' "$1" | python3 -c "import json,sys; print(json.load(sys.stdin)['hookSpecificOutput']['additionalContext'])"; }

valid_json() { printf '%s' "$1" | python3 -c "import json,sys; json.load(sys.stdin)" >/dev/null 2>&1; }

# --- (1) таблица фаз: пайплайн целиком, включая Phase 5 ---

new_project
out=$(run_hook); rc=$?
ctx=$(context_of "$out")
[ "$rc" -eq 0 ] \
  && valid_json "$out" \
  && printf '%s' "$ctx" | grep -q "Phase 5" \
  && printf '%s' "$ctx" | grep -q "forge:status-report" \
  && printf '%s' "$ctx" | grep -q "forge:execute"
check "intro should list the whole pipeline including Phase 5 (status-report)" $?

# --- (2) без отчёта — ни слова про него ---

! printf '%s' "$ctx" | grep -q "📊 Отчёт"
check "should stay silent about the report when the project has none" $?
cd / && rm -rf "$WORK"

# --- (3) есть открытые решения и устаревание → одна строка-напоминание ---

new_project
cat > .forge/status-report.json <<'EOF'
{"stale_tasks": 3,
 "findings": [{"id": "a", "owner": "decision", "status": "open"},
              {"id": "b", "owner": "both", "status": "open"},
              {"id": "c", "owner": "decision", "status": "done"},
              {"id": "d", "owner": "code", "status": "open"}]}
EOF
out=$(run_hook); rc=$?
ctx=$(context_of "$out")
[ "$rc" -eq 0 ] \
  && valid_json "$out" \
  && printf '%s' "$ctx" | grep -q "ждут 2 решения владельца" \
  && printf '%s' "$ctx" | grep -q "отчёт устарел на 3 задачи"
check "should remind about open owner decisions and a stale report in one line" $?

# --- (4) решения закрыты и отчёт свежий → тишина ---

cat > .forge/status-report.json <<'EOF'
{"stale_tasks": 0, "findings": [{"id": "a", "owner": "decision", "status": "done"}]}
EOF
out=$(run_hook)
ctx=$(context_of "$out")
valid_json "$out" && ! printf '%s' "$ctx" | grep -q "📊 Отчёт"
check "should stay silent when nothing waits for the owner and the report is fresh" $?

# --- (5) битый JSON отчёта не ломает старт сессии ---

printf '{ это не json' > .forge/status-report.json
out=$(run_hook); rc=$?
[ "$rc" -eq 0 ] && valid_json "$out" && printf '%s' "$(context_of "$out")" | grep -q "Phase 5"
check "should survive a broken status-report.json (exit 0, still valid JSON)" $?
cd / && rm -rf "$WORK"

echo "---"
if [ "$fails" -gt 0 ]; then
    echo "$fails test(s) FAILED"
    exit 1
fi
echo "All tests passed"
exit 0
