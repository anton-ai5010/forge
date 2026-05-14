#!/usr/bin/env bash
# SessionStart hook — лёгкое введение в forge plugin
# Не дампим весь using-forge skill — Claude подгрузит через Skill tool когда нужно.
# Содержимое using-forge становится lazy-load по trigger через description match.

set -euo pipefail

# Legacy warning (если кто-то имеет старую папку)
legacy_skills_dir="${HOME}/.config/forge/skills"
warning=""
if [ -d "$legacy_skills_dir" ]; then
    warning="\n\n⚠️ Найдена legacy папка ~/.config/forge/skills — Claude Code её НЕ читает. Перенеси скиллы в ~/.claude/skills, а потом удали legacy."
fi

# Короткое введение — что есть forge и как им пользоваться
intro="<forge-plugin-loaded>
Forge plugin (v6.2.3) активен.

Доступен 4-фазный pipeline разработки:
  Phase 1 /new-task   — раскрутить сырую задачу в чистую задача + критерий
  Phase 2 /plan       — план с чекпоинтами
  Phase 3 /critique   — 4 параллельных персоны рвут план
  Phase 4 /execute    — реализация через субагентов

И ~24 поддерживающих скилла (debugging, design, deployment, etc.) — триггерятся автоматически по описанию или вызываются явно через /forge:<name>.

ROUTING: Match .forge/index.yml catalog[].tags with current task to decide which L1 files to load. Do NOT load all L1 files — only what matches.

DOC DISCIPLINE: If you just made a technical decision — record in .forge/decisions.yml. If an approach failed — record in .forge/dead-ends.yml. If you learned something non-obvious — record in .forge/learnings.yml. Do it NOW, not later.

Для глубокого введения — Skill tool: forge:using-forge.
$warning
</forge-plugin-loaded>"

# Escape для JSON
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

escaped=$(escape_for_json "$intro")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${escaped}"
  }
}
EOF

exit 0
