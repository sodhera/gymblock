#!/usr/bin/env python3
"""Frames App Store screenshots for the 6.9-inch (1320x2868), 6.3-inch (1206x2622) and 6.1-inch
(1179x2556) slots, one image per slide.

Principles: the caption must read at search-result size (about a sixth of full size), so it is
large, bold and at most two lines. Since 23 Oct 2026 (at the user's request: the blue stage and red
words didn't match the icon) the slides wear the icon's colours: an ink stage (the kettlebell's black) with
white type and one word in the keyhole's emerald, picked that day from ink, emerald and paper. The
phone is Apple's own iPhone 18 Pro Max frame (see BEZEL_DIR), with a drawn phone as a fallback. The same phone size and position on every slide; the phone runs off the
bottom edge, cut above each screen's bottom button.

    python3 scripts/frame-store-screenshots.py
    python3 scripts/frame-store-screenshots.py --custom-pages

Reads screenshots/store-2026-10-20/ (and the newer captures named by path), writes
screenshots/store-final/6.9/, 6.3/ and 6.1/. The 6.3-inch set is the 6.9-inch frame scaled down;
the 6.1-inch one is scaled to its width and trimmed at the foot, where the phone runs off the edge.
--white writes the same set on the white stage (`white-clean`) to screenshots/store-final-white/, with
store-final-white-overview.png (8 Nov 2026, at the user's request, as an alternative to the ink set).
--custom-pages writes the custom product pages (docs/listing.md#custom-product-pages) instead: one
folder per page under screenshots/store-cpp/, numbered in upload order, with an overview strip.
"""
import os
import re
import shutil
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "screenshots", "store-2026-10-20")
OUT = os.path.join(ROOT, "screenshots", "store-final")

W, H = 1320, 2868
# Stages in the icon's colours (paper, ink, emerald). `top`/`bottom` are the stage's gradient, `glow`
# the light behind the phone, then the headline, its one accent word, the second line and the shadow.
STYLES = {
    "paper": dict(top=(245, 243, 239), bottom=(245, 243, 239), glow=((255, 230, 190), 120), text=(20, 20, 22),
                  accent=(15, 154, 107), sub=(110, 108, 104), shadow=((60, 50, 40), 0.28)),
    # The kettlebell's ink, with the keyhole's emerald (brightened to read on black).
    "ink": dict(top=(30, 30, 33), bottom=(8, 8, 9), glow=((15, 154, 107), 70), text=(255, 255, 255),
                accent=(46, 214, 150), sub=(168, 168, 174), shadow=((0, 0, 0), 0.6)),
    # The keyhole's emerald, deepened, with the icon's paper and ink.
    "emerald": dict(top=(16, 128, 90), bottom=(5, 52, 37), glow=((90, 230, 170), 70), text=(255, 255, 255),
                    accent=(20, 20, 22), sub=(196, 236, 218), shadow=((0, 20, 12), 0.5)),
    # Yellow for the eye at search-result size (23 Oct 2026, trial): the gym's black and yellow.
    "ink-yellow": dict(top=(30, 30, 33), bottom=(8, 8, 9), glow=((255, 214, 10), 34), text=(255, 255, 255),
                       accent=(255, 214, 10), sub=(168, 168, 174), shadow=((0, 0, 0), 0.6)),
    # The accent word in ink on a yellow highlighter swipe.
    # Option 1 with the app's green in it (23 Oct 2026): an emerald glow behind the phone ...
    "ink-yellow-glow": dict(top=(30, 30, 33), bottom=(8, 8, 9), glow=((15, 154, 107), 120), text=(255, 255, 255),
                            accent=(255, 214, 10), sub=(168, 168, 174), shadow=((0, 0, 0), 0.6)),
    # ... or the ink fading into deep emerald towards the foot, with the same glow.
    "ink-yellow-deep": dict(top=(26, 28, 27), bottom=(3, 52, 36), glow=((15, 154, 107), 110), text=(255, 255, 255),
                            accent=(255, 214, 10), sub=(168, 168, 174), shadow=((0, 0, 0), 0.6)),
    "ink-highlight": dict(top=(30, 30, 33), bottom=(8, 8, 9), glow=((255, 214, 10), 34), text=(255, 255, 255),
                          accent=(20, 20, 22), highlight=(255, 214, 10), sub=(168, 168, 174), shadow=((0, 0, 0), 0.6)),
    "emerald-yellow": dict(top=(16, 128, 90), bottom=(5, 52, 37), glow=((255, 230, 120), 50), text=(255, 255, 255),
                           accent=(255, 214, 10), sub=(196, 236, 218), shadow=((0, 20, 12), 0.5)),
    # 8 Nov 2026, at the user's request: no green halo and no yellow. Flat ink, white type, one emerald
    # word, the icon's own colours; or the same on white, to match the app's white screens.
    "ink-clean": dict(top=(22, 22, 24), bottom=(10, 10, 11), glow=((0, 0, 0), 0), text=(255, 255, 255),
                      accent=(46, 214, 150), sub=(168, 168, 174), shadow=((0, 0, 0), 0.6)),
    "white-clean": dict(top=(255, 255, 255), bottom=(242, 242, 245), glow=((0, 0, 0), 0), text=(20, 20, 22),
                        accent=(15, 154, 107), sub=(110, 110, 116), shadow=((30, 30, 40), 0.22)),
}
STYLE = "ink-clean"  # 8 Nov 2026 (was ink-yellow-deep, 23 Oct): flat ink, white type, one emerald word

