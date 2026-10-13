#!/usr/bin/env python3
"""Оглавление файлов памяти .forge (stdlib, без PyYAML).

  toc.py <file>                  строка на запись: код/id · дата · начало главного текста
  toc.py <file> --get <код|id>   запись целиком, дословно
  toc.py --journal <.forge> [N]  последние N итогов (по умолчанию 5), новые первыми
"""
import glob
import os
import re
import sys

MAIN_KEYS = ("decision", "summary", "lesson", "learning", "what")
START = re.compile(r"^(\s*)- [A-Za-z_][\w-]*:")


def read_lines(path):
    with open(path, encoding="utf-8") as f:
        return f.read().split("\n")


def split_records(lines):
    """Записи верхнего списка: блоки, начинающиеся с '<отступ>- key:'."""
    starts = [(i, len(m.group(1))) for i, l in enumerate(lines) if (m := START.match(l))]
    if not starts:
        return []
    ind = min(s[1] for s in starts)
    idx = [i for i, n in starts if n == ind]
    recs = []
    for k, i in enumerate(idx):
        end = idx[k + 1] if k + 1 < len(idx) else len(lines)
        block = lines[i:end]
        # хвост: пустые строки и строки с меньшим отступом (новый верхний ключ) — не часть записи
        for j in range(1, len(block)):
            l = block[j]
            if l.strip() and not l.startswith("#") and (len(l) - len(l.lstrip())) <= ind:
                block = block[:j]
                break
        while block and not block[-1].strip():
            block.pop()
        recs.append(block)
    return recs


def clean(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        v = v[1:-1]
    return v


def field(block, key):
    pat = re.compile(r"^\s*(?:- )?" + re.escape(key) + r":\s*(.*)$")
    for i, l in enumerate(block):
        m = pat.match(l)
        if not m:
            continue
        v = m.group(1).strip()
        if v[:1] in ("|", ">"):
            for nxt in block[i + 1:]:
                if nxt.strip():
                    return nxt.strip()
            return ""
        if v == "":
            for nxt in block[i + 1:]:
                if nxt.strip():
                    return nxt.strip().lstrip("- ").strip()
            return ""
        return clean(v)
    return None


def main_text(block):
    for k in MAIN_KEYS:
        v = field(block, k)
        if v:
            return v
    return ""


def one_line(s, n=80):
    return re.sub(r"\s+", " ", s).strip()[:n]


def toc_line(block, n):
    parts = [field(block, "code") or field(block, "id") or f"#{n}", field(block, "date"), one_line(main_text(block))]
    return " · ".join(p for p in parts if p)


def journal(forge, n):
    items = []  # (date, tier, name, block)
    old = os.path.join(forge, "journal.yml")
    if os.path.isfile(old):
        for i, b in enumerate(split_records(read_lines(old))):
            items.append((field(b, "date") or "", 0, f"{i:08d}", b))
    for p in glob.glob(os.path.join(forge, "journal.d", "*.yml")):
        name = os.path.basename(p)
        lines = read_lines(p)
        recs = split_records(lines)
        if not recs:  # без верхнего ключа: поля с нулевого отступа
            body = [l for l in lines if not l.startswith("#") and l.strip() != "entries:"]
            while body and not body[-1].strip():
                body.pop()
            recs = [body] if body else []
        for b in recs:
            date = field(b, "date") or name[:10]
            items.append((date, 1, name, b))
    items.sort(key=lambda t: t[:3], reverse=True)
    out = []
    for _, _, _, b in items[:n]:
        out.extend(b)
        out.append("")
    return "\n".join(out).rstrip("\n")


def main(argv):
    if len(argv) >= 3 and argv[1] == "--journal":
        n = int(argv[3]) if len(argv) > 3 and argv[3].isdigit() else 5
        text = journal(argv[2], n)
        if text:
            print(text)
        return 0
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    recs = split_records(read_lines(argv[1]))
    if len(argv) >= 4 and argv[2] == "--get":
        for n, b in enumerate(recs, 1):
            if argv[3] in (field(b, "code"), field(b, "id"), f"#{n}"):
                print("\n".join(b))
                return 0
        print(f"не найдено: {argv[3]}", file=sys.stderr)
        return 1
    for n, b in enumerate(recs, 1):
        print(toc_line(b, n))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
