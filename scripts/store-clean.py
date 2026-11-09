#!/usr/bin/env python3
"""GymBlock's 'clean' App Store set (9 Nov 2026), modelled on Cal AI's.

Cal AI's system, measured on its 1242 x 2208 slides: one flat dark colour; a plain white headline
in two lines at the top left (about 10% of the slide's width tall, medium weight, no second line,
no highlight); one whole phone, centred, never cut; and one real element of that screen lifted out,
about 1.15x larger, breaking past both edges of the phone. The slides tell one story in order:
the promise, the action, the result, then progress.

GymBlock's story is one workout: stop scrolling between sets (a real iPhone mid-workout, its feeds
dimmed by Screen Time), just tap Start workout, then the apps you chose stay locked (the shield),
rest on the Lock Screen, log every set, your progress. Other companies' icons stay inside the real
Home Screen, unenlarged and unmarked, rebuilt on a clean emerald wallpaper without its dock.
Slides 2, 4, 5 and 6 are one Push workout on one morning (store-2026-11-09, US region, 9:41).

    python3 scripts/store-clean.py             # writes screenshots/store-clean/<slot>/ and an overview
    python3 scripts/store-clean.py --only 1,2  # those slides, 6.9-inch only
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import store_kit as k  # noqa: E402

SHOTS = os.path.join(k.ROOT, "screenshots")
# Two themes to compare (9 Nov 2026, the user's call): white with black type, or black with white type.
THEME = os.environ.get("GB_THEME", "white")
OUT = os.path.join(SHOTS, f"store-clean-{THEME}")
W, H = k.W, k.H

# Pure white (the user tried a faint mint, #F3F8F5, and went back to white on 9 Nov).
BG = (255, 255, 255) if THEME == "white" else (10, 10, 11)
WHITE = (255, 255, 255)
INK = (14, 14, 15)
FG = INK if THEME == "white" else (255, 255, 255)   # the headline
HEAD_WEIGHT = 700
MARGIN = 112               # Cal AI's 8.4% left margin
TEXT_W = W - MARGIN - 96
HEAD = 134                 # Cal AI's headline is about 10% of the slide's width
DEVICE_TOP = 640           # the phone fills the slide from about 22% to 95% of its height
SCREEN_W = 912
LIFT = 1.15                # the lifted element's size against the phone's screen


def cap(path):
    return Image.open(os.path.join(SHOTS, path)).convert("RGB")


def headline(c, text):
    f = k.sf(HEAD, weight=HEAD_WEIGHT)
    # Centred (the user, 9 Nov), over the centred phone.
    k.text_block(c, text, MARGIN, 150, TEXT_W, f, FG, align="center", leading=1.17)


def phone(c, shot):
    """The whole phone, centred. Returns (screen x, screen y, capture-to-canvas scale)."""
    s = SCREEN_W / shot.width
    border = 17 * 3 * (SCREEN_W / 1320)   # the outline-to-screen border of Apple's frame, at this size
    x, y = (W - SCREEN_W) // 2, round(DEVICE_TOP + border)
    island = not (shot.crop((shot.width // 2 - 20, round(shot.width * 0.05), shot.width // 2 + 20,
                             round(shot.width * 0.07))).convert("L").getextrema()[1] < 30)
    k.place_device(c, shot, x, y, SCREEN_W, island=island,
                   drop=(0.55, 60, 36) if THEME == "black" else (0.24, 56, 30))
    return x, y, s


CARD_W = W - 2 * MARGIN    # the lifted card spans the text column: 1096 px, about 60 px past each side of the phone
CARD_R = 48


def lift(c, shot, box, screen, pad=48, r=CARD_R, min_top=None):
    """Lifts `box` (capture pixels) out of the phone at its own place, as Cal AI does: a white card
    as wide as the text column (so it overhangs the phone by about 60 px a side), the crop padded
    with the screen's own white so nothing touches the card's edge, a light shadow and a hairline.
    `min_top` keeps the card below the status bar or a title it would otherwise cover."""
    sx, sy, s = screen
    x0, y0, x1, y1 = box
    piece = shot.crop(box)
    if pad:
        framed = Image.new("RGB", (piece.width + 2 * pad, piece.height + 2 * pad), WHITE)
        framed.paste(piece, (pad, pad))
        piece = framed
    k_ = CARD_W / piece.width
    w, h = CARD_W, round(piece.height * k_)
    cy = sy + (y0 + y1) / 2 * s
    left, top = MARGIN, round(cy - h / 2)
    # Never over the status bar or the Dynamic Island, as Cal AI's card never is.
    top = max(top, round(sy + 150 * s), min_top or 0)
    # On white the card needs its own edge: a fuller shadow and a grey hairline.
    if THEME == "white":
        k.shadow(c, (left, top, left + w, top + h), r, blur=34, opacity=0.20, dy=16, color=(0, 0, 0))
        hair = Image.new("RGB", (w + 4, h + 4), (222, 224, 227))
    else:
        k.shadow(c, (left, top, left + w, top + h), r, blur=22, opacity=0.28, dy=12, color=(0, 0, 0))
        hair = Image.new("RGB", (w + 4, h + 4), (214, 216, 215))
    k.paste_rounded(c, hair, left - 2, top - 2, r + 2)
    k.paste_rounded(c, piece.resize((w, h), Image.LANCZOS), left, top, r)
    return (left, top, left + w, top + h)


def without_dock(home):
    """The real Home Screen with its Search pill and dock (other companies' apps) painted over by
    the wallpaper's own colours, so only the locked apps and GymBlock carry brands."""
    img = home.copy()
    w, h = img.size
    y0 = 2036   # above the Search pill's soft shadow
    top = [img.getpixel((x, y0 - 6)) for x in range(w)]
    corner = img.getpixel((12, h - 12))   # the wallpaper's own dark foot, clear of the dock and home bar
    px = img.load()
    for y in range(y0, h):
        t = ((y - y0) / (h - y0)) ** 0.8
        for x in range(w):
            a = top[x]
            px[x, y] = tuple(round(a[i] + (corner[i] - a[i]) * t) for i in range(3))
    return img


def _wallpaper(w, h):
    """A clean emerald wallpaper in the icon's colour: light from the top left, deep at the foot."""
    from PIL import ImageFilter
    img = k._vgrad(w, h, (40, 146, 108), (5, 46, 34)) if hasattr(k, "_vgrad") else None
    if img is None:
        g = Image.linear_gradient("L").resize((w, h))
        img = Image.composite(Image.new("RGB", (w, h), (5, 46, 34)), Image.new("RGB", (w, h), (40, 146, 108)), g)
    light = Image.new("L", (w // 6, h // 6), 0)
    ImageDraw.Draw(light).ellipse((-w // 6 * 0.4, -h // 6 * 0.25, w // 6 * 0.9, h // 6 * 0.45), fill=255)
    light = light.filter(ImageFilter.GaussianBlur(40)).resize((w, h), Image.BICUBIC)
    from PIL import ImageChops
    lit = ImageChops.screen(img, Image.new("RGB", (w, h), (70, 190, 140)))
    return Image.composite(lit, img, light.point(lambda v: round(v * 0.55)))


def _white_on(src_l, box, ya, yb):
    """Alpha of white text in `box` of a capture, read against the wallpaper just above (row ya)
    and below (row yb) it, so the text can move onto another wallpaper with its own anti-aliasing."""
    x0, y0, x1, y1 = box
    a = Image.new("L", src_l.size, 0)
    px, ap = src_l.load(), a.load()
    for x in range(x0, x1):
        ba, bb = px[x, ya], px[x, yb]
        for y in range(y0, y1):
            bg = ba + (bb - ba) * (y - ya) / (yb - ya)
            v = px[x, y]
            if v > bg + 6 and bg < 250:
                ap[x, y] = max(0, min(255, round(255 * (v - bg) / (255 - bg) * 1.08)))
    return a


def rebuilt_home():
    """The real iPhone Home Screen mid-workout (store-2026-11-02/blocked-home.png) moved onto a clean
    wallpaper: its own icons (Screen Time's dimming included), the labels with their hourglasses,
    the status bar and the workout clock in the Dynamic Island. The Search pill and the dock of
    unrelated apps are left out. Nothing the app does is changed; only the wallpaper is."""
    from PIL import ImageFilter
    src = cap("store-2026-11-02/blocked-home.png")
    w, h = src.size
    out = _wallpaper(w, h)
    L = src.convert("L")
    # White text: the two label rows and the status bar (clear of the island).
    text = Image.new("L", (w, h), 0)
    from PIL import ImageChops
    for box, ya, yb in (((40, 444, w - 40, 496), 440, 500), ((40, 740, w - 40, 792), 736, 796),
                        ((60, 58, 280, 116), 54, 120), ((944, 58, w - 40, 116), 54, 120)):
        text = ImageChops.lighter(text, _white_on(L, box, ya, yb))
    shadow = text.filter(ImageFilter.GaussianBlur(3)).point(lambda v: round(v * 0.35))
    out.paste(Image.new("RGB", (w, h), (0, 0, 0)), (0, 2), shadow)
    out.paste(Image.new("RGB", (w, h), (255, 255, 255)), (0, 0), text)
    # The icons, cut along iOS's icon shape, with a soft shadow.
    size = 192
    # iOS's icon corner, measured on this capture: the curve starts about 45 px along each edge and
    # sits 15 px in on the diagonal, i.e. close to a 50 px circular radius at this size.
    m3 = Image.new("L", ((size - 2) * 3, (size - 2) * 3), 0)
    ImageDraw.Draw(m3).rounded_rectangle((0, 0, (size - 2) * 3 - 1, (size - 2) * 3 - 1), 52 * 3, fill=255)
    m = m3.resize((size - 2, size - 2), Image.LANCZOS)
    for iy in (240, 536):
        for ix in (85, 357, 631, 903):
            piece = src.crop((ix + 1, iy + 1, ix + size - 1, iy + size - 1))
            k.shadow(out, (ix + 2, iy + 2, ix + size - 2, iy + size - 2), 44, blur=10, opacity=0.25, dy=6)
            out.paste(piece, (ix + 1, iy + 1), m)
    # The Dynamic Island with the workout clock, as a pill.
    ix0, iy0, ix1, iy1 = 289, 31, 932, 146
    pill = Image.new("L", ((ix1 - ix0) * 3, (iy1 - iy0) * 3), 0)
    ImageDraw.Draw(pill).rounded_rectangle((0, 0, (ix1 - ix0) * 3, (iy1 - iy0) * 3), (iy1 - iy0) * 3 // 2, fill=255)
    out.paste(src.crop((ix0, iy0, ix1, iy1)), (ix0, iy0), pill.resize((ix1 - ix0, iy1 - iy0), Image.LANCZOS))
    return out


POSTER = os.environ.get("GB_POSTER", "dark" if THEME == "black" else "light")   # 'dark', 'light' or 'phone'


def _icon_tile(name, size, rot, locked, theme):
    """One app icon at `size`, rounded as iOS rounds it, with a lock badge on its top-right corner,
    rotated `rot` degrees, on a transparent tile (with room for the shadow)."""
    from PIL import ImageFilter
    pad = round(size * 0.35)
    t = size + 2 * pad
    tile = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    m3 = Image.new("L", (size * 3, size * 3), 0)
    ImageDraw.Draw(m3).rounded_rectangle((0, 0, size * 3 - 1, size * 3 - 1), round(size * 0.235 * 3), fill=255)
    m = m3.resize((size, size), Image.LANCZOS)
    # Shadow under the icon.
    sh = Image.new("L", (t, t), 0)
    sh.paste(m, (pad, pad + round(size * 0.07)))
    sh = sh.filter(ImageFilter.GaussianBlur(size * 0.09)).point(lambda v: round(v * (0.55 if theme == "dark" else 0.22)))
    tile.paste(Image.new("RGBA", (t, t), (0, 0, 0, 255)), (0, 0), sh)
    art = k.icon(name).convert("RGB").resize((size, size), Image.LANCZOS)
    # A soft sheen from the top left, so the icons read as objects, not stickers.
    g = Image.new("L", (64, 64))
    g.putdata([round(46 * max(0.0, 1 - (x + y) / 64) ** 2) for y in range(64) for x in range(64)])
    sheen = g.resize((size, size), Image.BICUBIC)
    art = Image.composite(Image.new("RGB", (size, size), (255, 255, 255)), art, sheen)
    if theme == "dark":
        # A faint rim, so black icons (TikTok, X, Spotify) keep their edge on the dark stage.
        rim = Image.new("L", (size, size), 0)
        rim.paste(m, (0, 0))
        inner = m.filter(ImageFilter.MinFilter(5))
        from PIL import ImageChops
        rim = ImageChops.subtract(rim, inner).point(lambda v: round(v * 0.30))
        art = Image.composite(Image.new("RGB", (size, size), (255, 255, 255)), art, rim)
    tile.paste(art, (pad, pad), m)
    if locked:
        d = round(size * 0.36)
        cx, cy = pad + size - round(size * 0.08), pad + round(size * 0.08)
        ring = max(4, round(d * 0.09))
        bsh = Image.new("L", (t, t), 0)
        ImageDraw.Draw(bsh).ellipse((cx - d / 2, cy - d / 2 + d * 0.12, cx + d / 2, cy + d / 2 + d * 0.12), fill=255)
        tile.paste(Image.new("RGBA", (t, t), (0, 0, 0, 255)), (0, 0), bsh.filter(ImageFilter.GaussianBlur(d * 0.12)).point(lambda v: round(v * 0.35)))
        badge = Image.new("RGB", (t, t))
        k.lock_badge(badge, cx, cy, d + 2 * ring, bg=WHITE, fg=WHITE)
        k.lock_badge(badge, cx, cy, d, bg=INK, fg=WHITE)
        bm = Image.new("L", (t, t), 0)
        ImageDraw.Draw(bm).ellipse((cx - d / 2 - ring, cy - d / 2 - ring, cx + d / 2 + ring, cy + d / 2 + ring), fill=255)
        tile.paste(badge, (0, 0), bm)
    return tile.rotate(rot, resample=Image.BICUBIC, expand=False)


def slide_stop_poster(theme):
    """1. The promise as a poster, after PushUp Time's first slide: the feeds people scroll between
    sets float with a lock on each; Spotify and GymBlock stay open (music keeps playing)."""
    bg, fg = BG, FG
    c = Image.new("RGB", (W, H), bg)
    headline(c, "Stop scrolling\nbetween sets")
    # (name, centre x, centre y, size, rotation, locked)
    cloud = [
        ("tiktok", 390, 960, 430, -9, True),
        ("instagram", 1010, 880, 350, 10, True),
        ("reddit", 700, 1440, 280, -6, True),
        ("youtube", 1030, 1760, 370, 7, True),
        ("x", 330, 1840, 330, 9, True),
        ("spotify", 400, 2470, 290, -6, False),
        ("gymblock", 930, 2420, 400, 4, False),
    ]
    for name, cx, cy, size, rot, locked in cloud:
        tile = _icon_tile(name, size, rot, locked, theme)
        c.paste(tile, (round(cx - tile.width / 2), round(cy - tile.height / 2)), tile)
    return c


def slide_stop():
    """1. The promise, shown: a real iPhone mid-workout, the feeds dimmed by Screen Time."""
    if POSTER in ("dark", "light"):
        return slide_stop_poster(POSTER)
    c = Image.new("RGB", (W, H), BG)
    headline(c, "Stop scrolling\nbetween sets")
    phone(c, rebuilt_home())
    return c


def slide_start():
    """2. The action: Start workout."""
    c = Image.new("RGB", (W, H), BG)
    headline(c, "Just tap\nStart workout")
    shot = cap("store-2026-11-09/home.png")
    scr = phone(c, shot)
    lift(c, shot, (36, 1690, 1170, 2290), scr)
    return c


def slide_locked():
    """3. The result: what a chosen app shows mid-workout."""
    c = Image.new("RGB", (W, H), BG)
    headline(c, "Then your chosen\napps stay locked")
    shot = cap("store-2026-11-09/shield-tiktok.png")
    scr = phone(c, shot)
    # The mark and the words; the button stays on the phone, at its foot, where iOS draws it.
    lift(c, shot, (40, 680, 1166, 1290), scr)
    return c


def slide_rest():
    c = Image.new("RGB", (W, H), BG)
    headline(c, "Rest on your\nLock Screen")
    shot = cap("store-2026-11-09/lock-rest.png")
    scr = phone(c, shot)
    # The Live Activity's own platter, to its edges, with its own corner (no wallpaper at the corners).
    box = (42, 1722, 1164, 2228)
    lift(c, shot, box, scr, pad=0, r=round(66 * CARD_W / (box[2] - box[0])))
    return c


def slide_log():
    c = Image.new("RGB", (W, H), BG)
    headline(c, "Log every set\nin seconds")
    shot = cap("store-2026-11-09/workout-rest.png")
    scr = phone(c, shot)
    # From the workout's title row (Push, its clock, End) to set 3, so no title is cut.
    lift(c, shot, (36, 190, 1170, 1125), scr)
    return c


def slide_progress():
    c = Image.new("RGB", (W, H), BG)
    headline(c, "Your progress,\nlift by lift")
    shot = cap("store-2026-11-09/record.png")
    scr = phone(c, shot)
    # From the split's label (Push) down to "Same reps", so no label is cut by the card's edge.
    lift(c, shot, (36, 405, 1170, 1060), scr)
    return c


SLIDES = [
    ("1-stop-scrolling-between-sets", slide_stop),
    ("2-just-tap-start-workout", slide_start),
    ("3-then-your-chosen-apps-stay-locked", slide_locked),
    ("4-rest-on-your-lock-screen", slide_rest),
    ("5-log-every-set-in-seconds", slide_log),
    ("6-your-progress-lift-by-lift", slide_progress),
]


def main():
    only = None
    if "--only" in sys.argv:
        only = {int(v) for v in sys.argv[sys.argv.index("--only") + 1].split(",")}
    names = []
    for i, (name, fn) in enumerate(SLIDES, 1):
        if only and i not in only:
            continue
        img = fn()
        if only:
            os.makedirs(os.path.join(OUT, "6.9"), exist_ok=True)
            img.save(os.path.join(OUT, "6.9", name + ".png"))
        else:
            k.export(img, OUT, name + ".png")
        names.append(name)
        print(name)
    if not only:
        k.overview([os.path.join(OUT, "6.9", n + ".png") for n in names], os.path.join(SHOTS, f"store-clean-{THEME}-overview.png"))


if __name__ == "__main__":
    main()
