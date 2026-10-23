#!/usr/bin/env python3
"""Фоновый голос: держит модель в памяти, берёт фразы из очереди notify.py и озвучивает их по одной.

voiced.py            — демон (запускает notify.py из ~/.claude/forge-voice/venv)
voiced.py --say ТЕКСТ — сказать одну фразу и выйти (установка, проверка)

Один экземпляр — LOCK_EX на voiced.lock (второй ждёт, пока старый доиграет). Разрешения — первыми;
из фраз одного проекта — только последняя; старше 5 минут — выброс. Постоянные фразы — в кэше,
в простое заготавливаются на все проекты из names.json. Сбой — mp3 из задания и строка в voiced.log.
"""
import array
import fcntl
import glob
import hashlib
import json
import math
import os
import random
import re
import subprocess
import sys
import threading
import time
import wave

if not os.environ.get("FORGE_VOICE_ONLINE"):
    os.environ.setdefault("HF_HUB_OFFLINE", "1")      # модель скачана установкой — без сети не висим

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.environ.get("FORGE_VOICE_HOME") or os.path.expanduser("~/.claude/forge-voice")
ONESHOT = bool(os.environ.get("FORGE_VOICE_ONESHOT"))   # тесты: очередь и заготовки разобраны — выход
STALE = 300                                            # с
STALL = 90                                             # с без продвижения — пульс замирает, notify.py видит зависание
FIXED = ("жду разрешения", "жду разрешения — хочу запустить команду", "жду разрешения — хочу изменить файл",
         "жду разрешения — хочу в интернет", "есть вопрос к тебе", "готово")
progress = time.time()                                 # основной цикл двигает на каждом этапе
# Модель держится в памяти всё время (~3 ГБ) — сознательно; выгружать по простою, если памяти станет мало.


def path(*p):
    return os.path.join(HOME, *p)


def log(line):
    try:
        with open(path("voiced.log"), "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + "voiced: " + line + "\n")
    except OSError:
        pass


def remove(p):
    try:
        os.remove(p)
    except OSError:
        pass


def tick():
    global progress
    progress = time.time()


def rotate_log():
    p = path("voiced.log")
    try:
        if os.path.getsize(p) > 1_000_000:
            with open(p, "rb") as f:
                f.seek(-200_000, 2)
                tail = f.read()
            with open(p, "wb") as f:
                f.write(tail.split(b"\n", 1)[-1])      # с начала строки — не посреди буквы
    except OSError:
        pass


def clean_leftovers():
    """Хвосты прошлого запуска, убитого посреди фразы (notify.py убивает зависший голос через SIGKILL)."""
    for pattern in ("live-*.wav", "say-*.wav", "cache/*.tmp.wav", "cache/*.raw.wav", "queue/*.tmp"):
        for f in glob.glob(path(pattern)):
            try:
                if time.time() - os.path.getmtime(f) > 60:
                    os.remove(f)
            except OSError:
                pass


def volume():
    try:
        with open(path("volume")) as f:
            v = float(f.read().strip())
        if math.isfinite(v):
            return str(min(max(v, 0.0), 2.0))
    except (OSError, ValueError):
        pass
    return "0.5"


# --- движки ---

class Chatterbox:
    """Копия голоса VASKO (DEC-21): Chatterbox Multilingual, ударения сам (russian_text_stresser), темп и тембр — ffmpeg."""

    def __init__(self):
        import perth
        import torch
        import torchaudio
        if perth.PerthImplicitWatermarker is None:      # на маке настоящий водяной знак не грузится
            perth.PerthImplicitWatermarker = perth.DummyWatermarker
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        load = torch.load
        torch.load = lambda *a, **k: load(*a, **{**k, "map_location": torch.device(device)})
        from chatterbox.mtl_tts import ChatterboxMultilingualTTS
        self.model = ChatterboxMultilingualTTS.from_pretrained(device=device)
        self.model.prepare_conditionals(path("ref", "vasko.wav"), exaggeration=0.4)   # образец голоса — один раз
        self.ta = torchaudio

    def generate(self, text, out):
        raw = out + ".raw.wav"
        try:
            wav = self.model.generate(text, language_id="ru", cfg_weight=0.3, exaggeration=0.4)
            self.ta.save(raw, wav, self.model.sr)
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", raw,
                            "-af", "asetrate=22080,aresample=24000,atempo=0.9783", out], check=True, timeout=60)
        finally:
            remove(raw)


