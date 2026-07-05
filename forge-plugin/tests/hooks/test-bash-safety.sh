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

# --- rm на критический путь ---

run_case "rm -rf ~/ блокируется" \
    '{"tool_input":{"command":"rm -rf ~/"}}' 2

run_case "экранированная кавычка не обходит блок" \
    '{"tool_input":{"command":"echo \"done\" && rm -rf ~/"}}' 2

run_case "rm -rf /* блокируется" \
    '{"tool_input":{"command":"rm -rf /*"}}' 2

run_case "rm -r -f / (раздельные флаги) блокируется" \
    '{"tool_input":{"command":"rm -r -f /"}}' 2

run_case "rm -rf \"/\" (путь в кавычках) блокируется" \
    '{"tool_input":{"command":"rm -rf \"/\""}}' 2

run_case "rm --recursive --force / блокируется" \
    '{"tool_input":{"command":"rm --recursive --force /"}}' 2

run_case "rm -rf \$HOME блокируется" \
    '{"tool_input":{"command":"rm -rf $HOME"}}' 2

run_case "rm -rf ./tmp && ls / НЕ блокируется (цель ищем только в rm-сегменте)" \
    '{"tool_input":{"command":"rm -rf ./tmp && ls /"}}' 0

run_case "rm -rf ./build (обычный путь) проходит" \
    '{"tool_input":{"command":"rm -rf ./build"}}' 0

# --- git push --force в main/master ---

run_case "git push -f origin main блокируется" \
    '{"tool_input":{"command":"git push -f origin main"}}' 2

run_case "git push origin main -f (флаг после ветки) блокируется" \
    '{"tool_input":{"command":"git push origin main -f"}}' 2

run_case "git push --force origin master блокируется" \
    '{"tool_input":{"command":"git push --force origin master"}}' 2

run_case "git push --force-with-lease origin main блокируется (консерватизм)" \
    '{"tool_input":{"command":"git push --force-with-lease origin main"}}' 2

run_case "git push -f origin feature (не main/master) проходит" \
    '{"tool_input":{"command":"git push -f origin feature"}}' 0

run_case "git push origin main без force проходит" \
    '{"tool_input":{"command":"git push origin main"}}' 0

run_case "git commit --fixup + push main без force НЕ ловится на букву f" \
    '{"tool_input":{"command":"git commit --fixup abc123 && git push origin main"}}' 0

run_case "git rebase main && git push -f origin my-feature НЕ блокируется (main вне push-сегмента)" \
    '{"tool_input":{"command":"git rebase main && git push -f origin my-feature"}}' 0

run_case "git fetch origin main && git push --force origin feat НЕ блокируется" \
    '{"tool_input":{"command":"git fetch origin main && git push --force origin feat"}}' 0

run_case "git rebase feat && git push -f origin main блокируется (force и main в push-сегменте)" \
    '{"tool_input":{"command":"git rebase feat && git push -f origin main"}}' 2

# --- dd на блочное устройство ---

run_case "dd of=/dev/disk0 (macOS) блокируется" \
    '{"tool_input":{"command":"dd if=/dev/zero of=/dev/disk0"}}' 2

run_case "dd of=/dev/rdisk0 (macOS raw) блокируется" \
    '{"tool_input":{"command":"dd if=/dev/zero of=/dev/rdisk0 bs=1m"}}' 2

run_case "dd of=/dev/sda (Linux) блокируется" \
    '{"tool_input":{"command":"dd if=/dev/zero of=/dev/sda"}}' 2

run_case "dd в обычный файл проходит" \
    '{"tool_input":{"command":"dd if=/dev/urandom of=./file.bin count=1"}}' 0

# --- безопасные команды ---

run_case "безопасный git commit с кавычками проходит" \
    '{"tool_input":{"command":"git commit -m \"safe\""}}' 0

run_case "простая безопасная команда проходит" \
    '{"tool_input":{"command":"ls"}}' 0

# --- fail-open при сломанном python3 (проверяем предупреждение, не молчание) ---

fake_bin=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' > "$fake_bin/python3"
chmod +x "$fake_bin/python3"
stderr_out=$(printf '%s' '{"tool_input":{"command":"rm -rf /"}}' | PATH="$fake_bin:$PATH" "$HOOK" 2>&1 >/dev/null)
rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$stderr_out" | grep -q "ОТКЛЮЧЕНА"; then
    echo "PASS: сломанный python3 — fail-open (exit 0) с громким предупреждением в stderr"
else
    echo "FAIL: сломанный python3 — ожидался exit 0 + предупреждение, получено exit=$rc, stderr='$stderr_out'"
    fails=$((fails + 1))
fi
rm -rf "$fake_bin"

echo "---"
if [ "$fails" -gt 0 ]; then
    echo "$fails test(s) FAILED"
    exit 1
fi
echo "All tests passed"
exit 0