# Apple's own iPhone frame (Bezel-iPhone-18.dmg from developer.apple.com/design/resources, under the
# Apple Design Resources license: used here only to show the app, never redistributed, so the PNGs
# are git-ignored in scripts/bezels/). Its screen opening is 1320 × 2868 at (75, 66), the captures'
# own size, and it carries the Dynamic Island. Without the file, the drawn phone below stands in.
BEZEL_DIR = os.path.join(ROOT, "scripts", "bezels")
BEZEL_COLOUR = "Silver"
BEZEL_SCREEN = (75, 66, 1320, 2868)
RIM = (58, 58, 62)
RIM_EDGE = (128, 128, 134)
BODY = (6, 6, 7)

# Headline, the accent word, second line (none since 23 Oct 2026, at the user's request), capture.
SLIDES = [
    # Slide 1 is real blocking (23 Oct 2026, at the user's request): Sulav's own Home Screen mid-workout,
    # the chosen apps dimmed under Screen Time's hourglass, GymBlock bright, the rest in the Dynamic
    # Island. Status bar cleaned to 9:41 and a full battery (store-2026-11-02/blocked-home-original.png
    # is the untouched capture). Retaken on 2 Nov 2026 with Spotify left open: the 23 Oct one had it locked.
    ("Stop scrolling in the gym", "scrolling", None, "../store-2026-11-02/blocked-home.png"),
    # Slides 2–5 retaken on 8 Nov 2026 on the white app (the paper captures of 20 Oct went with it).
    ("Track your workouts", "workouts", None, "../store-2026-11-08/workout-rest.png"),
    ("Plan your progress", "progress", None, "../store-2026-11-08/home.png"),
    ("Beat your record", "record", None, "../store-2026-11-08/record.png"),
    # Profile with October's calendar (`--demo -storeShots YES -calendarMonthsBack 1 -denseDemo YES`):
    # the sample history six days a week, Sundays off, where November had four days so far.
    ("Keep your streak alive", "streak", None, "../store-2026-11-08/profile.png"),
]

