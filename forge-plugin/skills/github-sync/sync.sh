#!/usr/bin/env bash
# forge github-sync — синхронизирует пайплайн с GitHub Issues/Sub-issues + карту проекта
# (Pinned Issue + README шапка). Вызывается из скиллов new-task/critique/execute/roadmap.
# Тихо no-op если выключено; громко предупреждает если включено но сломано.
# Slug-контракт: <task-slug> = имя task-файла без датного префикса и .md (см. normalize_slug).
#
# Документация: SKILL.md рядом.

set -euo pipefail

# ============ ГЛОБАЛЬНОЕ ============

OWNER=""
REPO=""
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

resolve_repo() {
    OWNER=$(gh repo view --json owner -q .owner.login 2>/dev/null) || return 1
    REPO=$(gh repo view --json name -q .name 2>/dev/null) || return 1
    return 0
}

# Тихая проверка: можно ли синкать
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
    [ -f ".forge/index.yml" ] || { echo "⚠ .forge/index.yml не найден — sync выключен (это нормально если ты не в forge-проекте)." >&2; return 1; }
    grep -q "^github_sync:[[:space:]]*true" .forge/index.yml || { echo "ℹ github_sync: true не выставлен в .forge/index.yml — sync выключен." >&2; return 1; }
    git config --get remote.origin.url 2>/dev/null | grep -qE "github\.com" || { echo "⚠ github_sync: true, но у репозитория нет GitHub remote. Sync отключён." >&2; return 1; }
    command -v gh >/dev/null 2>&1 || { echo "⚠ github_sync: true, но gh CLI не установлен. Установи: https://cli.github.com/" >&2; return 1; }
    gh auth status >/dev/null 2>&1 || { echo "⚠ github_sync: true, но gh не авторизован или токен истёк. Запусти: gh auth login" >&2; return 1; }
    resolve_repo || { echo "⚠ github_sync: true, но не получается определить owner/repo. Проверь git remote." >&2; return 1; }
    return 0
}

# Предложить включить sync в этом проекте? (есть github remote, gh auth, но github_sync ещё не задан в index.yml)
should_offer_sync() {
    [ -f .forge/index.yml ] || { echo "no"; return 0; }
    grep -q "^github_sync:" .forge/index.yml && { echo "no"; return 0; }
    git config --get remote.origin.url 2>/dev/null | grep -qE "github\.com" || { echo "no"; return 0; }
    command -v gh >/dev/null 2>&1 || { echo "no"; return 0; }
    gh auth status >/dev/null 2>&1 || { echo "no"; return 0; }
    echo "yes"
}

# Записать github_sync: true (или false при disable) в .forge/index.yml
write_sync_flag() {
    local value="$1"  # true | false
    [ -f .forge/index.yml ] || { echo "no .forge/index.yml — сначала /forge:init" >&2; return 1; }
    if grep -q "^github_sync:" .forge/index.yml; then
        sed -i "s/^github_sync:.*/github_sync: $value/" .forge/index.yml
    else
        # Добавить после первой строки (после project:)
        sed -i "1a github_sync: $value" .forge/index.yml
    fi
}

# ============ HELPERS ============

# Ленивый bootstrap — вызывается из первой sync-операции в новом проекте.
# Идемпотентно: lock-файл .forge/.github-bootstrapped кеширует факт того что прошли.
ensure_bootstrap() {
    [ -f .forge/.github-bootstrapped ] && return 0
    check_enabled || return 0
    bootstrap_labels
    ensure_pinned_map >/dev/null
    touch .forge/.github-bootstrapped
}

# Снимает все forge:phase-* лейблы и ставит новый. Устойчиво к set -e и отсутствию старого лейбла.
relabel_phase() {
    local issue_num="$1" new_phase="$2"
    for p in phase-1 phase-2 phase-3 phase-4 done; do
        gh issue edit "$issue_num" --remove-label "forge:$p" 2>/dev/null || true
    done
    gh issue edit "$issue_num" --add-label "forge:$new_phase" 2>/dev/null || true
}

