#!/usr/bin/env python3
"""Build the DMC DBA Toolkit landing page from the script headers.

Walks every diagnostic script, reads its standard header (engine, category,
impact, level) and the one-line description from the README catalog, and emits
a single self-contained `site/index.html`: a searchable, filterable catalogue
of the whole toolkit. No build dependencies, no JS framework — one HTML file.

    python scripts/build_site.py            # writes site/index.html
"""
from __future__ import annotations

import html
import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "site"
GH = "https://github.com/dmcteknoloji/dmc-dba-toolkit/blob/main"

ENGINES = {
    "mssql": {"label": "SQL Server", "glob": "*.sql", "dot": "#cc2927"},
    "postgresql": {"label": "PostgreSQL", "glob": "*.sql", "dot": "#336791"},
    "mysql": {"label": "MySQL", "glob": "*.sql", "dot": "#00758f"},
    "mongodb": {"label": "MongoDB", "glob": "*.js", "dot": "#00ed64"},
}

HEADER_FIELD = re.compile(r"^(?:--|//)\s*║\s*([A-Za-z][A-Za-z ]+?)\s*:\s*(.+?)\s*║\s*$")
README_ROW = re.compile(r"^\|\s*\[`([^`]+)`\]\(\.?/?([^)]+)\)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|")
EMOJI = re.compile(r"[\U0001F300-\U0001FAFF☀-➿️]")


def readme_descriptions() -> dict[str, str]:
    out = {}
    for line in (REPO / "README.md").read_text(encoding="utf-8").splitlines():
        m = README_ROW.match(line)
        if m:
            out[m.group(2).strip()] = m.group(3).strip()
    return out


def parse_header(path: Path) -> dict:
    meta = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines()[:40]:
        m = HEADER_FIELD.match(line)
        if m:
            meta[m.group(1)] = m.group(2)
    return meta


def short_impact(value: str) -> str:
    # "🟢 Light  (msdb scan)" -> "Light"
    v = EMOJI.sub("", value or "").strip()
    return re.split(r"\s{2,}|\(", v, maxsplit=1)[0].strip() or "—"


def short_level(value: str) -> str:
    v = EMOJI.sub("", value or "").strip()
    return re.split(r"\s{2,}|\(", v, maxsplit=1)[0].strip() or "—"


def collect() -> list[dict]:
    desc = readme_descriptions()
    rows = []
    for eng, cfg in ENGINES.items():
        for path in sorted((REPO / eng).rglob(cfg["glob"])):
            rel = path.relative_to(REPO).as_posix()
            meta = parse_header(path)
            rows.append({
                "name": meta.get("Script", path.stem),
                "engine": eng,
                "engine_label": cfg["label"],
                "category": path.parent.name,
                "impact": short_impact(meta.get("Impact", "")),
                "level": short_level(meta.get("Level", "")),
                "desc": desc.get(rel, ""),
                "url": f"{GH}/{rel}",
            })
    return rows


def render(rows: list[dict]) -> str:
    engines = sorted({r["engine_label"] for r in rows})
    categories = sorted({r["category"] for r in rows})
    levels = ["Newborn", "Middle", "Expert"]
    data = json.dumps(rows, ensure_ascii=False)
    dots = {ENGINES[e]["label"]: ENGINES[e]["dot"] for e in ENGINES}
    return TEMPLATE \
        .replace("/*DATA*/", data) \
        .replace("/*DOTS*/", json.dumps(dots)) \
        .replace("__COUNT__", str(len(rows))) \
        .replace("__ENGINES__", "".join(f'<button class="chip" data-k="engine" data-v="{html.escape(e)}">{html.escape(e)}</button>' for e in engines)) \
        .replace("__CATEGORIES__", "".join(f'<button class="chip" data-k="category" data-v="{html.escape(c)}">{html.escape(c)}</button>' for c in categories)) \
        .replace("__LEVELS__", "".join(f'<button class="chip" data-k="level" data-v="{html.escape(l)}">{html.escape(l)}</button>' for l in levels))


