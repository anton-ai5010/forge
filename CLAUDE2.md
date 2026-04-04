# Claude Code Instructions

<!-- ==========================================
     PROJECT CONTEXT (fill in after init)
     ========================================== -->

## Project Overview
<!-- TODO: Claude Code — read the spec files in this repo and fill this section:
     - What this project does (2-3 sentences)
     - Who uses it
     - Key success metrics
-->
_To be filled by Claude Code on first run._

## Technical Stack
<!-- TODO: Claude Code — detect from existing files and spec, fill this:
     - Primary language(s)
     - Frameworks and libraries
     - Database(s)
     - ML frameworks
-->
_To be filled by Claude Code on first run._

## Project Structure
<!-- TODO: Claude Code — scan the repo and document main directories:
     - What each top-level directory contains
     - Where the spec files live
     - Where models/data/features go
-->
_To be filled by Claude Code on first run._

<!-- ==========================================
     FORGE PLUGIN RULES (do not modify)
     ========================================== -->

## Forge Plugin Workflow

This project uses the **Forge plugin** for structured development. Always follow these rules.

### Mandatory workflow for any new work

1. **Before writing any code** — run `/forge:brainstorm` to clarify requirements and design
2. **After brainstorming** — a plan is created automatically in `docs/plans/`
3. **During implementation** — follow TDD: write failing test first, then production code
4. **After completing a phase** — run `/forge:sync` to update documentation
5. **Before merging** — run `/forge:validate` to check code matches the plan

### Hard rules — no exceptions

- **NO production code without a failing test first.** If code was written before a test, delete it and redo it TDD.
- **NO implementation without approved design.** Use `/forge:brainstorm` first.
- **NO fixes without root cause analysis.** Use systematic debugging before touching code.
- **NO "done" claims without verification.** Run tests, confirm output, then claim success.

### Forge commands reference

| Command | When to use |
|---------|-------------|
| `/forge:init` | Once, at project start — creates `docs/` structure |
| `/forge:brainstorm` | Before every new feature or phase |
| `/forge:validate` | Before merge — read-only check code vs plan vs docs |
| `/forge:sync` | After completing work — updates `docs/` to match code |

### Documentation structure (after `/forge:init`)

```
docs/
├── map.json          ← project structure, red zones (read by Claude)
├── conventions.json  ← naming rules, patterns (read by Claude)
├── state.json        ← current task and progress (updated by /forge:sync)
├── history.log       ← session log (humans only)
├── product.md        ← why project exists, users, metrics
├── tech.md           ← stack, reasoning, constraints
├── plans/            ← design docs and implementation plans
└── library/          ← machine-readable specs per directory
```

### On session start

- If `docs/map.json` exists — run `/forge:forge-context` to load project knowledge (~2k tokens instead of scanning codebase)
- If `docs/` does not exist — run `/forge:init` first

### Execution modes for plans

When executing a plan from `docs/plans/`, choose:
- **Subagent-Driven** — fresh subagent per task, clean context, in current session
- **Batch Execution** — 3 tasks at a time with human checkpoints
- **Autonomous** — all tasks auto in separate session

Default for small tasks: **Subagent-Driven**.
Default for implementation phases (Phase 0–11): **Batch Execution** — 3 tasks at a time with human checkpoints.

<!-- ==========================================
     PROJECT-SPECIFIC CONVENTIONS
     ========================================== -->

## Development Conventions
<!-- TODO: Claude Code — after reading the spec, fill in:
     - File naming rules
     - Module structure patterns
     - How to add a new model/feature/pipeline stage
     - Any naming conventions specific to this domain (e.g. feature columns, match IDs)
-->
_To be filled by Claude Code on first run._

## Red Zones
<!-- TODO: Claude Code — identify critical files that need extra care:
     - Core data pipeline (bugs = corrupted training data)
     - Model evaluation code (bugs = wrong metrics)
     - Any financial/betting calculation logic
-->
_To be filled after `/forge:init`._

## Spec Files Location
<!-- TODO: Claude Code — document where specs live and their structure -->
_To be filled by Claude Code on first run._

<!-- ==========================================
     WORKING STYLE
     ========================================== -->

## Communication

- Respond in **Russian** unless asked otherwise
- Be concise — no fluff, no repeating the question
- When referencing code, include `file_path:line_number`
- Ask one clarifying question at a time, not a list

## When Stuck

- Do not brute-force or retry the same approach
- Investigate root cause first
- If blocked — report what was tried and ask how to proceed
