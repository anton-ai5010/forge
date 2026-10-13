#!/usr/bin/env python3
"""Проставляет стабильные коды DEC-NN записям .forge/decisions.yml (stdlib, без PyYAML).

Запись списка: строка `  - id: <x>`. Если в записи нет `code:` — после строки id
вставляется `    code: DEC-NN` (следующий номер после максимального). Остальное не трогается.
Использование: decision-codes.py [путь к decisions.yml]  (по умолчанию .forge/decisions.yml)
"""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else ".forge/decisions.yml"
with open(path, encoding="utf-8", newline="") as f:
    lines = f.read().split("\n")

ID_RE = re.compile(r"^(\s*)- id:\s")
CODE_RE = re.compile(r"^\s*code:\s*[\"']?DEC-(\d+)")

# границы записей: от строки id до следующей записи или строки с меньшим отступом
starts = [i for i, l in enumerate(lines) if ID_RE.match(l)]
entries = []
for n, s in enumerate(starts):
    indent = len(ID_RE.match(lines[s]).group(1))
    end = len(lines)
    for j in range(s + 1, len(lines)):
        l = lines[j]
        if l.strip() and (len(l) - len(l.lstrip())) <= indent and not l.lstrip().startswith("#"):
            end = j
            break
    entries.append((s, end, indent))

maxn = 0
has_code = []
for s, end, _ in entries:
    found = None
    for l in lines[s + 1:end]:
        m = CODE_RE.match(l)
        if m:
            found = int(m.group(1))
            break
    has_code.append(found is not None)
    if found:
        maxn = max(maxn, found)

inserts = []  # (индекс строки id, текст)
nxt = maxn
for (s, _, indent), ok in zip(entries, has_code):
    if not ok:
        nxt += 1
        inserts.append((s, " " * (indent + 2) + "code: DEC-%02d" % nxt))

for s, text in reversed(inserts):
    lines.insert(s + 1, text)

if inserts:
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines))
print("добавлено кодов: %d" % len(inserts))
