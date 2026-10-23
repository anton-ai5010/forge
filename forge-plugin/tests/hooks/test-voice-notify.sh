#!/usr/bin/env bash
# Тесты для voice/notify.py — решение «говорить или молчать» и фраза голоса.
# VOICE_HOME подменён, пробы окна/простоя — переменными, venv — заглушка, звук — в лог.
set -uo pipefail

NOTIFY="$(cd "$(dirname "$0")/../../voice" && pwd)/notify.py"
VOICED="$(cd "$(dirname "$0")/../../voice" && pwd)/voiced.py"
T="$(mktemp -d)"; trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT
fails=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fails=$((fails+1)); }
check() { [ "$2" = "$3" ] && ok "$1" || bad "$1 — got [$2], want [$3]"; }

VH="$T/voice"; mkdir -p "$VH/venv/bin"
printf '#!/bin/sh\necho "spawned $*" >> "%s/spawn.log"\n' "$VH" > "$VH/venv/bin/python"; chmod +x "$VH/venv/bin/python"
printf '{"/x/plugin": "Плагин", "/x/dom": "Дом"}' > "$VH/names.json"
export FORGE_VOICE_HOME="$VH" FORGE_VOICE_PLAYER="log:$T/played.log"

msg() { python3 -c 'import json,sys; print(json.dumps({"last_assistant_message": sys.argv[1], "cwd": "/x/plugin"}))' "$1"; }
run() {  # kind json [VAR=val ...] → строка решения (DRYRUN)
    local kind="$1" json="$2"; shift 2
    printf '%s' "$json" | env FORGE_VOICE_DRYRUN=1 CLAUDE_PROJECT_DIR=/x/plugin FORGE_VOICE_FRONT=0 FORGE_VOICE_IDLE=5 "$@" python3 "$NOTIFY" "$kind" 2>/dev/null
}

# --- молчание на промежуточных ---
check "should stay silent when the answer starts with ⏳" "$(run stop "$(msg '⏳ Жду результатов тестов.')")" "silent"
check "should stay silent when ⏳ is wrapped in markdown" "$(run stop "$(msg '**⏳ Жду** прогона')")" "silent"
check "should stay silent when ⏳ follows the «понял так» line" "$(run stop "$(msg $'понял так: проверить поддержку\n⏳ Обход идёт.')")" "silent"
check "should stay silent on a quiet round without the badge" "$(run stop "$(msg 'Обход 12:07 — тихо.')")" "silent"
check "should stay silent while background tasks are still running" \
    "$(run stop '{"last_assistant_message": "Запустил полный прогон.", "background_tasks": [{"id": "b1"}]}')" "silent"

# --- новости и итоги ---
check "should speak news when the project window is not in front" \
    "$(run stop "$(msg 'Поддержка маркета подтвердила возврат. Деньги вернутся завтра.')")" "say Плагин: Поддержка маркета подтвердила возврат"
check "should speak the result after a series of ⏳ answers" "$(run stop "$(msg 'Тесты прошли.')")" "say Плагин: Тесты прошли"
check "should stay silent in the front project while the owner is active" "$(run stop "$(msg 'Тесты прошли.')" FORGE_VOICE_FRONT=1)" "silent"
check "should speak in the front project when the owner is idle over a minute" \
    "$(run stop "$(msg 'Тесты прошли.')" FORGE_VOICE_FRONT=1 FORGE_VOICE_IDLE=120)" "say Плагин: Тесты прошли"
rm -f "$VH/no-access"
check "should speak when window access is unknown" "$(run stop "$(msg 'Тесты прошли.')" FORGE_VOICE_FRONT=unknown)" "say Плагин: Тесты прошли"
[ -f "$VH/no-access" ] && ok "should mark missing window access" || bad "should mark missing window access"
run stop "$(msg 'Тесты прошли.')" FORGE_VOICE_FRONT=0 >/dev/null
[ ! -f "$VH/no-access" ] && ok "should clear the no-access mark when the window is readable" || bad "should clear the no-access mark when the window is readable"

check "should clean markdown, links, paths and dangling prepositions, cutting at a comma" \
    "$(run stop "$(msg 'Сохранил **итог** в [файл](.forge/x.md), `код` в /a/b/c.py и всё готово к проверке завтра утром. Дальше.')")" "say Плагин: Сохранил итог в файл"