# The custom product pages' own first cards. A capture outside store-2026-10-20 is given as its path
# from screenshots/. `phone` and `popout` are frame()'s: the Lock Screen puts the Live Activity at its
# foot, below the usual cut, so those cards' phone sits 110 px higher and 7% smaller, cut just under
# the activity's Start set button; the two Profile cards lift a different part of the screen.
LOCK = "../store-2026-10-17/rest-lock-screen.png"
NEW_SLIDES = {
    # The shield iOS shows over a blocked app, GymBlock's design rebuilt for the simulator (`-shieldPreview TikTok`).
    "shield": dict(headline="TikTok can wait", accent="wait", sub=None,
                   capture="../store-2026-11-08/shield-tiktok.png"),
    "reels": dict(headline="Block reels between sets", accent="reels", sub="Shorts and feeds too",
                  capture="1-blocking-apps.png"),
    "rest": dict(headline="Rest on your Lock Screen", accent="Rest", sub="No unlocking, no scrolling",
                 capture=LOCK, phone=(900, 1000)),
    "gym-log": dict(headline="Log every set in one tap", accent="set", sub="Last time already filled in",
                    capture="2-workout-rest.png"),
    "pr": dict(headline="Track every PR", accent="PR", sub="Same reps, more weight",
               capture="4-squat-record.png"),
    "doomscrolling": dict(headline="Quit doomscrolling", accent="doomscrolling", sub="Apps locked until Finish",
                          capture="1-blocking-apps.png"),
    "social": dict(headline="Social media off at the gym", accent="Social", sub="Back on when you finish",
                   capture="5-profile-month.png", popout=((72, 1626, 1248, 1928), 1.14)),
    "phone": dict(headline="Phone down. Focus up.", accent="Focus", sub="Rest on the Lock Screen",
                  capture=LOCK, phone=(900, 1000)),
    "splits": dict(headline="Rotate push, pull, legs", accent="legs", sub="Home shows what’s next",
                   capture="../store-2026-10-17/splits-up-next.png"),
    "progress": dict(headline="See if you got stronger", accent="stronger", sub="Like for like, every split",
                     capture="3-home.png"),
    "streak": dict(headline="Never miss gym day", accent="gym", sub="Your streak, week by week",
                   capture="5-profile-month.png", popout=((48, 440, 1272, 1130), 1.1)),
    # Apple's app picker with the feeds ticked and Spotify left open (2 Nov 2026, at the user's request:
    # people took "blocks your apps" to mean all of them, music too). A rebuild (`-pickerPreview YES`).
    "choose": dict(headline="Choose apps to lock", accent="Choose", sub=None,
                   capture="../store-2026-11-02/choose-apps.png"),
}

# The default page: real blocking, which apps (your pick), the shield, then the workout, plans,
# records and the streak.
DEFAULT = [1, "choose", "shield", 2, 3, 4, 5]

# Real cards lifted out of the phone, Bumble-style (23 Oct 2026, at the user's request), only where the
# app has a self-contained card: the box in capture pixels. Drawn as a card of the screen's own colour,
# a little wider than the phone, with padding, round corners and a soft shadow; the phone stays undimmed.
# Behind a card the screen is blurred, so the card is the only sharp thing on the phone (23 Oct 2026).
# A fifth number is the padding (default 44); a sixth, the card's centre on the slide, for a box that sits
# too low on the screen to stay where it is without running off the foot.
CARDS = {
    # The locked apps, as a pane of the Home Screen's own wallpaper (no padding: the wallpaper is the card).
    1: (14, 222, 1165, 812, 0),
    # The 8 Nov 2026 captures (white app):
    2: (40, 370, 1290, 1130),            # Dumbbell curl: a set done, the rest counting down, the next set
    "shield": (60, 560, 1260, 1520),     # "You're mid-workout." and Back to training
    3: (40, 800, 1290, 1460),            # Bench press, +20 kg, the strength line
    4: (40, 500, 1290, 1060),            # before → after, +20 kg
    5: (48, 440, 1272, 1125),            # October: 27 days trained, every split twice a week, one dot per split colour
    "choose": (60, 842, 1260, 2022, 44, 1880),  # Social and Entertainment open: feeds ticked, Spotify not
}
USE_CARDS = True

# Upload order per page: a NEW_SLIDES key, or a slide number from SLIDES. Most pages open with the
# welcome (slide 1) and then their own card (20 Oct 2026, at the user's request); PR tracker, Rest
# timer and Splits, searched for one feature, open with theirs. No page shows a capture twice.
PAGES = {
    "workout-tracker": [1, 2, 4, 3, 5],
    "gym-log": [1, "gym-log", 4, 3, 5],
    "pr-tracker": ["pr", 3, 2, 1, 5],
    "rest-timer": ["rest", 2, 1, 4, 5],
    "reels-blocker": [1, "reels", 2, 4, 5],
    "doomscrolling": [1, "doomscrolling", "rest", 2, 4],
    "social-media": [1, "social", "rest", 2, 4],
    "phone-focus": [1, "phone", 2, 4, 5],
    "splits": ["splits", 3, 2, 4, 5],
    "progress": [1, "progress", 4, 2, 5],
    "streak": [1, "streak", 3, 2, 4],
}
CPP_OUT = os.path.join(ROOT, "screenshots", "store-cpp")

SF = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight):
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_name(weight)
    return f


HEAD = font(196, "Bold")
SUB = font(120, "Semibold")

