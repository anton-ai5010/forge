#!/usr/bin/env python3
"""Голос уведомлений: хуки Stop / PermissionRequest → «говорить или молчать» и фраза «<проект>: <что>».

notify.py stop|permission   — вход хука на stdin; фраза уходит в очередь фонового голоса (voiced.py)
notify.py name [<имя>]      — имя текущего проекта: без аргумента печатает, с аргументом записывает
notify.py mute|unmute       — полная тишина / снова говорит
notify.py volume [N|тише|громче] — громкость в процентах; без аргумента — печатает текущую

Только stdlib. Голос не установлен или не macOS — старые mp3, как раньше. Любая ошибка — mp3.
"""
import fcntl
import json
import os
import random
import re
import signal
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
VOICED = os.path.join(HERE, "voiced.py")
SOUNDS = os.path.join(os.path.dirname(HERE), "sounds")
HOME = os.environ.get("FORGE_VOICE_HOME") or os.path.expanduser("~/.claude/forge-voice")
DRYRUN = bool(os.environ.get("FORGE_VOICE_DRYRUN"))

QUIET = re.compile(r"(?<!\w)(тихо|ничего нового)(?!\w)")
STOP = {"в", "и", "до", "после", "на", "с", "по", "к", "а", "но", "что", "для", "из", "о", "у", "за", "от", "не",
        "это", "как", "или", "при", "про", "его", "её", "их"}
PREP = {"в", "на", "с", "по", "к", "до", "из", "о", "у", "за", "от", "при", "про", "для", "после"}
ACTIONS = {"Bash": "хочу запустить команду", "Edit": "хочу изменить файл", "Write": "хочу изменить файл",
           "MultiEdit": "хочу изменить файл", "NotebookEdit": "хочу изменить файл",
           "WebFetch": "хочу в интернет", "WebSearch": "хочу в интернет"}
TRANSLIT = [("sch", "щ"), ("sh", "ш"), ("ch", "ч"), ("zh", "ж"), ("kh", "х"), ("ts", "ц"), ("ya", "я"),
            ("yu", "ю"), ("yo", "ё"), ("a", "а"), ("b", "б"), ("c", "к"), ("d", "д"), ("e", "е"), ("f", "ф"),
            ("g", "г"), ("h", "х"), ("i", "и"), ("j", "дж"), ("k", "к"), ("l", "л"), ("m", "м"), ("n", "н"),
            ("o", "о"), ("p", "п"), ("q", "к"), ("r", "р"), ("s", "с"), ("t", "т"), ("u", "у"), ("v", "в"),
            ("w", "в"), ("x", "кс"), ("y", "ы"), ("z", "з")]
EMOJI = re.compile("[\U0001F000-\U0001FAFF☀-➿⬀-⯿️‍]")
BROKEN_FRESH = 600      # с; свежая поломка — без перезапуска демона
WARN_EVERY = 3 * 3600   # с; «голос сломался» вслух — не чаще
STUCK = 60              # с; задание лежит дольше — голос не разбирает очередь
ACCESS = "unknown"      # ok — заголовок окна прочитан; denied — нет «Универсального доступа»; unknown — не проверяли


def path(*p):
    return os.path.join(HOME, *p)


