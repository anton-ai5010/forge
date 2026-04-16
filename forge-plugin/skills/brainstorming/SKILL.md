---
name: brainstorming
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
---

# Brainstorming Ideas Into Designs

## Автозагруженный контекст

### Провальные подходы (не повторять):
!`cat .forge/dead-ends.yml 2>/dev/null || cat .forge/dead-ends/*.md 2>/dev/null || echo "нет dead-ends"`

### Ключевые решения:
!`cat .forge/decisions.yml 2>/dev/null || cat .forge/decisions.md 2>/dev/null || echo "нет decisions"`

---

## Overview

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design and get user approval.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

<FORGE-GATE>
You MUST read .forge/library/ spec files (spec.yml or spec.json) BEFORE exploring the project in any other way. If you find yourself running `find`, `ls`, `tree`, or reading source code files before reading .forge/library/ — you are violating this gate. STOP and read .forge/library/ first.

You MUST generate and get approval for requirements BEFORE proposing any design approaches. If you find yourself proposing architecture before requirements are approved — STOP.
</FORGE-GATE>

**Role:** You are a principal product architect (15 years, ex-Stripe/Notion — built products from 0→1 and scaled to millions). You were brought in because the previous designs missed critical constraints.
**Stakes:** A design flaw discovered after implementation costs 10x more than one caught now. Explore ruthlessly — every hidden constraint you miss becomes a production incident.

## Anti-Pattern: "This Is Too Simple To Need A Design"

Every project goes through this process. A todo list, a single-function utility, a config change — all of them. "Simple" projects are where unexamined assumptions cause the most wasted work. The design can be short (a few sentences for truly simple projects), but you MUST present it and get approval.

## Think Before Coding

Don't assume — surface tradeoffs:
- **State assumptions explicitly.** If you're making a guess about requirements, say so. Don't silently pick one interpretation.
- **Present multiple interpretations** when the request is ambiguous. Let the user choose.
- **Push back** on approaches that seem overcomplicated. Suggest simpler alternatives.
- **Stop and ask** when confused. A clarifying question now saves a rewrite later.

## Разведка окружения

Перед началом работы проверь доступные инструменты и используй лучшие:
- **MCP серверы:** Serena (символьный анализ кода вместо grep), Playwright (проверка UI), Context7 (актуальная документация библиотек), другие — оцени пользу
- **Плагины/скиллы** Claude Code помимо Forge — задействуй где уместно
- **Инфраструктура:** Docker (поднять и проверить проект), SSH, доступ к БД

## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Load FORGE context (MANDATORY FIRST STEP)** — L0 is auto-injected. Load L1 files in PARALLEL:

   Dispatch 2 subagents simultaneously:
   - Agent 1: Read `.forge/map.yml` (structure + red zones) + `.forge/conventions.yml` (rules)
   - Agent 2: Read `.forge/dead-ends.yml` (failed approaches) + ALL `.forge/library/*/spec.yml` (project knowledge)

   Wait for both. Do NOT read source code — everything is in .forge/library/.
   If neither .forge/index.yml nor .forge/index.md exists, tell user to run /forge:init and STOP.

2. **Confirm understanding of goal** — Restate what you believe the user wants to build and ask for confirmation before proceeding

2.5. **Internet Research (parallel agents)** — After user confirms the goal, formulate 3 search briefs based on the idea and project context (stack, stage, domain). Then dispatch 3 agents IN PARALLEL using Agent tool (single message, 3 tool calls):

   **Agent 1 — Analyst (аналоги и конкуренты):**
   ```
   Search for existing solutions, open source projects, and competitors that solve a similar problem.
   Use WebSearch to find analogues, alternatives, and how others approached this.
   Project context: {{idea description}}, stack: {{project stack}}.
   Return a concise report (max 300 words): what exists, what's useful, what doesn't fit.
   ```

   **Agent 2 — Technologist (технические решения):**
   ```
   Search for libraries, frameworks, APIs, and implementation patterns relevant to this feature.
   Use WebSearch for general search. Use Context7 MCP if the feature involves specific libraries/frameworks.
   Project context: {{idea description}}, stack: {{project stack}}.
   Return a concise report (max 300 words): approaches, tools, pros/cons.
   ```

   **Agent 3 — Critic (риски и ограничения):**
   ```
   Search for common pitfalls, mistakes, limitations, and scaling issues for this type of feature.
   Use WebSearch to find post-mortems, "lessons learned", known issues with similar approaches.
   Project context: {{idea description}}, stack: {{project stack}}.
   Return a concise report (max 300 words): risks, how to mitigate, what to watch out for.
   ```

   Wait for all 3 agents. Synthesize results into a **Research Report** (see format below) and show to user.
   If an agent found nothing useful — mark its section "Релевантных результатов не найдено".
   If ALL agents returned empty — continue to step 3 without blocking.

3. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria. **Use Research Report findings to inform your questions** — reference discovered analogues, suggest approaches found by agents, flag risks identified by Critic.
3.5. **Define requirements** — Based on the clarifying questions, generate a numbered list of requirements. Each requirement has:
   - **ID** (R1, R2, R3...)
   - **Description** — what must be true when this feature is done
   - **Acceptance criteria** — specific, testable conditions (not vague "should work well")
   - **Priority** — must-have / nice-to-have

   Format:
   ```
   Requirements

   Must-Have

   R1: [description]
   AC: [specific testable condition]

   R2: [description]
   AC: [specific testable condition]

   Nice-to-Have

   R5: [description]
   AC: [specific testable condition]
   ```

   Present requirements to user and get explicit approval: "Эти requirements верны? Что добавить/убрать?"

   DO NOT proceed to design (step 4) until requirements are approved.

3.7. **Domain modeling (DDD)** — Before proposing approaches, identify the domain structure:

   **Bounded Contexts** — separate areas of the system where the same words mean different things.
   Example: "Product" in the catalog context (title, description, price) vs "Product" in the warehouse context (weight, dimensions, shelf location).

   **Entities** — objects with a unique ID and lifecycle (statuses, transitions).
   For each entity define: name, key attributes, lifecycle states, what transitions are allowed.
   Example: `Order: draft → paid → shipped → delivered | cancelled`

   **Value Objects** — objects without ID, defined only by their properties. Immutable.
   Example: `Address(street, city, zip)`, `Money(amount, currency)`, `Email(validated string)`

   **Aggregates** — groups of entities managed as a unit through one root entity.
   Example: `Order (root)` manages `OrderItems`. External code talks to Order, never directly to OrderItems.

   **Domain Primitives** — value objects with built-in validation. If created successfully, guaranteed valid.
   Example: `Email` — if `new Email("bad")` throws, then any existing `Email` instance is always valid.

   Present domain model to user:
   ```
   Доменная модель

   Контексты:
     📦 [Context name] — [what it's responsible for]

   Сущности:
     [Name] — [key attributes]
       Жизненный цикл: state1 → state2 → state3
       Агрегат: [manages what]

   Value Objects:
     [Name]([properties]) — immutable, no ID

   Доменные примитивы:
     [Name] — [what it validates]
   ```

   Get user approval: "Доменная модель верна? Что добавить/убрать?"
   DO NOT proceed to approaches until domain model is approved.

4. **Propose 2-3 approaches** — with trade-offs and your recommendation. Approaches must respect the approved domain model — entities, aggregates, and bounded contexts from step 3.7.
5. **Present design** — in sections scaled to their complexity, get user approval after each section
6. **Write design doc** — save to `.forge/plans/YYYY-MM-DD-<topic>-design.md` and commit. Design doc MUST include Requirements section and Domain Model section at the beginning (copy from steps 3.5 and 3.7)

<HARD-GATE>
STOP. Before step 7, verify ALL of the following:
- [ ] Design doc file EXISTS at `.forge/plans/YYYY-MM-DD-<topic>-design.md`
- [ ] Design doc is COMMITTED to git (run `git log --oneline -1` to confirm)
- [ ] Design doc contains sections: Requirements, Domain Model, Research Findings, Architecture, Data Flow, Error Handling, Testing
- [ ] User has EXPLICITLY approved the design ("ок", "да", "согласен", etc.)

If ANY check fails — STOP and fix it. Do NOT proceed to step 7.
Do NOT combine the design doc and implementation plan into one document.
The design doc is the OUTPUT of brainstorming. The plan is the OUTPUT of writing-plans. They are SEPARATE files.
</HARD-GATE>

7. **Transition to implementation** — invoke writing-plans skill to create implementation plan. This is a SEPARATE step that produces a SEPARATE file.

## Process Flow

