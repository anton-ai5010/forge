#!/bin/bash
# Факты о плагине, которые легко разъезжаются с текстом.
# Usage: bash tests/hooks/test-plugin-facts.sh

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FAIL=0
check() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; FAIL=$((FAIL+1)); fi; }

check "docs/delivery-bar.md существует" "[ -f '$ROOT/docs/delivery-bar.md' ]"
for f in skills/plan/SKILL.md skills/execute/SKILL.md skills/critique/SKILL.md; do
  check "$f: короткая мера «по делу» ровно один раз" "[ \$(grep -c '^\*\*Мера «по делу»\*\* (полностью' '$ROOT/$f') -eq 1 ]"
  check "$f: ссылка на delivery-bar.md" "grep -q 'docs/delivery-bar.md' '$ROOT/$f'"
done
check "чеклист: пункты «перебор?» и «нижняя планка»" "grep -q 'Перебор?' '$ROOT/skills/requesting-code-review/review-checklist.md' && grep -q 'Нижняя планка выполнена?' '$ROOT/skills/requesting-code-review/review-checklist.md'"

RC="$ROOT/skills/requesting-code-review"
check "шаблон проверяющего: дифф в промпте ({DIFF}) и ссылка на чеклист" "grep -q '{DIFF}' '$RC/code-reviewer.md' && grep -q 'review-checklist.md' '$RC/code-reviewer.md'"
check "агент code-reviewer ссылается на чеклист" "grep -q 'review-checklist.md' '$ROOT/agents/code-reviewer.md'"
check "шаблон двойной проверки (SDD) — на новом шаблоне с диффом" "grep -q 'DIFF:' '$ROOT/skills/subagent-driven-development/code-quality-reviewer-prompt.md' && ! grep -q 'BASE_SHA' '$ROOT/skills/subagent-driven-development/code-quality-reviewer-prompt.md'"

N_DECL="$(grep -oE '[0-9]+ скилл[а-я]*' "$ROOT/../CLAUDE.md" | head -1 | grep -oE '^[0-9]+')"
N_REAL="$(ls "$ROOT"/skills/*/SKILL.md | wc -l | tr -d ' ')"
check "CLAUDE.md: число скиллов ($N_DECL) = числу SKILL.md ($N_REAL)" "[ '$N_DECL' = '$N_REAL' ]"

# каждый скрипт, который hooks.json вызывает напрямую, должен быть исполняемым (иначе хук падает на каждом событии)
for f in $(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/hooks/[a-z0-9_-]+\.sh' "$ROOT/hooks/hooks.json" | sed 's|${CLAUDE_PLUGIN_ROOT}/||' | sort -u); do
  check "$f исполняемый (вызывается из hooks.json)" "[ -x '$ROOT/$f' ]"
done
check "в git у hooks/*.sh стоит бит запуска" "[ -z \"\$(git -C '$ROOT' ls-files -s hooks/*.sh | awk '\$1 != \"100755\"')\" ]"

EX="$ROOT/skills/execute/SKILL.md"
check "execute: схема проверки прямо в тексте (углы, Codex, второй круг, Opus после углов)" "grep -q 'Порядок проверки шага' '$EX' && grep -q 'логика' '$EX' && grep -q 'codex-review.sh review' '$EX' && grep -q 'Второй круг' '$EX' && grep -q 'Opus — никогда вместо углов' '$EX'"
check "execute: обязательная строка отчёта «проверка: …»" "grep -q '«проверка: чисто»' '$EX'"

echo; [ $FAIL -eq 0 ] && echo OK || echo "$FAIL FAIL"
exit $FAIL
