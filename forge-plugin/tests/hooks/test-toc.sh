#!/usr/bin/env bash
# Тесты skills/forge-context/toc.py — оглавление памяти, --get, --journal.
set -uo pipefail

TOC="$(cd "$(dirname "$0")/../../skills/forge-context" && pwd)/toc.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0
ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fails=$((fails + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (ждали [$3], получили [$2])"; fi; }

# --- фикстура decisions: code, id, многострочное значение, запись без id ---
cat > "$T/decisions.yml" <<'Y'
# шапка
entries:
  - id: alpha
    code: DEC-01
    date: "2026-09-06"
    decision: "Первое решение про альфу"
    why: "потому что"
  - id: beta
    date: 2026-09-07
    decision: >
      Многострочное решение
      продолжение
    why: |
      строка 1
      строка 2
  - date: 2026-09-08
    what: "Запись без кода и id"
Y
out="$(python3 "$TOC" "$T/decisions.yml")"
check "строка на запись" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" 3
check "формат с кодом" "$(printf '%s\n' "$out" | sed -n 1p)" "DEC-01 · 2026-09-06 · Первое решение про альфу"
check "id и многострочное" "$(printf '%s\n' "$out" | sed -n 2p)" "beta · 2026-09-07 · Многострочное решение"
printf '%s\n' "$out" | sed -n 3p | grep -q "^#3 · 2026-09-08 · Запись без кода и id" && ok "запись без id" || bad "запись без id"

python3 "$TOC" "$T/decisions.yml" --get DEC-01 > "$T/got.txt"
sed -n '4,8p' "$T/decisions.yml" | head -5 >/dev/null
printf '  - id: alpha\n    code: DEC-01\n    date: "2026-09-06"\n    decision: "Первое решение про альфу"\n    why: "потому что"\n' > "$T/exp.txt"
cmp -s "$T/got.txt" "$T/exp.txt" && ok "--get по коду дословно" || bad "--get по коду дословно"
python3 "$TOC" "$T/decisions.yml" --get beta | grep -q "строка 2" && ok "--get по id, многострочная" || bad "--get по id"

python3 "$TOC" "$T/decisions.yml" --get '#3' | grep -q "Запись без кода" && ok "--get #N" || bad "--get #N"

# --- большой реальный файл ---
REAL="/Users/mac/Projects/Ya. Market/integration/.forge/decisions.yml"
if [ -f "$REAL" ]; then
  cp "$REAL" "$T/big.yml"
  size=$(wc -m < "$T/big.yml" | tr -d ' '); tsz=$(python3 "$TOC" "$T/big.yml" | wc -m | tr -d ' ')
  [ $((tsz * 100)) -le $((size * 15)) ] && ok "оглавление ≤15% ($tsz из $size)" || bad "оглавление ≤15% ($tsz из $size)"
fi

# --- журнал ---
mkdir -p "$T/p/.forge"; F="$T/p/.forge"
python3 "$TOC" --journal "$F" >/dev/null; check "пусто — exit 0" "$?" 0
check "пусто — вывод пуст" "$(python3 "$TOC" --journal "$F")" ""
cat > "$F/journal.yml" <<'Y'
entries:
  - date: "2026-10-01"
    summary: "old-1"
  - date: "2026-10-05"
    summary: "old-2"
Y
check "только journal.yml, новые первыми" "$(python3 "$TOC" --journal "$F" | grep -o 'old-[0-9]' | tr '\n' ' ')" "old-2 old-1 "
mkdir "$F/journal.d"
printf 'date: "2026-10-05"\nsummary: "frag-a"\n' > "$F/journal.d/2026-10-05-0900-a.yml"
printf 'entries:\n  - date: "2026-10-05"\n    summary: "frag-b"\n' > "$F/journal.d/2026-10-05-1000-b.yml"
printf 'date: "2026-10-09"\nsummary: "frag-c"\n' > "$F/journal.d/2026-10-09-1200-c.yml"
check "смесь: порядок" "$(python3 "$TOC" --journal "$F" | grep -o '\(old\|frag\)-[0-9a-c]' | tr '\n' ' ')" "frag-c frag-b frag-a old-2 old-1 "
check "N=2" "$(python3 "$TOC" --journal "$F" 2 | grep -o '\(old\|frag\)-[0-9a-c]' | tr '\n' ' ')" "frag-c frag-b "
rm "$F/journal.yml"
check "только journal.d" "$(python3 "$TOC" --journal "$F" | grep -c 'frag-')" 3

[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
