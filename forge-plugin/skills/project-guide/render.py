#!/usr/bin/env python3
"""Рендерер гайда по проекту (Фаза 5). Только стандартная библиотека.

Данные — .forge/guide/vX.Y.json (память проекта, коммитится; последняя версия = максимум по имени файла),
выход — docs/guide/guide-vX.Y.html + guide-latest.html (побайтовая копия), PDF рядом через Chrome.
Клод пишет только JSON; HTML собирает этот скрипт по образцу гайда Vespera (forge-plugin/docs/project-guide-format.md).

Режимы:
  bump    [major]                    новая версия: копия последней → vX.(Y+1) (major → v(X+1).0);
                                     нет версий → v1.0 с P1 + миграция старого отчёта .forge/status-report.json
  render  [json] [out.html]          собрать HTML; без аргументов — последняя версия → docs/guide/ + built_at;
                                     с out.html — только этот файл (макет), JSON не трогается
  pdf     [html] [pdf]               PDF через Chrome headless (FORGE_CHROME=/путь переопределяет поиск)
  verdict <код> <статус> [текст]     ответ владельца по одному коду: решения — accepted|changed|discuss|works|dropped,
                                     риски R<n> — agreed|done|up|down|deferred|changed
  merged  <task-slug>                после мержа: находка с task_slug → done, stale_tasks+1, пересобрать
  link    <id|R-код> <task-slug>     привязать находку к задаче (new-task)
  summary                            одна строка для session-start; пусто — если напоминать нечего
Всегда exit 0 (кроме неверных аргументов) — гайд не должен ронять основной процесс.
"""

import base64
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import date
from pathlib import Path

GUIDE_DIR = Path(".forge/guide")
DOCS_DIR = Path("docs/guide")
LEGACY_JSON = Path(".forge/status-report.json")
VER_RE = re.compile(r"^v(\d+)\.(\d+)\.json$")
CODE_RE = re.compile(r"^[A-Z]\d+$")
CHROME_CANDIDATES = ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "google-chrome", "chromium", "chromium-browser"]
MIME = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}
# Служебный мусор .forge — построчно равен heredoc в skills/memory-backup/backup.sh и commands/init.md
FORGE_IGNORE = [".inject-state", ".last-backup", ".migration-declined", "state.yml",
                ".github-*", "graph.json", "guide/shots/"]
GUIDE_LINES = ("guide/shots/",)
NO_GUIDE = "FORGE-GUIDE: гайд ещё не собирали — скажи «собери гайд»"

UNANSWERED = {"default", "open", "discuss"}            # «ждут ответа»
ANSWERED = {"accepted", "changed", "works", "dropped"}  # 🔥 гаснет
CHIP = {"default": ("dflt", "дефолт"), "accepted": ("acc", "принято"), "changed": ("acc", "переделано"),
        "discuss": ("dsc", "обсудить"), "works": ("dflt", "уже работает"), "open": ("dsc", "открыто")}
GROUP_BASE = {"P": "Процесс", "O": "Открытые вопросы"}
TIER = {"crit": "crit", "biz": "warn", "imp": "mid", "pol": "mid"}
TIER_HEAD = [("crit", "🔴 Критичные — закрыть в первую очередь"),
             ("warn", "🟠 Высокие — ближайший месяц"),
             ("mid", "🟡 Средние — держать в поле зрения")]
SECTIONS = [("00", "Где мы сейчас — за 30 секунд"), ("01", "Что это такое"), ("02", "Из чего состоит"),
            ("03", "Главный путь по шагам"), ("04", "Кто и что делает"), ("05", "Решения"),
            ("06", "Карта рисков"), ("07", "План"), ("08", "Словарик")]
EMPTY = '<p class="empty">раздел появится в следующей версии</p>'
HOWTO_DEFAULT = ("Ответы — владельцу проекта в любом виде: списком кодов, голосом, в переписке; "
                 "он вносит их в гайд, и следующая версия выйдет с обновлёнными статусами")

DEC_STATUSES = ("accepted", "changed", "discuss", "works", "dropped")
RISK_STATUSES = ("agreed", "done", "up", "down", "deferred", "changed")
LABEL = {"accepted": "принято", "changed": "переделано", "discuss": "обсудить", "works": "уже работает", "dropped": "снято",
         "agreed": "предложение принято", "done": "сделано", "up": "приоритет выше", "down": "приоритет ниже", "deferred": "отложено"}
# Голосовой ввод: кириллица в коде — сначала по звуку (Р→R), не нашли — по глифу (Р→P)
SOUND = str.maketrans("РПНБВДКМТАОЕС", "RPNBVDKMTAOES")
GLYPH = str.maketrans("РНВСАОЕКМТ", "PHBCAOEKMT")

P1 = {"code": "P1", "group": "P", "group_title": "Процесс", "title": "Правило дефолта", "status": "default", "fire": False,
      "source": "плагин forge",
      "what": "По каждому пункту с меткой «дефолт» есть наша рекомендация. Если возражений нет — действуем по ней и не стоим; передумать можно позже.",
      "why": "Двигает проект вперёд без бесконечных согласований, и всегда видно, что и когда решили."}

