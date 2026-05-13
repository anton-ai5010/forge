# Forge

Forge is a complete software development workflow for your coding agents, built on top of a set of composable "skills" and some initial instructions that make sure your agent uses them.

## How it works

It starts from the moment you fire up your coding agent. As soon as it sees that you're building something, it *doesn't* just jump into trying to write code. Instead, it runs you through a four-phase pipeline.

**Phase 1 — Understanding (`new-task`).** Your raw prompt gets turned into a clean task statement with an explicit definition of done. Anything that's a logical or product question comes back to you. Anything technical, Claude researches itself.

**Phase 2 — Planning (`plan`).** Once the task is clear, the agent writes an implementation plan organised around checkpoints rather than micro-steps. Distant blockers get spun out into their own follow-up sessions so the current plan stays focused.

**Phase 3 — Critique (`critique`).** Four personas — Skeptic, Pragmatist, Architect, User Advocate — run in parallel and tear the plan apart. They then write the Execution Strategy section: what runs in parallel, what gets delegated to subagents, where the checkpoints are.

**Phase 4 — Implementation (`execute`).** Once you say "go", implementation happens in the main session. Dirty or parallelisable work goes to subagents. Execution stops at every checkpoint defined in the plan, so you stay in the loop without babysitting.

There's a bunch more to it — TDD, code review, worktree management — but that's the core of the system. And because the skills trigger automatically, you don't need to do anything special. Your coding agent just has Forge.


## Sponsorship

If Forge has helped you do stuff that makes money and you are so inclined, I'd greatly appreciate it if you'd consider [sponsoring my opensource work](https://github.com/sponsors/obra).

Thanks! 

- Jesse


## Installation

**Note:** Installation differs by platform. Claude Code has a built-in plugin system. Codex and OpenCode require manual setup.

### Claude Code (via Plugin Marketplace)

In Claude Code, register the marketplace first:

```bash
/plugin marketplace add obra/forge-marketplace
```

Then install the plugin from this marketplace:

```bash
/plugin install forge@forge-marketplace
```

### Verify Installation

Start a new session and ask Claude to help with something that would trigger a skill (e.g., "help me plan this feature" or "let's debug this issue"). Claude should automatically invoke the relevant forge skill.

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/forge/refs/heads/main/.codex/INSTALL.md
```

**Detailed docs:** [docs/README.codex.md](docs/README.codex.md)

### OpenCode

Tell OpenCode:

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/forge/refs/heads/main/.opencode/INSTALL.md
```

**Detailed docs:** [docs/README.opencode.md](docs/README.opencode.md)

## The Basic Workflow

The core pipeline is four phases. Each phase has its own command, its own output, and a clean handoff to the next.

1. **new-task** (Phase 1: Understanding) — Activates on any new request. Turns a raw prompt into a clean task statement with an explicit definition of done. Logical/product questions go back to you; technical questions Claude researches itself. Optional HTML sketch when the result is visual.

2. **plan** (Phase 2: Planning) — Activates once the task is clear. Builds an implementation plan structured around checkpoints (not micro-steps). Long-range blockers get spun out into their own follow-up sessions instead of bloating the current plan.

3. **critique** (Phase 3: Critique) — Activates on a draft plan. Runs four personas in parallel — Skeptic, Pragmatist, Architect, User Advocate — who tear the plan apart and then write the Execution Strategy section (parallel vs sequential, subagents vs main session, checkpoints).

4. **execute** (Phase 4: Implementation) — Activates with an approved plan. Implementation happens in the main session; dirty/parallelisable work is delegated to subagents. Execution stops at every checkpoint defined in the plan.

Supporting skills:

- **using-git-worktrees** — Creates an isolated workspace on a new branch, runs project setup, verifies clean test baseline.
- **test-driven-development** — Enforces RED-GREEN-REFACTOR: failing test first, minimal code, commit. Code written before tests gets deleted.
- **requesting-code-review** — Reviews work against the plan between checkpoints, reports issues by severity. Critical issues block progress.
- **finishing-a-development-branch** — Verifies tests, presents options (merge/PR/keep/discard), cleans up worktree.

**The agent checks for relevant skills before any task.** Mandatory workflows, not suggestions.

## What's Inside

### Skills Library

**Testing**
- **test-driven-development** - RED-GREEN-REFACTOR cycle (includes testing anti-patterns reference)

**Debugging**
- **systematic-debugging** - 4-phase root cause process (includes root-cause-tracing, defense-in-depth, condition-based-waiting techniques)
- **verification-before-completion** - Ensure it's actually fixed

**Collaboration**
- **new-task** - Phase 1: turn a raw prompt into a clean task + definition of done
- **plan** - Phase 2: build a checkpoint-based implementation plan
- **critique** - Phase 3: four personas tear the plan apart and write Execution Strategy
- **execute** - Phase 4: implement against the plan, stop at every checkpoint
- **dispatching-parallel-agents** - Concurrent subagent workflows
- **requesting-code-review** - Pre-review checklist
- **receiving-code-review** - Responding to feedback
- **using-git-worktrees** - Parallel development branches
- **finishing-a-development-branch** - Merge/PR decision workflow
- **subagent-driven-development** - Fast iteration with two-stage review (spec compliance, then code quality)

**Meta**
- **writing-skills** - Create new skills following best practices (includes testing methodology)
- **using-forge** - Introduction to the skills system

## Philosophy

- **Test-Driven Development** - Write tests first, always
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success

Read more: [Forge for Claude Code](https://blog.fsck.com/2025/10/09/forge/)

## Contributing

Skills live directly in this repository. To contribute:

1. Fork the repository
2. Create a branch for your skill
3. Follow the `writing-skills` skill for creating and testing new skills
4. Submit a PR

See `skills/writing-skills/SKILL.md` for the complete guide.

## Updating

Skills update automatically when you update the plugin:

```bash
/plugin update forge
```

## License

MIT License - see LICENSE file for details

## Support

- **Issues**: https://github.com/obra/forge/issues
- **Marketplace**: https://github.com/obra/forge-marketplace
