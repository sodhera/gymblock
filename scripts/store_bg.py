"""Emerald stages for the App Store slides (9 Nov 2026): never a flat colour.

aurora  - deep emerald with flowing bands of mint and green light and fine light lines, drawn as
          one panorama across the whole set, so neighbouring slides join up in the search row.
mark    - emerald with the brand's kettlebell drawn huge and tone-on-tone behind the phone, its
          keyhole glowing yellow (the highlight colour).
spot    - a dark emerald room: light beams from above onto the phone, haze, and a glow beneath it.

All are drawn small and blurred, then scaled up (smooth light needs no detail), with fine grain on
top at full size so the colour doesn't band.
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H = 1320, 2868
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON = os.path.join(ROOT, "GymBlock", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
S = 6  # draw the light at 1/6 size


def _vgrad(w, h, top, bottom):
    g = Image.linear_gradient("L").resize((w, h))
    return Image.composite(Image.new("RGB", (w, h), bottom), Image.new("RGB", (w, h), top), g)


def grain(img, amount=8, seed=0):
    rnd = random.Random(seed)
    w, h = img.size
    small = Image.new("L", (w // 2, h // 2))
    small.putdata([128 + rnd.randint(-amount, amount) for _ in range((w // 2) * (h // 2))])
    noise = small.resize((w, h), Image.BILINEAR).convert("RGB")
    return ImageChops.add(img, ImageChops.subtract(noise, Image.new("RGB", (w, h), (128, 128, 128))), 1, 0)


def _light(base, mask, colour, alpha):
    """Screen-blends `colour` over base through `mask` (L) at `alpha`."""
    lit = ImageChops.screen(base, Image.new("RGB", base.size, colour))
    return Image.composite(lit, base, mask.point(lambda v: round(v * alpha)))


# ---------- aurora ----------

_PANO = {}


def _wave(x, amp, wl, phase, y0):
    return y0 + amp * math.sin(2 * math.pi * x / wl + phase) + amp * 0.35 * math.sin(2 * math.pi * x / (wl * 0.47) + phase * 1.7)


def aurora_panorama(n):
    if n in _PANO:
        return _PANO[n]
    pw, ph = n * W // S, H // S
    img = _vgrad(pw, ph, (10, 104, 74), (4, 50, 35))
    # Bands of light: (colour, alpha, thickness px at full size, amplitude, wavelength, phase, centre y)
    bands = [
        ((46, 226, 156), 0.70, 420, 0.10 * H, 2.6 * W, 0.4, 0.70 * H),
        ((18, 180, 128), 0.60, 520, 0.12 * H, 3.4 * W, 2.2, 0.36 * H),
        ((190, 236, 96), 0.28, 220, 0.08 * H, 2.1 * W, 4.1, 0.86 * H),
        ((120, 245, 200), 0.35, 260, 0.06 * H, 1.7 * W, 1.0, 0.18 * H),
    ]
    for colour, alpha, thick, amp, wl, phase, y0 in bands:
        m = Image.new("L", (pw, ph), 0)
        d = ImageDraw.Draw(m)
        pts = [(x, _wave(x * S, amp, wl, phase, y0) / S) for x in range(-20, pw + 20, 4)]
        d.line(pts, fill=255, width=max(2, round(thick / S)), joint="curve")
        img = _light(img, m.filter(ImageFilter.GaussianBlur(thick / S * 0.9)), colour, alpha)
    # A darker river between the bands, for depth.
    m = Image.new("L", (pw, ph), 0)
    pts = [(x, _wave(x * S, 0.09 * H, 3.0 * W, 3.3, 0.53 * H) / S) for x in range(-20, pw + 20, 4)]
    ImageDraw.Draw(m).line(pts, fill=255, width=round(360 / S), joint="curve")
    img = Image.composite(Image.new("RGB", (pw, ph), (2, 30, 21)), img, m.filter(ImageFilter.GaussianBlur(40)).point(lambda v: round(v * 0.55)))
    _PANO[n] = img
    return img


def aurora(slide_no, n=7):
    pano = aurora_panorama(n)
    x0 = (slide_no - 1) * W // S
    piece = pano.crop((x0, 0, x0 + W // S, H // S)).resize((W, H), Image.BICUBIC)
    # Fine light lines riding the bands, drawn at full size (like the iOS wallpaper's ribbons).
    lines = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(lines)
    off = (slide_no - 1) * W
    for amp, wl, phase, y0, a in ((0.10 * H, 2.6 * W, 0.4, 0.70 * H, 150), (0.10 * H, 2.6 * W, 0.55, 0.735 * H, 90),
                                  (0.12 * H, 3.4 * W, 2.2, 0.36 * H, 110), (0.12 * H, 3.4 * W, 2.32, 0.395 * H, 70)):
        pts = [(x, _wave(x + off, amp, wl, phase, y0)) for x in range(-10, W + 10, 6)]
        d.line(pts, fill=a, width=3, joint="curve")
    piece = _light(piece, lines.filter(ImageFilter.GaussianBlur(1.2)), (200, 255, 230), 0.8)
    return grain(piece, 7, slide_no)


# ---------- the kettlebell mark ----------

def _mark_mask():
    im = Image.open(ICON).convert("RGB")
    dark = im.convert("L").point(lambda v: 255 if v < 90 else 0)
    box = dark.getbbox()
    px = im.load()
    key = Image.new("L", im.size, 0)
    kp = key.load()
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            r, g, b = px[x, y]
            if g > 110 and r < 90:
                kp[x, y] = 255
    return dark.crop(box), key.crop(box)


_MARK = {}


def mark(slide_no):
    if "m" not in _MARK:
        _MARK["m"] = _mark_mask()
    body, key = _MARK["m"]
    img = _vgrad(W, H, (16, 132, 92), (5, 60, 42))
    # Soft light from the top left.
    lt = Image.new("L", (W // S, H // S), 0)
    ImageDraw.Draw(lt).ellipse((-60, -90, 200, 200), fill=255)
    img = _light(img, lt.filter(ImageFilter.GaussianBlur(50)).resize((W, H), Image.BICUBIC), (70, 210, 160), 0.45)
    # The mark: huge, a different crop on each slide, so it reads as one big shape moving through.
    plan = {1: (1.55, 0.62, 0.30, -8), 2: (1.35, 0.20, 0.42, 6), 3: (1.45, 0.78, 0.34, -4),
            4: (1.30, 0.30, 0.40, 8), 5: (1.50, 0.70, 0.32, -6), 6: (1.35, 0.25, 0.38, 5), 7: (1.50, 0.60, 0.30, -7)}
    hk, cx, cy, rot = plan.get(slide_no, plan[1])
    th = round(H * hk * 0.62)
    tw = round(body.width * th / body.height)
    b = body.resize((tw, th), Image.LANCZOS).rotate(rot, resample=Image.BICUBIC, expand=True)
    kk = key.resize((tw, th), Image.LANCZOS).rotate(rot, resample=Image.BICUBIC, expand=True)
    ox, oy = round(W * cx - b.width / 2), round(H * cy)
    m = Image.new("L", (W, H), 0)
    m.paste(b, (ox, oy))
    km = Image.new("L", (W, H), 0)
    km.paste(kk, (ox, oy))
    # Tone on tone: a little darker than the stage, with a lit rim on its upper edge.
    img = Image.composite(Image.new("RGB", (W, H), (3, 44, 30)), img, m.point(lambda v: round(v * 0.42)))
    rim = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(9)).transform((W, H), Image.AFFINE, (1, 0, 0, 0, 1, 6)))
    img = _light(img, rim.filter(ImageFilter.GaussianBlur(2)), (110, 240, 190), 0.55)
    # The keyhole glows in the highlight's yellow.
    img = _light(img, km.filter(ImageFilter.GaussianBlur(60)), (255, 214, 10), 0.55)
    img = Image.composite(Image.new("RGB", (W, H), (255, 214, 10)), img, km.point(lambda v: round(v * 0.85)))
    return grain(img, 7, slide_no)


# ---------- spotlight ----------

def spot(slide_no):
    img = _vgrad(W, H, (6, 58, 41), (3, 26, 19))
    sw, sh = W // S, H // S
    rnd = random.Random(slide_no)
    # Beams from above, converging on the phone.
    beams = Image.new("L", (sw, sh), 0)
    d = ImageDraw.Draw(beams)
    for top_x, spread, a in ((0.22, 0.30, 150), (0.55, 0.34, 190), (0.86, 0.28, 140)):
        tx = top_x * sw + rnd.uniform(-8, 8)
        d.polygon([(tx - 6, -10), (tx + 6, -10), (sw * 0.5 + spread * sw, sh * 0.78), (sw * 0.5 - spread * sw * 0.2, sh * 0.78)], fill=a)
    beams = beams.filter(ImageFilter.GaussianBlur(14)).resize((W, H), Image.BICUBIC)
    img = _light(img, beams, (120, 240, 190), 0.35)
    # Haze behind the phone and a glow on the floor beneath it.
    haze = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(haze).ellipse((sw * 0.05, sh * 0.30, sw * 0.95, sh * 0.80), fill=210)
    img = _light(img, haze.filter(ImageFilter.GaussianBlur(40)).resize((W, H), Image.BICUBIC), (30, 200, 140), 0.45)
    floor = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(floor).ellipse((sw * 0.0, sh * 0.86, sw * 1.0, sh * 1.12), fill=255)
    img = _light(img, floor.filter(ImageFilter.GaussianBlur(24)).resize((W, H), Image.BICUBIC), (60, 230, 170), 0.55)
    # Dust in the light.
    dust = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(dust)
    for _ in range(140):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H * 0.8)
        r = rnd.uniform(1.5, 4.5)
        dd.ellipse((x - r, y - r, x + r, y + r), fill=rnd.randint(60, 200))
    img = _light(img, ImageChops.multiply(dust.filter(ImageFilter.GaussianBlur(1.5)), beams), (220, 255, 235), 1.0)
    return grain(img, 7, slide_no)


# ---------- bolder looks (second round) ----------

# Where each slide's phone or card sits (its centre), so the light comes from behind it.
CENTRES = {1: (0.5, 0.58), 2: (0.5, 0.64), 3: (0.5, 0.56), 4: (0.5, 0.54), 5: (0.5, 0.58), 6: (0.5, 0.56), 7: (0.5, 0.64)}


def ripple(slide_no):
    """A strong mint glow behind the phone with rings spreading out from it, like a timer's pulse."""
    img = _vgrad(W, H, (12, 112, 80), (3, 46, 33))
    cx, cy = CENTRES.get(slide_no, (0.5, 0.55))
    cx, cy = cx * W, cy * H
    sw, sh = W // S, H // S
    glow = Image.new("L", (sw, sh), 0)
    r = 150
    ImageDraw.Draw(glow).ellipse((cx / S - r, cy / S - r * 1.25, cx / S + r, cy / S + r * 1.25), fill=255)
    img = _light(img, glow.filter(ImageFilter.GaussianBlur(70)).resize((W, H), Image.BICUBIC), (70, 235, 170), 0.85)
    rings = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(rings)
    for i, rr in enumerate(range(420, 2600, 190)):
        a = max(30, 190 - i * 12)
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=a, width=4)
    img = _light(img, rings.filter(ImageFilter.GaussianBlur(1.5)), (170, 255, 215), 0.55)
    # Keep the top calm enough for white type.
    shade = Image.linear_gradient("L").resize((W, 1000)).point(lambda v: round(110 * (1 - v / 255)))
    img.paste(Image.new("RGB", (W, 1000), (2, 40, 28)), (0, 0), shade)
    return grain(img, 7, slide_no)


