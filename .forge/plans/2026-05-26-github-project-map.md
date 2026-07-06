# План: GitHub Project Map (v2 — после критики)

**Задача:** см. [.forge/tasks/2026-05-26-github-project-map.md](../tasks/2026-05-26-github-project-map.md)

**Подход:** Один централизованный bash-скрипт `skills/github-sync/sync.sh` инкапсулирует все вызовы `gh` CLI. Тяжёлый рендеринг (markdown для Pinned Issue, шапка README) вынесен в отдельные Python-скрипты `skills/github-sync/scripts/*.py` (паттерн как в `ui-ux-design/scripts/`). Существующие скиллы (new-task / plan / critique / execute / forge-context) в конце своих процессов добавляют вызов нужного `sync.sh <action>`. Новая команда `/forge:roadmap` — обёртка над новым скиллом `roadmap` для управления картой целей; на первом запуске обязательно знакомит Антона с целями (не даёт авто-создаваться "целям из задач"). Включается флагом `github_sync: true` в `.forge/index.yml`; молча выключается если нет GitHub remote — но **громко предупреждает** если флаг включён а `gh auth` сломан.

**Что выкинуто после критики:**
- **Projects v2 board** (исходные Шаги 4 и 11) — дублирует Pinned Issue, требует `gh auth scope project` которого нет у 80% юзеров, сложный GraphQL setup
- **Семантический авто-матч "молча"** — заменён на explicit подтверждение Антоном или явный roadmap-init если карта пустая
- **Чекпоинт D как отдельная остановка** — слит с финалом

**Что добавлено после критики:**
- Smoke-test gh CLI syntax + scope-check в Шаге 1 (15 находок Скептика про сломанные команды)
- Roadmap-init на первом запуске (находка №1 Адвоката — без неё карта = список задач)
- Reassign-task action и триггеры "переcyдь" в roadmap skill (находка №4 Адвоката — критерий не закрыт)
- Громкое warning при сломанном `gh auth` (находка №9 Адвоката — иначе тихо не работает)
- Title задачи из H1 файла, а не из slug имени (находка №2 Скептика + №2 Адвоката)
- Dedup проверка перед `gh issue create` (находка №3 Скептика)
- Substep mapping в файл для корректного close (находка №4 Скептика)
- journal.yml update при close_task (находка №11 Адвоката)
- Mobile-friendly прогресс `[3/12] 25%` (находка №7 Адвоката)
- Python вынесен в `scripts/*.py`, не inline heredoc (А3 Архитектора + P3 Прагматика)
- `.forge/.github-*` явно в gitignore пользователя (находка А2 Архитектора)
- Решения зафиксированы в `.forge/decisions.yml` (А1, А4 Архитектора)

**Открытые вопросы:** нет

**Блокеры:** нет

---

## Шаг 1: Конфигурация + детектор + smoke test gh

**Файлы:**
- Создать: `forge-plugin/skills/github-sync/SKILL.md` — frontmatter, краткое описание
- Создать: `forge-plugin/skills/github-sync/sync.sh` — каркас с `check_enabled`, `OWNER`/`REPO` resolve, scope check, smoke test

**Что делаем:**

```bash
#!/usr/bin/env bash
set -euo pipefail
action="${1:-help}"

# Глобально резолвим OWNER/REPO (не полагаемся на {owner}/{repo} substitution)
OWNER=""; REPO=""
resolve_repo() {
    OWNER=$(gh repo view --json owner -q .owner.login 2>/dev/null) || return 1
    REPO=$(gh repo view --json name -q .name 2>/dev/null) || return 1
}

# Тихая проверка
check_enabled() {
    [ -f ".forge/index.yml" ] || return 1
    grep -q "^github_sync:[[:space:]]*true" .forge/index.yml || return 1
    git config --get remote.origin.url 2>/dev/null | grep -qE "github\.com" || return 1
    command -v gh >/dev/null 2>&1 || return 1
    gh auth status >/dev/null 2>&1 || return 1
    resolve_repo || return 1
    return 0
}

# Громкая диагностика: если флаг включён но что-то сломано — расскажи Антону
diagnose() {
    [ -f ".forge/index.yml" ] || return 0
    grep -q "^github_sync:[[:space:]]*true" .forge/index.yml || return 0
    # Флаг включён, проверяем по шагам
    git config --get remote.origin.url 2>/dev/null | grep -qE "github\.com" || { echo "⚠ github_sync: true, но у репозитория нет GitHub remote. Sync отключён." >&2; return 1; }
    command -v gh >/dev/null 2>&1 || { echo "⚠ github_sync: true, но gh CLI не установлен. Установи: https://cli.github.com/" >&2; return 1; }
    gh auth status >/dev/null 2>&1 || { echo "⚠ github_sync: true, но gh не авторизован или токен истёк. Запусти: gh auth login" >&2; return 1; }
    resolve_repo || { echo "⚠ github_sync: true, но не получается определить owner/repo. Проверь git remote." >&2; return 1; }
    return 0
}

case "$action" in
    enabled) check_enabled && echo "yes" || echo "no" ;;
    diagnose) diagnose && echo "ok" ;;
    *) echo "unknown action: $action" >&2; exit 1 ;;
esac
```

