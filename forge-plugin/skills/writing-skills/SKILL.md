---
name: writing-skills
description: "Use when creating, editing, or verifying a Claude skill. RU: 'создай скилл', 'новый скилл', 'напиши скилл', 'сделай скилл', 'добавь скилл', 'поправь скилл', 'редактируй скилл'. EN: 'create skill', 'write skill', 'edit skill', 'modify skill'. Covers: authoring SKILL.md, changing description/triggers/body, debugging why a skill doesn't fire, tuning frontmatter. Applies TDD to process docs — write a failing pressure test with a subagent first, then the minimal skill, then verify compliance."
---

# Writing Skills

**Role:** Senior process engineer. Apply TDD to process docs — test before writing.
**Stakes:** A skill that doesn't trigger correctly is worse than no skill — it gives false confidence.

## Core Principle

**Writing skills IS TDD applied to process documentation.** You write a pressure test (subagent scenario), watch it fail (baseline), write the minimal skill, watch it pass (compliance), refactor (close loopholes).

If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing.

**REQUIRED BACKGROUND:** Read forge:test-driven-development before using this skill. For Anthropic's official authoring guidance see `anthropic-best-practices.md`.

## What is a Skill?

A reusable reference guide for proven techniques, patterns, or tools. **Not** a narrative about how you solved a problem once.

**Types:**
- **Technique** — concrete method with steps (e.g., condition-based-waiting)
- **Pattern** — way of thinking about problems (e.g., flatten-with-flags)
- **Reference** — API docs, syntax, tool documentation

## When to Create a Skill

**Create when:** technique wasn't obvious; you'd reference it again across projects; pattern applies broadly; others benefit.

**Don't create for:** one-off solutions; standard practices documented elsewhere; project-specific conventions (put in CLAUDE.md); mechanical constraints (automate with regex/validation instead).

## TDD Mapping

| TDD Concept | Skill Creation |
|-------------|----------------|
| Test case | Pressure scenario with subagent |
| Production code | SKILL.md |
| RED (fails) | Agent violates rule without skill |
| GREEN (passes) | Agent complies with skill present |
| Refactor | Close loopholes while maintaining compliance |

## Directory Structure

```
skills/
  skill-name/
    SKILL.md              # Main reference (required)
    supporting-file.*     # Only if needed
```

**Separate files for:** heavy reference (100+ lines), reusable tools/scripts, language-specific hints (`stack-hints/{language}.md`).
**Keep inline:** principles, concepts, code patterns <50 lines.

## SKILL.md Structure

**YAML frontmatter** — only two fields: `name` and `description`. Max 1024 chars total.
- `name`: kebab-case, letters/numbers/hyphens only
- `description`: third-person, starts with "Use when...", describes ONLY triggering conditions (see CSO below)

**Body skeleton:**
```markdown
# Skill Name

## Overview
Core principle in 1-2 sentences.

## When to Use
Symptoms, use cases. When NOT to use.

## Core Pattern
Before/after comparison.

## Quick Reference
Table or bullets for scanning.

## Implementation
Inline code OR link to file.

## Common Mistakes
What goes wrong + fixes.
```

## Claude Search Optimization (CSO)

Future Claude must FIND your skill. The description is what gets matched.

### Description = When to Use, NOT What the Skill Does

**Critical:** Do NOT summarize the skill's process or workflow in the description. If you do, Claude follows the description and skips reading the skill body.

Real example: a description saying "code review between tasks" caused Claude to do ONE review even though the skill flowchart specified TWO. Changing it to just "Use when executing implementation plans with independent tasks" fixed it.

```yaml
# BAD: Summarizes workflow — Claude follows this instead of reading skill
description: Use when executing plans - dispatches subagent per task with code review between tasks

# BAD: Process detail
description: Use for TDD - write test first, watch it fail, write minimal code, refactor

# BAD: First person
description: I can help you with async tests when they're flaky

# BAD: Mentions tech but skill isn't tech-specific
description: Use when tests use setTimeout/sleep and are flaky

# GOOD: Just triggers
description: Use when executing implementation plans with independent tasks in the current session

# GOOD: Problem-focused
description: Use when tests have race conditions, timing dependencies, or pass/fail inconsistently

# GOOD: Tech-specific skill, explicit trigger
description: Use when using React Router and handling authentication redirects
```

### Keyword Coverage

Use words Claude would search for:
- Error messages: "Hook timed out", "ENOTEMPTY", "race condition"
- Symptoms: "flaky", "hanging", "zombie", "pollution"
- Synonyms: "timeout/hang/freeze", "cleanup/teardown/afterEach"
- Tools: actual commands, library names, file types

### Descriptive Naming

Active voice, verb-first. Gerunds (-ing) work for processes.
- `creating-skills` not `skill-creation`
- `condition-based-waiting` not `async-test-helpers`
- `root-cause-tracing` not `debugging-techniques`

### Cross-Referencing Other Skills

Use skill name with explicit requirement markers. **Never** use `@` links — they force-load and burn context.

- Good: `**REQUIRED SUB-SKILL:** Use forge:test-driven-development`
- Bad: `@skills/testing/test-driven-development/SKILL.md`

### Token Efficiency

Frequently-loaded skills cost tokens in every conversation.
- getting-started workflows: <150 words
- Frequently-loaded: <200 words
- Other skills: <500 words

