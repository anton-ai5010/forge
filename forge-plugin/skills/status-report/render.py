#!/usr/bin/env python3
"""Рендерер отчёта «Что дальше» (Фаза 5). Только стандартная библиотека.

Данные — .forge/status-report.json (память проекта), выход — .forge/status-report.html
(один живой файл, перезаписывается). Клод пишет только JSON; HTML собирает этот скрипт
по forge-plugin/docs/status-report-format.md.

Режимы:
  render  [json] [html]          собрать HTML (по умолчанию .forge/status-report.json → .forge/status-report.html)
  merged  <task-slug> [json]     после мержа: карточка с task_slug → done, stale_tasks+1, пересобрать HTML
  link    <finding-id> <slug> [json]   привязать карточку к задаче (new-task, шаг 9)
  summary [json]                 одна строка для session-start; пусто — если напоминать нечего
Всегда exit 0 (кроме неверных аргументов) — отчёт не должен ронять основной процесс.
"""

import base64
import html
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

DEFAULT_JSON = Path(".forge/status-report.json")
DEFAULT_HTML = Path(".forge/status-report.html")

BLOCK_ORDER = ["crit", "biz", "imp"]  # pol — в футер
BLOCKS = {
    "crit": ("Кровь из носа — чиню в коде",
             "Без этого сервис не выполняет свою главную функцию. Моя работа; где стоит чип «Решение+код» — сначала нужно твоё слово."),
    "biz": ("Решения — нужны от тебя",
            "Деньги, люди, правила. Я не двигаю это сам — жду ответа, потом делаю."),
    "imp": ("Скоро — усиливает продукт",
            "Не горит, но заметно улучшает. Делаю после Блока 1."),
}
CHIP = {"code": ("code", "Код"), "decision": ("biz", "Решение"), "both": ("both", "Решение+код")}
MIME = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}
# Служебный мусор .forge — построчно равен heredoc в skills/memory-backup/backup.sh
FORGE_IGNORE = [".inject-state", ".last-backup", ".migration-declined", "state.yml",
                ".github-*", "graph.json", "status-report.html", "reports/shots/"]

