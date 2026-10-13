#!/usr/bin/env bash
# Тесты для hooks/statusline.sh: процент чата и процент недельного лимита
# берутся каждый из своего поля JSON, а не первое попавшееся used_percentage.

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SL="$PLUGIN_ROOT/hooks/statusline.sh"
fails=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fails=$((fails+1)); fi; }
run() { (cd "$(mktemp -d)" && printf '%s' "$1" | bash "$SL"); }

both='{"model":{"display_name":"Opus"},"rate_limits":{"five_hour":{"used_percentage":12.5},"seven_day":{"used_percentage":31.2}},"context_window":{"used_percentage":64.9}}'
out=$(run "$both")
echo "$out" | grep -q "чат 64%" ; check "чат — из context_window, а не из rate_limits ($out)" $?
echo "$out" | grep -q "неделя 31%" ; check "неделя — из rate_limits.seven_day ($out)" $?

out=$(run '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":40}}')
echo "$out" | grep -q "чат 40%" ; check "без rate_limits — только чат ($out)" $?
echo "$out" | grep -q "неделя" ; check "без rate_limits — недели нет ($out)" $((1-$?))

out=$(run '{"rate_limits":{"seven_day":{"used_percentage":55}}}')
echo "$out" | grep -q "неделя 55%" && ! echo "$out" | grep -q "чат" ; check "нет модели и чата — неделя не съезжает в чат ($out)" $?

out=$(run 'не json')
[ -n "$out" ] ; check "мусор на входе — строка всё равно печатается, без падения" $?

echo; [ $fails -eq 0 ] && echo OK || echo "$fails FAIL"
exit $fails
