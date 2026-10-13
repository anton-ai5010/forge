#!/usr/bin/env bash
# Statusline для forge-plugin — показывает текущую фазу пайплайна
# Срабатывает после каждого сообщения Claude (+ refreshInterval из settings.json)
# Читает .forge/state.yml если есть, иначе graceful degradation

input=$(cat)

# Парсим JSON от Claude Code: used_percentage встречается и в context_window, и в rate_limits —
# поэтому каждое поле берём по своему пути, а не первое попавшееся
IFS=$'\x1f' read -r model pct week < <(printf '%s' "$input" | python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: d = {}
def g(*keys):
    v = d
    for k in keys:
        v = v.get(k) if isinstance(v, dict) else None
    return v
num = lambda v: str(int(v)) if isinstance(v, (int, float)) else ""
print((g("model", "display_name") or "") + "\x1f" + num(g("context_window", "used_percentage")) + "\x1f" + num(g("rate_limits", "seven_day", "used_percentage")))
' 2>/dev/null)

# Текущая ветка git
branch=$(git branch --show-current 2>/dev/null)

# Читаем .forge/state.yml если есть (фаза пайплайна)
phase=""
task=""
if [ -f ".forge/state.yml" ]; then
    phase=$(grep "^phase:" .forge/state.yml 2>/dev/null | cut -d: -f2- | xargs | cut -c1-30)
    task=$(grep "^task:" .forge/state.yml 2>/dev/null | cut -d: -f2- | xargs | cut -c1-35)
fi

# Маппинг фаз → эмодзи (подписи по-русски — их видит пользователь)
phase_icon=""
case "$phase" in
    unblocker|"Phase 0"|0) phase_icon="🧭 Фаза 0: Направление" ;;
    new-task|"Phase 1"|1) phase_icon="🎯 Фаза 1: Понимание задачи" ;;
    refine-idea|"Phase 1.5"|1.5) phase_icon="🔬 Фаза 1.5: Проверка идеи" ;;
    plan|"Phase 2"|2) phase_icon="📋 Фаза 2: План" ;;
    critique|"Phase 3"|3) phase_icon="🔍 Фаза 3: Критика плана" ;;
    execute|"Phase 4"|4) phase_icon="🚀 Фаза 4: Реализация" ;;
    guide|"Phase 5"|5) phase_icon="📖 Фаза 5: Гайд по проекту" ;;
    idle) phase_icon="✅ Задача завершена" ;;
    "") phase_icon="" ;;
    *) phase_icon="📌 $phase" ;;
esac

# Сборка statusline
parts=()
[ -n "$model" ] && parts+=("$model")
[ -n "$phase_icon" ] && parts+=("$phase_icon")
[ -n "$task" ] && parts+=("\"$task\"")
[ -n "$branch" ] && parts+=("🌿$branch")
[ -n "$pct" ] && parts+=("чат ${pct}%")
[ -n "$week" ] && parts+=("неделя ${week}%")

# Соединяем через " | " (явный join — IFS-трюк брал только первый символ)
out=""
for p in "${parts[@]}"; do out="${out:+$out | }$p"; done
printf '%s\n' "${out:-forge}"
