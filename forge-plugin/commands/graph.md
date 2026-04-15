---
description: Build or update code knowledge graph for the project — stores in .forge/graph.json. Use --query, --path, --explain for navigation.
---

# FORGE Graph — Code Knowledge Map

**Purpose:** Build a navigable graph of code relationships (modules, functions, imports, dependencies) using graphify. Stored in `.forge/graph.json` — all Forge skills use it automatically for smarter navigation.

**Announce at start:** "I'm using the forge:graph command to build/query the code knowledge graph."

## Pre-Check

```bash
which graphify 2>/dev/null || echo "NOT_INSTALLED"
```

**If NOT_INSTALLED:**
```
graphify is not installed. Install it:
  pipx install graphifyy    (note: two y's — that's the real PyPI package name)
Then run /forge:graph again.
```
Stop.

## Mode Detection

Parse user input:
- `/forge:graph` or `/forge:graph .` → **build/rebuild graph** (tree-sitter extraction, no LLM needed)
- `/forge:graph --update` → same as above (alias for convenience)
- `/forge:graph --query "question"` → **query mode**
- `/forge:graph --path "A" "B"` → **path between two nodes**
- `/forge:graph --explain "Node"` → **explain a node and its neighbors**

## Build Graph

Both `/forge:graph` and `/forge:graph --update` do the same thing: extract code structure via tree-sitter (fast, deterministic, no LLM cost).

**Step 1: Build graph**
```bash
graphify update . 2>&1 | tail -5
```

**Step 2: Copy output to .forge/**
```bash
mkdir -p .forge
cp graphify-out/graph.json .forge/graph.json 2>/dev/null
cp graphify-out/GRAPH_REPORT.md .forge/graph-report.md 2>/dev/null
```

**Step 3: Report stats**
```bash
node_count=$(python3 -c "import json; d=json.load(open('.forge/graph.json')); print(len(d.get('nodes',d.get('elements',{}).get('nodes',[]))))" 2>/dev/null || echo "?")
edge_count=$(python3 -c "import json; d=json.load(open('.forge/graph.json')); print(len(d.get('links',d.get('edges',d.get('elements',{}).get('edges',[])))))" 2>/dev/null || echo "?")
echo "Nodes: $node_count, Edges: $edge_count"
```

**Step 4: Show summary**
```
Graph built: X nodes, Y edges.
Stored in .forge/graph.json
Report: .forge/graph-report.md

Navigation commands:
  /forge:graph --query "how does auth work?"
  /forge:graph --path "UserModel" "PaymentService"
  /forge:graph --explain "AuthMiddleware"

Graph is now available to all Forge skills automatically.
```

## Query Mode

```bash
graphify query "USER_QUESTION" --graph .forge/graph.json --budget 2000
```

Show the result to user. If result is insufficient, suggest `--dfs` for depth-first or higher `--budget`.

## Path Mode

```bash
graphify path "NODE_A" "NODE_B" --graph .forge/graph.json
```

Shows shortest path between two concepts — useful for understanding how components are connected.

## Explain Mode

```bash
graphify explain "NODE_NAME" --graph .forge/graph.json
```

Shows plain-language explanation of a node and all its direct neighbors.
