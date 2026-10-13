#!/usr/bin/env bash
# Тесты для hooks/log-compress.sh. HOME подменён, ollama/claude — заглушки в PATH,
# Ollama HTTP — крошечный локальный сервер (FORGE_OLLAMA_URL).
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/../../hooks" && pwd)/log-compress.sh"
T="$(mktemp -d)"; trap 'kill $SRV 2>/dev/null; rm -rf "$T"' EXIT
fails=0
ok()   { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fails=$((fails+1)); }

export HOME="$T/home"; mkdir -p "$HOME"
PROJ="$T/proj"; mkdir -p "$PROJ/.forge" && git -C "$PROJ" init -q
PROJ="$(cd "$PROJ" && pwd -P)"
SLUG="$(printf '%s' "$PROJ" | tr '/' '-')"
LOGS="$HOME/.claude/forge-logs/$SLUG"

# заглушки
BIN="$T/bin"; mkdir -p "$BIN"
printf '#!/bin/sh\n[ "$1" = list ] && [ -n "$FAKE_OLLAMA" ] && echo "qwen3.8:27b abc 17 GB now"\nexit 0\n' > "$BIN/ollama"
printf '#!/bin/sh\ncase "$FAKE_CLAUDE" in hang) sleep 30;; fail) exit 1;; *) cat >/dev/null; echo "HAIKU-SUMMARY";; esac\n' > "$BIN/claude"
chmod +x "$BIN"/*
cat > "$T/srv.py" <<'PY'
import http.server, json, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers['Content-Length']))
        b = json.dumps({"response": "OLLAMA-SUMMARY"}).encode()
        self.send_response(200); self.send_header('Content-Length', str(len(b))); self.end_headers(); self.wfile.write(b)
    def log_message(self, *a): pass
s = http.server.HTTPServer(('127.0.0.1', 0), H); print(s.server_port, flush=True); s.serve_forever()
PY
python3 "$T/srv.py" > "$T/port" & SRV=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$T/port" ] && break; sleep 0.3; done
export FORGE_OLLAMA_URL="http://127.0.0.1:$(cat "$T/port")/api/generate"
export FORGE_COMPRESS_TIMEOUT=3
export PATH="$BIN:$PATH"

long()  { python3 -c "print('\n'.join('line %d of build output' % i for i in range(1000)))"; }
longsecret() { { long; echo 'API_KEY = "abcdefghijkl1234567890"'; } ; }
payload() { python3 -c 'import json,sys; print(json.dumps({"cwd":sys.argv[1],"tool_name":"Bash","tool_input":{"command":"make test"},"tool_response":{"stdout":sys.stdin.read(),"stderr":"","exit_code":1}}))' "$PROJ"; }
enable()  { printf 'goal: x\nlog_compressor: on\n' > "$PROJ/.forge/index.yml"; }
disable() { printf 'goal: x\n' > "$PROJ/.forge/index.yml"; }
run() { payload | "$HOOK" 2>/dev/null; }
newest() { ls -1 "$LOGS"/2*.txt 2>/dev/null | tail -1; }

# 1 выключено
disable; out="$(long | run)"
[ -z "$out" ] && [ ! -d "$LOGS" ] && ok "выключено — не трогается" || bad "выключено"

# 2 короткий
enable; out="$(echo short | run)"
[ -z "$out" ] && ok "короткий вывод не трогается" || bad "короткий"

# 3 FORGE_NESTED
out="$(long 2>/dev/null | FORGE_NESTED=1 run)"
[ -z "$out" ] && ok "FORGE_NESTED=1 — выход" || bad "FORGE_NESTED"

# 4 секрет без Ollama -> голова+хвост
out="$(longsecret | FAKE_OLLAMA= run)"
txt="$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["updatedToolOutput"]["stdout"])' 2>/dev/null)"
f="$(newest)"
if printf '%s' "$txt" | grep -q 'сжато грубо: пересказчик недоступен' && printf '%s' "$txt" | grep -q 'line 0 of' \
   && printf '%s' "$txt" | grep -q 'API_KEY' && ! printf '%s' "$txt" | grep -q 'HAIKU' && [ -f "$f" ] && ! printf '%s' "$f" | grep -q "^$PROJ"; then
  ok "секрет без Ollama — голова+хвост с пометкой, файл вне репо"; else bad "секрет без Ollama"; fi

# 5 секрет с Ollama -> Ollama, не Haiku
out="$(longsecret | FAKE_OLLAMA=1 run)"
printf '%s' "$out" | grep -q 'OLLAMA-SUMMARY' && ok "секрет + Ollama — пересказ Ollama" || bad "секрет + Ollama"

# 6 без секрета, Ollama есть
out="$(long | FAKE_OLLAMA=1 run)"
printf '%s' "$out" | python3 -c 'import json,sys; s=json.load(sys.stdin)["hookSpecificOutput"]["updatedToolOutput"]["stdout"]; sys.exit(0 if "OLLAMA-SUMMARY" in s and "полный вывод: " in s else 1)' && ok "длинный + Ollama — пересказ и путь" || bad "длинный + Ollama"

# 7 без секрета, Ollama нет -> haiku; путь существует
out="$(long | FAKE_OLLAMA= run)"
p="$(printf '%s' "$out" | python3 -c 'import json,sys,re; s=json.load(sys.stdin)["hookSpecificOutput"]["updatedToolOutput"]["stdout"]; print(re.search(r"полный вывод: (\S+)",s).group(1))' 2>/dev/null)"
printf '%s' "$out" | grep -q 'HAIKU-SUMMARY' && [ -f "$p" ] && ok "длинный + haiku — пересказ, файл есть" || bad "длинный + haiku"

# 8 пересказчик упал
rm -f "$LOGS/compress-errors.log"
out="$(long | FAKE_OLLAMA= FAKE_CLAUDE=fail run)"
[ -z "$out" ] && [ -s "$LOGS/compress-errors.log" ] && ok "пересказчик упал — вывод не подменён, ошибка в логе" || bad "пересказчик упал"

# 9 завис
rm -f "$LOGS/compress-errors.log"
out="$(long | FAKE_OLLAMA= FAKE_CLAUDE=hang run)"
[ -z "$out" ] && [ -s "$LOGS/compress-errors.log" ] && ok "пересказчик завис — вывод не подменён, ошибка в логе" || bad "пересказчик завис"

# 10 Ollama есть, но не ответила (холодный старт) и секрета нет -> Haiku
rm -f "$LOGS/compress-errors.log"
out="$(long | FAKE_OLLAMA=1 FORGE_OLLAMA_URL="http://127.0.0.1:9/api/generate" run)"
printf '%s' "$out" | grep -q 'HAIKU-SUMMARY' && grep -q "Ollama не ответил" "$LOGS/compress-errors.log" && ok "Ollama не ответила — запасной Haiku, сбой Ollama в логе" || bad "Ollama не ответила -> Haiku"

[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
