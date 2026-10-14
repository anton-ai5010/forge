#!/usr/bin/env bash
# Тесты для skills/requesting-code-review/codex-review.sh.
# Реальный Codex не зовём: вместо него в PATH кладём заглушку `codex`, которая
# пишет в файл -o свой входной input.txt — так видно, что ушло бы в OpenAI.
# Живой прогон и ловушка (Codex не читает диск) — test-codex-live.sh, запускает владелец.

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/skills/requesting-code-review/codex-review.sh"
fails=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fails=$((fails+1)); fi; }

T=$(mktemp -d)
mkdir -p "$T/bin" "$T/proj/.forge" "$T/home/.codex"
echo '{"tokens":{}}' > "$T/home/.codex/auth.json"
cat > "$T/bin/codex" <<'STUB'
#!/bin/bash
# заглушка: найти -C <dir> и -o <file>, вернуть input.txt и путь CODEX_HOME как JSON
while [ $# -gt 0 ]; do case "$1" in -C) dir="$2"; shift;; -o) out="$2"; shift;; esac; shift; done
python3 -c 'import json,sys,os; print(json.dumps({"findings":[],"summary":open(sys.argv[1]).read(),"codex_home":os.environ.get("CODEX_HOME","")}))' "$dir/input.txt" > "$out"
STUB
chmod +x "$T/bin/codex"
echo "codex_review: on" > "$T/proj/.forge/index.yml"
echo "Задача: поправить цену. Критерий: цена не ниже закупки." > "$T/task.md"
printf 'diff --git a/app.py b/app.py\n+price = cost * 1.2\n' > "$T/clean.diff"

run() { (cd "$T/proj" && HOME="$T/home" PATH="$1:/usr/bin:/bin:/usr/sbin" bash "$SCRIPT" "${@:2}"); }

out=$(run /nonexistent review "$T/clean.diff" "$T/task.md")
echo "$out" | grep -q "^SKIP: Codex не установлен" ; check "нет codex в PATH → SKIP ($out)" $?

echo "codex_review: off" > "$T/proj/.forge/index.yml"
out=$(run "$T/bin" review "$T/clean.diff" "$T/task.md")
echo "$out" | grep -q "^SKIP: Codex выключен" ; check "нет codex_review: on → SKIP ($out)" $?
echo "codex_review: on" > "$T/proj/.forge/index.yml"

# Поиск .forge/index.yml: соседняя рабочая копия (git worktree), подпапка, выключено в основной
runin() { (cd "$1" && HOME="$T/home" PATH="$T/bin:/usr/bin:/bin:/usr/sbin" bash "$SCRIPT" "${@:2}"); }
G="$T/main"; mkdir -p "$G/.forge" "$G/sub/dir"; echo "codex_review: on" > "$G/.forge/index.yml"
( cd "$G" && git init -q && git -c user.email=a@b -c user.name=t commit -qm init --allow-empty && git worktree add -q "$T/wt" -b wtb ) >/dev/null 2>&1
out=$(runin "$T/wt" review "$T/clean.diff" "$T/task.md")
echo "$out" | grep -q "^SKIP: Codex выключен" ; check "worktree без .forge → берёт index.yml основной копии ($out)" $((1-$?))
echo "$out" | grep -q '"findings"' ; check "worktree: дошло до Codex" $?
out=$(runin "$G/sub/dir" review "$T/clean.diff" "$T/task.md")
echo "$out" | grep -q "^SKIP: Codex выключен" ; check "подпапка основного репо → включено ($out)" $((1-$?))
echo "codex_review: off" > "$G/.forge/index.yml"
out=$(runin "$T/wt" review "$T/clean.diff" "$T/task.md")
echo "$out" | grep -q "^SKIP: Codex выключен" ; check "в основной копии выключено → SKIP из worktree ($out)" $?

i=0
for s in '-----BEGIN RSA PRIVATE KEY-----' 'password = "hunter2hunter2xx"' 'token: y0_AgAAAAAbcdefghijklmnopqrstuv' 'BOT=1234567890:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw' 'AKIAABCDEFGHIJKLMNOP' 'OPENAI=sk-abcdefghijklmnopqrstuvwxyz' 'ghp_abcdefghijklmnopqrstuvwxyz0123456789'; do
  i=$((i+1)); printf 'diff --git a/x b/x\n+%s\n' "$s" > "$T/s$i.diff"
  out=$(run "$T/bin" review "$T/s$i.diff" "$T/task.md")
  echo "$out" | grep -q "^SKIP: в изменениях похоже на секрет" ; check "секрет #$i в диффе → SKIP" $?
done
printf 'diff --git a/x b/x\n+API_TOKEN=abcdefghijklmnopqrstuv\n' > "$T/env.diff"
out=$(run "$T/bin" review "$T/env.diff" "$T/task.md")
echo "$out" | grep -q "^SKIP: в изменениях похоже на секрет" ; check "секрет без кавычек до конца строки → SKIP" $?
printf 'diff --git a/x b/x\n+    order_id, token = _ym_token_for_order(order_id, "200")\n+    password_hash = hash_password(raw_password_value)\n' > "$T/code.diff"
out=$(run "$T/bin" review "$T/code.diff" "$T/task.md")
echo "$out" | grep -q "^SKIP" ; check "обычный код со словом token = функция(...) — не секрет ($out)" $((1-$?))
printf 'diff --git a/tests/t.py b/tests/t.py\n API_KEY = "test-api-key-123456"\n HMAC_SECRET = "fake-secret-value-000"\n+password = "dummy_password_1234"\n' > "$T/fixture.diff"
out=$(run "$T/bin" review "$T/fixture.diff" "$T/task.md")
echo "$out" | grep -q "^SKIP" ; check "заглушки test-/fake-/dummy- в тестах — не секрет ($out)" $((1-$?))
printf 'Задача. api_key="abcdefghijklmnopqrst"\n' > "$T/task-secret.md"
out=$(run "$T/bin" review "$T/clean.diff" "$T/task-secret.md")
echo "$out" | grep -q "^SKIP: в изменениях похоже на секрет" ; check "секрет в task-файле → SKIP" $?

printf 'diff --git a/app.py b/app.py\n+price = cost * 1.2\ndiff --git a/.env.prod b/.env.prod\n+DB=localonly\ndiff --git a/certs/server.pem b/certs/server.pem\n+xyz\ndiff --git a/lib.py b/lib.py\n+def f(): pass\n' > "$T/mixed.diff"
out=$(run "$T/bin" review "$T/mixed.diff" "$T/task.md")
echo "$out" | grep -q "price = cost" && echo "$out" | grep -q "def f" ; check "обычные файлы диффа доходят до Codex" $?
echo "$out" | grep -qE "env.prod|server.pem|localonly" ; check "куски .env* и *.pem выкинуты из диффа" $((1-$?))

out=$(run "$T/bin" review "$T/clean.diff" "$T/task.md")
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); h=d["codex_home"]; assert h and "/.codex" not in h' "$out" 2>/dev/null
check "Codex запускается с отдельной папкой настроек, не ~/.codex" $?

