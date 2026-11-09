"""Drawing kit for the App Store slides (9 Nov 2026): the stage, display type, a drawn iPhone,
enlarged crops of real captures, app icons, chips, and the export to every iPhone slot.

Used by scripts/store-slides.py. Everything is drawn at the 6.9-inch size (1320 x 2868) and scaled
for the other slots. Shapes are drawn 3x larger and scaled down for clean edges.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 1320, 2868
SS = 3
SF = "/System/Library/Fonts/SFNS.ttf"
SF_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
ICONS = os.path.join(ROOT, "GymBlock", "StoreShots.xcassets")
APP_ICON = os.path.join(ROOT, "GymBlock", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")

# Apple's iPhone slots: 6.9-inch (large Dynamic Island) and the 6.3/6.1-inch (medium) sizes, as the
# earlier sets had them.
SIZES = {"6.9": (1320, 2868), "6.3": (1206, 2622), "6.1": (1179, 2556)}


# ---------- type ----------

_FONTS = {}


def sf(size, weight=700, width=100, rounded=False):
    """SF Pro at a pixel size, with the optical size set for display text (the canvas is a 3x
    phone, so a 210-px headline is 70 pt and gets SF's tighter display cut)."""
    key = (size, weight, width, rounded)
    if key not in _FONTS:
        f = ImageFont.truetype(SF_ROUNDED if rounded else SF, size)
        opsz = max(17, min(96, size / 3))
        axes = {a["name"]: a for a in f.get_variation_axes()}
        values = []
        for name in axes:
            values.append({b"Width": width, b"Optical Size": opsz, b"GRAD": 400, b"Weight": weight,
                           "Width": width, "Optical Size": opsz, "GRAD": 400, "Weight": weight}.get(name, axes[name]["default"]))
        f.set_variation_by_axes(values)
        _FONTS[key] = f
    return _FONTS[key]


def parse(text):
    """'Lock *TikTok* at the gym' -> [('Lock', False), ('TikTok', True), ...]; '\n' forces a break."""
    out = []
    for line in text.split("\n"):
        words = []
        for w in line.split(" "):
            if not w:
                continue
            acc = w.startswith("*") and w.rstrip(".,!?:;").endswith("*")
            words.append((w.replace("*", ""), acc))
        out.append(words)
    return out


def text_block(canvas, text, x, y, max_w, font, color, accent=None, align="left", leading=1.0,
               tracking=0, highlight=None, measure_only=False):
    """Draws `text` (with *accent* words and \n breaks) inside max_w, wrapping greedily.
    Returns (bottom y, list of line boxes). `leading` is the line height as a share of the font size."""
    draw = ImageDraw.Draw(canvas)
    lines = []
    for words in parse(text):
        cur = []
        for w in words:
            trial = cur + [w]
            if cur and _width(draw, trial, font, tracking) > max_w:
                lines.append(cur)
                cur = [w]
            else:
                cur = trial
        lines.append(cur)
    asc, desc = font.getmetrics()
    lh = round(font.size * leading)
    boxes = []
    cy = y
    for words in lines:
        lw = _width(draw, words, font, tracking)
        if align == "center":
            cx = x + (max_w - lw) / 2
        elif align == "right":
            cx = x + max_w - lw
        else:
            cx = x
        boxes.append((cx, cy, cx + lw, cy + lh))
        if not measure_only:
            space = draw.textlength(" ", font=font)
            for i, (w, acc) in enumerate(words):
                if acc and highlight:
                    b = draw.textbbox((cx, cy), w, font=font)
                    pad = round(font.size * 0.08)
                    draw.rounded_rectangle((b[0] - pad, b[1] - pad * 0.5, b[2] + pad, b[3] + pad * 0.6),
                                           round(font.size * 0.12), fill=highlight)
                _draw_word(draw, cx, cy, w, font, accent if (acc and accent) else color, tracking)
                cx += _wlen(draw, w, font, tracking) + (space if i < len(words) - 1 else 0)
        cy += lh
    return cy, boxes


def _wlen(draw, w, font, tracking):
    return draw.textlength(w, font=font) + tracking * max(0, len(w) - 1)


def _width(draw, words, font, tracking):
    space = draw.textlength(" ", font=font)
    return sum(_wlen(draw, w, font, tracking) for w, _ in words) + space * max(0, len(words) - 1)


def _draw_word(draw, x, y, w, font, fill, tracking):
    if not tracking:
        draw.text((x, y), w, font=font, fill=fill)
        return
    for ch in w:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + tracking


def fit_font(canvas, text, max_w, max_lines, size, min_size, **kw):
    """The largest font from `size` down to `min_size` that sets `text` in max_lines within max_w."""
    s = size
    while s >= min_size:
        f = sf(s, **kw)
        _, boxes = text_block(canvas, text, 0, 0, max_w, f, (0, 0, 0), measure_only=True)
        if len(boxes) <= max_lines and all(b[2] - b[0] <= max_w + 0.5 for b in boxes):
            return f
        s -= 4
    raise ValueError(f"{text!r} does not fit in {max_lines} lines at {min_size}px")


# ---------- shapes ----------

def squircle(w, h, r, n=5.0):
    """A rounded rectangle with continuous (superellipse) corners, as Apple draws them."""
    r = min(r * 1.22, w / 2, h / 2)
    pts = []
    for cx, cy, a0 in ((w - r, r, -90), (w - r, h - r, 0), (r, h - r, 90), (r, r, 180)):
        for i in range(48):
            t = math.radians(a0 + 90 * i / 47)
            c, s_ = math.cos(t), math.sin(t)
            pts.append((cx + r * math.copysign(abs(c) ** (2 / n), c), cy + r * math.copysign(abs(s_) ** (2 / n), s_)))
    return pts


def mask(w, h, r):
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).polygon(squircle(w * SS, h * SS, r * SS), fill=255)
    return m.resize((w, h), Image.LANCZOS)


