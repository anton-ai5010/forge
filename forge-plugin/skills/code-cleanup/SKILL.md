---
name: code-cleanup
description: Use when the user asks to clean up, refactor, lint, or improve code quality across the project. Also use when code feels messy, has dead code, naming inconsistencies, overly complex functions, or structural problems. Triggers on phrases like "навести порядок", "почистить код", "refactor", "code quality", "clean up", "technical debt".
---

**Role:** You are a staff software engineer (12 years) specializing in codebase rehabilitation — brought in to rescue codebases that teams are afraid to touch.
**Stakes:** Every cleanup that changes behavior is a production bug. Find the mess, measure it, clean it systematically — but break nothing. The team ships on this code tomorrow.

# Code Cleanup

## Автозагруженный контекст — ключевые решения (не противоречить):
!`cat .forge/decisions.md 2>/dev/null || echo "нет decisions.md"`

---

## Overview

Systematic project-wide code quality review with parallel agents. Produces a structured report before making any changes.

**Core principle:** Understand first, report second, fix only after approval. Never silently change code during analysis.

## When to Use

- User asks to clean up or refactor code
- Code has accumulated technical debt
- Before a major release or handoff
- After rapid prototyping phase — time to solidify
- Project conventions exist but aren't consistently followed

### Разведка окружения

Перед началом работы проверь доступные инструменты и используй лучшие:
- **MCP серверы:** Serena (символьный анализ кода вместо grep), Playwright (проверка UI), Context7 (актуальная документация библиотек), другие — оцени пользу
- **Плагины/скиллы** Claude Code помимо Forge — задействуй где уместно
- **Инфраструктура:** Docker (поднять и проверить проект), SSH, доступ к БД

## The Process

### Phase 1: Gather Context

**If FORGE docs exist** (`.forge/map.yml`):
1. Read `.forge/map.yml` — project structure, red zones
2. Read `.forge/conventions.yml` — naming rules, patterns, decisions
3. Use this as the source of truth for what "correct" looks like

**If no FORGE docs:**
1. Scan project structure (`find` / `ls` / `Glob`)
2. Infer conventions from the most consistent parts of the codebase
3. Note: without conventions.yml, report will flag inconsistencies but can't say which style is "correct"

**If Serena MCP is available** — use `get_file_structure` to quickly understand file contents without reading them fully.

### Phase 2: Dispatch Analysis Agents

Split the project into independent areas (by directory, module, or layer). Dispatch one agent per area using the `forge:dispatching-parallel-agents` pattern.

**Scan in parallel** — dispatch subagents for independent checks:
- Agent 1: Dead code + unused imports
- Agent 2: Naming inconsistencies + convention violations
- Agent 3: Duplication + complexity (functions >50 lines, nesting >3 levels)

Aggregate findings into a single report before presenting to user.

Each agent gets this prompt template:

```markdown
Analyze code quality in [directory/module]. Do NOT make any changes.

Project conventions: [paste from conventions.yml or describe inferred conventions]
Red zones: [list if any in this area]

Check for:
1. **Dead code** — unused imports, unreachable branches, commented-out code, unused variables/functions
2. **Naming** — inconsistent naming (camelCase vs snake_case mix, abbreviations, unclear names)
3. **Complexity** — functions over 40 lines, deeply nested logic (3+ levels), functions doing multiple things
4. **Duplication** — copy-pasted logic that should be extracted, near-identical functions
5. **Structure** — files doing too much, misplaced files (wrong directory), missing separation of concerns
6. **Convention violations** — deviations from project conventions (if known)
7. **DDD violations** (if design doc has Domain Model):
   - **Primitive obsession** — raw strings/numbers used for emails, money, IDs instead of domain primitives with validation
   - **Anemic entities** — entities that are just data bags with no behavior (all logic in services)
   - **Aggregate leaks** — external code reaching into aggregate internals instead of going through root
   - **Missing lifecycle validation** — state transitions without checking if transition is allowed
   - **Broken bounded contexts** — one context directly using another context's internal classes

For each issue found, report:
- File path and line number(s)
- Category (dead-code / naming / complexity / duplication / structure / convention)
- Severity (low / medium / high)
- What's wrong (one sentence)
- Suggested fix (one sentence)

Return a structured list. Do NOT fix anything.
```

### Phase 3: Compile Report

Merge agent results into a single report. Group by category, sort by severity.

Present to the user in this format:

```
## Code Cleanup Report

### Summary
- Files analyzed: X
- Issues found: Y
- High severity: N | Medium: N | Low: N

### High Severity
| File | Line | Category | Issue | Suggested Fix |
|------|------|----------|-------|---------------|
| ... | ... | ... | ... | ... |

### Medium Severity
| File | Line | Category | Issue | Suggested Fix |
|------|------|----------|-------|---------------|
| ... | ... | ... | ... | ... |

### Low Severity
(collapsed or summarized if many)

### Patterns Noticed
- [Any recurring issues across the codebase]
- [Systemic problems worth addressing at architecture level]
```

### Phase 4: Fix (Only After Approval)

After presenting the report, ask the user:
- "Fix all?" — proceed with everything
- "Fix high/medium only?" — skip low severity
- "Cherry-pick?" — user selects specific issues

When fixing, dispatch parallel agents again — one per directory/module. Each agent:
1. Gets the specific issues to fix in their area
2. Makes minimal changes — fix the issue, nothing else
3. Reports what was changed

After all agents return:
1. Review for conflicts
2. Run tests / linter if available
3. Present summary of changes made

## Red Zones

Files in red zones (from `.forge/map.yml`) get special treatment:
- Still analyzed and reported
- But NEVER auto-fixed — always require explicit per-file approval
- Flagged visually in the report

## Surgical Changes Principle

Touch only what you must. Clean up only your own mess:
- **Don't improve adjacent code** that isn't part of the cleanup task
- **Don't add docstrings** to functions you didn't change
- **Don't fix unrelated issues** you happen to notice — flag them in the report instead
- **Match existing style** — don't impose preferences
- **Remove only what YOUR cleanup made unnecessary.** Pre-existing dead code: flag, don't delete (unless explicitly asked)
- Every changed line should trace directly to the cleanup request

## What This Skill Does NOT Do

- **Architecture redesign** — this is cleanup, not rewrite. If analysis reveals architectural problems, flag them in "Patterns Noticed" and suggest a separate discussion.
- **Feature changes** — cleanup must not change behavior. If a function is wrong, that's a bug, not cleanup.
- **Style preferences** — don't impose style beyond project conventions. If the project uses tabs, don't switch to spaces.

## Related Skills

- **forge:dispatching-parallel-agents** — used for parallel analysis and fixing
- **forge:verification-before-completion** — verify fixes don't break anything
- **forge:forge-context** — load project conventions before analysis