# CSS эталона (гайд Vespera) как есть + классы, которых в эталоне не было
CSS = """
@page{size:A4;margin:16mm 14mm}
:root{
  --bg:#FFFFFF; --card:#FBF7EF; --border:#E2D5C3;
  --text:#33291F; --text2:#6E6258; --muted:#8A7A67;
  --accent:#A9603C; --accent-d:#8C4A2B; --accent-bg:#F4E9DE;
  --crit:#B0472F; --crit-bg:#F6DFD6; --warn:#9A6B22; --warn-bg:#F3E7CF;
  --ok:#6B7A52; --ok-bg:#EAEDDF;
}
*{box-sizing:border-box}
body{background:var(--bg);color:var(--text);font-family:'Golos Text',system-ui,sans-serif;font-size:10.5pt;line-height:1.5;margin:0}
h1{font-family:'Playfair Display',serif;font-size:23pt;font-weight:700;line-height:1.15;margin:0 0 6pt}
h2{font-family:'Playfair Display',serif;font-size:16pt;font-weight:600;margin:22pt 0 6pt;break-after:avoid}
h2 .no{color:var(--accent);margin-right:6pt}
h3{font-size:11.5pt;font-weight:600;margin:14pt 0 6pt;break-after:avoid}
p{margin:6pt 0}
.brandline{display:flex;align-items:center;gap:10pt;margin-bottom:12pt}
.logo{width:30pt;height:30pt;border-radius:8pt;background:var(--accent);color:#FFFCF6;display:flex;align-items:center;justify-content:center;font-family:'Playfair Display',serif;font-size:16pt;font-weight:700}
.bn{font-family:'Playfair Display',serif;font-size:13pt;font-weight:600}
.bd{font-size:8.5pt;color:var(--muted)}
.sub{font-size:11pt;color:var(--text2);margin:0 0 10pt}
.howto{background:var(--accent-bg);border:1pt solid var(--border);border-radius:10pt;padding:10pt 12pt;margin:12pt 0;break-inside:avoid}
.howto b{color:var(--accent-d)}
.howto .ex{font-family:ui-monospace,Menlo,monospace;font-size:9pt;background:var(--bg);border:1pt solid var(--border);border-radius:6pt;padding:6pt 8pt;margin-top:6pt}
.card{background:var(--card);border:1pt solid var(--border);border-radius:10pt;padding:9pt 11pt;margin:8pt 0;break-inside:avoid}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:8pt}
.svc .t{font-weight:600;font-size:10.5pt}
.svc .d{font-size:9.5pt;color:var(--text2);margin-top:2pt}
.svc .cd{font-size:8pt;color:var(--accent-d);font-weight:600}
/* схема */
.scheme{display:flex;align-items:stretch;gap:0;margin:12pt 0;break-inside:avoid}
.sbox{flex:1;background:var(--card);border:1pt solid var(--border);border-radius:10pt;padding:8pt 9pt;text-align:center}
.sbox .st{font-weight:600;font-size:10pt}
.sbox .sd{font-size:8.5pt;color:var(--text2);margin-top:2pt}
.sarr{display:flex;flex-direction:column;justify-content:center;padding:0 4pt;color:var(--accent);font-size:12pt}
.sarr small{font-size:7pt;color:var(--muted);text-align:center}
.flow{counter-reset:st;display:flex;flex-direction:column;gap:5pt;margin:10pt 0}
.fstep{background:var(--card);border:1pt solid var(--border);border-radius:8pt;padding:7pt 10pt 7pt 34pt;position:relative;font-size:9.8pt;break-inside:avoid}
.fstep::before{counter-increment:st;content:counter(st);position:absolute;left:8pt;top:6pt;width:18pt;height:18pt;border-radius:50%;background:var(--accent-bg);color:var(--accent-d);font-weight:600;font-size:9pt;display:flex;align-items:center;justify-content:center}
table{border-collapse:collapse;width:100%;font-size:9.5pt;margin:8pt 0;break-inside:avoid}
th,td{border:1pt solid var(--border);padding:5pt 8pt;text-align:left;vertical-align:top}
th{background:var(--accent-bg);font-weight:600}
/* решения */
.dcs{background:var(--card);border:1pt solid var(--border);border-radius:10pt;padding:9pt 11pt;margin:7pt 0;break-inside:avoid}
.dcs .dh{display:flex;align-items:baseline;gap:8pt;flex-wrap:wrap}
.code{font-family:ui-monospace,Menlo,monospace;font-weight:700;font-size:10.5pt;background:var(--accent);color:#FFFCF6;border-radius:6pt;padding:1pt 7pt}
.code.o{background:var(--warn)}
.dcs .dt{font-weight:600;font-size:10.5pt}
.dcs .what{font-size:9.8pt;margin:5pt 0 2pt}
.dcs .why{font-size:9.3pt;color:var(--text2);margin:2pt 0 0}
.dcs .why b,.dcs .what b{font-weight:600}
.gt{font-size:9pt;color:var(--muted);margin:2pt 0 8pt}
/* риски */
.risk{border:1pt solid var(--border);border-left:3pt solid var(--muted);border-radius:8pt;padding:7pt 10pt;margin:6pt 0;break-inside:avoid;background:var(--card)}
.risk.crit{border-left-color:var(--crit)}
.risk.warn{border-left-color:var(--warn)}
.risk .rt{font-weight:600;font-size:10pt}
.risk .rt .rc{font-family:ui-monospace,Menlo,monospace;color:var(--crit);font-weight:700;margin-right:4pt}
.risk.warn .rt .rc{color:var(--warn)}
.risk.mid .rt .rc{color:var(--accent-d)}
.risk p{font-size:9.3pt;color:var(--text2);margin:3pt 0}
.risk p b{color:var(--ok);font-weight:600}
ul.clean{padding-left:14pt;margin:6pt 0}
ul.clean li{margin:3pt 0}
.gl{font-size:9.5pt;columns:2;column-gap:16pt}
.gl dt{font-weight:600;margin-top:6pt}
.gl dd{margin:1pt 0 0;color:var(--text2)}
footer{margin-top:24pt;padding-top:8pt;border-top:1pt solid var(--border);font-size:8.5pt;color:var(--muted)}
.pagebreak{break-before:page}
.facts{display:grid;grid-template-columns:1fr 1fr;gap:6pt;margin:8pt 0}
.fact{background:var(--ok-bg);border-radius:8pt;padding:6pt 9pt;font-size:9.3pt}
.fact b{color:var(--ok)}
.fire{font-size:8pt;font-weight:700;letter-spacing:.03em;background:var(--crit-bg);color:var(--crit);border-radius:5pt;padding:1pt 6pt;text-transform:uppercase}
.dflt{font-size:8pt;font-weight:600;background:var(--ok-bg);color:var(--ok);border-radius:5pt;padding:1pt 6pt}
.week{background:var(--crit-bg);border-radius:10pt;padding:10pt 12pt;margin:10pt 0;break-inside:avoid}
.week .wt{font-weight:700;font-size:10.5pt;color:var(--crit)}
.week ul{margin:4pt 0 0;padding-left:14pt;font-size:9.8pt}
.week li{margin:3pt 0}
.shots{display:grid;grid-template-columns:repeat(4,1fr);gap:8pt;margin:10pt 0;break-inside:avoid}
.shot{margin:0}
.shot img{width:100%;border:1pt solid var(--border);border-radius:8pt;display:block}
.shot figcaption{font-size:8.3pt;color:var(--muted);text-align:center;margin-top:3pt}
.rmap{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8pt;margin:10pt 0}
.rcol{background:var(--card);border:1pt solid var(--border);border-radius:10pt;padding:9pt 11pt;break-inside:avoid}
.rcol .rh{font-weight:700;font-size:10pt;margin-bottom:4pt}
.rcol.now .rh{color:var(--crit)} .rcol.next .rh{color:var(--warn)} .rcol.later .rh{color:var(--ok)}
.rcol ul{margin:0;padding-left:12pt;font-size:9pt}
.rcol li{margin:3pt 0}
/* мокап телеграм-чата партнёра */
.tgmock{background:var(--accent-bg);border:1pt solid var(--border);border-radius:12pt;padding:10pt 12pt;display:flex;flex-direction:column;gap:5pt;max-width:340pt;break-inside:avoid}
.tgb{border-radius:10pt;padding:6pt 9pt;font-size:8.8pt;line-height:1.45;white-space:pre-line;max-width:85%}
.tgb.bot{background:var(--card);border:1pt solid var(--border);align-self:flex-start}
.tgb.me{background:var(--accent);color:#FFFCF6;align-self:flex-end}
.tgb.sysnote{background:none;border:none;color:var(--muted);font-size:8pt;align-self:flex-start;padding:0 4pt}
.tgbtns{display:flex;gap:4pt;margin-top:3pt}
.tgbtn{background:var(--accent-bg);border:1pt solid var(--border);border-radius:6pt;padding:2pt 8pt;font-size:8pt;color:var(--accent-d);font-weight:600}
.shots3{display:grid;grid-template-columns:repeat(3,1fr);gap:8pt;margin:10pt 0;break-inside:avoid}
.shots2{display:grid;grid-template-columns:1fr 1fr;gap:10pt;margin:10pt 0;break-inside:avoid}
.shots3 .shot img,.shots2 .shot img{width:100%;border:1pt solid var(--border);border-radius:8pt;display:block}
.shotwide{margin:8pt 0;break-inside:avoid}
.shotwide img{width:100%;border:1pt solid var(--border);border-radius:8pt;display:block}
.shotwide figcaption{font-size:8.3pt;color:var(--muted);margin-top:3pt}
.acc{font-size:8pt;font-weight:600;background:var(--ok-bg);color:var(--ok);border-radius:5pt;padding:1pt 6pt}
.dsc{font-size:8pt;font-weight:600;background:var(--warn-bg);color:var(--warn);border-radius:5pt;padding:1pt 6pt}
.dcs .was{display:block;font-size:8.8pt;color:var(--muted);text-decoration:line-through;margin:2pt 0}
.dcs .vd{display:block;font-size:8.8pt;color:var(--accent-d);margin-top:3pt}
.risk.done{opacity:.55}.risk.done .rt{text-decoration:line-through}
.risk .slug{font-family:ui-monospace,Menlo,monospace;font-size:8pt;color:var(--accent-d)}
.risk .shot img{width:100%;border:1pt solid var(--border);border-radius:8pt;margin-top:4pt}
.changes{background:var(--card);border:1pt solid var(--border);border-radius:10pt;padding:8pt 12pt;margin:10pt 0;font-size:9.5pt;break-inside:avoid}
.changes .ct{font-weight:600;color:var(--accent-d)}
.empty{font-size:9.3pt;color:var(--muted);font-style:italic}
/* на экране — читаемая колонка; печать/PDF остаются как у эталона (@page A4) */
@media screen{body{max-width:960px;margin:0 auto;padding:28px 36px 48px}}
"""


