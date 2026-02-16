---
description: Validate code against implementation plan and documentation - finds discrepancies between what should be implemented, what exists, and what's documented
---

# FORGE Validate

**Purpose:** Verify project state matches plan and documentation.

**When to run:** After implementing features, before merging, when something feels off.

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

## Step 1: Load Context

Read project documentation:

```bash
cat docs/map.json
cat docs/state.json
```

For each directory in `docs/library/`:

```bash
cat docs/library/*/spec.json
```

Store in memory:
- Expected file structure (from map.json)
- Expected file purposes (from spec.json files)
- Current task status (from state.json)

## Step 2: Find Active Plan

Check for implementation plans:

```bash
ls -t docs/plans/*.md 2>/dev/null | head -1
```

**If no plan exists:**
```
No implementation plan found. Skipping plan validation.

Proceeding to documentation validation only.
```

Continue to Step 4.

**If plan exists:**

Read the most recent plan file.

Extract from plan:
- Task numbers and descriptions
- Files mentioned in each task (creates, modifies, reads)
- Expected implementations (functions, classes, imports)
- Test requirements
- Documentation requirements

## Step 3: Validate Code vs Plan

For each task in the plan, verify implementation:

### Task Status Check

For each task, determine status:

**✅ Implemented:**
- All mentioned files exist
- Expected content present (functions, classes match)
- Tests exist and pass
- Matches specification

**⚠️ Partial:**
- Files exist but content differs from plan
- Some expected elements missing
- Tests missing or failing
- Configuration values differ

**❌ Missing:**
- Files don't exist
- No implementation found
- Not started

### Verification Commands

For each file mentioned in plan:

```bash
# Check file exists
test -f {file_path} && echo "✓ exists" || echo "✗ missing"

# Check for expected content
grep -q "{expected_class_or_function}" {file_path} && echo "✓ found" || echo "⚠ not found"
```

For tests:

```bash
# Find test file
find . -name "test_*.py" -o -name "*_test.py" | grep {feature_name}

# Count test functions
grep -c "def test_" {test_file}
```

### Plan Compliance Report

Generate report in this format:

```
Plan Validation
═══════════════

Plan: docs/plans/2026-02-15-polymarket-smart-money.md
Tasks: 13 total

✅ Task 1: SmartMoneyStore implementation
   File: src/database/smart_money_store.py
   Expected: 4 tables (wallets, positions, outcomes, wallet_stats)
   Found: 4 tables present
   Tests: 8/8 passing

✅ Task 2: PolymarketParser
   File: src/parsers/polymarket_parser.py
   Expected: parse_wallet_data, extract_positions
   Found: Both methods present
   Tests: 5/5 passing

⚠️ Task 6: Pipeline integration
   File: src/analysis/analysis_service.py
   Expected: smart_money weight = 0.3
   Found: weight = 0.2 (MISMATCH)
   Action: Update weight to match plan

❌ Task 13: Documentation sync
   Expected: docs/library/ updated with new files
   Found: spec.json missing entries for:
     - src/database/smart_money_store.py
     - src/parsers/polymarket_parser.py
   Action: Run /forge:sync

Summary:
────────
✅ Implemented: 10/13 tasks
⚠️ Partial: 2/13 tasks
❌ Missing: 1/13 task

Plan compliance: 77% (10 fully implemented)
```

If all tasks ✅:
```
✓ All plan tasks implemented correctly
```

## Step 4: Validate Docs vs Code

Compare documentation against actual codebase.

### For Each docs/library/[folder]/spec.json

Read spec.json to get expected files and their purposes.

Scan actual directory on disk:

```bash
# Get files documented in spec
jq -r '.files | keys[]' docs/library/{folder}/spec.json

# Get actual files in directory
find {folder} -type f -name "*.py" -o -name "*.js" -o -name "*.ts"
```

Compare:

**Files in spec but NOT on disk:**
```
❌ Documented but missing: {folder}/{file}
   Action: Remove from spec.json or restore file
```

**Files on disk but NOT in spec:**
```
⚠️ Undocumented: {folder}/{file}
   Action: Run /forge:sync to document
```

