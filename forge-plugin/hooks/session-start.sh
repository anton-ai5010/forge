#!/usr/bin/env bash
# SessionStart hook — лёгкое введение в forge plugin
# Не дампим весь using-forge skill — Claude подгрузит через Skill tool когда нужно.
# Содержимое using-forge становится lazy-load по trigger через description match.
[ -n "$FORGE_NESTED" ] && exit 0   # вложенный вызов claude из сжимателя логов — молчим

set -euo pipefail

# Legacy warning (если кто-то имеет старую папку)
legacy_skills_dir="${HOME}/.config/forge/skills"
warning=""
if [ -d "$legacy_skills_dir" ]; then
    warning=$'\n\n'"⚠️ Найдена legacy папка ~/.config/forge/skills — Claude Code её НЕ читает. Перенеси скиллы в ~/.claude/skills, а потом удали legacy."
fi

# Напоминание о несохранённой памяти проекта (дёшево: пара git-команд, один раз за сессию)
mem_warn=""
if [ -d ".forge" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git check-ignore -q .forge 2>/dev/null; then
        # .forge/.migration-declined — пользователь уже отказался, не пилим каждую сессию
        if [ ! -f ".forge/.migration-declined" ]; then
            mem_warn=$'\n\n'"💾 Память проекта (.forge) не под git — умрёт вместе с диском. Предложи пользователю одной строкой включить сохранение (скилл memory-backup, процедура миграции)."
        fi
    else
        dirty=$(git status --porcelain .forge 2>/dev/null | head -1 || true)
        unpushed=""
        if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
            unpushed=$(git log '@{u}..HEAD' --oneline -- .forge 2>/dev/null | head -1 || true)
        elif git remote get-url origin >/dev/null 2>&1; then
            # origin есть, а upstream нет (например, push падал и не поставил его) —
            # локальные .forge-коммиты считаем неотправленными
            unpushed=$(git log --oneline -1 -- .forge 2>/dev/null | head -1 || true)
        fi
        if [ -n "$dirty" ] || [ -n "$unpushed" ]; then
            last=$(cat .forge/.last-backup 2>/dev/null || echo 0)
            case "$last" in ''|*[!0-9]*) last=0 ;; esac
            if [ $(( $(date +%s) - last )) -gt 86400 ]; then
                mem_warn=$'\n\n'"💾 В памяти проекта есть несохранённое, а бэкапа не было больше суток. Скажи пользователю одной строкой: «скажи \"сохрани\" — уберу память проекта в сохранность» (скилл memory-backup)."
            fi
        fi
    fi
fi

# Версия плагина из manifest (fallback — просто без версии)
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
version=$(grep -m1 '"version"' "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
if [ -n "$version" ]; then
    header="Forge plugin (v${version}) активен."
else
    header="Forge plugin активен."
fi

# Напоминание про гайд по проекту (Фаза 5): одна строка и только когда есть что напомнить
# (render.py summary молчит, если открытых решений нет и гайд не устарел). Без PyYAML — JSON.
# Гайд есть, если лежит хоть одна версия .forge/guide/vX.Y.json (последняя = максимум по имени).
# Расхождения код/доки (drift-check.py) — раз в сутки на проект; отметка и число — вне репо,
# в ~/.claude/forge-state/<путь проекта>/drift-checked (строка 1 — дата, строка 2 — число)
drift_part=""
if [ -d .forge ]; then
    top=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    mark="$HOME/.claude/forge-state/${top//\//-}/drift-checked"
    today=$(date +%F)
    if [ "$(sed -n 1p "$mark" 2>/dev/null)" = "$today" ]; then
        drift_n=$(sed -n 2p "$mark")
    else
        drift_n=$(python3 "$plugin_root/skills/forge-context/drift-check.py" --count 2>/dev/null || true)
        mkdir -p "$(dirname "$mark")" 2>/dev/null && printf '%s\n%s\n' "$today" "$drift_n" > "$mark" 2>/dev/null || true
    fi
    if [ "${drift_n:-0}" -gt 0 ] 2>/dev/null; then
        case "$drift_n" in
            *1[1-4]) word="расхождений" ;;
            *1) word="расхождение" ;;
            *[2-4]) word="расхождения" ;;
            *) word="расхождений" ;;
        esac
        drift_part="доки: $drift_n $word"
    fi
fi

report_warn=""
if ls .forge/guide/v*.json >/dev/null 2>&1; then
    line=$(python3 "$plugin_root/skills/project-guide/render.py" summary 2>/dev/null || true)
    if [ -n "$line" ] && [ -n "$drift_part" ]; then
        line="$line · $drift_part (список — python3 $plugin_root/skills/forge-context/drift-check.py)"
    fi
    if [ -n "$line" ]; then
        report_warn=$'\n\n'"$line — напомни пользователю одной строкой; вопросы по решениям задавай по одному и только по его слову. Если владелец отвечает на решение из гайда (кодом или словами) — разбери, что он имел в виду, и примени по одному коду: \`python3 $plugin_root/skills/project-guide/render.py verdict <КОД> <accepted|changed|discuss|works|dropped|agreed|done|up|down|deferred> [текст]\`; принятое запиши в .forge/decisions.yml; рендерер сам перерисует guide-latest.html, новую версию не заводит"
    fi
