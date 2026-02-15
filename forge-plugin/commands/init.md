---
description: Initialize FORGE project documentation - creates docs/ structure with map.json, conventions.json, state.json, and library/ mirror
---

# FORGE Initialization

**Purpose:** Create project documentation structure for context-aware development.

## Pre-Check: Documentation Already Exists?

```bash
ls docs/map.json 2>/dev/null
```

**If exists:**
```
FORGE documentation already exists at docs/

Regenerating will overwrite:
- docs/map.json
- docs/conventions.json
- docs/state.json
- docs/library/

Type 'regenerate' to confirm, or any other key to cancel.
```

Wait for user confirmation. If not confirmed, stop.

## Pre-Check: Clean Conflicting Configs

Check for conflicting documentation systems:

```bash
ls -d .kiro/ 2>/dev/null
```

**If .kiro/ exists:**
```
⚠️  Found .kiro/ directory (Gotolab/Kiro documentation system)

FORGE and Kiro may conflict — both manage project documentation.

Recommendation: Keep only one system.

Remove .kiro/? (yes/no)
```

Wait for user input:
- If "yes" — remove .kiro/ directory
- If "no" — proceed with warning: "Keeping both .kiro/ and docs/. Be aware they may conflict."

## Step 1: Scan Project Structure

Scan the project to understand its layout:

```bash
# Get all directories (excluding common ignore patterns)
find . -type d \
  ! -path "*/node_modules/*" \
  ! -path "*/.git/*" \
  ! -path "*/dist/*" \
  ! -path "*/build/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/venv/*" \
  -print

# Count files per directory
find . -type f \
  ! -path "*/node_modules/*" \
  ! -path "*/.git/*" \
  ! -path "*/dist/*" \
  ! -path "*/build/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/venv/*" \
  -printf "%h\n" | sort | uniq -c
```

Analyze structure to identify main source directories.

## Step 2: Identify Red Zones

Ask user which files should be marked as red zones:

```
I've scanned your project. Which files are critical and should be marked as red zones?

Red zones are files that:
- Production systems depend on (exact behavior matters)
- Are complex and fragile (high risk of breaking)
- Require careful review before modification

Examples: core algorithms, production configs, data models

List file paths (one per line), or 'none' if no red zones yet:
```

Wait for user input. Collect list of red zone files.

## Step 3: Identify Language and Conventions

Ask user about project conventions:

```
What language/framework is this project using?

Examples: python, typescript, rust, go, java
```

Wait for language input.

```
What naming conventions does this project follow?

Common patterns:
1. snake_case files, PascalCase classes (Python)
2. camelCase files, PascalCase classes (TypeScript)
3. snake_case everything (Rust)
4. Custom conventions

Describe your project's conventions, or 'default' for language defaults:
```

Wait for conventions input.

## Step 4: Create Directory Structure

Create FORGE documentation structure:

```bash
# Create main docs directory
mkdir -p docs/plans
mkdir -p docs/library

# Create library subdirectories mirroring project structure
# For each source directory found in Step 1
```

For each source directory (e.g., `indicators/`, `strategies/`, `utils/`):
```bash
mkdir -p docs/library/{directory_name}
```

## Step 5: Generate map.json

Create `docs/map.json`:

```json
{
  "project": "{project_name_from_git_or_folder}",
  "directories": {
    "{dir1}/": { "files": {count}, "red_zone_files": {count} },
    "{dir2}/": { "files": {count}, "red_zone_files": {count} }
  },
  "red_zones": [
    "{file_paths_from_step_2}"
  ]
}
```

Count files accurately for each directory. Count red_zone_files per directory.

## Step 6: Generate conventions.json

Create `docs/conventions.json`:

```json
{
  "language": "{from_step_3}",
  "naming": {
    "files": "{based_on_language_or_user_input}",
    "classes": "{based_on_language_or_user_input}",
    "functions": "{based_on_language_or_user_input}",
    "constants": "{based_on_language_or_user_input}"
  },
  "structure": {
    "{dir1}": "{describe purpose based on contents}",
    "{dir2}": "{describe purpose based on contents}"
  },
  "patterns": {},
  "decisions": {}
}
```

