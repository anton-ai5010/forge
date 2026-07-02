#!/usr/bin/env bash
# PreToolUse hook — блокирует опасные bash-команды до выполнения
# Срабатывает только когда Claude собирается запустить Bash tool.
# Возврат:
#   exit 0       — разрешить (вывод на stdout идёт в Claude как доп. контекст)
#   exit 2       — заблокировать (вывод на stderr показывается Claude как причина)

set -euo pipefail

# Парсим JSON от Claude Code (tool input в поле .tool_input.command)
# python3 вместо sed: sed-регэксп обрывался на первой экранированной кавычке,
# и любая команда с кавычкой обходила все паттерны.
hook_input=$(cat)
cmd=$(printf '%s' "$hook_input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || true)

# Если команды нет (другой Bash параметр) — пропускаем
[ -z "$cmd" ] && exit 0

# ============ ОПАСНЫЕ ПАТТЕРНЫ ============

# 1. rm -rf на корень / home / etc
if printf '%s' "$cmd" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-rf|-fr)[[:space:]]+(/[[:space:]]*$|/[[:space:]]+|~[[:space:]]*$|~/[[:space:]]*$|~/[[:space:]]+|\$HOME)'; then
    echo "BLOCKED: rm -rf на критический путь (/, ~, \$HOME). Если правда нужно — попроси пользователя сделать руками." >&2
    exit 2
fi

# 2. git push --force в main / master
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push[[:space:]].*(--force|--force-with-lease|-f[[:space:]])[[:space:]].*(main|master|origin[[:space:]]+main|origin[[:space:]]+master|HEAD:main|HEAD:master)'; then
    echo "BLOCKED: git push --force в main/master. Это перепишет историю на удалёнке. Спроси пользователя явно." >&2
    exit 2
fi

# 3. git reset --hard без указания цели или к старому коммиту
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard[[:space:]]+(HEAD~[0-9]+|[a-f0-9]{7,40})'; then
    echo "BLOCKED: git reset --hard к старому коммиту удалит работу. Если правда нужно — пользователь сделает сам." >&2
    exit 2
fi

# 4. dd to /dev/sda* — затирание диска
if printf '%s' "$cmd" | grep -qE '\bdd[[:space:]].*of=/dev/(sd[a-z]|nvme[0-9]|hd[a-z])'; then
    echo "BLOCKED: dd на блочное устройство (sd/nvme/hd) — затирание диска. Не запускай." >&2
    exit 2
fi

# 5. chmod 777 на /, /etc, /home
if printf '%s' "$cmd" | grep -qE 'chmod[[:space:]]+(-R[[:space:]]+)?777[[:space:]]+(/|/etc|/home|/root|/usr)([[:space:]]|$)'; then
    echo "BLOCKED: chmod 777 на системные каталоги. Дай конкретный путь, не корни." >&2
    exit 2
fi

# 6. Удаление .env / секретов
if printf '%s' "$cmd" | grep -qE 'rm[[:space:]].*(\.env|\.env\.|credentials|secrets|\.pem|\.key)([[:space:]]|$)'; then
    echo "BLOCKED: попытка удалить .env / credentials / .pem / .key. Спроси пользователя явно." >&2
    exit 2
fi

# 7. curl | bash / wget | sh — выполнение скрипта из интернета
if printf '%s' "$cmd" | grep -qE '(curl|wget)[[:space:]].*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh|zsh)([[:space:]]|$)'; then
    echo "BLOCKED: запуск скрипта из интернета через pipe. Скачай файл отдельно, дай пользователю проверить." >&2
    exit 2
fi

# Всё OK — пропускаем
exit 0
