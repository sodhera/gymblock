#!/usr/bin/env python3
"""Frames App Store screenshots for the 6.9-inch (1320x2868) and 6.3-inch (1206x2622) slots.

Principles: the caption must read at search-result size (about a sixth of full size), so it is
large, bold and at most two lines; one word per headline in red and no other colour; a deep blue
stage so the app's light screens stand out; a thick phone with a titanium rim and side buttons so the
device reads at a glance; the same phone size and position on every slide; the phone runs off the
bottom edge, cut above each screen's bottom button.

    python3 scripts/frame-store-screenshots.py
    python3 scripts/frame-store-screenshots.py --custom-pages

Reads screenshots/store-2026-10-13/, writes screenshots/store-final/6.9/ and store-final/6.3/.
Both slots have the same shape, so the 6.3-inch set is the 6.9-inch frame scaled down.
--custom-pages writes the custom product pages (docs/listing.md#custom-product-pages) instead: one
folder per page under screenshots/store-cpp/, numbered in upload order, with an overview strip.
"""
import os
import shutil
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "screenshots", "store-2026-10-13")
OUT = os.path.join(ROOT, "screenshots", "store-final")

W, H = 1320, 2868
STAGE_TOP = (20, 44, 92)
STAGE_BOTTOM = (7, 17, 40)
TEXT = (255, 255, 255)
SECONDARY = (184, 202, 232)
RED = (255, 77, 66)
GLOW = (58, 120, 255)
RIM = (92, 92, 98)
RIM_EDGE = (140, 140, 146)
BODY = (8, 8, 9)

# Headline, the red word, second line, capture.
SLIDES = [
    ("Stop scrolling in the gym", "scrolling", "Block apps", "1-blocking-apps.png"),
    ("Track your workouts", "workouts", "Time your rests", "2-workout-rest.png"),
    ("Plan your progress", "progress", "Stay motivated", "3-home.png"),
    ("Beat your record", "record", None, "4-squat-record.png"),
    ("Keep your streak alive", "streak", None, "5-profile-month.png"),
]

# The custom product pages' own first cards, in the same shape as SLIDES. A capture outside
# store-2026-10-13 is given as its path from screenshots/. The Lock Screen puts the Live Activity
# at its foot, below the usual cut, so that card's phone sits 110 px higher and 7% smaller, cut just
# under the activity's Start set button.
NEW_SLIDES = {
    "reels": ("Block reels between sets", "reels", "Shorts and feeds too", "1-blocking-apps.png"),
    "rest": ("Rest on your Lock Screen", "Rest", "No unlocking, no scrolling",
             "../store-2026-10-17/rest-lock-screen.png", (900, 1000)),
}

# Upload order per page: a NEW_SLIDES key, or a slide number from SLIDES.
PAGES = {
    "workout-log": [2, 4, 3, 1, 5],
    "reels-blocker": ["reels", 2, 4, 3, 5],
    "rest-timer": ["rest", 2, 1, 4, 5],
}
CPP_OUT = os.path.join(ROOT, "screenshots", "store-cpp")

SF = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight):
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_name(weight)
    return f


HEAD = font(196, "Bold")
SUB = font(120, "Semibold")

# Phone geometry: the screen keeps the capture's proportions; a thick black bezel inside a
# titanium rim, with the side buttons standing proud of the rim.
SCREEN_W = 1080
SCREEN_H = round(SCREEN_W * 2868 / 1320)
BEZEL = 40
RIM_W = 12
PHONE_W = SCREEN_W + 2 * (BEZEL + RIM_W)
PHONE_TOP = 1010
SCREEN_R = round(SCREEN_W * 0.128)
PHONE_R = SCREEN_R + BEZEL + RIM_W


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
    lines = wrap(headline.split(), W - 80, draw)
    assert len(lines) <= 2, f"{headline!r} wraps to {len(lines)} lines"
    for line in lines:
        width = draw.textlength(" ".join(line), font=HEAD)
        assert width <= W - 80, f"{' '.join(line)!r} is {width:.0f}px wide"
    if sub:
        sub_font(sub, draw)


def wrap(words, max_w, draw):
    """Greedy wrap, then rebalance two lines so neither is a lone short word."""
    lines, line = [], []
    for w in words:
        trial = " ".join(line + [w])
        if line and draw.textlength(trial, font=HEAD) > max_w:
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
            wa, wb = draw.textlength(a, font=HEAD), draw.textlength(b, font=HEAD)
            if max(wa, wb) <= max_w and (best is None or abs(wa - wb) < best[0]):
                best = (abs(wa - wb), [flat[:i], flat[i:]])
        if best:
            lines = best[1]
    return lines


def draw_line(draw, words, accent, y):
    text = " ".join(words)
    x = (W - draw.textlength(text, font=HEAD)) / 2
    for i, w in enumerate(words):
        piece = w + (" " if i < len(words) - 1 else "")
        draw.text((x, y), piece, font=HEAD, fill=RED if w.strip(".,") == accent else TEXT)
        x += draw.textlength(piece, font=HEAD)


