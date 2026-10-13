#!/usr/bin/env bash
[ -n "$FORGE_NESTED" ] && exit 0
# PostToolUse (Bash): сжимает длинный вывод команды до пересказа. ВЫКЛЮЧЕН по умолчанию:
# работает только если в .forge/index.yml проекта есть строка `log_compressor: on`.
#
# Опора на документацию (code.claude.com/docs/en/hooks, PostToolUse, сверено 2026-10-13):
#  - stdin: {cwd, tool_name:"Bash", tool_input:{command,...},
#            tool_response:{stdout, stderr, exit_code}}
#  - подмена вывода: stdout хука = {"hookSpecificOutput":{"hookEventName":"PostToolUse",
#            "updatedToolOutput":{stdout, stderr, exit_code}}}
#  - запасной пересказчик — `claude -p --model haiku` БЕЗ --bare: --bare авторизуется только API-ключом,
#    а на подписке ключа нет. Вложенный вызов помечен FORGE_NESTED=1 — все хуки плагина (звук Stop,
#    инжект контекста, сам этот хук) при нём молчат; инструментов и MCP у пересказчика нет.
# Не проверено на живом событии: что updatedToolOutput принимает именно такую форму для фоновых
# (run_in_background) команд; что поле stderr/exit_code обязательны (передаём их как есть, на всякий случай).
#
# Сбой самого хука -> exit 0 без вывода (исходный вывод остаётся), причина в compress-errors.log.
# Тестовые переопределения: FORGE_OLLAMA_URL, FORGE_COMPRESS_TIMEOUT (по умолчанию 60 с).

input="$(cat)"
cwd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)"
[ -z "$cwd" ] && cwd="$PWD"
[ -f "$cwd/.forge/index.yml" ] && grep -qE '^log_compressor:[[:space:]]*on[[:space:]]*$' "$cwd/.forge/index.yml" || exit 0

root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"; [ -z "$root" ] && root="$cwd"
slug="$(printf '%s' "$root" | tr '/' '-')"
logdir="$HOME/.claude/forge-logs/$slug"
umask 077   # сырой вывод может содержать секреты — файлы и папки только владельцу
errlog="$logdir/compress-errors.log"
logerr() { mkdir -p -m 700 "$logdir" 2>/dev/null; echo "$(date '+%F %T') $*" >> "$errlog" 2>/dev/null; }
fail() { logerr "$@"; exit 0; }

# достаём вывод в файлы (stdout+stderr), команду отдельно
tmp="$(mktemp -d)" || exit 0
trap 'rm -rf "$tmp"' EXIT
printf '%s' "$input" | TMP="$tmp" python3 -c '
import json,os,sys
d=json.load(sys.stdin); r=d.get("tool_response") or {}
if not isinstance(r,dict): sys.exit(1)
t=os.environ["TMP"]
out=(r.get("stdout") or ""); err=(r.get("stderr") or "")
open(t+"/out.txt","w").write(out+(("\n"+err) if err else ""))
open(t+"/cmd.txt","w").write(str((d.get("tool_input") or {}).get("command",""))[:1500])
open(t+"/err.txt","w").write(err); open(t+"/stdout.txt","w").write(out)
open(t+"/code.txt","w").write(str(r.get("exit_code",0)))
' 2>/dev/null || exit 0

size="$(wc -m < "$tmp/out.txt" | tr -d ' ')"
[ "${size:-0}" -lt 12000 ] && exit 0

mkdir -p -m 700 "$logdir" 2>/dev/null || exit 0
chmod 700 "$logdir" 2>/dev/null
raw="$logdir/$(date +%Y%m%d-%H%M%S)-$$.txt"
cp "$tmp/out.txt" "$raw" || fail "не смог сохранить сырой вывод в $raw"

# секреты (паттерн из skills/requesting-code-review/codex-review.sh)
KEY='(token|secret|passw|bearer|api[_-]?key)[A-Za-z_]*["'"'"']?[[:space:]]*[:=][[:space:]]*'
SECRET="BEGIN [A-Z ]*PRIVATE KEY|${KEY}[\"'][^[:space:]\"']{12,}[\"']|${KEY}[A-Za-z0-9_+/=.-]{12,}[[:space:]]*\$|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|y0_[A-Za-z0-9_-]{20,}|[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}|AKIA[0-9A-Z]{16}"
FAKE='[:=][[:space:]]*["'"'"']?(test|fake|dummy|example|sample|placeholder|changeme|your[_-]|xxx)'
has_secret=0
grep -hoiE "$SECRET" "$tmp/out.txt" | grep -qviE "$FAKE" && has_secret=1

