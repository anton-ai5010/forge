---
description: Analyze project code quality and produce a cleanup report — finds dead code, naming issues, complexity, duplication, and convention violations using parallel agents
---

# FORGE Code Cleanup

**Purpose:** Systematic code quality analysis across the entire project with parallel agents.

**When to run:** When code feels messy, after rapid prototyping, before release, to pay down tech debt.

## Pre-Check: Invoke Skill

```
Invoke skill: forge:code-cleanup
Follow the skill instructions exactly.
```

The skill handles:
1. Loading project context (FORGE docs or scanning)
2. Splitting project into independent areas
3. Dispatching parallel analysis agents
4. Compiling the report
5. Asking user what to fix

## Quick Usage

```
/forge:cleanup

Проверить качество кода во всём проекте.
Особое внимание: именование, дублирование, мёртвый код.
```

```
/forge:cleanup

Проанализировать только директорию src/parsers/ —
там накопился технический долг после быстрого прототипирования.
```

## What You Get

A structured report with:
- Summary (files analyzed, issues by severity)
- High/Medium/Low severity tables (file, line, category, issue, fix)
- Patterns noticed (systemic problems)

No changes are made until you approve.