class Fake:
    """Учебный движок для тестов: тишина длиной по тексту; «БОРМОТАНИЕ» — слишком длинно, «СБОЙ» — ошибка."""

    def __init__(self):
        if os.environ.get("FORGE_VOICE_ENGINE") == "fake-broken":
            raise RuntimeError("учебный движок не загрузился")

    def generate(self, text, out):
        with open(os.environ.get("FORGE_VOICE_FAKE_LOG", os.devnull), "a", encoding="utf-8") as f:
            f.write("gen " + text + "\n")
        if "СБОЙ" in text:
            raise RuntimeError("учебный сбой генерации: " + text)

        def tone(seconds, amp):                            # «звук» без пауз
            return b"".join((amp if (i // 20) % 2 else -amp).to_bytes(2, "little", signed=True)
                            for i in range(int(8000 * seconds)))
        if "БОРМОТАНИЕ" in text:
            frames = tone(20 + 0.5 * len(text), 8000)
        elif "ХВОСТ" in text:                             # речь, пауза, шум после фразы
            frames = tone(0.09 * len(text), 4000) + b"\0\0" * 2400 + tone(2.5, 16000)
        elif "ДВЕЧАСТИ" in text:                          # медленная речь с паузой — не хвост
            frames = tone(0.09 * len(text), 6000) + b"\0\0" * 2400 + tone(1.9, 6000)
        elif "ШОРОХ" in text:                     # хвост короче прежнего запаса по длине
            frames = tone(0.09 * len(text), 6000) + b"\0\0" * 4000 + tone(0.8, 2000)
        elif "ТИШИНАСНАЧАЛА" in text:                     # тишина, потом речь — резать нечего
            frames = b"\0\0" * 24000 + tone(3.0, 6000)
        elif "ДЛИННАЯПАУЗА" in text:                      # речь, долгая тишина, тихий шорох
            frames = tone(0.09 * len(text), 6000) + b"\0\0" * 4800 + tone(1.5, 1500)
        else:
            frames = b"\0\0" * int(8000 * 0.05 * len(text))
        with wave.open(out, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(8000)
            w.writeframes(frames)


def load_engine():
    return Fake() if os.environ.get("FORGE_VOICE_ENGINE", "").startswith("fake") else Chatterbox()


# --- фраза → звук ---

def normalize(text):
    """Цифры словами: «60%» → «шестьдесят процентов», «06:41» → «шесть сорок один»."""
    text = re.sub(r"(\d):(\d)", r"\1 \2", text.replace("%", " процентов"))
    try:
        from num2words import num2words
        text = re.sub(r"\d+", lambda m: " " + num2words(int(m.group()), lang="ru") + " ", text)
    except ImportError:
        pass
    return re.sub(r"\s+", " ", text).strip()


def duration(wav_path):
    with wave.open(wav_path) as w:
        return w.getnframes() / float(w.getframerate())


def mumbled(wav_path, spoken):
    """Зациклилась модель: настоящая речь VASKO на темпе 0.9 — ~0.09 с на символ («Плагин: есть вопрос к тебе» — 2.2 с)."""
    return duration(wav_path) > 0.2 * len(spoken) + 2


def trim_tail(wav_path, spoken):
    """Модель иногда дописывает шум после фразы (речь, пауза, громкий хвост). Запись длиннее ожидаемого —
    режем по первой паузе ≥ 150 мс после 60% ожидаемой длины, если пауза ≥ 0.4 с (внутри фразы таких нет)
    или после неё ≥ 1 с звука заметно громче речи (настоящий хвост: −6…−10 дБ против −17…−24). True — обрезано."""
    with wave.open(wav_path) as w:
        sr, n, sw, ch = w.getframerate(), w.getnframes(), w.getsampwidth(), w.getnchannels()
        frames = w.readframes(n)
    expected = 0.11 * len(spoken) + 0.4
    # речь VASKO ~0.09 с/символ: длиннее — проверяем; от среза настоящей речи защищают правила паузы и громкости ниже
    if sw != 2 or ch != 1 or n / sr <= 0.09 * len(spoken) + 0.5:
        return False
    a = array.array("h")
    a.frombytes(frames)
    win = max(int(sr * 0.05), 1)
    level = [math.sqrt(sum(x * x for x in a[i:i + win]) / max(len(a[i:i + win]), 1)) for i in range(0, n, win)]

    def loudness(ws):                                      # средняя громкость звучащих окон
        ws = [x for x in ws if x >= 328]
        return sum(ws) / len(ws) if ws else 0.0
    run = 0
    for k in range(int(0.6 * expected / 0.05), len(level)):
        run = run + 1 if level[k] < 328 else 0             # −40 дБ — пауза
        if run < 3:
            continue
        gap = k - run + 1
        end = k
        while end + 1 < len(level) and level[end + 1] < 328:
            end += 1
        before, after = level[:gap], level[end + 1:]
        if loudness(before) == 0:
            return False                                   # до паузы тишина — отрезали бы саму речь
        long_pause = (end - gap + 1) * 0.05 >= 0.4        # внутри фразы пауз такой длины не бывает
        loud_tail = len(after) * 0.05 >= 1.0 and loudness(after) >= 1.4 * loudness(before)
        if not (long_pause or loud_tail):
            return False                                   # дальше обычная речь, а не шум — не трогаем
        cut = (gap + 1) * win                              # пауза — первые 50 мс оставляем
        fade = min(int(sr * 0.03), cut)
        for i in range(fade):
            a[cut - fade + i] = int(a[cut - fade + i] * (fade - i) / fade)
        tmp = wav_path + ".trim.tmp.wav"
        with wave.open(tmp, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes(a[:cut].tobytes())
        os.replace(tmp, wav_path)                          # кэш не остаётся полузаписанным
        return True
    return False


def trim_safe(wav_path, spoken):
    """Обрезка — украшение: сбой не должен терять фразу."""
    try:
        return trim_tail(wav_path, spoken)
    except Exception as e:
        log("обрезка не вышла (%r): %s" % (e, wav_path))
        return False


def trim_cached():
    """Записи, заготовленные до обрезки хвоста, — подрезать при старте (тексты известны: names.json × FIXED)."""
    try:
        with open(path("names.json"), encoding="utf-8") as f:
            names = json.load(f)
    except (OSError, ValueError):
        return
    for n in (names.values() if isinstance(names, dict) else []):
        if not isinstance(n, str) or not n.strip():
            continue
        n = n[:1].upper() + n[1:]
        for suffix in FIXED:
            f = cache_file(n + ": " + suffix)
            if os.path.exists(f):
                if trim_safe(f, normalize(n + ": " + suffix)):
                    log("обрезал хвост: " + n + ": " + suffix)
        tick()


def play_wav(wav_path, text):
    """True — сыграно; False — проигрыватель не смог (битый файл, занятый звук)."""
    player = os.environ.get("FORGE_VOICE_PLAYER", "")
    if player.startswith("log:"):
        with open(player[4:], "a", encoding="utf-8") as f:
            f.write("say " + text + "\n")
        return True
    r = subprocess.run(["afplay", "-v", volume(), wav_path], timeout=60)
    return r.returncode == 0


def play_mp3(mp3_dir):
    try:
        files = [f for f in os.listdir(mp3_dir) if f.endswith(".mp3")] if mp3_dir and os.path.isdir(mp3_dir) else []
        if not files:
            return
        f = os.path.join(mp3_dir, random.choice(files))
        player = os.environ.get("FORGE_VOICE_PLAYER", "")
        if player.startswith("log:"):
            with open(player[4:], "a", encoding="utf-8") as fh:
                fh.write(f + "\n")
        else:
            subprocess.run(["afplay", "-v", "0.05", f], timeout=30)
    except Exception as e:
        log("и mp3 не сыгрался: %r" % (e,))


def cache_file(text):
    return path("cache", hashlib.sha1(text.encode("utf-8")).hexdigest() + ".wav")


def cached(engine, text):
    """Постоянная фраза: из кэша или сгенерировать (одна повторная попытка при «бормотании»); None — не вышло."""
    os.makedirs(path("cache"), exist_ok=True)
    out = cache_file(text)
    if os.path.exists(out) and os.path.getsize(out) > 44:
        return out
    spoken = normalize(text)
    tmp = out + ".tmp.wav"
    try:
        for _ in range(2):
            tick()
            engine.generate(spoken, tmp)
            trim_safe(tmp, spoken)
            if not mumbled(tmp, spoken):
                os.rename(tmp, out)
                return out
            log("бормотание, переделываю: " + text)
        return None
    finally:
        remove(tmp)


def say_cached(engine, text, mp3_dir):
    wav = cached(engine, text)
    tick()
    if wav and play_wav(wav, text):
        return
    if wav:
        remove(wav)                                    # проигрыватель не принял — файл битый, сделать заново
    log("постоянная фраза не прозвучала — mp3: " + text)
    play_mp3(mp3_dir)


def speak(engine, job):
    text, mp3_dir = job["text"], job.get("mp3_dir")
    tmp = path("live-%d.wav" % os.getpid())
    try:
        if job.get("fixed"):
            t = time.time()
            say_cached(engine, text, mp3_dir)
            log("сказал «%s» (постоянная): ждало %.0f с, с проигрыванием %.1f с" % (text, job.get("_age", 0), time.time() - t))
            return
        spoken = normalize(text)
        tick()
        t = time.time()
        engine.generate(spoken, tmp)
        trim_safe(tmp, spoken)
        log("сказал «%s»: ждало %.0f с, делалось %.1f с, звучит %.1f с" % (text, job.get("_age", 0), time.time() - t, duration(tmp)))
        if mumbled(tmp, spoken):
            log("бормотание в живой фразе — говорю «готово»: " + text)
            say_cached(engine, str(job.get("project") or "") + ": готово", mp3_dir)
            return
        tick()
        if not play_wav(tmp, text):
            play_mp3(mp3_dir)
    except Exception as e:
        log("сбой озвучки (%r) — mp3: %s" % (e, text))
        play_mp3(mp3_dir)
    finally:
        remove(tmp)


# --- очередь ---

def take_job():
    """Следующее задание: разрешения первыми, у проекта — только последняя фраза, старьё — вон."""
    try:
        names = sorted(os.listdir(path("queue")))
    except OSError:
        os.makedirs(path("queue"), exist_ok=True)
        return None
    muted = os.path.exists(path("mute"))
    jobs = []
    for f in names:
        if not f.endswith(".json"):
            continue
        p = os.path.join(path("queue"), f)
        try:
            with open(p, encoding="utf-8") as fh:
                j = json.load(fh)
            if not isinstance(j, dict) or not isinstance(j.get("text"), str) or not isinstance(j.get("project", ""), str):
                raise ValueError("не то задание")
            j["_path"], j["_age"] = p, time.time() - float(j["created"])
            if not math.isfinite(j["_age"]):
                raise ValueError("время создания")
        except FileNotFoundError:
            continue
        except Exception as e:
            log("битое задание %s (%r) — выброшено" % (f, e))
            remove(p)
            continue
        if muted:
            remove(p)                                  # «выключи голос» — то, что успело встать в очередь, тоже молчит
        else:
            jobs.append(j)
    fresh = []
    for j in jobs:
        if j["_age"] > STALE:
            log("устарело (%d с) — выброшено: %s" % (j["_age"], j["text"]))
            remove(j["_path"])
        else:
            fresh.append(j)
    latest = {}
    for j in sorted(fresh, key=lambda j: -j["_age"]):
        if j.get("kind") != "permission":
            prev = latest.get(j.get("project", ""))
            if prev:
                remove(prev["_path"])
            latest[j.get("project", "")] = j
    rest = [j for j in fresh if j.get("kind") == "permission"] + list(latest.values())
    if not rest:
        return None
    j = sorted(rest, key=lambda j: (j.get("kind") != "permission", -j["_age"]))[0]
    remove(j["_path"])
    return j


def next_pregen(failed):
    try:
        with open(path("names.json"), encoding="utf-8") as f:
            names = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(names, dict):
        return None
    for n in names.values():
        if not isinstance(n, str) or not n.strip():
            continue
        n = n[:1].upper() + n[1:]
        for suffix in FIXED:
            text = n + ": " + suffix
            if text not in failed and not os.path.exists(cache_file(text)):
                return text
    return None


def heartbeat():
    """Пульс — пока основной цикл продвигается; завис (модель, ffmpeg) — пульс замирает, notify.py это видит."""
    while True:
        if time.time() - progress < STALL:
            try:
                open(path("voiced.beat"), "w").close()
            except OSError:
                pass
        time.sleep(5)


def daemon():
    os.makedirs(path("queue"), exist_ok=True)
    lock = open(path("voiced.lock"), "a")
    fcntl.flock(lock, fcntl.LOCK_EX)                   # старый демон доигрывает — ждём
    with open(path("voiced.pid"), "w", encoding="utf-8") as f:
        f.write("%d %s" % (os.getpid(), os.path.abspath(__file__)))
    remove(path("restart"))                            # метка была для старого (после pid — чтобы notify.py не спавнил лишнего)
    global progress
    progress = time.time() + 300                       # загрузка модели с холодного диска бывает дольше STALL
    threading.Thread(target=heartbeat, daemon=True).start()
    rotate_log()
    clean_leftovers()
    try:
        engine = load_engine()
    except Exception as e:
        with open(path("broken"), "w", encoding="utf-8") as f:
            f.write("голос не загрузился: %r\n" % (e,))
        log("модель не загрузилась: %r" % (e,))
        sys.exit(1)
    remove(path("broken"))
    tick()
    trim_cached()
    log("голос готов")
    failed = set()                                     # заготовки, которые не вышли, — до перезапуска не повторяем
    while not os.path.exists(path("restart")):
        tick()
        try:
            job = take_job()
            if job:
                speak(engine, job)
                continue
            text = next_pregen(failed)
            if text:
                try:
                    if not cached(engine, text):
                        failed.add(text)
                except Exception as e:
                    failed.add(text)
                    log("заготовка не вышла (%r): %s" % (e, text))
                continue
        except Exception as e:                         # одна кривая итерация не роняет голос
            log("сбой в цикле: %r" % (e,))
            time.sleep(1)
            continue
        if ONESHOT:
            return
        time.sleep(0.3)
    log("новая версия плагина — выхожу")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--say":
        if len(sys.argv) < 3:
            print("использование: voiced.py --say ТЕКСТ", file=sys.stderr)
            sys.exit(2)
        os.makedirs(HOME, exist_ok=True)
        t = time.time()
        engine = load_engine()
        loaded = time.time() - t
        text = " ".join(sys.argv[2:])
        tmp = path("say-%d.wav" % os.getpid())
        try:
            t = time.time()
            engine.generate(normalize(text), tmp)
            trim_safe(tmp, normalize(text))
            made = time.time() - t
            play_wav(tmp, text)
            print("загрузка %.1f с, фраза %.1f с, звучит %.1f с" % (loaded, made, duration(tmp)))
        finally:
            remove(tmp)
        return
    daemon()


if __name__ == "__main__":
    main()