В index.yml формат: top-level `github_sync: true` (не nested).

**Как проверим:**
- `bash sync.sh enabled` → `yes`
- Убрать флаг → `no`
- Поставить флаг но `gh auth logout` → `sync.sh diagnose` печатает в stderr "⚠ gh не авторизован, запусти: gh auth login"

---

## Шаг 2: Bootstrap — лейблы фаз

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — добавить action `bootstrap-labels`

**Что делаем:**

```bash
bootstrap_labels() {
    check_enabled || return 0
    declare -A labels=(
        [phase-1]="cccccc"
        [phase-2]="c5def5"
        [phase-3]="fef2c0"
        [phase-4]="c2e0c6"
        [done]="0e8a16"
        [project-map]="d4c5f9"
    )
    for name in "${!labels[@]}"; do
        gh label create "forge:$name" --color "${labels[$name]}" --description "forge pipeline" 2>/dev/null || true
    done
}

# Helper для смены лейбла фазы (снимает все forge:phase-*, ставит новый) — устойчиво к set -e
relabel_phase() {
    local issue_num="$1" new_phase="$2"
    for p in phase-1 phase-2 phase-3 phase-4 done; do
        gh issue edit "$issue_num" --remove-label "forge:$p" 2>/dev/null || true
    done
    gh issue edit "$issue_num" --add-label "forge:$new_phase" 2>/dev/null || true
}
```

**Как проверим:** `gh label list | grep forge:` показывает 6 лейблов.

---

## Шаг 3: Bootstrap — Pinned Issue с graceful pin limit

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — добавить `ensure_pinned_map`
- Создать: `skills/github-sync/templates/project-map.md` — начальный шаблон

**Что делаем:**

```bash
ensure_pinned_map() {
    check_enabled || return 0
    local num
    # Найти existing — приоритет по лейблу, fallback по title
    num=$(gh issue list --label "forge:project-map" --state open --json number -q '.[0].number')
    if [ -z "$num" ]; then
        num=$(gh issue list --search "in:title \"🗺 Карта проекта\"" --state open --json number -q '.[0].number')
        # Если нашли по title — повесить лейбл
        [ -n "$num" ] && gh issue edit "$num" --add-label "forge:project-map" 2>/dev/null || true
    fi
    if [ -z "$num" ]; then
        local body
        body=$(cat "$CLAUDE_PLUGIN_ROOT/skills/github-sync/templates/project-map.md")
        # gh issue create возвращает URL, не JSON
        local url
        url=$(gh issue create --title "🗺 Карта проекта" --body "$body" --label "forge:project-map")
        num="${url##*/}"
        # Pin — может упасть если уже 3 запинено
        gh issue pin "$num" 2>/dev/null || echo "⚠ не смог запинить — у тебя уже 3 pinned issues. Открепи неактуальные и запусти sync ещё раз." >&2
    fi
    echo "$num" > .forge/.github-pinned-id
}
```

Шаблон `templates/project-map.md`:
```markdown
## Цели проекта

Карта пока пустая. Запусти `/forge:roadmap` чтобы добавить первые цели.

<!-- forge:goals:start -->
<!-- forge:goals:end -->
```

**Как проверим:** `gh issue list --label forge:project-map` — 1 закреплённый Issue. Если уже 3 pinned — на stderr предупреждение, но скрипт не падает.

---

## Шаг 4: Roadmap-init — обязательное знакомство с целями при первом запуске

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — добавить `roadmap-init-needed` action
- Изменить: будет использовано в Шаге 5 (new-task hook)

**Что делаем:**

```bash
# Проверяет: пустая ли карта целей (0 milestones)?
roadmap_init_needed() {
    check_enabled || { echo "disabled"; return 0; }
    local count
    count=$(gh api "repos/$OWNER/$REPO/milestones?state=all&per_page=1" --jq 'length')
    [ "$count" -eq 0 ] && echo "yes" || echo "no"
}
```

Логика в new-task SKILL.md (см. Шаг 5): если `roadmap-init-needed` = `yes` — **не создавать Issue молча**, а инвокнуть скилл `roadmap` для начального знакомства (см. Шаг 12).

**Как проверим:** на свежем репо без milestones — `sync.sh roadmap-init-needed` = `yes`. После создания первой цели — `no`.