def shadow(canvas, box, r, blur=50, opacity=0.35, dy=30, color=(0, 0, 0)):
    """A soft drop shadow under the rounded box (x0, y0, x1, y1)."""
    x0, y0, x1, y1 = [round(v) for v in box]
    pad = blur * 3
    w, h = x1 - x0, y1 - y0
    layer = Image.new("L", (w + 2 * pad, h + 2 * pad), 0)
    layer.paste(mask(w, h, r), (pad, pad))
    layer = layer.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: round(v * opacity))
    canvas.paste(Image.new("RGB", layer.size, color), (x0 - pad, y0 - pad + dy), layer)


def paste_rounded(canvas, img, x, y, r):
    img = img.convert("RGB")
    canvas.paste(img, (round(x), round(y)), mask(img.width, img.height, r))


# ---------- stage ----------

def stage(top, bottom=None, glow=None):
    """A vertical gradient; `glow` = (colour, alpha 0-255, (cx, cy, rx, ry)) adds a soft light."""
    bottom = bottom or top
    img = Image.new("RGB", (W, H), top)
    if bottom != top:
        grad = Image.linear_gradient("L").resize((W, H))
        img = Image.composite(Image.new("RGB", (W, H), bottom), img, grad)
    if glow:
        col, a, (cx, cy, rx, ry) = glow
        g = Image.new("L", (W, H), 0)
        ImageDraw.Draw(g).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=a)
        g = g.filter(ImageFilter.GaussianBlur(max(rx, ry) * 0.45))
        img.paste(Image.new("RGB", (W, H), col), (0, 0), g)
    return img


# ---------- the real iPhone 18 Pro Max outline ----------
#
# Xcode's Simulator draws this phone from vector PDFs on this Mac: the device outline and side buttons
# (DeviceKit chrome 'phone12') and the display's own corner mask (the iPhone 18 Pro Max device type).
# They're rendered once at 3x (1 pt = 3 px, so the screen is 1320 x 2868, the captures' size) into
# scripts/bezels/sim/ (git-ignored: Apple's artwork, not ours to redistribute). The phone keeps their
# exact shape and draws the materials over it: a titanium edge, the black border, the Dynamic Island
# (iPhone 18 Pro proportions, measured from the simulator: 23.6% of the screen's width, 9.1% tall).