**Files in both — validate metadata:**

For each file in spec, read actual file and check:

```bash
# Extract imports from actual file
grep "^import\|^from" {file_path}
```

Compare against `depends_on` in spec.json:

```
⚠️ Import mismatch: {folder}/{file}
   Spec says: ["pandas", "numpy"]
   Found imports: ["pandas", "polars", "numpy"]
   Missing in spec: polars
   Action: Run /forge:sync to update
```

### Documentation Coverage Report

```
Documentation Validation
════════════════════════

Scanning 8 directories in docs/library/

✅ analyzers/ (9 files)
   Spec: 9 files documented
   Disk: 9 files present
   Status: All files match

⚠️ parsers/ (10 files)
   Spec: 9 files documented
   Disk: 10 files present
   Undocumented:
     - parsers/polymarket_parser.py (NEW)
   Action: Run /forge:sync

❌ ml/ (12 files)
   Spec: 11 files documented
   Disk: 12 files present
   Undocumented:
     - ml/ensemble_model.py (NEW)
   Import mismatches:
     - ml/predictor.py
       Spec: ["torch", "numpy"]
       Found: ["torch", "numpy", "sklearn"]
   Action: Run /forge:sync

✅ database/ (5 files)
   Spec: 5 files documented
   Disk: 5 files present
   Status: All files match

Summary:
────────
✅ Fully documented: 6/8 directories
⚠️ Missing entries: 2 files
⚠️ Import mismatches: 1 file

Documentation coverage: 95% (57/59 files)
```

## Step 5: Validate map.json Accuracy

Check if file counts in map.json match reality:

For each directory in map.json:

```bash
# Expected count from map.json
jq -r '.directories["{folder}"].files' docs/map.json

# Actual count on disk
find {folder} -type f | wc -l
```

Compare:

```
⚠️ Count mismatch: indicators/
   map.json: 5 files
   Actual: 6 files
   Action: Run /forge:sync
```

For red zones:

```bash
# Expected red zones from map.json
jq -r '.red_zones[]' docs/map.json

# Check each exists
for file in {red_zones}; do
  test -f "$file" && echo "✓ $file" || echo "✗ $file MISSING"
done
```

```
❌ Red zone file missing: strategies/production_v1.py
   Listed in map.json but doesn't exist
   Action: Remove from red_zones or restore file
```

## Step 6: Summary Report

Combine all findings into final report:

```
FORGE Validation Summary
════════════════════════

Validated: {date} {time}
Project: {project_name}

Plan Compliance
───────────────
Plan: docs/plans/{latest_plan}
✅ Implemented: {N}/{total} tasks
⚠️ Partial: {M} tasks
❌ Missing: {K} tasks

Discrepancies:
{list each ⚠️ and ❌ item with specific details}

Documentation Coverage
──────────────────────
✅ Documented: {N}/{total} files
⚠️ Undocumented: {M} files
⚠️ Import mismatches: {K} files

Discrepancies:
{list each undocumented file and mismatch}

map.json Accuracy
─────────────────
✅ File counts: {N}/{total} directories match
⚠️ Count mismatches: {M} directories
❌ Missing red zones: {K} files

Discrepancies:
{list each mismatch}

═══════════════════════════════════════
Overall Status: {✅ ALL CLEAR | ⚠️ ISSUES FOUND | ❌ CRITICAL GAPS}
═══════════════════════════════════════

{if ✅}:
✓ All clear. Code matches plan and documentation.

{if ⚠️ or ❌}:
Actions Needed:
1. {action 1}
2. {action 2}
...

Next Steps:
- Fix discrepancies manually OR
- Run /forge:sync to update documentation OR
- Review plan and adjust implementation
```

## When to Use

**Trigger situations:**
- Before merging feature branch
- After implementing from plan
- When returning to project after time away
- Before code review
- When something feels inconsistent
- After major refactoring

**Integration points:**
- After `/forge:execute-plan` completes
- Before `/forge:finishing-a-development-branch`
- Periodically during long development sessions