CSS = """
:root{--bg:#F4F5F8;--panel:#fff;--panel-2:#F9FAFC;--ink:#171B24;--ink-2:#4A5163;--ink-3:#8A91A3;--line:#E2E5EC;--accent:#3D5AFE;--shadow:0 1px 2px rgba(23,27,36,.04),0 8px 24px rgba(23,27,36,.06);
--crit:#D93636;--crit-bg:#FDECEC;--biz:#7A3EF0;--biz-bg:#F0EAFE;--imp:#D98A00;--imp-bg:#FFF4DE;--pol:#1E9E5A;--pol-bg:#E6F7EE}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#0E1017;--panel:#171A22;--panel-2:#1D212B;--ink:#EDEFF5;--ink-2:#B4BAC9;--ink-3:#7C8397;--line:#2A2F3B;--accent:#7C93FF;--shadow:0 1px 2px rgba(0,0,0,.4),0 8px 24px rgba(0,0,0,.35);
--crit:#FF6B6B;--crit-bg:#3A1C1C;--biz:#B48CFF;--biz-bg:#2A1F45;--imp:#FFC14D;--imp-bg:#3B2E12;--pol:#5DD69A;--pol-bg:#173225}}
:root[data-theme="dark"]{--bg:#0E1017;--panel:#171A22;--panel-2:#1D212B;--ink:#EDEFF5;--ink-2:#B4BAC9;--ink-3:#7C8397;--line:#2A2F3B;--accent:#7C93FF;--shadow:0 1px 2px rgba(0,0,0,.4),0 8px 24px rgba(0,0,0,.35);
--crit:#FF6B6B;--crit-bg:#3A1C1C;--biz:#B48CFF;--biz-bg:#2A1F45;--imp:#FFC14D;--imp-bg:#3B2E12;--pol:#5DD69A;--pol-bg:#173225}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-family:"IBM Plex Sans",system-ui,-apple-system,Segoe UI,sans-serif;font-size:16px;line-height:1.55}
.mono{font-family:"IBM Plex Mono",ui-monospace,SFMono-Regular,Menlo,monospace}
.wrap{max-width:1080px;margin:0 auto;padding:40px 24px 64px}
.head .eyebrow{font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-3)}
.head h1{font-family:Archivo,system-ui,sans-serif;font-weight:800;font-size:clamp(28px,5vw,44px);letter-spacing:-.02em;line-height:1.1;margin:10px 0 14px}
.head p{max-width:66ch;color:var(--ink-2);margin:0 0 16px}
.meta{display:flex;flex-wrap:wrap;gap:8px 18px;font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:13px;color:var(--ink-3)}
.verdict{margin:28px 0 36px;padding:20px 24px;background:var(--panel);border:1px solid var(--line);border-left:5px solid var(--crit);border-radius:14px;box-shadow:var(--shadow)}
.verdict h2{font-family:Archivo,system-ui,sans-serif;font-weight:700;font-size:15px;letter-spacing:.02em;text-transform:uppercase;color:var(--crit);margin:0 0 8px}
.verdict p{margin:0;font-size:17px}
.phase{margin:0 0 40px}
.phase-head{display:flex;align-items:center;gap:12px;margin:0 0 6px}
.phase-head h2{font-family:Archivo,system-ui,sans-serif;font-weight:700;font-size:24px;letter-spacing:-.01em;margin:0}
.tag{font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:12px;font-weight:600;padding:4px 10px;border-radius:999px;white-space:nowrap}
.tag.crit{color:var(--crit);background:var(--crit-bg)}.tag.biz{color:var(--biz);background:var(--biz-bg)}.tag.imp{color:var(--imp);background:var(--imp-bg)}.tag.pol{color:var(--pol);background:var(--pol-bg)}
.phase-sub{color:var(--ink-2);margin:0 0 18px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:18px 20px;box-shadow:var(--shadow)}
.card-top{display:flex;align-items:flex-start;gap:10px;margin:0 0 10px}
.card-top h3{font-family:Archivo,system-ui,sans-serif;font-weight:600;font-size:17px;line-height:1.3;margin:0;flex:1}
.chip{font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:11px;font-weight:600;padding:3px 8px;border-radius:6px;white-space:nowrap;margin-top:2px}
.chip.code{color:#fff;background:var(--crit)}.chip.biz{color:#fff;background:var(--biz)}.chip.both{color:var(--biz);background:var(--biz-bg);border:1px solid var(--biz)}.chip.done{color:#fff;background:var(--pol)}
.eff{font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:12px;font-weight:600;color:var(--ink-2);background:var(--panel-2);border:1px solid var(--line);border-radius:6px;padding:3px 8px;margin-top:2px}
.card p{margin:0 0 8px;font-size:15px}.card p:last-child{margin-bottom:0}
.card .why{color:var(--ink-2)}
.card .src{font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:11px;color:var(--ink-3);margin-top:10px}
.card .slug{font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:11px;color:var(--accent);margin-top:6px}
.card.done{opacity:.6}.card.done h3{text-decoration:line-through}
.shot{display:block;width:100%;height:auto;border:1px solid var(--line);border-radius:10px;margin:10px 0 4px}
.foot{font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:13px;line-height:1.6;color:var(--ink-3);border-top:1px solid var(--line);padding-top:20px}
.foot p{margin:0 0 8px;max-width:80ch}
"""


def esc(s):
    """Экранирование + минимальная разметка **жирный**. Опечатка в тексте вёрстку не ломает."""
    t = html.escape(str(s or ""), quote=True)
    return re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)


def plural(n, one, few, many):
    n = abs(int(n))
    if n % 10 == 1 and n % 100 != 11:
        return f"{n} {one}"
    if 2 <= n % 10 <= 4 and not 12 <= n % 100 <= 14:
        return f"{n} {few}"
    return f"{n} {many}"


class ReportBroken(Exception):
    """Битый JSON отчёта: сообщаем по-человечески и выходим с кодом 0 — merged зовут посреди мержа."""


def load(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError, OSError) as e:
        raise ReportBroken(f"FORGE-REPORT: файл отчёта повреждён ({path}: {e}) — скажи «собери отчёт», пересоберу") from e