CHROME = "/Library/Developer/DeviceKit/Chrome/phone12.devicechrome/Contents/Resources"
DEVICE = "/Library/Developer/CoreSimulator/Profiles/DeviceTypes/iPhone 18 Pro Max.simdevicetype/Contents/Resources"
SIM_DIR = os.path.join(ROOT, "scripts", "bezels", "sim")
PT = 3                      # px per pt in the rendered chrome
BORDER_PT = 17              # outline to screen, per side (the chrome's 474 x 990 pt around a 440 x 956 pt screen)
BUTTONS = [("Mute BTN", "left", 180), ("Vol BTN", "left", 268), ("Vol BTN", "left", 354), ("X_Power BTN", "right", 293)]
_DEVICE_CACHE = {}


def _render_pdf(pdf, png, scale=PT):
    import subprocess
    tool = os.path.join(SIM_DIR, "render-pdf")
    if not os.path.exists(tool):
        subprocess.run(["swiftc", "-O", os.path.join(ROOT, "scripts", "render-pdf.swift"), "-o", tool], check=True)
    subprocess.run([tool, pdf, png, str(scale)], check=True, capture_output=True)


def _sim_assets():
    os.makedirs(SIM_DIR, exist_ok=True)
    want = {"composite": (os.path.join(CHROME, "PhoneComposite.pdf"), "composite.png"),
            "mask": (None, "screen-mask.png")}
    for name, _, _ in BUTTONS:
        want[name] = (os.path.join(CHROME, name + ".pdf"), name.replace(" ", "_") + ".png")
    mask_pdf = [f for f in os.listdir(DEVICE) if f.endswith(".pdf") and not f.startswith("sensor")][0]
    want["mask"] = (os.path.join(DEVICE, mask_pdf), "screen-mask.png")
    out = {}
    for key, (pdf, png) in want.items():
        path = os.path.join(SIM_DIR, png)
        if not os.path.exists(path):
            _render_pdf(pdf, path, PT if key != "mask" else 1)  # the mask PDF is already 1320 x 2868
        out[key] = Image.open(path).convert("RGBA")
    return out


def _vgrad(w, h, top, bottom):
    g = Image.linear_gradient("L").resize((w, h))
    return Image.composite(Image.new("RGB", (w, h), bottom), Image.new("RGB", (w, h), top), g)


def device_frame():
    """The phone without its screen content, at 3x, as RGBA: (image, screen box, outline mask)."""
    if "frame" in _DEVICE_CACHE:
        return _DEVICE_CACHE["frame"]
    a = _sim_assets()
    body_a = a["composite"].getchannel("A")
    bw, bh = body_a.size
    pad = 9 * PT
    W2, H2 = bw + 2 * pad, bh
    frame = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
    # Side buttons behind the body, titanium-shaded.
    for name, side, y in BUTTONS:
        m = a[name].getchannel("A")
        x = pad + 8 * PT - m.width if side == "left" else pad + bw - 8 * PT
        tint = _vgrad(m.width, m.height, (150, 150, 156), (86, 86, 92))
        frame.paste(tint, (x, y * PT), m)
    # The body: titanium edge, then the black border, both inside Apple's outline.
    outline = Image.new("L", (W2, H2), 0)
    outline.paste(body_a, (pad, 0))
    metal = _vgrad(W2, H2, (118, 118, 124), (74, 74, 80))
    frame.paste(metal, (0, 0), outline)
    # A bright line just inside the outer edge, the polished chamfer.
    inner1 = outline.filter(ImageFilter.MinFilter(9))
    hl = ImageChops_sub(outline, inner1)
    frame.paste(Image.new("RGB", (W2, H2), (196, 196, 202)), (0, 0), hl)
    # The black glass border: everything 9 pt inside the outline.
    glass = outline.filter(ImageFilter.MinFilter(13)).filter(ImageFilter.MinFilter(13))
    for _ in range(3):
        glass = glass.filter(ImageFilter.MinFilter(9))
    frame.paste(Image.new("RGB", (W2, H2), (8, 8, 9)), (0, 0), glass)
    sx, sy = pad + BORDER_PT * PT, BORDER_PT * PT
    screen_mask = a["mask"].getchannel("A")
    _DEVICE_CACHE["frame"] = (frame, (sx, sy, sx + screen_mask.width, sy + screen_mask.height), outline, screen_mask)
    return _DEVICE_CACHE["frame"]


