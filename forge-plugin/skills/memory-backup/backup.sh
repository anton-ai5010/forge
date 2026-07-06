#!/usr/bin/env bash
# Сохранение памяти проекта: коммитит .forge/ (задачи, планы, решения, журнал)
# и пушит текущую ветку на удалёнку. Вызывается скиллом memory-backup,
# session-awareness (итог сессии) и finishing (после мержа).
#
# $1 — короткое описание для сообщения коммита (опционально).
# Вывод — строки FORGE-MEMORY для Claude (не для пользователя напрямую).
# Всегда exit 0: сохранение памяти не должно ронять основной процесс.

set -euo pipefail

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -d .forge ] || exit 0

# Легаси-проект: вся .forge под игнором. НЕ форсим add — миграцию делает
# Claude по процедуре из SKILL.md, с согласия пользователя.
if git check-ignore -q .forge 2>/dev/null; then
    echo "FORGE-MEMORY: .forge/ игнорируется git-ом (старый проект) — память не защищена. Нужна миграция (см. SKILL.md memory-backup): убрать '.forge' из .gitignore и запустить сохранение снова."
    exit 0
fi

# Служебный мусор в git не попадает: гарантируем .forge/.gitignore
if [ ! -f .forge/.gitignore ]; then
    cat > .forge/.gitignore <<'EOF'
.inject-state
.last-backup
state.yml
.github-*
graph.json
EOF
fi

git add .forge >/dev/null 2>&1 || true
if ! git diff --cached --quiet -- .forge 2>/dev/null; then
    msg="${1:-обновление памяти проекта}"
    git commit -q -m "[forge] память: ${msg}" -- .forge >/dev/null 2>&1 || \
        echo "FORGE-MEMORY: коммит памяти не прошёл (git config user.name/email?) — сообщи пользователю одной строкой."
fi

branch=$(git branch --show-current 2>/dev/null || true)
if [ -n "$branch" ] && git remote get-url origin >/dev/null 2>&1; then
    if git push -q -u origin "$branch" >/dev/null 2>&1; then
        echo "FORGE-MEMORY: память сохранена на GitHub (ветка ${branch})."
    else
        echo "FORGE-MEMORY: память закоммичена локально, но push не прошёл (сеть/права). Сообщи пользователю одной строкой, не блокируй работу."
    fi
else
    echo "FORGE-MEMORY: удалёнки нет — память сохранена только локально. Предложи пользователю создать ПРИВАТНЫЙ репозиторий (gh repo create <имя> --private --source=. --push) — создавать только после его явного «да»."
fi

date +%s > .forge/.last-backup 2>/dev/null || true
exit 0
