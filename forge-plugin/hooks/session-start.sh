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

# Версия плагина из manifest (fallback — просто без версии)
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
version=$(grep -m1 '"version"' "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
if [ -n "$version" ]; then
    header="Forge plugin (v${version}) активен."
else
    header="Forge plugin активен."
fi

# Короткое введение — что есть forge и как им пользоваться
intro="<forge-plugin-loaded>
${header}

Доступен pipeline разработки:
  Phase 0   /forge:unblocker   — куда двигать проект
  Phase 1   /forge:new-task    — сырой запрос → чистая задача
  Phase 1.5 /forge:refine-idea — реалити-чек идеи
  Phase 2   /forge:plan        — план с чекпоинтами
  Phase 3   /forge:critique    — 4 персоны рвут план
  Phase 4   /forge:execute     — реализация

И 30+ поддерживающих скиллов (debugging, design, deployment, etc.) — триггерятся автоматически по описанию или вызываются явно через /forge:<name>.

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
