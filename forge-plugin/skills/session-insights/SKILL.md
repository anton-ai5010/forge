---
name: session-insights
description: "Use when user wants to analyze their past conversations with Claude Code for the current project — extract pain points, recurring themes, unresolved problems, idea evolution, communication style. Triggers on: 'проанализируй диалоги', 'что мы обсуждали', 'инсайты из сессий', 'session insights', 'история разговоров', 'паттерны общения', 'что я чаще всего спрашиваю', 'analyze my conversations', 'what did we discuss'."
---

# Session Insights — Анализ диалогов с Claude Code

**Role:** You are a conversation analyst who reads between the lines. You don't just count words — you understand what the user was trying to achieve, where they got stuck, what frustrated them, and how their thinking evolved. You write for a human, not for a machine.

**Stakes:** Bad insights are worse than no insights — they create a false picture. If you report "user struggles with deployment" when the real issue is "user doesn't understand the project structure", every future session starts with wrong assumptions. Be honest about what you see.

**Announce at start:** "Анализирую историю диалогов для этого проекта."

## What This Produces

1. **Markdown report** in console — 6 sections covering pain points, themes, unresolved issues, idea evolution, communication style, and user profile
2. **Memory files** — key insights saved to `~/.claude/projects/{slug}/memory/` for future sessions

## The Process

### Phase 1: Extract Messages

Determine the project slug and extract user messages from JSONL conversation logs. Run this Python script via Bash:

```python
import json, os, sys

# Determine project slug from cwd
cwd = os.getcwd()
slug = cwd.replace('/', '-')
projects_dir = os.path.expanduser('~/.claude/projects')
proj_path = os.path.join(projects_dir, slug)

if not os.path.isdir(proj_path):
    print(f"NO_SESSIONS_FOUND:{slug}")
    sys.exit(0)

# Collect all JSONL files
jsonl_files = sorted(
    [f for f in os.listdir(proj_path) if f.endswith('.jsonl')],
    key=lambda f: os.path.getmtime(os.path.join(proj_path, f))
)

if not jsonl_files:
    print(f"NO_SESSIONS_FOUND:{slug}")
    sys.exit(0)

# Extract user text messages with deduplication
sessions = []
seen_keys = set()

for fname in jsonl_files:
    fpath = os.path.join(proj_path, fname)
    
    # Skip files > 5MB — take only last portion
    fsize = os.path.getsize(fpath)
    
    messages = []
    session_id = fname.replace('.jsonl', '')[:8]
    
    with open(fpath, 'r', errors='ignore') as f:
        for line in f:
            try:
                msg = json.loads(line)
            except (json.JSONDecodeError, UnicodeDecodeError):
                continue
            
            if msg.get('type') != 'user':
                continue
            
            timestamp = msg.get('timestamp', '')
            content = msg.get('message', {})
            if not isinstance(content, dict):
                continue
            
            items = content.get('content', '')
            if not isinstance(items, list):
                continue
            
            for item in items:
                if not isinstance(item, dict) or item.get('type') != 'text':
                    continue
                txt = item['text'].strip()
                
                # Skip noise
                if not txt:
                    continue
                if txt.startswith('<ide_'):
                    continue
                if txt.startswith('{') and 'tool_use_id' in txt[:80]:
                    continue
                if txt in ('[Request interrupted by user]', '[Request interrupted by user for tool use]'):
                    continue
                # Skip skill invocation boilerplate
                if txt.startswith('Invoke the ') and 'skill and follow' in txt[:80]:
                    continue
                if txt.startswith('Base directory for this skill:'):
                    continue
                
                messages.append((timestamp, txt))
    
    if not messages:
        continue
    
    # Dedup by first 3 messages
    dedup_key = tuple(m[1][:50] for m in messages[:3])
    if dedup_key in seen_keys:
        continue
    seen_keys.add(dedup_key)
    
    sessions.append((session_id, messages))

# Output
total_msgs = sum(len(msgs) for _, msgs in sessions)
print(f"STATS: {len(sessions)} sessions, {total_msgs} user messages")
print(f"SLUG: {slug}")
print("---")

# If too many messages, keep last 500
all_msgs = []
for sid, msgs in sessions:
    for ts, txt in msgs:
        all_msgs.append((ts, sid, txt))

if len(all_msgs) > 500:
    all_msgs = all_msgs[-500:]
    print("WARNING: Truncated to last 500 messages")

for ts, sid, txt in all_msgs:
    # Escape newlines in message for single-line format
    clean = txt.replace('\n', ' ↵ ')[:500]
    print(f"[{sid}] [{ts}] {clean}")
```

Save the script output. If output says `NO_SESSIONS_FOUND` — tell the user "Нет истории диалогов для этого проекта" and stop.

Read the output file to verify extraction worked. Note the SLUG value for Phase 3.

### Phase 2: Parallel Analysis

Dispatch 4 agents simultaneously (single message, 4 Agent tool calls). Each agent receives the extracted messages via the task prompt — paste the full extraction output into each agent's prompt.

