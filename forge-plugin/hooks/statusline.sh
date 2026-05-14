#!/usr/bin/env bash
# Statusline для forge-plugin — показывает текущую фазу пайплайна
# Срабатывает после каждого сообщения Claude (+ refreshInterval из settings.json)
# Читает .forge/state.yml если есть, иначе graceful degradation

input=$(cat)

# Парсим JSON от Claude Code
model=$(printf '%s' "$input" | sed -n 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
pct=$(printf '%s' "$input" | sed -n 's/.*"used_percentage"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' | cut -d. -f1)
pct=${pct:-0}

# Текущая ветка git
branch=$(git branch --show-current 2>/dev/null)

# Читаем .forge/state.yml если есть (фаза пайплайна)
phase=""
task=""
if [ -f ".forge/state.yml" ]; then
    phase=$(grep "^phase:" .forge/state.yml 2>/dev/null | cut -d: -f2- | xargs | head -c 30)
    task=$(grep "^task:" .forge/state.yml 2>/dev/null | cut -d: -f2- | xargs | head -c 35)
fi

# Маппинг фаз → эмодзи
phase_icon=""
case "$phase" in
    new-task|"Phase 1"|1) phase_icon="🎯 Phase 1: Understanding" ;;
    plan|"Phase 2"|2) phase_icon="📋 Phase 2: Planning" ;;
    critique|"Phase 3"|3) phase_icon="🔍 Phase 3: Critique" ;;
    execute|"Phase 4"|4) phase_icon="🚀 Phase 4: Implementation" ;;
    "") phase_icon="" ;;
    *) phase_icon="📌 $phase" ;;
esac

# Сборка statusline
parts=()
[ -n "$model" ] && parts+=("$model")
[ -n "$phase_icon" ] && parts+=("$phase_icon")
[ -n "$task" ] && parts+=("\"$task\"")
[ -n "$branch" ] && parts+=("🌿$branch")
[ "$pct" -gt 0 ] && parts+=("${pct}%")

# Соединяем через " | "
IFS=" | "
printf "%s\n" "${parts[*]}"
