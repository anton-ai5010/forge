# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

```
Agent tool (subagent_type: forge:code-reviewer):
  model: "sonnet"   (тип уже на sonnet; Opus — только по правилу схемы проверки в requesting-code-review)
  Use template at requesting-code-review/code-reviewer.md

  TASK_TEXT: [FULL TEXT of task requirements]
  STEP_CRITERION: [acceptance criterion of Task N from plan-file]
  DESCRIPTION: [from implementer's report, 1–3 lines]
  DIFF: [output of `git diff <commit before task>..HEAD` — pasted, not "go look"]
```

**Code reviewer returns:** findings in the checklist format (`requesting-code-review/review-checklist.md`) + one line per checklist item. Re-review after a fix — same template, DIFF = only the fix.
