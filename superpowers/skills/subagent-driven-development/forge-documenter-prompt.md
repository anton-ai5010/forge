# Documentation Updater Prompt Template

Use this template when dispatching the forge-documenter subagent after task completion.

**Purpose:** Update FORGE project documentation to reflect code changes from completed task.

**When to dispatch:** After both spec compliance review AND code quality review pass.

```
Task tool (general-purpose):
  model: sonnet
  description: "Update documentation for Task N changes"
  prompt: |
    You are updating FORGE project documentation after code changes.

    ## What the Implementer Changed

    [FROM IMPLEMENTER'S REPORT]

    Files created:
    {list_created_files_with_paths}

    Files modified:
    {list_modified_files_with_paths}

    Files deleted:
    {list_deleted_files_with_paths}

    What they claim they built:
    {implementer_summary}

    ## Verify with Git Diff

    **CRITICAL:** Do not trust the implementer's report. Verify everything.

    Run this to see actual changes:
    ```bash
    git diff {BASE_COMMIT}..{HEAD_COMMIT}
    ```

    Compare report to actual diff. Implementer may have:
    - Missed files they changed
    - Claimed changes they didn't make
    - Mischaracterized what changed

    Trust the diff, not the report.

    ## Affected Directories

    Based on changed files, you'll update documentation for:
    {list_affected_folders}

    ## Your Job

    Update FORGE documentation for each changed file:

    ### For CREATED Files

    1. Read the new file to understand:
       - What it does and WHY (intent)
       - Function signatures (inputs)
       - What it returns (outputs)
       - What it imports (depends_on)

    2. Add entry to `docs/library/{folder}/spec.json`:
       ```json
       {
         "filename.ext": {
           "intent": "What this file does and WHY it exists",
           "inputs": ["param: type", "param2: type"],
           "outputs": "What it returns or produces",
           "depends_on": ["module1", "module2"],
           "red_zone": false
         }
       }
       ```

    3. Add line to `docs/library/{folder}/README.md`:
       ```markdown
       - **filename.ext** — простое объяснение что делает этот файл
       ```

    4. Update `docs/map.json`:
       - Increment file count for directory
       - If new directory, add new entry

    ### For MODIFIED Files

    1. Read the file to check what actually changed:
       - Did behavior change? (update intent)
       - Did signature change? (update inputs/outputs)
       - Did imports change? (update depends_on)

    2. Update `docs/library/{folder}/spec.json` ONLY if:
       - Intent changed (does different thing)
       - Inputs/outputs changed (different interface)
       - Dependencies changed (imports added/removed)

       If only implementation changed (same interface): do NOT update spec.json

    3. Update `docs/library/{folder}/README.md` ONLY if:
       - File's purpose changed
       - User-facing behavior changed

    4. map.json: no changes for modified files

    ### For DELETED Files

    1. Remove entry from `docs/library/{folder}/spec.json`

    2. Remove line from `docs/library/{folder}/README.md`

    3. Update `docs/map.json`:
       - Decrement file count
       - If file was in red_zones, remove it
       - If directory now empty, remove directory entry

    ## Output Formats

    **spec.json:**
    - English language
    - Machine-readable
    - Concise technical descriptions
    - Exact function signatures

    **README.md:**
    - Russian language (or user's preferred language)
    - Human-readable
    - Simple explanations
    - No code, no jargon

    ## When Done

    Report back:

    ```
    Documentation updated for Task N:

    Created:
    - {folder}/{file} (added to spec.json and README.md)

    Modified:
    - {folder}/{file} (updated spec.json: {what_changed})

    Deleted:
    - {folder}/{file} (removed from spec.json, README.md, map.json)

    Summary:
    - Files documented: {N} created, {M} modified, {K} deleted
    - Directories updated: {list_folders}
    - map.json updated: {yes/no}
    ```

    ## Critical Rules

    **DO:**
    - Verify implementer's report against git diff
    - Read actual code before documenting
    - Extract exact signatures and imports
    - Update only what actually changed

    **DON'T:**
    - Trust implementer's report blindly
    - Document files you didn't read
    - Add speculative information
    - Update unchanged files
    - Change red_zone status
```

## Example Usage

```markdown
From controller session, after both reviews pass:

Task tool (general-purpose):
  model: sonnet
  description: "Update documentation for Task 3 changes"
  prompt: |
    You are updating FORGE project documentation after code changes.

    ## What the Implementer Changed

    Files created:
    - indicators/bollinger.py
    - tests/test_bollinger.py

    Files modified:
    - indicators/__init__.py

    Files deleted:
    - none

    What they claim they built:
    "Added Bollinger Bands indicator with standard deviation bands"

    ## Verify with Git Diff

    Run this to see actual changes:
    ```bash
    git diff a4f7b2c..HEAD
    ```

    ## Affected Directories

    - indicators/
    - tests/

    ## Your Job

    [... full template instructions ...]
```
