---
description: Update FORGE documentation after code changes - syncs docs/library/ and docs/map.json with current project state
---

# FORGE Sync

**Purpose:** Keep project documentation current after development work.

## Pre-Check: FORGE Documentation Exists?

```bash
ls docs/map.json 2>/dev/null
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
- Ask: "Proceed with manual update? (reads all project files)"
- If yes: scan all files and update all documentation
- If no: stop

Collect list of:
- Created files (A status)
- Modified files (M status)
- Deleted files (D status)

## Step 2: Launch Documentation Updater Subagent

Dispatch sonnet subagent to update documentation:

```
Task tool (general-purpose):
  model: sonnet
  description: "Update FORGE documentation for recent changes"
  prompt: |
    Update FORGE project documentation to reflect code changes.

    ## Project Documentation

    - docs/map.json — project structure and red zones
    - docs/library/[folders]/spec.json — file intents and dependencies
    - [folders]/README.md — human-readable descriptions in project folders
    - docs/state.json — current task and progress

    ## Changes to Document

    Created files:
    {list_created_files}

    Modified files:
    {list_modified_files}

    Deleted files:
    {list_deleted_files}

    ## Your Job

    For each CREATED file:
    1. Read the file to understand its purpose
    2. Add entry to docs/library/{folder}/spec.json:
       {
         "filename": {
           "intent": "What this file does and WHY",
           "inputs": ["parameters it receives"],
           "outputs": "What it returns",
           "depends_on": ["modules it imports"],
           "red_zone": false
         }
       }
    3. Update {folder}/README.md (in project folder) with simple description
    4. Add to docs/map.json directories count
    5. If new directory created, add to docs/map.json, create docs/library/ subfolder and README.md in project folder

    For each MODIFIED file:
    1. Read the file to check if behavior changed
    2. Update docs/library/{folder}/spec.json if intent/inputs/outputs changed
    3. Update {folder}/README.md if description needs updating
    4. Update depends_on if imports changed

    For each DELETED file:
    1. Remove from docs/library/{folder}/spec.json
    2. Remove from {folder}/README.md
    3. Update docs/map.json file counts
    4. If file was in red_zones, remove from there too

    ## Output Format

    spec.json: English, machine-readable, concise
    README.md: Russian (or user's language), simple language, no code

    ## Report Back

    When done, report:
    - Files documented (created/modified/deleted counts)
    - Directories updated in docs/library/
    - map.json updated: yes/no
```

Wait for subagent to complete.

## Step 3: Update state.json

After subagent completes, update `docs/state.json`:

Ask user about current work:

```
What are you working on now?

Examples:
- "Adding user authentication"
- "Fixing database connection bug"
- "Refactoring payment module"

Current task:
```

Wait for user input.

```
What's the progress on this task?

Examples:
- "2/5 steps complete"
- "Just starting"
- "Nearly done"

Progress:
```

Wait for user input.

```
What's still pending?

Examples:
- "Add tests for new feature"
- "Update documentation"
- "Deploy to production"

Pending items (one per line), or 'none':
```

Wait for user input. Collect pending list.

Update `docs/state.json`:

```json
{
  "current_task": "{from_user_input}",
  "progress": "{from_user_input}",
  "last_session": "{today's_date}",
  "last_session_summary": "{generate_from_git_commits_or_ask_user}",
  "pending": [
    "{items_from_user_input}"
  ],
  "recent_changes": [
    "{file} — {created|modified|deleted}",
    ...
  ]
}
```

## Step 4: Update history.log

Append one line to `docs/history.log`:

```
{date} | {current_task_summary} | {files_changed_count} files changed
```

Example:
```
2026-02-15 | Added user authentication | 8 files changed
```

## Step 5: Mark Sync Point

Save current commit as sync marker:

```bash
CURRENT_SHA=$(git rev-parse HEAD)
git config forge.last-sync-sha $CURRENT_SHA
```

Next sync will diff from this point.

## Step 6: Confirm Completion

Report to user:

```
✓ FORGE documentation synced

Updated:
- docs/library/ ({N} directories)
  - Created: {M} file entries
  - Modified: {K} file entries
  - Deleted: {L} file entries
- docs/map.json (updated counts)
- docs/state.json (current task: {task})
- docs/history.log (appended)

Documentation is current as of {commit_sha_short}.

Next sync will track changes from this point forward.
```

## Smart Updates

**Optimization:** Subagent only reads files that changed.
- Don't re-document unchanged files
- Only update spec.json entries (in docs/library/) for modified files
- Only update README.md (in project folders) if file descriptions changed

**Efficiency:** Using sonnet subagent keeps main session context clean.
- Main session: ~200 tokens for sync
- Subagent: handles all file reading and doc updates
- Total cost: minimal, fast execution

## Error Handling

**Git diff fails:**
- Fall back to manual mode (ask user what changed)
- Or offer to scan all files and regenerate

**Subagent fails:**
- Report error details
- Offer to retry
- Offer to do manual update step-by-step

**Concurrent changes:**
- If docs/ was modified outside this command, warn user
- Show conflicts
- Ask whether to proceed or abort