---

### ✅ Чекпоинт A: Bootstrap готов

Что показываем: открываешь репо в браузере → 6 forge-лейблов, закреплённый Issue "🗺 Карта проекта", graceful обработка лимита pin. `sync.sh diagnose` показывает понятную ошибку если что-то сломано.

Что подтверждает пользователь: "разметка появилась, ничего не сломалось".

Следующее: подключение фаз пайплайна.

---

## Шаг 5: `/forge:new-task` hook — Issue из H1, dedup, явная привязка

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — добавить `create-task <task-file> <milestone-num>`
- Изменить: `forge-plugin/skills/new-task/SKILL.md` — шаг 9.5

**Что делаем:**

```bash
create_task() {
    check_enabled || return 0
    local task_file="$1" milestone_num="${2:-}"
    local slug title body url issue_num
    slug=$(basename "$task_file" .md)

    # Dedup — если уже есть pointer, переиспользовать
    if [ -f ".forge/.github-issue-$slug" ]; then
        issue_num=$(cat ".forge/.github-issue-$slug")
        [ -n "$issue_num" ] && { echo "issue $issue_num уже существует для $slug"; return 0; }
    fi

    # Title из H1, не из slug
    title=$(awk '/^# /{sub(/^# /,""); print; exit}' "$task_file")
    [ -z "$title" ] && title="$slug"  # fallback

    body=$(cat "$task_file")

    local args=(--title "$title" --body "$body" --label "forge:phase-1")
    [ -n "$milestone_num" ] && args+=(--milestone "$milestone_num")

    url=$(gh issue create "${args[@]}")
    issue_num="${url##*/}"
    echo "$issue_num" > ".forge/.github-issue-$slug"
}
```

В `new-task/SKILL.md` после шага 9 (сохранение `.forge/tasks/`):

```markdown
### Шаг 9.5: Синхронизация с GitHub

1. `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh enabled` — если `no` → пропускаем всю секцию.
2. `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh roadmap-init-needed` — если `yes`:
   - **НЕ создавать Issue молча**. Сказать пользователю: "У тебя в проекте пока нет целей в карте — нужно их назвать прежде чем привязывать задачи. Запускаю /forge:roadmap."
   - Инвокать skill `roadmap` с режимом `init`. Дождаться завершения. Перепроверить `roadmap-init-needed` — если опять `yes` (пользователь отменил) → создать Issue без milestone и сказать "создал без привязки".
3. Получить список открытых milestones: `gh api "repos/$OWNER/$REPO/milestones?state=open&per_page=100" --jq '.[] | {n: .number, t: .title, d: .description}'`
4. **Семантически сматчить** задачу к цели:
   - Прочитай title задачи и description каждой цели
   - Если есть явный кандидат с высокой уверенностью — выбери его номер
   - Если несколько подходят или ни одна — **спросить Антона одной фразой**: "Привязываю к цели 'X' — или скажи 'к цели Y', или 'новая цель'."
5. `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh create-task <task-file> <milestone-num>`
6. Одной строкой: "Привязал к цели 'X'" (с человеческим именем цели)
```

**Как проверим:** `/forge:new-task` на свежем репо → запускается roadmap-init, после создания целей → Claude явно показывает выбор → Issue создан с правильным title из H1, привязан к выбранной цели, файл `.forge/.github-issue-<slug>` создан.

---

## Шаг 6: `/forge:plan` hook — sub-issues с substep mapping

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — добавить `add-steps <task-slug> <plan-file>`
- Изменить: `forge-plugin/skills/plan/SKILL.md` — шаг 7.5

**Что делаем:**

```bash
add_steps() {
    check_enabled || return 0
    local task_slug="$1" plan_file="$2"
    local parent
    parent=$(cat ".forge/.github-issue-$task_slug" 2>/dev/null)
    [ -n "$parent" ] || { echo "sync: no parent issue for $task_slug, skipping" >&2; return 0; }

    local parent_node_id mapping_file
    parent_node_id=$(gh issue view "$parent" --json id -q .id)
    mapping_file=".forge/.github-substeps-$task_slug"

    # Идемпотентность: если mapping уже есть — переиспользовать
    [ -f "$mapping_file" ] && { echo "substeps уже созданы для $task_slug"; relabel_phase "$parent" phase-2; return 0; }

    > "$mapping_file"
    grep -E "^## Шаг " "$plan_file" | while IFS= read -r line; do
        local step_num step_title url sub_num sub_node_id
        step_title=$(echo "$line" | sed 's/^## //')
        step_num=$(echo "$step_title" | sed -E 's/^Шаг ([0-9]+).*/\1/')

        url=$(gh issue create --title "$step_title" --body "Часть #$parent" --label "forge:phase-2")
        sub_num="${url##*/}"
        sub_node_id=$(gh issue view "$sub_num" --json id -q .id)

        # GraphQL addSubIssue
        gh api graphql -f query="mutation { addSubIssue(input: {issueId: \"$parent_node_id\", subIssueId: \"$sub_node_id\"}) { issue { id } } }" >/dev/null 2>&1 || true

        echo "$step_num:$sub_num" >> "$mapping_file"
    done

    relabel_phase "$parent" phase-2
}
```