out=$(run "$T/bin" critique "$T/clean.diff" "$T/task.md")
echo "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null ; check "режим critique → JSON" $?

out=$(run "$T/bin" bogus "$T/clean.diff" "$T/task.md")
echo "$out" | grep -q "^SKIP:" ; check "неизвестный режим → SKIP, не падение" $?

cat > "$T/bin/codex" <<'STUB'
#!/bin/bash
# первая модель «перегружена», вторая отвечает
while [ $# -gt 0 ]; do case "$1" in -m) m="$2"; shift;; -o) out="$2"; shift;; esac; shift; done
[ "$m" = "gpt-6.1-sol" ] && { echo "ERROR: Selected model is at capacity."; exit 1; }
echo "{\"findings\":[],\"summary\":\"model=$m\"}" > "$out"
STUB
out=$(run "$T/bin" review "$T/clean.diff" "$T/task.md")
echo "$out" | grep -q "model=gpt-6-astra" ; check "рабочая модель перегружена → повтор на запасной ($out)" $?

cat > "$T/bin/codex" <<'STUB'
#!/bin/bash
echo "ERROR: unauthorized"; exit 1
STUB
out=$(run "$T/bin" review "$T/clean.diff" "$T/task.md"); rc=$?
echo "$out" | grep -q "^SKIP: Codex не ответил.*unauthorized" && [ $rc -eq 0 ] ; check "Codex упал → SKIP с причиной, exit 0 ($out)" $?

# Песочница сама по себе (без Codex): домашняя папка закрыта, временная — открыта
SB="$PLUGIN_ROOT/skills/requesting-code-review/codex.sb"
W=$(cd "$(mktemp -d)" && pwd -P); cp "$SB" "$W/"
mkdir -p "$T/home/Projects"; echo "DECOY" > "$T/home/Projects/decoy"
TH=$(cd "$T/home" && pwd -P)   # песочница сравнивает настоящие пути (без ярлыков) — скрипт делает так же
sandbox-exec -D HOME="$TH" -D WORK="$W" -f "$W/codex.sb" cat "$T/home/Projects/decoy" >/dev/null 2>&1
check "песочница: чтение из домашней папки запрещено" $((1-$?))
sandbox-exec -D HOME="$TH" -D WORK="$W" -f "$W/codex.sb" sh -c "echo x > '$T/home/w'" 2>/dev/null; [ ! -f "$T/home/w" ]
check "песочница: запись в домашнюю папку запрещена" $?
sandbox-exec -D HOME="$TH" -D WORK="$W" -f "$W/codex.sb" sh -c "echo ok > '$W/t'" 2>/dev/null; [ -f "$W/t" ]
check "песочница: запись во временную папку проверки разрешена" $?
rm -rf "$W"

rm -rf "$T"
echo; [ $fails -eq 0 ] && echo OK || echo "$fails FAIL"
exit $fails
