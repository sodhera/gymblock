#!/usr/bin/env python3
"""Frames App Store screenshots for the 6.9-inch slot (1320x2868).

Principles: the caption must read at search-result size (about a sixth of full size), so it is
large, bold and at most two lines; one word per headline in red and no other colour; a deep blue
stage so the app's light screens stand out; a thick phone with a titanium rim and side buttons so the
device reads at a glance; the same phone size and position on every slide; the phone runs off the
bottom edge, cut above each screen's bottom button.

    python3 scripts/frame-store-screenshots.py

Reads screenshots/store-2026-10-12/, writes screenshots/store-final/.
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "screenshots", "store-2026-10-12")
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


def frame(headline, accent, sub, capture):
    # Deep blue stage: a vertical gradient and a brighter blue glow behind the top of the phone.
    canvas = Image.new("RGB", (W, H))
    grad = ImageDraw.Draw(canvas)
    for y in range(H):
        t = y / (H - 1)
        grad.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(STAGE_TOP, STAGE_BOTTOM)))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.5 - 700, PHONE_TOP - 260, W * 0.5 + 700, PHONE_TOP + 900), fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(240))
    canvas.paste(Image.new("RGB", (W, H), GLOW), (0, 0), glow)

    draw = ImageDraw.Draw(canvas)
    lines = wrap(headline.split(), W - 80, draw)
    line_h = 214
    block_h = len(lines) * line_h + (46 + 140 if sub else 0)
    y = (PHONE_TOP - 50 - block_h) / 2 + 10
    for line in lines:
        draw_line(draw, line, accent, y)
        y += line_h
    if sub:
        y += 46
        draw.text(((W - draw.textlength(sub, font=SUB)) / 2, y), sub, font=SUB, fill=SECONDARY)

    px = (W - PHONE_W) // 2
    bottom = H + 600
    # Side buttons first, so the rim covers their inner edge: action and volume on the left, power on the right.
    for side, top, height in (("l", 300, 110), ("l", 470, 200), ("l", 700, 200), ("r", 560, 300)):
        x0 = px - 9 if side == "l" else px + PHONE_W - 8
        draw.rounded_rectangle((x0, PHONE_TOP + top, x0 + 17, PHONE_TOP + top + height), 6, fill=RIM)
    # Rim with a lighter outer edge, then the black bezel, then the screen.
    draw.rounded_rectangle((px, PHONE_TOP, px + PHONE_W, bottom), PHONE_R, fill=RIM_EDGE)
    draw.rounded_rectangle((px + 3, PHONE_TOP + 3, px + PHONE_W - 3, bottom), PHONE_R - 3, fill=RIM)
    draw.rounded_rectangle((px + RIM_W, PHONE_TOP + RIM_W, px + PHONE_W - RIM_W, bottom), PHONE_R - RIM_W, fill=BODY)

    shot = Image.open(os.path.join(SRC, capture)).convert("RGB").resize((SCREEN_W, SCREEN_H), Image.LANCZOS)
    mask = Image.new("L", (SCREEN_W, SCREEN_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SCREEN_W, SCREEN_H), SCREEN_R, fill=255)
    sx, sy = px + RIM_W + BEZEL, PHONE_TOP + RIM_W + BEZEL
    canvas.paste(shot, (sx, sy), mask)

    iw, ih = round(SCREEN_W * 0.213), round(SCREEN_H * 0.0375)
    iy = sy + round(SCREEN_H * 0.0150)
    draw.rounded_rectangle((sx + (SCREEN_W - iw) / 2, iy, sx + (SCREEN_W + iw) / 2, iy + ih), ih / 2, fill=(0, 0, 0))
    return canvas


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, (headline, accent, sub, capture) in enumerate(SLIDES, 1):
        name = f"{i}-{headline.lower().replace(' ', '-')}.png"
        frame(headline, accent, sub, capture).save(os.path.join(OUT, name))
        print(name)

if __name__ == "__main__":
    main()
