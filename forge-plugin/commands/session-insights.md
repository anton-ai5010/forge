---
description: Analyze past Claude Code conversations for the current project — extract pain points, recurring themes, unresolved problems, idea evolution, and save insights to memory
---

# FORGE Session Insights

**Purpose:** Deep analysis of all past conversations with Claude Code in this project.

**When to run:** When you want to understand patterns in how you work with Claude, find unresolved problems, or populate memory with insights from past sessions.

## Pre-Check: Invoke Skill

```
Invoke skill: forge:session-insights
Follow the skill instructions exactly.
```

The skill handles:
1. Extracting user messages from JSONL conversation logs
2. Dispatching 4 parallel agents for analysis
3. Compiling a markdown report
4. Saving insights to project memory

## Quick Usage

```
/forge:session-insights

Проанализируй все мои диалоги в этом проекте.
```

## What You Get

A report with 6 sections:
- Pain points and frustrations
- Recurring themes
- Unresolved problems
- Idea evolution
- Communication style
- User profile

Plus: memory files auto-saved for future sessions.
