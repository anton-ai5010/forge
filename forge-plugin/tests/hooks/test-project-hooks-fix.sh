#!/usr/bin/env bash
# Тесты для skills/forge-context/project-hooks-fix.sh — хуки проекта в .claude/settings*.json:
# check / apply / decline (старые копии подсказки плагина и старая защита main),
# install (init) и сама новая защита main (смотрит на путь файла, а не только на ветку).
# Все проекты — во временных папках, HOME — временный (отметки forge-state не мусорят).

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIX="$PLUGIN_ROOT/skills/forge-context/project-hooks-fix.sh"
export HOME="$(mktemp -d)"
fails=0

check() {
    local desc="$1" ok="$2"
    if [ "$ok" -eq 0 ]; then echo "PASS: $desc"; else echo "FAIL: $desc"; fails=$((fails + 1)); fi
}

# Дословная старая защита из шаблона init (commands/init.md, до 7.13.1)
OLD_GUARD='[ "$(git branch --show-current)" != "main" ] && [ "$(git branch --show-current)" != "master" ] || { echo '"'"'BLOCKED: Do not edit files on main/master. Create a feature branch first.'"'"' >&2; exit 2; }'

# settings-файл из python-выражения (OLD, COPY, LIVE доступны) — в формате json.dumps с нужным отступом.
# eval — только над литералами, написанными в этом же тест-файле (внешнего ввода нет)
write_settings() {
    python3 - "$1" "$2" "$3" "$OLD_GUARD" <<'PY'
import json, sys
f, ind, expr, OLD = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
COPY = "bash /home/anton/.claude/plugins/marketplaces/forge-marketplace/forge-plugin/hooks/context-inject.sh"
LIVE = "bash .live/hooks/context-inject.sh"
open(f, "w", encoding="utf-8").write(json.dumps(eval(expr), ensure_ascii=False, indent=ind) + "\n")
PY
}

new_project() {
    P=$(cd "$(mktemp -d)" && pwd -P)
    mkdir -p "$P/.claude"
}

# --- check ---

new_project
mkdir -p "$P/.live/hooks" && touch "$P/.live/hooks/context-inject.sh"
write_settings "$P/.claude/settings.json" 2 '{"hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": LIVE}]}]}}'
write_settings "$P/.claude/settings.local.json" 2 '{"hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": COPY}]}], "PreToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": OLD}]}]}}'
out=$(bash "$FIX" check "$P"); rc=$?
[ "$rc" -eq 0 ] \
  && printf '%s' "$out" | grep "settings.json:" | grep -q "рабочая" \
  && printf '%s' "$out" | grep "settings.local.json:" | grep -q "старый путь" \
  && printf '%s' "$out" | grep "settings.local.json:" | grep -q "старая защита"
check "check should find working and dead hook copies and the verbatim old guard in both settings files" $?

new_project
write_settings "$P/.claude/settings.json" 4 '{"hooks": {"PreToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": OLD.replace("master", "prod")}]}], "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": COPY + " --my-flag"}]}]}}'
out=$(bash "$FIX" check "$P"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ]
check "check should stay silent about a guard or hook the user changed by hand" $?

E=$(mktemp -d)
out=$(bash "$FIX" check "$E"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ]
check "check should be silent with rc 0 when the project has no .claude" $?

# --- apply: меняются только наши записи, остальное байт-в-байт ---

for IND in 2 4; do
    new_project
    BEFORE='{"permissions": {"allow": ["Bash(ls)"], "deny": ["Bash(rm -rf /)"]}, "hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "echo свой хук"}, {"type": "command", "command": COPY}]}], "PreToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": OLD}]}, {"matcher": "Bash", "hooks": [{"type": "command", "command": "echo проверка"}]}]}, "language": "ru", "note": "русская строка — «кавычки»"}'
    write_settings "$P/.claude/settings.json" "$IND" "$BEFORE"
    cp "$P/.claude/settings.json" "$E/orig.json"
    out=$(bash "$FIX" apply "$P"); rc=$?
    python3 - "$P/.claude/settings.json" "$IND" "$OLD_GUARD" <<'PY'
