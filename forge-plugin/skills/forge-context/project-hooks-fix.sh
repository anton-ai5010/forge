#!/usr/bin/env bash
# Хуки проекта (.claude/settings.json и settings.local.json) — одна правда для init и старта сессии.
#   install [папка] — init: новая защита основной ветки + запреты опасных команд + language; копию подсказки L0 не ставит
#                     (подсказка уже подключена у плагина в hooks/hooks.json — копия в проекте даёт её дважды)
#   check   [папка] — найти старые копии подсказки плагина и старую защиту main; печатает по строке на находку, иначе ничего
#   apply   [папка] — убрать копии, заменить старую защиту на новую; резервная копия — вне проекта (~/.claude/forge-state)
#   decline [папка] — больше не предлагать для этого проекта
# Трогаем только записи, совпадающие с нашим шаблоном один в один: переделанное пользователем — его, не наше.
# Всегда rc 0 — старт сессии и init не должны падать из-за чужих настроек.

cmd="${1:-check}"
dir="${2:-$PWD}"
top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || (cd "$dir" 2>/dev/null && pwd) || echo "$dir")

python3 - "$cmd" "$top" <<'PY' || true
import json, os, re, shutil, subprocess, sys, time

cmd, top = sys.argv[1], sys.argv[2]

# Старая защита — дословно из шаблона init до 7.13.1: блокировала любую правку на main/master, включая память .forge
OLD_GUARD = ('[ "$(git branch --show-current)" != "main" ] && [ "$(git branch --show-current)" != "master" ] '
             "|| { echo 'BLOCKED: Do not edit files on main/master. Create a feature branch first.' >&2; exit 2; }")
# Новая защита: смотрит на путь файла из JSON на stdin и на ветку репозитория, где этот файл лежит.
# Память (.forge), настройки (.claude), CLAUDE.md и файлы вне git — можно; код на main/master — нет.
NEW_GUARD = (
    """f=$(sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' | head -n 1); [ -n "$f" ] || exit 0; """
    """case "$f" in /*) ;; *) f="$PWD/$f" ;; esac; d=$(dirname "$f"); while [ ! -d "$d" ]; do d=$(dirname "$d"); done; """
    """b=$(git -C "$d" branch --show-current 2>/dev/null); case "$b" in main|master) ;; *) exit 0 ;; esac; """
    """r="$(git -C "$d" rev-parse --show-prefix 2>/dev/null)${f#"$d"/}"; """
    # путь с «..» исключений не получает: .forge/../src/a.py — это код, а не память
    """case "/$r/" in */../*) ;; *) case "$r" in .forge/*|.claude/*|CLAUDE.md|*/CLAUDE.md) exit 0 ;; esac ;; esac; """
    """echo "BLOCKED: файл $r на основной ветке $b. Код здесь не правим — заведи рабочую ветку """
    """(git switch -c feat/<задача>); память .forge, .claude и CLAUDE.md на основной ветке можно. """
    """Если пользователь явно просит править прямо здесь — скажи, что мешает защита в .claude/settings.json, """
    """и спроси, снять ли её." >&2; exit 2"""
)
# Копия подсказки плагина — ровно шаблон init «bash <путь>/hooks/context-inject.sh», без добавок
COPY_RE = re.compile(r"^bash [^ ]*hooks/context-inject\.sh$")
DENY = ["Bash(rm -rf /)", "Bash(git push --force*)", "Bash(git reset --hard*)"]
FILES = ["settings.json", "settings.local.json"]
STATE = os.path.join(os.path.expanduser("~"), ".claude", "forge-state", top.replace("/", "-"))


