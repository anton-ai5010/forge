---
name: product-mapping
description: "Use when user asks for a project overview, product map, wants to understand the full project, or asks 'what does this project do?' / 'show me the big picture'. Generates an interactive HTML navigator showing business logic flows, entities, and gaps — not code structure, but how the project works as a mechanism. Also trigger when user says 'карта проекта', 'обзор проекта', 'из чего состоит', 'полная картина', 'навигатор', 'product map'."
---

# Product Mapping — Interactive Project Navigator

**Role:** You are a product analyst who explains complex systems to non-technical people. You see past the code to the business logic — not "AuthMiddleware validates JWT" but "проверка авторизации — подтверждает что пользователь тот за кого себя выдаёт". Every description must pass the test: would a smart person who doesn't code understand this?

**Stakes:** A confusing navigator is worse than none — it creates false confidence. If someone reads your output and misunderstands the system, they'll make bad decisions. Clarity over completeness. If you're not sure about something, say so — never fabricate certainty.

**Announce at start:** "Я использую скилл product-mapping для создания навигатора проекта."

## What This Produces

An interactive HTML page with 4 tabs:
- **Картина** — the whole mechanism on one screen (5-8 big blocks connected by arrows)
- **Потоки** — step-by-step flows with forks/decisions (3-7 flows)
- **Детали** — entity cards with "what / why / how to use" (5-15 entities)
- **Дыры** — what's missing or broken (gaps with severity)

Every block is expandable. Inside each — human-readable details. Pink 🔍 blocks show "under the hood" — what actually happens technically, explained simply.

## How It Works

You generate **only JSON data**. A fixed HTML template renders it. This means:
- No risk of broken HTML / black screens
- Fast — you focus on content, not markup
- The template already has all React components, CSS, dark theme

## The Process

### Step 1: Load Context

Load everything available about the project:

```
READ (parallel where possible):
  .forge/index.yml          — L0 project overview
  .forge/map.yml            — structure, red zones
  .forge/status.yml         — working/broken/blocked
  .forge/decisions.yml      — architectural choices
  .forge/dead-ends.yml      — failed approaches
  .forge/infrastructure.yml — Docker, DBs, servers
  README.md                 — project description
  CLAUDE.md                 — project instructions
```

If `.forge/graph.json` exists, query the graph:
```bash
graphify query "main components and data flows" --graph .forge/graph.json --budget 3000
```

If no `.forge/` exists, tell user: "Проект не инициализирован. Запусти `/forge:init` для лучшего результата, или я попробую разобраться по коду."

### Step 2: Identify Flows

Flows are how data/requests/events move through the system. Think of the project as a machine — what goes in, what happens inside, what comes out.

**Dispatch 2 subagents in parallel:**

**Subagent 1 — Flow Extractor:**
```
Analyze the project context provided below and identify 3-7 main business flows.

A flow is a sequence of steps that data or a request goes through.
Examples: "User registration", "Order checkout", "Report generation", "Error handling"

For each flow:
- title: human-readable name (Russian)
- icon: relevant emoji
- description: one sentence — what happens start to finish
- steps: ordered list, each with icon + title + description
- forks: decision points (if any) — question + options
- badge: "основной" / "авто" / "по ситуации" / "1 раз"

Project context:
{paste all loaded context here}
```

**Subagent 2 — Entity + Gap Extractor:**
```
Analyze the project context and identify:

ENTITIES (5-15): the building blocks of the system.
For each entity:
- icon, label (Russian), oneLiner (one sentence)
- what: explain to a non-coder what this is (2-3 sentences)
- benefit: why should I care? What does this give me?
- howTo: 2-3 steps — how to use/interact with this
- inside: 3-5 points about what's inside (expandable details)
- status: "ok" / "warn" (partially working) / missing
- color: pick from #3fb950 (green), #58a6ff (blue), #bc8cff (purple), #f0883e (orange), #4dd0e1 (cyan), #f778ba (pink), #7d8590 (gray)

GAPS (3-7): what's not done, broken, or missing.
For each gap:
- label, description (Russian, one sentence)
- severity: "high" / "medium" / "low"

LANGUAGE RULES:
- NO technical jargon: not "middleware", "ORM", "endpoint"
- YES plain language: "проверка авторизации", "хранилище данных", "точка входа"
- Use analogies where helpful
- If something doesn't work — say so honestly

Project context:
{paste all loaded context here}
```

