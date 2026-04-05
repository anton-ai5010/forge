---
name: forge-context
description: Use at session start when project has docs/index.md — loads project context, stage, and current state for context-aware development
---

# FORGE Project Context

## Overview

Load project context from docs/index.md instead of reading source code.

**Core principle:** ~400 tokens of index.md > 40k tokens of source reading.

**Use when:** Project has `docs/index.md` (created by `/forge:init`).

## When to Use

**Always check at session start.** If docs/index.md exists, load context before doing anything else.

If docs/index.md does not exist, check for legacy docs/map.json. If neither exists, suggest `/forge:init`.

## The Process

### Step 1: Read index.md (ALWAYS FIRST)

```bash
cat docs/index.md
```

This single file tells you:
- **Project goal** — what we're building
- **Stage** — how far along, what phase, any blockers
- **Current task** — what we're working on RIGHT NOW
- **Session state** — what was done, what's next (live-updated)
- **Last session** — continuity from previous work
- **Docs pointers** — where to find details

**After reading index.md you know enough to start working.**

### Step 2: Read detail files ON DEMAND

Only read what's relevant to the current request:

| Need | Read |
|---|---|
| Project structure, red zones | `docs/map.json` |
| Coding patterns, naming rules | `docs/conventions.json` |
| What works / what's broken | `docs/status.md` |
| Failed approaches for topic X | `docs/dead-ends/X.md` (check `ls docs/dead-ends/` first) |
| Why we chose approach Y | `docs/decisions.md` |
| What happened last sessions | `docs/journal.md` (top entries) |
| File-level details | `docs/library/[folder]/spec.json` |

**Do NOT read all files at once.** Follow the pointers from index.md.

### Step 3: Check dead-ends (if working on a specific topic)

```bash
ls docs/dead-ends/ 2>/dev/null
```

If a file matches your current topic — read it BEFORE starting work.
This prevents repeating failed approaches.

### Step 4: Context Loaded — Ready to Work

You now have:
- Project goal and stage (from index.md)
- Current task and session state (from index.md)
- Dead ends for current topic (from dead-ends/)
- Whatever detail files were relevant

**Do NOT read source files yet.** Read `docs/library/[folder]/spec.json` first.
Only read source when implementing or modifying.

**If Serena MCP is available** — use `find_symbol` / `get_symbols_overview` for navigating code instead of reading entire files.

## Разведка окружения

После загрузки контекста — проверь доступные инструменты:

**MCP серверы:**
- **Serena** — символьный анализ кода вместо grep
- **Playwright** — проверка UI, скриншоты
- **Context7** — актуальная документация библиотек
- Другие — оцени пользу для текущей задачи

**Плагины/скиллы** Claude Code помимо Forge — задействуй где уместно

**Инфраструктура:** Docker, SSH к серверам, доступ к БД

## Token Budget

| What | Tokens | When |
|------|--------|------|
| index.md | ~400 | Always |
| dead-ends/<topic>.md | ~100-300 | When working on that topic |
| status.md | ~200 | When asking about project state |
| decisions.md | ~300 | When making architectural choices |
| journal.md (top entry) | ~150 | When need session continuity |
| map.json | ~300 | When need structure overview |
| conventions.json | ~500 | When writing new code |
| **Typical session** | **400-800** | **index.md + 1-2 detail files** |

## docs/ Structure

```
docs/
├── index.md              # Entry point — goal, stage, session state (LIVE)
├── status.md             # What works / broken / blocked
├── decisions.md          # Key decisions and WHY
├── dead-ends/            # Failed approaches BY TOPIC
│   └── <topic>.md        # One file per domain
├── journal.md            # Last 5-7 sessions with details
├── journal-archive/      # Older sessions (never auto-read)
├── map.json              # Project structure, red zones
├── conventions.json      # Coding rules, patterns
├── plans/                # Implementation plans
└── library/              # File-level specs
    └── */spec.json
```

## After Loading Context

1. Acknowledge current task and stage from index.md
2. Check if work relates to red zones from map.json
3. Check dead-ends for current topic — avoid failed approaches
4. Follow patterns from conventions.json when writing code
5. Check available environment (MCP servers, plugins, infrastructure)
6. Proceed with relevant skill

Example acknowledgment:
```
Project: trading-bot (Python) — Phase: MVP, 7/12 tasks
Current: Adding MACD indicator
Last session: Wrote calculation, tests passing, need backtest

Ready to continue.
```

## Integration

**Called by:** using-forge skill (at session start if docs/index.md exists)

**Works with:** session-awareness skill (maintains index.md live during work)

**Before using:** Project must have been initialized with `/forge:init`

## Remember

- index.md is the SINGLE entry point — always start here
- Detail files are read ON DEMAND, not all at once
- dead-ends/ is split by topic — `ls` first, read only relevant file
- session-awareness keeps index.md alive during work
- If context compresses — re-read index.md to restore
