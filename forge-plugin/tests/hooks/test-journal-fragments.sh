#!/usr/bin/env bash
# Журнал фрагментами: sync.sh close-task пишет в .forge/journal.d/, шапка README и toc.py видят фрагменты.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYNC="$ROOT/skills/github-sync/sync.sh"
HDR="$ROOT/skills/github-sync/scripts/render_readme_header.py"
TOC="$ROOT/skills/forge-context/toc.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0
ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fails=$((fails + 1)); }

# --- временный репо + поддельный gh ---
mkdir -p "$T/bin" "$T/repo/.forge"
cat > "$T/bin/gh" <<'G'
#!/usr/bin/env bash
case "$*" in
  "repo view --json owner"*) echo me ;;
  "repo view --json name"*) echo proj ;;
  "issue view"*"title"*) echo "Тестовая задача" ;;
  "issue view"*"milestone"*) echo "Цель X" ;;
  *) : ;;
esac
exit 0
G
chmod +x "$T/bin/gh"
cd "$T/repo" && git init -q && git remote add origin https://github.com/me/proj.git
printf 'github_sync: true\nnow:\n  task: demo\n' > .forge/index.yml
printf 'entries:\n  - date: "2026-01-01"\n    summary: "старая запись"\n' > .forge/journal.yml
echo 7 > .forge/.github-issue-demo
before=$(wc -c < .forge/journal.yml)

PATH="$T/bin:$PATH" bash "$SYNC" close-task demo >/dev/null 2>&1
n=$(ls .forge/journal.d/*.yml 2>/dev/null | wc -l | tr -d ' ')
[ "$n" = "1" ] && ok "close-task: фрагмент в journal.d" || bad "close-task: фрагмент в journal.d (файлов: $n)"
[ "$(wc -c < .forge/journal.yml)" = "$before" ] && ok "journal.yml не вырос" || bad "journal.yml вырос"
f=$(ls .forge/journal.d/*.yml 2>/dev/null | head -1)
case "$(basename "${f:-x}")" in 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]-demo.yml) ok "имя фрагмента";; *) bad "имя фрагмента ($f)";; esac
grep -q 'Закрыта задача: Тестовая задача' "$f" 2>/dev/null && grep -q 'slug: "demo"' "$f" && ok "содержимое записи" || bad "содержимое записи"

# --- читатели видят фрагмент ---
printf -- '- date: "2026-12-31"\n  summary: "ФРАГМЕНТ-МАРКЕР"\n  result: "r"\n' > .forge/journal.d/2026-12-31-0900-marker.yml
python3 "$TOC" --journal .forge 3 | grep -q 'ФРАГМЕНТ-МАРКЕР' && ok "toc.py видит фрагмент" || bad "toc.py видит фрагмент"
out=$(python3 -c "
import importlib.util,sys
sp=importlib.util.spec_from_file_location('h','$HDR'); m=importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
from pathlib import Path
print(m.last_journal_summary(Path('.forge')))" 2>&1)
[ "$out" = "ФРАГМЕНТ-МАРКЕР" ] && ok "шапка README: последний итог из фрагмента" || bad "шапка README (получили [$out])"

[ "$fails" = 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