check "should drop latin words and not end on a preposition" \
    "$(run stop "$(msg '`switch` запустится в 06:41 UTC, до этого времени выкат не начнётся.')")" "say Плагин: запустится в 06:41"
check "should drop brackets and a trailing preposition" \
    "$(run stop "$(msg 'Тесты дописаны (5067 зелёных) и закоммичены отдельно, на выкат это не влияет.')")" "say Плагин: Тесты дописаны 5067 зелёных и закоммичены отдельно"
check "should skip markdown tables and emoji" "$(run stop "$(msg $'| Проект | Статус |\n|---|---|\n✅ Готово, таблица выше 🎉')")" "say Плагин: Готово, таблица выше"
check "should keep «как и» and not end on a pronoun" "$(run stop "$(msg 'Тесты падают все, как и должны, его не трогаю пока что.')")" "say Плагин: Тесты падают все, как и должны"
check "should cut a long phrase at the last comma instead of a dangling word" \
    "$(run stop "$(msg 'Фоновая команда вместо тестов завершилась без ошибок, код выхода 0, всё штатно.')")" "say Плагин: Фоновая команда вместо тестов завершилась без ошибок"
check "should drop version strings" "$(run stop "$(msg 'Версия v7.13.1 выкачена.')")" "say Плагин: Версия выкачена"
out=$(run stop "$(msg 'Пересобрал документацию проекта, переименовал устаревшие разделы, перепроверил перекрёстные ссылки.')")
python3 - "$out" <<'PY' && ok "should keep the phrase within 60 characters on whole words" || bad "should keep the phrase within 60 characters on whole words — got [$out]"
import sys
body = sys.argv[1][len('say Плагин: '):]
assert sys.argv[1].startswith('say Плагин: ') and 0 < len(body) <= 60, body
assert 'Пересобрал документацию проекта, переименовал устаревшие разделы, перепроверил перекрёстные ссылки'.startswith(body), body
PY
check "should skip the «понял так» line in the phrase" "$(run stop "$(msg $'понял так: сделать отчёт\nГотово, всё работает.')")" "say Плагин: Готово, всё работает"
check "should say «есть вопрос» when the answer ends with a question" "$(run stop "$(msg $'Сделал два варианта.\n\nБерём первый?')")" "say Плагин: есть вопрос к тебе"
check "should detect a bold question" "$(run stop "$(msg $'Сделал два варианта.\n\n**Берём первый?**')")" "say Плагин: есть вопрос к тебе"
check "should detect a question followed by a hint in brackets" "$(run stop "$(msg $'Сделал.\nБерём первый? (да/нет)')")" "say Плагин: есть вопрос к тебе"
check "should not treat «тихого» as a quiet round" "$(run stop "$(msg 'Исправил: теперь тихого режима нет.')")" "say Плагин: Исправил: теперь тихого режима нет"
check "should not treat «без изменений» as a quiet round" "$(run stop "$(msg 'Файл остался без изменений, всё работает.')")" "say Плагин: Файл остался без изменений, всё работает"
check "should stay silent on «ничего нового»" "$(run stop "$(msg 'Проверил почту — ничего нового.')")" "silent"
check "should speak when the background task list is empty" "$(run stop '{"last_assistant_message": "Тесты прошли.", "background_tasks": []}')" "say Плагин: Тесты прошли"
check "should stay completely silent inside a nested plugin call" "$(run stop "$(msg 'Тесты прошли.')" FORGE_NESTED=1)" ""
python3 - "$T/tr.jsonl" <<'PY'
import json, sys
with open(sys.argv[1], 'w') as f:
    f.write(json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "Старый ответ."}]}}) + "\n")
    f.write(json.dumps({"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash"}]}}) + "\nnot json\n")
    f.write(json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "Отчёт собран."}]}}) + "\n")
PY
check "should read the answer from the transcript when the hook has no text" "$(run stop "{\"transcript_path\": \"$T/tr.jsonl\"}")" "say Плагин: Отчёт собран"
touch "$VH/no-access"
msg 'Тесты прошли.' | env FORGE_VOICE_DRYRUN=1 CLAUDE_PROJECT_DIR=/x/plugin FORGE_VOICE_APP=Safari FORGE_VOICE_IDLE=5 python3 "$NOTIFY" stop >/dev/null 2>&1
[ -f "$VH/no-access" ] && ok "should keep the no-access mark when the title was not checked" || bad "should keep the no-access mark when the title was not checked"
rm -f "$VH/no-access"
check "should say «готово» on an empty answer" "$(run stop '{"last_assistant_message": ""}')" "say Плагин: готово"
check "should not crash on garbage stdin" "$(run stop 'not json')" "say Плагин: готово"

