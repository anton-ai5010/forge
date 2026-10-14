#!/usr/bin/env bash
# Тесты для hooks/context-inject.sh — умная инжекция L0-контекста.
# Полный блок — при новой сессии / изменении контента / каждом 16-м промпте,
# иначе короткая строка-маркер. Прогоняет хук в изолированной tmp-директории.

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/../../hooks" && pwd)/context-inject.sh"
fails=0
workdir=$(mktemp -d)
cd "$workdir"

mkdir -p .forge
cat > .forge/index.yml <<'EOF'
goal: "тестовый проект — проверка инжекции"
stage: build
task: "проверить дедупликацию контекста"
EOF

run_hook() {
    printf '%s' "$1" | "$HOOK" 2>/dev/null
}

is_full() {
    printf '%s' "$1" | grep -q "FORGE L0 CONTEXT"
}

is_short() {
    printf '%s' "$1" | grep -q "без изменений" && ! is_full "$1"
}

is_json() {
    printf '%s' "$1" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null
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

PAYLOAD='{"session_id":"sess-1","prompt":"привет"}'

# --- (1) первый вызов — полная инжекция ---

out=$(run_hook "$PAYLOAD")
is_full "$out"; check "should inject full context when first call in session" $?

# --- (2) повторный вызов с тем же вводом — короткая строка ---

out=$(run_hook "$PAYLOAD")
is_short "$out"; check "should inject short marker when nothing changed" $?

# --- (3) изменение index.yml → снова полная ---

echo 'note: "контент поменялся"' >> .forge/index.yml
out=$(run_hook "$PAYLOAD")
is_full "$out"; check "should inject full context when index.yml changed" $?

# --- (4) новый session_id → полная ---

run_hook "$PAYLOAD" >/dev/null  # закрепляем короткое состояние для sess-1
out=$(run_hook '{"session_id":"sess-2","prompt":"привет"}')
is_full "$out"; check "should inject full context when session_id is new" $?

# --- (5) страховка: 15 коротких повторов → полная на 16-м ---

rm -f .forge/.inject-state
run_hook "$PAYLOAD" >/dev/null  # полная, счётчик = 0
all_short=0
for i in $(seq 1 15); do
    out=$(run_hook "$PAYLOAD")
    is_short "$out" || all_short=1
done
check "should keep short markers for 15 repeats after full injection" $all_short
out=$(run_hook "$PAYLOAD")
is_full "$out"; check "should re-inject full context on 16th repeat (safety after /compact)" $?

# --- (6) отсутствие .forge/ → exit 0 без вывода ---

nodir=$(mktemp -d)
out=$(cd "$nodir" && printf '%s' "$PAYLOAD" | "$HOOK" 2>/dev/null)
rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ]; check "should exit 0 silently when .forge/ is missing" $?
rm -rf "$nodir"

# --- (7) вывод всегда валидный JSON (и полный, и короткий) ---

rm -f .forge/.inject-state
out=$(run_hook "$PAYLOAD")
is_json "$out"; check "should emit valid JSON when injection is full" $?
out=$(run_hook "$PAYLOAD")
is_json "$out"; check "should emit valid JSON when injection is short" $?

# --- (8) нет session_id во вводе → fallback (PPID+день), дедуп работает ---
# Без command substitution: $() форкает subshell и PPID хука меняется между
# вызовами. В пайплайне напрямую PPID = PID этого скрипта — стабилен, как
# у реального Claude Code (родитель хука — процесс Claude Code).

rm -f .forge/.inject-state
printf '%s' '{"prompt":"без session_id"}' | "$HOOK" > out1.json 2>/dev/null
printf '%s' '{"prompt":"без session_id"}' | "$HOOK" > out2.json 2>/dev/null
out=$(cat out2.json)
is_short "$out"; check "should dedupe via PPID+day fallback when session_id is absent" $?
rm -f out1.json out2.json

# --- (9а) обрезка большого кириллического index.yml не рвёт букву пополам ---

rm -f .forge/.inject-state
mv .forge/index.yml .forge/index.yml.bak
python3 -c "open('.forge/index.yml','w').write('goal: \"' + 'я'*1500 + '\"\n')"  # ~3 КБ кириллицы
out=$(run_hook "$PAYLOAD")
printf '%s' "$out" | python3 -c "
import json,sys
raw = sys.stdin.buffer.read()
raw.decode('utf-8')  # strict: упадёт, если буква разрезана по байтам
ctx = json.loads(raw)['hookSpecificOutput']['additionalContext']
assert '�' not in ctx, 'битый UTF-8 (U+FFFD) в обрезанном контексте'
assert 'truncated' in ctx, 'нет пометки об обрезке'
" 2>/dev/null
check "should truncate large Cyrillic index.yml at char boundary (no broken UTF-8)" $?
mv .forge/index.yml.bak .forge/index.yml

# --- (9б) секция dont:/constraints: в конце длинного index.yml доходит целиком ---

for key in dont constraints; do
    rm -f .forge/.inject-state
    mv .forge/index.yml .forge/index.yml.bak
    python3 - "$key" <<'PY'