```dot
digraph brainstorming {
    "Explore project context" [shape=box];
    "Confirm understanding of goal" [shape=box];
    "Internet Research (3 agents)" [shape=box, style=bold];
    "Show Research Report" [shape=box, style=bold];
    "Ask clarifying questions" [shape=box];
    "Define requirements" [shape=box];
    "User approves requirements?" [shape=diamond];
    "Propose 2-3 approaches" [shape=box];
    "Present design sections" [shape=box];
    "User approves design?" [shape=diamond];
    "Write design doc" [shape=box];
    "Invoke writing-plans skill" [shape=doublecircle];

    "Explore project context" -> "Confirm understanding of goal";
    "Confirm understanding of goal" -> "Internet Research (3 agents)";
    "Internet Research (3 agents)" -> "Show Research Report";
    "Show Research Report" -> "Ask clarifying questions";
    "Ask clarifying questions" -> "Define requirements";
    "Define requirements" -> "User approves requirements?";
    "User approves requirements?" -> "Define requirements" [label="no, revise"];
    "User approves requirements?" -> "Propose 2-3 approaches" [label="yes"];
    "Propose 2-3 approaches" -> "Present design sections";
    "Present design sections" -> "User approves design?";
    "User approves design?" -> "Present design sections" [label="no, revise"];
    "User approves design?" -> "Write design doc" [label="yes"];
    "Write design doc" -> "Invoke writing-plans skill";
}
```

**The terminal state is invoking writing-plans.** Do NOT invoke frontend-design, mcp-builder, or any other implementation skill. The ONLY skill you invoke after brainstorming is writing-plans.

## The Process

**Conducting research:**
- After user confirms the goal, formulate 3 search briefs — one per agent role
- Each brief includes: the user's idea in 1-2 sentences, project stack from L0, and the agent's specific search angle
- Launch all 3 agents simultaneously (single message with 3 Agent tool calls)
- Wait for all results, then synthesize into this format:

```
## Research Report

### Аналоги и существующие решения
- [название] — что делает, чем полезно/не подходит для нас
- ...

### Технические подходы
- [подход] — библиотеки/инструменты, плюсы/минусы
- ...

### Риски и ограничения
- [риск] — почему важен, как митигировать
- ...

### Ключевые выводы
1-3 пункта, которые должны повлиять на дизайн
```

- Show the full report to user before proceeding to clarifying questions
- Do NOT ask "should I search?" — research is mandatory for every brainstorming session

**Understanding the idea:**
- Check out the current project state first (files, docs, recent commits)
- Ask questions one at a time to refine the idea
- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Focus on understanding: purpose, constraints, success criteria

**Defining requirements:**
- After clarifying questions, synthesize answers into concrete requirements
- Each requirement must be:
  - **Specific** — not vague ("fast", "user-friendly"), but measurable ("respond in <200ms", "3 clicks max")
  - **Testable** — you can write a test to verify it's met
  - **Prioritized** — must-have vs nice-to-have
- Acceptance criteria must be objective: "When X happens, Y should be true"
- Example of good requirement:
  ```
  R1: Cache API responses to reduce backend load
  AC: 95% of requests to /api/indicators/* return cached data when called within 5 minutes
  Priority: must-have
  ```
- Example of bad requirement (too vague):
  ```
  R1: Make API fast
  AC: Should work well
  ```
- Present ALL requirements to user and get explicit approval before moving to design
- If user suggests changes, revise requirements and get approval again

**Exploring approaches:**
- Propose 2-3 different approaches with trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why

**Presenting the design:**
- Before presenting, verify: Does this touch red zones from map.yml? Does it conflict with conventions.yml? Are external dependencies specified in library/*/spec.yml up to date?
- Once you believe you understand what you're building, present the design
- Scale each section to its complexity: a few sentences if straightforward, up to 200-300 words if nuanced
- Ask after each section whether it looks right so far
- Cover: architecture, components, data flow, error handling, testing
- Be ready to go back and clarify if something doesn't make sense

## After the Design

**Documentation:**
- Write the validated design to `.forge/plans/YYYY-MM-DD-<topic>-design.md`
- Design document structure:
  1. **Requirements** section (copy approved requirements from step 3.5)
  2. **Domain Model** section (copy approved model from step 3.7 — contexts, entities, value objects, aggregates, lifecycles)
  3. **Research Findings** section (key findings from Research Report that influenced the design)
  4. **Architecture** section (system design, components — must align with domain model)
  5. **Data Flow** section (how data moves through the system)
  6. **Error Handling** section (how failures are handled)
  7. **Testing** section (test strategy)
- Use elements-of-style:writing-clearly-and-concisely skill if available
- Commit the design document to git

**Implementation:**
- If the design doc exceeds 150 lines, split it into separate feature docs before proceeding
- Invoke the writing-plans skill to create a detailed implementation plan
- Do NOT invoke any other skill. writing-plans is the next step.

## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present design, get approval before moving on
- **Be flexible** - Go back and clarify when something doesn't make sense