has_ollama=0
ollama list 2>/dev/null | grep -q 'qwen3.8:27b' && has_ollama=1

# Qwen 3.8 27B: ~20 с прогретая, холодная загрузка 18 ГБ — дольше минуты; Haiku — ~16 с (замер 2026-10-12)
OLLAMA_TIMEOUT="${FORGE_COMPRESS_TIMEOUT:-90}"
HAIKU_TIMEOUT="${FORGE_COMPRESS_TIMEOUT:-45}"
{
  printf '%s\n' 'Ты помогаешь агенту-программисту экономить внимание. Ниже — команда терминала и её вывод.
Сожми вывод до самого важного, не больше 15 строк:
- что делала команда / что проверялось;
- что упало, сломано или выглядит неправильно — с конкретикой: файлы, строки, числа, тексты ошибок;
- что прошло нормально — одной строкой.
Ничего не выдумывай: только то, что есть в выводе. Если важного нет — так и скажи.
'
  printf 'КОМАНДА:\n'; cat "$tmp/cmd.txt"; printf '\n\nВЫВОД:\n'; cat "$tmp/out.txt"
} > "$tmp/prompt.txt"

summary=""; rough=0; use_haiku=0
if [ "$has_ollama" = 1 ]; then
  summary="$(PROMPT="$tmp/prompt.txt" URL="${FORGE_OLLAMA_URL:-http://localhost:11434/api/generate}" perl -e "alarm $OLLAMA_TIMEOUT; exec @ARGV" python3 -c '
import json,os,urllib.request
body=json.dumps(dict(model="qwen3.8:27b",prompt=open(os.environ["PROMPT"]).read(),stream=False,think=False,options=dict(num_ctx=32768,temperature=0.2))).encode()
r=json.load(urllib.request.urlopen(urllib.request.Request(os.environ["URL"],body,{"Content-Type":"application/json"}),timeout=int(os.environ.get("T","120"))))
print(r.get("response","").strip())
' 2>"$tmp/sum.err")" || {
    # Ollama не успела (обычно холодный старт) — без секрета дальше Haiku, с секретом — грубо, наружу не шлём
    logerr "Ollama не ответил/упал: $(head -c 300 "$tmp/sum.err")"
    summary=""
    if [ "$has_secret" = 1 ]; then rough=1; else use_haiku=1; fi
  }
elif [ "$has_secret" = 1 ]; then
  rough=1
else
  use_haiku=1
fi
if [ "$use_haiku" = 1 ]; then
  summary="$(FORGE_NESTED=1 perl -e "alarm $HAIKU_TIMEOUT; exec @ARGV" claude -p --model haiku --tools '' --strict-mcp-config --no-session-persistence --system-prompt 'Ты точный и краткий помощник.' < "$tmp/prompt.txt" 2>"$tmp/sum.err")" \
    || fail "claude -p упал/завис: $(head -c 300 "$tmp/sum.err")"
fi

if [ "$rough" = 1 ]; then
  summary="$(head -n 60 "$tmp/out.txt"; echo '[... пропущено ...]'; tail -n 60 "$tmp/out.txt")"
  note=$'[сжато грубо: пересказчик недоступен]\n'
else
  [ -z "${summary//[[:space:]]/}" ] && fail "пустой пересказ"
  note=""
fi

# stderr уже внутри out.txt, поэтому подменяем stdout, stderr обнуляем
NOTE="$note" SUM="$summary" RAW="$raw" CODE="$(cat "$tmp/code.txt")" python3 -c '
import json,os
try: code=int(os.environ["CODE"])
except ValueError: code=0
text=os.environ["NOTE"]+os.environ["SUM"]+"\n\nполный вывод: "+os.environ["RAW"]
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PostToolUse","updatedToolOutput":{"stdout":text,"stderr":"","exit_code":code}}}))
' || fail "не смог собрать JSON ответа"
exit 0
