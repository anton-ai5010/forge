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
if ! cmd=$(printf '%s' "$hook_input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null); then
    # Парсер упал (python3 отсутствует/сломан — на свежем macOS без CLT заглушка
    # /usr/bin/python3 существует, но падает при запуске). Fail-open осознанно:
    # fail-closed заблокировал бы ВЕСЬ Bash. Предупреждаем громко в stderr —
    # при exit 0 это уходит только в debug-логи хуков, но лучше, чем молчание.
    # permissionDecision:"allow" тут нельзя — он отключил бы штатные permission-промпты.
    echo "forge bash-safety: python3 недоступен — проверка опасных команд ОТКЛЮЧЕНА (fail-open)" >&2
    exit 0
fi

# Если команды нет (другой Bash параметр) — пропускаем
[ -z "$cmd" ] && exit 0

# ВАЖНО (честное ограничение): это last-line защита по регэкспам, а не гарантия.
# Обход через переменные (X=/; rm -rf "$X"), sh -c '...', eval, find / -delete
# паттернами не закрыть — от таких сценариев хук НЕ защищает.

# ============ ОПАСНЫЕ ПАТТЕРНЫ ============

# 1. rm -rf на корень / home / etc
# Проверяем только сегменты команды с вызовом rm (до ; & |), чтобы составные
# команды вида `rm -rf ./tmp && ls /` не давали ложных срабатываний.
rm_segs=$(printf '%s' "$cmd" | grep -oE '(^|[;&|[:space:]])rm[[:space:]]+[^;&|]*' || true)
if [ -n "$rm_segs" ] \
   && printf '%s' "$rm_segs" | grep -qE '(^|[[:space:]])(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]|$)' \
   && printf '%s' "$rm_segs" | grep -qE '(^|[[:space:]])(-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]]|$)' \
   && printf '%s' "$rm_segs" | grep -qE '(^|[[:space:]])["'\'']?(/\*?|~/?|\$HOME/?)["'\'']?([[:space:]]|$)'; then
    echo "BLOCKED: rm -rf на критический путь (/, ~, \$HOME). Если правда нужно — попроси пользователя сделать руками." >&2
    exit 2
fi

# 2. git push --force в main / master (флаг в любой позиции: -f, --force,
# --force-with-lease — последний тоже переписывает историю, для не-кодера блокируем).
# Как и у rm: проверяем только сегменты с git push (до ; & |), чтобы
# `git rebase main && git push -f origin feature` не давал ложного срабатывания.
push_segs=$(printf '%s' "$cmd" | grep -oE '(^|[;&|[:space:]])git[[:space:]]+push[[:space:]][^;&|]*' || true)
if [ -n "$push_segs" ] \
   && printf '%s' "$push_segs" | grep -qE '(^|[[:space:]])(-[a-zA-Z]*f[a-zA-Z]*|--force(-with-lease(=[^[:space:]]*)?)?)([[:space:]]|$)' \
   && printf '%s' "$push_segs" | grep -qE '(^|[[:space:]:/])(main|master)([[:space:]]|$)'; then
    echo "BLOCKED: git push --force в main/master. Это перепишет историю на удалёнке. Спроси пользователя явно." >&2
    exit 2
fi

# 3. git reset --hard без указания цели или к старому коммиту
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard[[:space:]]+(HEAD~[0-9]+|[a-f0-9]{7,40})'; then
    echo "BLOCKED: git reset --hard к старому коммиту удалит работу. Если правда нужно — пользователь сделает сам." >&2
    exit 2
fi

# 4. dd на блочное устройство — затирание диска (Linux: sd/nvme/hd, macOS: disk/rdisk)
if printf '%s' "$cmd" | grep -qE '\bdd[[:space:]].*of=/dev/(r?disk[0-9]|sd[a-z]|nvme[0-9]|hd[a-z])'; then
    echo "BLOCKED: dd на блочное устройство (disk/rdisk/sd/nvme/hd) — затирание диска. Не запускай." >&2
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