# Phone geometry, in an iPhone 17 Pro's proportions: the screen keeps the capture's shape, a thin
# black bezel (about 2% of the width) inside a slim titanium rim, the side buttons standing proud.
SCREEN_W = 1080
SCREEN_H = round(SCREEN_W * 2868 / 1320)
BEZEL = 22
RIM_W = 11
PHONE_W = SCREEN_W + 2 * (BEZEL + RIM_W)
PHONE_TOP = 1010
SCREEN_R = round(SCREEN_W * 0.137)
PHONE_R = SCREEN_R + BEZEL + RIM_W
SS = 3  # shapes are drawn this many times larger, then scaled down: smooth, anti-aliased edges


def squircle(w, h, r, n=5.0):
    """A rounded rectangle with continuous corners, as Apple draws them: each corner a superellipse
    a little larger than the circular radius it replaces, so the curve eases in instead of starting abruptly."""
    import math
    r = min(r * 1.22, w / 2, h / 2)
    pts = []
    for cx, cy, a0 in ((w - r, r, -90), (w - r, h - r, 0), (r, h - r, 90), (r, r, 180)):
        for i in range(65):
            t = math.radians(a0 + 90 * i / 64)
            c, s_ = math.cos(t), math.sin(t)
            pts.append((cx + r * math.copysign(abs(c) ** (2 / n), c), cy + r * math.copysign(abs(s_) ** (2 / n), s_)))
    return pts


def shape_mask(w, h, r):
    """An anti-aliased squircle mask, w × h."""
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).polygon(squircle(w * SS, h * SS, r * SS), fill=255)
    return m.resize((w, h), Image.LANCZOS)


def head_font(headline, draw):
    """The headline keeps its size unless a word is wider than the slide or it needs a third line;
    then it steps down until it sits inside wider margins (80 px a side), so a long word doesn't
    touch the edges. Returns the font and the lines."""
    size, max_w = 196, W - 80
    while True:
        f = HEAD if size == 196 else font(size, "Bold")
        lines = wrap(headline.split(), max_w, draw, f)
        if len(lines) <= 2 and all(draw.textlength(" ".join(l), font=f) <= max_w for l in lines):
            return f, lines
        max_w = W - 160
        size -= 2
        assert size >= 176, f"{headline!r} doesn't fit on two lines; shorten it"


def sub_font(sub, draw):
    """The second line keeps its size unless it would run past the margins; then it steps down
    only as far as it needs to."""
    size = 120
    while draw.textlength(sub, font=font(size, "Semibold")) > W - 160:
        size -= 2
    assert size >= 100, f"{sub!r} needs {size} pt to fit; shorten it"
    return SUB if size == 120 else font(size, "Semibold")


def check_fits(headline, sub):
    """Fail loudly instead of drawing a headline past the edge or onto a third line."""
    draw = ImageDraw.Draw(Image.new("RGB", (W, H)))
    head_font(headline, draw)
    if sub:
        sub_font(sub, draw)


def wrap(words, max_w, draw, f=HEAD):
    """Greedy wrap, then rebalance two lines so neither is a lone short word."""
    lines, line = [], []
    for w in words:
        trial = " ".join(line + [w])
        if line and draw.textlength(trial, font=f) > max_w:
            lines.append(line)
            line = [w]
        else:
            line.append(w)
    lines.append(line)
    if len(lines) == 2:
        best = None
        flat = lines[0] + lines[1]
        for i in range(1, len(flat)):
            a, b = " ".join(flat[:i]), " ".join(flat[i:])
            wa, wb = draw.textlength(a, font=f), draw.textlength(b, font=f)
            if max(wa, wb) <= max_w and (best is None or abs(wa - wb) < best[0]):
                best = (abs(wa - wb), [flat[:i], flat[i:]])
        if best:
            lines = best[1]
    return lines


def draw_line(draw, words, accent, y, f=HEAD):
    text = " ".join(words)
    x = (W - draw.textlength(text, font=f)) / 2
    st = STYLES[STYLE]
    for i, w in enumerate(words):
        piece = w + (" " if i < len(words) - 1 else "")
        is_accent = w.strip(".,?") == accent
        if is_accent and "highlight" in st:
            # A marker swipe behind the word: a little wider than it, over its lower three quarters.
            box = draw.textbbox((x, y), w, font=f)
            pad = round(f.size * 0.09)
            draw.rounded_rectangle((box[0] - pad, box[1] - pad * 0.6, box[2] + pad, box[3] + pad * 0.7), round(f.size * 0.08),
                                   fill=st["highlight"])
        draw.text((x, y), piece, font=f, fill=st["accent"] if is_accent else st["text"])
        x += draw.textlength(piece, font=f)


