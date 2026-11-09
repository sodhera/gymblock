#!/usr/bin/env python3
"""GymBlock's App Store screenshots, 9 Nov 2026 set (the 'emerald' set).

Why it looks like this (research and review in docs/listing.md#screenshots-9-nov-2026):
- Most visitors come from TikTok, Instagram and YouTube, search the name, and decide on the search
  row: three slides about 118 pt wide. So every slide carries one idea in a short headline that reads
  at that size, and the app's own screens are shown large and sharp (no blurred phone body).
- Slides 1-3 tell one workout: your feeds lock (the real Home Screen mid-workout, and the shield you
  hit if you open one anyway), rest on the Lock Screen, and the log. The rest follow.
- The stage is emerald and never flat (the user, 9 Nov 2026): deep emerald, darker at the edges, a
  bright mint glow behind each phone with pulse rings (`glow` in store_bg.py; --bg picks another look).
  White headlines with one word in a yellow box with black type, as the user asked.
- The phone is Apple's own iPhone 18 Pro Max outline (store_kit.place_device), on every slide.
- Only real captures: the Home Screen and the shield's design are from a real iPhone and the app's
  rebuild; every number is the app's sample data. Lock badges are drawn over the real Screen Time
  hourglasses so 'locked' reads at search size.

    python3 scripts/store-slides.py            # writes screenshots/store-emerald/<slot>/, overview
    python3 scripts/store-slides.py --only 1   # one slide (6.9-inch only), for quick checks
    python3 scripts/store-slides.py --bg aurora --only 1,2,3 --out store-options/aurora   # try a look

Captures: screenshots/store-2026-11-02 (real iPhone Home Screen, picker rebuild),
store-2026-11-08 (white app), store-2026-11-09 (Lock Screen rest Live Activity, new).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import store_kit as k  # noqa: E402

ROOT = k.ROOT
SHOTS = os.path.join(ROOT, "screenshots")
OUT = os.path.join(SHOTS, "store-emerald")
W, H = k.W, k.H

# The icon's emerald (#0F9A6B), deepened so white type passes 7:1 and the slide keeps an edge on
# both App Store backgrounds.
STAGE = ((14, 124, 88), (8, 92, 65))
WHITE = (255, 255, 255)
PAPER = (245, 243, 239)
YELLOW = (255, 214, 10)   # the highlight box (9 Nov 2026, the user's call: yellow with black words)
INK = (12, 12, 13)
MINT = (206, 240, 225)
SHADOW = (0, 26, 17)
MARGIN = 84
TEXT_W = W - 2 * MARGIN


def cap(path):
    return Image.open(os.path.join(SHOTS, path)).convert("RGB")


# ---------- type ----------

def _line_width(draw, words, f):
    """A line's width, counting the paper box's overhang (and a word space) at each end of an accent run."""
    space = draw.textlength(" ", font=f)
    padx = round(f.size * 0.13)
    w = sum(draw.textlength(x, font=f) for x, _ in words) + space * (len(words) - 1)
    for i, (_, acc) in enumerate(words):
        if acc and (i == 0 or not words[i - 1][1]):
            w += padx + (space * 0.35 if i > 0 else 0)
        if acc and (i == len(words) - 1 or not words[i + 1][1]):
            w += padx + (space * 0.35 if i < len(words) - 1 else 0)
    return w


def _wrap(draw, text, f, max_w=TEXT_W):
    out = []
    for words in k.parse(text):
        cur = []
        for w in words:
            trial = cur + [w]
            if cur and _line_width(draw, trial, f) > max_w:
                out.append(cur)
                cur = [w]
            else:
                cur = trial
        out.append(cur)
    return out


def fitted_size(text, size=204, min_size=150, lines=2):
    """The largest headline size (in 4-px steps) that sets `text` in `lines` lines inside the margins."""
    draw = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    s = size
    while s >= min_size:
        f = k.sf(s, weight=820)
        rows = _wrap(draw, text, f)
        if len(rows) <= lines and all(_line_width(draw, r, f) <= TEXT_W for r in rows):
            return s
        s -= 4
    raise ValueError(f"{text!r} doesn't fit in {lines} lines at {min_size}px")


HEAD_SIZE = None  # set in main(): one size for the whole set, the largest every headline fits


def headline(canvas, text, y, size=None, min_size=150, align="left", lines=2):
    """White display type with *accent* words set in a paper box (consecutive accent words share one
    box, which sits inside the margins and clear of its neighbours). Returns the bottom y."""
    draw = ImageDraw.Draw(canvas)
    s = size or HEAD_SIZE or 200
    while True:
        f = k.sf(s, weight=820)
        rows = _wrap(draw, text, f)
        if len(rows) <= lines and all(_line_width(draw, r, f) <= TEXT_W for r in rows):
            break
        s -= 4
        if s < min_size:
            raise ValueError(f"{text!r} doesn't fit in {lines} lines")
    lh = round(f.size * 1.06)
    space = draw.textlength(" ", font=f)
    padx, pady = round(f.size * 0.13), round(f.size * 0.10)
    cap_top, base = f.getbbox("H")[1], f.getbbox("H")[3]
    cy = y
    for words in rows:
        lw = _line_width(draw, words, f)
        cx = MARGIN if align == "left" else MARGIN + (TEXT_W - lw) / 2
        xs = []
        for i, (w, acc) in enumerate(words):
            if acc and (i == 0 or not words[i - 1][1]):
                cx += padx + (space * 0.35 if i > 0 else 0)
            ww = draw.textlength(w, font=f)
            xs.append((cx, cx + ww, acc))
            cx += ww
            if acc and (i == len(words) - 1 or not words[i + 1][1]):
                cx += padx + (space * 0.35 if i < len(words) - 1 else 0)
            cx += space
        i = 0
        while i < len(xs):
            if xs[i][2]:
                j = i
                while j + 1 < len(xs) and xs[j + 1][2]:
                    j += 1
                box = (xs[i][0] - padx, cy + cap_top - pady, xs[j][1] + padx, cy + base + pady)
                draw.rounded_rectangle(box, round(f.size * 0.16), fill=YELLOW)
                i = j + 1
            else:
                i += 1
        for (x0, _, acc), (w, _) in zip(xs, words):
            draw.text((x0, cy), w, font=f, fill=INK if acc else WHITE)
        cy += lh
    return cy


def subline(canvas, text, y, align="left", size=58, min_size=50):
    """One line in pale mint under the headline; it steps down (to min_size) to stay on one line."""
    draw = ImageDraw.Draw(canvas)
    s = size
    while s > min_size and draw.textlength(text, font=k.sf(s, weight=560)) > TEXT_W:
        s -= 2
    f = k.sf(s, weight=560)
    bottom, _ = k.text_block(canvas, text, MARGIN, y, TEXT_W, f, MINT, align=align, leading=1.22)
    return bottom


BG = "glow"  # 9 Nov 2026: emerald, never flat (scripts/store_bg.py)
SLIDE_NO = 1
# Gym photos for the 'photo' stage: crops of the Unsplash photos the carousels already use
# (docs/marketing/carousels/*/SOURCES.md), the parts no caption covers. (path, box)
PHOTOS = {
    1: ("docs/marketing/carousels/02-doomscrolling-is-killing-your-gains/1-you-get-lost-while-scrolling.png", (0, 800, 540, 1350)),
    2: ("docs/marketing/carousels/05-5-gym-mistakes-everyone-makes/4-walking-in-without-a-plan.png", (0, 0, 540, 640)),
    3: ("docs/marketing/carousels/02-doomscrolling-is-killing-your-gains/2-your-focus-leaves-the-muscle.png", (0, 0, 540, 520)),
}


def _grain(img, amount=10, seed=0):
    """Fine film grain, so a large colour field doesn't look flat."""
    import random
    rnd = random.Random(seed)
    small = Image.new("L", (W // 2, H // 2))
    small.putdata([128 + rnd.randint(-amount, amount) for _ in range((W // 2) * (H // 2))])
    noise = small.resize((W, H), Image.BILINEAR).convert("RGB")
    from PIL import ImageChops
    return ImageChops.add(img, ImageChops.subtract(noise, Image.new("RGB", (W, H), (128, 128, 128))), 1, 0)


def base_stage():
    import store_bg
    if BG in store_bg.STYLES:
        return store_bg.STYLES[BG](SLIDE_NO)
    if BG == "depth":
        # Emerald with depth: lighter at the top left, deep at the foot, a soft light behind the
        # phone and fine grain.
        img = k.stage((22, 150, 106), (4, 58, 41))
        light = Image.new("L", (W, H), 0)
        ImageDraw.Draw(light).ellipse((-300, -500, W + 200, 1500), fill=110)
        light = light.filter(ImageFilter.GaussianBlur(320))
        img.paste(Image.new("RGB", (W, H), (60, 200, 150)), (0, 0), light)
        glow = Image.new("L", (W, H), 0)
        ImageDraw.Draw(glow).ellipse((W * 0.5 - 700, 1300, W * 0.5 + 700, 2700), fill=90)
        img.paste(Image.new("RGB", (W, H), (40, 190, 135)), (0, 0), glow.filter(ImageFilter.GaussianBlur(260)))
        return _grain(img, 9, SLIDE_NO)
    if BG == "ink":
        # The icon's ink at the top, deep emerald at the foot, an emerald glow behind the phone.
        img = k.stage((18, 20, 19), (4, 74, 52))
        glow = Image.new("L", (W, H), 0)
        ImageDraw.Draw(glow).ellipse((W * 0.5 - 720, 1100, W * 0.5 + 720, 2600), fill=150)
        img.paste(Image.new("RGB", (W, H), (15, 154, 107)), (0, 0), glow.filter(ImageFilter.GaussianBlur(300)))
        return _grain(img, 7, SLIDE_NO)
    if BG == "photo":
        # A real gym photo across the top, where the headline sits, fading into the brand's deep green
        # behind the phone. Darkened only as far as white type needs.
        path, box = PHOTOS[(SLIDE_NO - 1) % len(PHOTOS) + 1]
        ph = Image.open(os.path.join(ROOT, path)).convert("RGB").crop(box)
        top_h = round(H * 0.62)
        sc = max(W / ph.width, top_h / ph.height)
        ph = ph.resize((round(ph.width * sc), round(ph.height * sc)), Image.LANCZOS)
        ph = ph.crop(((ph.width - W) // 2, 0, (ph.width - W) // 2 + W, top_h)).filter(ImageFilter.GaussianBlur(3))
        ph = Image.blend(ph, Image.new("RGB", ph.size, (6, 30, 21)), 0.30)
        img = k.stage((6, 34, 24), (4, 52, 36))
        fade = Image.linear_gradient("L").resize((W, top_h)).point(lambda v: 255 if v < 150 else round(255 * (255 - v) / 105))
        img.paste(ph, (0, 0), fade)
        # A dark wash behind the headline for legibility.
        wash = Image.linear_gradient("L").resize((W, 900)).point(lambda v: round(150 * (1 - v / 255)))
        img.paste(Image.new("RGB", (W, 900), (0, 0, 0)), (0, 0), wash)
        return _grain(img, 6, SLIDE_NO)
    return k.stage(STAGE[0], STAGE[1])


def drop(op=0.42, blur=54, dy=34):
    return (op, blur, dy)


def card(canvas, img, box, x, y, width, r=56, op=0.42):
    """A crop of a real screen, enlarged to `width`, as a rounded card with a deep-green shadow."""
    x0, y0, x1, y1 = box
    h = round((y1 - y0) * width / (x1 - x0))
    k.shadow(canvas, (x, y, x + width, y + h), r, blur=54, opacity=op, dy=34, color=SHADOW)
    piece = img.crop(box).resize((width, h), Image.LANCZOS)
    k.paste_rounded(canvas, piece, x, y, r)
    return (x, y, x + width, y + h)


def has_island(img):
    """Simulator captures of the Lock Screen already draw the Dynamic Island; app captures don't."""
    w = img.width
    px = img.crop((w // 2 - 20, round(w * 0.05), w // 2 + 20, round(w * 0.07))).convert("L")
    return px.getextrema()[1] < 30


def phone(canvas, img, x, y, screen_w, cut=H):
    """Apple's iPhone 18 Pro Max outline around a capture (store_kit.place_device)."""
    k.place_device(canvas, img, x, y, screen_w, cut=cut, island=not has_island(img), drop=(0.5, 56, 44),
                   shadow_color=(0, 14, 9))


# ---------- slides ----------

def slide_lock():
    """1. The feeds locked mid-workout, and what opening one shows."""
    c = base_stage()
    y = headline(c, "No *scrolling* between sets", 150)
    subline(c, "Your apps lock until you tap Finish.", y + 26)
    home = cap("store-2026-11-02/blocked-home.png")
    shield = cap("store-2026-11-08/shield-tiktok.png")
    # The real iPhone's Home Screen mid-workout, in the phone: the workout clock in the Dynamic
    # Island, the feeds under Screen Time's hourglass, Spotify and GymBlock open.
    sw, top = 1080, 860
    x0 = (W - sw) // 2
    phone(c, home, x0, top, sw)
    s = sw / home.width
    # Lock badges over the six locked icons (top-right corner of each), so 'locked' reads small.
    icons = [(85, 240), (357, 240), (632, 240), (905, 240), (85, 538), (357, 538)]
    for ix, iy in icons:
        bx, by = x0 + (ix + 182) * s, top + (iy + 6) * s
        ring = 10
        d = round(92 * s)
        k.lock_badge(c, bx, by, d + 2 * ring, bg=WHITE, fg=WHITE)
        k.lock_badge(c, bx, by, d, bg=INK, fg=WHITE)
    # What opening one shows (the shield), lifted over the Home Screen's empty lower half.
    box = (60, 560, 1260, 1520)
    cw = W - 2 * 64
    card(c, shield, box, 64, top + round(860 * s), cw, r=60, op=0.55)
    return c


def slide_rest():
    """2. Rest counts down on the Lock Screen (Live Activity), so the phone stays locked."""
    c = base_stage()
    y = headline(c, "Rest on your *Lock Screen*", 150)
    subline(c, "Nothing to unlock. Nothing to scroll.", y + 26)
    lock = cap("store-2026-11-09/lock-rest.png")
    sw = 900
    px = (W - sw) // 2
    py = 880
    phone(c, lock, px, py, sw)
    # Lift the Live Activity out, larger, where it sits on the Lock Screen.
    box = (42, 1786, 1164, 2238)
    s = sw / lock.width
    mid = py + (box[1] + box[3]) / 2 * s
    cw = W - 2 * 64
    ch = round((box[3] - box[1]) * cw / (box[2] - box[0]))
    card(c, lock, box, 64, round(mid - ch / 2), cw, r=72, op=0.5)
    return c


def slide_log():
    """3. The workout: a set done, rest running, the next set already filled in."""
    c = base_stage()
    y = headline(c, "Log a set in *seconds*", 150)
    subline(c, "Last time’s weight and reps, filled in.", y + 26)
    shot = cap("store-2026-11-08/workout-rest.png")
    sw = 1060
    phone(c, shot, (W - sw) // 2, 1000, sw)
    box = (40, 370, 1290, 1130)
    cw = W - 2 * 56
    card(c, shot, box, 56, 1180, cw, r=60, op=0.5)
    return c


def fact_rows(canvas, items, y, size=58, h=120):
    """True product facts as pills: deep green, a yellow check, white words. Readable on any glow."""
    f = k.sf(size, weight=640)
    draw = ImageDraw.Draw(canvas)
    d, padx = round(h * 0.58), round(h * 0.28)
    for i, text in enumerate(items):
        cy = y + i * (h + 22)
        w = round(padx + d + 26 + draw.textlength(text, font=f) + padx + 8)
        x = MARGIN
        k.shadow(canvas, (x, cy, x + w, cy + h), h // 2, blur=26, opacity=0.35, dy=12, color=SHADOW)
        pill = Image.new("L", (w * 3, h * 3), 0)
        ImageDraw.Draw(pill).rounded_rectangle((0, 0, w * 3, h * 3), h * 3 // 2, fill=255)
        canvas.paste(Image.new("RGB", (w, h), (4, 46, 32)), (x, cy), pill.resize((w, h), Image.LANCZOS))
        chip = Image.new("L", (d * 3, d * 3), 0)
        ImageDraw.Draw(chip).ellipse((0, 0, d * 3, d * 3), fill=255)
        ccx, ccy = x + padx, cy + (h - d) // 2
        canvas.paste(Image.new("RGB", (d, d), YELLOW), (ccx, ccy), chip.resize((d, d), Image.LANCZOS))
        tick = Image.new("L", (d * 3, d * 3), 0)
        ImageDraw.Draw(tick).line([(d * 0.86, d * 1.56), (d * 1.30, d * 2.0), (d * 2.16, d * 1.06)], fill=255,
                                  width=round(d * 0.30), joint="curve")
        canvas.paste(Image.new("RGB", (d, d), INK), (ccx, ccy), tick.resize((d, d), Image.LANCZOS))
        draw.text((ccx + d + 26, cy + h / 2), text, font=f, fill=WHITE, anchor="lm")


def slide_choose():
    """4. You choose what locks; music can stay on; the picks stay on the iPhone."""
    c = base_stage()
    y = headline(c, "Feeds off. *Music* on.", 150)
    subline(c, "You choose the apps. We never see which.", y + 26)
    shot = cap("store-2026-11-02/choose-apps.png")
    # Apple's app picker, in the phone; the facts float over its lower part.
    sw, top = 1080, 790
    phone(c, shot, (W - sw) // 2, top, sw)
    fact_rows(c, ["Locks only during workouts", "Works offline in the gym"], 2584, size=52, h=106)
    return c


def slide_record():
    """5. Like-for-like progress: same reps, before and after."""
    c = base_stage()
    y = headline(c, "Same reps. *More* weight.", 150)
    subline(c, "Every lift compared like for like.", y + 26)
    shot = cap("store-2026-11-08/record.png")
    sw = 1060
    phone(c, shot, (W - sw) // 2, 1000, sw)
    # The page's own title (Bench press) down to "Same reps · 5".
    box = (40, 180, 1290, 1060)
    cw = W - 2 * 56
    card(c, shot, box, 56, 1118, cw, r=60, op=0.5)
    return c


def slide_month():
    """6. The month: every training day in its split's colour."""
    c = base_stage()
    y = headline(c, "Watch your month *fill up*", 150)
    subline(c, "Every gym day in its split’s color.", y + 26)
    shot = cap("store-2026-11-08/profile.png")
    sw = 1060
    phone(c, shot, (W - sw) // 2, 1000, sw)
    box = (48, 440, 1272, 1125)
    cw = W - 2 * 56
    card(c, shot, box, 56, 1180, cw, r=60, op=0.5)
    return c


def slide_next():
    """7. Home: the split that's up next and one button to start (and lock)."""
    c = base_stage()
    y = headline(c, "*Lock in* for push day", 150)
    subline(c, "Home shows the split that’s up next.", y + 26)
    shot = cap("store-2026-11-08/home.png")
    # The whole Home screen, so its Start workout button is on the slide.
    sw, top = 830, 900
    phone(c, shot, (W - sw) // 2, top, sw)
    # Up next, the split's name and Start workout, lifted out larger where they sit.
    box = (40, 1930, 1290, 2560)
    s = sw / shot.width
    mid = top + (box[1] + box[3]) / 2 * s + 56  # low enough to cover the tab bar's labels
    cw = W - 2 * 56
    ch = round((box[3] - box[1]) * cw / (box[2] - box[0]))
    card(c, shot, box, 56, round(mid - ch / 2), cw, r=60, op=0.5)
    return c


SLIDES = [
    ("1-no-scrolling-between-sets", slide_lock),
    ("2-rest-on-your-lock-screen", slide_rest),
    ("3-log-a-set-in-seconds", slide_log),
    ("4-feeds-off-music-on", slide_choose),
    ("5-same-reps-more-weight", slide_record),
    ("6-watch-your-month-fill-up", slide_month),
    ("7-lock-in-for-push-day", slide_next),
]


HEADLINES = ["No *scrolling* between sets", "Rest on your *Lock Screen*", "Log a set in *seconds*",
             "Feeds off. *Music* on.", "Same reps. *More* weight.", "Watch your month *fill up*",
             "*Lock in* for push day"]


def main():
    global HEAD_SIZE, BG, SLIDE_NO, OUT
    if "--bg" in sys.argv:
        BG = sys.argv[sys.argv.index("--bg") + 1]
    if "--out" in sys.argv:
        OUT = os.path.join(SHOTS, sys.argv[sys.argv.index("--out") + 1])
    # One size for the set: the largest that all but the longest line fit (that one steps down 4 px).
    HEAD_SIZE = sorted(fitted_size(t) for t in HEADLINES)[1]
    print("headline size", HEAD_SIZE)
    only = None
    if "--only" in sys.argv:
        only = {int(v) for v in sys.argv[sys.argv.index("--only") + 1].split(",")}
    names = []
    for i, (name, fn) in enumerate(SLIDES, 1):
        if only and i not in only:
            continue
        SLIDE_NO = i
        img = fn()
        if only:
            os.makedirs(os.path.join(OUT, "6.9"), exist_ok=True)
            img.save(os.path.join(OUT, "6.9", name + ".png"))
        else:
            k.export(img, OUT, name + ".png")
        names.append(name)
        print(name)
    if not only:
        k.overview([os.path.join(OUT, "6.9", n + ".png") for n in names], os.path.join(SHOTS, "store-emerald-overview.png"))


if __name__ == "__main__":
    main()
