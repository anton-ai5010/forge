#!/usr/bin/env bash
# Тесты для hooks/bash-safety.sh — прогоняет хук с JSON payload'ами
# и проверяет exit-коды (0 = разрешить, 2 = заблокировать).

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/../../hooks" && pwd)/bash-safety.sh"
fails=0

run_case() {
    local desc="$1" payload="$2" expected="$3"
    local actual=0
    printf '%s' "$payload" | "$HOOK" >/dev/null 2>&1 || actual=$?
    if [ "$actual" -eq "$expected" ]; then
        echo "PASS: $desc (exit $actual)"
    else
        echo "FAIL: $desc (expected exit $expected, got $actual)"
        fails=$((fails + 1))
    fi
}

run_case "rm -rf ~/ блокируется" \
    '{"tool_input":{"command":"rm -rf ~/"}}' 2

run_case "экранированная кавычка не обходит блок" \
    '{"tool_input":{"command":"echo \"done\" && rm -rf ~/"}}' 2

run_case "безопасный git commit с кавычками проходит" \
    '{"tool_input":{"command":"git commit -m \"safe\""}}' 0

run_case "простая безопасная команда проходит" \
    '{"tool_input":{"command":"ls"}}' 0

echo "---"
if [ "$fails" -gt 0 ]; then
    echo "$fails test(s) FAILED"
    exit 1
fi
echo "All tests passed"
exit 0