В `plan/SKILL.md` после "Сохрани план":
```markdown
### Шаг 7.5: GitHub-sync
- `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh add-steps <task-slug> <plan-file>`
```

**Как проверим:** `/forge:plan` создаёт N sub-issues под parent, файл `.forge/.github-substeps-<slug>` содержит `step_num:issue_num` mapping, лейбл родителя → `forge:phase-2`. Повторный вызов — идемпотентен.

---

## Шаг 7: `/forge:critique` hook — comment + label

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — `add-critique <task-slug> <summary-file>`
- Изменить: `forge-plugin/skills/critique/SKILL.md`

**Что делаем:**

```bash
add_critique() {
    check_enabled || return 0
    local task_slug="$1" summary_file="$2"
    local parent
    parent=$(cat ".forge/.github-issue-$task_slug" 2>/dev/null)
    [ -n "$parent" ] || { echo "sync: no parent for $task_slug" >&2; return 0; }
    [ -f "$summary_file" ] || { echo "sync: no summary file $summary_file" >&2; return 0; }
    gh issue comment "$parent" --body-file "$summary_file"
    relabel_phase "$parent" phase-3
}
```

В `critique/SKILL.md` в шаге 4 (после применения правок):
```markdown
- Записать summary блокеров+важного в `/tmp/forge-critique-<slug>.md`
- `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh add-critique <task-slug> /tmp/forge-critique-<slug>.md`
```

**Как проверим:** в parent Issue появляется комментарий с критикой, лейбл → `forge:phase-3`.

---

## Шаг 8: `/forge:execute` hooks — close через mapping + journal update

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — `close-step <task-slug> <step-num>`, `close-task <task-slug>`, `reassign-task <task-slug> <new-milestone-num>`
- Изменить: `forge-plugin/skills/execute/SKILL.md`

**Что делаем:**

```bash
close_step() {
    check_enabled || return 0
    local task_slug="$1" step_num="$2"
    local mapping_file=".forge/.github-substeps-$task_slug"
    [ -f "$mapping_file" ] || { echo "sync: no substeps mapping" >&2; return 0; }
    local sub_num
    sub_num=$(grep "^$step_num:" "$mapping_file" | cut -d: -f2)
    [ -n "$sub_num" ] && gh issue close "$sub_num" 2>/dev/null || true
}

close_task() {
    check_enabled || return 0
    local task_slug="$1"
    local parent
    parent=$(cat ".forge/.github-issue-$task_slug" 2>/dev/null)
    [ -n "$parent" ] || return 0
    relabel_phase "$parent" done
    gh issue close "$parent" 2>/dev/null || true

    # Запись в .forge/journal.yml — критерий №4 готовности
    local issue_title milestone_title
    issue_title=$(gh issue view "$parent" --json title -q .title)
    milestone_title=$(gh issue view "$parent" --json milestone -q '.milestone.title // "—"')
    python3 - "$task_slug" "$issue_title" "$milestone_title" <<'PYEOF'
import sys, datetime, pathlib
slug, title, milestone = sys.argv[1:4]
p = pathlib.Path('.forge/journal.yml')
date = datetime.date.today().isoformat()
entry = f"""\n  - date: "{date}"
    summary: "Закрыта задача: {title}"
    milestone: "{milestone}"
    slug: "{slug}"
    result: "Done"
"""
if p.exists():
    c = p.read_text()
    if 'entries:' in c:
        c = c.replace('entries:', f'entries:{entry}', 1)
    else:
        c = f'entries:{entry}\n' + c
else:
    c = f'entries:{entry}\n'
p.write_text(c)
PYEOF
}

reassign_task() {
    check_enabled || return 0
    local task_slug="$1" new_milestone="$2"
    local parent
    parent=$(cat ".forge/.github-issue-$task_slug" 2>/dev/null)
    [ -n "$parent" ] || return 0
    gh issue edit "$parent" --milestone "$new_milestone" 2>/dev/null || gh issue edit "$parent" --milestone ""
}
```