TEMPLATE = r"""<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DMC DBA Toolkit — searchable catalogue</title>
<meta name="description" content="A modern, opinionated, execution-tested diagnostics kit for SQL Server, PostgreSQL, MySQL and MongoDB. Read-only by default. By DMC Bilgi Teknolojileri.">
<meta property="og:title" content="DMC DBA Toolkit">
<meta property="og:description" content="__COUNT__ execution-tested, read-only DBA diagnostics across four engines.">
<meta property="og:type" content="website">
<style>
  :root{--bg:#0b0e14;--panel:#121722;--line:#1f2733;--txt:#e6edf3;--mut:#8b98a9;--accent:#2f81f7;--ok:#2ea043}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--txt);font:15px/1.55 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}
  a{color:var(--accent);text-decoration:none}
  .wrap{max-width:1100px;margin:0 auto;padding:28px 20px 80px}
  header.hero{background:radial-gradient(900px 300px at 20% -10%,rgba(47,129,247,.25),transparent),linear-gradient(180deg,#0e1420,#0b0e14);border:1px solid var(--line);border-radius:18px;padding:40px 34px}
  .brand{font-weight:800;letter-spacing:.4px;text-transform:uppercase;font-size:13px;color:var(--mut)}
  h1{margin:8px 0 6px;font-size:34px;letter-spacing:-.5px}
  .tag{color:var(--mut);font-size:16px;max-width:680px}
  .stats{display:flex;gap:14px;flex-wrap:wrap;margin:22px 0 4px}
  .stat{background:rgba(255,255,255,.04);border:1px solid var(--line);border-radius:12px;padding:12px 16px}
  .stat b{font-size:22px} .stat span{color:var(--mut);font-size:12px;text-transform:uppercase;letter-spacing:.5px;display:block}
  .cta{margin-top:20px;display:flex;gap:10px;flex-wrap:wrap}
  .btn{border:1px solid var(--line);background:#0f1521;color:var(--txt);padding:10px 16px;border-radius:10px;font-weight:600}
  .btn.primary{background:var(--accent);border-color:var(--accent);color:#fff}
  .controls{position:sticky;top:0;background:rgba(11,14,20,.92);backdrop-filter:blur(8px);padding:18px 0 10px;margin-top:26px;z-index:5;border-bottom:1px solid var(--line)}
  input[type=search]{width:100%;padding:13px 16px;background:var(--panel);border:1px solid var(--line);border-radius:12px;color:var(--txt);font-size:15px}
  .chips{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}
  .chip{background:var(--panel);border:1px solid var(--line);color:var(--mut);padding:6px 12px;border-radius:20px;font-size:13px;cursor:pointer}
  .chip.on{background:var(--accent);border-color:var(--accent);color:#fff}
  .chips .lbl{color:var(--mut);font-size:12px;text-transform:uppercase;letter-spacing:.5px;align-self:center;margin-right:2px}
  .count{color:var(--mut);font-size:13px;margin:16px 2px 8px}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:12px}
  .card{display:block;background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--dot,#444);border-radius:12px;padding:14px 16px}
  .card:hover{border-color:var(--accent)}
  .card .top{display:flex;align-items:center;gap:8px;margin-bottom:6px}
  .card .nm{font-weight:700;font-family:ui-monospace,Menlo,monospace;font-size:14px;color:var(--txt)}
  .card .eng{margin-left:auto;font-size:11px;color:var(--mut)}
  .card .d{color:var(--mut);font-size:13.5px;min-height:34px}
  .card .meta{display:flex;gap:8px;margin-top:10px;font-size:11px;color:var(--mut)}
  .pill{border:1px solid var(--line);border-radius:20px;padding:2px 8px}
  footer{color:var(--mut);font-size:13px;margin-top:40px;text-align:center}
</style></head>
<body><div class="wrap">
  <header class="hero">
    <div class="brand">🛡️ DMC DBA Toolkit · DMC Bilgi Teknolojileri</div>
    <h1>The diagnostic drawer, rebuilt with discipline.</h1>
    <p class="tag">__COUNT__ opinionated, read-only diagnostics for SQL Server, PostgreSQL, MySQL and MongoDB. Every script carries a standard header, a documented output schema, and runs against a real engine on every push.</p>
    <div class="stats">
      <div class="stat"><b>__COUNT__</b><span>scripts</span></div>
      <div class="stat"><b>4</b><span>engines</span></div>
      <div class="stat"><b>✓</b><span>execution-tested</span></div>
      <div class="stat"><b>MIT</b><span>license</span></div>
    </div>
    <div class="cta">
      <a class="btn primary" href="https://github.com/dmcteknoloji/dmc-dba-toolkit">View on GitHub</a>
      <a class="btn" href="https://github.com/dmcteknoloji/dmc-dba-toolkit#-run-the-whole-suite-in-one-command">One-command runner</a>
      <a class="btn" href="https://github.com/dmcteknoloji/dmc-dba-toolkit/blob/main/docs/OUTPUT_SCHEMAS.md">Output schemas</a>
    </div>
  </header>

  <div class="controls">
    <input id="q" type="search" placeholder="Search __COUNT__ scripts — name, description, category…" autocomplete="off">
    <div class="chips"><span class="lbl">Engine</span>__ENGINES__</div>
    <div class="chips"><span class="lbl">Category</span>__CATEGORIES__</div>
    <div class="chips"><span class="lbl">Level</span>__LEVELS__</div>
  </div>

  <div class="count" id="count"></div>
  <div class="grid" id="grid"></div>

  <footer>
    Built from the script headers · <a href="https://github.com/dmcteknoloji/dmc-dba-toolkit">dmcteknoloji/dmc-dba-toolkit</a><br>
    DMC Bilgi Teknolojileri · read-only by default · public vendor docs only
  </footer>
</div>
<script>
const DATA = /*DATA*/;
const DOTS = /*DOTS*/;
const filters = {engine:null, category:null, level:null};
const grid = document.getElementById('grid');
const countEl = document.getElementById('count');
const q = document.getElementById('q');

function matches(r){
  if(filters.engine && r.engine_label!==filters.engine) return false;
  if(filters.category && r.category!==filters.category) return false;
  if(filters.level && !r.level.startsWith(filters.level)) return false;
  const t = q.value.trim().toLowerCase();
  if(t){ const hay=(r.name+' '+r.desc+' '+r.category+' '+r.engine_label).toLowerCase(); if(!hay.includes(t)) return false; }
  return true;
}
function render(){
  const rows = DATA.filter(matches);
  countEl.textContent = rows.length + ' of ' + DATA.length + ' scripts';
  grid.innerHTML = rows.map(r=>`
    <a class="card" style="--dot:${DOTS[r.engine_label]||'#444'}" href="${r.url}">
      <div class="top"><span class="nm">${r.name}</span><span class="eng">${r.engine_label}</span></div>
      <div class="d">${r.desc||''}</div>
      <div class="meta"><span class="pill">${r.category}</span><span class="pill">${r.impact}</span><span class="pill">${r.level}</span></div>
    </a>`).join('');
}
document.querySelectorAll('.chip').forEach(c=>c.addEventListener('click',()=>{
  const k=c.dataset.k, v=c.dataset.v;
  const on = filters[k]===v;
  document.querySelectorAll(`.chip[data-k="${k}"]`).forEach(x=>x.classList.remove('on'));
  filters[k] = on?null:v; if(!on) c.classList.add('on');
  render();
}));
q.addEventListener('input', render);
render();
</script>
</body></html>"""


def main() -> None:
    rows = collect()
    OUT.mkdir(exist_ok=True)
    (OUT / "index.html").write_text(render(rows), encoding="utf-8")
    print(f"wrote {OUT/'index.html'} with {len(rows)} scripts")


if __name__ == "__main__":
    main()
