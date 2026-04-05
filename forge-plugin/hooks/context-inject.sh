#!/usr/bin/env bash
# UserPromptSubmit hook — inject project context into every prompt
# Only fires if docs/index.md exists (FORGE-initialized project)

set -euo pipefail

# Check if FORGE docs exist
if [ ! -f "docs/index.md" ]; then
    exit 0
fi

# Read index.md (the critical context file, ~400 tokens)
index_content=$(cat docs/index.md 2>/dev/null || echo "")

# List dead-ends topics (just filenames, not contents)
dead_ends=$(ls docs/dead-ends/ 2>/dev/null || echo "none")

# Last 3 commits for recent activity
git_log=$(git log --oneline -3 2>/dev/null || echo "no git")

# Current branch
branch=$(git branch --show-current 2>/dev/null || echo "unknown")

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

context="📋 FORGE CONTEXT (auto-injected):\n\n${index_content}\n\n--- Dead-ends topics: ${dead_ends}\n--- Branch: ${branch}\n--- Recent: ${git_log}\n\n⚠️ Before fixing bugs — check docs/dead-ends/ for this topic. Before architectural choices — check docs/decisions.md. After completing work — update docs/index.md Session section."

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