def ImageChops_sub(a, b):
    from PIL import ImageChops
    return ImageChops.subtract(a, b)


def device(capture, island=True):
    """The phone showing `capture` (scaled to the 1320 x 2868 screen), at 3x, RGBA."""
    frame, (sx, sy, sx2, sy2), outline, screen_mask = device_frame()
    img = frame.copy()
    cap = capture if isinstance(capture, Image.Image) else Image.open(capture)
    cap = cap.convert("RGB").resize((sx2 - sx, sy2 - sy), Image.LANCZOS)
    img.paste(cap, (sx, sy), screen_mask)
    if island:
        sw = sx2 - sx
        iw, ih, top = round(sw * 0.2355), round(sw * 0.0912), round(sw * 0.0348)
        isl = Image.new("L", (iw * SS, ih * SS), 0)
        ImageDraw.Draw(isl).rounded_rectangle((0, 0, iw * SS, ih * SS), ih * SS // 2, fill=255)
        img.paste(Image.new("RGB", (iw, ih), (0, 0, 0)), (sx + (sw - iw) // 2, sy + top), isl.resize((iw, ih), Image.LANCZOS))
    return img, (sx, sy, sx2, sy2), outline


def place_device(canvas, capture, x, y, screen_w, cut=None, island=True, drop=(0.42, 60, 40), shadow_color=(0, 0, 0)):
    """Pastes the phone so its screen's top-left is at (x, y) and the screen is screen_w wide.
    Returns the screen box on the canvas."""
    img, (sx, sy, sx2, sy2), outline = device(capture, island)
    k = screen_w / (sx2 - sx)
    dw, dh = round(img.width * k), round(img.height * k)
    img = img.resize((dw, dh), Image.LANCZOS)
    ox, oy = round(x - sx * k), round(y - sy * k)
    if drop:
        op, blur, dy = drop
        # Blur on a margin wide enough for the whole falloff, so the shadow has no hard edge.
        m = blur * 3
        sh = Image.new("L", (dw + 2 * m, dh + 2 * m), 0)
        sh.paste(outline.resize((dw, dh), Image.LANCZOS), (m, m))
        sh = sh.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: round(v * op))
        canvas.paste(Image.new("RGB", sh.size, shadow_color), (ox - m, oy + dy - m), sh)
    if cut is not None and oy + dh > cut:
        img = img.crop((0, 0, dw, max(0, cut - oy)))
    canvas.paste(img, (ox, oy), img)
    return (x, y, x + screen_w, y + round((sy2 - sy) * k))


# ---------- phone (drawn; superseded by place_device) ----------

def phone(canvas, capture, x, y, screen_w, cut=None, rim=(40, 40, 44), rim_light=(118, 118, 124),
          drop=(0.38, 60, 40), island=True, screen_crop_top=0):
    """Draws an iPhone (18 Pro shape: thin black border, titanium rim, Dynamic Island) whose screen
    shows `capture` scaled to screen_w, top-left of the screen at (x, y). `cut` clips the phone at that
    canvas y (it runs off the slide). Returns the screen box on the canvas and the scale."""
    cap = capture if isinstance(capture, Image.Image) else Image.open(capture)
    cap = cap.convert("RGB")
    k = screen_w / cap.width
    sh = round(cap.height * k)
    border = round(screen_w * 0.020)
    rimw = round(screen_w * 0.010)
    sr = round(screen_w * 0.135)
    pw, ph = screen_w + 2 * (border + rimw), sh + 2 * (border + rimw)
    px, py = round(x - border - rimw), round(y - border - rimw)
    if drop:
        op, blur, dy = drop
        shadow(canvas, (px, py, px + pw, py + ph), sr + border + rimw, blur=blur, opacity=op, dy=dy)
    body = Image.new("RGB", (pw, ph), rim)
    # The rim: a light edge over the dark titanium.
    edge = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(edge).rectangle((0, 0, pw, ph), fill=255)
    inner = mask(pw - 4, ph - 4, sr + border + rimw - 2)
    edge.paste(0, (2, 2), inner)
    body.paste(Image.new("RGB", (pw, ph), rim_light), (0, 0), edge)
    blk = Image.new("RGB", (pw - 2 * rimw, ph - 2 * rimw), (6, 6, 7))
    body.paste(blk, (rimw, rimw), mask(blk.width, blk.height, sr + border))
    screen = cap.resize((screen_w, sh), Image.LANCZOS)
    body.paste(screen, (rimw + border, rimw + border), mask(screen_w, sh, sr))
    if island:
        iw, ih = round(screen_w * 0.305), round(screen_w * 0.090)
        ix, iy = rimw + border + (screen_w - iw) // 2, rimw + border + round(screen_w * 0.028)
        isl = Image.new("L", (iw * SS, ih * SS), 0)
        ImageDraw.Draw(isl).rounded_rectangle((0, 0, iw * SS, ih * SS), ih * SS // 2, fill=255)
        body.paste(Image.new("RGB", (iw, ih), (0, 0, 0)), (ix, iy), isl.resize((iw, ih), Image.LANCZOS))
    m = mask(pw, ph, sr + border + rimw)
    if cut is not None and py + ph > cut:
        keep = max(0, cut - py)
        body, m = body.crop((0, 0, pw, keep)), m.crop((0, 0, pw, keep))
    canvas.paste(body, (px, py), m)
    return (x, y, x + screen_w, y + sh), k


def zoom(canvas, capture, box, x, y, width, r=44, drop=(0.30, 46, 30), border=None, bg=None, pad=0):
    """Lifts the part `box` (capture pixels) out of a capture, enlarged to `width`, as a rounded card.
    `pad` adds a margin of `bg` (default: the capture's own colour at the box's corner) around it."""
    cap = capture if isinstance(capture, Image.Image) else Image.open(capture)
    cap = cap.convert("RGB")
    x0, y0, x1, y1 = box
    inner_w = width - 2 * pad
    inner_h = round((y1 - y0) * inner_w / (x1 - x0))
    card = Image.new("RGB", (width, inner_h + 2 * pad), bg or cap.getpixel((x0 + 4, y0 + 4)))
    card.paste(cap.crop(box).resize((inner_w, inner_h), Image.LANCZOS), (pad, pad))
    if drop:
        op, blur, dy = drop
        shadow(canvas, (x, y, x + card.width, y + card.height), r, blur=blur, opacity=op, dy=dy)
    if border:
        bw, bc = border
        b = Image.new("RGB", (card.width + 2 * bw, card.height + 2 * bw), bc)
        paste_rounded(canvas, b, x - bw, y - bw, r + bw)
    paste_rounded(canvas, card, x, y, r)
    return (x, y, x + card.width, y + card.height)


def icon(name):
    """An app icon from the screenshot-only asset catalog (tiktok, instagram, ...), or 'gymblock'."""
    if name == "gymblock":
        return Image.open(APP_ICON).convert("RGB")
    folder = os.path.join(ICONS, f"shot.{name}.imageset")
    png = [f for f in os.listdir(folder) if f.endswith(".png")][0]
    return Image.open(os.path.join(folder, png)).convert("RGBA")


def draw_icon(canvas, name, x, y, size, dim=0.0, gray=0.0, drop=(0.25, 18, 10)):
    """An app icon at (x, y), size px, with iOS's corner shape; `dim` darkens and `gray` desaturates
    it (Screen Time's look for a blocked app)."""
    im = icon(name).convert("RGB").resize((size, size), Image.LANCZOS)
    if gray:
        g = im.convert("L").convert("RGB")
        im = Image.blend(im, g, gray)
    if dim:
        im = Image.blend(im, Image.new("RGB", im.size, (0, 0, 0)), dim)
    r = round(size * 0.225)
    if drop:
        shadow(canvas, (x, y, x + size, y + size), r, blur=drop[1], opacity=drop[0], dy=drop[2])
    paste_rounded(canvas, im, x, y, r)
    return (x, y, x + size, y + size)


def pill(canvas, text, x, y, font, fg, bg, pad=(34, 18), r=None, align="left", border=None):
    draw = ImageDraw.Draw(canvas)
    tw = draw.textlength(text, font=font)
    asc, desc = font.getmetrics()
    w, h = round(tw + 2 * pad[0]), round(asc + desc * 0.4 + 2 * pad[1])
    if align == "center":
        x = x - w / 2
    r = r if r is not None else h // 2
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * SS, h * SS), r * SS, fill=255)
    m = m.resize((w, h), Image.LANCZOS)
    if border:
        bw, bc = border
        bm = Image.new("L", ((w + 2 * bw) * SS, (h + 2 * bw) * SS), 0)
        ImageDraw.Draw(bm).rounded_rectangle((0, 0, (w + 2 * bw) * SS, (h + 2 * bw) * SS), (r + bw) * SS, fill=255)
        canvas.paste(Image.new("RGB", (w + 2 * bw, h + 2 * bw), bc), (round(x) - bw, round(y) - bw), bm.resize((w + 2 * bw, h + 2 * bw), Image.LANCZOS))
    canvas.paste(Image.new("RGB", (w, h), bg), (round(x), round(y)), m)
    draw.text((x + pad[0], y + pad[1]), text, font=font, fill=fg)
    return (x, y, x + w, y + h)


def lock_badge(canvas, cx, cy, d, bg=(20, 20, 22), fg=(255, 255, 255)):
    """A round badge with a padlock, centred at (cx, cy), diameter d."""
    s = d * SS
    m = Image.new("L", (s, s), 0)
    ImageDraw.Draw(m).ellipse((0, 0, s, s), fill=255)
    lock = Image.new("L", (s, s), 0)
    dr = ImageDraw.Draw(lock)
    bw, bh = s * 0.44, s * 0.34
    bx, by = (s - bw) / 2, s * 0.47
    dr.rounded_rectangle((bx, by, bx + bw, by + bh), s * 0.07, fill=255)
    sw = s * 0.30
    t = s * 0.075
    dr.arc(((s - sw) / 2, s * 0.25, (s + sw) / 2, s * 0.25 + sw), 180, 360, fill=255, width=round(t))
    dr.line(((s - sw) / 2 + t / 2, s * 0.25 + sw / 2, (s - sw) / 2 + t / 2, by + 2), fill=255, width=round(t))
    dr.line(((s + sw) / 2 - t / 2, s * 0.25 + sw / 2, (s + sw) / 2 - t / 2, by + 2), fill=255, width=round(t))
    badge = Image.new("RGB", (s, s), bg)
    badge.paste(Image.new("RGB", (s, s), fg), (0, 0), lock)
    badge = badge.resize((d, d), Image.LANCZOS)
    canvas.paste(badge, (round(cx - d / 2), round(cy - d / 2)), m.resize((d, d), Image.LANCZOS))


# ---------- export ----------

def export(slide, folder, name):
    """Writes the slide to <folder>/<slot>/<name> for every slot: scaled to the slot's width,
    then trimmed or extended at the foot to its height."""
    for slot, (w, h) in SIZES.items():
        os.makedirs(os.path.join(folder, slot), exist_ok=True)
        if (w, h) == (W, H):
            out = slide
        else:
            sh = round(H * w / W)
            out = slide.resize((w, sh), Image.LANCZOS)
            if sh >= h:
                out = out.crop((0, 0, w, h))
            else:
                ext = Image.new("RGB", (w, h), out.getpixel((w // 2, sh - 1)))
                ext.paste(out, (0, 0))
                out = ext
        out.convert("RGB").save(os.path.join(folder, slot, name), optimize=True)


def overview(paths, out, width=446, gap=24, bg=(242, 242, 244)):
    shots = [Image.open(p) for p in paths]
    h = round(width * H / W)
    strip = Image.new("RGB", (len(shots) * (width + gap) + gap, h + 2 * gap), bg)
    for i, im in enumerate(shots):
        strip.paste(im.convert("RGB").resize((width, h), Image.LANCZOS), (gap + i * (width + gap), gap))
    strip.save(out)
