#!/bin/bash
# Сверяет места запуска помощников и frontmatter агентов с таблицей docs/model-roles.md.
# Usage: bash tests/hooks/test-model-roles.sh

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

python3 - "$ROOT" <<'EOF'
import re, sys, os
root = sys.argv[1]
doc = open(os.path.join(root, 'docs/model-roles.md')).read()

def rows(marker):
    block = doc.split(f'<!-- {marker}:start -->')[1].split(f'<!-- {marker}:end -->')[0]
    out = []
    for line in block.strip().splitlines()[2:]:
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        out.append(cells)
    return out

fails = 0
def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    if not ok: fails += 1

for f, anchor, model in rows('inventory'):
    lines = open(os.path.join(root, f)).read().splitlines()
    idx = next((i for i, l in enumerate(lines) if anchor in l), None)
    if idx is None:
        check(False, f'{f}: нет якоря «{anchor}»'); continue
    # первая модель, упомянутая на строке якоря или в 6 строках после — она и должна совпасть
    window = '\n'.join(lines[idx:idx + 7])
    m = re.search(r'forge:scout|model:\s*"?(haiku|sonnet|opus)\b', window)
    got = None if m is None else ('scout' if m.group(0) == 'forge:scout' else m.group(1))
    check(got == model, f'{f} «{anchor}» → ждём {model}, в тексте {got}')

for f in sorted({r[0] for r in rows('inventory')} - {'commands/sync.md'} - {r[0] for r in rows('inventory') if r[0].endswith('-prompt.md')}):
    check('docs/model-roles.md' in open(os.path.join(root, f)).read(), f'{f}: ссылка на docs/model-roles.md')

check('## Когда отдавать помощнику' in doc, 'docs/model-roles.md: раздел «Когда отдавать помощнику»')
for s in ('refine-idea', 'plan', 'problem-investigation', 'systematic-debugging', 'execute'):
    check('Когда отдавать помощнику' in open(os.path.join(root, f'skills/{s}/SKILL.md')).read(), f'skills/{s}: ссылка на «Когда отдавать помощнику»')

for name, model, effort, turns in rows('agents'):
    fm = open(os.path.join(root, f'agents/{name}.md')).read().split('\n---\n')[0]
    get = lambda k: (re.search(rf'^{k}:\s*(\S+)', fm, re.M) or [None, '—'])[1]
    check((get('model'), get('effort'), get('maxTurns')) == (model, effort, turns),
          f'agents/{name}.md: model={get("model")} effort={get("effort")} maxTurns={get("maxTurns")}')

for f in os.listdir(os.path.join(root, 'agents')):
    check('model: inherit' not in open(os.path.join(root, 'agents', f)).read(), f'agents/{f}: не наследует модель')

print(f'\n{"OK" if not fails else f"{fails} FAIL"}')
sys.exit(1 if fails else 0)
EOF
