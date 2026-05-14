# Systematic Debugging — Deep Dive

Supplementary material for SKILL.md. Read when you need detailed examples or full rationale.

## Multi-Component Evidence Gathering — Full Example

When system has multiple components (CI → build → signing, API → service → database), instrument every boundary BEFORE proposing fixes:

```bash
# Layer 1: Workflow
echo "=== Secrets available in workflow: ==="
echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"

# Layer 2: Build script
echo "=== Env vars in build script: ==="
env | grep IDENTITY || echo "IDENTITY not in environment"

# Layer 3: Signing script
echo "=== Keychain state: ==="
security list-keychains
security find-identity -v

# Layer 4: Actual signing
codesign --sign "$IDENTITY" --verbose=4 "$APP"
```

This reveals which layer fails (secrets → workflow ✓, workflow → build ✗).

**Parallelize:** if 3+ components, dispatch one subagent per boundary simultaneously. Don't check layers one by one — check all at once, then analyze where the break is.

For EACH component boundary:
- Log what data enters component
- Log what data exits component
- Verify environment/config propagation
- Check state at each layer

## Domain Model (DDD) Bug Sources

If design doc or `.forge/` has a Domain Model:
- Identify which **bounded context** the bug is in (auth? orders? payments?)
- Check if error crosses **aggregate boundaries** — data passed between aggregates by ID only, not by reference
- Check **lifecycle violations** — entity in invalid state? (e.g., "shipped" order without payment)
- Check **domain primitive validation** — invalid value (bad email, negative price) bypassing validation?

These are the most common DDD bug sources: boundary violations, lifecycle skips, unvalidated primitives.

## Common Rationalizations (full table)

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "I'll write test after confirming fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question pattern, don't fix again. |

## the user's Signals You're Doing It Wrong

- "Is that not happening?" — you assumed without verifying
- "Will it show us...?" — you should have added evidence gathering
- "Stop guessing" — you're proposing fixes without understanding
- "Ultrathink this" — question fundamentals, not just symptoms
- "We're stuck?" (frustrated) — your approach isn't working

When you see these: STOP. Return to Phase 1.

## When Process Reveals "No Root Cause"

If investigation reveals issue is truly environmental, timing-dependent, or external:
1. You've completed the process
2. Document what you investigated
3. Implement appropriate handling (retry, timeout, error message)
4. Add monitoring/logging for future investigation

**But:** 95% of "no root cause" cases are incomplete investigation.

## Real-World Impact

From debugging sessions:
- Systematic approach: 15-30 minutes to fix
- Random fixes approach: 2-3 hours of thrashing
- First-time fix rate: 95% vs 40%
- New bugs introduced: near zero vs common
