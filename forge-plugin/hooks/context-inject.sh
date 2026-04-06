#!/usr/bin/env bash
# UserPromptSubmit hook — inject L0 project context into every prompt
# Reads ONLY index.yml (~200 tokens) or index.md (legacy, ~400 tokens)
# Claude decides what L1/L2 to load based on catalog tags

set -euo pipefail

# Check for FORGE docs (new format first, then legacy)
if [ -f "docs/index.yml" ]; then
    index_content=$(cat docs/index.yml 2>/dev/null || echo "")
elif [ -f "docs/index.md" ]; then
    index_content=$(cat docs/index.md 2>/dev/null || echo "")
else
    exit 0
fi

# Current branch
branch=$(git branch --show-current 2>/dev/null || echo "unknown")

# Last 3 commits
git_log=$(git log --oneline -3 2>/dev/null || echo "no git")

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

context="FORGE L0 CONTEXT (auto-injected):\n\n${index_content}\n\n--- Branch: ${branch}\n--- Recent: ${git_log}\n\nROUTING: Match catalog[].tags with current task to decide which L1 files to load. Do NOT load all files — only what matches."

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