# Создать .forge/ если нет
ensure_forge_dir() {
    mkdir -p .forge
}

# ---- Slug-контракт ----
# slug задачи = имя task-файла в .forge/tasks/ БЕЗ датного префикса и БЕЗ .md:
#   .forge/tasks/2026-07-03-search-fix.md  →  search-fix
# Все фазы (plan/critique/execute) обязаны передавать один и тот же slug.
# Для устойчивости sync сам нормализует вход, а на чтении принимает и старые
# маркеры с датой (см. find_marker).
normalize_slug() {
    basename "$1" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//'
}

# find_marker <issue|substeps> <slug>: найти marker-файл по slug.
# Порядок: каноничное имя (без даты) → как передали → легаси-имя с датным префиксом.
# stdout: путь к файлу; return 1 если не найден. Легаси-попадание — громкий warning в stderr.
find_marker() {
    local prefix="$1" raw="$2" slug f
    slug=$(normalize_slug "$raw")
    for f in ".forge/.github-$prefix-$slug" ".forge/.github-$prefix-$raw"; do
        [ -f "$f" ] && { echo "$f"; return 0; }
    done
    for f in .forge/.github-"$prefix"-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-"$slug"; do
        if [ -f "$f" ]; then
            echo "⚠ sync: маркер для '$slug' найден только в старом формате с датой ($f). Работаю с ним, но все фазы должны передавать slug без даты (имя task-файла без датного префикса и .md)." >&2
            echo "$f"
            return 0
        fi
    done
    return 1
}

# ============ ACTIONS ============

# bootstrap-labels: создать 6 forge-лейблов (идемпотентно)
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

# ensure-pinned-map: создать или найти Pinned Issue "🗺 Карта проекта"
ensure_pinned_map() {
    check_enabled || return 0
    ensure_forge_dir
    local num
    # 1. Найти по нашему лейблу
    num=$(gh issue list --label "forge:project-map" --state open --json number -q '.[0].number' 2>/dev/null || echo "")
    if [ -z "$num" ]; then
        # 2. Fallback: по title (на случай если кто-то создал руками)
        num=$(gh issue list --search "in:title \"🗺 Карта проекта\"" --state open --json number -q '.[0].number' 2>/dev/null || echo "")
        if [ -n "$num" ]; then
            gh issue edit "$num" --add-label "forge:project-map" 2>/dev/null || true
        fi
    fi
    if [ -z "$num" ]; then
        # 3. Создаём новый
        local body url
        body=$(cat "$PLUGIN_ROOT/skills/github-sync/templates/project-map.md")
        url=$(gh issue create --title "🗺 Карта проекта" --body "$body" --label "forge:project-map")
        num="${url##*/}"
        # Pin может упасть если уже 3 запинено
        gh issue pin "$num" 2>/dev/null || echo "⚠ не смог запинить Issue #$num — у тебя уже 3 pinned issues. Открепи неактуальные и запусти 'sync.sh ensure-pinned-map' ещё раз." >&2
    fi
    echo "$num" > .forge/.github-pinned-id
    echo "$num"
}

# roadmap-init-needed: карта пустая? (yes/no)
roadmap_init_needed() {
    check_enabled || { echo "disabled"; return 0; }
    local count
    count=$(gh api "repos/{owner}/{repo}/milestones?state=all&per_page=1" --jq 'length' 2>/dev/null || echo "0")
    [ "$count" -eq 0 ] && echo "yes" || echo "no"
}

