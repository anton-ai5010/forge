#!/usr/bin/env bash
# Тесты для skills/session-awareness/decision-codes.py — коды DEC-NN в decisions.yml.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/../../skills/session-awareness" && pwd)/decision-codes.py"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fails=0
check() { if [ "$2" = "0" ]; then echo "PASS: $1"; else echo "FAIL: $1"; fails=$((fails + 1)); fi; }

F="$TMP/d.yml"
cat > "$F" <<'Y'
# Шапка файла
# Формат: id, date

entries:
  # комментарий перед записью
  - id: first
    date: "2026-01-01"
    decision: "A"

  - id: second
    why: "B"
    date: "2026-01-02"
  - id: third
    decision: "C"
    tags: [a, b]
Y
cp "$F" "$TMP/orig.yml"

# (а) три записи без кода
python3 "$SCRIPT" "$F" >/dev/null 2>&1
[ "$(grep -c '^    code: DEC-0[123]$' "$F")" = 3 ] \
  && [ "$(grep -A1 'id: first' "$F" | tail -1)" = "    code: DEC-01" ] \
  && [ "$(grep -A1 'id: third' "$F" | tail -1)" = "    code: DEC-03" ]
check "а: записям присвоены DEC-01..03 сразу после id" $?

# (г) всё остальное байт-в-байт
diff <(grep -v '^    code: DEC-' "$F") "$TMP/orig.yml" >/dev/null
check "г: комментарии, пустые строки, порядок ключей сохранены" $?

# (б) идемпотентность
cp "$F" "$TMP/once.yml"
python3 "$SCRIPT" "$F" >/dev/null 2>&1
cmp -s "$F" "$TMP/once.yml"
check "б: повторный запуск не меняет файл" $?

# (в) следующий после максимального
G="$TMP/g.yml"
cat > "$G" <<'Y'
entries:
  - id: old
    code: DEC-07
    decision: "x"
  - id: new
    decision: "y"
Y
python3 "$SCRIPT" "$G" >/dev/null 2>&1
[ "$(grep -A1 'id: new' "$G" | tail -1)" = "    code: DEC-08" ] && [ "$(grep -c 'DEC-07' "$G")" = 1 ]
check "в: после DEC-07 новая получает DEC-08" $?

[ "$fails" -eq 0 ] || exit 1