Techniques: reference `--help` instead of listing flags; cross-reference instead of repeating; compress examples; verify with `wc -w SKILL.md`.

## Flowcharts

Use ONLY for non-obvious decisions, process loops where you might stop early, "A vs B" choices.

Never for: reference material (use tables), code examples (use markdown), linear instructions (use numbered lists).

See `graphviz-conventions.dot` for style rules. Render via `./render-graphs.js ../some-skill`.

## Code Examples

**One excellent example beats many mediocre ones.** Choose the most relevant language (testing → TS/JS; systems → shell/Python; data → Python).

Good example: complete, runnable, commented WHY, from a real scenario, shows the pattern clearly.

Don't: implement in 5 languages; create fill-in-the-blank templates; write contrived examples.

## The Iron Law

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

Applies to NEW skills AND EDITS.

**No exceptions:** not for "simple additions", "just a section", "documentation updates". Don't keep untested changes as reference. Don't adapt while running tests. Delete means delete.

## Testing by Skill Type

| Type | Test with | Success |
|------|-----------|---------|
| **Discipline-enforcing** (TDD, verification-before-completion) | Pressure scenarios + combined pressures (time + sunk cost + exhaustion) | Agent follows rule under max pressure |
| **Technique** (how-to guides) | Application + variation + missing-info scenarios | Agent applies technique to new scenario |
| **Pattern** (mental models) | Recognition + application + counter-examples | Agent recognizes when (not) to apply |
| **Reference** (API docs) | Retrieval + application + gap testing | Agent finds and uses info correctly |

**Full methodology:** see `testing-skills-with-subagents.md` (pressure types, plugging holes, meta-testing).

## RED-GREEN-REFACTOR

**RED — Failing baseline.** Run pressure scenario WITHOUT the skill. Document verbatim: choices, rationalizations, which pressures triggered violations.

**GREEN — Minimal skill.** Address those specific rationalizations. No extra content for hypothetical cases. Re-run scenarios WITH skill. Agent should now comply.

**REFACTOR — Close loopholes.** New rationalization? Add explicit counter. Re-test until bulletproof.

## Bulletproofing Against Rationalization

Discipline skills must resist clever agents looking for loopholes. (Psychology background: see `persuasion-principles.md` — Cialdini's authority/commitment/scarcity/social proof/unity.)

### Close Every Loophole Explicitly

Don't just state the rule — forbid workarounds.

Bad:
```markdown
Write code before test? Delete it.
```

Good:
```markdown
Write code before test? Delete it. Start over.

No exceptions:
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete
```

### Spirit-vs-Letter Cut-off

Add early in skill:

> **Violating the letter of the rules is violating the spirit of the rules.**

### Rationalization Table

Capture every excuse agents make during baseline testing:

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |

### Red Flags List

Make self-checking easy:

```markdown
## Red Flags — STOP and Start Over
- Code before test
- "I already manually tested it"
- "This is different because..."

All of these mean: Delete code. Start over.
```

## Common Rationalizations for Skipping Testing

| Excuse | Reality |
|--------|---------|
| "Skill is obviously clear" | Clear to you ≠ clear to other agents. Test it. |
| "It's just a reference" | References have gaps. Test retrieval. |
| "Testing is overkill" | Untested skills have issues. Always. |
| "I'll test if problems emerge" | Problems = agents can't use it. Test BEFORE deploying. |
| "Academic review is enough" | Reading ≠ using. Test application. |
| "No time to test" | Deploying untested wastes more time later. |

## Anti-Patterns

- **Narrative example:** "In session 2025-10-03, we found..." — too specific, not reusable.
- **Multi-language dilution:** example-js.js, example-py.py — mediocre quality, maintenance burden.
- **Code in flowcharts:** can't copy-paste, hard to read.
- **Generic labels:** helper1, step3 — labels should have semantic meaning.

## STOP Before Next Skill

After writing ANY skill, complete the deployment checklist. Do NOT batch multiple untested skills.

## Checklist (TDD Adapted)

**RED — Failing test:**
- [ ] Pressure scenarios written (3+ combined pressures for discipline skills)
- [ ] Run WITHOUT skill — document baseline verbatim
- [ ] Identify rationalization patterns

**GREEN — Minimal skill:**
- [ ] Name: kebab-case, letters/numbers/hyphens only
- [ ] YAML frontmatter: name + description (max 1024 chars)
- [ ] Description starts with "Use when...", third person, triggers only (no workflow summary)
- [ ] Keywords for search (errors, symptoms, tools)
- [ ] Addresses specific baseline failures
- [ ] One excellent example
- [ ] Run WITH skill — verify compliance

**REFACTOR — Close loopholes:**
- [ ] Identify new rationalizations from testing
- [ ] Add explicit counters
- [ ] Build rationalization table + red flags list
- [ ] Re-test until bulletproof

**Quality:**
- [ ] Flowchart only if decision is non-obvious
- [ ] Quick reference table
- [ ] Common mistakes section
- [ ] No narrative storytelling
- [ ] Supporting files only for heavy reference or tools

**Deploy:** commit; consider contributing back if broadly useful.

## Bottom Line

Same Iron Law as TDD: no skill without failing test first. Same cycle: RED → GREEN → REFACTOR. If you follow TDD for code, follow it for skills.
