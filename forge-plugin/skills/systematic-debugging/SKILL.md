---
name: systematic-debugging
description: "Use proactively when ANYTHING broken, failing, or behaving unexpectedly — BEFORE proposing any fix. Trigger on Russian voice: 'почини', 'пофикс', 'фикс', 'сломалось', 'не работает', 'падает', 'крашит', 'глючит', 'вылетает', 'отвалил', 'отвалилось', 'ошибка', 'баг', 'кривой', 'кривое', 'тупит', 'тормозит', 'странно ведёт себя', 'почему так'. English: fix, debug, crash, error, broken, fail, exception, stacktrace, regression, flaky. Concrete contexts: test failure, bug report, unexpected behavior, exception trace, build failure, performance regression, integration breakage. Forces 4-phase process (root cause → pattern → hypothesis → fix) instead of guess-patch-pray. WHY NOT SKIP: random fixes mask the real bug and create new ones — symptom fixes are failure. Don't guess — measure, trace, prove. If you can't explain WHY it broke, you haven't found the cause. Use ESPECIALLY when under time pressure or 'just one quick fix' feels obvious — that's exactly when guessing burns the most time."
---

# Systematic Debugging

## Автозагруженный контекст — провальные подходы (НЕ повторять):
!`cat .forge/dead-ends.yml 2>/dev/null || cat .forge/dead-ends/*.md 2>/dev/null || echo "нет dead-ends"`

---

**Role:** Senior diagnostics engineer (12 years debugging distributed systems, the person called at 3 AM). Never guess — trace, measure, prove.

**Iron Law:** NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST. Symptom fixes are failure. If you can't explain WHY it broke, you haven't found the cause.

## When to Use

Any technical issue: test failures, production bugs, unexpected behavior, performance problems, build failures, integration issues.

**ESPECIALLY when:** under time pressure, "just one quick fix" seems obvious, you've already tried multiple fixes, previous fix didn't work, you don't fully understand the issue.

**Don't skip because:** "simple" bugs have root causes too. Systematic debugging is FASTER than guess-and-check thrashing.

## Environment Recon

Before starting, check available tools:
- **MCP servers:** Serena (symbolic code analysis instead of grep), Playwright (UI checks), Context7 (current library docs)
- **Other Claude Code plugins/skills** — use where useful
- **Infrastructure:** Docker, SSH, DB access

## The Four Phases

Complete each phase before proceeding to the next.

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read errors carefully** — stack traces fully, line numbers, file paths, error codes. They often contain the solution.

2. **Reproduce consistently** — exact steps? Every time? If not reproducible → gather more data, don't guess.

3. **Check recent changes** — git diff, new dependencies, config changes, environmental differences.

4. **Gather evidence in multi-component systems** (CI → build → signing, API → service → DB):

   For EACH component boundary: log data in, log data out, verify config propagation, check state at each layer. Run once to see WHERE it breaks, THEN investigate that component.

   **Parallelize:** if 3+ components, dispatch one subagent per boundary simultaneously.

   Full bash example: see `references/deep-dive.md`.

5. **Check domain model boundaries** (if DDD design exists): bounded context? aggregate boundary violation? lifecycle violation? unvalidated domain primitive? Details in `references/deep-dive.md`.

6. **Trace data flow** — when error is deep in call stack:
   - Where does the bad value originate?
   - What called this with the bad value?
   - Keep tracing up until you find the source
   - Fix at source, not at symptom

   Full technique: see `root-cause-tracing.md`. If Serena MCP is available — use `find_symbol` and `find_references` instead of grep.

### Phase 2: Pattern Analysis

1. **Find working examples** — similar working code in same codebase.
2. **Compare against references** — read reference implementation COMPLETELY, every line. Don't skim.
3. **Identify differences** — list every difference, however small. Don't assume "that can't matter".
4. **Understand dependencies** — what components, config, environment, assumptions does it need?

### Phase 3: Hypothesis and Testing

Scientific method:

1. **Form ONE hypothesis** — "I think X is the root cause because Y". Specific, not vague.
2. **Test minimally** — SMALLEST possible change. One variable at a time. No bundled fixes.
3. **Verify** — worked? → Phase 4. Didn't? → form NEW hypothesis. DON'T pile fixes on top.
4. **When you don't know** — say "I don't understand X". Don't pretend. Ask, research more.

### Phase 4: Implementation

Fix the root cause, not the symptom:

1. **Create failing test case** — simplest possible reproduction. Automated if framework exists, one-off script otherwise. MUST exist before fixing. Use `forge:test-driven-development` skill.

2. **Implement single fix** — root cause only. ONE change. No "while I'm here" improvements. No bundled refactoring.

3. **Verify** — test passes? other tests still pass? issue actually resolved?

4. **If fix didn't work:** STOP. Count failed attempts.
   - < 3 → return to Phase 1 with new info
   - **≥ 3 → STOP, question architecture (step 5)**
   - DON'T attempt Fix #4 without architectural discussion

5. **If 3+ fixes failed: question architecture**

   Pattern of architectural problem:
   - Each fix reveals new shared state/coupling in a different place
   - Fixes require "massive refactoring" to implement
   - Each fix creates new symptoms elsewhere

   Ask: is this pattern fundamentally sound? Sticking with it through inertia? Refactor vs. continue patching?

   Discuss with the user before more fixes. This is wrong architecture, not failed hypothesis.

## Red Flags — STOP and Return to Phase 1

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run tests"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "Pattern says X but I'll adapt it differently"
- Proposing solutions before tracing data flow
- **"One more fix attempt" after 2+ failures**
- **Each fix reveals a new problem in a different place**

The user's signals you're off-track: "Is that not happening?", "Stop guessing", "Ultrathink this", "We're stuck?". Full list in `references/deep-dive.md`.

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare | Identify differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Implementation** | Create test, fix, verify | Bug resolved, tests pass |

## Supporting Files

In this directory:
- `root-cause-tracing.md` — backward tracing through call stack
- `defense-in-depth.md` — validation at multiple layers after root cause found
- `references/deep-dive.md` — multi-component evidence example, DDD bug sources, rationalizations table, the user's signals, "no root cause" cases, real-world impact data

Related skills:
- `forge:test-driven-development` — failing test case (Phase 4, step 1)
- `forge:verification-before-completion` — verify fix before claiming success
