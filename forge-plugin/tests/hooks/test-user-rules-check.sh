#!/usr/bin/env bash
# Тесты для hooks/user-rules-check.sh — hookify-правила из .forge/hookrules/*.md.
# Прогоняет хук с JSON payload'ами в изолированной tmp-директории.

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/../../hooks" && pwd)/user-rules-check.sh"
fails=0
workdir=$(mktemp -d)
cd "$workdir"
mkdir -p .forge/hookrules

check() {
    local desc="$1" expected="$2" payload="$3"
    local actual=0
    printf '%s' "$payload" | "$HOOK" >/dev/null 2>&1 || actual=$?
    if [ "$actual" -eq "$expected" ]; then
        echo "PASS: $desc (exit $actual)"
    else
        echo "FAIL: $desc (expected exit $expected, got $actual)"
        fails=$((fails + 1))
    fi
}

# --- block-правило ---

cat > .forge/hookrules/no-force.md <<'EOF'
---
matcher: Bash
action: block
pattern: 'git push --force'
message: "Нельзя force-push"
---
EOF

check "should block (exit 2) when pattern matches command" 2 \
    '{"tool_name":"Bash","tool_input":{"command":"git push --force origin dev"}}'

check "should pass (exit 0) when command is clean" 0 \
    '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'

check "should pass (exit 0) when matcher does not include tool" 0 \
    '{"tool_name":"Edit","tool_input":{"new_string":"git push --force origin dev"}}'

# --- warn-правило: exit 0 + валидный JSON с причиной ---

cat > .forge/hookrules/warn-todo.md <<'EOF'
---
matcher: Bash
action: warn
pattern: 'TODO'
message: "В команде TODO"
---
EOF
out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"echo TODO"}}' | "$HOOK" 2>/dev/null)
rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'TODO' in d['hookSpecificOutput']['permissionDecisionReason']" 2>/dev/null; then
    echo "PASS: should emit valid warn-JSON with reason when warn rule matches"
else
    echo "FAIL: should emit valid warn-JSON with reason when warn rule matches (exit=$rc, out='$out')"
    fails=$((fails + 1))
fi
rm .forge/hookrules/warn-todo.md

# --- правило без строки matcher не должно ронять хук (grep под set -e) ---

cat > .forge/hookrules/no-matcher.md <<'EOF'
---
action: block
pattern: 'FORBIDDEN_MARKER'
message: "Правило без matcher действует на все инструменты"
---
EOF

check "should block (exit 2, not crash 1) when rule has no matcher line and pattern matches" 2 \
    '{"tool_name":"Edit","tool_input":{"new_string":"x FORBIDDEN_MARKER y"}}'

check "should pass (exit 0, not crash 1) when rule has no matcher line and content is clean" 0 \
    '{"tool_name":"Edit","tool_input":{"new_string":"clean content"}}'

rm .forge/hookrules/no-matcher.md

# --- NotebookEdit: new_source ловится ---

cat > .forge/hookrules/nb.md <<'EOF'
---
matcher: NotebookEdit
action: block
pattern: 'SECRET_CELL'
message: "Нельзя секреты в ноутбук"
---
EOF

check "should block (exit 2) when NotebookEdit new_source matches" 2 \
    '{"tool_name":"NotebookEdit","tool_input":{"new_source":"x = SECRET_CELL"}}'

rm .forge/hookrules/nb.md

# --- сломанный python3: fail-open с громким предупреждением, не молчание ---

fake_bin=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' > "$fake_bin/python3"
chmod +x "$fake_bin/python3"
stderr_out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push --force origin dev"}}' | PATH="$fake_bin:$PATH" "$HOOK" 2>&1 >/dev/null)
rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$stderr_out" | grep -q "ОТКЛЮЧЕНЫ"; then
    echo "PASS: should fail-open (exit 0) with loud stderr warning when python3 is broken"
else
    echo "FAIL: should fail-open (exit 0) with loud stderr warning when python3 is broken (exit=$rc, stderr='$stderr_out')"
    fails=$((fails + 1))
fi
rm -rf "$fake_bin"

cd / && rm -rf "$workdir"

echo "---"
if [ "$fails" -gt 0 ]; then
    echo "$fails test(s) FAILED"
    exit 1
fi
echo "All tests passed"
exit 0