Wait for both subagents.

### Step 3: Build Big Picture

From the flows and entities, construct the "big picture" — 5-8 blocks showing the entire mechanism:

```
Input → Processing Step 1 → Processing Step 2 → ... → Output
```

Each block in bigPicture has:
- icon, title, description (all Russian, human-readable)
- color: pick one that matches the theme
- details: array of expandable items
  - Regular items: { text: "description" }
  - Warnings: { text: "...", warn: true }
  - Under-the-hood: { text: "🔍 ...", pink: true, infoBlock: { title, lines: [{icon, label, value, sub}] } }
- last: true for the final block (no arrow after it)

The big picture should tell a story. Someone reading top to bottom should understand: "ah, so THIS goes in, THAT happens, and THIS comes out."

### Step 4: Assemble JSON

Combine everything into the data format. Structure:

```json
{
  "project": "Project Name",
  "version": "1.0.0",
  "goal": "One sentence — what this project does",
  "bigPicture": [ ... ],
  "flows": [ ... ],
  "entities": [ ... ],
  "gaps": [ ... ]
}
```

### Step 5: Write Output

1. Find the template:
```bash
TEMPLATE=$(find ~/.claude/plugins -path "*/product-mapping/template-product-map.html" 2>/dev/null | head -1)
```

2. If template not found, tell user and offer to generate full HTML instead (fallback).

3. Read the template, find the `<script id="forge-data" type="application/json">` block, replace its contents with your JSON.

4. Write to project root:
```
{project-root}/product-map.html
```

5. Open in browser:
```bash
xdg-open product-map.html 2>/dev/null || open product-map.html 2>/dev/null
```

6. Report:
```
Навигатор создан: product-map.html
Открыт в браузере.

4 таба:
  🔗 Картина — весь механизм на одном экране
  ⚙️ Потоки — {N} потоков с развилками
  🧩 Детали — {N} сущностей
  🚨 Дыры — {N} проблем

Данные сохранены в .forge/product-map.json
```

Also extract and save the raw JSON from the HTML for future updates:
```bash
python3 -c "
import re, sys
html = open('product-map.html').read()
m = re.search(r'<script id=\"forge-data\"[^>]*>(.*?)</script>', html, re.DOTALL)
if m: open('.forge/product-map.json','w').write(m.group(1).strip())
"
```

## Language Rules

This is critical. Every description must be:

- **Russian** (unless the project is English-only)
- **No jargon**: not "endpoint", "middleware", "ORM", "JWT"
- **Plain language**: "точка входа для запросов", "проверка прав доступа", "хранилище данных"
- **Analogies**: "как чеклист пилота", "как библиотека — каталог на входе"
- **Honest**: if something doesn't work, say "не реализовано" not "в процессе"

Test: would your grandma understand the title? No → rewrite.

## Limits

- Max 8 blocks in big picture
- Max 7 flows
- Max 15 entities
- Max 10 gaps
- If project is too large: ask "Какую часть визуализировать?"
- If no .forge/ and no graphify: work from README + code scan, warn about lower accuracy

## Graphify Integration

If `.forge/graph.json` exists, use it extensively:
- `graphify query "main data flows"` — to identify flows
- `graphify query "key business objects"` — to identify entities
- `graphify explain "ModuleName"` — to understand what a module does
- `graphify path "A" "B"` — to trace connections between components

This is faster and more accurate than reading all source files.
