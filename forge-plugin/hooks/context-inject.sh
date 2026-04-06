#!/usr/bin/env bash
# UserPromptSubmit hook — inject L0 context + skill hints into every prompt
# Reads ONLY index.yml (~200 tokens) or index.md (legacy, ~400 tokens)
# Analyzes user prompt keywords to recommend relevant skills

set -euo pipefail

# Check for FORGE docs (new format first, then legacy)
if [ -f ".forge/index.yml" ]; then
    index_content=$(cat .forge/index.yml 2>/dev/null || echo "")
elif [ -f ".forge/index.md" ]; then
    index_content=$(cat .forge/index.md 2>/dev/null || echo "")
else
    exit 0
fi

# Current branch
branch=$(git branch --show-current 2>/dev/null || echo "unknown")

# Last 3 commits
git_log=$(git log --oneline -3 2>/dev/null || echo "no git")

# ============ SKILL HINTS (R1+R6) ============
# Read user prompt from stdin (hook receives JSON with "input" field)
hook_input=$(cat)
user_prompt=$(printf '%s' "$hook_input" | sed -n 's/.*"input"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')

skill_hint=""

# R1: Keyword-based skill matching (first match wins)
if printf '%s' "$user_prompt" | grep -qiE 'bug|fix|error|broken|fail|crash|баг|ошибк|сломал|не работа|debug'; then
    skill_hint="forge:systematic-debugging"
elif printf '%s' "$user_prompt" | grep -qiE 'design|ui |ux |color|font|palette|палитр|дизайн|стиль|шрифт|макет|layout'; then
    skill_hint="forge:ui-ux-design"
elif printf '%s' "$user_prompt" | grep -qiE 'test|tdd|тест|покры'; then
    skill_hint="forge:test-driven-development"
elif printf '%s' "$user_prompt" | grep -qiE 'plan|план|архитектур|спроектир|decompos'; then
    skill_hint="forge:writing-plans"
elif printf '%s' "$user_prompt" | grep -qiE 'refactor|cleanup|dead.?code|почист|рефактор|порядок|качеств'; then
    skill_hint="forge:code-cleanup"
elif printf '%s' "$user_prompt" | grep -qiE 'review|ревью|проверь|посмотри код'; then
    skill_hint="forge:requesting-code-review"
elif printf '%s' "$user_prompt" | grep -qiE 'stuck|застрял|не знаю|что делать|с чего начать|потерял|контекст'; then
    skill_hint="forge:project-unblocker"
elif printf '%s' "$user_prompt" | grep -qiE 'brainstorm|мозговой|придумай|обсудим|давай подумаем|новая фича|новый функционал'; then
    skill_hint="forge:brainstorming"
elif printf '%s' "$user_prompt" | grep -qiE 'merge|pr |pull.?request|finish|branch|ветк.*готов|мерж'; then
    skill_hint="forge:finishing-a-development-branch"
elif printf '%s' "$user_prompt" | grep -qiE 'sync|синх|обнови.*док|документац'; then
    skill_hint="forge:sync"
fi

# R6: File-context hints (only if no keyword match)
if [ -z "$skill_hint" ]; then
    changed_files=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null) || true
    if printf '%s' "$changed_files" | grep -qiE '\.(css|scss|less|styled|vue|svelte)$'; then
        skill_hint="forge:ui-ux-design"
    elif printf '%s' "$changed_files" | grep -qiE '(test|spec|__test__)'; then
        skill_hint="forge:test-driven-development"
    fi
fi

# ============ BUILD CONTEXT ============
# Escape for JSON
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

context="FORGE L0 CONTEXT (auto-injected):\n\n${index_content}\n\n--- Branch: ${branch}\n--- Recent: ${git_log}"

# Add skill hint if found
if [ -n "$skill_hint" ]; then
    context="${context}\n\nSKILL HINT: Consider using ${skill_hint} for this task."
fi

context="${context}\n\nROUTING: Match catalog[].tags with current task to decide which L1 files to load. Do NOT load all files — only what matches.\n\nDOC DISCIPLINE: If you just made a technical decision — record in .forge/decisions.yml. If an approach failed — record in .forge/dead-ends.yml. If you learned something non-obvious — record in .forge/learnings.yml. Do it NOW, not later."

escaped=$(escape_for_json "$context")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "${escaped}"
  }
}
EOF

exit 0
