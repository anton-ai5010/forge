# Graphify Integration into Forge Plugin — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use forge:executing-plans or forge:subagent-driven-development to implement this plan task-by-task.

**Goal:** Встроить graphify (графовую карту кода) в forge plugin — команда `/forge:graph`, автопостроение при init, автообновление при sync, подсказка во всех скиллах через using-forge + context-inject.

**Architecture:** Graphify CLI вызывается из shell-скриптов и команд Forge. Граф хранится в `.forge/graph.json`. Все скиллы узнают о графе через одну точку — using-forge + context-inject хук. Не меняем каждый скилл по отдельности.

**Tech Stack:** Bash (hooks), Markdown (commands, skills), graphify CLI (Python/pipx)

---

### Task 1: Команда /forge:graph

**Files:**
- Create: `commands/graph.md`

**Step 1: Написать команду**

```markdown
---
description: Build or update code knowledge graph for the project — stores in .forge/graph.json
---

# FORGE Graph — Code Knowledge Map

**Purpose:** Build a navigable graph of code relationships (modules, functions, imports, dependencies) for smarter navigation, debugging, and planning.

## Pre-Check

\`\`\`bash
which graphify 2>/dev/null || echo "NOT_INSTALLED"
\`\`\`

**If NOT_INSTALLED:**
\`\`\`
graphify is not installed. Install it:
  pipx install graphifyy
Then run /forge:graph again.
\`\`\`
Stop.

## Mode Detection

Parse user input for flags:
- `/forge:graph` or `/forge:graph .` → **full build**
- `/forge:graph --update` → **incremental update** (only changed files, no LLM)
- `/forge:graph --query "question"` → **query mode**
- `/forge:graph --path "A" "B"` → **path between nodes**
- `/forge:graph --explain "Node"` → **explain a node**

## Full Build

**Step 1: Detect files**
\`\`\`bash
graphify update . 2>&1 | tail -5
\`\`\`

**Step 2: Move output to .forge/**
\`\`\`bash
cp graphify-out/graph.json .forge/graph.json 2>/dev/null
cp graphify-out/GRAPH_REPORT.md .forge/graph-report.md 2>/dev/null
\`\`\`

**Step 3: Report**
\`\`\`
Graph built: X nodes, Y edges.
Stored in .forge/graph.json
Report: .forge/graph-report.md

Use:
  /forge:graph --query "how does auth work?"
  /forge:graph --path "UserModel" "PaymentService"
  /forge:graph --explain "AuthMiddleware"
\`\`\`

## Incremental Update

\`\`\`bash
graphify update . 2>&1 | tail -3
cp graphify-out/graph.json .forge/graph.json 2>/dev/null
\`\`\`

Report: "Graph updated (incremental)."

## Query Mode

\`\`\`bash
graphify query "QUESTION" --graph .forge/graph.json --budget 2000
\`\`\`

Show result to user.

## Path Mode

\`\`\`bash
graphify path "NODE_A" "NODE_B" --graph .forge/graph.json
\`\`\`

## Explain Mode

\`\`\`bash
graphify explain "NODE" --graph .forge/graph.json
\`\`\`
```

**Step 2: Verify file created**

```bash
cat forge-plugin/commands/graph.md | head -5
```
Expected: frontmatter with description

**Step 3: Commit**

```bash
git add forge-plugin/commands/graph.md
git commit -m "feat: add /forge:graph command for code knowledge graph"
```

---

### Task 2: Автопостроение графа при /forge:init

**Files:**
- Modify: `commands/init.md` — добавить 5-й параллельный агент

**Step 1: Найти секцию Step 1 (параллельные агенты) в init.md**

Добавить после существующих агентов:

```markdown
**Agent 5: Build Code Knowledge Graph (if graphify installed)**

```bash
if which graphify &>/dev/null; then
  graphify update . 2>&1 | tail -3
  cp graphify-out/graph.json .forge/graph.json 2>/dev/null
  cp graphify-out/GRAPH_REPORT.md .forge/graph-report.md 2>/dev/null
  echo "Graph: $(jq '.nodes | length' .forge/graph.json 2>/dev/null || echo '?') nodes"
fi
```

If graphify is not installed — skip silently. Graph is optional.
```

**Step 2: Добавить graph.json в секцию генерации index.yml**

В каталоге L1/L2 ресурсов добавить:

```yaml
  - graph: .forge/graph.json
    tags: [graph, dependencies, architecture, navigate, code-map]
    note: "Code knowledge graph. Use graphify query/path/explain for navigation."
```

**Step 3: Verify changes**

```bash
grep -n "graph" forge-plugin/commands/init.md
```
Expected: lines with graph agent and catalog entry

**Step 4: Commit**

```bash
git add forge-plugin/commands/init.md
git commit -m "feat: build code graph during /forge:init (optional, if graphify installed)"
```

---

### Task 3: Автообновление графа при /forge:sync

**Files:**
- Modify: `commands/sync.md` — добавить graph update параллельно с документатором

**Step 1: Найти Step 2 (Documentation Updater subagent) в sync.md**

Добавить параллельный субагент:

```markdown
**Subagent B (parallel): Graph Updater (if graphify installed and .forge/graph.json exists)**

```bash
if which graphify &>/dev/null && [ -f ".forge/graph.json" ]; then
  graphify update . 2>&1 | tail -3
  cp graphify-out/graph.json .forge/graph.json 2>/dev/null
fi
```

If graph doesn't exist or graphify not installed — skip silently.
```

**Step 2: Verify**

```bash
grep -n "graph" forge-plugin/commands/sync.md
```

**Step 3: Commit**