_SCREEN_MASKS = {}


def screen_mask(bezel_path, w, h):
    """The frame's own screen shape, w × h: its transparent opening, traced by filling from the
    middle of the screen, so the capture's square corners never show past the phone's rounded ones."""
    key = (bezel_path, w, h)
    if key not in _SCREEN_MASKS:
        x0, y0, sw0, sh0 = BEZEL_SCREEN
        alpha = Image.open(bezel_path).getchannel("A").crop((x0, y0, x0 + sw0, y0 + sh0))
        opening = alpha.point(lambda v: 255 if v < 250 else 0)
        ImageDraw.floodfill(opening, (sw0 // 2, sh0 // 2), 128)
        _SCREEN_MASKS[key] = opening.point(lambda v: 255 if v == 128 else 0).resize((w, h), Image.LANCZOS)
    return _SCREEN_MASKS[key]


def frame(headline, accent, sub, capture, phone=None, popout=None, card=None):
    """`phone` = (top, screen width) moves and scales the phone for a capture whose subject sits
    lower than the cut, such as a Live Activity at the foot of the Lock Screen. `popout` = (box in
    capture pixels, scale) lifts that part of the screen out of the phone, enlarged, where it sits."""
    phone_top, sw = phone or (PHONE_TOP, SCREEN_W)
    k = sw / SCREEN_W
    sh = round(sw * 2868 / 1320)
    bezel, rim = round(BEZEL * k), round(RIM_W * k)
    pw = sw + 2 * (bezel + rim)
    sr = round(sw * 0.128)
    pr = sr + bezel + rim
    # The stage: a vertical gradient and a glow behind the top of the phone.
    st = STYLES[STYLE]
    canvas = Image.new("RGB", (W, H))
    grad = ImageDraw.Draw(canvas)
    for y in range(H):
        t = y / (H - 1)
        grad.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(st["top"], st["bottom"])))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.5 - 650, phone_top - 300, W * 0.5 + 650, phone_top + 800), fill=st["glow"][1])
    glow = glow.filter(ImageFilter.GaussianBlur(260))
    canvas.paste(Image.new("RGB", (W, H), st["glow"][0]), (0, 0), glow)

    draw = ImageDraw.Draw(canvas)
    hf, lines = head_font(headline, draw)
    line_h = round(214 * hf.size / 196)
    block_h = len(lines) * line_h + (46 + 140 if sub else 0)
    y = (phone_top - 50 - block_h) / 2 + 10
    for line in lines:
        draw_line(draw, line, accent, y, hf)
        y += line_h
    if sub:
        y += 46
        sf = sub_font(sub, draw)
        draw.text(((W - draw.textlength(sub, font=sf)) / 2, y), sub, font=sf, fill=st["sub"])

    full = Image.open(os.path.join(SRC, capture)).convert("RGB")
    shot = full.resize((sw, sh), Image.LANCZOS)
    bezel_path = os.path.join(BEZEL_DIR, f"iPhone 18 Pro Max - {BEZEL_COLOUR} - Portrait.png")
    if os.path.exists(bezel_path):
        # Apple's frame, scaled so its screen is `sw` wide, its top at `phone_top`: the capture behind,
        # the frame (rim, buttons, corners, island) over it, and a soft shadow from its outline.
        frame_img = Image.open(bezel_path).convert("RGBA")
        kb = sw / BEZEL_SCREEN[2]
        fw, fh = round(frame_img.width * kb), round(frame_img.height * kb)
        frame_img = frame_img.resize((fw, fh), Image.LANCZOS)
        fx, fy = (W - fw) // 2, phone_top
        sx, sy = fx + round(BEZEL_SCREEN[0] * kb), fy + round(BEZEL_SCREEN[1] * kb)
        shadow = Image.new("L", (W, H), 0)
        shadow.paste(frame_img.getchannel("A"), (fx, fy + 36))
        canvas.paste(Image.new("RGB", (W, H), st["shadow"][0]), (0, 0), shadow.filter(ImageFilter.GaussianBlur(48)).point(lambda v: v * st["shadow"][1]))
        screen = screen_mask(bezel_path, sw, sh)
        canvas.paste(shot, (sx, sy), screen)
        canvas.paste(frame_img, (fx, fy), frame_img)
    else:
        px = (W - pw) // 2
        ph = H + 600 - phone_top  # runs off the foot of the slide
        # A soft shadow on the paper, then the side buttons (the rim covers their inner edge): action and
        # volume on the left, the side button on the right.
        shadow = Image.new("L", (W, H), 0)
        shadow.paste(shape_mask(pw, ph, pr), (px, phone_top + 36))
        canvas.paste(Image.new("RGB", (W, H), st["shadow"][0]), (0, 0), shadow.filter(ImageFilter.GaussianBlur(48)).point(lambda v: v * st["shadow"][1]))
        for side, top, height in (("l", 300, 110), ("l", 470, 200), ("l", 700, 200), ("r", 560, 300)):
            top, height = round(top * k), round(height * k)
            bw, bx = round(14 * k), (px - round(6 * k) if side == "l" else px + pw - round(8 * k))
            canvas.paste(Image.new("RGB", (bw, height), RIM), (bx, phone_top + top), shape_mask(bw, height, bw / 2))
        # Rim with a lighter outer edge, then the black bezel, then the screen, each anti-aliased.
        canvas.paste(Image.new("RGB", (pw, ph), RIM_EDGE), (px, phone_top), shape_mask(pw, ph, pr))
        canvas.paste(Image.new("RGB", (pw - 6, ph), RIM), (px + 3, phone_top + 3), shape_mask(pw - 6, ph, pr - 3))
        canvas.paste(Image.new("RGB", (pw - 2 * rim, ph), BODY), (px + rim, phone_top + rim), shape_mask(pw - 2 * rim, ph, pr - rim))

        sx, sy = px + rim + bezel, phone_top + rim + bezel
        screen = shape_mask(sw, sh, sr)
        canvas.paste(shot, (sx, sy), screen)
        # The Dynamic Island, for captures that don't carry one (older simulators leave it out). Measured on
        # an iPhone 17 Pro Max capture: 28.5% of the screen's width, 8.3% tall, 3.2% from the top.
        iw, ih, it = round(sw * 0.2848), round(sw * 0.0833), round(sw * 0.0318)
        if sum(full.getpixel((full.width // 2, round(full.width * 0.0318 + full.width * 0.0833 / 2)))) > 60:
            # A true pill (round ends), drawn large and scaled down so its edge is smooth.
            pill = Image.new("L", (iw * SS, ih * SS), 0)
            ImageDraw.Draw(pill).rounded_rectangle((0, 0, iw * SS - 1, ih * SS - 1), ih * SS / 2, fill=255)
            canvas.paste(Image.new("RGB", (iw, ih), (0, 0, 0)), (sx + (sw - iw) // 2, sy + it), pill.resize((iw, ih), Image.LANCZOS))

    if popout:
        (x0, y0, x1, y1), scale = popout
        k_cap = sw / full.width
        # No wider than the phone itself, so the card overhangs the screen but stays on the slide.
        scale = min(scale, (W - 120) / ((x1 - x0) * k_cap))
        cw, ch = round((x1 - x0) * k_cap * scale), round((y1 - y0) * k_cap * scale)
        # The rest of the screen dims, so the lifted card is the brightest thing on the phone.
        canvas.paste(Image.new("RGB", (sw, sh), (0, 0, 0)), (sx, sy), screen.point(lambda v: round(v * 0.42)))
        card = full.crop((x0, y0, x1, y1)).resize((cw, ch), Image.LANCZOS)
        cx, cy = round((W - cw) / 2), round(sy + (y0 + y1) / 2 * k_cap - ch / 2)
        r = round(40 * scale)
        shadow = Image.new("L", (W, H), 0)
        ImageDraw.Draw(shadow).rounded_rectangle((cx, cy + 30, cx + cw, cy + ch + 30), r, fill=round(255 * min(1, st["shadow"][1] + 0.2)))
        canvas.paste(Image.new("RGB", (W, H), (0, 0, 0)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(40)))
        canvas.paste(card, (cx, cy), shape_mask(cw, ch, r / 1.22))  # anti-aliased, continuous corners
    if card:
        x0, y0, x1, y1 = card[:4]
        k_cap = sw / full.width
        cw, pad = W - 100, (card[4] if len(card) > 4 else 44)
        inner_w = cw - 2 * pad
        inner_h = round((y1 - y0) * inner_w / (x1 - x0))
        ch = inner_h + 2 * pad
        sheet = Image.new("RGB", (cw, ch), full.getpixel((x0 + 6, y0 + 6)))
        sheet.paste(full.crop((x0, y0, x1, y1)).resize((inner_w, inner_h), Image.LANCZOS), (pad, pad))
        mid = card[5] if len(card) > 5 else sy + (y0 + y1) / 2 * k_cap
        cx, cy = (W - cw) // 2, round(mid - ch / 2)
        # Blur below the status bar only: blurring it smeared the Dynamic Island into a dark halo.
        below = screen.copy()
        ImageDraw.Draw(below).rectangle((0, 0, sw, round(sh * 0.066)), fill=0)
        canvas.paste(shot.filter(ImageFilter.GaussianBlur(16)), (sx, sy), below.filter(ImageFilter.GaussianBlur(6)))
        shadow = Image.new("L", (W, H), 0)
        shadow.paste(shape_mask(cw, ch, 46), (cx, cy + 34))
        canvas.paste(Image.new("RGB", (W, H), (0, 0, 0)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(46)).point(lambda v: round(v * 0.55)))
        canvas.paste(sheet, (cx, cy), shape_mask(cw, ch, 46))
    return canvas


SIZES = {"6.9": (1320, 2868), "6.3": (1206, 2622), "6.1": (1179, 2556)}


def save(slide, folder, name):
    for slot, (w, h) in SIZES.items():
        os.makedirs(os.path.join(folder, slot), exist_ok=True)
        if (w, h) == (W, H):
            out = slide
        else:
            # Scale to the slot's width; the 6.1-inch slot is a touch shorter, so trim its foot.
            out = slide.resize((w, round(H * w / W)), Image.LANCZOS).crop((0, 0, w, h))
        out.save(os.path.join(folder, slot, name))


def slug(headline):
    return re.sub(r"[^a-z0-9]+", "-", headline.lower()).strip("-")


def main(out=OUT, overview_path=os.path.join(ROOT, "screenshots", "store-final-overview.png")):
    shutil.rmtree(out, ignore_errors=True)
    for i, key in enumerate(DEFAULT, 1):
        slide = NEW_SLIDES.get(key) or dict(zip(("headline", "accent", "sub", "capture"), SLIDES[key - 1]))
        if USE_CARDS and key in CARDS:
            slide = dict(slide, card=CARDS[key])
        check_fits(slide["headline"], slide["sub"])
        name = f"{i}-{slug(slide['headline'])}.png"
        save(frame(**slide), out, name)
        print(name)
    overview(out, overview_path)


def overview(folder, out=None):
    """One strip per page, the way the set reads left to right: store-final-overview.png for the
    default set, <page>-overview.png for each custom product page."""
    shots = [Image.open(os.path.join(folder, "6.9", n)) for n in sorted(os.listdir(os.path.join(folder, "6.9")))]
    w, h, gap = 446, round(446 * H / W), 24
    strip = Image.new("RGB", (len(shots) * (w + gap) + gap, h + 2 * gap), (242, 242, 244))
    for i, im in enumerate(shots):
        strip.paste(im.resize((w, h), Image.LANCZOS), (gap + i * (w + gap), gap))
    strip.save(out or os.path.join(CPP_OUT, f"{os.path.basename(folder)}-overview.png"))


def custom_pages():
    drawn = {}
    shutil.rmtree(CPP_OUT, ignore_errors=True)
    for page, order in PAGES.items():
        folder = os.path.join(CPP_OUT, page)
        for i, key in enumerate(order, 1):
            slide = NEW_SLIDES.get(key) or dict(zip(("headline", "accent", "sub", "capture"), SLIDES[key - 1]))
            if key not in drawn:
                check_fits(slide["headline"], slide["sub"])
                drawn[key] = frame(**slide)
            name = f"{i}-{slug(slide['headline'])}.png"
            save(drawn[key], folder, name)
            print(f"{page}/{name}")
        overview(folder)


if __name__ == "__main__":
    if "--custom-pages" in sys.argv:
        custom_pages()
    elif "--white" in sys.argv:
        STYLE = "white-clean"
        main(os.path.join(ROOT, "screenshots", "store-final-white"),
             os.path.join(ROOT, "screenshots", "store-final-white-overview.png"))
    else:
        main()