**Agent A — Pain Points & Frustrations:**
```
You are analyzing a user's conversation history with Claude Code.
Your task: find moments of pain, frustration, confusion, and failure.

Look for:
- Explicit frustration: "не работает", "не понимаю", "не то", "стоп", "погоди", "ты не ответил"
- Repeated requests (user asked the same thing multiple times — Claude didn't get it)
- Interruptions (user stopped Claude mid-response)
- Long messages after short Claude responses (user had to over-explain)
- Escalating tone or punctuation (???, !!!)
- Moments where user corrected Claude's direction

For each pain point found, provide:
- The actual user quote (shortened)
- What the underlying problem was
- Whether it was resolved or not

Output format — a numbered list, sorted by severity (most painful first).
Write in Russian.

Here are the extracted messages:
{PASTE EXTRACTION OUTPUT HERE}
```

**Agent B — Themes & Evolution:**
```
You are analyzing a user's conversation history with Claude Code.
Your task: identify recurring themes, topic clusters, and how ideas evolved over time.

Look for:
- Topics that appear across multiple sessions
- How the user's understanding of a topic changed (first mention vs latest)
- Abandoned topics (discussed once, never returned)
- Topics that keep coming back (unresolved or important)
- Keyword frequency — what words/concepts appear most

For each theme:
- Name it in 2-3 words
- Count how many sessions it appeared in
- Track evolution: first mention → current state
- Flag if the topic seems resolved or still active

Output format — themes grouped by frequency (most common first), with evolution timeline.
Write in Russian.

Here are the extracted messages:
{PASTE EXTRACTION OUTPUT HERE}
```

**Agent C — Unresolved Issues:**
```
You are analyzing a user's conversation history with Claude Code.
Your task: find discussions that were started but never finished — abandoned threads, unanswered questions, ideas that were discussed but never implemented.

Look for:
- Questions the user asked that were never clearly answered
- Features/ideas discussed but no evidence of implementation
- Problems mentioned but no fix confirmed
- "Потом сделаем" / "давай позже" / topic changes mid-discussion
- Sessions that ended abruptly (last message is a question or request)

For each unresolved item:
- What was being discussed
- How far it got (just an idea / partially done / abandoned)
- The session it appeared in
- Whether it was picked up in a later session

Output format — list sorted by importance (most impactful unresolved items first).
Write in Russian.

Here are the extracted messages:
{PASTE EXTRACTION OUTPUT HERE}
```

**Agent D — Profile & Communication Style:**
```
You are analyzing a user's conversation history with Claude Code.
Your task: build a profile of the user — who they are, how they work, what they prefer.

Analyze:
- Role/expertise: what do they know well, what's new to them?
- Communication style: short vs long messages, formal vs casual, voice input vs typed
- Decision-making: do they plan ahead or iterate? Do they approve quickly or deliberate?
- Preferences: what formats do they like (visual/text/code)? What annoys them?
- Work patterns: do they work in bursts or steady? Single-task or multi-task?
- Language: what language do they write in? Do they mix languages?

For voice input detection, look for: long messages without punctuation, typos/transliteration errors, stream-of-consciousness style.

Output format — structured profile with sections for each aspect above.
Write in Russian.

Here are the extracted messages:
{PASTE EXTRACTION OUTPUT HERE}
```

### Phase 3: Synthesis

After all 4 agents complete, synthesize their results.

#### 3a. Build the Report

Create a markdown report with these 6 sections:

```markdown
# Session Insights: {project name}
*Проанализировано: {N} сессий, {M} сообщений*

## 1. Болевые точки
{From Agent A — top 5-7 pain points, most severe first}

## 2. Повторяющиеся темы
{From Agent B — top themes with session count}

## 3. Нерешённые проблемы
{From Agent C — unresolved items, most impactful first}

## 4. Эволюция идей
{From Agent B — how key ideas changed over time}

## 5. Стиль общения
{From Agent D — communication preferences, work patterns}

## 6. Профиль пользователя
{From Agent D — role, expertise, what they know/don't know}
```

Present this report to the user.

#### 3b. Save to Memory

Save insights as memory files in `~/.claude/projects/{SLUG}/memory/`.

Before writing, check if memory files already exist (read MEMORY.md if it exists). Update existing files rather than creating duplicates.

Create these memory files:

**1. User profile** (`user_profile.md`):
```markdown
---
name: user-profile
description: User role, expertise, projects, work style — extracted from conversation analysis
type: user
---
{Content from Agent D profile section}
```

**2. Communication feedback** (`feedback_communication.md`):
```markdown
---
name: feedback-communication-style
description: How to communicate with this user — preferences extracted from conversation analysis
type: feedback
---
{Content from Agent D communication preferences, formatted as rules with Why/How to apply}
```

**3. Project context** (`project_insights.md`):
```markdown
---
name: project-session-insights
description: Recurring themes, pain points, unresolved issues extracted from conversation history
type: project
---
{Synthesized from Agents A, B, C — key themes, active pain points, open issues}

**Why:** Extracted from {N} conversation sessions on {date}
**How to apply:** Use these insights to anticipate user needs and avoid repeating past mistakes
```

Update MEMORY.md index with one-line pointers to each file.

## Important Constraints

- **Never load raw JSONL into agent context** — always use the Python extraction script first
- **Extraction output goes into agent prompts as text** — don't make agents read files if avoidable, paste the content directly
- **Russian language** — all output in Russian, technical terms can stay in English
- **Honest analysis** — don't fabricate insights. If there's not enough data, say so
- **Privacy** — don't include passwords, API keys, or sensitive data in reports or memory files
- **Freshness** — note when insights might be stale (old sessions about resolved issues)