В `execute/SKILL.md`:
- В шаге 3 (после завершения каждого шага плана): `sync.sh close-step <task-slug> <step-num>`
- В шаге 7 (финальный отчёт): `sync.sh close-task <task-slug>` затем `sync.sh sync-all` (см. Шаг 11)
- Триггер "переcyдь" / "не туда" → переcyдь к цели — описано в `roadmap/SKILL.md`, вызывает `sync.sh reassign-task`

**Как проверим:** sub-issues закрываются по правильному step_num (не по глобальному поиску), родитель закрыт с лейблом `forge:done`, в `.forge/journal.yml` появилась entry.

---

### ✅ Чекпоинт B: Task-level sync end-to-end

Что показываем: прогнать тестовую задачу через 4 фазы — Issue, sub-issues, comment, closure по mapping, journal entry.

Что подтверждает пользователь: "конвейер видно в GitHub, никаких дублей и потерянных Issue".

Следующее: project map (README + Pinned).

---

## Шаг 9: README header sync — human names, fallback на отсутствие H1

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — добавить `sync-readme`
- Создать: `skills/github-sync/scripts/render_readme_header.py` — рендеринг

**Что делаем:**

```bash
sync_readme() {
    check_enabled || return 0
    # Передаём данные через env, чтобы не страдать с escape
    python3 "$CLAUDE_PLUGIN_ROOT/skills/github-sync/scripts/render_readme_header.py"
}
```

`scripts/render_readme_header.py`:
```python
#!/usr/bin/env python3
"""
Обновляет шапку README.md между маркерами <!-- forge:status:start --> и <!-- forge:status:end -->.
Источник: .forge/index.yml (now.task), .forge/journal.yml (последняя summary).
Использует HUMAN NAMES: title из H1 task-файла, не slug.
"""
import re, pathlib, subprocess, os
try: import yaml
except ImportError:
    print("WARN: PyYAML not installed; pip install pyyaml", file=__import__('sys').stderr)
    raise SystemExit(0)

def human_name_for_task(slug):
    """Извлечь H1 из .forge/tasks/<slug>.md если есть."""
    if not slug: return None
    p = pathlib.Path(f'.forge/tasks/{slug}.md')
    if not p.exists(): return slug
    for line in p.read_text().splitlines():
        if line.startswith('# '): return line[2:].strip()
    return slug

def fetch_milestone_for_slug(slug):
    """Если у задачи есть GitHub Issue с milestone — вернуть title milestone."""
    pointer = pathlib.Path(f'.forge/.github-issue-{slug}')
    if not pointer.exists(): return None
    issue_num = pointer.read_text().strip()
    if not issue_num: return None
    try:
        result = subprocess.run(['gh', 'issue', 'view', issue_num, '--json', 'milestone', '-q', '.milestone.title'],
                                capture_output=True, text=True, timeout=10)
        return result.stdout.strip() or None
    except Exception:
        return None

# Читаем index.yml
idx = yaml.safe_load(pathlib.Path('.forge/index.yml').read_text())
now_slug = idx.get('now', {}).get('task', '')
next_text = idx.get('now', {}).get('next', '')

# Журнал
journal = pathlib.Path('.forge/journal.yml')
last_summary = ''
if journal.exists():
    j = yaml.safe_load(journal.read_text())
    entries = (j or {}).get('entries') or []
    if entries: last_summary = entries[0].get('summary', '')

now_human = human_name_for_task(now_slug) or now_slug
milestone = fetch_milestone_for_slug(now_slug)
now_line = f"{milestone} — {now_human}" if milestone and milestone != '—' else now_human

block = f"""<!-- forge:status:start -->
🧭 **Сейчас:** {now_line or '—'}
⏭️ **Следующее:** {next_text or '—'}
✅ **Недавно:** {last_summary or '—'}
<!-- forge:status:end -->"""

readme = pathlib.Path('README.md')
if not readme.exists():
    # Fallback: создать минимальный README
    repo_name = os.path.basename(os.getcwd())
    readme.write_text(f"# {repo_name}\n\n{block}\n")
else:
    c = readme.read_text()
    if '<!-- forge:status:start -->' in c:
        c = re.sub(r'<!-- forge:status:start -->.*?<!-- forge:status:end -->', block, c, flags=re.DOTALL)
    else:
        lines = c.split('\n')
        inserted = False
        for i, l in enumerate(lines):
            if l.startswith('# '):
                lines.insert(i+1, '\n' + block + '\n')
                inserted = True
                break
        if not inserted:
            # H1 нет — вставить в начало с предупреждением
            print("WARN: no H1 in README.md; inserting status block at top", file=__import__('sys').stderr)
            lines.insert(0, block + '\n')
        c = '\n'.join(lines)
    readme.write_text(c)

print("README shapка обновлена.")
```

