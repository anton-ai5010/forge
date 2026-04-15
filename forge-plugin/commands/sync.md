---
description: Update FORGE documentation after code changes - syncs .forge/ YAML files with current codebase state
---

# FORGE Sync

**Purpose:** Keep project documentation current after development work.

## Pre-Check: FORGE Documentation Exists?

```bash
ls .forge/index.yml .forge/index.md 2>/dev/null
```

**If neither exists:**
```
FORGE documentation not found. Run `/forge:init` first.
```
Stop.

**Detect format:** If `.forge/index.yml` exists → v3 (YAML). Else → v2 (legacy MD/JSON).
Use detected format for all updates below.

## Step 1: Determine Changes Since Last Sync

```bash
git config --get forge.last-sync-sha 2>/dev/null
```

**If marker exists:**
```bash
LAST_SYNC=$(git config --get forge.last-sync-sha)
git diff --name-status $LAST_SYNC..HEAD
```

**If no marker:**
```bash
git diff --name-status HEAD~1..HEAD
```

**If not in git:** Warn and ask to proceed with manual update.

Collect: Created (A), Modified (M), Deleted (D) files.

## Step 1.5: Check and Update Infrastructure

If `.forge/infrastructure.yml` exists — verify and update it.

```bash
# Local Docker
docker compose ps 2>/dev/null

# Remote Docker (if remote.server defined in infrastructure.yml)
ssh server "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null

# DB health (if databases defined)
# Try connecting, check migrations status

# Remote services
ssh server "systemctl is-active app.service" 2>/dev/null
```

Update `.forge/infrastructure.yml`:
- Container statuses (running/stopped/restarting)
- New containers or removed ones
- DB table count changes
- Migration status (pending/applied)

If Playwright MCP available — check main page is responding.

If no `.forge/infrastructure.yml` — skip.

## Step 1.7: Enforce Project Structure

If `.forge/structure.md` exists — dispatch structure enforcer agent:

```
Agent tool (general-purpose):
  model: sonnet
  description: "Enforce project structure conventions"
  prompt: |
    You are the FORGE Structure Enforcer.
    Read .forge/structure.md and .forge/conventions.yml (or .json for legacy).
    Compare expected vs actual structure.
    Focus on recently changed files: {Created list}, {Modified list}
    Move misplaced files, update ALL imports.
    DO NOT move: root configs, dotfiles, .forge/, generated dirs.
    Report: Moved, Created dirs, Warnings.
```

If agent moved files — add to changed files list.

## Step 1.9: Update Code Knowledge Graph (if exists)

If graphify is installed and `.forge/graph.json` exists — update the graph incrementally (no LLM needed, fast):

```bash
if which graphify &>/dev/null && [ -f ".forge/graph.json" ]; then
  graphify update . 2>&1 | tail -3
  cp graphify-out/graph.json .forge/graph.json 2>/dev/null
fi
```

If graphify not installed or no graph — skip silently.

## Step 2: Launch Documentation Updater Subagent

```
Agent tool (general-purpose):
  model: sonnet
  description: "Update FORGE documentation for recent changes"
  prompt: |
    Update FORGE project documentation for code changes.

    Format: YAML (if .forge/index.yml exists) or JSON (if legacy .forge/index.md)

    Docs to update:
    - .forge/map.yml (or map.json) — structure, red zones, directory counts
    - .forge/library/[folders]/spec.yml (or spec.json) — file specs
    - [folders]/README.md — human-readable descriptions

    Changes:
    Created: {list}
    Modified: {list}
    Deleted: {list}

    For CREATED files: read → add to spec.yml → update README.md → update map.yml
    For MODIFIED files: check behavior change → update if needed
    For DELETED files: remove from spec.yml, README.md, map.yml

    spec.yml format: English, machine-readable YAML
    README.md format: Russian, simple language
```

Wait for subagent.

## Step 3: Update index.yml (or index.md)

**For v3 (YAML):** Update fields:
- `stage`, `progress` — based on current state
- `now.task` — current work description
- `now.branch` — current git branch
- `last_session` — summary of this sync

Do NOT overwrite `session:` — that's maintained by session-awareness skill.

**For v2 (legacy):** Update Stage, Current, Last Session sections in index.md.

## Step 4: Update status.yml (or status.md)

Ask or infer:
- Anything new working? → add to `working:`
- Anything broke? → add to `broken:`
- New blockers? → add to `blocked:`

If tests were run, use results.

## Step 5: Check for Dead Ends

```
Были ли подходы, которые не сработали?
(или 'нет')
```

**If yes:**

Add entry to `.forge/dead-ends.yml`:
```yaml
  - id: {slug}
    date: {date}
    summary: "{что не сработало и почему}"
    tags: [{relevant, keywords}]
    detail: null  # или путь к L2 если нужен полный анализ
```

Create L2 file `.forge/dead-ends/{id}.md` only if summary insufficient.

## Step 6: Check for Decisions

```
Были ли важные технические решения?
(или 'нет')
```

If yes — add entry to `.forge/decisions.yml`:
```yaml
  - id: {slug}
    date: {date}
    decision: "{что решили}"
    why: "{почему}"
    tags: [{keywords}]
```

## Step 7: Update journal.yml (or journal.md)

Add entry at TOP of `entries:`:

```yaml
  - date: {date}
    summary: "{что делали}"
    result: "{итог}"
    next: "{что дальше}"
    files: [{key files}]
```

If entries >7 — remove oldest.

## Step 7.5: Extract Learnings (Compound)

Reflect on this session's work and extract actionable lessons.

Ask:
```
Какие уроки из этой сессии стоит запомнить?

Примеры:
- "pytest fixtures лучше чем setUp/tearDown для нашего стека"
- "API v2 не поддерживает batch — нужны отдельные запросы"
- "Docker build с --no-cache решает проблему кеша слоёв"

Опишите 1-3 урока (или 'нет'):
```

**If 'нет'** — skip.

**If user provides lessons OR you can extract non-obvious ones from dead-ends/errors:**

If `.forge/learnings.yml` doesn't exist — create it:
```yaml
# Уроки проекта — накапливаются через /forge:sync
# Загружаются при brainstorming для informed decisions
entries: []
```

Add entries to `.forge/learnings.yml`:
```yaml
  - id: {slug}
    date: {date}
    summary: "{урок — одна строка}"
    tags: [{relevant, keywords}]
    source: "{из какой задачи или ошибки}"
```

## Step 8: Mark Sync Point

```bash
git config forge.last-sync-sha $(git rev-parse HEAD)
```

## Step 9: Confirm

```
FORGE documentation synced

Updated:
- .forge/library/ ({N} directories)
  Created: {M} | Modified: {K} | Deleted: {L}
- .forge/map.yml (counts updated)
- .forge/index.yml (stage, last session)
- .forge/status.yml ({updated|no changes})
- .forge/dead-ends.yml ({new entries|no changes})
- .forge/decisions.yml ({new entries|no changes})
- .forge/journal.yml (new entry)
- .forge/learnings.yml ({new entries|no changes|created})

Graph: {updated N nodes|no graphify|no graph}
Structure: {N files moved|no violations|skipped}
Infrastructure: {checked|skipped}
  Docker: {N containers: M running, K stopped|no docker}
  Server: {services checked|no remote server}
  DB: {tables: N, migrations: applied/pending|no DB}

Current as of {commit_sha_short}.
```