# --- разрешения ---
check "should always announce a Bash permission, even in the front window" \
    "$(run permission '{"tool_name": "Bash", "tool_input": {"command": "ls"}}' FORGE_VOICE_FRONT=1)" "say Плагин: жду разрешения — хочу запустить команду"
check "should announce an unknown tool permission generically" "$(run permission '{"tool_name": "mcp__x__y"}')" "say Плагин: жду разрешения"
check "should announce a file edit permission" "$(run permission '{"tool_name": "Edit"}')" "say Плагин: жду разрешения — хочу изменить файл"

# --- имя проекта ---
check "should transliterate an unknown folder name" "$(run stop "$(msg 'Тесты прошли.')" CLAUDE_PROJECT_DIR=/x/zombashnya)" "say Зомбашня: Тесты прошли"
check "should match the front window by the project root, not by a subfolder cwd" \
    "$(printf '{"last_assistant_message": "Тесты прошли.", "cwd": "/x/plugin/sub"}' | env FORGE_VOICE_DRYRUN=1 CLAUDE_PROJECT_DIR=/x/plugin FORGE_VOICE_APP=Code FORGE_VOICE_TITLE='a.md — plugin' FORGE_VOICE_IDLE=5 python3 "$NOTIFY" stop 2>/dev/null)" "silent"
check "should speak when another project's window is in front" \
    "$(printf '{"last_assistant_message": "Тесты прошли."}' | env FORGE_VOICE_DRYRUN=1 CLAUDE_PROJECT_DIR=/x/plugin FORGE_VOICE_APP=Code FORGE_VOICE_TITLE='a.md — dom' FORGE_VOICE_IDLE=5 python3 "$NOTIFY" stop 2>/dev/null)" "say Плагин: Тесты прошли"
CLAUDE_PROJECT_DIR=/x/newproj python3 "$NOTIFY" name "Новый" >/dev/null 2>&1
check "should print the stored project name" "$(CLAUDE_PROJECT_DIR=/x/newproj python3 "$NOTIFY" name 2>/dev/null)" "Новый"
cp "$VH/names.json" "$T/names.good"; printf '[1]' > "$VH/names.json"
check "should survive a names table of the wrong shape" "$(run stop "$(msg 'Тесты прошли.')")" "say Плугин: Тесты прошли"
printf '{broken' > "$VH/names.json"
CLAUDE_PROJECT_DIR=/x/newproj python3 "$NOTIFY" name "Новый" >/dev/null 2>&1
[ -f "$VH/names.json.bad" ] && [ "$(CLAUDE_PROJECT_DIR=/x/newproj python3 "$NOTIFY" name 2>/dev/null)" = "Новый" ] \
    && ok "should set a corrupted names table aside instead of silently overwriting it" || bad "should set a corrupted names table aside instead of silently overwriting it"
cp "$T/names.good" "$VH/names.json"

# --- громкость словами ---
python3 "$NOTIFY" volume 15 >/dev/null 2>&1
check "should set the volume in percent" "$(cat "$VH/volume")" "0.15"
check "should print the current volume in percent" "$(python3 "$NOTIFY" volume 2>/dev/null)" "Громкость голоса: 15%"
python3 "$NOTIFY" volume тише >/dev/null 2>&1
check "should make it 20% quieter on «тише»" "$(cat "$VH/volume")" "0.12"
python3 "$NOTIFY" volume громче >/dev/null 2>&1
check "should make it 25% louder on «громче»" "$(cat "$VH/volume")" "0.15"
python3 "$NOTIFY" volume 500 >/dev/null 2>&1
check "should not go above 100%" "$(cat "$VH/volume")" "1.0"
rm -f "$VH/volume"
check "should report the default volume when none is set" "$(python3 "$NOTIFY" volume 2>/dev/null)" "Громкость голоса: 50%"