elif [ -f ".forge/status-report.json" ]; then
    # Гайда ещё нет, но лежит старый отчёт «Что дальше» — по слову «собери гайд» он станет версией 1.0 гайда
    report_warn=$'\n\n'"📖 Найден старый отчёт «Что дальше» (.forge/status-report.json), гайда по проекту ещё нет — скажи владельцу одной строкой: «скажи «собери гайд» — перенесу находки в гайд по проекту»."
fi
if [ -z "$report_warn" ] && [ -n "$drift_part" ]; then
    report_warn=$'\n\n'"📌 Доки: ${drift_part#доки: } с кодом (список — python3 $plugin_root/skills/forge-context/drift-check.py) — скажи владельцу одной строкой; правь по иерархии правды (forge-context)."
fi

# Правила памяти — только если у проекта есть .forge; иначе один раз на проект предложить /forge:init
routing=""; doc_discipline=""; init_warn=""
if [ -d .forge ]; then
    routing="ROUTING: Match .forge/index.yml catalog[].tags with current task to decide which L1 files to load. Do NOT load all L1 files — only what matches.

"
    doc_discipline="DOC DISCIPLINE: If you just made a technical decision — record in .forge/decisions.yml. If an approach failed — record in .forge/dead-ends.yml. If you learned something non-obvious — record in .forge/learnings.yml. Do it NOW, not later.
"
elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    top=$(git rev-parse --show-toplevel)
    imark="$HOME/.claude/forge-state/${top//\//-}/init-offered"
    if [ ! -e "$imark" ]; then
        init_warn=$'\n\n'"🆕 У проекта нет памяти плагина (.forge/) — решения, задачи и журнал никуда не записываются. Предложи владельцу одной строкой: «завести память проекта? скажи «/forge:init» — буду помнить решения и ход работы между чатами». Один раз: отказался — не повторяй."
        mkdir -p "$(dirname "$imark")" 2>/dev/null && touch "$imark" 2>/dev/null || true
    fi
fi

# Старые копии подсказки плагина и старая защита main в .claude/settings*.json проекта —
# предложить починку не чаще раза в сутки (отметка вне репо); «нет» → decline, больше не предлагаем
hooks_warn=""
ptop=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
if ls "$ptop"/.claude/settings*.json >/dev/null 2>&1; then
    hmark="$HOME/.claude/forge-state/${ptop//\//-}/hooks-fix-shown"
    if [ "$(cat "$hmark" 2>/dev/null)" != "$(date +%F)" ]; then
        hfix="$plugin_root/skills/forge-context/project-hooks-fix.sh"
        found=$(bash "$hfix" check "$ptop" 2>/dev/null || true)
        # отметка — после любой проверки, не только при находке: иначе python3 запускается в каждом чате
        mkdir -p "$(dirname "$hmark")" 2>/dev/null && date +%F > "$hmark" 2>/dev/null || true
        if [ -n "$found" ]; then
            hooks_warn=$'\n\n'"🧹 Настройки проекта: ${found//$'\n'/; }. Скажи пользователю одной строкой простыми словами, что это и что ничего не сломается (резервная копия — вне проекта), и спроси «убрать?»: да → \`bash $hfix apply '$ptop'\`, нет → \`bash $hfix decline '$ptop'\` (больше не предложу). Без ответа напомню завтра."
        fi
    fi
fi

# Кто пользователь — личный файл ~/.claude/forge-user.yml (name, level: simple|technical, notes; без PyYAML).
# Файла нет — один раз за всё время (отметка в forge-state) просим Claude спросить; дальше нейтрально.
# Отметка ставится при выдаче просьбы, а не после ответа: сессия без диалога (claude -p без FORGE_NESTED)
# съест вопрос — осознанно, ради «спросить один раз»; человек всегда может попросить обращаться иначе.
ufile="$HOME/.claude/forge-user.yml"
# tr -d '\000-\037' — CR и любые управляющие символы: иначе escape_for_json отдаст невалидный JSON
ukey() { { sed -n "s/^$1:[[:space:]]*//p" "$ufile" | head -1 | tr -d '\000-\037' | sed "s/^[\"']//; s/[\"'][[:space:]]*\$//"; } 2>/dev/null || true; }
user_ask=""
if [ -f "$ufile" ]; then
    u_name=$(ukey name); u_level=$(ukey level); u_notes=$(ukey notes)
    # кириллица — целыми словами, не [Пп]: классы символов в локали C сравниваются по байтам и не срабатывают
    case "$u_level" in
        simple*|Simple*|SIMPLE*|прост*|Прост*|ПРОСТ*) u_level=simple ;;
        *) u_level=technical ;;
    esac
    user_line="USER: ${u_name:-пользователь} · уровень: ${u_level}${u_notes:+ · $u_notes}"