import json, sys
path, ind, OLD = sys.argv[1], int(sys.argv[2]), sys.argv[3]
text = open(path, encoding="utf-8").read()
d = json.loads(text)
pre = d["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
assert pre != OLD and "BLOCKED" in pre and ".forge" in pre, "old guard not replaced"
ups = d["hooks"]["UserPromptSubmit"][0]["hooks"]
assert [h["command"] for h in ups] == ["echo свой хук"], ups
assert d["hooks"]["PreToolUse"][1]["hooks"][0]["command"] == "echo проверка"
assert d["permissions"] == {"allow": ["Bash(ls)"], "deny": ["Bash(rm -rf /)"]}
assert d["note"] == "русская строка — «кавычки»" and d["language"] == "ru"
assert text == json.dumps(d, ensure_ascii=False, indent=ind) + "\n", "formatting changed"
PY
    ok=$?
    [ "$rc" -eq 0 ] && [ "$ok" -eq 0 ]
    check "apply (indent $IND) should drop only our copy, swap only the old guard and keep the rest byte-for-byte" $?
    bak=$(ls "$HOME"/.claude/forge-state/*/settings.json.*.bak 2>/dev/null | tail -1)
    [ -n "$bak" ] && cmp -s "$bak" "$E/orig.json" && printf '%s' "$out" | grep -qF "$bak" \
      && [ "$(ls -A "$P/.claude")" = "settings.json" ]
    check "apply (indent $IND) should keep a backup outside the project and print its path" $?
    rm -rf "$HOME"/.claude/forge-state
done

new_project
write_settings "$P/.claude/settings.json" 2 '{"hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": COPY}]}]}, "language": "ru"}'
bash "$FIX" apply "$P" >/dev/null
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d=={'language':'ru'}, d" "$P/.claude/settings.json"
check "apply should not leave empty hook lists behind" $?
[ -z "$(bash "$FIX" check "$P")" ]
check "check should be silent after apply" $?

# --- decline ---

new_project
write_settings "$P/.claude/settings.json" 2 '{"hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": COPY}]}]}}'
bash "$FIX" decline "$P" >/dev/null
[ -z "$(bash "$FIX" check "$P")" ] && ls "$HOME"/.claude/forge-state/*/hooks-fix-declined >/dev/null 2>&1
check "decline should silence check for this project (mark outside the project)" $?

# --- install (для init) ---

new_project; rmdir "$P/.claude"
bash "$FIX" install "$P" >/dev/null; rc=$?
python3 - "$P/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert "UserPromptSubmit" not in d["hooks"], "init must not copy the L0 hook"
pre = d["hooks"]["PreToolUse"]
assert len(pre) == 1 and pre[0]["matcher"] == "Edit|Write" and ".forge" in pre[0]["hooks"][0]["command"]
assert d["permissions"]["deny"] == ["Bash(rm -rf /)", "Bash(git push --force*)", "Bash(git reset --hard*)"]
assert d["language"] == "ru"
PY
ok=$?
[ "$rc" -eq 0 ] && [ "$ok" -eq 0 ]
check "install should create settings.json with the new guard, deny list and language — without the L0 hook copy" $?
cp "$P/.claude/settings.json" "$E/guard.json"

new_project
write_settings "$P/.claude/settings.json" 2 '{"permissions": {"allow": ["Bash(npm test)"], "deny": ["Bash(git push --force*)"]}, "hooks": {"PreToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": OLD}]}]}, "language": "en"}'
bash "$FIX" install "$P" >/dev/null; bash "$FIX" install "$P" >/dev/null
python3 - "$P/.claude/settings.json" "$OLD_GUARD" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); OLD = sys.argv[2]
cmds = [h["command"] for g in d["hooks"]["PreToolUse"] for h in g["hooks"]]
assert OLD not in cmds and len(cmds) == 1, cmds
assert d["permissions"]["allow"] == ["Bash(npm test)"]
assert d["permissions"]["deny"] == ["Bash(git push --force*)", "Bash(rm -rf /)", "Bash(git reset --hard*)"], d["permissions"]["deny"]
assert d["language"] == "en"
PY
check "install twice on existing settings should merge without duplicates, replace the old guard, keep the user's choices" $?
ls "$HOME"/.claude/forge-state/*/settings.json.*.bak >/dev/null 2>&1
check "install should keep a backup before rewriting an existing settings.json" $?

new_project
write_settings "$P/.claude/settings.json" 2 '{"hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": COPY}]}]}}'
bash "$FIX" install "$P" >/dev/null
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert 'UserPromptSubmit' not in d['hooks'], d" "$P/.claude/settings.json"
check "install should drop an old L0 hook copy left by an old init" $?

# --- новая защита main: смотрит на путь файла ---

GUARD=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['hooks']['PreToolUse'][0]['hooks'][0]['command'])" "$E/guard.json")
R=$(cd "$(mktemp -d)" && pwd -P); git -C "$R" init -q -b master
mkdir -p "$R/src" "$R/.forge"
guard() { (cd "$R" && printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a"}}' "$1" | sh -c "$GUARD" 2>"$E/err"); }
guard "$R/.forge/x.yml"; check "guard should allow .forge on master" $?
guard "$R/CLAUDE.md"; check "guard should allow CLAUDE.md on master" $?
guard "$R/.claude/settings.json"; check "guard should allow .claude on master" $?
guard "/tmp/outside-$$.txt"; check "guard should allow files outside the repo" $?
guard "$R/src/a.py"; rc=$?
[ "$rc" -eq 2 ] && grep -q "src/a.py" "$E/err" && grep -q "master" "$E/err"
check "guard should block code on master and name the file and the branch" $?
guard "$R/src/new/b.py"; [ $? -eq 2 ]
check "guard should block a new file in a not-yet-existing folder on master" $?
guard "$R/.claude/../lib/c.py"; [ $? -eq 2 ]
check "guard should block code reached through «..» from a not-yet-existing .claude on master" $?
git -C "$R" checkout -q -b feat/x
guard "$R/src/a.py"; check "guard should allow code on a work branch" $?
N=$(mktemp -d)
(cd "$N" && printf '{"tool_input":{"file_path":"%s/a.py"}}' "$N" | sh -c "$GUARD" 2>/dev/null)
check "guard should allow anything outside git" $?

rm -rf "$HOME" "$E" "$R" "$N"
echo "---"
if [ "$fails" -gt 0 ]; then echo "$fails test(s) FAILED"; exit 1; fi
echo "All tests passed"
exit 0