def esc(s):
    """Экранирование + минимальная разметка **жирный**. Опечатка в тексте вёрстку не ломает."""
    t = html.escape(str(s or ""), quote=True)
    return re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)


def attr(s):
    """Для значений атрибутов и <title>: только экранирование, **жирный** там был бы виден тегами."""
    return html.escape(str(s or ""), quote=True)


def plural(n, one, few, many):
    n = abs(int(n))
    if n % 10 == 1 and n % 100 != 11:
        return f"{n} {one}"
    if 2 <= n % 10 <= 4 and not 12 <= n % 100 <= 14:
        return f"{n} {few}"
    return f"{n} {many}"


def lower1(t):
    t = str(t or "")
    return t[:1].lower() + t[1:]


class GuideBroken(Exception):
    """Битый JSON гайда: сообщаем по-человечески и выходим с кодом 0 — merged зовут посреди мержа."""


def load(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError, OSError) as e:
        raise GuideBroken(f"FORGE-GUIDE: файл гайда повреждён ({path}: {e}) — почини JSON или верни из git: git checkout -- {path}") from e
    if not isinstance(data, dict):
        raise GuideBroken(f"FORGE-GUIDE: файл гайда повреждён ({path}: не объект JSON) — почини JSON или верни из git: git checkout -- {path}")
    for k in ("decisions", "findings", "pending_changes", "changelog"):  # null вместо списка/объекта — как пусто
        if not isinstance(data.get(k), list):
            data[k] = []
    for k in ("meta", "snapshot", "about", "plan"):
        if not isinstance(data.get(k), dict):
            data[k] = {}
    return data


