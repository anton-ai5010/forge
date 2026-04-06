# Implementer Subagent Prompt Template

Use this template when dispatching an implementer subagent.

## Before Dispatching: Stack Hint Injection

Read `.forge/conventions.yml` to detect the project's language/framework.
Then read the matching hint file from `./stack-hints/` and include its content
in the `## Stack-Specific Patterns` section of the prompt below.

**Matching rules:**
| conventions.yml | Hint file |
|---|---|
| `language: python` | `stack-hints/python.md` |
| `language: typescript` or `language: javascript` | `stack-hints/typescript.md` |
| `language: go` | `stack-hints/go.md` |
| framework includes `react`, `next`, `nextjs` | `stack-hints/react.md` |
| task involves database/SQL work | `stack-hints/sql.md` |

Multiple hints can apply (e.g., TypeScript + React + SQL for a Next.js fullstack task).
Only include hints relevant to the specific task — not all project languages.

If no matching hint exists, omit the section entirely.

## Prompt Template

```
Task tool (general-purpose):
  description: "Implement Task N: [task name]"
  prompt: |
    You are implementing Task N: [task name]

    ## Task Description

    [FULL TEXT of task from plan - paste it here, don't make subagent read file]

    ## Context

    [Scene-setting: where this fits, dependencies, architectural context]

    ## Project Context

    If the project has FORGE documentation, read before starting:
    - `.forge/library/[your-working-folder]/spec.yml` — file intents, dependencies, red zones
    - `.forge/conventions.yml` — naming rules, structure patterns, project decisions

    Follow conventions. Respect file intents. If a file is marked red_zone, do not modify
    unless the task explicitly requires it.

    ## Stack-Specific Patterns

    [PASTE CONTENT FROM MATCHING stack-hints/*.md FILE HERE]

    Follow these patterns for this project's stack. They are not suggestions — they are
    the expected idioms. Deviating without reason is a bug.

    ## Before You Begin

    If you have questions about:
    - The requirements or acceptance criteria
    - The approach or implementation strategy
    - Dependencies or assumptions
    - Anything unclear in the task description

    **Ask them now.** Raise any concerns before starting work.

    ## Your Job

    Once you're clear on requirements:
    1. Implement exactly what the task specifies
    2. Write tests (following TDD if task says to)
    3. Verify implementation works
    4. Commit your work
    5. Self-review (see below)
    6. Report back

    Work from: [directory]

    **While you work:** If you encounter something unexpected or unclear, **ask questions**.
    It's always OK to pause and clarify. Don't guess or make assumptions.

    ## Before Reporting Back: Self-Review

    Review your work with fresh eyes. Check:

    **Completeness:**
    - Did I implement everything in the spec? Any missed requirements or edge cases?

    **Quality:**
    - Are names clear and accurate? Is code clean and maintainable?
    - Does it follow the stack patterns above? (type hints, error handling, testing style)

    **Discipline:**
    - Did I avoid overbuilding (YAGNI)? Only what was requested?
    - Did I follow existing patterns in the codebase?

    **Testing:**
    - Do tests verify behavior (not mock behavior)?
    - Did I follow TDD if required? Are tests comprehensive?

    If you find issues during self-review, fix them now before reporting.

    ## Report Format

    When done, report:
    - What you implemented
    - What you tested and test results
    - Files changed
    - Self-review findings (if any)
    - Any issues or concerns
```
