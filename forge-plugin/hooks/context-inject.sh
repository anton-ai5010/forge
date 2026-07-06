#!/usr/bin/env bash
# UserPromptSubmit hook — minimal L0 context injection.
# STYLE rules → moved to output-styles/forge-concise.md (native Output Style, auto-cached)
# ROUTING + DOC DISCIPLINE → moved to session-start.sh (one-time per session)
# Skill discovery → relies on skill descriptions (Claude auto-triggers)
# Дедупликация: полный блок — только при новой сессии / изменении контента /
# каждом 16-м промпте (страховка после /compact); иначе короткая строка-маркер.

set -euo pipefail

# Check for FORGE docs (new format first, then legacy)
truncate_note=""
if [ -f ".forge/index.yml" ]; then
    # Обрезка по границе символа: head -c режет байты и разваливает кириллицу
    # посередине буквы (битый UTF-8 уезжает в JSON). python3 выкидывает
    # неполный хвостовой символ; fallback на head -c если python3 сломан.
    index_content=$(python3 -c "import sys; sys.stdout.write(open('.forge/index.yml','rb').read()[:2500].decode('utf-8','ignore'))" 2>/dev/null \
        || head -c 2500 .forge/index.yml 2>/dev/null || echo "")
    index_size=$(wc -c < .forge/index.yml 2>/dev/null || echo 0)
    if [ "$index_size" -gt 2500 ]; then
        truncate_note=$'\n'"[index.yml truncated — читай файл целиком при необходимости]"
    fi
elif [ -f ".forge/index.md" ]; then
    index_content=$(cat .forge/index.md 2>/dev/null || echo "")
else
    exit 0
fi

# Читаем hook input — нужен session_id для дедупликации
hook_input=$(cat 2>/dev/null || true)
session_id=$(printf '%s' "$hook_input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || true)
if [ -z "$session_id" ]; then
    # Fallback: PPID + день — стабильны в рамках одной сессии Claude Code
    session_id="ppid-${PPID}-$(date +%Y%m%d)"
fi

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

# ============ ДЕДУПЛИКАЦИЯ ============
# Состояние: .forge/.inject-state — одна строка "session_id hash счётчик_коротких".
# Файл под .forge/ — в git не попадает (init игнорирует всю директорию).
state_file=".forge/.inject-state"

hash_context() {
    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$context" | shasum | cut -d' ' -f1
    elif command -v md5sum >/dev/null 2>&1; then
        printf '%s' "$context" | md5sum | cut -d' ' -f1
    else
        printf '%s' "$context" | cksum | cut -d' ' -f1
    fi
}
ctx_hash=$(hash_context 2>/dev/null || echo "nohash")

prev_session=""; prev_hash=""; prev_count=0
if [ -f "$state_file" ]; then
    read -r prev_session prev_hash prev_count < "$state_file" 2>/dev/null || true
fi
# Битый счётчик → считаем что пора полную (fail-open в сторону полного контекста)
case "$prev_count" in ''|*[!0-9]*) prev_count=99 ;; esac

if [ "$prev_session" = "$session_id" ] && [ "$prev_hash" = "$ctx_hash" ] && [ "$prev_count" -lt 15 ]; then
    # Ничего не изменилось — короткий маркер вместо полного блока (~30 токенов вместо ~800)
    printf '%s %s %s\n' "$session_id" "$ctx_hash" $((prev_count + 1)) > "$state_file" 2>/dev/null || true
    context="FORGE L0: без изменений (полный контекст выше; файл .forge/index.yml)"
else
    printf '%s %s %s\n' "$session_id" "$ctx_hash" 0 > "$state_file" 2>/dev/null || true
fi

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
