#!/bin/bash
# shots-page.py: страничка снимков прохода «прокликай»
# Usage: bash tests/hooks/test-walkthrough-page.sh
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; S="$ROOT/skills/browser-walkthrough/shots-page.py"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT; fails=0
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
check() { if eval "$2"; then echo "✓ $1"; else echo "✗ $1"; fails=$((fails+1)); fi; }
python3 -c "import base64;d=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');[open(f'$T/{n}','wb').write(d) for n in ('1.png','2.jpg')]"
python3 "$S" "$T/logs/out.html" "Форма заказа — всё работает <i>" --url=http://127.0.0.1:5173/order --record="заказ тест-1540" --record="<i>&" "$T/1.png::Открыл <b>форму</b>" "$T/2.jpg::!починил: Нажал «Отправить»" >/dev/null
check "собрал страничку" "[ -s '$T/logs/out.html' ]"
check "две картинки внутри файла" "[ \$(grep -oE 'src=\"data:image/(png|jpeg);base64,' '$T/logs/out.html' | wc -l) -eq 2 ]"
check "jpg — с типом jpeg" "grep -q 'data:image/jpeg;base64,' '$T/logs/out.html'"
check "подписи экранированы" "grep -q 'Открыл &lt;b&gt;форму&lt;/b&gt;' '$T/logs/out.html'"
check "метка «починил» на втором снимке" "grep -q 'было сломано → починил</span><br>2. Нажал' '$T/logs/out.html'"
check "тестовые записи в блоке" "grep -q '<li>заказ тест-1540</li>' '$T/logs/out.html'"
check "заголовок на месте, экранирован" "grep -q 'Форма заказа — всё работает &lt;i&gt;' '$T/logs/out.html'"
check "запись экранирована" "grep -q '<li>&lt;i&gt;&amp;</li>' '$T/logs/out.html'"
check "адрес в шапке" "grep -q '· http://127.0.0.1:5173/order' '$T/logs/out.html'"
check "файл только владельцу (600)" "[ \$(mode '$T/logs/out.html') = 600 ]"
check "папка только владельцу (700)" "[ \$(mode '$T/logs') = 700 ]"
mkdir -m 755 "$T/old"; touch "$T/old/o.html"; chmod 644 "$T/old/o.html"
python3 "$S" "$T/old/o.html" t "$T/1.png::x" >/dev/null
check "существующая папка — права не трогает" "[ \$(mode '$T/old') = 755 ]"
check "перезаписанный файл — снова 600" "[ \$(mode '$T/old/o.html') = 600 ]"
err=$(python3 "$S" "$T/small.html" t "$T/1.png::x" 2>&1 >/dev/null)
check "маленькая страничка — без предупреждений" "[ -z \"\$err\" ]"
head -c 4000000 /dev/urandom > "$T/big.png"
err=$(python3 "$S" "$T/big.html" t "$T/big.png::x" 2>&1 >/dev/null)
check "больше 3 МБ — предупреждение" "[[ \"\$err\" == *'на телефоне может не открыться'* ]]"
err=$(python3 "$S" "$T/bad.html" "x" "$T/1.png::есть" "$T/нет.png::y" 2>&1 >/dev/null); rc=$?
check "нет снимка → код 1, сказал, файла нет" "[ $rc -eq 1 ] && [[ \"\$err\" == *'нет снимка'*'страничка не создана'* ]] && [ ! -e '$T/bad.html' ]"
err=$(python3 "$S" 2>&1); rc=$?
check "без аргументов → код 2 и подсказка" "[ $rc -eq 2 ] && [[ \"\$err\" == *'Usage: shots-page.py'* ]]"
err=$(python3 "$S" "$T/r.html" t --record=a 2>&1); rc=$?
check "только записи, без снимков → код 2" "[ $rc -eq 2 ] && [[ \"\$err\" == *'нет ни одного снимка'* ]] && [ ! -e '$T/r.html' ]"
echo; [ $fails -eq 0 ] && echo OK || { echo "$fails FAIL"; exit 1; }
