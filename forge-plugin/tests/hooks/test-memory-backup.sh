#!/usr/bin/env bash
# Тесты для skills/memory-backup/backup.sh — сохранение памяти проекта (.forge/)
# в git и на удалёнку. Прогоняется в изолированных tmp-репозиториях.
#
# ⚠️ Изоляция обязательна: cd в $(command substitution) НЕ переживает подстановку
# (урок git-tests-must-isolate-cwd) — поэтому new_repo это обычная функция,
# а guard_isolated прерывает сьют, если тест оказался в реальном репозитории.

set -uo pipefail

BACKUP="$(cd "$(dirname "$0")/../../skills/memory-backup" && pwd)/backup.sh"
PLUGIN_REPO="$(cd "$(dirname "$0")/../../.." && git rev-parse --show-toplevel 2>/dev/null || true)"
fails=0

guard_isolated() {
    local top
    top=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$PLUGIN_REPO" ] && [ "$top" = "$PLUGIN_REPO" ]; then
        echo "ABORT: тест оказался в реальном репозитории плагина ($top) — изоляция сломана" >&2
        exit 1
    fi
}

check() {
    local desc="$1" ok="$2"
    if [ "$ok" -eq 0 ]; then
        echo "PASS: $desc"
    else
        echo "FAIL: $desc"
        fails=$((fails + 1))
    fi
}

# Обычная функция (НЕ через $()): cd должен пережить вызов
REPO=""
new_repo() {
    REPO=$(mktemp -d)
    cd "$REPO" || exit 1
    git init -q
    git config user.email "test@test"
    git config user.name "test"
    echo "# proj" > README.md
    git add README.md && git commit -qm init
    mkdir -p .forge
    echo 'goal: "тест"' > .forge/index.yml
    guard_isolated
}

run_backup() {
    guard_isolated
    bash "$BACKUP" "$@" 2>&1
}

# --- (1) коммитит только .forge, чужие правки не трогает ---

new_repo
echo "правка кода" >> README.md            # грязный файл ВНЕ .forge
out=$(run_backup "первый бэкап")
last_msg=$(git log -1 --format=%s)
files=$(git show --name-only --format= HEAD)
[ "$last_msg" = "[forge] память: первый бэкап" ] \
  && printf '%s' "$files" | grep -q ".forge/index.yml" \
  && ! printf '%s' "$files" | grep -q "README.md" \
  && [ -n "$(git status --porcelain README.md)" ]
check "should commit only .forge paths and leave other dirty files alone" $?

# --- (2) нечего коммитить → нового коммита нет, exit 0 ---

before=$(git rev-list --count HEAD)
run_backup >/dev/null
rc=$?
after=$(git rev-list --count HEAD)
[ "$rc" -eq 0 ] && [ "$before" -eq "$after" ]
check "should exit 0 without new commit when .forge is clean" $?

# --- (3) служебный мусор не коммитится (.forge/.gitignore создаётся сам) ---

echo "x" > .forge/.inject-state
echo "phase: idle" > .forge/state.yml
echo "123" > .forge/.github-issue-test
echo 'note: "новое"' >> .forge/index.yml
run_backup >/dev/null
files=$(git show --name-only --format= HEAD)
printf '%s' "$files" | grep -q "index.yml" \
  && ! printf '%s' "$files" | grep -qE "inject-state|state.yml|github-issue" \
  && [ -f .forge/.gitignore ]
check "should auto-create .forge/.gitignore and never commit runtime junk" $?
cd / && rm -rf "$REPO"

# --- (4) нет удалёнки → сохраняет локально + просит предложить приватный репо ---

new_repo
out=$(run_backup)
printf '%s' "$out" | grep -q "удалёнки нет" && printf '%s' "$out" | grep -qi "приватн"
check "should save locally and hint about private repo when no remote" $?
cd / && rm -rf "$REPO"

# --- (5) с удалёнкой → пушит текущую ветку, ставит upstream ---

new_repo
bare=$(mktemp -d)
git init -q --bare "$bare"
git remote add origin "$bare"
echo 'note: "для пуша"' >> .forge/index.yml
out=$(run_backup "пуш-тест")
remote_msg=$(git --git-dir="$bare" log -1 --format=%s 2>/dev/null)
[ "$remote_msg" = "[forge] память: пуш-тест" ] && printf '%s' "$out" | grep -q "сохранена"
check "should push current branch to origin when remote exists" $?

# --- (6) пишет .forge/.last-backup и не коммитит его ---

[ -f .forge/.last-backup ] && ! git ls-files --error-unmatch .forge/.last-backup >/dev/null 2>&1
check "should write .forge/.last-backup timestamp and keep it untracked" $?
cd / && rm -rf "$REPO" "$bare"

# --- (7) .forge под игнором (легаси-проект) → не форсит, подсказывает миграцию ---

new_repo
echo ".forge" > .gitignore && git add .gitignore && git commit -qm gitignore
echo 'note: "легаси"' >> .forge/index.yml
before=$(git rev-list --count HEAD)
out=$(run_backup)
after=$(git rev-list --count HEAD)
[ "$before" -eq "$after" ] && printf '%s' "$out" | grep -qi "миграц"
check "should not force-add ignored .forge and should hint migration (legacy project)" $?
cd / && rm -rf "$REPO"

# --- (8) не git-репозиторий → тихий exit 0 ---

nodir=$(mktemp -d)
cd "$nodir" || exit 1
mkdir -p .forge && echo 'x: 1' > .forge/index.yml
out=$(bash "$BACKUP" 2>&1)
rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ]
check "should exit 0 silently when not a git repository" $?
cd / && rm -rf "$nodir"

echo "---"
if [ "$fails" -gt 0 ]; then
    echo "$fails test(s) FAILED"
    exit 1
fi
echo "All tests passed"
exit 0
