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
hook_input=$(cat)
tool_name=$(printf '%s' "$hook_input" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
# Для Bash — берём команду. Для Edit/Write — содержимое.
tool_content=$(printf '%s' "$hook_input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -z "$tool_content" ] && tool_content=$(printf '%s' "$hook_input" | sed -n 's/.*"new_string"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -z "$tool_content" ] && tool_content=$(printf '%s' "$hook_input" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

[ -z "$tool_content" ] && exit 0

# Проходим по правилам
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
            echo "WARN ($rule_name): ${message:-User rule warning}" >&2
            # warn — продолжаем, не блокируем
        fi
    fi
done

exit 0
