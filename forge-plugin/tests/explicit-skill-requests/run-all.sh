#!/bin/bash
# Run all explicit skill request tests
# Usage: ./run-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"

echo "=== Running All Explicit Skill Request Tests ==="
echo ""

PASSED=0
FAILED=0
RESULTS=""

# Test: subagent-driven-development, please
echo ">>> Test 1: subagent-driven-development-please"
if "$SCRIPT_DIR/run-test.sh" "subagent-driven-development" "$PROMPTS_DIR/subagent-driven-development-please.txt"; then
    PASSED=$((PASSED + 1))
    RESULTS="$RESULTS\nPASS: subagent-driven-development-please"
else
    FAILED=$((FAILED + 1))
    RESULTS="$RESULTS\nFAIL: subagent-driven-development-please"
fi
echo ""

# Test: use systematic-debugging
echo ">>> Test 2: use-systematic-debugging"
if "$SCRIPT_DIR/run-test.sh" "systematic-debugging" "$PROMPTS_DIR/use-systematic-debugging.txt"; then
    PASSED=$((PASSED + 1))
    RESULTS="$RESULTS\nPASS: use-systematic-debugging"
else
    FAILED=$((FAILED + 1))
    RESULTS="$RESULTS\nFAIL: use-systematic-debugging"
fi
echo ""

# Test: please use new-task
echo ">>> Test 3: please-use-new-task"
if "$SCRIPT_DIR/run-test.sh" "new-task" "$PROMPTS_DIR/please-use-new-task.txt"; then
    PASSED=$((PASSED + 1))
    RESULTS="$RESULTS\nPASS: please-use-new-task"
else
    FAILED=$((FAILED + 1))
    RESULTS="$RESULTS\nFAIL: please-use-new-task"
fi
echo ""

# Test: mid-conversation execute
echo ">>> Test 4: mid-conversation-execute"
if "$SCRIPT_DIR/run-test.sh" "subagent-driven-development" "$PROMPTS_DIR/mid-conversation-execute.txt"; then
    PASSED=$((PASSED + 1))
    RESULTS="$RESULTS\nPASS: mid-conversation-execute"
else
    FAILED=$((FAILED + 1))
    RESULTS="$RESULTS\nFAIL: mid-conversation-execute"
fi
echo ""

echo "=== Summary ==="
echo -e "$RESULTS"
echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Total: $((PASSED + FAILED))"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
