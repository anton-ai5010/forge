#!/bin/bash
# Второй взгляд другой семьи — Codex (подписка ChatGPT, лимит Claude не тратит).
#   codex-review.sh review   <diff-file> <task-file>   — проверка кода шага
#   codex-review.sh critique <plan-file> <task-file>   — 5-й критик плана
# Выход: JSON находок (codex-findings.schema.json) или строка "SKIP: <причина>". Всегда exit 0.
#
# Что Codex получает: только текст диффа/плана + задачи. Запуск — в пустой временной папке,
# с отдельной папкой настроек (CODEX_HOME) — без ~/.codex/config.toml и глобального AGENTS.md
# (там личные данные), и в песочнице codex.sb: домашняя папка закрыта целиком, писать — только во
# временную папку. Своя песочница Codex внутри чужой не стартует, поэтому она отключена флагом.
# Включается в проекте строкой `codex_review: on` в .forge/index.yml (по умолчанию выключен).

DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="$1"; INPUT="$2"; TASK="$3"
MODELS="gpt-6.1-sol gpt-6-astra"   # рабочая модель Codex; флагманская — запасная, если рабочая перегружена

command -v codex >/dev/null || { echo "SKIP: Codex не установлен"; exit 0; }
grep -qE '^codex_review:[[:space:]]*on' .forge/index.yml 2>/dev/null || { echo "SKIP: Codex выключен в этом проекте"; exit 0; }
case "$MODE" in
  review)   PROMPT_FILE="$DIR/review-checklist.md" ;;
  critique) PROMPT_FILE="$DIR/../critique/codex-critic.md" ;;
  *) echo "SKIP: неизвестный режим «$MODE» (нужно review или critique)"; exit 0 ;;
esac
[ -f "$INPUT" ] && [ -f "$TASK" ] || { echo "SKIP: нет входного файла ($INPUT / $TASK)"; exit 0; }
[ -f "$HOME/.codex/auth.json" ] || { echo "SKIP: Codex не залогинен (нет ~/.codex/auth.json)"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/work" "$tmp/home"

# Куски диффа по файлам секретов (.env*, *.pem, *secret*, *credential*) — выкинуть целиком
awk '/^diff --git /{ skip = ($0 ~ /\/(\.env[^ ]*|[^ ]*\.pem|[^ ]*secret[^ ]*|[^ ]*credential[^ ]*)( |$)/) } !skip' "$INPUT" > "$tmp/work/input.txt"
cp "$TASK" "$tmp/work/task.md"

# значение секрета — в кавычках, или голая строка до конца строки (не вызов функции: `token = get_token(x)` — не секрет)
KEY='(token|secret|passw|bearer|api[_-]?key)[A-Za-z_]*["'"'"']?[[:space:]]*[:=][[:space:]]*'
SECRET="BEGIN [A-Z ]*PRIVATE KEY|${KEY}[\"'][^[:space:]\"']{12,}[\"']|${KEY}[A-Za-z0-9_+/=.-]{12,}[[:space:]]*\$|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|y0_[A-Za-z0-9_-]{20,}|[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}|AKIA[0-9A-Z]{16}"
# явные заглушки из тестов (API_KEY = "test-…", "fake-…", "dummy…") секретом не считаются
FAKE='[:=][[:space:]]*["'"'"']?(test|fake|dummy|example|sample|placeholder|changeme|your[_-]|xxx)'
grep -hoiE "$SECRET" "$tmp/work/input.txt" "$tmp/work/task.md" | grep -qviE "$FAKE" && { echo "SKIP: в изменениях похоже на секрет — в OpenAI не отправляю"; exit 0; }

# Отдельная папка настроек: только вход в аккаунт, без конфига и глобальных инструкций
cp "$HOME/.codex/auth.json" "$tmp/home/auth.json"; chmod 600 "$tmp/home/auth.json"
cp "$HOME/.codex/auth.json" "$tmp/auth.orig"
cp "$DIR/codex-findings.schema.json" "$tmp/schema.json"   # песочница не пустит Codex в папку плагина

PROMPT="$(cat "$PROMPT_FILE")

Входные файлы — в текущей папке: input.txt ($([ "$MODE" = review ] && echo 'дифф шага' || echo 'план')), task.md (задача и критерий). Читай только их. Ответ — по схеме, по-русски."

for MODEL in $MODELS; do
  ( cd "$tmp/work" && CODEX_HOME="$tmp/home" perl -e 'alarm 600; exec @ARGV' \
      sandbox-exec -D HOME="$(cd "$HOME" && pwd -P)" -D WORK="$(cd "$tmp" && pwd -P)" -f "$DIR/codex.sb" \
      codex exec --dangerously-bypass-approvals-and-sandbox -C "$tmp/work" --skip-git-repo-check --ephemeral \
        -m "$MODEL" -c model_reasoning_effort=medium \
        --output-schema "$tmp/schema.json" -o "$tmp/out.json" "$PROMPT" ) </dev/null >"$tmp/log" 2>&1
  grep -q "at capacity" "$tmp/log" || break
done

# Codex мог обновить вход (refresh token) — вернуть его в ~/.codex, если там за это время ничего не менялось
if ! cmp -s "$tmp/home/auth.json" "$tmp/auth.orig" && cmp -s "$HOME/.codex/auth.json" "$tmp/auth.orig"; then
  cp "$tmp/home/auth.json" "$HOME/.codex/auth.json"
fi

if [ -s "$tmp/out.json" ] && python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$tmp/out.json" 2>/dev/null; then
  cat "$tmp/out.json"
else
  why=$(grep -iE 'error|denied|not permitted|unauthori|login|timeout' "$tmp/log" | tail -1 | cut -c1-160)
  echo "SKIP: Codex не ответил (упал, не залогинен или 10 минут без ответа)${why:+ — $why}"
fi
exit 0