def load(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    return text, json.loads(text)


def indent_of(text):
    m = re.search(r"\n( +)\S", text)
    return len(m.group(1)) if m else 2


def dump(d, ind):
    return json.dumps(d, ensure_ascii=False, indent=ind) + "\n"


def backup(name, p):
    """Резервная копия вне проекта, с отметкой времени — повторный запуск не затирает прошлую."""
    os.makedirs(STATE, exist_ok=True)
    bak = os.path.join(STATE, f"{name}.{time.strftime('%Y%m%d-%H%M%S')}.bak")
    shutil.copy2(p, bak)
    return bak


def write(p, text):
    """Через временный файл рядом + замену: оборванная запись не оставит полфайла.
    realpath — settings.json бывает ссылкой на файл в dotfiles: правим сам файл, ссылку не затираем."""
    p = os.path.realpath(p)
    tmp = p + ".forge-tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(text)
        if os.path.exists(p):
            shutil.copymode(p, tmp)
        os.replace(tmp, p)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def entries(d):
    """(событие, группа, хук) по всем хукам файла — только корректно устроенные записи."""
    hooks = d.get("hooks") if isinstance(d, dict) else None
    if not isinstance(hooks, dict):
        return
    for ev, groups in hooks.items():
        if not isinstance(groups, list):
            continue
        for g in groups:
            if isinstance(g, dict) and isinstance(g.get("hooks"), list):
                for h in g["hooks"]:
                    if isinstance(h, dict) and isinstance(h.get("command"), str):
                        yield ev, g, h


def is_copy(ev, h):
    return ev == "UserPromptSubmit" and bool(COPY_RE.match(h["command"].strip()))


def is_old(ev, h):
    return ev == "PreToolUse" and h["command"] == OLD_GUARD


def findings(d):
    copies = [h["command"].strip() for ev, _, h in entries(d) if is_copy(ev, h)]
    old = sum(1 for ev, _, h in entries(d) if is_old(ev, h))
    return copies, old


def fix(d):
    """Убрать копии подсказки, заменить старую защиту. Пустые группы/события после нас — убрать."""
    emptied = []
    for ev, g, h in list(entries(d)):
        if is_copy(ev, h):
            g["hooks"].remove(h)
            if not g["hooks"]:
                emptied.append((ev, g))
        elif is_old(ev, h):
            h["command"] = NEW_GUARD
    hooks = d.get("hooks")
    for ev, g in emptied:
        hooks[ev] = [x for x in hooks[ev] if x is not g]
        if not hooks[ev]:
            del hooks[ev]
    if hooks == {}:
        del d["hooks"]


def tracked(rel):
    r = subprocess.run(["git", "-C", top, "ls-files", "--error-unmatch", rel],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return r.returncode == 0


def settings_files():
    for name in FILES:
        p = os.path.join(top, ".claude", name)
        if os.path.isfile(p):
            try:
                text, d = load(p)
            except (OSError, ValueError):
                continue
            if isinstance(d, dict):
                yield name, p, text, d


def do_check():
    if os.path.exists(os.path.join(STATE, "hooks-fix-declined")):
        return
    for name, p, text, d in settings_files():
        copies, old = findings(d)
        git = " · файл хранится в истории проекта — правка будет видна там" if tracked(".claude/" + name) else ""
        for c in copies:
            target = c.split(" ", 1)[1]
            live = os.path.exists(target if target.startswith("/") else os.path.join(top, target))
            kind = "рабочая — подсказка приходит дважды" if live else "старый путь, не работает"
            print(f".claude/{name}: лишняя копия подсказки плагина ({kind}){git}")
        if old:
            print(f".claude/{name}: старая защита основной ветки (мешает записывать память .forge на main){git}")


def do_apply():
    done = False
    for name, p, text, d in settings_files():
        copies, old = findings(d)
        if not copies and not old:
            continue
        ind = indent_of(text)
        reformatted = text != dump(d, ind)
        bak = backup(name, p)
        fix(d)
        write(p, dump(d, ind))
        note = " (файл был в другом оформлении — переформатирован)" if reformatted else ""
        print(f".claude/{name}: убрано копий подсказки — {len(copies)}, защита заменена — {old}{note}; "
              f"резервная копия: {bak}")
        done = True
    if not done:
        print("чинить нечего")


def do_decline():
    os.makedirs(STATE, exist_ok=True)
    open(os.path.join(STATE, "hooks-fix-declined"), "w").close()
    print("ок, для этого проекта больше не предлагаю")


def do_install():
    p = os.path.join(top, ".claude", "settings.json")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    d, ind, text = {}, 2, None
    if os.path.isfile(p):
        text, d = load(p)
        ind = indent_of(text)
        if not isinstance(d, dict):
            print(f"{p}: не объект JSON — не трогаю")
            return
        fix(d)
    pre = d.setdefault("hooks", {}).setdefault("PreToolUse", [])
    if not any(h["command"] == NEW_GUARD for ev, _, h in entries(d) if ev == "PreToolUse"):
        pre.append({"matcher": "Edit|Write", "hooks": [{"type": "command", "command": NEW_GUARD}]})
    deny = d.setdefault("permissions", {}).setdefault("deny", [])
    deny.extend(x for x in DENY if x not in deny)
    d.setdefault("language", "ru")
    new = dump(d, ind)
    if new == text:
        print(f"{p}: уже настроено")
        return
    note = ""
    if text is not None:
        note = f"; резервная копия: {backup('settings.json', p)}"
    write(p, new)
    print(f"{p}: защита основной ветки (код — только в рабочей ветке, память и настройки — можно), "
          f"запреты опасных команд{note}")


try:
    {"check": do_check, "apply": do_apply, "decline": do_decline, "install": do_install}.get(
        cmd, lambda: print(f"неизвестная команда: {cmd} (install | check | apply | decline)"))()
except Exception as e:  # чужой файл настроек не должен ронять старт сессии / init
    print(f"project-hooks-fix: {cmd} не выполнен — {e}", file=sys.stderr)
PY
exit 0