**Как проверим:** `bash sync.sh sync-readme` → README.md содержит блок между маркерами с человеческими именами (milestone + H1 задачи), а не slug. Если нет H1 — fallback вставляет в начало с warning в stderr.

---

## Шаг 10: Pinned Issue sync — mobile-friendly, last activity

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — `sync-pinned`
- Создать: `skills/github-sync/scripts/render_pinned.py`

**Что делаем:**

```bash
sync_pinned() {
    check_enabled || return 0
    local pinned_num
    pinned_num=$(cat .forge/.github-pinned-id 2>/dev/null) || { ensure_pinned_map; pinned_num=$(cat .forge/.github-pinned-id); }
    [ -n "$pinned_num" ] || return 0

    local milestones_json tmp
    milestones_json=$(gh api "repos/$OWNER/$REPO/milestones?state=all&per_page=100")
    tmp=$(mktemp)
    gh issue view "$pinned_num" --json body -q .body > "$tmp"

    python3 "$CLAUDE_PLUGIN_ROOT/skills/github-sync/scripts/render_pinned.py" "$tmp" <<<"$milestones_json"

    gh issue edit "$pinned_num" --body-file "$tmp"
    rm "$tmp"
}
```

`scripts/render_pinned.py`:
```python
#!/usr/bin/env python3
"""
Обновляет тело Pinned Issue.
- stdin: JSON массив milestones
- argv[1]: путь к temp файлу с текущим body, его перезаписываем
- Mobile-friendly: [3/12] 25%, не unicode-блоки
- Group: 🔥 Сейчас (priority:1) / ⏭️ Следующее (2-3) / 📅 Потом (4+) / ✅ Готово (closed)
- Каждая цель: title + human description + прогресс + last activity
"""
import json, re, sys, pathlib, datetime

body_file = pathlib.Path(sys.argv[1])
milestones = json.loads(sys.stdin.read())

def priority(m):
    desc = m.get('description') or ''
    match = re.search(r'priority:\s*(\d+)', desc)
    return int(match.group(1)) if match else 5

def status(m):
    if m['state'] == 'closed': return '✅ Готово'
    p = priority(m)
    if p == 1: return '🔥 Сейчас в фокусе'
    if p <= 3: return '⏭️ Следующее'
    return '📅 Потом'

def human_desc(m):
    desc = m.get('description') or ''
    # Убираем priority: N\n из начала
    lines = [l for l in desc.splitlines() if not l.startswith('priority:')]
    return ' '.join(l.strip() for l in lines if l.strip()) or ''

def last_activity_days(m):
    upd = m.get('updated_at') or m.get('created_at')
    if not upd: return None
    try:
        dt = datetime.datetime.fromisoformat(upd.replace('Z', '+00:00'))
        return (datetime.datetime.now(dt.tzinfo) - dt).days
    except Exception:
        return None

groups = {}
for m in sorted(milestones, key=priority):
    groups.setdefault(status(m), []).append(m)

out = ["## Цели проекта (полный список)\n"]
for g in ['🔥 Сейчас в фокусе', '⏭️ Следующее', '📅 Потом', '✅ Готово']:
    if g not in groups: continue
    out.append(f"### {g}\n")
    for m in groups[g]:
        opened, closed = m['open_issues'], m['closed_issues']
        total = opened + closed
        pct = int(closed * 100 / total) if total else 0
        line = f"- **{m['title']}** — `[{closed}/{total}] {pct}%`"
        days = last_activity_days(m)
        if days is not None:
            if days == 0: line += " · сегодня"
            elif days < 7: line += f" · {days}д назад"
            elif days < 30: line += f" · {days // 7}нед назад"
            else: line += f" · {days // 30}мес назад"
        out.append(line)
        d = human_desc(m)
        if d: out.append(f"  _{d}_")
    out.append('')

new_block = '\n'.join(out)
c = body_file.read_text()
c = re.sub(r'<!-- forge:goals:start -->.*?<!-- forge:goals:end -->',
           f'<!-- forge:goals:start -->\n{new_block}\n<!-- forge:goals:end -->',
           c, flags=re.DOTALL)
body_file.write_text(c)
```

**Как проверим:** обновить Pinned Issue — открыть на телефоне, прогресс не съезжает за экран, секции читаемы. `[3/12] 25% · 2д назад` под каждой целью.

---

## Шаг 11: `sync-all` + хук на финал execute

**Файлы:**
- Изменить: `skills/github-sync/sync.sh` — `sync-all`
- Изменить: `forge-plugin/skills/execute/SKILL.md` — финальный шаг

**Что делаем:**

```bash
sync_all() {
    check_enabled || return 0
    sync_readme
    sync_pinned
}
```

В `execute/SKILL.md` шаг 7:
```markdown
### Финал: обновить карту проекта
- `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh sync-all`
- Одной строкой: "Карта проекта обновлена"
```