import sys
key = sys.argv[1]
body = 'goal: "x"\nnotes:\n' + ''.join('  - заметка номер %d, длинная строка для объёма\n' % i for i in range(150))
body += key + ':\n' + ''.join('  - НИКОГДА-правило-%d\n' % i for i in range(1, 6))
open('.forge/index.yml', 'w').write(body)
PY
    out=$(run_hook "$PAYLOAD")
    printf '%s' "$out" | python3 -c "
import json,sys
ctx = json.load(sys.stdin)['hookSpecificOutput']['additionalContext']
for i in range(1, 6):
    assert 'НИКОГДА-правило-%d' % i in ctx, i
" 2>/dev/null
    check "should deliver all 5 lines of '$key:' section at the end of a ~6KB index.yml" $?
    mv .forge/index.yml.bak .forge/index.yml
done

# --- (9в) без секции dont/constraints старое поведение (обрезка) сохраняется ---

rm -f .forge/.inject-state
mv .forge/index.yml .forge/index.yml.bak
python3 -c "open('.forge/index.yml','w').write('goal: \"x\"\n' + 'note: \"' + 'a'*4000 + '\"\n')"
out=$(run_hook "$PAYLOAD")
printf '%s' "$out" | grep -q "truncated" && is_json "$out"; check "should truncate as before when no dont/constraints section" $?
mv .forge/index.yml.bak .forge/index.yml

# --- (9) битый JSON на входе не роняет хук ---

rm -f .forge/.inject-state
out=$(run_hook 'не json вообще')
rc=$?
[ "$rc" -eq 0 ] && is_json "$out"; check "should survive malformed stdin and still emit valid JSON" $?

# --- (10) гигиена чата: размер контекста из transcript_path ---

REAL_HOME="$HOME"
export HOME=$(mktemp -d)
mkdir -p "$HOME/.claude/forge-state"
TD=$(mktemp -d)

mk_tr() { # файл, input_tokens, cache_read, cache_creation
    python3 - "$1" "$2" "$3" "$4" <<'PY'
import json,sys
f,i,r,c=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4])
with open(f,'w') as o:
    o.write(json.dumps({"type":"user","message":{"content":"привет"}})+"\n")
    o.write(json.dumps({"type":"assistant","message":{"usage":{"input_tokens":5,"cache_read_input_tokens":1,"cache_creation_input_tokens":1}}})+"\n")
    o.write(json.dumps({"type":"assistant","message":{"usage":{"input_tokens":i,"cache_read_input_tokens":r,"cache_creation_input_tokens":c}}})+"\n")
    o.write(json.dumps({"type":"user","message":{"content":"ещё"}})+"\n")
PY
}
mk_tr "$TD/big.jsonl" 10 290000 10000
mk_tr "$TD/small.jsonl" 10 90000 10000

out=$(run_hook "{\"session_id\":\"sess-big\",\"prompt\":\"x\",\"transcript_path\":\"$TD/big.jsonl\"}")
printf '%s' "$out" | grep -q "Чат разросся (~300 тыс." && is_json "$out"; check "should hint when transcript usage is 300k" $?
out=$(run_hook "{\"session_id\":\"sess-big\",\"prompt\":\"x\",\"transcript_path\":\"$TD/big.jsonl\"}")
printf '%s' "$out" | grep -q "Чат разросся"; check "should not repeat ctx hint twice in a session" $((1-$?))

out=$(run_hook "{\"session_id\":\"sess-small\",\"prompt\":\"x\",\"transcript_path\":\"$TD/small.jsonl\"}")
printf '%s' "$out" | grep -q "Чат разросся"; check "should not hint at 100k" $((1-$?))

out=$(run_hook '{"session_id":"sess-nopath","prompt":"x"}')
printf '%s' "$out" | grep -q "Чат разросся"; r1=$?
printf '%s' "$out" | grep -q "не включена строка"; r2=$?
[ "$r1" -ne 0 ] && [ "$r2" -ne 0 ] && is_json "$out"; check "should stay quiet with valid JSON without transcript_path" $?
out=$(run_hook "{\"session_id\":\"sess-nofile\",\"prompt\":\"x\",\"transcript_path\":\"$TD/nope.jsonl\"}")
printf '%s' "$out" | grep -q "Чат разросся"; r1=$?
[ "$r1" -ne 0 ] && is_json "$out"; check "should stay quiet with valid JSON when transcript file is missing" $?

# проект без .forge/ — подсказка всё равно работает
NF=$(mktemp -d)
out=$(cd "$NF" && printf '%s' "{\"session_id\":\"sess-nf\",\"prompt\":\"x\",\"transcript_path\":\"$TD/big.jsonl\"}" | "$HOOK" 2>/dev/null)
printf '%s' "$out" | grep -q "Чат разросся" && is_json "$out"; check "should hint at 300k even in a project without .forge" $?
out=$(cd "$NF" && printf '%s' '{"session_id":"sess-nf2","prompt":"x"}' | "$HOOK" 2>/dev/null)
[ -z "$out" ]; check "should stay silent (no output) without .forge and without hint" $?
rm -rf "$NF" "$TD"

export HOME="$REAL_HOME"

cd / && rm -rf "$workdir"

echo "---"
if [ "$fails" -gt 0 ]; then
    echo "$fails test(s) FAILED"
    exit 1
fi
echo "All tests passed"
exit 0
