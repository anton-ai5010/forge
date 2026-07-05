#!/usr/bin/env bash
# UserPromptSubmit hook — minimal L0 context injection.
# STYLE rules → moved to output-styles/forge-concise.md (native Output Style, auto-cached)
# ROUTING + DOC DISCIPLINE → moved to session-start.sh (one-time per session)
# Skill discovery → relies on skill descriptions (Claude auto-triggers)

set -euo pipefail

# Check for FORGE docs (new format first, then legacy)
truncate_note=""
if [ -f ".forge/index.yml" ]; then
    index_content=$(head -c 2500 .forge/index.yml 2>/dev/null || echo "")
    index_size=$(wc -c < .forge/index.yml 2>/dev/null || echo 0)
    if [ "$index_size" -gt 2500 ]; then
        truncate_note=$'\n'"[index.yml truncated — читай файл целиком при необходимости]"
    fi
elif [ -f ".forge/index.md" ]; then
    index_content=$(cat .forge/index.md 2>/dev/null || echo "")
else
    exit 0
fi

# Consume hook input (we don't parse it)
cat >/dev/null

# Current branch + last 3 commits
branch=$(git branch --show-current 2>/dev/null || echo "unknown")
git_log=$(git log --oneline -3 2>/dev/null || echo "no git")

# ============ GRAPH HINT ============
# Советуем graphify только если CLI реально установлен
graph_hint=""
if [ -f ".forge/graph.json" ] && command -v graphify >/dev/null 2>&1; then
    node_count=$(python3 -c "import json; d=json.load(open('.forge/graph.json')); print(len(d.get('nodes',d.get('elements',{}).get('nodes',[]))))" 2>/dev/null || echo "?")
    graph_hint=$'\n'"--- Graph: .forge/graph.json (${node_count} nodes). Before grep/find, try: graphify query/path/explain --graph .forge/graph.json"
fi

# ============ BUILD CONTEXT ============
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

context="FORGE L0 CONTEXT (auto-injected):"$'\n\n'"${index_content}"$'\n\n'"--- Branch: ${branch}"$'\n'"--- Recent: ${git_log}${graph_hint}${truncate_note}"

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