**Как проверим:** прогнать задачу до конца — после execute README шапка и Pinned Issue обновлены. Projects v2 board — НЕ обновляется (его нет, осознанное решение).

---

### ✅ Чекпоинт C: Project map работает

Что показываем: репо проекта — README с человеческой шапкой, Pinned Issue с полной картой целей mobile-friendly, journal.yml пополнен. Никакой Projects board (выкинули как дубль).

Что подтверждает пользователь: "захожу — сразу понимаю где я".

Следующее: roadmap skill, start enhancement, документация.

---

## Шаг 12: Скилл `roadmap` + команда `/forge:roadmap`

**Файлы:**
- Создать: `forge-plugin/skills/roadmap/SKILL.md`
- Создать: `forge-plugin/commands/roadmap.md` (тонкая обёртка)

**Что делаем:**

`roadmap/SKILL.md`:
```markdown
---
name: roadmap
description: "Use when the user wants to manage project goals — triggers: 'добавь цель', 'переименуй цель', 'переставь приоритеты', 'удали цель', 'покажи карту проекта', 'переcyдь на цель', 'не туда привязал', 'это к другой цели', 'перепривяжи задачу', 'не та цель', 'почисти карту'. Also use INIT mode when github_sync включён в новом проекте и в карте 0 целей (вызывается из new-task)."
---

# Roadmap — управление картой проекта

## Режим INIT (вызывается из /forge:new-task при пустой карте)

1. Сказать Антону простым языком: "У тебя пока нет крупных целей в этом проекте. Назови 2-3 направления одной фразой каждое — например 'добавить онлайн-оплату', 'почистить старый код', 'мобильная версия'."
2. Дождаться ответа. Принимать как угодно: список, голосом, через запятую.
3. Для каждого направления — ОДИН вопрос: "В чём суть '<название>' одной фразой?" (для описания, которое потом используется в Pinned Issue + семантическом матче)
4. Распределить по приоритетам автоматически: первая названная = priority 1 (Сейчас), вторая = 2, третья = 3. Не спрашивать число.
5. Для каждой — создать milestone: `gh api -X POST "repos/$OWNER/$REPO/milestones" -f title="<название>" -f description="priority: N\n<описание>"`
6. `bash sync.sh sync-pinned` чтобы обновилась карта.
7. "Карта готова. Возвращаюсь к твоей задаче."

## Режим обычный (/forge:roadmap или явные триггеры)

1. `bash sync.sh diagnose` — если sync не работает, объяснить Антону почему.
2. Получить milestones: `gh api "repos/$OWNER/$REPO/milestones?state=all" --jq '.[] | "\(.number)|\(.title)|\(.state)|\(.description)"'`
3. Показать списком простым языком: "У тебя 5 целей. Сейчас: X (priority 1), Y (priority 2). Потом: Z. Готово: W."
4. Спросить ОДНОЙ фразой что хочешь делать. Понимать естественные формулировки:
   - "добавь цель X" / "новая цель" → переход к диалогу добавления
   - "переименуй X в Y" → PATCH title
   - "переcyдь задачу X на цель Y" / "не туда привязал" / "перепривяжи к Y" → вызов `sync.sh reassign-task <slug> <new-milestone-num>`
   - "поставь X в сейчас" / "X в следующее" / "X отложить" → PATCH description (меняем priority по human language, не по числу)
   - "удали цель X" → DELETE
   - "почисти карту" → показать open Issues старше 14 дней по каждой цели, спросить по каждой "это актуально или закрыть?"
5. После любого изменения — `bash sync.sh sync-pinned && sync.sh sync-readme`
6. "Сделано. Карта обновлена."

## Что НЕ делать

- Не спрашивать "какой приоритет — 1, 2 или 3?" — выводи из контекста или из human language
- Не показывать сырые номера milestone — используй названия
- Не дампить полный список 20 целей — сначала сводку, детали по запросу
```

`commands/roadmap.md`:
```markdown
---
description: "Управление картой целей проекта — добавить, переименовать, переcyдить, почистить"
disable-model-invocation: true
---

Invoke the forge:roadmap skill and follow it exactly.
```

**Как проверим:**
- `/forge:roadmap` на пустой карте → диалог INIT, создаёт 2-3 milestone с описаниями
- "переcyдь задачу github-project-map на цель Y" → Issue перепривязан, Pinned обновлён
- "почисти карту" → показывает старые Issues, предлагает закрыть

---

## Шаг 13: `/forge:start` — человеческий дашборд, не сырой markdown

**Файлы:**
- Изменить: `forge-plugin/commands/start.md`

**Что делаем:**

В `commands/start.md` после Step 2 (загрузка `.forge/`):