```bash
git add forge-plugin/commands/sync.md
git commit -m "feat: update code graph during /forge:sync (if exists)"
```

---

### Task 4: Подсказка в context-inject.sh

**Files:**
- Modify: `hooks/context-inject.sh` — добавить graph hint в L0 контекст

**Step 1: После строки 75 (сборка context), перед skill hint — добавить:**

```bash
# Graph hint (if graph exists)
graph_hint=""
if [ -f ".forge/graph.json" ]; then
    node_count=$(python3 -c "import json; print(len(json.load(open('.forge/graph.json')).get('nodes',[])))" 2>/dev/null || echo "?")
    graph_hint="\\n--- Code graph: .forge/graph.json (${node_count} nodes). Use 'graphify query/path/explain --graph .forge/graph.json' before grep/find for navigation."
fi
```

**Step 2: Добавить graph_hint в context (строка 75):**

Изменить:
```bash
context="FORGE L0 CONTEXT (auto-injected):\n\n${index_content}\n\n--- Branch: ${branch}\n--- Recent: ${git_log}"
```
На:
```bash
context="FORGE L0 CONTEXT (auto-injected):\n\n${index_content}\n\n--- Branch: ${branch}\n--- Recent: ${git_log}${graph_hint}"
```

**Step 3: Verify**

```bash
bash -n forge-plugin/hooks/context-inject.sh && echo "syntax ok"
```

**Step 4: Commit**

```bash
git add forge-plugin/hooks/context-inject.sh
git commit -m "feat: inject graph hint into L0 context when .forge/graph.json exists"
```

---

### Task 5: Инструкция в using-forge — одна точка для всех скиллов

**Files:**
- Modify: `skills/using-forge/SKILL.md` — добавить секцию про граф

**Step 1: После секции "The Rule" (после строки ~27), добавить:**

```markdown
## Code Knowledge Graph

If `.forge/graph.json` exists — the project has a code knowledge graph built by graphify.

**Before searching code (grep, find, glob):**
1. First try `graphify query "your question" --graph .forge/graph.json` — it finds relevant code paths in seconds
2. Use `graphify path "ModuleA" "ModuleB" --graph .forge/graph.json` — to trace dependencies between components
3. Use `graphify explain "ClassName" --graph .forge/graph.json` — to understand a node and its neighbors

**This applies to ALL skills.** Whether you're debugging, planning, brainstorming, or reviewing — check the graph first. It's faster and more accurate than grep for understanding architecture.

**If graph doesn't exist** — skip this. Don't suggest building it unless user asks.
```

**Step 2: Verify**

```bash
grep -c "graph" forge-plugin/skills/using-forge/SKILL.md
```
Expected: several matches

**Step 3: Commit**

```bash
git add forge-plugin/skills/using-forge/SKILL.md
git commit -m "feat: add graph usage instructions to using-forge (applies to all skills)"
```

---

### Task 6: Добавить graph в L1 catalog tags (.forge/index.yml template)

**Files:**
- Modify: `commands/init.md` — в шаблоне index.yml добавить graph в catalog

**Step 1: В секции генерации index.yml найти catalog и добавить:**

```yaml
  - graph: .forge/graph.json
    tags: [graph, dependencies, architecture, navigate, code-map, imports, calls]
    note: "Code knowledge graph (graphify). Query: graphify query/path/explain --graph .forge/graph.json"
```

**Step 2: Commit**

```bash
git add forge-plugin/commands/init.md
git commit -m "feat: add graph.json to L1 catalog template in init"
```

---

### Task 7: Обновить COMMANDS.md

**Files:**
- Modify: `COMMANDS.md` — добавить /forge:graph в список команд

**Step 1: Добавить в таблицу команд:**

```markdown
| `/forge:graph` | Построить/обновить графовую карту кода. `--query`, `--path`, `--explain` для навигации |
```

**Step 2: Добавить описание в секцию команд:**

```markdown
## /forge:graph — Графовая карта кода

Строит граф зависимостей кода (модули, функции, импорты, вызовы) через graphify.
Хранится в `.forge/graph.json`. Все скиллы автоматически используют граф для навигации.

**Использование:**
- `/forge:graph` — построить с нуля
- `/forge:graph --update` — обновить только изменённые файлы (быстро, без LLM)
- `/forge:graph --query "как работает авторизация?"` — поиск по графу
- `/forge:graph --path "User" "Payment"` — путь между компонентами
- `/forge:graph --explain "AuthMiddleware"` — объяснение узла

**Требования:** graphify (`pipx install graphifyy`)
**Автоматизация:** строится при `/forge:init`, обновляется при `/forge:sync`
```

**Step 3: Commit**

```bash
git add forge-plugin/COMMANDS.md
git commit -m "docs: add /forge:graph to commands reference"
```

---

## Summary

| Task | Что | Файл | Время |
|------|-----|------|-------|
| 1 | Команда /forge:graph | commands/graph.md (новый) | 3 мин |
| 2 | Граф при init | commands/init.md | 3 мин |
| 3 | Граф при sync | commands/sync.md | 2 мин |
| 4 | Hint в хуке | hooks/context-inject.sh | 3 мин |
| 5 | Инструкция в using-forge | skills/using-forge/SKILL.md | 2 мин |
| 6 | Catalog tags | commands/init.md | 2 мин |
| 7 | Документация | COMMANDS.md | 2 мин |

**Итого: ~17 минут, 7 коммитов**

Ключевое решение: **одна точка интеграции** (using-forge + context-inject) вместо изменения 23 скиллов. Using-forge загружается ВСЕГДА → все скиллы автоматически знают про граф.