def save(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# ---------- модель: версии, index.yml, каркас ----------

def versions(d=GUIDE_DIR):
    """[(major, minor, path)] по именам файлов. Отдельного latest.json нет — нечему разъехаться."""
    out = []
    for p in Path(d).glob("v*.json"):
        m = VER_RE.match(p.name)
        if m:
            out.append((int(m.group(1)), int(m.group(2)), p))
    return sorted(out)


def latest_json():
    vs = versions()
    return vs[-1][2] if vs else None


def ver_of(data):
    return str((data.get("meta") or {}).get("version", "1.0"))


def read_index():
    """project и version из .forge/index.yml без PyYAML — две строки regex по верхнему уровню."""
    try:
        t = Path(".forge/index.yml").read_text(encoding="utf-8")
    except OSError:
        return {}

    def g(k):
        m = re.search(rf"^{k}:[ \t]*(.+?)[ \t]*$", t, re.M)
        return m.group(1).strip().strip("\"'") if m else ""
    return {"project": g("project"), "project_version": g("version")}


def skeleton(today, project=""):
    ix = read_index()
    return {"meta": {"project": ix.get("project") or project or "Проект", "version": "1.0",
                     "project_version": ix.get("project_version", ""), "date": today,
                     "audience": "для владельца проекта", "eyebrow": "", "built_from": ""},
            "built_at": None, "updated_at": today, "stale_tasks": 0, "sources": {"analysts": 0, "found": 0},
            "snapshot": {"facts": [], "howto_extra": ""},
            "about": {"text": "", "after": "", "scheme": [], "screens": []},
            "parts": [], "flow": [], "roles": [], "decisions": [dict(P1)], "findings": [],
            "plan": {"now": [], "next": [], "later": []}, "glossary": [], "tg_mocks": [],
            "changelog": [], "pending_changes": []}


# ---------- хелперы по данным ----------

def risk_code(f):
    return "R" + (re.sub(r"\D", "", str(f.get("id", ""))) or "?")


def group_of(d):
    return str(d.get("group") or str(d.get("code") or "?")[:1]).upper()


def is_fire(d):
    return bool(d.get("fire")) and (d.get("status") or "open") not in ANSWERED


def moved_out(f):
    """Находка-решение, вынесенная в открытый вопрос O<n>: не «отложена», а живёт в разделе 05."""
    return (f.get("owner") in ("decision", "both") and f.get("status") == "deferred"
            and any(re.match(r"^O\d+$", str(x)) for x in (f.get("links") or [])))


def groups(decisions):
    """[(буква, заголовок)]: P первой, буквы проекта по алфавиту, O последней. P и O есть всегда, даже пустые."""
    seen = {}
    for d in decisions:
        if d.get("status") == "dropped":
            continue
        g = group_of(d)
        seen.setdefault(g, d.get("group_title") or GROUP_BASE.get(g, g))
    for g, t in GROUP_BASE.items():
        seen.setdefault(g, t)
    order = ["P"] + sorted(g for g in seen if g not in ("P", "O")) + ["O"]
    return [(g, seen[g]) for g in order]


def legend(decisions):
    items = []
    for g, t in groups(decisions):
        if g == "R":
            continue
        items.append(f"<b>{esc(g)}*</b> — {'процесс' if g == 'P' else esc(lower1(t))}")
    items.append("<b>R*</b> — риски")
    return ", ".join(items)


def bad_codes(data):
    """Код решения не по правилу ^[A-Z]\\d+$ или на букву R — печатается, но с ⚠."""
    out = []
    for d in data.get("decisions", []):
        code = str(d.get("code") or "")
        if not CODE_RE.match(code) or code.startswith("R"):
            out.append(code or "?")
    return out


VALID_BLOCKS = set(TIER)


def normalize_blocks(data):
    """Находка с незнакомым или пустым блоком не должна исчезать со страницы.
    Кладём такие в средний ярус и возвращаем список — вызывающий скажет о них вслух."""
    fixed = []
    for f in data.get("findings", []):
        if f.get("block") not in VALID_BLOCKS:
            fixed.append((f.get("id", "?"), f.get("block")))
            f["block"] = "imp"
    return fixed


def counts(data):
    ds = [d for d in data.get("decisions", []) if d.get("status") != "dropped"]
    fs = data.get("findings", [])
    active = [f for f in fs if f.get("status") != "deferred"]
    st = lambda d: d.get("status") or "open"
    return {
        "decisions": len(ds),
        "waiting": sum(1 for d in ds if st(d) in UNANSWERED),
        "fire": sum(1 for d in ds if is_fire(d)),
        "risks": len(active),
        "crit": sum(1 for f in active if f.get("block") == "crit" and f.get("status") != "done"),
        "done": sum(1 for f in fs if f.get("status") == "done"),
        "deferred": [f for f in fs if f.get("status") == "deferred" and not moved_out(f)],
        # для session-start: P1 и дефолты без 🔥 не нагоняют
        "open_decisions": sum(1 for d in ds if st(d) in ("open", "discuss"))
                          + sum(1 for d in ds if st(d) == "default" and d.get("fire"))
                          + sum(1 for f in fs if f.get("status") == "open" and f.get("owner") in ("decision", "both") and not moved_out(f)),
    }


# ---------- HTML ----------

def h2(no, title):
    return f'<h2><span class="no">{no}</span>{title}</h2>'


def img_tag(shot, alt, base, caption=None):
    """<figure class="shot"> с data: URI, если файл на месте; нет файла — пустая строка, без ошибки."""
    if not shot:
        return ""
    p = Path(shot)
    for cand in ([p] if p.is_absolute() else [Path.cwd() / p, base / p]):
        if cand.is_file() and cand.suffix.lower() in MIME:
            b64 = base64.b64encode(cand.read_bytes()).decode("ascii")
            cap = f"<figcaption>{esc(caption)}</figcaption>" if caption is not None else ""
            return f'<figure class="shot"><img src="data:{MIME[cand.suffix.lower()]};base64,{b64}" alt="{attr(alt)}">{cap}</figure>'
    return ""


def render_howto(decisions, extra):
    return ('<div class="howto"><b>Как работать с документом.</b> Каждое решение и риск имеет код: ' + legend(decisions) + ". "
            "Метка 🔥 — нужно на этой неделе, без этого стоим. "
            "Метка «дефолт» — наша рекомендация: нет возражений — действуем (см. P1). "
            "Отвечайте списком кодов — так / не так / как переделать:"
            '<div class="ex">A2 — ок.&nbsp;&nbsp;B2 — переделать: …и как именно.&nbsp;&nbsp;D2 — обсудить.</div>'
            f"{esc(extra or HOWTO_DEFAULT)}</div>")


def render_decision(d):
    st = d.get("status") or "open"
    head = [f'<span class="code{" o" if group_of(d) == "O" else ""}">{esc(d.get("code"))}</span>']
    if is_fire(d):
        head.append('<span class="fire">🔥 эта неделя</span>')
    head.append(f'<span class="dt">{esc(d.get("title"))}</span>')
    chip = CHIP.get(st)
    if chip:
        head.append(f'<span class="{chip[0]}">{chip[1]}</span>')
    out = [f'<div class="dcs"><div class="dh">{"".join(head)}</div>']
    if d.get("what"):
        out.append(f'<div class="what">{esc(d["what"])}</div>')
    if d.get("was"):
        out.append(f'<span class="was">было: {esc(d["was"])}</span>')
    if d.get("why"):
        out.append(f'<div class="why"><b>Почему:</b> {esc(d["why"])}</div>')
    v = d.get("verdict") or {}
    if v.get("text"):
        out.append(f'<span class="vd">Ваш ответ {esc(v.get("date"))}: {esc(v["text"])}</span>')
    out.append("</div>")
    return "\n".join(out)


def render_risk(f, base):
    done = f.get("status") == "done"
    tier = TIER.get(f.get("block"), "mid")
    links = ", ".join(str(x) for x in (f.get("links") or []))
    title = esc(f.get("title")) + (f" (→ {esc(links)})" if links else "")
    out = [f'<div class="risk {tier}{" done" if done else ""}"><div class="rt"><span class="rc">{risk_code(f)}</span>{title}</div>']
    if not done:
        if f.get("why"):
            out.append(f"<p>{esc(f['why'])}</p>")
        if f.get("what"):
            out.append(f"<p><b>Предлагаем:</b> {esc(f['what'])}</p>")
        out.append(img_tag(f.get("screenshot"), f.get("title"), base))
    if f.get("task_slug"):
        out.append(f'<p><span class="slug" title="{attr(f["task_slug"])}">→ {"уже работает" if done else "в работе"}</span></p>')
    out.append("</div>")
    return "\n".join(p for p in out if p)


def render_scheme(boxes):
    parts = []
    for i, b in enumerate(boxes):
        if i:
            parts.append(f'<div class="sarr">→<small>{esc(b.get("arrow", ""))}</small></div>')
        parts.append(f'<div class="sbox"><div class="st">{esc(b.get("title"))}</div><div class="sd">{esc(b.get("text"))}</div></div>')
    return '<div class="scheme">\n' + "\n".join(parts) + "\n</div>" if parts else ""


def render_screens(screens, base):
    """Группы по group; 1 снимок → shotwide, 2 → shots2, 3 → shots3, 4+ → shots. Нет файлов — группы нет."""
    by = {}
    for s in screens:
        tag = img_tag(s.get("file"), s.get("caption"), base, caption=s.get("caption", ""))
        if tag:
            by.setdefault(s.get("group") or "Экраны", []).append(tag)
    out = []
    for g, tags in by.items():
        cls = {1: "shotwide", 2: "shots2", 3: "shots3"}.get(len(tags), "shots")
        out.append(f'<h3>{esc(g)}</h3>\n<div class="{cls}">\n' + "\n".join(tags) + "\n</div>")
    return "\n".join(out)


def render_tgmock(m):
    bub = []
    for b in m.get("bubbles", []) or []:
        who = {"bot": "bot", "me": "me", "sys": "sysnote"}.get(b.get("who"), "bot")
        btn = "".join(f'<span class="tgbtn">{esc(x)}</span>' for x in (b.get("buttons") or []))
        bub.append(f'<div class="tgb {who}">{esc(b.get("text"))}' + (f'<div class="tgbtns">{btn}</div>' if btn else "") + "</div>")
    return (f'<h3>{esc(m.get("title"))}</h3>\n<div class="tgmock">\n' + "\n".join(bub) + "\n</div>\n"
            '<p class="gt">Воспроизведение сообщений бота, данные вымышленные.</p>')


def render_plan(plan):
    cols = [("now", "Сейчас · эта неделя"), ("next", "Дальше · 2–4 недели"), ("later", "Позже")]
    out = ['<div class="rmap">']
    for key, title in cols:
        lis = "".join(f"<li>{esc(i)}</li>" for i in (plan.get(key) or [])) or '<li class="empty">пока пусто</li>'
        out.append(f'<div class="rcol {key}"><div class="rh">{title}</div><ul>{lis}</ul></div>')
    out.append("</div>")
    return "\n".join(out)


def render_html(data, base):
    meta = data.get("meta") or {}
    ver = ver_of(data)
    proj = esc(meta.get("project") or "Проект")
    ds = [d for d in data.get("decisions", []) if d.get("status") != "dropped"]
    fs = data.get("findings", [])
    snap = data.get("snapshot") or {}
    about = data.get("about") or {}
    c = counts(data)

    bd = " · ".join(x for x in (esc(meta.get("audience")), esc(meta.get("date")),
                                 f"версия проекта {esc(meta['project_version'])}" if meta.get("project_version") else "") if x)
    out = ['<!DOCTYPE html>', '<html lang="ru">', '<head>', '<meta charset="utf-8">',
           '<meta name="viewport" content="width=device-width,initial-scale=1">',
           f"<title>{attr(meta.get('project') or 'Проект')} · Гайд по проекту v{attr(ver)}</title>",
           '<link rel="preconnect" href="https://fonts.googleapis.com">',
           '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600;700&family=Golos+Text:wght@400;500;600&display=swap">',
           f"<style>{CSS}</style>", "</head>", "<body>",
           f'<div class="brandline"><div class="logo">{esc(str(meta.get("project") or "П")[:1].upper())}</div>'
           f'<div><div class="bn">{proj}</div><div class="bd">{bd}</div></div></div>',
           f"<h1>Гайд по проекту v{esc(ver)}</h1>"]
    if meta.get("eyebrow"):
        out.append(f'<p class="sub">{esc(meta["eyebrow"])}</p>')

    # 00 — за 30 секунд: факты, 🔥, как работать с документом, что изменилось
    out.append(h2(*SECTIONS[0]))
    facts = snap.get("facts") or []
    if facts:
        out.append('<div class="facts">\n' + "\n".join(
            f'<div class="fact"><b>{esc(f.get("lead"))}</b> — {esc(f.get("text"))}</div>' for f in facts) + "\n</div>")
    fire = [d for d in ds if is_fire(d)]
    if fire:
        out.append('<div class="week"><div class="wt">🔥 Решения, без которых стоим — нужны на этой неделе</div>\n<ul>\n'
                   + "\n".join(f'<li><b>{esc(d.get("code"))}</b> — {esc(d.get("title"))}</li>' for d in fire) + "\n</ul></div>")
    out.append(render_howto(ds, snap.get("howto_extra")))
    log = data.get("changelog") or []
    if log and (log[0].get("items") or []):
        prev = meta.get("previous") or (log[1].get("version") if len(log) > 1 else "")
        out.append(f'<div class="changes"><div class="ct">Что изменилось{f" с v{esc(prev)}" if prev else ""}</div>\n<ul class="clean">\n'
                   + "\n".join(f"<li>{esc(i)}</li>" for i in log[0]["items"]) + "\n</ul></div>")

    # 01 — что это такое
    out.append(h2(*SECTIONS[1]))
    body = []
    if about.get("text"):
        body.append(f"<p>{esc(about['text'])}</p>")
    body.append(render_scheme(about.get("scheme") or []))
    if about.get("after"):
        body.append(f'<p style="font-size:9.5pt;color:var(--text2)">{esc(about["after"])}</p>')
    body.append(render_screens(about.get("screens") or [], base))
    body.extend(render_tgmock(m) for m in (data.get("tg_mocks") or []))
    body = [b for b in body if b]
    out.extend(body or [EMPTY])

    # 02 — из чего состоит
    out.append(h2(*SECTIONS[2]))
    parts = data.get("parts") or []
    if parts:
        cards = []
        for p in parts:
            codes = ", ".join(str(x) for x in (p.get("codes") or []))
            cd = f' <span class="cd">→ {esc(codes)}</span>' if codes else ""
            cards.append(f'<div class="card svc"><div class="t">{esc(p.get("icon"))} {esc(p.get("title"))}{cd}</div>'
                         f'<div class="d">{esc(p.get("text"))}</div></div>')
        out.append('<div class="grid2">\n' + "\n".join(cards) + "\n</div>")
    else:
        out.append(EMPTY)

    # 03 — главный путь
    out.append(h2(*SECTIONS[3]))
    flow = data.get("flow") or []
    out.append('<div class="flow">\n' + "\n".join(
        f'<div class="fstep"><b>{esc(s.get("title"))}.</b> {esc(s.get("text"))}</div>' for s in flow) + "\n</div>" if flow else EMPTY)

    # 04 — роли
    out.append(h2(*SECTIONS[4]))
    roles = data.get("roles") or []
    out.append("<table>\n<tr><th>Роль</th><th>Что видит и делает</th></tr>\n" + "\n".join(
        f'<tr><td><b>{esc(r.get("role"))}</b></td><td>{esc(r.get("does"))}</td></tr>' for r in roles) + "\n</table>" if roles else EMPTY)

    # 05 — решения по группам
    out.append(h2(*SECTIONS[5]))
    out.append('<p class="gt">Каждое — как заложено сейчас и почему. Ждём по каждому: ок / переделать / обсудить.</p>')
    for g, title in groups(ds):
        out.append(f"<h3>{esc(g)} — {esc(title)}</h3>")
        items = [d for d in ds if group_of(d) == g]
        out.extend(render_decision(d) for d in items) if items else out.append('<p class="empty">пока нет</p>')

    # 06 — карта рисков
    out.append(h2(*SECTIONS[6]))
    out.append('<p class="gt">Отсортировано по срочности. Меры — наши предложения, отвечайте по кодам R.</p>')
    active = [f for f in fs if f.get("status") != "deferred"]
    any_tier = False
    for tier, head in TIER_HEAD:
        cards = [f for f in active if TIER.get(f.get("block"), "mid") == tier]
        if not cards:
            continue
        any_tier = True
        cards.sort(key=lambda f: f.get("status") == "done")  # сделанное — в конец яруса
        out.append(f"<h3>{head}</h3>")
        out.extend(render_risk(f, base) for f in cards)
    if not any_tier:
        out.append(EMPTY)
    if c["deferred"]:
        ex = "; ".join(esc(f.get("title")) for f in c["deferred"])
        out.append(f'<p class="gt">Отложено — {len(c["deferred"])}: {ex}.</p>')

    # 07 — план
    out.append(h2(*SECTIONS[7]))
    out.append(render_plan(data.get("plan") or {}))

    # 08 — словарик
    out.append(h2(*SECTIONS[8]))
    gl = data.get("glossary") or []
    out.append('<dl class="gl">\n' + "\n".join(
        f"<dt>{esc(g.get('term'))}</dt><dd>{esc(g.get('text'))}</dd>" for g in gl) + "\n</dl>" if gl else EMPTY)

    foot = [f"{proj} · гайд v{esc(ver)} от {esc(meta.get('date'))}",
            f"Собрано из: {esc(meta.get('built_from') or 'код проекта и память .forge')}"]
    pend = len(data.get("pending_changes") or [])
    stale = int(data.get("stale_tasks", 0) or 0)
    if pend or stale:
        s = f"обновлён {esc(data.get('updated_at'))}: {plural(pend, 'изменение', 'изменения', 'изменений')} после сборки"
        if stale:
            s += f" · гайд устарел на {plural(stale, 'задачу', 'задачи', 'задач')}"
        foot.append(s)
    out.append("<footer>" + " · ".join(foot) + "</footer>")
    out.append("</body>\n</html>")
    return "\n".join(out)


def ensure_gitignore(forge_dir):
    """Снимки регенерируются — в git им не место. Рождаются они здесь, значит и игнор — здесь
    (finishing делает git add -A раньше backup.sh — ждать его нельзя)."""
    gi = forge_dir / ".gitignore"
    if not gi.is_file():
        gi.write_text("".join(l + "\n" for l in FORGE_IGNORE), encoding="utf-8")
        return
    text = gi.read_text(encoding="utf-8")
    missing = [l for l in GUIDE_LINES if l not in text.splitlines()]
    if missing:
        with gi.open("a", encoding="utf-8") as fh:
            fh.write(("" if text.endswith("\n") else "\n") + "".join(l + "\n" for l in missing))


def do_render(jp, out_html=None):
    jp = Path(jp)
    data = load(jp)
    fixed = normalize_blocks(data)
    rp = jp.resolve()
    in_guide = len(rp.parents) > 2 and rp.parent.name == "guide" and rp.parents[1].name == ".forge"
    base = rp.parents[2] if in_guide else rp.parent  # .forge/guide/vX.Y.json → корень проекта; макет — папка json
    text = render_html(data, base)
    ver = ver_of(data)
    if out_html:  # макет: только этот файл
        out_html = Path(out_html)
        out_html.parent.mkdir(parents=True, exist_ok=True)
        out_html.write_text(text, encoding="utf-8")
        print(f"FORGE-GUIDE: v{ver} → {out_html}")
    else:
        DOCS_DIR.mkdir(parents=True, exist_ok=True)
        hp = DOCS_DIR / f"guide-v{ver}.html"
        hp.write_text(text, encoding="utf-8")
        shutil.copyfile(hp, DOCS_DIR / "guide-latest.html")
        if in_guide:
            ensure_gitignore(base / ".forge")
        print(f"FORGE-GUIDE: v{ver} → {hp} (+ guide-latest.html)")
    for fid, bad in fixed:
        print(f"FORGE-GUIDE: ⚠ у находки {fid} блок «{bad}» неизвестен — показана в средних; поправь block в JSON")
    for code in bad_codes(data):
        print(f"FORGE-GUIDE: ⚠ код «{code}» не по правилу (латинская заглавная буква + число, не R) — решение показано как есть")
    c = counts(data)
    shots = text.count('<figure class="shot"')
    print(f"FORGE-GUIDE: решений {c['decisions']} (ждут ответа {c['waiting']}, 🔥 {c['fire']}), "
          f"рисков {c['risks']} (крит {c['crit']}), сделано {c['done']}, отложено {len(c['deferred'])}, снимков — {shots}")


def rerender(jp, data):
    """После правки JSON: обе HTML, а PDF этой версии — только если он уже есть. Несобранную версию не публикуем."""
    if not data.get("built_at"):
        print(f"FORGE-GUIDE: HTML не перерисован (v{ver_of(data)} ещё не собрана) — ответ учтён в JSON")
        return
    do_render(jp)
    pdf = DOCS_DIR / f"guide-v{ver_of(data)}.pdf"
    if pdf.is_file():
        do_pdf(pdf.with_suffix(".html"), pdf)


# ---------- PDF ----------

def find_chrome():
    env = os.environ.get("FORGE_CHROME")
    if env:  # явный путь — только он (тесты подсовывают /nonexistent)
        return env if Path(env).is_file() else None
    for c in CHROME_CANDIDATES:
        if Path(c).is_file():
            return c
        w = shutil.which(c)
        if w:
            return w
    return None


def do_pdf(html_path, pdf_path):
    """Chrome 152 после печати не завершается сам — Popen, ждём файл со стабильным размером, гасим."""
    html_path, pdf_path = Path(html_path), Path(pdf_path)
    if not html_path.is_file():
        print(f"FORGE-GUIDE: нет {html_path} — сначала render")
        return
    chrome = find_chrome()
    if not chrome:
        print("FORGE-GUIDE: Chrome не найден — PDF пропущен, есть HTML (поставь Google Chrome или укажи FORGE_CHROME=/путь)")
        return
    pdf_path.unlink(missing_ok=True)
    profile = tempfile.mkdtemp(prefix="forge-guide-chrome-")
    cmd = [chrome, "--headless", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
           "--disable-component-update", "--disable-background-networking", "--no-pdf-header-footer",
           f"--user-data-dir={profile}", "--virtual-time-budget=5000",  # шрифтам Google Fonts дать подгрузиться
           f"--print-to-pdf={pdf_path.resolve()}", html_path.resolve().as_uri()]
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as e:
        shutil.rmtree(profile, ignore_errors=True)
        print(f"FORGE-GUIDE: Chrome не запустился ({e}) — PDF пропущен, есть HTML")
        return
    deadline, last, stable = time.time() + 60, -1, 0
    while time.time() < deadline and stable < 4:  # файл появился и секунду не растёт → готов
        if p.poll() is not None:
            break
        size = pdf_path.stat().st_size if pdf_path.is_file() else 0
        stable = stable + 1 if size and size == last else 0
        last = size
        time.sleep(0.25)
    if p.poll() is None:
        p.terminate()
        try:
            p.wait(5)
        except subprocess.TimeoutExpired:
            p.kill()
    shutil.rmtree(profile, ignore_errors=True)
    ok = pdf_path.is_file() and pdf_path.read_bytes()[:4] == b"%PDF"
    print(f"FORGE-GUIDE: PDF собран → {pdf_path}" if ok else "FORGE-GUIDE: Chrome не отдал PDF за 60 с — пропущен, есть HTML")


# ---------- bump: новая версия / первая версия с миграцией старого отчёта ----------

def do_first(today):
    """Нет версий → v1.0 с P1. Старый отчёт «Что дальше» переезжает (находки + снимки), битый — откладывается в .broken."""
    old, broken = None, None
    if LEGACY_JSON.is_file():
        try:
            old = load(LEGACY_JSON)
        except GuideBroken:
            broken = Path(str(LEGACY_JSON) + ".broken")
            os.replace(LEGACY_JSON, broken)
    data = skeleton(today, project=(old or {}).get("project", ""))
    moved = 0
    if old is not None:
        data["findings"] = old.get("findings", []) or []
        data["sources"] = old.get("sources") or data["sources"]
        data["meta"]["eyebrow"] = old.get("eyebrow", "")
        for f in data["findings"]:  # снимки переезжают вместе с находками
            if str(f.get("screenshot", "")).startswith(".forge/reports/shots/"):
                f["screenshot"] = f["screenshot"].replace(".forge/reports/shots/", ".forge/guide/shots/", 1)
        moved = len(data["findings"])
    GUIDE_DIR.mkdir(parents=True, exist_ok=True)
    dst = GUIDE_DIR / "v1.0.json"
    save(dst, data)
    if old is not None:
        LEGACY_JSON.unlink(missing_ok=True)
        Path(".forge/status-report.html").unlink(missing_ok=True)
        shots = Path(".forge/reports/shots")
        if shots.is_dir():
            (GUIDE_DIR / "shots").mkdir(parents=True, exist_ok=True)
            for p in shots.iterdir():
                p.replace(GUIDE_DIR / "shots" / p.name)
            try:
                shots.rmdir()
            except OSError:
                pass
        ensure_gitignore(Path(".forge"))  # снимки уже здесь — игнор тоже, не ждать первого render
        print(f"FORGE-GUIDE: создан {dst} — перенёс {plural(moved, 'находку', 'находки', 'находок')} из старого отчёта, старый отчёт убран")
    elif broken:
        print(f"FORGE-GUIDE: создан {dst} (пустой каркас, P1 заведён); старый отчёт повреждён — отложен в {broken}")
    else:
        print(f"FORGE-GUIDE: создан {dst} (пустой каркас, P1 заведён)")


def do_bump(major, today):
    vs = versions()
    if not vs:
        do_first(today)
        return
    ma, mi, src = vs[-1]
    data = load(src)
    prev = f"{ma}.{mi}"
    if not data.get("built_at"):
        print(f"FORGE-GUIDE: v{prev} ещё не собрана — дособери (Edit → render), новую версию не завожу")
        return
    ma, mi = (ma + 1, 0) if major else (ma, mi + 1)
    ver = f"{ma}.{mi}"
    items = data.pop("pending_changes", []) or []
    data.setdefault("changelog", []).insert(0, {"version": ver, "date": today, "items": items})
    data.setdefault("meta", {}).update({"version": ver, "date": today, "previous": prev})
    ix = read_index()
    if ix.get("project_version"):
        data["meta"]["project_version"] = ix["project_version"]
    data["pending_changes"] = []
    data["updated_at"], data["stale_tasks"], data["built_at"] = today, 0, None
    dst = GUIDE_DIR / f"v{ver}.json"
    save(dst, data)
    print(f"FORGE-GUIDE: версия {ver} → {dst} (прошлая v{prev} не тронута; в changelog {plural(len(items), 'запись', 'записи', 'записей')})")


# ---------- verdict: ответ владельца по одному коду ----------

def normalize_code(raw, known):
    up = str(raw).strip().upper()
    by_sound = up.translate(SOUND)
    if by_sound in known:
        return by_sound
    by_glyph = up.translate(GLYPH)
    return by_glyph if by_glyph in known else by_sound


def do_verdict(jp, raw_code, status, text, today):
    data = load(jp)
    by_dec = {str(d.get("code")): d for d in data.get("decisions", [])}
    by_risk = {risk_code(f): f for f in data.get("findings", [])}
    code = normalize_code(raw_code, set(by_dec) | set(by_risk))
    status = status.strip().lower()
    if code in by_dec:
        d = by_dec[code]
        if status not in DEC_STATUSES:
            print(f"FORGE-GUIDE: ⚠ статус «{status}» для решения {code} не знаю — допустимы: accepted, changed, discuss, works, dropped")
            return
        if status == "changed" and not text:
            print(f"FORGE-GUIDE: ⚠ переделать — а как? {code} не тронут: добавь текст (verdict {code} changed \"новая формулировка\")")
            return
        if text and status in ("accepted", "changed"):
            d["was"], d["what"] = d.get("what", ""), text
        d["status"] = status
        if status != "discuss":
            d["fire"] = False  # 🔥 остаётся только у неотвеченных
        d["verdict"] = {"date": today, "text": text or LABEL[status]}
    elif code in by_risk:
        f = by_risk[code]
        if status not in RISK_STATUSES:
            print(f"FORGE-GUIDE: ⚠ статус «{status}» для риска {code} не знаю — допустимы: agreed, done, up, down, deferred, changed")
            return
        if status == "changed" and not text:
            print(f"FORGE-GUIDE: ⚠ переделать — а как? {code} не тронут: добавь текст (verdict {code} changed \"новое предложение\")")
            return
        if status == "agreed":
            f["agreed_at"] = today
        elif status == "done":
            f["status"], f["done_at"] = "done", today
        elif status == "up":
            f["block"] = "crit"
        elif status == "down":
            f["block"] = "pol"
        elif status == "deferred":
            f["status"] = "deferred"
        else:
            f["was"], f["what"] = f.get("what", ""), text
    else:
        print(f"FORGE-GUIDE: ⚠ код {code} не найден в гайде")
        return
    label = LABEL[status]
    data.setdefault("pending_changes", []).append(f"{today}: {code} — {label}" + (f" ({text})" if text else ""))
    data["updated_at"] = today
    save(jp, data)
    print(f"FORGE-GUIDE: {code} → {label}" + (f": {text}" if text else ""))
    rerender(jp, data)


# ---------- CLI ----------

def cd_repo_root():
    """Пути по умолчанию — от корня проекта; вызов из поддиректории (finishing, хуки) не должен молча промахиваться."""
    if Path(".forge").is_dir():  # проект без своего .git внутри чужого репо — не уходить в его корень
        return
    try:
        top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    except OSError:
        top = ""
    if top:
        os.chdir(top)


def run(argv):
    mode = argv[1] if len(argv) > 1 else "render"
    if mode in ("render", "pdf") and len(argv) > 2:  # явные пути — от cwd вызывающего, до смены каталога
        argv = argv[:2] + [str(Path(a).absolute()) for a in argv[2:]]
    cd_repo_root()
    today = date.today().isoformat()
    if mode == "render":
        jp = latest_json()
        if len(argv) > 2:  # явный JSON: с out.html — макет, JSON не трогаем; без — только последняя версия
            ep = Path(argv[2])
            if not ep.is_file():
                print(f"FORGE-GUIDE: нет {ep}")
                return 0
            if len(argv) > 3:
                do_render(ep, Path(argv[3]))
                return 0
            if not jp or ep.resolve() != jp.resolve():
                print("FORGE-GUIDE: макет — render <json> <out.html>; сборка последней версии — render без аргументов")
                return 0
        if not jp:
            print(NO_GUIDE)
            return 0
        do_render(jp)
        data = load(jp)
        data["built_at"] = today  # версия собрана — после записи HTML
        save(jp, data)
    elif mode == "bump":
        do_bump(len(argv) > 2 and argv[2] == "major", today)
    elif mode == "pdf":
        if len(argv) > 2:
            hp = Path(argv[2])
            pp = Path(argv[3]) if len(argv) > 3 else hp.with_suffix(".pdf")
        else:
            jp = latest_json()
            if not jp:
                print(NO_GUIDE)
                return 0
            hp = DOCS_DIR / f"guide-v{ver_of(load(jp))}.html"
            pp = hp.with_suffix(".pdf")
        do_pdf(hp, pp)
    elif mode == "verdict":
        if len(argv) < 4:
            print("usage: render.py verdict <код> <статус> [текст]", file=sys.stderr)
            return 2
        jp = latest_json()
        if not jp:
            print(NO_GUIDE)
            return 0
        do_verdict(jp, argv[2], argv[3], " ".join(argv[4:]).strip(), today)
    elif mode == "merged":
        if len(argv) < 3:
            print("usage: render.py merged <task-slug>", file=sys.stderr)
            return 2
        slug = argv[2]
        jp = latest_json()
        if not jp:
            return 0  # гайда нет — нечего обновлять, молча
        data = load(jp)
        hit = []
        for f in data.get("findings", []):
            if f.get("task_slug") == slug and f.get("status") != "done":
                f["status"], f["done_at"] = "done", today
                title = f.get("title") or f.get("id")
                hit.append(title)
                data.setdefault("pending_changes", []).append(f"{today}: {risk_code(f)} — сделано: {title} (задача {slug})")
        data["stale_tasks"] = int(data.get("stale_tasks", 0) or 0) + 1
        data["updated_at"] = today
        save(jp, data)
        stale = plural(data["stale_tasks"], "задачу", "задачи", "задач")
        if hit:
            print(f"FORGE-GUIDE: сделано → {'; '.join(hit)}; гайд устарел на {stale}")
        else:
            print(f"FORGE-GUIDE: карточки с задачей «{slug}» нет; гайд устарел на {stale}")
        rerender(jp, data)
    elif mode == "link":
        if len(argv) < 4:
            print("usage: render.py link <finding-id|R-код> <task-slug>", file=sys.stderr)
            return 2
        fid, slug = argv[2], argv[3]
        jp = latest_json()
        if not jp:
            return 0
        data = load(jp)
        hit = [f for f in data.get("findings", []) if f.get("id") == fid or risk_code(f) == fid.upper()]
        if not hit:
            print(f"FORGE-GUIDE: карточки {fid} нет")
            return 0
        for f in hit:
            f["task_slug"] = slug
            print(f"FORGE-GUIDE: карточка {f.get('id')} → задача {slug}")
        data["updated_at"] = today
        save(jp, data)
        rerender(jp, data)
    elif mode == "summary":
        jp = latest_json()
        if not jp:
            return 0
        try:
            data = load(jp)
        except Exception:
            return 0
        ver = ver_of(data)
        if not data.get("built_at"):
            print(f"📖 Гайд по проекту: v{ver} ещё не собрана — скажи «собери гайд»")
            return 0
        c = counts(data)
        stale = int(data.get("stale_tasks", 0) or 0)
        bits = []
        if c["open_decisions"]:
            bits.append(f"ждут {plural(c['open_decisions'], 'решение', 'решения', 'решений')} владельца")
        if stale:
            bits.append(f"гайд устарел на {plural(stale, 'задачу', 'задачи', 'задач')}")
        if bits:
            print(f"📖 Гайд по проекту v{ver}: " + ", ".join(bits)
                  + " (docs/guide/guide-latest.html; ответы — кодами в чат, пересобрать — «собери гайд»)")
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


def main(argv):
    try:
        return run(argv)
    except GuideBroken as e:
        print(e)
        return 0
    except Exception as e:  # контракт: гайд не роняет основной процесс — merged зовут посреди мержа
        print(f"FORGE-GUIDE: ⚠ гайд не обновлён — ошибка рендерера: {e!r}")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
