---
description: Search Claude Code marketplace for skills and plugins matching your implementation plan's technologies and domains
---

# FORGE Discover

**Purpose:** Find marketplace skills that can accelerate plan execution.

**When to run:** After plan is written, before choosing execution approach.

## Pre-Check: Plan Exists?

```bash
ls docs/plans/*.md 2>/dev/null | tail -1
```

**If no plan:**
```
No implementation plan found in docs/plans/

Run `/forge:brainstorming` and `/forge:writing-plans` first to create a plan.
```

Stop.

**If multiple plans exist:**
```
Multiple plans found. Which plan should I analyze?

1. docs/plans/2026-02-15-authentication.md
2. docs/plans/2026-02-14-payment-integration.md
...

Select number or 'latest':
```

Wait for user input.

## Step 1: Read and Analyze Plan

Read the selected plan file from `docs/plans/`.

Extract from plan content:

**Technologies mentioned:**
- Libraries (pandas, PyTorch, React, Django, FastAPI, etc.)
- Languages (Python, TypeScript, Rust, Go, etc.)
- Frameworks (Express, Flask, Next.js, etc.)

**Work types:**
- ML training, data processing, API development, testing, DevOps, etc.

**Domains:**
- Trading, web scraping, security, authentication, payments, etc.

**Patterns needed:**
- State machines, pipelines, pub/sub, event sourcing, etc.

**Specific tools:**
- Docker, Kubernetes, Terraform, Git workflows, CI/CD, etc.

Create internal list of keywords to search for.

## Step 2: Check Currently Installed

Run in Claude Code:

```bash
/plugins
```

List what's already installed. Extract plugin names.

**Do NOT suggest:**
- Plugins already installed
- Duplicate functionality

## Step 3: Search Marketplace

**CRITICAL:** This is a placeholder step. Real marketplace search API doesn't exist yet.

**For now:**
- Document what WOULD be searched (technologies/domains from Step 1)
- Report to user that marketplace search is not yet implemented
- Skip to Step 6 (Report Missing Skills)

**Future implementation:** When marketplace API is available, search by categories:
- Language-specific: python, typescript, rust, go, java
- Domain-specific: ml, data-engineering, security, devops, web
- Tool-specific: docker, kubernetes, terraform, git
- Framework-specific: django, react, pytorch, fastapi

For each keyword from Step 1, query marketplace API.

Collect results with:
- Plugin name
- Install count
- Description
- Relevance score (how well it matches plan tasks)

## Step 4: Rank by Relevance

**Future implementation:** Sort findings into categories:

**High Relevance:**
- Plugin directly addresses plan task
- High install count (500+ installs)
- Description matches specific technology/domain in plan

**Medium Relevance:**
- Plugin could help with some tasks
- Moderate install count (100-500 installs)
- Partial match to plan requirements

**Low Priority:**
- Tangentially related
- Low install count (<100 installs)
- Only mention if nothing better exists

Limit recommendations:
- Max 5 high relevance
- Max 3 medium relevance
- Don't overwhelm with options

## Step 5: Present Recommendations

**Future implementation:** Present findings in this format:

```
Recommended Skills for This Plan

## High Relevance (directly matches plan tasks)

- **plugin-name** (1.2k installs) — What it does. Why it's relevant to YOUR plan.
- **another-plugin** (850 installs) — What it does. Why it helps with [specific task from plan].

## Medium Relevance (could help with some tasks)

- **helper-plugin** (320 installs) — What it does. Why it might help.

## Not Found

These areas from your plan have no matching plugins in the marketplace:

- **[technology/domain]** — No ready-made skill available.
  → I can write a custom skill for this if you want. (Requires your approval)

Install any of these? (list numbers, "all high", or "skip")
```

Wait for user input.

## Step 6: Report Marketplace Status

**Current state:** Marketplace search API not yet available.

Report to user:

```
FORGE Discover Analysis

I've analyzed your plan and identified these areas that could benefit from marketplace skills:

Technologies detected:
- {list_technologies}

Domains detected:
- {list_domains}

Patterns needed:
- {list_patterns}

---

⚠️ Marketplace search is not yet implemented.

What I would search for when marketplace API is available:
- [technology 1] — for {plan task description}
- [domain 1] — for {plan task description}
- [pattern 1] — for {plan task description}

For now, you have these options:

1. **Proceed without marketplace skills** — Use existing skills and tools
2. **Custom skill creation** — I can write a custom skill for specific needs (requires your approval)
3. **Manual plugin search** — Check Claude Code documentation for relevant plugins

Which option?
```

Wait for user decision.

## Step 7: Install Approved (Future)

**Future implementation:** When marketplace API available and user approves installations:

For each approved plugin:

```bash
/install plugin-name
```

Verify installation succeeded.

Report:
```
✓ Installed: plugin-name
✓ Installed: another-plugin

Installed 2 plugins. Ready to execute plan with enhanced tooling.
```

## Step 8: Offer Custom Skill Creation

If user requests custom skill for areas not covered:

```
You've requested a custom skill for: {area}

Before I create a custom skill, I need your approval for:

1. Skill name: {suggested-name}
2. Scope: {what it will do}
3. Location: ~/.claude/skills/{suggested-name}/

This will require testing before deployment (TDD for skills).
Estimated time: 15-20 minutes (includes testing).

Proceed with custom skill creation? (yes/no)
```

Wait for explicit approval.

**CRITICAL:** Never create custom skills without explicit user approval.

If approved:
- Use `/forge:writing-skills` to create skill with proper TDD workflow
- Test before deployment
- Report completion

## When to Use

**Trigger:** After plan is written (writing-plans completes), before execution begins.

**Integration:** writing-plans skill should prompt user to run this command before choosing execution approach.

## Rules

**DO:**
- Search broadly — check multiple keyword variations (future)
- Prioritize plugins with high install counts (community-validated)
- Explain WHY each plugin is relevant to THIS specific plan
- Show install counts so user can judge popularity
- Clearly separate "install from marketplace" from "create custom"
- Report current marketplace status honestly

**DON'T:**
- Auto-install anything (user must approve)
- Generate custom skills without explicit approval
- Recommend plugins with <100 installs unless nothing better exists
- Suggest plugins unrelated to plan's actual tasks
- Overwhelm — max 5 high relevance, 3 medium relevance
- Claim marketplace works if API isn't available

## Red Flags — STOP Immediately

If you're about to:
- "I'll create a quick skill for this" — STOP. Ask user first.
- "Installing recommended plugins" — STOP. User must approve each one.
- Suggest 10+ plugins — STOP. Prioritize. Each plugin adds context tokens.
- Auto-install without confirmation — STOP. Explicit approval required.

## Error Handling

**No plan file:**
- Suggest running brainstorming and writing-plans first

**Marketplace API unavailable:**
- Report current status
- Document what would be searched
- Offer alternatives (proceed without, custom skills, manual search)

**Installation failures:**
- Report which plugins failed
- Continue with successful installations
- Suggest manual installation for failures

**User rejects all recommendations:**
- Acknowledge decision
- Proceed with execution using existing tools
- Note that custom skills remain an option
