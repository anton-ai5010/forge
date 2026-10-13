#!/usr/bin/env python3
"""drift-check.py — автопроверка расхождений код/доки. Только stdlib.

Запуск из корня проекта:
  python3 drift-check.py [--write] [--days N] [--count]

Что проверяет:
  1. Пути в .forge/map.yml, .forge/conventions.yml и CLAUDE.md.
     Путь-кандидат — латинское слово из букв/цифр/_.-/ с "/" внутри, которое
     заканчивается на "/" (папка) или на известное расширение файла (md, sh, py,
     yml, json, js, html, ...). Голые имена файлов без "/" не проверяются (шум).
     Пропускаются: URL, плейсхолдеры (<…>, *, {…}, vX.Y, YYYY, NN), абсолютные и
     ~-пути, .forge/… (создаётся по требованию), guide/shots, кириллица, «a/b/c» без расширения и без хвостового "/".
     Путь живой, если он есть от корня проекта ИЛИ от любой верхнеуровневой папки,
     где лежит .claude-plugin/ (в этом репо — forge-plugin/), ИЛИ является хвостом /
     началом любого файла из git ls-files (иначе обход диска): так "criteria/"
     находится в evals/criteria/.
  2. "Доки без правки N дней": последний коммит .forge/ старше последнего коммита
     остального кода (без .forge/ и CLAUDE.md) больше чем на N дней (по умолчанию 30).
  --write: записывает расхождения в .forge/status.yml в секцию `drift:`
     (записи what/found/truth). Наши записи начинаются с "drift-check:" — их секция
     пересобирается целиком (дублей нет, закрытое уходит); чужие записи не трогаются.
  --count: печатает только число расхождений (для хука).
"""
import os
import re
import subprocess
import sys

EXTS = {"md", "sh", "py", "yml", "yaml", "json", "js", "ts", "html", "css", "mp3", "txt", "toml", "tsv", "jsonl"}
TOKEN = re.compile(r"[^\s\"'`,;()\[\]]+")
PREFIX = "drift-check:"
SKIP_DIRS = {".git", "node_modules", "__pycache__"}


def sh(args, cwd):
    try:
        return subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception:
        return ""


def candidates(text):
    seen = []
    for line in text.splitlines():
        for tok in TOKEN.findall(line):
            tok = tok.rstrip(":.,")
            if "/" not in tok or "://" in tok or tok.startswith(("/", "~", "-")):
                continue
            if not re.fullmatch(r"[A-Za-z0-9_.\-/]+", tok) or re.search(r"[vV]?X\.Y|YYYY|NN", tok):
                continue
            last = tok.rsplit("/", 1)[-1]
            ext = last.rsplit(".", 1)[-1].lower() if "." in last else ""
            if not tok.endswith("/") and ext not in EXTS:
                continue
            if tok.startswith(".forge/") or tok.startswith("guide/shots"):
                continue  # память проекта создаётся по требованию — не дрейф
            if tok.strip("/") in ("", ".", "..") or re.fullmatch(r"[\d./]+", tok):
                continue
            if tok not in seen:
                seen.append(tok)
    return seen


def tracked_paths(root):
    out = sh(["git", "ls-files"], root)
    if out:
        return out.splitlines()
    res = []
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        res += [os.path.relpath(os.path.join(d, f), root) for f in files]
    return res


def plugin_roots(root):
    roots = [root]
    for e in sorted(os.listdir(root)):
        if os.path.isdir(os.path.join(root, e, ".claude-plugin")):
            roots.append(os.path.join(root, e))
    return roots


def check_paths(root):
    roots = plugin_roots(root)
    tracked = None
    found = []
    for rel in (".forge/map.yml", ".forge/conventions.yml", "CLAUDE.md"):
        p = os.path.join(root, rel)
        if not os.path.isfile(p):
            continue
        with open(p, encoding="utf-8", errors="replace") as f:
            text = f.read()
        for tok in candidates(text):
            if any(os.path.exists(os.path.join(r, tok)) for r in roots):
                continue
            if tracked is None:
                tracked = tracked_paths(root)
            if any(("/" + tok) in ("/" + t) or t.startswith(tok) for t in tracked):
                continue
            found.append((rel, tok))
    return found


def check_stale(root, days):
    if not os.path.isdir(os.path.join(root, ".git")) and not sh(["git", "rev-parse", "--git-dir"], root):
        return None
    docs = sh(["git", "log", "-1", "--format=%ct", "--", ".forge"], root)
    code = sh(["git", "log", "-1", "--format=%ct", "--", ".", ":(exclude).forge", ":(exclude)CLAUDE.md"], root)
    if not docs or not code:
        return None
    gap = (int(code) - int(docs)) // 86400
    return gap if gap > days else None


def write_status(root, entries):
    path = os.path.join(root, ".forge", "status.yml")
    if not os.path.isfile(path):
        return
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    start = next((i for i, l in enumerate(lines) if re.match(r"drift:", l)), None)
    kept = []
    if start is not None:
        end = start + 1
        while end < len(lines) and (lines[end] == "" or lines[end][0] in " \t-#"):
            end += 1
        block = lines[start + 1:end]
        trail = []
        while block and block[-1] == "":
            trail.append(block.pop())
        # чужие записи: блоки, начинающиеся с "  - ", но не с нашего префикса
        cur = []
        for l in block:
            if re.match(r"\s*- ", l):
                cur = [l]
                kept.append(cur)
            elif cur:
                cur.append(l)
        kept = [c for c in kept if PREFIX not in c[0]]
        rest_before, rest_after = lines[:start], lines[end - len(trail):]
    else:
        rest_before, rest_after = lines, []
        while rest_before and rest_before[-1] == "":
            rest_before.pop()
            rest_after.append("")
    new = []
    for c in kept:
        new += c
    for what, found, truth in entries:
        new += [f'  - what: "{PREFIX} {what}"', f'    found: "{found}"', f'    truth: "{truth}"']
    section = ["drift:"] + new if new else ["drift: []"]
    if start is None and not new:
        return
    out = rest_before + section + rest_after
    if start is None and (not rest_after or rest_after[-1] != ""):
        out.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out))


def main(argv):
    days, write, count = 30, False, False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--write":
            write = True
        elif a == "--count":
            count = True
        elif a == "--days" and i + 1 < len(argv):
            i += 1
            days = int(argv[i])
        i += 1
    root = os.getcwd()
    msgs, entries = [], []
    for rel, tok in check_paths(root):
        msgs.append(f"путь не найден: {tok} (упомянут в {rel})")
        entries.append((f"{rel} → {tok}", f"путь упомянут в {rel}", "на диске его нет: поправить доку или вернуть файл"))
    gap = check_stale(root, days)
    if gap is not None:
        msgs.append(f"доки без правки {gap} дн.: .forge/ старше кода больше чем на {days} дн.")
        entries.append(("доки без правки", f"последний коммит .forge/ старше кода на {gap} дн. (порог {days})", "запустить /forge:sync"))
    if write:
        write_status(root, entries)
    if count:
        print(len(msgs))
    else:
        for m in msgs:
            print(m)
        print(f"расхождений: {len(msgs)}")


if __name__ == "__main__":
    main(sys.argv[1:])
