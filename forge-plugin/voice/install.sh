#!/usr/bin/env bash
# Установка голоса уведомлений на мак (DEC-21): venv с Chatterbox, образец голоса VASKO из sounds/stop, прогрев.
# Повторный запуск безопасен: пакеты не переставляются, образец пересобирается, кэш фраз чистится
# (настройки голоса могли поменяться), работающий голос перезапускается.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VH="${FORGE_VOICE_HOME:-$HOME/.claude/forge-voice}"
PY="$VH/venv/bin/python"
STRESS="git+https://github.com/Vuizur/add-stress-to-epub@9e064c815373ef6f0360dd97b0d0fc37b52d256f"
REF_SHA1="dfeac53991aa21a1e7b64e117318516e6c529b73"   # образец, утверждённый на слух 2026-10-23
REF_FILES=(
  "ElevenLabs_2026-04-08T12_04_34_VASKO - Deep, Warm and Pleasant_pvc_sp100_s75_sb70_se0_b_m2.mp3"
  "ElevenLabs_2026-04-08T12_04_52_VASKO - Deep, Warm and Pleasant_pvc_sp100_s75_sb70_se0_b_m2.mp3"
  "ElevenLabs_2026-04-08T12_05_08_VASKO - Deep, Warm and Pleasant_pvc_sp100_s75_sb70_se0_b_m2.mp3"
)

[ "$(uname)" = Darwin ] || { echo "Голос — только для macOS; здесь остаются старые mp3."; exit 1; }
command -v uv >/dev/null || { echo "Нужен uv: brew install uv"; exit 1; }
command -v ffmpeg >/dev/null || { echo "Нужен ffmpeg: brew install ffmpeg"; exit 1; }
mkdir -p "$VH/ref" "$VH/queue"

if [ -x "$PY" ] && "$PY" -c "import chatterbox.mtl_tts, russian_text_stresser, num2words" 2>/dev/null; then
    echo "Пакеты голоса уже установлены — не трогаю."
else
    [ -x "$PY" ] || uv venv -q --python 3.11 "$VH/venv"
    echo "Ставлю пакеты голоса (несколько ГБ, первый раз — минуты)…"
    # chatterbox-tts и ударения формально конфликтуют (gradio / spacy) — ставим проверенный набор как есть
    UV_NO_PROGRESS=1 uv pip install -q --python "$PY" --no-deps -r "$ROOT/voice/requirements.lock"
    UV_NO_PROGRESS=1 uv pip install -q --python "$PY" num2words
    "$PY" -c "import chatterbox.mtl_tts, russian_text_stresser, num2words"
fi

# образец голоса: ровно эти три записи VASKO → 24 кГц моно, склейка (~10 с)
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
i=0
for f in "${REF_FILES[@]}"; do
    ffmpeg -loglevel error -y -i "$ROOT/sounds/stop/$f" -ar 24000 -ac 1 "$tmp/part$i.wav"
    echo "file 'part$i.wav'" >> "$tmp/list.txt"
    i=$((i + 1))
done
(cd "$tmp" && ffmpeg -loglevel error -y -f concat -safe 0 -i list.txt "$VH/ref/vasko.wav")
sha=$(shasum "$VH/ref/vasko.wav" | cut -d' ' -f1)
[ "$sha" = "$REF_SHA1" ] && echo "Образец голоса совпал с утверждённым." \
    || echo "Образец голоса собран, но отличается от утверждённого по байтам (другая сборка ffmpeg) — сверить на слух."

rm -rf "$VH/cache"
rm -f "$VH/broken" "$VH/warned"
if [ -f "$VH/voiced.pid" ]; then
    touch "$VH/restart"   # работающий голос доиграет и выйдет; следующий хук поднимет новый
fi

echo "Прогрев (первый раз модель может докачиваться)…"
FORGE_VOICE_HOME="$VH" FORGE_VOICE_ONLINE=1 "$PY" "$ROOT/voice/voiced.py" --say "Плагин: голос установлен"
