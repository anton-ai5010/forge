#!/usr/bin/env bash
# UserPromptSubmit hook — inject L0 context + STYLE + graph hint into every prompt
# Skill discovery now relies on skill descriptions (Claude triggers them automatically)
# Reads ONLY index.yml (~200 tokens) or index.md (legacy, ~400 tokens)

set -euo pipefail

# Check for FORGE docs (new format first, then legacy)
if [ -f ".forge/index.yml" ]; then
    index_content=$(cat .forge/index.yml 2>/dev/null || echo "")
elif [ -f ".forge/index.md" ]; then
    index_content=$(cat .forge/index.md 2>/dev/null || echo "")
else
    exit 0
fi

# Current branch
branch=$(git branch --show-current 2>/dev/null || echo "unknown")

# Last 3 commits
git_log=$(git log --oneline -3 2>/dev/null || echo "no git")

# Consume hook input (we don't parse it — skill triggering is now on descriptions)
cat >/dev/null

# ============ GRAPH HINT ============
graph_hint=""
if [ -f ".forge/graph.json" ]; then
    node_count=$(python3 -c "import json; d=json.load(open('.forge/graph.json')); print(len(d.get('nodes',d.get('elements',{}).get('nodes',[]))))" 2>/dev/null || echo "?")
    graph_hint="--- Graph: .forge/graph.json (${node_count} nodes). Before grep/find, try: graphify query/path/explain --graph .forge/graph.json"
fi

# ============ BUILD CONTEXT ============
# Escape for JSON
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

context="FORGE L0 CONTEXT (auto-injected):\n\n${index_content}\n\n--- Branch: ${branch}\n--- Recent: ${git_log}"

# Add graph hint if available
if [ -n "$graph_hint" ]; then
    context="${context}\n${graph_hint}"
fi

# ============ COMMUNICATION STYLE ============
context="${context}\n\nSTYLE: Сжимай ответы. Конкретные правила:\n- Первое предложение — что ты делаешь или предлагаешь. Без преамбул и лести.\n- Максимум 1 уровень списка. Никаких вложенных буллетов, таблиц с вариантами A/B/C/D, нумерованных шагов 1-7.\n- Если есть выбор — предложи ОДИН путь и коротко скажи почему. Не вываливай 3 варианта чтобы пользователь решал за тебя.\n- Один вопрос за раз. Не два, не 'и ещё'. Если нужно несколько — задай первый, остальные после ответа.\n- Технические термины (файл, функция, API, миграция) оставляй — они не пугают. Но не нагромождай по 5 в предложении.\n- Длинный ответ = плохой ответ. Если получилось больше 15 строк — выкинь половину. Структура не заменяет ясность.\n- Не пиши финальных 'если согласен — стартуем', 'дай отмашку', 'жду ответа'. Просто жди.\n- Файл, функция, строка — конкретно, не абстрактно. Мат допустим. Без воды."

context="${context}\n\nROUTING: Match catalog[].tags with current task to decide which L1 files to load. Do NOT load all files — only what matches.\n\nDOC DISCIPLINE: If you just made a technical decision — record in .forge/decisions.yml. If an approach failed — record in .forge/dead-ends.yml. If you learned something non-obvious — record in .forge/learnings.yml. Do it NOW, not later."

escaped=$(escape_for_json "$context")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "${escaped}"
  }
}
EOF

exit 0
