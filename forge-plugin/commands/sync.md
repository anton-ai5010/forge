---
description: Update FORGE documentation after code changes - syncs docs/library/, docs/map.json, and project state with current codebase
---

# FORGE Sync

**Purpose:** Keep project documentation current after development work.

## Pre-Check: FORGE Documentation Exists?

```bash
ls docs/index.md 2>/dev/null
```

**If not exists:**
```
FORGE documentation not found.
Run `/forge:init` first to initialize project documentation.
```
Stop.

## Step 1: Determine Changes Since Last Sync

Check for sync marker:

```bash
git config --get forge.last-sync-sha 2>/dev/null
```

**If marker exists:**
```bash
LAST_SYNC=$(git config --get forge.last-sync-sha)
git diff --name-status $LAST_SYNC..HEAD
```

**If no marker (first sync):**
```bash
git diff --name-status HEAD~1..HEAD
```

**If not in git repository:**
- Warn: "Not a git repository - cannot determine changes automatically"
- Ask: "Proceed with manual update?"
- If yes: scan all files and update all documentation

Collect: Created (A), Modified (M), Deleted (D) files.

## Step 1.5: Check Connected Infrastructure

If project has server infrastructure — check its state.

**Determine infrastructure:**
- `docker-compose.yml` / `Dockerfile` — containers?
- `.env` / configs — server addresses, SSH, DBs?
- `docs/tech.md` — described infrastructure?
- MCP servers (Playwright etc.) — can check UI?

**If Docker (local or remote):**
```bash
docker compose ps 2>/dev/null
docker compose logs --tail=20 2>/dev/null

# Remote (if SSH available)
ssh server "cd /path && docker compose ps" 2>/dev/null
```

**If DB exists:** check schema matches code models, migrations applied.

**If web UI (and Playwright MCP available):** open main page, check not broken.

**If no infrastructure** — skip.

## Step 2: Launch Documentation Updater Subagent

Dispatch sonnet subagent to update documentation:

```
Agent tool (general-purpose):
  model: sonnet
  description: "Update FORGE documentation for recent changes"
  prompt: |
    Update FORGE project documentation to reflect code changes.

    ## Project Documentation

    - docs/map.json — project structure and red zones
    - docs/library/[folders]/spec.json — file intents and dependencies
    - [folders]/README.md — human-readable descriptions in project folders

    ## Changes to Document

    Created files: {list}
    Modified files: {list}
    Deleted files: {list}

    ## Your Job

    For each CREATED file:
    1. Read the file to understand its purpose
    2. Add entry to docs/library/{folder}/spec.json
    3. Update {folder}/README.md
    4. Update docs/map.json directory counts
    5. If new directory — create docs/library/ subfolder

    For each MODIFIED file:
    1. Read and check if behavior changed
    2. Update spec.json if intent/inputs/outputs changed
    3. Update README.md if description needs updating

    For each DELETED file:
    1. Remove from spec.json
    2. Remove from README.md
    3. Update map.json counts
    4. Remove from red_zones if applicable

    Output format:
    - spec.json: English, machine-readable
    - README.md: Russian, simple language, no code
```

Wait for subagent to complete.

## Step 3: Update index.md

Read current `docs/index.md`. Update:

- `Stage.Progress` — based on current state
- `Current.Modified` — files changed in this session
- `Last Session` — summary of this sync

Do NOT overwrite `Session (live)` section — that's maintained by session-awareness skill.

## Step 4: Update status.md

Ask or infer:
- Did anything new start working? → add to `## Working`
- Did anything break? → add to `## Broken`
- Any new blockers? → add to `## Blocked`

If tests were run, use results to auto-update.

## Step 5: Check for Dead Ends

```
Были ли подходы, которые не сработали?

Примеры:
- "Пробовал websockets — слишком сложно, polling лучше"
- "Мокал базу — ложные срабатывания"

Опишите (или 'нет'):
```

**If 'нет'** — skip.

**If user describes failure:**

```
К какой теме это относится? (auth, database, ui, api, ...)
```

```
Что делать вместо этого?
```

Create or append to `docs/dead-ends/<тема>.md`:

```markdown
## <краткое описание>
Date: {date}
Approach: {что пробовали}
Why failed: {почему не работает}
Lesson: {что делать вместо}
```

## Step 6: Check for Decisions

If significant technical decisions were made in this session:

```
Были ли важные технические решения?
(выбор библиотеки, архитектуры, подхода)

Опишите (или 'нет'):
```

If yes — append to `docs/decisions.md`.

## Step 7: Update journal.md

Append entry at the TOP of journal.md:

```markdown
## {date} — {summary}
Did: {what was done, 2-4 points}
Result: {outcome}
Next: {what's next}
Files: {key files changed}
```

If journal.md has >7 entries — move oldest to `docs/journal-archive/YYYY-MM.md`.

## Step 8: Mark Sync Point

```bash
CURRENT_SHA=$(git rev-parse HEAD)
git config forge.last-sync-sha $CURRENT_SHA
```

## Step 9: Confirm Completion

```
FORGE documentation synced

Updated:
- docs/library/ ({N} directories)
  - Created: {M} file entries
  - Modified: {K} file entries
  - Deleted: {L} file entries
- docs/map.json (updated counts)
- docs/index.md (stage, last session)
- docs/status.md ({updated|no changes})
- docs/dead-ends/ ({new entries|no changes})
- docs/decisions.md ({new entries|no changes})
- docs/journal.md (new entry added)

Infrastructure: {checked|no infrastructure|skipped}

Documentation is current as of {commit_sha_short}.
```