def save(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def img_tag(shot, alt, base):
    """<img data:…> если файл на месте; нет файла — пустая строка (карточка без картинки)."""
    if not shot:
        return ""
    p = Path(shot)
    for cand in ([p] if p.is_absolute() else [Path.cwd() / p, base / p]):
        if cand.is_file() and cand.suffix.lower() in MIME:
            b64 = base64.b64encode(cand.read_bytes()).decode("ascii")
            return f'<img class="shot" src="data:{MIME[cand.suffix.lower()]};base64,{b64}" alt="{esc(alt)}">'
    return ""


def render_card(f, block, base):
    done = f.get("status") == "done"
    chip_cls, chip_txt = ("done", "Сделано") if done else CHIP.get(f.get("owner"), CHIP["code"])
    eff = "—" if f.get("owner") == "decision" or f.get("effort") in (None, "", "-") else f["effort"]
    parts = [f'<div class="card{" done" if done else ""}">',
             f'<div class="card-top"><span class="chip {chip_cls}">{chip_txt}</span>'
             f'<h3>{esc(f.get("title"))}</h3><span class="eff">{esc(eff)}</span></div>']
    if not done:
        what, why = f.get("what", ""), f.get("why", "")
        if block == "crit":
            parts.append(f"<p><b>Что:</b> {esc(what)}</p>")
            if why:
                parts.append(f'<p class="why"><b>Зачем:</b> {esc(why)}</p>')
        elif block == "biz":
            parts.append(f"<p><b>Что решить:</b> {esc(what)}</p>")
            if why:
                parts.append(f'<p class="why">{esc(why)}</p>')
        else:
            parts.append(f"<p>{esc(what)}</p>")
            if why:
                parts.append(f'<p class="why">{esc(why)}</p>')
        parts.append(img_tag(f.get("screenshot"), f.get("title"), base))
    if f.get("task_slug"):
        label = "влито" if done else "в работе"
        parts.append(f'<div class="slug">→ {label}: {esc(f["task_slug"])}</div>')
    if f.get("source"):
        parts.append(f'<div class="src">{esc(f["source"])}</div>')
    parts.append("</div>")
    return "\n".join(p for p in parts if p)


VALID_BLOCKS = set(BLOCK_ORDER) | {"pol"}


def normalize_blocks(data):
    """Находка с незнакомым или пустым блоком не должна исчезать со страницы (счётчик её всё равно считает).
    Кладём такие в «Скоро» и возвращаем список id — вызывающий скажет о них вслух."""
    fixed = []
    for f in data.get("findings", []):
        if f.get("block") not in VALID_BLOCKS:
            fixed.append((f.get("id", "?"), f.get("block")))
            f["block"] = "imp"
    return fixed


def counts(data):
    fs = data.get("findings", [])
    active = [f for f in fs if f.get("status") != "deferred"]
    present = [b for b in BLOCK_ORDER + ["pol"] if any(f.get("block") == b for f in active)]
    return {
        "total": len(fs),
        "blocks": len(present),
        "present": present,
        "deferred": [f for f in fs if f.get("status") == "deferred"],
        "done": sum(1 for f in fs if f.get("status") == "done"),
        "pol": [f for f in active if f.get("block") == "pol"],
        "open_decisions": sum(1 for f in fs if f.get("status") == "open" and f.get("owner") in ("decision", "both")),
        "open_code": sum(1 for f in fs if f.get("status") == "open" and f.get("owner") == "code"),
    }


def render_html(data, base):
    c = counts(data)
    proj = esc(data.get("project", "Проект"))
    src = data.get("sources", {}) or {}
    analysts = int(src.get("analysts", 0) or 0)
    found = int(src.get("found", c["total"]) or c["total"])
    stale = int(data.get("stale_tasks", 0) or 0)

    lead = (f"{plural(analysts, 'аналитик прошёл', 'аналитика прошли', 'аналитиков прошли')} по коду и памяти проекта "
            f"и {'нашёл' if analysts == 1 else 'нашли'} {plural(found, 'пробел', 'пробела', 'пробелов')}. "
            f"Свёл в приоритеты: <b>что чиню я в коде</b> и <b>что решаешь ты</b>. "
            f"Порядок — по тому, что мешает сервису работать, а не по тому, что заметнее.")
    meta = [f"<span>{esc(data.get('built_at', ''))}</span>",
            f'<span class="mono">{plural(c["total"], "находка", "находки", "находок")} → {plural(c["blocks"], "блок", "блока", "блоков")}'
            + (f', {plural(len(c["deferred"]), "отложена", "отложены", "отложено")}' if c["deferred"] else "") + "</span>"]
    if data.get("next_after"):
        meta.append(f'<span class="mono">{esc(data["next_after"])}</span>')
    if stale:
        meta.append(f'<span class="mono">обновлён {esc(data.get("updated_at", ""))} · устарел на {plural(stale, "задачу", "задачи", "задач")}</span>')

    out = [f"<!DOCTYPE html><html lang=\"ru\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
           f"<title>{proj} · Что дальше</title>",
           '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
           '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@500;600;700;800&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500;600&display=swap">',
           f"<style>{CSS}</style></head><body><div class=\"wrap\">",
           '<header class="head">',
           f'<div class="eyebrow">{esc(data.get("eyebrow", "Дорожная карта"))}</div>',
           f'<h1>{proj}: {esc(data.get("question", "что дальше"))}</h1>',
           f"<p>{lead}</p>",
           f'<div class="meta">{"".join(meta)}</div></header>']

    v = data.get("verdict") or {}
    if v.get("text"):
        out.append(f'<div class="verdict"><h2>Главное одной фразой</h2><p>{esc(v["text"])}</p></div>')

    n = 0
    for b in BLOCK_ORDER:
        cards = [f for f in data.get("findings", []) if f.get("block") == b and f.get("status") != "deferred"]
        if not cards:
            continue
        n += 1
        title, sub = BLOCKS[b]
        cards.sort(key=lambda f: f.get("status") == "done")  # сделанное — в конец блока
        out.append(f'<section class="phase"><div class="phase-head"><span class="tag {b}">Блок {n}</span><h2>{title}</h2></div>'
                   f'<p class="phase-sub">{sub}</p><div class="grid">')
        out.extend(render_card(f, b, base) for f in cards)
        out.append("</div></section>")

    foot = []
    if c["pol"]:
        ex = "; ".join(esc(f.get("title")) for f in c["pol"][:2])
        foot.append(f"<p>Блок {n + 1} «Потом» — {plural(len(c['pol']), 'находка', 'находки', 'находок')}, не срочно ({ex}).</p>")
    if c["deferred"]:
        ex = "; ".join(esc(f.get("title")) for f in c["deferred"][:2])
        foot.append(f"<p>Отложено — {plural(len(c['deferred']), 'находка', 'находки', 'находок')} ({ex}).</p>")
    if c["done"]:
        foot.append(f"<p>Сделано с момента сборки — {plural(c['done'], 'карточка', 'карточки', 'карточек')}.</p>")
    order = []
    names = {"crit": "Блок {} (без него сервис не работает)", "biz": "параллельно собрать ответы Блока {}", "imp": "затем Блок {}"}
    k = 0
    for b in BLOCK_ORDER:
        if b in c["present"]:
            k += 1
            order.append(("сначала <b>" if k == 1 else "<b>") + names[b].format(k) + "</b>")
    if order:
        foot.append("<p>Порядок: " + ", ".join(order) + (", потом косметика." if c["pol"] else "."))
    if stale:
        foot.append(f"<p>С момента сборки влито {plural(stale, 'задача', 'задачи', 'задач')} — цифры могли поплыть. Скажи «собери отчёт» — пересоберу с аудитом.</p>")
    out.append(f'<div class="foot">{"".join(foot)}</div></div></body></html>')
    return "\n".join(out)


def ensure_gitignore(forge_dir):
    """HTML и снимки регенерируются из JSON — в git им не место. Рождаются они здесь, значит и игнор — здесь
    (finishing делает git add -A раньше backup.sh — ждать его нельзя)."""
    gi = forge_dir / ".gitignore"
    if not gi.is_file():
        gi.write_text("".join(l + "\n" for l in FORGE_IGNORE), encoding="utf-8")
        return
    text = gi.read_text(encoding="utf-8")
    missing = [l for l in ("status-report.html", "reports/shots/") if l not in text.splitlines()]
    if missing:
        with gi.open("a", encoding="utf-8") as fh:
            fh.write(("" if text.endswith("\n") else "\n") + "".join(l + "\n" for l in missing))


def do_render(json_path, html_path):
    data = load(json_path)
    fixed = normalize_blocks(data)
    base = Path(json_path).resolve().parent.parent  # .forge/status-report.json → корень проекта
    out_dir = Path(html_path).resolve().parent
    if out_dir.name == ".forge":  # боевой отчёт, не макет в sketches/ или /tmp
        ensure_gitignore(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    html_text = render_html(data, base)
    Path(html_path).write_text(html_text, encoding="utf-8")
    print(f"FORGE-REPORT: HTML собран → {html_path}")
    for fid, bad in fixed:
        print(f"FORGE-REPORT: у находки {fid} блок «{bad}» неизвестен — показана в «Скоро»; поправь block в JSON")
    c = counts(data)
    print(f"FORGE-REPORT: {plural(c['total'], 'находка', 'находки', 'находок')} → "
          f"{plural(c['blocks'], 'блок', 'блока', 'блоков')}, чиню я — {c['open_code']}, "
          f"решаешь ты — {c['open_decisions']}, отложено — {len(c['deferred'])}, "
          f"снимков — {html_text.count('class=\"shot\"')}")


def cd_repo_root():
    """Пути по умолчанию — от корня проекта; вызов из поддиректории (finishing, хуки) не должен молча промахиваться."""
    if DEFAULT_JSON.is_file():
        return
    try:
        top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    except OSError:
        top = ""
    if top:
        os.chdir(top)


def run(argv):
    mode = argv[1] if len(argv) > 1 else "render"
    cd_repo_root()
    today = date.today().isoformat()
    if mode == "render":
        jp = Path(argv[2]) if len(argv) > 2 else DEFAULT_JSON
        hp = Path(argv[3]) if len(argv) > 3 else DEFAULT_HTML
        if not jp.is_file():
            print(f"FORGE-REPORT: нет {jp} — отчёт ещё не собирали")
            return 0
        do_render(jp, hp)
    elif mode == "merged":
        if len(argv) < 3:
            print("usage: render.py merged <task-slug> [json]", file=sys.stderr)
            return 2
        slug = argv[2]
        jp = Path(argv[3]) if len(argv) > 3 else DEFAULT_JSON
        if not jp.is_file():
            return 0  # отчёта нет — нечего обновлять, молча
        data = load(jp)
        hit = []
        for f in data.get("findings", []):
            if f.get("task_slug") == slug and f.get("status") != "done":
                f["status"] = "done"
                f["done_at"] = today
                hit.append(f.get("title", f.get("id")))
        data["stale_tasks"] = int(data.get("stale_tasks", 0) or 0) + 1
        data["updated_at"] = today
        save(jp, data)
        do_render(jp, jp.with_suffix(".html"))
        if hit:
            print(f"FORGE-REPORT: сделано → {'; '.join(hit)}; отчёт устарел на {plural(data['stale_tasks'], 'задачу', 'задачи', 'задач')}")
        else:
            print(f"FORGE-REPORT: карточки с задачей «{slug}» нет; отчёт устарел на {plural(data['stale_tasks'], 'задачу', 'задачи', 'задач')}")
    elif mode == "link":
        if len(argv) < 4:
            print("usage: render.py link <finding-id> <task-slug> [json]", file=sys.stderr)
            return 2
        fid, slug = argv[2], argv[3]
        jp = Path(argv[4]) if len(argv) > 4 else DEFAULT_JSON
        if not jp.is_file():
            return 0
        data = load(jp)
        hit = [f for f in data.get("findings", []) if f.get("id") == fid]
        if not hit:
            print(f"FORGE-REPORT: карточки {fid} нет")
            return 0
        for f in hit:
            f["task_slug"] = slug
        data["updated_at"] = today
        save(jp, data)
        do_render(jp, jp.with_suffix(".html"))
        print(f"FORGE-REPORT: карточка {fid} → задача {slug}")
    elif mode == "summary":
        jp = Path(argv[2]) if len(argv) > 2 else DEFAULT_JSON
        if not jp.is_file():
            return 0
        try:
            data = load(jp)
        except Exception:
            return 0
        c = counts(data)
        stale = int(data.get("stale_tasks", 0) or 0)
        bits = []
        if c["open_decisions"]:
            bits.append(f"ждут {plural(c['open_decisions'], 'решение', 'решения', 'решений')} владельца")
        if stale:
            bits.append(f"отчёт устарел на {plural(stale, 'задачу', 'задачи', 'задач')}")
        if bits:
            print("📊 Отчёт «Что дальше»: " + ", ".join(bits) + " (.forge/status-report.html; пересобрать — «собери отчёт»)")
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


def main(argv):
    try:
        return run(argv)
    except ReportBroken as e:
        print(e)
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