```markdown
### Карта проекта из GitHub (если есть)

!`if [ -f .forge/.github-pinned-id ] && command -v gh >/dev/null 2>&1; then gh issue view $(cat .forge/.github-pinned-id) --json body -q .body 2>/dev/null > /tmp/.forge-pinned-body.md && echo "PINNED_BODY_AT:/tmp/.forge-pinned-body.md"; fi`
```

В `Step 3: Common-Ground Check` инструкция Claude'у:
- Если выше есть `PINNED_BODY_AT:` — прочитать файл и **сжать в 5-7 строк** простым языком: "Цель сейчас: X (прогресс 3/12, last 2д назад). Последняя закрытая задача: Y. Открытых задач: 2 шт."
- Не показывать сырой markdown, эмодзи-бары, маркеры `<!-- -->`

**Как проверим:** `/forge:start` в новой сессии → дашборд показывает сжатую человеческую сводку с GitHub карты, не сырой markdown.

---

## Шаг 14: Документация + decisions + gitignore

**Файлы:**
- Изменить: `CLAUDE.md` — добавить раздел про `github_sync: true` + `/forge:roadmap`
- Изменить: `forge-plugin/README.md` — про новый скилл/команду
- Изменить: `forge-plugin/COMMANDS.md` — `/forge:roadmap`
- Изменить: `.forge/decisions.yml` плагина — записать решения:
  - `id: github-sync-via-skill-not-hook` — почему не PostToolUse хук (фаза завершается не одним tool-call'ом, нужна точка после серии операций)
  - `id: gh-cli-not-mcp-from-bash` — почему `gh` CLI а не MCP github (логика в bash-скрипте, MCP только из Claude tool_use)
  - `id: no-projects-v2-board` — почему выкинули (дублирует Pinned Issue, требует non-default scope)
- Изменить: `.forge/map.yml` плагина — добавить `skills/github-sync/`, `skills/roadmap/`
- Изменить: `.forge/conventions.yml` плагина — маркеры `<!-- forge:status:* -->` и `<!-- forge:goals:* -->`
- Изменить: `forge-plugin/.gitignore` или документация для пользователя — `.forge/.github-*` не коммитятся (runtime state)

**Как проверим:** прочитать обновлённые файлы — все 3 новых решения зафиксированы, runtime артефакты явно в gitignore.

---

## Execution Strategy

### Делать в основной сессии (требует решений / диалога)
- Шаг 4 (roadmap-init logic) — затрагивает UX
- Шаг 5 (new-task интеграция) — затрагивает существующий скилл, нужна аккуратность
- Шаг 12 (roadmap skill) — много текста SKILL.md с триггерами, нужна вычитка
- Шаг 13 (start) — аккуратно править существующую команду
- Шаг 14 (документация) — финальная стыковка

### Делегировать субагентам (грязная работа)
- Шаги 9-10 (Python рендереры) — `general-purpose` агент пишет render_readme_header.py и render_pinned.py за одну итерацию, возвращает diff
- Шаг 6-8 (bash действия) — `general-purpose` пишет функции add_steps/close_step/close_task в sync.sh, возвращает результат
- Smoke-test gh CLI команд — отдельный субагент проверяет на тестовом репо `gh issue create`, парсинг URL, scope check, возвращает working snippets

### Параллельно (одновременно через субагентов)
- Шаги 9 и 10 (два независимых Python скрипта) — в одном сообщении 2 Agent вызова
- Шаг 12 (roadmap SKILL.md) + Шаг 14 (документация) — независимы, параллельно

### Последовательно (зависимости)
- 1 → 2 → 3 → 4 → ✅ Чекпоинт A — bootstrap должен пройти до интеграции
- 5 → 6 → 7 → 8 → ✅ Чекпоинт B — task-level sync по фазам
- 9, 10 параллельно → 11 → ✅ Чекпоинт C — рендеринг → объединение
- 12, 13, 14 параллельно → финал

### Чекпоинты
- **A** (после Шага 4): bootstrap + roadmap-init готовы
- **B** (после Шага 8): task-level sync end-to-end
- **C** (после Шага 11): project map работает
- **Финал** (после Шага 14): документация + всё проверено

### Контекст-стратегия

Контекст текущего чата уже **тяжёлый** (35+ ходов, прочитаны все скиллы, 4 персоны критики). Для Phase 4 (Execute) **сильно рекомендуется новый чат** — свежий контекст даст меньше ошибок к концу плана. Передать в новый чат:

```
/forge:execute план .forge/plans/2026-05-26-github-project-map.md

Ветка: feat/github-project-map (уже создана)
Контекст: .forge/tasks/2026-05-26-github-project-map.md + сам план содержат всё нужное.
```
