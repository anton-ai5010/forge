# Forge Plugin — Proposals for New Skills & Agents

> Date: 2026-04-05
> Status: Draft — awaiting prioritization

---

## High Priority

### 1. `ui-ux-design`

**Pain:** Claude generates functional but visually generic UI. No systematic approach to style, color, typography, UX patterns.

**Solution:** Integrate [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) as Forge skill with searchable databases: 67 UI styles, 161 palettes, 57 font pairings, 99 UX guidelines. Python search engine + CSV data.

**Workflow:** requirements analysis → style selection → palette → typography → UX rules → design system spec in `docs/plans/`.

**Command:** `/forge:design`

**Status:** Prompt ready, pending implementation.

---

### 2. `api-design`

**Pain:** `brainstorming` is too generic for API work. Claude jumps straight to code without designing endpoints, schemas, auth, error codes, versioning.

**Solution:** Skill that forces structured API design before implementation:
- List all resources and relationships
- Define endpoints (REST) or schema (GraphQL)
- Specify request/response shapes with examples
- Auth strategy (JWT, API keys, OAuth)
- Error codes and error response format
- Versioning strategy
- Rate limiting rules

**Output:** OpenAPI 3.x spec saved to `docs/plans/api-{name}.yaml`.

**Command:** `/forge:api-design`

---

### 3. `database-modeling`

**Pain:** Claude creates tables on the fly during implementation, leading to inconsistent schemas, missing indexes, and painful migrations later.

**Solution:** Skill for upfront DB design:
- Identify entities and relationships
- Normalize (3NF minimum, denormalize with justification)
- Define indexes for query patterns
- Plan migrations (up + down)
- Consider data volume and growth

**Output:** ER diagram (Mermaid) + migration plan in `docs/plans/db-{name}.md`.

**Command:** `/forge:db-design`

---

### 4. `security-review`

**Pain:** `verification-before-completion` checks "does it work?" but not "is it safe?" Security issues slip through to merge.

**Solution:** Pre-merge security audit skill:
- OWASP Top 10 checklist against diff
- SQL injection, XSS, CSRF, SSRF scan
- Secrets in code detection (.env, API keys, tokens)
- Dependency vulnerability check (npm audit / pip audit)
- Auth/authz logic review
- Input validation at system boundaries

**Trigger:** Before `finishing-a-development-branch` or on explicit `/forge:security-review`.

**Command:** `/forge:security-review`

---

### 5. `performance-profiling`

**Pain:** No systematic approach to "it's slow". Claude guesses at optimizations instead of measuring.

**Solution:** Analog of `systematic-debugging` but for performance:
1. **Measure** — establish baseline (time, memory, DB queries)
2. **Identify** — find the bottleneck (not guess)
3. **Optimize** — fix the specific bottleneck
4. **Verify** — measure again, confirm improvement

**Hard gate:** NO optimization without baseline measurement first.

**Command:** `/forge:perf`

---

## Medium Priority

### 6. `writing-tests-for-existing-code`

**Pain:** TDD skill works for new code. But when covering legacy code with tests, the approach is different — you need characterization tests, not red-green-refactor.

**Solution:**
- Identify critical paths and high-risk areas
- Write characterization tests (capture current behavior)
- Identify untested edge cases
- Add regression tests for known bugs
- Measure coverage delta

**Complements:** `test-driven-development` (new code) vs this skill (existing code).

---

### 7. `deployment-checklist`

**Pain:** Deployments fail due to forgotten steps — missing ENV vars, unapplied migrations, no rollback plan.

**Solution:** Pre-deploy verification:
- [ ] All ENV variables documented and set
- [ ] DB migrations tested (up + down)
- [ ] Feature flags configured
- [ ] Rollback plan written
- [ ] Health checks / monitoring in place
- [ ] Breaking changes communicated

**Output:** Checklist in `docs/plans/deploy-{date}.md`.

---

### 8. `refactoring-legacy`

**Pain:** `code-cleanup` handles small improvements. Large-scale refactoring (extract service, replace framework, restructure modules) needs a different process — incremental, safe, test-covered at each step.

**Solution:**
- Map current architecture (what depends on what)
- Define target architecture
- Plan incremental steps (each step = working system)
- Strangler pattern for replacements
- Verify behavior preservation at each step

**Hard gate:** NO big-bang rewrites. Each step must pass all existing tests.

---

## Agents

### 9. `dependency-auditor` (agent)

**Pain:** Outdated and vulnerable dependencies accumulate silently.

**Solution:** Subagent that runs before merge:
- `npm audit` / `pip audit` / `cargo audit`
- Check for major version updates
- Flag deprecated packages
- Report CVEs with severity

**Trigger:** Automatic in `finishing-a-development-branch`.

---

### 10. `documentation-writer` (agent)

**Pain:** `forge-documenter` updates internal Forge docs. But user-facing docs (README, API reference, user guides) are always stale.

**Solution:** Subagent that generates/updates public documentation:
- README sections from current code state
- API docs from OpenAPI spec or code comments
- Changelog from git history
- Usage examples from tests

**Trigger:** On `/forge:sync` or explicit `/forge:write-docs`.

---

## Implementation Order (suggested)

| Phase | Skills | Rationale |
|-------|--------|-----------|
| 1 | `ui-ux-design`, `security-review` | Biggest gaps in current workflow |
| 2 | `api-design`, `database-modeling` | Design-first prevents rework |
| 3 | `performance-profiling`, `deployment-checklist` | Operational maturity |
| 4 | `writing-tests-for-existing-code`, `refactoring-legacy` | Legacy code support |
| 5 | `dependency-auditor`, `documentation-writer` | Automation agents |

---

## Notes

- Each skill should follow Forge conventions: `skills/{name}/SKILL.md` with YAML frontmatter
- Each skill needs a matching command in `commands/{name}.md`
- Update `using-forge` SKILL.md to list new skills
- Follow TDD for skill creation (per `writing-skills` process): baseline test → write skill → verify
