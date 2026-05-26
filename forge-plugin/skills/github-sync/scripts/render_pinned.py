#!/usr/bin/env python3
"""Update the goals block in a Pinned Issue body between forge:goals markers.

stdin: JSON array of GitHub milestones
argv[1]: path to a temp file holding the current Pinned Issue body
        (the file is read, mutated, and rewritten in place)
"""

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

START_MARKER = "<!-- forge:goals:start -->"
END_MARKER = "<!-- forge:goals:end -->"
PINNED_TITLE = "🗺 Карта проекта"

GROUP_FOCUS = "🔥 Сейчас в фокусе"
GROUP_NEXT = "⏭️ Следующее"
GROUP_LATER = "📅 Потом"
GROUP_DONE = "✅ Готово"

GROUP_ORDER = [GROUP_FOCUS, GROUP_NEXT, GROUP_LATER, GROUP_DONE]


def warn(msg):
    print(f"[render_pinned] WARN: {msg}", file=sys.stderr)


def parse_priority(description):
    """Return integer priority from description or None."""
    if not description:
        return None
    m = re.search(r"^\s*priority\s*:\s*(\d+)\s*$", description, re.MULTILINE | re.IGNORECASE)
    if m:
        try:
            return int(m.group(1))
        except ValueError:
            return None
    return None


def human_description(description):
    """Description text minus the `priority: N` line, joined into one phrase."""
    if not description:
        return ""
    lines = []
    for line in description.splitlines():
        if re.match(r"^\s*priority\s*:\s*\d+\s*$", line, re.IGNORECASE):
            continue
        stripped = line.strip()
        if stripped:
            lines.append(stripped)
    return " ".join(lines)


def classify_group(milestone, priority):
    if milestone.get("state") == "closed":
        return GROUP_DONE
    if priority == 1:
        return GROUP_FOCUS
    if priority in (2, 3):
        return GROUP_NEXT
    return GROUP_LATER


def last_activity_label(milestone):
    raw = milestone.get("updated_at") or milestone.get("created_at")
    if not raw:
        return "—"
    try:
        ts = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return "—"
    now = datetime.now(timezone.utc)
    delta_days = (now - ts).days
    if delta_days < 1:
        return "сегодня"
    if delta_days < 7:
        return f"{delta_days}д назад"
    if delta_days < 30:
        return f"{delta_days // 7}нед назад"
    return f"{delta_days // 30}мес назад"


def render_milestone(milestone):
    title = milestone.get("title", "(без названия)")
    closed = milestone.get("closed_issues", 0) or 0
    open_ = milestone.get("open_issues", 0) or 0
    total = closed + open_
    pct = int(round(closed * 100 / total)) if total > 0 else 0
    activity = last_activity_label(milestone)
    desc = human_description(milestone.get("description", ""))

    line = f"- **{title}** — `[{closed}/{total}] {pct}%` · {activity}"
    if desc:
        line += f"\n  _{desc}_"
    return line


def build_block(milestones):
    if not milestones:
        return "Карта пока пустая. Запусти `/forge:roadmap` чтобы добавить первые цели."

    buckets = {g: [] for g in GROUP_ORDER}
    for m in milestones:
        if m.get("title", "").strip() == PINNED_TITLE:
            continue
        priority = parse_priority(m.get("description", ""))
        group = classify_group(m, priority)
        buckets[group].append((priority if priority is not None else 9999, m))

    parts = ["## Цели проекта (полный список)"]
    has_any = False
    for group in GROUP_ORDER:
        items = buckets[group]
        if not items:
            continue
        has_any = True
        items.sort(key=lambda pair: pair[0])
        parts.append("")
        parts.append(f"### {group}")
        parts.append("")
        for _, m in items:
            parts.append(render_milestone(m))

    if not has_any:
        return "Карта пока пустая. Запусти `/forge:roadmap` чтобы добавить первые цели."

    return "\n".join(parts).strip() + "\n"


def splice_into_body(body, block):
    new_section = f"{START_MARKER}\n{block}\n{END_MARKER}"
    pattern = re.compile(
        re.escape(START_MARKER) + r".*?" + re.escape(END_MARKER),
        re.DOTALL,
    )
    if pattern.search(body):
        return pattern.sub(new_section, body)
    warn("markers not found in body — appending block at the end")
    suffix = "" if body.endswith("\n") else "\n"
    return f"{body}{suffix}\n{new_section}\n"


def main():
    if len(sys.argv) < 2:
        warn("usage: render_pinned.py <body-file>")
        return 0

    body_path = Path(sys.argv[1])

    try:
        raw = sys.stdin.read()
        milestones = json.loads(raw) if raw.strip() else []
        if not isinstance(milestones, list):
            warn("stdin JSON is not a list — treating as empty")
            milestones = []
    except Exception as e:
        warn(f"failed to parse stdin JSON: {e}")
        milestones = []

    try:
        body = body_path.read_text(encoding="utf-8") if body_path.exists() else ""
    except Exception as e:
        warn(f"failed to read body file {body_path}: {e}")
        body = ""

    try:
        block = build_block(milestones)
        new_body = splice_into_body(body, block)
        body_path.write_text(new_body, encoding="utf-8")
    except Exception as e:
        warn(f"failed to render/write body: {e}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
