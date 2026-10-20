#!/usr/bin/env python3
"""Builds index.html: every onboarding page, ours (Sirish) beside Sulav's, iPhone SE, same answers."""
from pathlib import Path
from PIL import Image, ImageChops

HERE = Path(__file__).parent

# (step, page name, what differs). Ours = V8 + the inspection fixes (uncommitted);
# Sulav = origin/main ef8a800 (V8 + his changes, without the inspection fixes).
PAGES = [
    ("welcome", "Welcome", "Sulav: one message, “Focused workouts.”, the locking phone and the flexing arm. Ours: the two-row welcome."),
    ("founder", "Sulav’s note", "Sulav: removed; Get started goes straight to the name. Ours: the note is page 2."),
    ("name", "Name", ""),
    ("trainingDays", "Days a week", "Ours: the slider’s end labels a shade darker (inspection fix)."),
    ("scrolling", "Phone between sets", "Sulav: “Does your phone suck you in between sets?” over a phone pulling the kit into its feed. Ours: “Do you check your phone between sets?” over notifications."),
    ("ahead", "“Rarely” answer", "Only if they answer Rarely on the page before."),
    ("restNeed", "Rest they need", "Ours: answers as big-number tiles (inspection fix). Sulav: answer rows."),
    ("scrollMinutes", "Minutes scrolling", "Sulav: “Once you start scrolling, how many minutes go by?” Ours: “When you start scrolling between sets, how many minutes do you scroll?”"),
    ("perRest", "Per rest", "Ours: the part of the scrolling bar that’s rest you need is grey, not pink, and the red is darker (inspection fixes)."),
    ("exerciseCount", "Exercises", "Sulav: “How many exercises per workout?”, the rack built to the count, a plain kettlebell. Ours: longer headline, tiles, the seven-slot rack with the brand mark."),
    ("setCount", "Sets each", "Sulav: “And how many sets of each?”, the log sits straight. Ours: longer headline, tiles, a tilted log."),
    ("gymTime", "Time at the gym", "Sulav: “How long are you at the gym?” Ours: “How long are you usually at the gym?”, tiles."),
    ("workoutTime", "Your workout", "Ours: darker bars and labels, every number rounded down to the same figure (inspection fixes)."),
    ("yearTime", "Your year", "Sulav: “That’s about 120 hours a year.”, with “At 4 workouts a week.” under the dots. Ours: “At 4 workouts a week, that’s about 120 hours a year.”, with “Your numbers, multiplied out.”"),
    ("promise", "The promise", "Ours: darker bars, the hero number placed higher (inspection fixes)."),
    ("shield", "Shield", "Sulav: plays on a phone (home screen, a tap on TikTok, then GymBlock’s shield; it loops). Ours: the shield on its own."),
    ("blocking", "Choose apps", "Sulav: “Which apps should we lock?” Ours: “…while you train?”"),
    ("alerts", "Rest alerts", ""),
    ("commit", "Commit", "Ours: the fingerprint sits higher on the SE (inspection fix)."),
    ("account", "Account", "Sulav: “Let’s save your plan.” Ours: “…to your account.”"),
    ("subscription", "Offer", "Sulav’s copy still has the cut-off “35 min scro…” label inside the red bar; ours moves it under the bar (inspection fix)."),
    ("splits", "Splits", "Sulav: “You’re in. How do you split your training?” Ours: “…usually split…”"),
    ("firstWorkout", "First workout", ""),
]


def changed(a: Path, b: Path) -> float:
    """Share of pixels that differ below the status bar (0–100)."""
    x, y = Image.open(a).convert("L"), Image.open(b).convert("L")
    if x.size != y.size:
        return 100.0
    w, h = x.size
    box = (0, int(h * 0.05), w, h)
    d = ImageChops.difference(x.crop(box), y.crop(box)).point(lambda v: 255 if v > 24 else 0)
    return 100.0 * d.histogram()[255] / (w * (h - box[1]))


rows = []
n = 0
for step, title, note in PAGES:
    ours, his = HERE / "sirish" / f"{step}.jpg", HERE / "sulav" / f"{step}.jpg"
    removed = step == "founder"
    if step != "ahead":
        n += 1
    num = "" if step == "ahead" else f"{n}"
    if removed:
        tag, cls = "Removed by Sulav", "diff"
        his_cell = '<div class="gone">No page.<br>Sulav removed his note.</div>'
    else:
        pct = changed(ours, his) if ours.exists() and his.exists() else 100.0
        tag, cls = ("Same", "same") if pct < 1.0 else ("Different", "diff")
        print(f"{step:14} {pct:6.2f}% {tag}")
        his_cell = f'<img src="sulav/{step}.jpg" alt="Sulav: {title}" loading="lazy">'
    rows.append(f"""
<section class="row" id="{step}">
  <header><span class="num">{num or "·"}</span><h2>{title}</h2><span class="tag {cls}">{tag}</span></header>
  {f'<p class="note">{note}</p>' if note else ''}
  <div class="pair">
    <figure><img src="sirish/{step}.jpg" alt="Ours: {title}" loading="lazy"><figcaption>Ours</figcaption></figure>
    <figure>{his_cell}<figcaption>Sulav</figcaption></figure>
  </div>
</section>""")