# create-task <task-file> [milestone-num]: создать Issue из task-файла
create_task() {
    check_enabled || return 0
    ensure_forge_dir
    ensure_bootstrap
    local task_file="$1" milestone_num="${2:-}"
    local slug title body url issue_num marker
    # Единый slug-контракт: имя файла без даты и .md (см. «Slug-контракт» в SKILL.md)
    slug=$(normalize_slug "$task_file")

    # Dedup (включая старые маркеры с датным префиксом)
    if marker=$(find_marker issue "$slug"); then
        issue_num=$(cat "$marker")
        if [ -n "$issue_num" ]; then
            echo "issue #$issue_num уже существует для $slug"
            return 0
        fi
    fi

    # Title из H1, fallback на slug
    title=$(awk '/^# /{sub(/^# /,""); print; exit}' "$task_file")
    [ -z "$title" ] && title="$slug"

    body=$(cat "$task_file")

    local args=(--title "$title" --body "$body" --label "forge:phase-1")
    [ -n "$milestone_num" ] && args+=(--milestone "$milestone_num")

    url=$(gh issue create "${args[@]}")
    issue_num="${url##*/}"
    echo "$issue_num" > ".forge/.github-issue-$slug"
    echo "$issue_num"

    # Карта обновляется на каждой фазе: новая задача видна сразу, не в финале execute
    sync_all || true
}

# add-steps <task-slug> <plan-file>: создать/обновить sub-issues по шагам плана.
# Повторный вызов (план правили после критики) — НЕ no-op: новые шаги создаёт,
# убранные закрывает, переименованные переименовывает. Mapping всегда = текущий план.
add_steps() {
    check_enabled || return 0
    ensure_bootstrap
    local task_slug="$1" plan_file="$2"
    local marker parent
    marker=$(find_marker issue "$task_slug") || { echo "⚠ sync: не нашёл Issue задачи для '$task_slug' — sub-issues не создаю. Проверь slug: имя task-файла без даты и .md." >&2; return 0; }
    parent=$(cat "$marker")
    [ -n "$parent" ] || { echo "⚠ sync: маркер Issue для '$task_slug' пуст, пропускаю" >&2; return 0; }

    local parent_node_id mapping_file
    parent_node_id=$(gh issue view "$parent" --json id -q .id)
    mapping_file=$(find_marker substeps "$task_slug") || mapping_file=".forge/.github-substeps-$(normalize_slug "$task_slug")"
    [ -f "$mapping_file" ] || : > "$mapping_file"

    # Читаем шаги из плана. Номер шага бывает дробным (3.5 — вставка после критики).
    # Используем mapfile чтобы избежать subshell у while
    mapfile -t step_lines < <(grep -E "^## Шаг " "$plan_file")
    local step_title step_num url sub_num new_mapping
    new_mapping=$(mktemp)
    for line in "${step_lines[@]}"; do
        step_title=$(echo "$line" | sed 's/^## //')
        step_num=$(echo "$step_title" | sed -E 's/^Шаг ([0-9]+(\.[0-9]+)?).*/\1/')
        sub_num=$(awk -F: -v n="$step_num" '$1==n{print $2; exit}' "$mapping_file")
        if [ -n "$sub_num" ]; then
            # Шаг уже есть — обновить заголовок (мог измениться при правках плана)
            gh issue edit "$sub_num" --title "$step_title" 2>/dev/null || true
        else
            url=$(gh issue create --title "$step_title" --body "Часть #$parent" --label "forge:phase-2")
            sub_num="${url##*/}"

            # Использовать subIssueUrl вариант — не нужен второй node_id lookup
            gh api graphql -f query='
                mutation($parent:ID!, $childUrl:String!) {
                  addSubIssue(input:{issueId:$parent, subIssueUrl:$childUrl}) {
                    subIssue { number }
                  }
                }' -F parent="$parent_node_id" -f childUrl="$url" >/dev/null 2>&1 || \
                echo "⚠ не удалось привязать sub-issue #$sub_num к #$parent (возможно репо не поддерживает sub-issues — оставляю как обычный Issue)" >&2
        fi
        echo "$step_num:$sub_num" >> "$new_mapping"
    done

    # Шаги, исчезнувшие из плана — закрыть их sub-issues
    local old_num old_sub
    while IFS=: read -r old_num old_sub; do
        [ -n "$old_num" ] || continue
        if ! awk -F: -v n="$old_num" '$1==n{f=1} END{exit !f}' "$new_mapping"; then
            echo "sync: шаг $old_num убран из плана — закрываю sub-issue #$old_sub" >&2
            gh issue close "$old_sub" 2>/dev/null || true
        fi
    done < "$mapping_file"

    mv "$new_mapping" "$mapping_file"

    # Фазу назад не откатываем: add-steps в critique идёт ПОСЛЕ add-critique (phase-3)
    local cur_label
    cur_label=$(gh issue view "$parent" --json labels -q '[.labels[].name | select(startswith("forge:phase-") or . == "forge:done")] | first // ""' 2>/dev/null || echo "")
    case "$cur_label" in
        forge:phase-3|forge:phase-4|forge:done) : ;;
        *) relabel_phase "$parent" phase-2 ;;
    esac

    # Карта обновляется на каждой фазе, не только в финале execute
    sync_all || true
}