# --- выключатель и голос не установлен ---
python3 "$NOTIFY" mute >/dev/null 2>&1
check "should stay silent when muted" "$(run permission '{"tool_name": "Bash"}')" "silent"
python3 "$NOTIFY" unmute >/dev/null 2>&1
check "should speak again after unmute" "$(run permission '{"tool_name": "Bash"}')" "say Плагин: жду разрешения — хочу запустить команду"
check "should fall back to mp3 when the voice is not installed" "$(run stop "$(msg 'Тесты прошли.')" FORGE_VOICE_HOME="$T/none")" "mp3 stop"
check "should fall back to mp3 for permissions when the voice is not installed" "$(run permission '{"tool_name": "Bash"}' FORGE_VOICE_HOME="$T/none")" "mp3 permission"

# --- очередь и запуск демона (без DRYRUN) ---
live() { printf '%s' "$1" | env CLAUDE_PROJECT_DIR=/x/plugin FORGE_VOICE_FRONT=0 FORGE_VOICE_IDLE=5 python3 "$NOTIFY" "$2" 2>/dev/null; }
spawned() { for _ in $(seq 50); do grep -q "spawned $VOICED" "$VH/spawn.log" 2>/dev/null && return 0; sleep 0.1; done; return 1; }  # демон стартует отдельным процессом
live "$(msg 'Тесты прошли.')" stop
job=$(ls "$VH/queue"/*.json 2>/dev/null | head -1)
python3 - "$job" <<'PY' && ok "should enqueue the phrase as a job" || bad "should enqueue the phrase as a job"
import json, sys
j = json.load(open(sys.argv[1]))
assert j['text'] == 'Плагин: Тесты прошли' and j['kind'] == 'stop' and j['fixed'] is False and j['mp3_dir'].endswith('sounds/stop'), j
PY
spawned && ok "should start the daemon when it is not running" || bad "should start the daemon when it is not running"
rm -f "$VH/queue"/*.json "$VH/spawn.log"

python3 -c 'import json,sys,time; json.dump({"text":"Дом: старое","kind":"stop","project":"Дом","fixed":False,"created":time.time()-120,"mp3_dir":"x"}, open(sys.argv[1],"w"))' "$VH/queue/1-old.json"
: > "$T/played.log"
live "$(msg 'Тесты прошли.')" stop
[ -f "$VH/broken" ] && grep -q "не запускается" "$VH/broken" && grep -q "sounds/stop/" "$T/played.log" && grep -q "^milena" "$T/played.log" && [ -z "$(ls "$VH/queue")" ] \
    && ok "should notice a daemon that never starts: mp3, broken mark, spoken warning, queue cleared" || bad "should notice a daemon that never starts: mp3, broken mark, spoken warning, queue cleared"
touch -t 202001010000 "$VH/broken"
live "$(msg 'Тесты прошли.')" stop
spawned && ok "should try the daemon again once the broken mark is old" || bad "should try the daemon again once the broken mark is old"
sleep 0.3; rm -f "$VH/broken" "$VH/warned" "$VH/spawn.log" "$VH/queue"/*.json
touch "$VH/restart"
live "$(msg 'Тесты прошли.')" stop
[ ! -f "$VH/restart" ] && spawned && ok "should clear a stale restart mark when no daemon runs" || bad "should clear a stale restart mark when no daemon runs"
sleep 0.3; rm -f "$VH/spawn.log" "$VH/queue"/*.json

hold_lock() { python3 -c 'import fcntl,sys,time; f=open(sys.argv[1],"w"); fcntl.flock(f, fcntl.LOCK_EX); open(sys.argv[2],"w").write("ok"); time.sleep(30)' "$VH/voiced.lock" "$T/locked" & HOLDER=$!; for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$T/locked" ] && break; sleep 0.2; done; rm -f "$T/locked"; }

hold_lock
printf '%s %s' "$HOLDER" "$VOICED" > "$VH/voiced.pid"; touch "$VH/voiced.beat"
live "$(msg 'Тесты прошли.')" stop; sleep 0.5
[ ! -f "$VH/spawn.log" ] && ok "should not start a second daemon when one is alive" || bad "should not start a second daemon when one is alive"
printf '%s %s' "$HOLDER" "/old/7.13.1/voice/voiced.py" > "$VH/voiced.pid"
live "$(msg 'Тесты прошли.')" stop
live "$(msg 'Тесты прошли.')" stop; sleep 0.5
[ -f "$VH/restart" ] && spawned && [ "$(grep -c spawned "$VH/spawn.log")" = 1 ] && ok "should restart the daemon once after a plugin update" || bad "should restart the daemon once after a plugin update"
sleep 0.3; rm -f "$VH/restart" "$VH/spawn.log" "$VH/queue"/*.json

printf '%s %s' "$HOLDER" "$VOICED" > "$VH/voiced.pid"
python3 -c 'import json,sys,time; json.dump({"text":"Дом: старое","kind":"stop","project":"Дом","fixed":False,"created":time.time()-120,"mp3_dir":"x"}, open(sys.argv[1],"w"))' "$VH/queue/1-old.json"
touch -t 202001010000 "$VH/voiced.beat"; : > "$T/played.log"
live "$(msg 'Тесты прошли.')" stop
[ -f "$VH/broken" ] && grep -q "sounds/stop/" "$T/played.log" && grep -q "^milena" "$T/played.log" && ok "should detect a hung daemon: mp3, broken mark, spoken warning" || bad "should detect a hung daemon: mp3, broken mark, spoken warning"
kill -0 "$HOLDER" 2>/dev/null && ok "should not kill a process that is not the voice daemon" || bad "should not kill a process that is not the voice daemon"
rm -f "$VH/broken" "$VH/warned"; : > "$T/played.log"
printf '%s %s' "$HOLDER" "/old/7.13.1/voice/voiced.py" > "$VH/voiced.pid"; touch "$VH/restart"
python3 -c 'import json,sys,time; json.dump({"text":"Дом: старое","kind":"stop","project":"Дом","fixed":False,"created":time.time()-120,"mp3_dir":"x"}, open(sys.argv[1],"w"))' "$VH/queue/2-old.json"
live "$(msg 'Тесты прошли.')" stop
[ -f "$VH/broken" ] && grep -q "sounds/stop/" "$T/played.log" && ok "should detect a hung daemon of an older plugin version too" || bad "should detect a hung daemon of an older plugin version too"
rm -f "$VH/restart"; printf '%s %s' "$HOLDER" "$VOICED" > "$VH/voiced.pid"
kill "$HOLDER" 2>/dev/null; wait "$HOLDER" 2>/dev/null
: > "$T/played.log"
live "$(msg 'Тесты прошли.')" stop; sleep 0.5
grep -q "sounds/stop/" "$T/played.log" && ! grep -q "^milena" "$T/played.log" && [ ! -f "$VH/spawn.log" ] \
    && ok "should keep playing mp3 without respawn or repeated warning while freshly broken" || bad "should keep playing mp3 without respawn or repeated warning while freshly broken"

# ================= команды хуков из hooks.json: FORGE_NESTED и запасной mp3 без python =================
HOOKS_JSON="$(cd "$(dirname "$NOTIFY")/../hooks" && pwd)/hooks.json"
FR="$T/fakeroot"; mkdir -p "$FR/voice" "$FR/sounds/stop" "$FR/sounds/permission" "$T/bin"
touch "$FR/sounds/stop/a.mp3" "$FR/sounds/permission/a.mp3"
printf '#!/bin/sh\necho "afplay $*" >> "%s/hookplay.log"\n' "$T" > "$T/bin/afplay"; chmod +x "$T/bin/afplay"
hook_cmd() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"][sys.argv[2]][0]["hooks"][0]["command"])' "$HOOKS_JSON" "$1"; }
for ev in Stop PermissionRequest; do
    printf 'open("%s", "a").write("ran")\n' "$T/notify-ran.log" > "$FR/voice/notify.py"
    rm -f "$T/notify-ran.log"
    echo '{}' | env FORGE_NESTED=1 CLAUDE_PLUGIN_ROOT="$FR" PATH="$T/bin:$PATH" bash -c "$(hook_cmd $ev)"
    [ ! -f "$T/notify-ran.log" ] && ok "$ev hook should not run the voice inside a nested plugin call" || bad "$ev hook should not run the voice inside a nested plugin call"
    echo '{}' | env -u FORGE_NESTED CLAUDE_PLUGIN_ROOT="$FR" PATH="$T/bin:$PATH" bash -c "$(hook_cmd $ev)"
    [ -f "$T/notify-ran.log" ] && ok "$ev hook should run the voice normally" || bad "$ev hook should run the voice normally"
    printf 'raise SystemExit(1)\n' > "$FR/voice/notify.py"; rm -f "$T/hookplay.log"
    echo '{}' | env -u FORGE_NESTED CLAUDE_PLUGIN_ROOT="$FR" PATH="$T/bin:$PATH" bash -c "$(hook_cmd $ev)"
    grep -q "sounds/" "$T/hookplay.log" 2>/dev/null && ok "$ev hook should fall back to the old mp3 when the voice script cannot run" || bad "$ev hook should fall back to the old mp3 when the voice script cannot run"
done

# ================= фоновый голос voiced.py (учебный движок, без звука) =================
kill "$HOLDER" 2>/dev/null; wait "$HOLDER" 2>/dev/null
DH="$T/daemon"; mkdir -p "$DH/queue"
export FORGE_VOICE_ENGINE=fake FORGE_VOICE_FAKE_LOG="$T/gen.log"
job() {  # файл текст kind fixed возраст_с
    python3 -c 'import json,sys,time; json.dump({"text":sys.argv[2],"kind":sys.argv[3],"project":sys.argv[2].split(":")[0],"fixed":sys.argv[4]=="1","created":time.time()-float(sys.argv[5]),"mp3_dir":sys.argv[6]}, open(sys.argv[1],"w"), ensure_ascii=False)' \
        "$DH/queue/$1.json" "$2" "$3" "$4" "$5" "$(cd "$(dirname "$NOTIFY")/../sounds" && pwd)/$3"
}
daemon_once() { env FORGE_VOICE_HOME="$DH" FORGE_VOICE_ONESHOT=1 FORGE_VOICE_PLAYER="log:$T/dplayed.log" "$@" python3 "$VOICED" >/dev/null 2>&1; }
reset_d() { rm -rf "$DH"; mkdir -p "$DH/queue"; : > "$T/dplayed.log"; : > "$T/gen.log"; }

reset_d
job 1 "Дом: первый" stop 0 3; job 2 "Мекс: второй" stop 0 2; job 3 "Плагин: жду разрешения" permission 1 1
daemon_once
check "should play a permission first, then the rest oldest first" "$(tr '\n' '|' < "$T/dplayed.log")" "say Плагин: жду разрешения|say Дом: первый|say Мекс: второй|"
[ -z "$(ls "$DH/queue")" ] && ok "should empty the queue" || bad "should empty the queue"

reset_d
job 1 "Дом: один" stop 0 3; job 2 "Дом: два" stop 0 2
daemon_once
check "should play only the latest phrase of one project" "$(tr '\n' '|' < "$T/dplayed.log")" "say Дом: два|"

reset_d
job 1 "Дом: старьё" stop 0 400; job 2 "Мекс: свежее" stop 0 1
daemon_once
check "should drop phrases older than 5 minutes" "$(tr '\n' '|' < "$T/dplayed.log")" "say Мекс: свежее|"

reset_d
job 1 "Дом: готово" stop 1 1; daemon_once; job 2 "Дом: готово" stop 1 1; daemon_once
check "should generate a fixed phrase once and replay it from the cache" "$(grep -c '^gen ' "$T/gen.log")" "1"
check "should play the cached phrase both times" "$(grep -c 'say Дом: готово' "$T/dplayed.log")" "2"
n_before=$(ls "$DH/cache" | wc -l | tr -d ' ')
job 3 "Дом: собрал отчёт" stop 0 1; daemon_once
check "should not keep live phrases in the cache" "$(ls "$DH/cache" | wc -l | tr -d ' ')" "$n_before"

reset_d
job 1 "Дом: жду разрешения БОРМОТАНИЕ" permission 1 1; daemon_once
check "should regenerate a mumbled fixed clip once" "$(grep -c '^gen ' "$T/gen.log")" "2"
[ -z "$(ls "$DH/cache" 2>/dev/null)" ] && grep -q "sounds/permission/" "$T/dplayed.log" && ok "should not cache a mumbled clip and fall back to mp3" || bad "should not cache a mumbled clip and fall back to mp3"
reset_d
job 1 "Дом: собрал БОРМОТАНИЕ" stop 0 1; daemon_once
check "should replace a mumbled live phrase with «готово»" "$(tr '\n' '|' < "$T/dplayed.log")" "say Дом: готово|"

dur() { python3 -c 'import sys,wave; w=wave.open(sys.argv[1]); print("%.1f" % (w.getnframes()/w.getframerate()))' "$1"; }
cache_of() { python3 -c 'import hashlib,sys; print(sys.argv[2]+"/cache/"+hashlib.sha1(sys.argv[1].encode()).hexdigest()+".wav")' "$1" "$DH"; }
reset_d
job 1 "Дом: есть вопрос ХВОСТ" stop 1 1; daemon_once
d=$(dur "$(cache_of 'Дом: есть вопрос ХВОСТ')")   # речь ~2.0 с, пауза 0.3 с, шум 2.5 с
python3 -c 'import sys; assert 1.9 <= float(sys.argv[1]) <= 2.3' "$d" && ok "should cut the noise the model adds after the phrase" || bad "should cut the noise the model adds after the phrase — got [$d]"
reset_d
job 1 "Дом: две части ДВЕЧАСТИ речи" stop 1 1; daemon_once
d=$(dur "$(cache_of 'Дом: две части ДВЕЧАСТИ речи')")   # речь 2.5 с, пауза 0.3 с, речь 1.9 с той же громкости
check "should not cut real speech after a pause" "$d" "4.7"
reset_d
job 1 "Дом: тихий ДЛИННАЯПАУЗА хвост" stop 1 1; daemon_once
d=$(dur "$(cache_of 'Дом: тихий ДЛИННАЯПАУЗА хвост')")   # речь 2.6 с, пауза 0.6 с, тихий шорох 1.5 с
python3 -c 'import sys; assert 2.5 <= float(sys.argv[1]) <= 2.8' "$d" && ok "should cut a quiet tail after a long pause" || bad "should cut a quiet tail after a long pause — got [$d]"
reset_d
job 1 "Дом: ТИШИНАСНАЧАЛА и потом обычная речь" stop 1 1; daemon_once
check "should never leave only the leading silence" "$(dur "$(cache_of 'Дом: ТИШИНАСНАЧАЛА и потом обычная речь')")" "6.0"
reset_d
printf '{"/x/dom": "Дом"}' > "$DH/names.json"; mkdir -p "$DH/cache"
python3 - "$(cache_of 'Дом: готово')" <<'PY'
import sys, wave
with wave.open(sys.argv[1], "wb") as w:   # речь 1 с, пауза 0.3 с, шум 2.5 с
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
    tone = lambda s, a: b"".join(((a if (i // 20) % 2 else -a).to_bytes(2, "little", signed=True)) for i in range(int(8000 * s)))
    w.writeframes(tone(1.0, 4000) + b"\0\0" * 2400 + tone(2.5, 16000))
PY
daemon_once
check "should trim old cached phrases with a noisy tail at start" "$(dur "$(cache_of 'Дом: готово')")" "1.1"

reset_d
job 1 "Дом: СБОЙ" stop 0 1; daemon_once
grep -q "sounds/stop/" "$T/dplayed.log" && grep -q "СБОЙ" "$DH/voiced.log" && ok "should fall back to mp3 and log when generation fails" || bad "should fall back to mp3 and log when generation fails"

reset_d
printf '{oops' > "$DH/queue/0-bad.json"; job 1 "Дом: после битого" stop 0 1; daemon_once
[ ! -f "$DH/queue/0-bad.json" ] && grep -q "say Дом: после битого" "$T/dplayed.log" && ok "should drop a broken job and keep going" || bad "should drop a broken job and keep going"

reset_d
daemon_once FORGE_VOICE_ENGINE=fake-broken; rc=$?
[ "$rc" != 0 ] && [ -s "$DH/broken" ] && ok "should mark broken and exit when the engine cannot load" || bad "should mark broken and exit when the engine cannot load"
touch "$DH/broken"; daemon_once
[ ! -f "$DH/broken" ] && ok "should clear the broken mark after a successful start" || bad "should clear the broken mark after a successful start"

reset_d
python3 -c 'import json,sys,time; json.dump({"text":"Дом: кривое","kind":"stop","project":["не строка"],"fixed":False,"created":time.time()-2,"mp3_dir":"x"}, open(sys.argv[1],"w"))' "$DH/queue/0-weird.json"
job 1 "Мекс: следующее" stop 0 1; daemon_once
grep -q "say Мекс: следующее" "$T/dplayed.log" && [ -z "$(ls "$DH/queue")" ] && ok "should survive a job of the wrong shape and keep going" || bad "should survive a job of the wrong shape and keep going"

reset_d
printf '{"/x/dom": "Дом СБОЙ"}' > "$DH/names.json"
perl -e 'alarm 15; exec @ARGV' env FORGE_VOICE_HOME="$DH" FORGE_VOICE_ONESHOT=1 FORGE_VOICE_PLAYER="log:$T/dplayed.log" python3 "$VOICED" >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && [ "$(grep -c '^gen ' "$T/gen.log")" -le 12 ] && ok "should give up on a phrase it cannot prepare instead of looping" || bad "should give up on a phrase it cannot prepare instead of looping (rc=$rc, gens=$(grep -c '^gen ' "$T/gen.log"))"

reset_d
mkdir -p "$DH/cache"; touch "$DH/live-1.wav" "$DH/say-2.wav" "$DH/cache/a.wav.tmp.wav" "$DH/cache/b.wav.raw.wav" "$DH/queue/3.tmp"
touch -t 202001010000 "$DH/live-1.wav" "$DH/say-2.wav" "$DH/cache/a.wav.tmp.wav" "$DH/cache/b.wav.raw.wav" "$DH/queue/3.tmp"
daemon_once
[ -z "$(ls "$DH" | grep -E '^(live|say)-')" ] && [ -z "$(ls "$DH/cache" | grep -E 'tmp|raw')" ] && [ ! -f "$DH/queue/3.tmp" ] \
    && ok "should clean leftovers of a crashed run at start" || bad "should clean leftovers of a crashed run at start"

reset_d
touch "$DH/mute"; job 1 "Дом: при выключенном" stop 0 1; daemon_once
[ ! -s "$T/dplayed.log" ] && [ -z "$(ls "$DH/queue")" ] && ok "should drop queued phrases while muted" || bad "should drop queued phrases while muted"

reset_d
perl -e 'alarm 5; exec @ARGV' env FORGE_VOICE_HOME="$DH" python3 "$VOICED" --say >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "should refuse --say without text instead of starting the daemon" || bad "should refuse --say without text instead of starting the daemon (rc=$rc)"

reset_d
printf '{"/x/dom": "Дом"}' > "$DH/names.json"; daemon_once
check "should prepare the six fixed phrases per project while idle" "$(ls "$DH/cache" | wc -l | tr -d ' ')" "6"
read -r dpid dpath < "$DH/voiced.pid"
[ "$dpath" = "$VOICED" ] && [ -f "$DH/voiced.beat" ] && ok "should write its pid and path and a heartbeat" || bad "should write its pid and path and a heartbeat"

reset_d
python3 -c 'import fcntl,sys,time; f=open(sys.argv[1],"w"); fcntl.flock(f, fcntl.LOCK_EX); open(sys.argv[2],"w").write("ok"); time.sleep(3)' "$DH/voiced.lock" "$T/dlocked" & LH=$!
for _ in $(seq 20); do [ -f "$T/dlocked" ] && break; sleep 0.1; done
job 1 "Дом: жду очереди" stop 0 1; touch "$DH/restart"
daemon_once & DP=$!; sleep 1
[ -f "$DH/queue/1.json" ] && kill -0 "$DP" 2>/dev/null && ok "should wait for the lock held by another daemon" || bad "should wait for the lock held by another daemon"
wait "$LH" 2>/dev/null; wait "$DP" 2>/dev/null
grep -q "say Дом: жду очереди" "$T/dplayed.log" && [ ! -f "$DH/restart" ] && ok "should take over after the old daemon exits and clear the restart mark" || bad "should take over after the old daemon exits and clear the restart mark"

reset_d
env FORGE_VOICE_HOME="$DH" FORGE_VOICE_PLAYER="log:$T/dplayed.log" python3 "$VOICED" >/dev/null 2>&1 & DP=$!
for _ in $(seq 30); do [ -f "$DH/voiced.pid" ] && break; sleep 0.1; done
touch "$DH/restart"; for _ in $(seq 30); do kill -0 "$DP" 2>/dev/null || break; sleep 0.1; done
[ -f "$DH/voiced.pid" ] && ! kill -0 "$DP" 2>/dev/null && ok "should exit when a newer version asks for a restart" || { bad "should exit when a newer version asks for a restart"; kill "$DP" 2>/dev/null; }

[ "$fails" -eq 0 ] && echo "All tests passed" || { echo "$fails test(s) FAILED"; exit 1; }