else
    user_line="USER: пользователь · уровень: не задан (нейтрально: без имени, термины можно, но каждый коротко поясняй; попросит обращаться иначе — запиши в ~/.claude/forge-user.yml)"
    umark="$HOME/.claude/forge-state/user-asked"
    if [ ! -e "$umark" ]; then
        user_ask=$'\n\n'"👤 Кто пользователь — не задано. В конце первого ответа задай один вопрос: «Как к вам обращаться и как объяснять — простыми словами или с терминами?» Ответил — запиши, подставив значения: имени не назвал — FORGE_NAME=''; «попроще / простыми словами» → simple, «с терминами / как программисту» → technical; одинарные кавычки из имени убери: \`FORGE_NAME='<имя>' FORGE_LEVEL=<simple|technical>; printf 'name: %s\nlevel: %s\n' \"\$FORGE_NAME\" \"\$FORGE_LEVEL\" > ~/.claude/forge-user.yml\`. Не ответил или ответ непонятен — ничего не пиши и больше не спрашивай."
        mkdir -p "$(dirname "$umark")" 2>/dev/null && touch "$umark" 2>/dev/null || true
    fi
fi

# Голос уведомлений (voice/notify.py) — одна строка, только если голос установлен (voice/install.sh)
voice_line=""
vhome="$HOME/.claude/forge-voice"
if [ -x "$vhome/venv/bin/python" ]; then
    vnotify="$plugin_root/voice/notify.py"
    vname=$(FORGE_VOICE_HOME="$vhome" CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}" perl -e 'alarm 3; exec @ARGV' python3 "$vnotify" name 2>/dev/null | tr -d '\000-\037' || true)
    if [ -f "$vhome/mute" ]; then
        vstate="выключен («включи голос» → \`python3 '$vnotify' unmute\`)"
    elif [ -f "$vhome/broken" ]; then
        vstate="сломался: $(head -1 "$vhome/broken" 2>/dev/null | tr -d '\000-\037') — скажи владельцу одной строкой; «почини голос» → разберись по ~/.claude/forge-voice/voiced.log, переустановка — \`bash '$plugin_root/voice/install.sh'\`"
    elif [ -f "$vhome/no-access" ]; then
        vstate="не видит окна (у VS Code нет «Универсального доступа») — говорит после каждого ответа; скажи владельцу одной строкой"
    else
        vstate="работает"
    fi
    voice_line=$'\n\n'"🔊 Голос: ${vstate}. Этот проект он зовёт «${vname:-проект}»: «называй этот проект Y» → \`python3 '$vnotify' name 'Y'\`; «выключи голос» / «включи голос» → \`python3 '$vnotify' mute\` / \`python3 '$vnotify' unmute\`; «тише» / «громче» / «громкость N» (про голос) → \`python3 '$vnotify' volume тише|громче|N\`."
fi

# Короткое введение — что есть forge и как им пользоваться
intro="<forge-plugin-loaded>
${user_line}
${header}

Доступен pipeline разработки:
  Phase 0   /forge:unblocker   — куда двигать проект
  Phase 1   /forge:new-task    — сырой запрос → чистая задача
  Phase 1.5 /forge:refine-idea — реалити-чек идеи
  Phase 2   /forge:plan        — план с чекпоинтами
  Phase 3   /forge:critique    — 4 персоны рвут план
  Phase 4   /forge:execute     — реализация
  Phase 5   /forge:guide       — гайд по проекту: суть, решения с кодами, риски, план

И 30+ поддерживающих скиллов (debugging, design, deployment, etc.) — триггерятся автоматически по описанию или вызываются явно через /forge:<name>.

${routing}WORKFLOWS: пишешь воркфлоу (Workflow tool, в т.ч. ультракод) — у КАЖДОГО agent() явные model и effort по $plugin_root/docs/model-roles.md (иначе помощник наследует модель чата); метки impl:/review:/verify:/final-review:/fix:; шаг с кодом проверяется по схеме skills/requesting-code-review (дифф в промпт, Sonnet-углы, Codex, Opus только для денег/прода/удаления), находки — пачкой, не скептик на каждую.

MODELS: любой вызов Agent — с явной model или типом из agents/ (поиск/перечисление — subagent_type forge:scout, проверка кода — forge:code-reviewer); встроенные Explore / Plan / general-purpose — только с model: \"haiku\" или \"sonnet\" (их inherit берёт Opus чата в обход страховки CLAUDE_CODE_SUBAGENT_MODEL). Помощник без модели — ошибка.

${doc_discipline}
Для глубокого введения — Skill tool: forge:using-forge.
$warning$mem_warn$report_warn$init_warn$hooks_warn$user_ask$voice_line
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
