#!/usr/bin/env python3
"""Страничка снимков прохода «прокликай»: один HTML, картинки внутри файла.

Usage: shots-page.py <out.html> <заголовок> [--url=<адрес>] [--record=<тестовая запись> ...] <снимок>::<подпись> [...]
Подпись с меткой «!починил: » в начале — карточка «было сломано → починил».
--url — адрес прохода в шапке; --record — строка в блок «Тестовые записи» (созданное на проходе).
Файл — только владельцу (600; новая папка — 700, существующую не трогает): на снимках могут быть его аккаунты.
"""
import base64
import html
import os
import sys
from datetime import datetime

MIME = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}
FIXED = "!починил: "
WARN_BYTES = 3 * 1024 * 1024
MONTHS = ("января", "февраля", "марта", "апреля", "мая", "июня",
          "июля", "августа", "сентября", "октября", "ноября", "декабря")

CSS = """
:root{--bg:#f6f5f2;--card:#fff;--ink:#1d1d1f;--muted:#6b6b70;--line:#e2e0da;--bad:#c62f2f}
@media (prefers-color-scheme:dark){:root{--bg:#151517;--card:#1f1f22;--ink:#ececee;--muted:#9a9aa1;--line:#2e2e33;--bad:#ff6b6b}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.5 -apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:960px;margin:0 auto;padding:24px 16px 48px}
h1,.meta,.cap,.records li{overflow-wrap:anywhere}
h1{font-size:22px;line-height:1.3;margin:0 0 6px}
.meta{color:var(--muted);font-size:14px;margin-bottom:24px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden}
.card.fixed{border-color:var(--bad)}
.card img{width:100%;max-height:70vh;object-fit:cover;object-position:top;display:block;background:var(--line)}
.cap{padding:10px 12px;font-size:15px}
.records{margin-top:24px;background:var(--card);border:1px solid var(--line);border-radius:12px;padding:12px 16px;font-size:15px}
.records h2{font-size:15px;margin:0 0 6px}
.records ul{margin:0;padding-left:20px}
.tag{display:inline-block;margin-bottom:4px;padding:1px 8px;border-radius:999px;font-size:12px;color:#fff;background:var(--bad)}
"""


def card(n, path, caption):
    fixed = caption.startswith(FIXED)
    if fixed:
        caption = caption[len(FIXED):]
    mime = MIME.get(os.path.splitext(path)[1].lower(), "image/png")
    with open(path, "rb") as f:
        src = f"data:{mime};base64,{base64.b64encode(f.read()).decode()}"
    tag = '<span class="tag">было сломано → починил</span><br>' if fixed else ""
    return (f'<div class="card{" fixed" if fixed else ""}"><img src="{src}" alt=""><div class="cap">{tag}{n}. {html.escape(caption)}</div></div>')


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    out, title = argv[0], argv[1]
    opts = [a for a in argv[2:] if a.startswith(("--record=", "--url="))]
    records = [a[len("--record="):] for a in opts if a.startswith("--record=")]
    url = next((a[len("--url="):] for a in opts if a.startswith("--url=")), "")
    shots = [a for a in argv[2:] if a not in opts]
    if not shots:
        print("нет ни одного снимка (<снимок>::<подпись>) — страничка не создана", file=sys.stderr)
        return 2
    pairs = [s.split("::", 1) if "::" in s else [s, ""] for s in shots]
    missing = [p for p, _ in pairs if not os.path.isfile(p)]
    if missing:
        for p in missing:
            print(f"нет снимка: {p}", file=sys.stderr)
        print("страничка не создана — проверь пути снимков", file=sys.stderr)
        return 1

    cards = "\n".join(card(i, p, c) for i, (p, c) in enumerate(pairs, 1))
    extra = ""
    if records:
        items = "".join(f"<li>{html.escape(r)}</li>" for r in records)
        extra = f'<div class="records"><h2>Тестовые записи</h2><ul>{items}</ul></div>'
    now = datetime.now()
    meta = f"{now.day} {MONTHS[now.month - 1]} {now.year}, {now:%H:%M}" + (f" · {html.escape(url)}" if url else "")
    page = (f'<!doctype html><html lang="ru"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">'
            f'<title>Прошёл в браузере</title><style>{CSS}</style></head><body><main>'
            f'<h1>{html.escape(title)}</h1><div class="meta">{meta}</div>'
            f'<div class="grid">{cards}</div>{extra}</main></body></html>')

    folder = os.path.dirname(os.path.abspath(out))
    if not os.path.isdir(folder):
        os.makedirs(folder, mode=0o700)
        os.chmod(folder, 0o700)
    fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(page)
    os.chmod(out, 0o600)

    size = os.path.getsize(out)
    if size > WARN_BYTES:
        print(f"страничка {size / 1024 / 1024:.1f} МБ — на телефоне может не открыться: меньше снимков или без fullPage", file=sys.stderr)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
