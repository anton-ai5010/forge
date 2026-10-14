#!/usr/bin/env bash
# UserPromptSubmit hook — minimal L0 context injection.
# STYLE rules → moved to output-styles/forge-concise.md (native Output Style, auto-cached)
# ROUTING + DOC DISCIPLINE → moved to session-start.sh (one-time per session)
# Skill discovery → relies on skill descriptions (Claude auto-triggers)
# Дедупликация: полный блок — только при новой сессии / изменении контента /
# каждом 16-м промпте (страховка после /compact); иначе короткая строка-маркер.
[ -n "$FORGE_NESTED" ] && exit 0   # вложенный вызов claude из сжимателя логов — молчим

set -euo pipefail

# Check for FORGE docs (new format first, then legacy)
truncate_note=""; no_forge=""
if [ -f ".forge/index.yml" ]; then
    # Обрезка по границе символа: head -c режет байты и разваливает кириллицу
    # посередине буквы (битый UTF-8 уезжает в JSON). python3 выкидывает
    # неполный хвостовой символ; fallback на head -c если python3 сломан.
    # Секция dont:/constraints: (жёсткие «никогда») идёт первой и целиком,
    # остальное режется в оставшийся бюджет 2500 байт.
    index_content=$(python3 -c "
import re
raw = open('.forge/index.yml','rb').read().decode('utf-8','ignore')
lines = raw.splitlines(keepends=True)
sec, rest, inside = [], [], False
for l in lines:
    if re.match(r'(dont|constraints):', l):
        inside = True
    elif inside and re.match(r'[^\\s#-]', l):
        inside = False
    (sec if inside else rest).append(l)
head = ''.join(sec)
budget = max(2500 - len(head.encode('utf-8')), 0)
tail = ''.join(rest).encode('utf-8')[:budget].decode('utf-8','ignore')
import sys
sys.stdout.write(head + tail)
" 2>/dev/null \
        || head -c 2500 .forge/index.yml 2>/dev/null || echo "")
    index_size=$(wc -c < .forge/index.yml 2>/dev/null || echo 0)
    if [ "$index_size" -gt 2500 ]; then
        truncate_note=$'\n'"[index.yml truncated — читай файл целиком при необходимости]"
    fi
elif [ -f ".forge/index.md" ]; then
    index_content=$(cat .forge/index.md 2>/dev/null || echo "")
else
    no_forge=1   # без .forge/ L0 не инжектим, но гигиена чата ниже работает
    index_content=""
fi

# Читаем hook input — нужен session_id для дедупликации
hook_input=$(cat 2>/dev/null || true)
session_id=$(printf '%s' "$hook_input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || true)
if [ -z "$session_id" ]; then
    # Fallback: PPID + день — стабильны в рамках одной сессии Claude Code
    session_id="ppid-${PPID}-$(date +%Y%m%d)"
fi

escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

context=""
if [ -z "$no_forge" ]; then
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
fi

# ============ ГИГИЕНА ЧАТА ============
# Подсказка «чат разросся» — один раз за сессию. Размер контекста — из хвоста
# transcript_path (последняя assistant-запись с usage); строка состояния не нужна.
fstate="$HOME/.claude/forge-state"
case "$session_id" in *[!A-Za-z0-9_.-]*) sid_safe="" ;; *) sid_safe="$session_id" ;; esac
if [ -n "$sid_safe" ] && [ ! -e "$fstate/hint-ctx-$sid_safe" ]; then
    ctx_tokens=$(printf '%s' "$hook_input" | python3 -c "
import json, os, sys
try:
    path = json.load(sys.stdin).get('transcript_path') or ''
    size = os.path.getsize(path)
    with open(path, 'rb') as f:
        f.seek(max(size - 2097152, 0))
        tail = f.read().decode('utf-8', 'ignore')
    for line in reversed(tail.splitlines()):
        if '\"usage\"' not in line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        u = (d.get('message') or {}).get('usage') if d.get('type') == 'assistant' else None
        if u:
            print(sum(int(u.get(k) or 0) for k in ('input_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens')))
            break
except Exception:
    pass
" 2>/dev/null || true)
    case "$ctx_tokens" in ''|*[!0-9]*) ctx_tokens=0 ;; esac
    if [ "$ctx_tokens" -gt 250000 ]; then
        hint="--- Чат разросся (~$((ctx_tokens / 1000)) тыс. токенов в памяти на каждый ход) — продолжать в новом чате дешевле. Скажи владельцу одной строкой: «чат разросся — дешевле продолжить в новом, сказать «передай» — дам текст для нового чата?»; работу не останавливай."
        context="${context:+${context}$'\n'}${hint}"
        { mkdir -p "$fstate" && touch "$fstate/hint-ctx-$sid_safe"; } 2>/dev/null || true
    fi
fi

# Без .forge/ и без подсказки — молчим, как раньше
[ -z "$context" ] && exit 0

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
