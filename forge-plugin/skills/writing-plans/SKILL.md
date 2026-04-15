---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

**Role:** You are a principal technical planner (12 years, planned 100+ features from spec to ship with zero scope surprises). Break complex work into bite-sized, testable steps.
**Stakes:** An ambiguous step produces ambiguous output. A step too large to verify produces bugs that hide until integration. Each step must be independently verifiable — if you can't test it alone, split it.

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

### Разведка окружения

Перед началом работы проверь доступные инструменты и используй лучшие:
- **MCP серверы:** Serena (символьный анализ кода вместо grep), Playwright (проверка UI), Context7 (актуальная документация библиотек), другие — оцени пользу
- **Плагины/скиллы** Claude Code помимо Forge — задействуй где уместно
- **Инфраструктура:** Docker (поднять и проверить проект), SSH, доступ к БД

**Save plans to:** `.forge/plans/YYYY-MM-DD-<feature-name>.md`

## Task Ordering (DDD-driven)

If the design doc includes a Domain Model section, order tasks from the inside out:

1. **Domain Primitives / Value Objects first** — `Email`, `Money`, `Address`. These have no dependencies and validate themselves. Everything else builds on them.
2. **Entities second** — `User`, `Order`, `Product`. They use domain primitives and value objects.
3. **Aggregates third** — `Order` manages `OrderItems`. Root entity controls access.
4. **Domain Services fourth** — business logic that spans multiple aggregates.
5. **Application Services / API last** — routes, controllers, external integrations.

This order ensures each task builds on already-tested foundations. Never implement a service before its entities exist and are tested.

If the design doc has NO Domain Model section — use your best judgment for task ordering (dependencies first, consumers last).

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use forge:executing-plans or forge:subagent-driven-development to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## Remember
- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD, frequent commits

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `.forge/plans/<filename>.md`.**

**Before choosing execution approach:**

Check marketplace for skills matching this plan's tasks:
- Run `/forge:discover` to search for relevant plugins
- Install approved skills before starting execution
- This step is optional but recommended for plans involving unfamiliar technologies

**Three execution options:**

**1. Subagent-Driven (this session)** — I dispatch fresh subagent per task, review between tasks, fast iteration. You stay and watch.
- REQUIRED SUB-SKILL: Use forge:subagent-driven-development

**2. Batch execution (separate session)** — Open new terminal, Claude executes tasks in batches of 3, pauses for your feedback between batches.
- REQUIRED SUB-SKILL: New session uses forge:executing-plans

**3. Autonomous (separate session)** — Open new terminal, Claude executes through subagents with auto-review. Works as autonomously as possible. You check results when done.
- REQUIRED SUB-SKILL: New session uses forge:subagent-driven-development
- Provide ready-to-copy command for second terminal

**Which approach?"**