Fill in naming conventions based on language defaults or user input.
Analyze directory contents to infer structure descriptions.

## Step 7: Generate state.json

Create `docs/state.json`:

```json
{
  "current_task": "FORGE initialization complete",
  "progress": "Ready for development",
  "last_session": "{today's_date}",
  "last_session_summary": "Initialized FORGE documentation structure",
  "pending": [],
  "recent_changes": [
    "docs/map.json — created",
    "docs/conventions.json — created",
    "docs/state.json — created"
  ]
}
```

Use current date for last_session.

## Step 8: Create history.log

Create `docs/history.log`:

```
{date} | FORGE initialization | Created project documentation structure
```

Append-only log file for session history.

## Step 9: Generate library/ Documentation

For each source directory, create two files:

**{directory}/README.md** (in the project folder itself):
```markdown
# {Directory Name}

{Simple description of what this directory contains}

{List files with brief descriptions}
```

Write in simple language, no code. For human readability. This file lives in the project folder so developers see it when browsing code.

**docs/library/{directory}/spec.json:**
```json
{
  "purpose": "{What this directory is for}",
  "files": {
    "{filename}": {
      "intent": "{What this file does and WHY it exists}",
      "inputs": ["{parameters or data it receives}"],
      "outputs": "{What it returns or produces}",
      "depends_on": ["{modules or files it imports}"],
      "red_zone": {true_if_in_red_zones_list}
    }
  }
}
```

For each file in directory:
- Read file to understand its purpose
- Extract function signatures or class definitions for inputs/outputs
- Identify imports for depends_on
- Check if file is in red zones list

Write spec.json in English, machine-readable format (in docs/library/{directory}/).
Write README.md in Russian (or user's language), simple format (in {directory}/ itself).

## Step 10: Configure CLAUDE.md

Ensure CLAUDE.md has FORGE context at the beginning:

```bash
# Check if CLAUDE.md exists
ls CLAUDE.md 2>/dev/null
```

**FORGE context block to add:**
```markdown
# FORGE Project Context

This project uses FORGE documentation system. Before any work:

1. Read `docs/map.json` — project structure and red zones
2. Read `docs/conventions.json` — project rules
3. Read `docs/state.json` — current state and pending tasks
4. Read ALL `docs/library/*/spec.json` — complete project knowledge

DO NOT scan the filesystem, read source code, or explore .kiro/ before reading docs/library/. Everything you need to know about the project is in docs/library/.

After completing any task, run `/forge:sync` to update documentation.

Available commands: /forge:brainstorm, /forge:write-plan, /forge:execute-plan, /forge:sync, /forge:discover
```

**If CLAUDE.md does not exist:**
- Create CLAUDE.md with the FORGE context block

**If CLAUDE.md exists:**
- Read current contents
- Check if it already contains "FORGE Project Context"
- If yes — skip (no duplication)
- If no — prepend FORGE context block BEFORE existing content

Example result when CLAUDE.md exists:
```markdown
# FORGE Project Context

This project uses FORGE documentation system. Before any work:
...

---

{existing CLAUDE.md content here}
```

## Step 11: Confirm Completion

Report to user:

```
✓ FORGE documentation initialized

Created:
- docs/map.json ({N} directories, {M} red zones)
- docs/conventions.json ({language})
- docs/state.json
- docs/history.log
- docs/library/ ({N} directories documented)

Next steps:
- Run `/forge:sync` after making changes to keep docs current
- Check docs/map.json to verify red zones are correct
- Update docs/conventions.json with project-specific patterns

Your project now has context documentation. Claude can understand your project structure without reading all source files (~2k tokens instead of ~40k+).
```

## Idempotency

If docs/ already exists, require explicit confirmation before regenerating.
Regeneration overwrites all files - warn user about losing manual edits.

## Error Handling

**No git repository:**
- Proceed anyway, use folder name as project name

**Empty project:**
- Create minimal docs structure
- Warn: "Project appears empty - create some code first"

**Permission errors:**
- Report which files couldn't be created
- Suggest checking permissions on project directory
