#!/usr/bin/env bash
# Тесты для skills/forge-context/drift-check.py — расхождения код/доки.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/../../skills/forge-context" && pwd)/drift-check.py"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fails=0
check() { if [ "$2" = "0" ]; then echo "PASS: $1"; else echo "FAIL: $1"; fails=$((fails + 1)); fi; }

P="$TMP/proj"
mkdir -p "$P/.forge" "$P/src"
echo "x" > "$P/src/app.py"
cat > "$P/.forge/map.yml" <<'Y'
directories:
  src/:
    about: "код"
  lib/:
    about: "мёртвая папка"
files:
  - "src/app.py"
  - "https://example.com/a/b.html"
  - "docs/<name>/x.md"
  - "src/*.py"
Y
cat > "$P/.forge/conventions.yml" <<'Y'
naming: "kebab-case"
Y
printf '# Проект\n\nКод в `src/app.py`.\n' > "$P/CLAUDE.md"
printf 'working:\n  - "ok"\nbroken: []\n' > "$P/.forge/status.yml"
(cd "$P" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init)

# (а) один мёртвый путь -> ровно одно предупреждение
OUT="$(cd "$P" && python3 "$SCRIPT" 2>&1)"
[ "$(cd "$P" && python3 "$SCRIPT" --count)" = "1" ] && echo "$OUT" | grep -q 'lib/' && echo "$OUT" | grep -q 'расхождений: 1'
check "а: один мёртвый путь (lib/) -> 1 предупреждение" $?

# (б) все пути живые -> 0
mkdir -p "$P/lib"
[ "$(cd "$P" && python3 "$SCRIPT" --count)" = "0" ] && (cd "$P" && python3 "$SCRIPT") | grep -q 'расхождений: 0'
check "б: все пути живые -> 0" $?

# (в) --write
rmdir "$P/lib"
cp "$P/.forge/status.yml" "$TMP/status.orig"
(cd "$P" && python3 "$SCRIPT" --write >/dev/null 2>&1)
S="$P/.forge/status.yml"
[ "$(grep -c '^  - what: ' "$S")" = 1 ] && grep -q '^drift:' "$S" && grep -q '^    found: ' "$S" && grep -q '^    truth: ' "$S"
check "в: --write дописал drift: с what/found/truth" $?
diff <(grep -v -e '^drift:' -e '^  - what: ' -e '^    found: ' -e '^    truth: ' "$S") "$TMP/status.orig" >/dev/null
check "в: остальной файл байт-в-байт" $?
(cd "$P" && python3 "$SCRIPT" --write >/dev/null 2>&1)
[ "$(grep -c '^  - what: ' "$S")" = 1 ] && [ "$(grep -c '^drift:' "$S")" = 1 ]
check "в: повторный --write без дублей" $?
mkdir -p "$P/lib"
(cd "$P" && python3 "$SCRIPT" --write >/dev/null 2>&1)
[ "$(grep -c '^  - what: ' "$S")" = 0 ]
check "в: закрытое (путь появился) удалено" $?

# (г) доки без правки N дней
(cd "$P" && git add -A && GIT_AUTHOR_DATE="2026-01-01T00:00:00" GIT_COMMITTER_DATE="2026-01-01T00:00:00" git -c user.name=t -c user.email=t@t commit -qm docs --allow-empty)
echo "y" > "$P/src/new.py"
(cd "$P" && git add -A && GIT_AUTHOR_DATE="2026-03-01T00:00:00" GIT_COMMITTER_DATE="2026-03-01T00:00:00" git -c user.name=t -c user.email=t@t commit -qm code)
(cd "$P" && python3 "$SCRIPT" --days 30) | grep -q 'без правки'
check "г: доки старше кода на >30 дней -> предупреждение" $?
[ "$(cd "$P" && python3 "$SCRIPT" --days 90 --count)" = "0" ]
check "г: порог 90 дней -> тишина" $?

echo; [ $fails -eq 0 ] && echo OK || echo "$fails FAIL"
exit $fails