## Rules

**DO:**
- Read actual files to verify content, don't trust file names alone
- Compare specific values (imports, function names, class names)
- Report exact discrepancies with file paths and line details
- Distinguish between "not started" and "partially done"
- Count test functions to verify coverage
- Check both directions (spec→code and code→spec)

**DON'T:**
- Modify any files (read-only validation)
- Fix issues found (only report them)
- Make assumptions (if file exists, verify expected content is actually there)
- Skip verification steps (run the checks, don't guess)
- Auto-run /forge:sync (suggest it, don't run it)
- Report "looks good" without checking each validation point

## Red Flags — STOP Immediately

If you're about to:
- "Everything looks fine" — STOP. Run the actual checks.
- "File exists so task is done" — STOP. Verify expected content is present.
- "I'll just fix this quickly" — STOP. Validate is read-only, report only.
- "Tests probably pass" — STOP. Run the tests, check output.
- Skip comparing imports/dependencies — STOP. Metadata accuracy matters.

## Error Handling

**No plan exists:**
- Skip plan validation
- Report: "No plan to validate against"
- Continue with documentation validation

**spec.json malformed:**
- Report which spec.json is broken
- Skip that directory
- Continue with other directories
- Suggest manual inspection

**Git repository not initialized:**
- Can't check recent changes context
- Proceed with current state validation
- Report: "Git not available, validating current state only"

**File read failures:**
- Report which files couldn't be read (permissions, corruption)
- Mark as "Unable to validate"
- Continue with accessible files

**Conflicting sources:**
- If plan says one thing, spec.json says another:
  - Report the conflict explicitly
  - Mark as ⚠️ inconsistent
  - Suggest resolving the conflict manually

## Examples

### Example 1: Perfect State

```
You: /forge:validate

[Reads docs/, scans codebase]

FORGE Validation Summary
════════════════════════

Plan Compliance: 15/15 tasks ✅
Documentation Coverage: 100% (42/42 files)
map.json Accuracy: ✅ All counts match

═══════════════════════════════════════
Overall Status: ✅ ALL CLEAR
═══════════════════════════════════════

✓ All clear. Code matches plan and documentation.
```

### Example 2: Found Issues

```
You: /forge:validate

[Reads docs/, scans codebase, finds problems]

FORGE Validation Summary
════════════════════════

Plan Compliance
───────────────
Plan: docs/plans/2026-02-15-caching.md
✅ Implemented: 10/12 tasks
⚠️ Partial: 1 task
❌ Missing: 1 task

Discrepancies:
⚠️ Task 8: Cache monitoring
   File: src/cache/metrics.py
   Expected: hit_rate, miss_rate, eviction_count methods
   Found: Only hit_rate implemented
   Missing: miss_rate, eviction_count

❌ Task 12: Documentation not synced
   Expected: docs/library/ updated
   Found: Missing spec.json entries

Documentation Coverage
──────────────────────
⚠️ Undocumented: 3 files
   - src/cache/redis_client.py (NEW)
   - src/cache/metrics.py (NEW)
   - src/decorators/cache.py (MODIFIED)

═══════════════════════════════════════
Overall Status: ⚠️ ISSUES FOUND
═══════════════════════════════════════

Actions Needed:
1. Implement missing methods in src/cache/metrics.py:
   - miss_rate()
   - eviction_count()
2. Run /forge:sync to update documentation

Next Steps:
- Complete Task 8 implementation OR
- Update plan if requirements changed OR
- Run /forge:sync to document completed work
```

## Optimization

**Smart Scanning:**
- Only read files mentioned in plan or spec.json
- Don't scan entire codebase unnecessarily
- Use grep for quick content checks before full file read
- Cache file lists per directory

**Performance:**
- Validation should complete in <30 seconds for typical project
- Use parallel checks where possible (checking multiple spec.json files)
- Bail early if critical errors found (missing docs/map.json)

**Accuracy vs Speed:**
- Prefer accuracy over speed
- Better to take 60 seconds and find all issues
- Than finish in 10 seconds and miss problems
