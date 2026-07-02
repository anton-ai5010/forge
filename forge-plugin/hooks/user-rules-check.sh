#!/usr/bin/env bash
# PreToolUse hook — применяет user-defined правила из .forge/hookrules/*.md
# Создаются через /forge:hookify по запросу пользователя.
#
# Формат правила (frontmatter):
#   matcher: Bash|Edit|Write    # на каких инструментах действует
#   action: block | warn        # block = exit 2, warn = exit 0 со stderr
#   pattern: 'regex'            # что искать в команде/контенте
#   message: "..."              # объяснение Claude почему правило сработало
#
# Hook читает все .forge/hookrules/*.md и применяет совпадения.

set -euo pipefail

# Нет правил — пропускаем
[ -d ".forge/hookrules" ] || exit 0
rules=$(find .forge/hookrules -name "*.md" -type f 2>/dev/null)
[ -z "$rules" ] && exit 0

# Парсим JSON от Claude Code
# python3 вместо sed: sed-регэксп обрывался на первой экранированной кавычке,
# и контент с кавычкой обходил все правила.
hook_input=$(cat)
tool_name=$(printf '%s' "$hook_input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || true)
# Для Bash — берём команду. Для Edit/Write — содержимое.
tool_input_field() {
    printf '%s' "$hook_input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('$1',''))" 2>/dev/null || true
}
tool_content=$(tool_input_field command)
[ -z "$tool_content" ] && tool_content=$(tool_input_field new_string)
[ -z "$tool_content" ] && tool_content=$(tool_input_field content)

[ -z "$tool_content" ] && exit 0

# Проходим по правилам
warn_msgs=""
for rule_file in $rules; do
    # Парсим YAML frontmatter (упрощённо — построчно)
    matcher=$(grep -E "^matcher:" "$rule_file" 2>/dev/null | head -1 | sed 's/^matcher:[[:space:]]*//' | tr -d '"')
    action=$(grep -E "^action:" "$rule_file" 2>/dev/null | head -1 | sed 's/^action:[[:space:]]*//' | tr -d '"' | xargs)
    pattern=$(grep -E "^pattern:" "$rule_file" 2>/dev/null | head -1 | sed "s/^pattern:[[:space:]]*//" | sed "s/^'//;s/'$//;s/^\"//;s/\"$//")
    message=$(grep -E "^message:" "$rule_file" 2>/dev/null | head -1 | sed 's/^message:[[:space:]]*//' | sed 's/^"//;s/"$//')

    # Пропускаем если matcher не совпадает с tool
    [ -n "$matcher" ] && ! printf '%s' "$tool_name" | grep -qE "$matcher" && continue

    # Применяем pattern
    if [ -n "$pattern" ] && printf '%s' "$tool_content" | grep -qE "$pattern"; then
        rule_name=$(basename "$rule_file" .md)
        if [ "$action" = "block" ]; then
            echo "BLOCKED ($rule_name): ${message:-User rule violation}" >&2
            exit 2
        else
            # warn — копим, не блокируем (stderr при exit 0 до Claude не доходит)
            warn_msg="WARN ($rule_name): ${message:-User rule warning}"
            if [ -n "$warn_msgs" ]; then
                warn_msgs="${warn_msgs}; ${warn_msg}"
            else
                warn_msgs="$warn_msg"
            fi
        fi
    fi
done

# Warn'ы отдаём Claude через JSON stdout (permissionDecision allow + reason)
if [ -n "$warn_msgs" ]; then
    escape_for_json() {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        s="${s//$'\n'/\\n}"
        s="${s//$'\r'/\\r}"
        s="${s//$'\t'/\\t}"
        printf '%s' "$s"
    }
    escaped=$(escape_for_json "$warn_msgs")
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "${escaped}"
  }
}
EOF
fi

exit 0