def aurora_bold(slide_no, n=7):
    """The aurora, twice as bright, with its brightest band running behind the headlines."""
    pano_key = ("bold", n)
    if pano_key not in _PANO:
        pw, ph = n * W // S, H // S
        img = _vgrad(pw, ph, (8, 92, 65), (3, 40, 28))
        bands = [
            ((70, 240, 170), 1.0, 700, 0.07 * H, 2.9 * W, 0.4, 0.17 * H),   # behind the headlines
            ((30, 205, 145), 0.9, 760, 0.11 * H, 3.6 * W, 2.2, 0.60 * H),
            ((205, 240, 90), 0.45, 300, 0.09 * H, 2.2 * W, 4.1, 0.88 * H),  # a yellow-green thread
            ((140, 255, 215), 0.6, 280, 0.06 * H, 1.8 * W, 1.0, 0.40 * H),
        ]
        for colour, alpha, thick, amp, wl, phase, y0 in bands:
            m = Image.new("L", (pw, ph), 0)
            pts = [(x, _wave(x * S, amp, wl, phase, y0) / S) for x in range(-20, pw + 20, 4)]
            ImageDraw.Draw(m).line(pts, fill=255, width=max(2, round(thick / S)), joint="curve")
            img = _light(img, m.filter(ImageFilter.GaussianBlur(thick / S * 0.7)), colour, alpha)
        _PANO[pano_key] = img
    pano = _PANO[pano_key]
    x0 = (slide_no - 1) * W // S
    piece = pano.crop((x0, 0, x0 + W // S, H // S)).resize((W, H), Image.BICUBIC)
    lines = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(lines)
    off = (slide_no - 1) * W
    for amp, wl, phase, y0, a in ((0.07 * H, 2.9 * W, 0.40, 0.17 * H, 230), (0.07 * H, 2.9 * W, 0.52, 0.205 * H, 150),
                                  (0.11 * H, 3.6 * W, 2.2, 0.60 * H, 200), (0.11 * H, 3.6 * W, 2.3, 0.635 * H, 130),
                                  (0.09 * H, 2.2 * W, 4.1, 0.88 * H, 170)):
        pts = [(x, _wave(x + off, amp, wl, phase, y0)) for x in range(-10, W + 10, 6)]
        d.line(pts, fill=a, width=4, joint="curve")
    piece = _light(piece, lines.filter(ImageFilter.GaussianBlur(1.3)), (215, 255, 235), 0.9)
    # A dark wash under the headline so white type stays crisp over the bright band.
    wash = Image.linear_gradient("L").resize((W, 900)).point(lambda v: round(120 * (1 - v / 255)))
    piece.paste(Image.new("RGB", (W, 900), (2, 38, 26)), (0, 0), wash)
    return grain(piece, 7, slide_no)


def plates(slide_no):
    """Giant weight plates, tone on tone, with lit rims, around and behind the phone."""
    img = _vgrad(W, H, (14, 120, 86), (4, 50, 35))
    lt = Image.new("L", (W // S, H // S), 0)
    ImageDraw.Draw(lt).ellipse((-60, -90, 220, 220), fill=255)
    img = _light(img, lt.filter(ImageFilter.GaussianBlur(50)).resize((W, H), Image.BICUBIC), (80, 220, 170), 0.5)
    plan = {1: [(1.02, 0.40, 900), (-0.05, 0.86, 640)], 2: [(-0.08, 0.42, 820), (1.06, 0.80, 700)],
            3: [(1.04, 0.30, 760), (-0.02, 0.78, 900)], 4: [(-0.06, 0.36, 760), (1.05, 0.88, 820)],
            5: [(1.03, 0.42, 860), (-0.04, 0.84, 640)], 6: [(-0.06, 0.44, 800), (1.04, 0.86, 700)],
            7: [(1.02, 0.36, 820), (-0.05, 0.80, 760)]}
    for fx, fy, r in plan.get(slide_no, plan[1]):
        cx, cy = fx * W, fy * H
        body = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(body)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
        d.ellipse((cx - r * 0.16, cy - r * 0.16, cx + r * 0.16, cy + r * 0.16), fill=0)  # the bar hole
        img = Image.composite(Image.new("RGB", (W, H), (4, 52, 36)), img, body.point(lambda v: round(v * 0.55)))
        rings = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(rings)
        for k_, a in ((1.0, 230), (0.86, 120), (0.62, 150), (0.30, 120), (0.16, 200)):
            rr = r * k_
            d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=a, width=6 if k_ in (1.0, 0.16) else 3)
        # Lit from the top left: fade the rims towards the bottom right.
        fade = Image.linear_gradient("L").rotate(-45, expand=False).resize((W, H)).point(lambda v: 255 - v)
        img = _light(img, ImageChops.multiply(rings.filter(ImageFilter.GaussianBlur(1.2)), fade), (150, 255, 210), 0.75)
    return grain(img, 7, slide_no)


# ---------- third round: built to show around the phone ----------

def _vignette(img, strength=0.55, colour=(1, 22, 15)):
    v = Image.new("L", (W // S, H // S), 255)
    ImageDraw.Draw(v).ellipse((-40, -20, W // S + 40, H // S + 20), fill=0)
    v = v.filter(ImageFilter.GaussianBlur(60)).resize((W, H), Image.BICUBIC).point(lambda x: round(x * strength))
    return Image.composite(Image.new("RGB", (W, H), colour), img, v)


def glow(slide_no):
    """Deep emerald, darker at the edges, a bright mint light behind the phone and pulse rings
    spreading from it; the top stays deep so the headline and its second line read cleanly."""
    img = _vgrad(W, H, (10, 100, 72), (2, 40, 28))
    cx, cy = CENTRES.get(slide_no, (0.5, 0.55))
    cx, cy = cx * W, cy * H
    sw, sh = W // S, H // S
    g = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(g).ellipse((cx / S - 200, cy / S - 210, cx / S + 200, cy / S + 230), fill=255)
    img = _light(img, g.filter(ImageFilter.GaussianBlur(80)).resize((W, H), Image.BICUBIC), (50, 240, 165), 1.0)
    core = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(core).ellipse((cx / S - 95, cy / S - 120, cx / S + 95, cy / S + 130), fill=255)
    img = _light(img, core.filter(ImageFilter.GaussianBlur(55)).resize((W, H), Image.BICUBIC), (190, 255, 225), 0.55)
    rings = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(rings)
    for i, rr in enumerate(range(380, 2900, 160)):
        d.ellipse((cx - rr, cy - rr * 1.06, cx + rr, cy + rr * 1.06), outline=max(40, 235 - i * 12), width=5)
    img = _light(img, rings.filter(ImageFilter.GaussianBlur(1.4)), (175, 255, 220), 0.62)
    img = _vignette(img, 0.6)
    # The headline zone stays deep: a wash that fades out by y = 1000.
    shade = Image.linear_gradient("L").resize((W, 1000)).point(lambda v: round(175 * (1 - v / 255) ** 1.2))
    img.paste(Image.new("RGB", (W, 1000), (2, 34, 24)), (0, 0), shade)
    return grain(img, 7, slide_no)


def _band(size, p0, p1, width, soft=0.5):
    """A straight band from p0 to p1, `width` wide: bright along one edge, fading across."""
    w, h = size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    (x0, y0), (x1, y1) = p0, p1
    L = math.hypot(x1 - x0, y1 - y0)
    nx, ny = -(y1 - y0) / L, (x1 - x0) / L
    steps = 24
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        a = round(255 * (1 - t0) ** 1.6)
        q = [(x0 + nx * width * t0, y0 + ny * width * t0), (x1 + nx * width * t0, y1 + ny * width * t0),
             (x1 + nx * width * t1, y1 + ny * width * t1), (x0 + nx * width * t1, y0 + ny * width * t1)]
        d.polygon(q, fill=a)
    return m


def streaks(slide_no, n=7):
    """Diagonal light streaks across a deep emerald field, running on from slide to slide."""
    img = _vgrad(W, H, (8, 92, 66), (2, 38, 27))
    off = (slide_no - 1) * W
    sw, sh = W // S, H // S
    big = Image.new("L", (sw, sh), 0)
    thin = Image.new("L", (W, H), 0)
    lime = Image.new("L", (W, H), 0)
    # Each streak: a start x at the top of the strip (in panorama px), its slope, width and strength.
    for x_top, slope, width, a in ((300, 1.25, 520, 1.0), (1900, 1.25, 380, 0.8), (3500, 1.25, 600, 1.0),
                                   (5100, 1.25, 420, 0.8), (6700, 1.25, 560, 1.0), (8300, 1.25, 400, 0.8)):
        x0 = x_top - off
        p0, p1 = (x0 / S, -50 / S), ((x0 - H * slope) / S, (H + 50) / S)
        band = _band((sw, sh), p0, p1, width / S)
        big = ImageChops.lighter(big, band.point(lambda v: round(v * a)))
        dt = ImageDraw.Draw(thin)
        dt.line([(x0, -50), (x0 - H * slope, H + 50)], fill=round(230 * a), width=4)
        dl = ImageDraw.Draw(lime)
        dl.line([(x0 + 70, -50), (x0 + 70 - H * slope, H + 50)], fill=round(150 * a), width=3)
    img = _light(img, big.filter(ImageFilter.GaussianBlur(6)).resize((W, H), Image.BICUBIC), (40, 220, 150), 0.75)
    img = _light(img, thin.filter(ImageFilter.GaussianBlur(1.3)), (200, 255, 230), 0.7)
    img = _light(img, lime.filter(ImageFilter.GaussianBlur(1.0)), (230, 240, 90), 0.55)
    img = _vignette(img, 0.45)
    shade = Image.linear_gradient("L").resize((W, 900)).point(lambda v: round(110 * (1 - v / 255)))
    img.paste(Image.new("RGB", (W, 900), (2, 34, 24)), (0, 0), shade)
    return grain(img, 7, slide_no)


WORDS = {1: "LOCKED", 2: "REST", 3: "LOG", 4: "FOCUS", 5: "PR", 6: "STREAK", 7: "LOCK IN"}


def giant_type(slide_no):
    """A huge outlined word behind the phone (LOCKED, REST, LOG...), cropped by the slide's edges."""
    from PIL import ImageFont
    img = _vgrad(W, H, (12, 108, 77), (3, 44, 31))
    lt = Image.new("L", (W // S, H // S), 0)
    ImageDraw.Draw(lt).ellipse((-60, -90, 220, 260), fill=255)
    img = _light(img, lt.filter(ImageFilter.GaussianBlur(55)).resize((W, H), Image.BICUBIC), (70, 220, 160), 0.5)
    word = WORDS.get(slide_no, "LOCKED")
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 900)
    axes = f.get_variation_axes()
    f.set_variation_by_axes([{"Width": 30, "Optical Size": 96, "GRAD": 400, "Weight": 1000}.get(a["name"] if isinstance(a["name"], str) else a["name"].decode(), a["default"]) for a in axes])
    layer = Image.new("L", (W * 3, H), 0)
    d = ImageDraw.Draw(layer)
    tw = d.textlength(word, font=f)
    size = 900 if tw < W * 1.35 else round(900 * W * 1.35 / tw)
    if size != 900:
        f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
        f.set_variation_by_axes([{"Width": 30, "Optical Size": 96, "GRAD": 400, "Weight": 1000}.get(a["name"] if isinstance(a["name"], str) else a["name"].decode(), a["default"]) for a in axes])
        tw = d.textlength(word, font=f)
    # Two stacked copies, the lower one fainter, stepping down the slide behind the phone.
    for row, (y, a_fill, a_line) in enumerate(((H * 0.40, 46, 210), (H * 0.70, 26, 120))):
        x = (W * 3 - tw) / 2 + (-90 if row else 60)
        d.text((x, y), word, font=f, fill=a_fill, stroke_width=0)
        outline = Image.new("L", (W * 3, H), 0)
        ImageDraw.Draw(outline).text((x, y), word, font=f, fill=0, stroke_width=5, stroke_fill=a_line)
        layer = ImageChops.lighter(layer, outline)
        d = ImageDraw.Draw(layer)
    layer = layer.crop((W, 0, W * 2, H))
    img = _light(img, layer, (150, 255, 210), 0.65)
    img = _vignette(img, 0.4)
    return grain(img, 7, slide_no)


STYLES = {"aurora": aurora, "mark": mark, "spot": spot, "ripple": ripple, "aurora_bold": aurora_bold, "plates": plates,
          "glow": glow, "streaks": streaks, "giant_type": giant_type}