# add-critique <task-slug> <summary-file>: комментарий + label
add_critique() {
    check_enabled || return 0
    local task_slug="$1" summary_file="$2"
    local marker parent
    marker=$(find_marker issue "$task_slug") || { echo "⚠ sync: не нашёл Issue задачи для '$task_slug' — комментарий критики не добавлен. Проверь slug: имя task-файла без даты и .md." >&2; return 0; }
    parent=$(cat "$marker")
    [ -n "$parent" ] || { echo "⚠ sync: маркер Issue для '$task_slug' пуст, пропускаю" >&2; return 0; }
    [ -f "$summary_file" ] || { echo "sync: no summary file $summary_file" >&2; return 0; }
    gh issue comment "$parent" --body-file "$summary_file"
    relabel_phase "$parent" phase-3
}

# close-step <task-slug> <step-num>
close_step() {
    check_enabled || return 0
    local task_slug="$1" step_num="$2"
    local mapping_file
    mapping_file=$(find_marker substeps "$task_slug") || { echo "⚠ sync: не нашёл mapping шагов для '$task_slug' — sub-issue не закрыт. Либо sub-issues не создавались (критика не запускалась), либо slug не тот: нужно имя task-файла без даты и .md." >&2; return 0; }
    local sub_num
    sub_num=$(awk -F: -v n="$step_num" '$1==n{print $2; exit}' "$mapping_file")
    [ -n "$sub_num" ] && gh issue close "$sub_num" 2>/dev/null || true
}