def frame(headline, accent, sub, capture, phone=None):
    """`phone` = (top, screen width) moves and scales the phone for a capture whose subject sits
    lower than the cut, such as a Live Activity at the foot of the Lock Screen."""
    phone_top, sw = phone or (PHONE_TOP, SCREEN_W)
    k = sw / SCREEN_W
    sh = round(sw * 2868 / 1320)
    bezel, rim = round(BEZEL * k), round(RIM_W * k)
    pw = sw + 2 * (bezel + rim)
    sr = round(sw * 0.128)
    pr = sr + bezel + rim
    # Deep blue stage: a vertical gradient and a brighter blue glow behind the top of the phone.
    canvas = Image.new("RGB", (W, H))
    grad = ImageDraw.Draw(canvas)
    for y in range(H):
        t = y / (H - 1)
        grad.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(STAGE_TOP, STAGE_BOTTOM)))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.5 - 700, phone_top - 260, W * 0.5 + 700, phone_top + 900), fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(240))
    canvas.paste(Image.new("RGB", (W, H), GLOW), (0, 0), glow)

    draw = ImageDraw.Draw(canvas)
    lines = wrap(headline.split(), W - 80, draw)
    line_h = 214
    block_h = len(lines) * line_h + (46 + 140 if sub else 0)
    y = (phone_top - 50 - block_h) / 2 + 10
    for line in lines:
        draw_line(draw, line, accent, y)
        y += line_h
    if sub:
        y += 46
        sf = sub_font(sub, draw)
        draw.text(((W - draw.textlength(sub, font=sf)) / 2, y), sub, font=sf, fill=SECONDARY)

    px = (W - pw) // 2
    bottom = H + 600
    # Side buttons first, so the rim covers their inner edge: action and volume on the left, power on the right.
    for side, top, height in (("l", 300, 110), ("l", 470, 200), ("l", 700, 200), ("r", 560, 300)):
        top, height = round(top * k), round(height * k)
        x0 = px - 9 if side == "l" else px + pw - 8
        draw.rounded_rectangle((x0, phone_top + top, x0 + 17, phone_top + top + height), 6, fill=RIM)
    # Rim with a lighter outer edge, then the black bezel, then the screen.
    draw.rounded_rectangle((px, phone_top, px + pw, bottom), pr, fill=RIM_EDGE)
    draw.rounded_rectangle((px + 3, phone_top + 3, px + pw - 3, bottom), pr - 3, fill=RIM)
    draw.rounded_rectangle((px + rim, phone_top + rim, px + pw - rim, bottom), pr - rim, fill=BODY)

    shot = Image.open(os.path.join(SRC, capture)).convert("RGB").resize((sw, sh), Image.LANCZOS)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), sr, fill=255)
    sx, sy = px + rim + bezel, phone_top + rim + bezel
    canvas.paste(shot, (sx, sy), mask)

    iw, ih = round(sw * 0.213), round(sh * 0.0375)
    iy = sy + round(sh * 0.0150)
    draw.rounded_rectangle((sx + (sw - iw) / 2, iy, sx + (sw + iw) / 2, iy + ih), ih / 2, fill=(0, 0, 0))
    return canvas


SIZES = {"6.9": (1320, 2868), "6.3": (1206, 2622)}


def save(slide, folder, name):
    for slot, size in SIZES.items():
        os.makedirs(os.path.join(folder, slot), exist_ok=True)
        (slide if size == (W, H) else slide.resize(size, Image.LANCZOS)).save(os.path.join(folder, slot, name))


def slug(headline):
    return headline.lower().replace(" ", "-")


def main():
    for i, (headline, accent, sub, capture) in enumerate(SLIDES, 1):
        check_fits(headline, sub)
        name = f"{i}-{slug(headline)}.png"
        save(frame(headline, accent, sub, capture), OUT, name)
        print(name)


def overview(folder):
    """One strip per page, the way the set reads left to right, as in store-final-overview.png."""
    shots = [Image.open(os.path.join(folder, "6.9", n)) for n in sorted(os.listdir(os.path.join(folder, "6.9")))]
    w, h, gap = 446, round(446 * H / W), 24
    strip = Image.new("RGB", (len(shots) * (w + gap) + gap, h + 2 * gap), (242, 242, 244))
    for i, im in enumerate(shots):
        strip.paste(im.resize((w, h), Image.LANCZOS), (gap + i * (w + gap), gap))
    strip.save(os.path.join(CPP_OUT, f"{os.path.basename(folder)}-overview.png"))


def custom_pages():
    drawn = {}
    for page, order in PAGES.items():
        folder = os.path.join(CPP_OUT, page)
        shutil.rmtree(folder, ignore_errors=True)
        for i, key in enumerate(order, 1):
            slide = NEW_SLIDES[key] if key in NEW_SLIDES else SLIDES[key - 1]
            if key not in drawn:
                check_fits(slide[0], slide[2])
                drawn[key] = frame(*slide)
            name = f"{i}-{slug(slide[0])}.png"
            save(drawn[key], folder, name)
            print(f"{page}/{name}")
        overview(folder)


if __name__ == "__main__":
    custom_pages() if "--custom-pages" in sys.argv else main()