def log(line):
    try:
        os.makedirs(HOME, exist_ok=True)
        with open(path("voiced.log"), "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + "notify: " + line + "\n")
    except OSError:
        pass


def age(p):
    try:
        return time.time() - os.path.getmtime(p)
    except OSError:
        return None


def run(cmd, timeout=3):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None


def remove(p):
    try:
        os.remove(p)
    except OSError:
        pass


def play(file, volume="0.05"):
    player = os.environ.get("FORGE_VOICE_PLAYER", "")
    if player.startswith("log:"):
        with open(player[4:], "a", encoding="utf-8") as f:
            f.write(file + "\n")
    elif sys.platform == "darwin":
        run(["afplay", "-v", volume, file], timeout=30)
    else:
        run(["paplay", "--volume", "3277", file], timeout=30)


def mp3(kind):
    if DRYRUN:
        print("mp3 " + kind)
        return
    d = os.path.join(SOUNDS, kind)
    files = [f for f in os.listdir(d) if f.endswith(".mp3")] if os.path.isdir(d) else []
    if files:
        play(os.path.join(d, random.choice(files)))


def warn_broken():
    """Раз в 3 часа системный голос говорит, что голос сломался (иначе mp3 не отличить от «просто пикнуло»)."""
    a = age(path("warned"))
    if a is not None and a < WARN_EVERY:
        return
    text = "Голос сломался, скажи: почини голос"
    player = os.environ.get("FORGE_VOICE_PLAYER", "")
    if player.startswith("log:"):
        with open(player[4:], "a", encoding="utf-8") as f:
            f.write("milena " + text + "\n")
    else:
        tmp = path("warn-%d.aiff" % os.getpid())
        r = run(["say", "-v", "Milena", "-o", tmp, text], timeout=15)
        if r is None or r.returncode != 0:
            return                                   # не сказал — отметку не ставим, попробуем в следующий раз
        play(tmp, volume="0.3")
        remove(tmp)
    open(path("warned"), "w").close()


# --- окно, простой, имя ---

def front_project(root):
    """True — окно этого проекта впереди; False — нет; None — не знаем (нет «Универсального доступа»)."""
    global ACCESS
    forced = os.environ.get("FORGE_VOICE_FRONT")
    if forced is not None:
        ACCESS = "denied" if forced == "unknown" else "ok"
        return {"1": True, "0": False}.get(forced)
    app = os.environ.get("FORGE_VOICE_APP")
    if app is None:
        front = run(["lsappinfo", "front"])
        info = run(["lsappinfo", "info", "-only", "name", front.stdout.strip()]) if front else None
        m = re.search(r'"LSDisplayName"="([^"]*)"', info.stdout) if info else None
        app = m.group(1) if m else ""
    if app != "Code":
        return False
    title = os.environ.get("FORGE_VOICE_TITLE")
    if title is None:
        r = run(["osascript", "-e", 'tell application "System Events" to tell process "Code" to get name of front window'])
        if r is None:                                # таймаут — машина занята; не знаем, но доступ не виноват
            return False
        if r.returncode != 0:
            ACCESS = "denied"
            return None
        title = r.stdout.strip()
    ACCESS = "ok"
    return os.path.basename(root.rstrip("/")) in [p.strip() for p in title.split(" — ")]


def idle_seconds():
    forced = os.environ.get("FORGE_VOICE_IDLE")
    if forced is not None:
        return float(forced)
    r = run(["ioreg", "-c", "IOHIDSystem"])
    m = re.search(r'"HIDIdleTime" = (\d+)', r.stdout) if r else None
    return int(m.group(1)) / 1e9 if m else 0.0


def load_names():
    try:
        with open(path("names.json"), encoding="utf-8") as f:
            names = json.load(f)
    except (OSError, ValueError):
        return {}
    return names if isinstance(names, dict) else {}


def translit(word):
    s = re.sub(r"[-_.]+", " ", word.lower())
    out, i = "", 0
    while i < len(s):
        for lat, cyr in TRANSLIT:
            if s.startswith(lat, i):
                out, i = out + cyr, i + len(lat)
                break
        else:
            out, i = out + s[i], i + 1
    return out


def project_name(root):
    name = load_names().get(root)
    if not isinstance(name, str) or not name.strip():
        name = translit(os.path.basename(root.rstrip("/")) or "проект")
    return name[:1].upper() + name[1:]


# --- текст ответа → фраза ---

def answer_text(data):
    text = data.get("last_assistant_message")
    if isinstance(text, str) and text:
        return text
    tp = data.get("transcript_path") or ""
    try:
        size = os.path.getsize(tp)
        with open(tp, "rb") as f:
            f.seek(max(size - 2097152, 0))
            lines = f.read().decode("utf-8", "ignore").splitlines()
    except (OSError, TypeError):
        return ""
    for line in reversed(lines):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if not isinstance(d, dict) or d.get("type") != "assistant":
            continue
        content = (d.get("message") or {}).get("content") or []
        texts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
        if any(t.strip() for t in texts):
            return "\n".join(texts)
    return ""


def strip_intro(text):
    """Правило стиля «понял так: …» первой строкой — не часть ответа для голоса."""
    lines = [l for l in text.strip().splitlines() if l.strip()]
    if lines and lines[0].lstrip("*_#> ").lower().startswith("понял так"):
        lines = lines[1:]
    return "\n".join(lines)


def clean_md(text):
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    text = re.sub(r"`([^`\s/.]+)`", r"\1", text)      # `слово` — слово; `код с путями` — вон
    text = re.sub(r"`[^`]*`", " ", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = EMOJI.sub(" ", text).replace("⏳", " ")
    lines = []
    for l in text.splitlines():
        if l.strip().startswith("|"):                    # таблица
            continue
        l = re.sub(r"^\s*(#+|>|[-*+]|\d+[.)])\s+", "", l)
        l = re.sub(r"\*\*|__|(?<!\w)[*_]|[*_](?!\w)", "", l).replace("(", " ").replace(")", " ")
        kept = []
        for w in l.split():
            if "/" in w or re.search(r"[A-Za-z]", w) or re.fullmatch(r"[\w.-]+\.\w{1,4}[,.;:]?", w):
                if kept and w[-1] in ",;:" and kept[-1][-1] not in ",;:":
                    kept[-1] += w[-1]                    # запятая выкинутого слова — пауза для голоса
                continue
            kept.append(w)
        l = " ".join(kept)
        if l.strip(" ,.;:—-"):
            lines.append(l.strip())
    return "\n".join(lines)


def first_sentence(text):
    first = text.split("\n", 1)[0] if text else ""
    m = re.match(r"(.+?[.!?…])(\s|$)", first)
    return (m.group(1) if m else first).strip().rstrip(".!?…:;,—- ")


def is_question(body):
    lines = [l for l in body.splitlines() if l.strip()]
    if not lines:
        return False
    last = EMOJI.sub("", lines[-1])
    last = re.sub(r"\s*\([^()]*\)\s*$", "", last)    # «…? (да/нет)»
    return re.sub(r"[\s*_)\"»'\]]+$", "", last).endswith("?")


def decide_stop(body, front, idle, background):
    if background:                                   # ход кончился, а фоновая работа идёт — это ожидание
        return False
    if body.lstrip("*_#> \n").startswith("⏳"):
        return False
    if QUIET.search(first_sentence(clean_md(body)).lower()):
        return False
    if front is None:                                # нет «Универсального доступа» → говорим всегда
        return True
    return (not front) or idle > 60


def bare(w):
    return w.lower().strip(",.:;—-")


def stop_phrase(name, body):
    if not body.strip():
        return name + ": готово", True
    if is_question(body):
        return name + ": есть вопрос к тебе", True
    words = first_sentence(clean_md(body)).split()
    # предлог перед вырезанным путём («в /a/b и» → «в и») — выкинуть
    words = [w for i, w in enumerate(words) if not (bare(w) in PREP and (i + 1 == len(words) or bare(words[i + 1]) in STOP))]
    cut = len(words) > 8
    words = words[:8]
    while words and len(" ".join(words)) > 60:
        words.pop()
        cut = True
    commas = [i for i, w in enumerate(words) if w.endswith(",") and i >= 2]
    if cut and commas:                               # обрезали — по последней запятой, а не на полуслове
        words = words[:commas[-1] + 1]
    while words and bare(words[-1]) in STOP:
        words.pop()
    s = " ".join(words).rstrip(".!?…:;,—- ")
    return (name + ": " + s, False) if s else (name + ": готово", True)


def permission_phrase(name, tool):
    act = ACTIONS.get(tool)
    return name + ": жду разрешения" + (" — " + act if act else "")


# --- очередь и демон ---

def daemon_alive():
    """Демон держит LOCK_EX на voiced.lock; общий замок без ожидания не берётся — значит жив."""
    try:
        with open(path("voiced.lock"), "a") as f:
            try:
                fcntl.flock(f, fcntl.LOCK_SH | fcntl.LOCK_NB)
            except BlockingIOError:
                return True
            fcntl.flock(f, fcntl.LOCK_UN)
            return False
    except OSError:
        return False


def daemon_pid():
    try:
        pid, p = open(path("voiced.pid"), encoding="utf-8").read().split(" ", 1)
        return int(pid), p.strip()
    except (OSError, ValueError):
        return None, ""


def kill_daemon(pid):
    """Только живой процесс голоса: после перезагрузки номер в voiced.pid мог достаться чужому."""
    if not pid or pid <= 1:
        return
    r = run(["ps", "-p", str(pid), "-o", "command="])
    if r is None or "voiced.py" not in r.stdout:
        return
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass


def spawn():
    log_f = open(path("voiced.log"), "a")
    subprocess.Popen([path("venv", "bin", "python"), VOICED], cwd=HOME, stdin=subprocess.DEVNULL,
                     stdout=log_f, stderr=log_f, start_new_session=True)


def oldest_job_age():
    ages = [0.0]
    for f in os.listdir(path("queue")):
        if f.endswith(".json"):
            try:
                with open(os.path.join(path("queue"), f), encoding="utf-8") as fh:
                    ages.append(time.time() - float(json.load(fh).get("created", time.time())))
            except (OSError, ValueError, TypeError, AttributeError):
                pass
    return max(ages)


def give_up(kind, reason):
    """Голос не разбирает очередь: метка broken, очередь пустая, mp3 сейчас, раз в 3 часа — Milena."""
    with open(path("broken"), "w", encoding="utf-8") as f:
        f.write(reason + "\n")
    log(reason)
    for f in os.listdir(path("queue")):
        if f.endswith(".json"):
            remove(os.path.join(path("queue"), f))
    mp3(kind)
    warn_broken()


def deliver(kind, text, name, fixed):
    """Фраза → очередь голоса; демон не жив — поднять; не разбирает очередь или свежая поломка — mp3."""
    if DRYRUN:
        print("say " + text)
        return
    os.makedirs(path("queue"), exist_ok=True)
    broken = age(path("broken"))
    if broken is not None and broken < BROKEN_FRESH:
        mp3(kind)
        warn_broken()
        return
    alive = daemon_alive()
    pid, p = daemon_pid()
    if oldest_job_age() > STUCK:
        if not alive:
            give_up(kind, "голос не запускается — подробности в voiced.log")
            return
        beat = age(path("voiced.beat"))
        if beat is None or beat > 30:               # и старой версии тоже: kill_daemon сам сверит, что это голос
            kill_daemon(pid)
            give_up(kind, "голос завис — не отвечает больше минуты")
            return
    if not alive:
        remove(path("restart"))                      # метка от умершего демона — новому не мешать
        spawn()
    elif p and p != VOICED and not os.path.exists(path("restart")):
        open(path("restart"), "w").close()           # плагин обновился: старый доигрывает и выходит, новый ждёт замок
        spawn()
    job = {"text": text, "kind": kind, "project": name, "fixed": fixed, "created": time.time(),
           "mp3_dir": os.path.join(SOUNDS, kind)}
    tmp = os.path.join(path("queue"), "%d-%d.tmp" % (time.time_ns(), os.getpid()))
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(job, f, ensure_ascii=False)
    os.rename(tmp, tmp[:-4] + ".json")


# --- вход ---

def hook(kind):
    if os.environ.get("FORGE_NESTED"):              # вложенный вызов claude из хуков плагина — молчим совсем
        return
    try:
        data = json.loads(sys.stdin.read() or "{}")
        if not isinstance(data, dict):
            data = {}
    except ValueError:
        data = {}
    if os.path.exists(path("mute")):
        if DRYRUN:
            print("silent")
        return
    if sys.platform != "darwin" or not os.path.exists(path("venv", "bin", "python")):
        mp3(kind)
        return
    root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    name = project_name(root)
    if kind == "permission":
        deliver(kind, permission_phrase(name, data.get("tool_name") or ""), name, True)
        return
    body = strip_intro(answer_text(data))
    front = front_project(root)
    if ACCESS == "denied":
        open(path("no-access"), "w").close()
    elif ACCESS == "ok":
        remove(path("no-access"))
    if not decide_stop(body, front, idle_seconds() if front else 0, data.get("background_tasks")):
        if DRYRUN:
            print("silent")
        return
    text, fixed = stop_phrase(name, body)
    deliver(kind, text, name, fixed)


def command(cmd, args):
    os.makedirs(HOME, exist_ok=True)
    root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    if cmd == "name":
        if not args:
            print(project_name(root))
            return
        try:
            with open(path("names.json"), encoding="utf-8") as f:
                names = json.load(f)
            if not isinstance(names, dict):
                raise ValueError("not a dict")
        except OSError:
            names = {}
        except ValueError:
            os.replace(path("names.json"), path("names.json.bad"))   # испорченную таблицу не затираем молча
            names = {}
        names[root] = " ".join(args).strip()
        tmp = path("names.json.%d.tmp" % os.getpid())
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(names, f, ensure_ascii=False, indent=1)
        os.rename(tmp, path("names.json"))
        print("Голос будет называть этот проект: " + names[root])
    elif cmd == "volume":
        try:
            with open(path("volume")) as f:
                cur = float(f.read().strip())
        except (OSError, ValueError):
            cur = 0.5                                    # как в voiced.py по умолчанию
        arg = args[0].lower() if args else ""
        if arg:
            new = cur * 0.8 if arg == "тише" else cur * 1.25 if arg == "громче" else float(arg.rstrip("%")) / 100
            with open(path("volume"), "w") as f:
                f.write(str(round(min(max(new, 0.01), 1.0), 2)))
            cur = round(min(max(new, 0.01), 1.0), 2)
        print("Громкость голоса: %d%%" % round(cur * 100))
    elif cmd == "mute":
        open(path("mute"), "w").close()
        print("Голос выключен")
    elif cmd == "unmute":
        remove(path("mute"))
        print("Голос включён")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd in ("name", "mute", "unmute", "volume"):
        command(cmd, sys.argv[2:])
        return
    kind = "permission" if cmd == "permission" else "stop"
    try:
        hook(kind)
    except Exception as e:  # хук не должен глушить даже mp3
        log("ошибка: %r" % (e,))
        try:
            mp3(kind)
        except Exception:
            pass


if __name__ == "__main__":
    main()