# close-task <task-slug>: закрыть Issue + journal.yml update
close_task() {
    check_enabled || return 0
    local task_slug="$1"
    local marker parent
    marker=$(find_marker issue "$task_slug") || { echo "⚠ sync: не нашёл Issue задачи для '$task_slug' — на GitHub ничего не закрыто. Проверь slug: имя task-файла без даты и .md." >&2; return 0; }
    parent=$(cat "$marker")
    [ -n "$parent" ] || { echo "⚠ sync: маркер Issue для '$task_slug' пуст, пропускаю" >&2; return 0; }
    relabel_phase "$parent" done
    gh issue close "$parent" 2>/dev/null || true

    # Запись в .forge/journal.yml (критерий №4 готовности)
    local issue_title milestone_title
    issue_title=$(gh issue view "$parent" --json title -q .title 2>/dev/null || echo "$task_slug")
    milestone_title=$(gh issue view "$parent" --json milestone -q '.milestone.title // "—"' 2>/dev/null || echo "—")
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

# reassign-task <task-slug> <new-milestone-num | empty>: перепривязать к другому milestone
reassign_task() {
    check_enabled || return 0
    local task_slug="$1" new_milestone="${2:-}"
    local marker parent
    marker=$(find_marker issue "$task_slug") || { echo "⚠ sync: не нашёл Issue задачи для '$task_slug' — перепривязка не сделана. Проверь slug: имя task-файла без даты и .md." >&2; return 0; }
    parent=$(cat "$marker")
    [ -n "$parent" ] || { echo "⚠ sync: маркер Issue для '$task_slug' пуст, пропускаю" >&2; return 0; }
    if [ -n "$new_milestone" ]; then
        gh issue edit "$parent" --milestone "$new_milestone" 2>/dev/null || true
    else
        # Снять milestone (передаём пустую строку)
        gh issue edit "$parent" --milestone "" 2>/dev/null || true
    fi
}

# sync-readme: обновить шапку README через Python скрипт
sync_readme() {
    check_enabled || return 0
    if [ ! -f "$PLUGIN_ROOT/skills/github-sync/scripts/render_readme_header.py" ]; then
        echo "sync: render_readme_header.py не найден, пропускаю" >&2
        return 0
    fi
    python3 "$PLUGIN_ROOT/skills/github-sync/scripts/render_readme_header.py"
}

# sync-pinned: обновить тело Pinned Issue через Python скрипт
sync_pinned() {
    check_enabled || return 0
    if [ ! -f "$PLUGIN_ROOT/skills/github-sync/scripts/render_pinned.py" ]; then
        echo "sync: render_pinned.py не найден, пропускаю" >&2
        return 0
    fi
    local pinned_num
    pinned_num=$(cat .forge/.github-pinned-id 2>/dev/null || echo "")
    [ -z "$pinned_num" ] && { pinned_num=$(ensure_pinned_map); }
    [ -z "$pinned_num" ] && { echo "sync: нет Pinned Issue, пропускаю" >&2; return 0; }

    local milestones_json tmp
    milestones_json=$(gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100")
    tmp=$(mktemp)
    gh issue view "$pinned_num" --json body -q .body > "$tmp"

    python3 "$PLUGIN_ROOT/skills/github-sync/scripts/render_pinned.py" "$tmp" <<<"$milestones_json"

    gh issue edit "$pinned_num" --body-file "$tmp"
    rm -f "$tmp"
}

# sync-all: README шапка + Pinned Issue (без Projects v2 board — выкинули)
sync_all() {
    check_enabled || return 0
    sync_readme
    sync_pinned
}

# ============ DISPATCH ============

action="${1:-help}"
shift || true

case "$action" in
    enabled)           check_enabled && echo "yes" || echo "no" ;;
    diagnose)          diagnose && echo "ok" ;;
    should-offer)      should_offer_sync ;;
    enable)            write_sync_flag true ;;
    disable)           write_sync_flag false ;;
    bootstrap-labels)  bootstrap_labels ;;
    ensure-pinned-map) ensure_pinned_map ;;
    roadmap-init-needed) roadmap_init_needed ;;
    create-task)       create_task "$@" ;;
    add-steps)         add_steps "$@" ;;
    add-critique)      add_critique "$@" ;;
    close-step)        close_step "$@" ;;
    close-task)        close_task "$@" ;;
    reassign-task)     reassign_task "$@" ;;
    sync-readme)       sync_readme ;;
    sync-pinned)       sync_pinned ;;
    sync-all)          sync_all ;;
    help|*)
        cat <<EOF
forge github-sync — actions:
  enabled               | проверка можно ли синкать (yes/no)
  diagnose              | громкая диагностика проблем
  should-offer          | стоит ли в этом проекте предложить sync? (yes/no)
  enable                | выставить github_sync: true в .forge/index.yml
  disable               | выставить github_sync: false (явный отказ)
  bootstrap-labels      | создать forge-лейблы
  ensure-pinned-map     | создать/найти Pinned Issue карты
  roadmap-init-needed   | нужно ли знакомство с целями (yes/no)
  create-task <f> [m]   | создать Issue из task-файла (+ обновить карту)
  add-steps <s> <f>     | sub-issues из шагов плана (повтор обновляет под текущий план)
  add-critique <s> <f>  | комментарий критики + label phase-3
  close-step <s> <n>    | закрыть sub-issue
  close-task <s>        | закрыть Issue + journal update
  reassign-task <s> [m] | перепривязать к другому milestone
  sync-readme           | обновить шапку README
  sync-pinned           | обновить Pinned Issue
  sync-all              | sync-readme + sync-pinned
EOF
        ;;
esac
