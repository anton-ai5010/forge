#!/usr/bin/env python3
"""Render/update the forge:status block in README.md using human names.

Reads .forge/index.yml (now.task slug + now.next text), looks up the
H1 of .forge/tasks/<slug>.md as the human name, optionally fetches the
GitHub milestone title via `gh issue view`, and updates README.md
between <!-- forge:status:start --> / <!-- forge:status:end --> markers.

Graceful: any error → WARN on stderr + exit 0.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

START = "<!-- forge:status:start -->"
END = "<!-- forge:status:end -->"
DASH = "—"


def warn(msg: str) -> None:
    print(f"WARN: {msg}", file=sys.stderr)


def read_h1(path: Path) -> str | None:
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("# "):
                return line[2:].strip()
    except OSError:
        return None
    return None


def get_milestone(issue_num: str) -> str:
    try:
        result = subprocess.run(
            ["gh", "issue", "view", issue_num, "--json", "milestone",
             "-q", ".milestone.title"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            title = result.stdout.strip()
            return title if title and title != "null" else ""
    except (subprocess.SubprocessError, FileNotFoundError, OSError) as e:
        warn(f"gh milestone lookup failed: {e}")
    return ""


def build_block(now_line: str, next_text: str, last_summary: str) -> str:
    return (
        f"{START}\n"
        f"🧭 **Сейчас:** {now_line}\n"
        f"⏭️ **Следующее:** {next_text}\n"
        f"✅ **Недавно:** {last_summary}\n"
        f"{END}"
    )


def update_readme(readme: Path, block: str) -> None:
    if not readme.exists():
        title = Path.cwd().name
        readme.write_text(f"# {title}\n\n{block}\n", encoding="utf-8")
        return

    text = readme.read_text(encoding="utf-8")
    pattern = re.compile(
        re.escape(START) + r".*?" + re.escape(END),
        flags=re.DOTALL,
    )
    if pattern.search(text):
        new_text = pattern.sub(block, text)
    else:
        # find first H1
        lines = text.splitlines(keepends=True)
        h1_idx = next(
            (i for i, ln in enumerate(lines) if ln.startswith("# ")),
            None,
        )
        if h1_idx is not None:
            insert_at = h1_idx + 1
            # ensure blank line before block
            prefix = lines[: insert_at]
            suffix = lines[insert_at:]
            sep_before = "" if (prefix and prefix[-1].endswith("\n\n")) else "\n"
            sep_after = "\n" if (not suffix or not suffix[0].startswith("\n")) else ""
            new_text = "".join(prefix) + sep_before + block + "\n" + sep_after + "".join(suffix)
        else:
            warn("README has neither markers nor H1 — inserting block at top")
            new_text = block + "\n\n" + text

    if new_text != text:
        readme.write_text(new_text, encoding="utf-8")


def main() -> int:
    cwd = Path.cwd()
    index_path = cwd / ".forge" / "index.yml"
    if not index_path.exists():
        return 0  # not a forge project, silent

    try:
        import yaml  # type: ignore
    except ImportError:
        warn("PyYAML not installed — skipping README header render")
        return 0

    try:
        with index_path.open(encoding="utf-8") as f:
            index = yaml.safe_load(f) or {}
    except (yaml.YAMLError, OSError) as e:
        warn(f"failed to parse .forge/index.yml: {e}")
        return 0

    now = index.get("now") or {}
    task_slug = (now.get("task") or "").strip()
    next_text = (now.get("next") or "").strip() or DASH

    # Resolve human name: H1 of tasks/<slug>.md, else use task_slug as-is, else "—"
    human_name = DASH
    if task_slug:
        task_md = cwd / ".forge" / "tasks" / f"{task_slug}.md"
        h1 = read_h1(task_md)
        human_name = h1 if h1 else task_slug

    # Milestone via gh, only if .github-issue-<slug> exists
    milestone = ""
    if task_slug:
        issue_file = cwd / ".forge" / f".github-issue-{task_slug}"
        if issue_file.exists():
            try:
                issue_num = issue_file.read_text(encoding="utf-8").strip()
                if issue_num:
                    milestone = get_milestone(issue_num)
            except OSError as e:
                warn(f"failed to read issue file: {e}")

    now_line = (
        f"{milestone} — {human_name}"
        if milestone and milestone != DASH
        else human_name
    )

    # Last summary from journal
    last_summary = DASH
    journal_path = cwd / ".forge" / "journal.yml"
    if journal_path.exists():
        try:
            with journal_path.open(encoding="utf-8") as f:
                journal = yaml.safe_load(f) or {}
            entries = journal.get("entries") or []
            if entries and isinstance(entries[0], dict):
                s = (entries[0].get("summary") or "").strip()
                if s:
                    last_summary = s
        except (yaml.YAMLError, OSError) as e:
            warn(f"failed to parse journal.yml: {e}")

    block = build_block(now_line, next_text, last_summary)

    try:
        update_readme(cwd / "README.md", block)
    except OSError as e:
        warn(f"failed to update README.md: {e}")
        return 0

    print("README шапка обновлена.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # absolute safety net
        warn(f"unexpected error: {e}")
        sys.exit(0)