html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Onboarding Side by Side</title>
<style>
:root {{ --paper:#F5F3EF; --ink:#16161A; --soft:#6B6A66; --line:#E2DED6; --emerald:#0F9A6B; --card:#FFFFFF; --warm:#B8452F; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --paper:#16161A; --ink:#F5F3EF; --soft:#A3A19B; --line:#2C2C31; --card:#1F1F24; }} }}
:root[data-theme="dark"] {{ --paper:#16161A; --ink:#F5F3EF; --soft:#A3A19B; --line:#2C2C31; --card:#1F1F24; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--paper); color:var(--ink); font:15px/1.45 -apple-system, "SF Pro Text", system-ui, sans-serif; }}
main {{ max-width:860px; margin:0 auto; padding:24px 16px 64px; }}
h1 {{ font-size:28px; margin:0 0 6px; letter-spacing:-0.02em; }}
.lede {{ color:var(--soft); margin:0 0 18px; }}
.key {{ display:grid; grid-template-columns:1fr 1fr; gap:12px; margin-bottom:22px; }}
.key div {{ background:var(--card); border:1px solid var(--line); border-radius:16px; padding:12px 14px; }}
.key b {{ display:block; }}
.key span {{ color:var(--soft); font-size:13px; }}
.cols {{ position:sticky; top:0; z-index:2; display:grid; grid-template-columns:1fr 1fr; gap:14px; padding:10px 0; background:var(--paper); border-bottom:1px solid var(--line); font-weight:600; text-align:center; }}
.row {{ padding:22px 0; border-bottom:1px solid var(--line); scroll-margin-top:48px; }}
.row header {{ display:flex; align-items:center; gap:10px; margin-bottom:6px; }}
.num {{ width:28px; height:28px; border-radius:50%; background:var(--ink); color:var(--paper); display:grid; place-items:center; font-size:13px; font-weight:600; flex:none; }}
h2 {{ font-size:18px; margin:0; flex:1; }}
.tag {{ font-size:12px; font-weight:600; padding:3px 9px; border-radius:99px; border:1px solid var(--line); }}
.tag.diff {{ color:var(--emerald); border-color:var(--emerald); }}
.tag.same {{ color:var(--soft); }}
.note {{ margin:0 0 12px; color:var(--soft); font-size:14px; }}
.pair {{ display:grid; grid-template-columns:1fr 1fr; gap:14px; }}
figure {{ margin:0; }}
figure img {{ width:100%; display:block; border-radius:18px; border:1px solid var(--line); background:var(--card); }}
figcaption {{ text-align:center; color:var(--soft); font-size:12px; margin-top:6px; }}
.gone {{ aspect-ratio:750/1334; border-radius:18px; border:1px dashed var(--line); display:grid; place-items:center; text-align:center; color:var(--soft); font-size:14px; padding:12px; }}
nav {{ display:flex; flex-wrap:wrap; gap:6px; margin-bottom:18px; }}
nav a {{ font-size:12px; color:var(--ink); text-decoration:none; border:1px solid var(--line); border-radius:99px; padding:3px 9px; background:var(--card); }}
@media (max-width:520px) {{ .key {{ grid-template-columns:1fr; }} .pair, .cols {{ gap:8px; }} figure img, .gone {{ border-radius:12px; }} }}
</style></head>
<body><main>
<h1>Onboarding, side by side</h1>
<p class="lede">Every page on the iPhone SE simulator (iOS 26.5, like your phone), same answers on both: rest 90 s, scrolling 4 min, 5 exercises × 3 sets, 90 min at the gym, 4 days a week. Each captured 12 s after the page opens.</p>
<div class="key">
  <div><b>Ours (GB Sirish)</b><span>V8 plus today’s inspection fixes, not committed. Doesn’t have Sulav’s changes.</span></div>
  <div><b>Sulav (GB Sulav)</b><span>GitHub main, ef8a800. V8 plus his changes. Doesn’t have today’s fixes.</span></div>
</div>
<nav>{''.join(f'<a href="#{s}">{t}</a>' for s, t, _ in PAGES)}</nav>
<div class="cols"><div>Ours</div><div>Sulav</div></div>
{''.join(rows)}
</main></body></html>"""

(HERE / "index.html").write_text(html)
print("wrote", HERE / "index.html")
