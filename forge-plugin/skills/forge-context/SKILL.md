---
name: forge-context
description: Use at session start when project has docs/index.yml — loads project context using L0/L1/L2 tiered system for minimal token usage
---

# FORGE Project Context (L0/L1/L2)

## Overview

Load project context from docs/index.yml — NOT from source code.

**Core principle:** 200 tokens of index.yml > 40k tokens of source reading.

**L0** (~200 tok) is auto-injected every prompt via hook. You already have it.
**L1** (~500-2K tok) — load by matching catalog tags to current task.
**L2** (unlimited) — load only when L1 summary is insufficient.

## When to Use

At session start if docs/index.yml (or legacy docs/index.md) exists.

## The Process

### Step 1: L0 is Already Loaded

The hook auto-injects docs/index.yml into every prompt. You already see:
- Project goal, stage, stack
- Current task and branch
- **catalog** — map of all L1 resources with tags
- Session state (live)

**Do NOT read index.yml manually — it's already in your context.**

### Step 2: Route to L1 by Tags

Match the user's request against `catalog[].tags`:

| User wants | Tags match | Load L1 file |
|---|---|---|
| Create/find files | structure, files, dirs | `docs/map.yml` |
| Write new code | naming, format, rules | `docs/conventions.yml` |
| Check project health | working, broken, blocked | `docs/status.yml` |
| Understand past choices | why, architecture | `docs/decisions.yml` |
| Avoid failed approaches | failed, tried, avoid | `docs/dead-ends.yml` |
| Resume previous work | history, last-session | `docs/journal.yml` |
| Find right skill | skill, workflow | `docs/skills-catalog.yml` |

**Load ONLY files whose tags match.** Typical: 1-2 L1 files per task.

### Step 3: L2 Only If Needed

L1 files contain one-liner summaries. If a summary answers the question — stop.

Load L2 (full document) only when:
- L1 summary is too brief for the specific case
- Need full dead-end analysis or decision rationale
- Need file-level specs from `docs/library/*/spec.yml`

### Step 4: Context Loaded — Ready to Work

After L0 + relevant L1, you have enough to start. Example:

```
Project: trading-bot (Python) — active-dev, 7/12 tasks
Task: Adding MACD indicator
Dead-ends: websockets (use polling instead)
Ready.
```

## Token Budget

| Level | Tokens | When |
|---|---|---|
| L0 (index.yml) | ~200 | Every prompt (auto) |
| L1 (one file) | ~200-500 | Per tag match |
| L2 (full doc) | ~300-2000 | Only if L1 insufficient |
| **Typical task** | **400-700** | **L0 + 1-2 L1 files** |

## Legacy Support

If project has `docs/index.md` (not .yml) — this is FORGE v2.
Read index.md as before (~400 tok). L1/L2 routing not available.
Suggest: "Run `/forge:init` to upgrade to L0/L1/L2 format."

## Environment Check

After loading context, check available tools:
- **Serena MCP** — symbolic code analysis (prefer over grep)
- **Playwright MCP** — UI verification
- **Context7 MCP** — library documentation
- **Docker/SSH** — infrastructure access

## After Loading

1. Acknowledge task and stage from L0
2. Check dead-ends tags if working on specific topic
3. Follow conventions from L1 when writing code
4. Proceed with relevant skill

## Integration

**Called by:** using-forge skill (at session start)
**Works with:** session-awareness skill (maintains index.yml live)
**Before using:** Project must be initialized with `/forge:init`
