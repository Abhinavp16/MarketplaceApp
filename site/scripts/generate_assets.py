#!/usr/bin/env python3
"""Generate the *synthetic* brand graphics for the DemoMart site with Pillow.

Run from the site/ directory:  python3 scripts/generate_assets.py   (or: npm run assets)

Outputs (all committed):
  public/logo.png, logo-mark.png, favicon*, apple-touch-icon.png, og-image.png
  public/demo/brands/brand-tile-*.png   - resized copies of the backend wordmark logos
  public/demo/*-placeholder.png         - neutral "no image" placeholders
  public/demo/banner/app-preview.png    - phone frame around docs/screenshots/app-home.png (if present)

Photographs under public/demo/{hero,categories,about,insights,banner} are real CC0 /
public-domain photos processed once (see backend/assets/demo-images/CREDITS.md) and are
NOT produced by this script.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBLIC = os.path.join(ROOT, "public")
FONT_BOLD = os.path.join(PUBLIC, "fonts", "cabinet-grotesk", "CabinetGrotesk-Extrabold.otf")

# Palette of the original platform site (leaf green + gold accent), see app/globals.css and
# the hard-coded hex values in components/ (#0b3b1f, #174f2c, #dfe8d3, #edf3e6, #1f8a3b, #d9a441...).
DEEP = (14, 74, 31)        # #0E4A1F
DARKER = (6, 39, 18)       # #062712
GREEN = (31, 138, 59)     # #1F8A3B  primary leaf green 
MID = (23, 79, 44)         # #174F2C
SOFT = (143, 191, 119)     # #8FBF77
LIGHT = (223, 232, 211)    # #DFE8D3
PALE = (237, 243, 230)     # #EDF3E6
GOLD = (217, 164, 65)      # #D9A441  gold accent used by the footer glow
GOLD_D = (179, 128, 40)
GOLD_L = (244, 201, 107)   # #F4C96B
WHITE = (255, 255, 255)
MARK_DOT = (158, 227, 176)  # #9EE3B0 light-green dot of the "D." mark
TILE_A = (15, 118, 41)     # tile gradient, sampled from app/assets/images/logo.png
TILE_B = (17, 95, 37)

SS = 2  # supersampling factor for smooth edges


def out(*parts):
    path = os.path.join(PUBLIC, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


class Canvas:
    """Draw with final-size coordinates; internally rendered at SS x for anti-aliasing."""

    def __init__(self, w, h, bg=None, gradient=None, transparent=False):
        self.w, self.h = w, h
        mode = "RGBA"
        if transparent:
            self.img = Image.new(mode, (w * SS, h * SS), (0, 0, 0, 0))
        elif gradient:
            c1, c2 = gradient
            base = Image.linear_gradient("L").resize((w * SS, h * SS))
            base = base.rotate(0)
            self.img = Image.composite(
                Image.new(mode, (w * SS, h * SS), c2 + (255,)),
                Image.new(mode, (w * SS, h * SS), c1 + (255,)),
                base,
            )
        else:
            self.img = Image.new(mode, (w * SS, h * SS), (bg or WHITE) + (255,))
        self.d = ImageDraw.Draw(self.img, "RGBA")

    def s(self, v):
        return [x * SS for x in v] if isinstance(v, (list, tuple)) else v * SS

    def poly(self, pts, fill):
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill)

    def rect(self, box, fill, r=0):
        x0, y0, x1, y1 = box
        if r:
            self.d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius=r * SS, fill=fill)
        else:
            self.d.rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=fill)

    def circle(self, cx, cy, r, fill, outline=None, width=0):
        self.d.ellipse(
            [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS],
            fill=fill,
            outline=outline,
            width=width * SS,
        )

    def line(self, pts, fill, width=4):
        self.d.line([(x * SS, y * SS) for x, y in pts], fill=fill, width=int(width * SS), joint="curve")

    def arc(self, box, start, end, fill, width=4):
        x0, y0, x1, y1 = box
        self.d.arc([x0 * SS, y0 * SS, x1 * SS, y1 * SS], start, end, fill=fill, width=int(width * SS))

    def pieslice(self, box, start, end, fill):
        x0, y0, x1, y1 = box
        self.d.pieslice([x0 * SS, y0 * SS, x1 * SS, y1 * SS], start, end, fill=fill)

    def cube(self, cx, cy, size, top=SOFT, left=GREEN, right=DEEP):
        w, h = size * 0.866, size * 0.5
        self.poly([(cx, cy), (cx + w, cy - h), (cx, cy - 2 * h), (cx - w, cy - h)], top)
        self.poly([(cx, cy), (cx + w, cy - h), (cx + w, cy - h + size), (cx, cy + size)], right)
        self.poly([(cx, cy), (cx - w, cy - h), (cx - w, cy - h + size), (cx, cy + size)], left)
        # tape line on top face for a "carton" look
        self.line([(cx - w / 2, cy - 1.25 * h), (cx + w / 2, cy - 0.75 * h)], mix(top, WHITE, 0.55), width=max(2, size * 0.06))

    def finish(self):
        return self.img.resize((self.w, self.h), Image.LANCZOS)


def cube_stack(c, cx, base_y, size, rows, top=SOFT, left=GREEN, right=DEEP, accent=None):
    """Pyramid of cubes in a simple isometric arrangement (front-facing rows)."""
    w = size * 0.866
    y = base_y
    for r in range(rows):
        n = rows - r
        start = cx - (n - 1) * w
        for i in range(n):
            col = (top, left, right)
            if accent and (r + i) % 3 == 0:
                col = (GOLD_L, GOLD, GOLD_D)
            c.cube(start + i * 2 * w, y, size, *col)
        y -= size * 1.5


def floating_dots(c, seed, count=14, w=1920, h=1080, cols=(GOLD_L, SOFT, WHITE)):
    import random

    rnd = random.Random(seed)
    for _ in range(count):
        x, y = rnd.randint(0, w), rnd.randint(0, h)
        r = rnd.randint(6, 26)
        col = rnd.choice(cols)
        c.circle(x, y, r, col + (rnd.randint(30, 90),))


def font(size):
    try:
        return ImageFont.truetype(FONT_BOLD, size)
    except OSError:
        return ImageFont.load_default()


# --------------------------------------------------------------------------- logo / favicon / og


def _rr_mask(size, box, r, corners):
    """Anti-aliased rounded-rectangle mask. box is in 512-unit coordinates."""
    k = 4 * size / 512
    m = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([v * k for v in box], radius=r * k, fill=255, corners=corners)
    return m


def logo_mark(size=512, rounded=False):
    """DemoMart 'D.' mark: white D + light-green dot on a green gradient tile
    (same artwork as app/assets/images/logo.png)."""
    from PIL import ImageChops

    # Diagonal gradient, top-left -> bottom-right.
    tile = Image.new("RGBA", (size, size))
    px = []
    den = 2.0 * (size - 1)
    for y in range(size):
        for x in range(size):
            t = (x + y) / den
            px.append(tuple(int(TILE_A[i] + (TILE_B[i] - TILE_A[i]) * t) for i in range(3)) + (255,))
    tile.putdata(px)
    # D body: small radius on the stem side, large radius on the bowl side.
    stem = _rr_mask(size, (106, 114, 342, 398), 22, (True, True, True, True))
    bowl = _rr_mask(size, (106, 114, 342, 398), 112, (False, True, True, False))
    body = ImageChops.darker(stem, bowl)
    cstem = _rr_mask(size, (180, 186, 270, 324), 10, (True, True, True, True))
    cbowl = _rr_mask(size, (180, 186, 270, 324), 46, (False, True, True, False))
    counter = ImageChops.darker(cstem, cbowl)
    d_mask = ImageChops.subtract(body, counter).resize((size, size), Image.LANCZOS)
    tile.paste(Image.new("RGBA", (size, size), WHITE + (255,)), (0, 0), d_mask)
    dot = Image.new("L", (size * 4, size * 4), 0)
    k = 4 * size / 512
    ImageDraw.Draw(dot).ellipse([(388 - 26) * k, (372 - 26) * k, (388 + 26) * k, (372 + 26) * k], fill=255)
    tile.paste(Image.new("RGBA", (size, size), MARK_DOT + (255,)), (0, 0), dot.resize((size, size), Image.LANCZOS))
    if rounded:
        m = Image.new("L", (size * 4, size * 4), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=size * 4 * 0.22, fill=255)
        tile.putalpha(m.resize((size, size), Image.LANCZOS))
    return tile


def build_logo():
    mark = logo_mark(512)
    mark.save(out("logo-mark.png"))
    mark.resize((512, 512), Image.LANCZOS).save(out("favicon-512.png"))
    mark.resize((192, 192), Image.LANCZOS).save(out("favicon.png"))
    mark.resize((180, 180), Image.LANCZOS).save(out("apple-touch-icon.png"))
    mark.save(
        out("favicon.ico"),
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64)],
    )
    # horizontal wordmark
    w, h = 1100, 260
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    img.alpha_composite(logo_mark(220, rounded=True), (20, 20))
    d = ImageDraw.Draw(img)
    d.text((270, 40), "DemoMart", font=font(120), fill=DEEP + (255,))
    d.text((272, 158), "DEMO  -  Distribution made simple", font=font(50), fill=GREEN + (255,))
    img.save(out("logo.png"))


def build_og():
    w, h = 1200, 630
    c = Canvas(w, h, gradient=(DEEP, GREEN))
    floating_dots(c, 3, 12, w, h)
    cube_stack(c, 930, 470, 80, 3, accent=True)
    img = c.finish()
    img.alpha_composite(logo_mark(200, rounded=True), (70, 90))
    d = ImageDraw.Draw(img)
    d.text((70, 320), "DemoMart", font=font(96), fill=WHITE)
    d.text((72, 440), "Distribution made simple", font=font(46), fill=GOLD_L)
    d.text((72, 530), "Demonstration environment - synthetic data", font=font(30), fill=LIGHT)
    img.convert("RGB").save(out("og-image.png"))


# --------------------------------------------------------------------------- placeholders / tiles


def neutral_placeholder(w, h, label):
    c = Canvas(w, h, gradient=(PALE, LIGHT))
    cx, cy = w / 2, h / 2 - h * 0.04
    r = min(w, h) * 0.16
    c.rect((cx - r * 1.5, cy - r, cx + r * 1.5, cy + r), (200, 214, 184), r=r * 0.18)
    c.circle(cx - r * 0.7, cy - r * 0.35, r * 0.24, PALE)
    c.poly([(cx - r * 1.3, cy + r * 0.85), (cx - r * 0.3, cy - r * 0.15), (cx + r * 0.3, cy + r * 0.45), (cx + r * 0.7, cy + r * 0.05), (cx + r * 1.3, cy + r * 0.85)], PALE)
    img = c.finish().convert("RGB")
    d = ImageDraw.Draw(img)
    f = font(int(min(w, h) * 0.05))
    tw = d.textlength(label, font=f)
    d.text(((w - tw) / 2, cy + r * 1.35), label, font=f, fill=(111, 131, 103))
    return img


def brand_tile(key):
    src = os.path.join(ROOT, "..", "backend", "assets", "demo-images", "brands", f"{key}.png")
    logo = Image.open(src).convert("RGB")
    tile = Image.new("RGB", (600, 400), WHITE)
    logo = logo.resize((400, 400), Image.LANCZOS)
    tile.paste(logo, (100, 0))
    return tile


def app_preview():
    """Phone frame around a real app screenshot (docs/screenshots/app-home.png)."""
    shot_path = os.path.join(ROOT, "..", "docs", "screenshots", "app-home.png")
    if not os.path.exists(shot_path):
        return None
    shot = Image.open(shot_path).convert("RGB")
    ph_h = 640
    ph_w = int(ph_h * shot.width / shot.height)
    pad = 14
    W, H = 1040, 700
    SSx = 3
    frame = Image.new("RGBA", (W * SSx, H * SSx), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    x0 = 90 * SSx
    y0 = 40 * SSx
    d.rounded_rectangle([x0, y0, x0 + (ph_w + 2 * pad) * SSx, y0 + (ph_h + 2 * pad) * SSx], radius=44 * SSx, fill=DARKER + (255,))
    screen = shot.resize((ph_w * SSx, ph_h * SSx), Image.LANCZOS)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen.width - 1, screen.height - 1], radius=32 * SSx, fill=255)
    frame.paste(screen, (x0 + pad * SSx, y0 + pad * SSx), mask)
    return frame.resize((W, H), Image.LANCZOS)


def main():
    build_logo()
    build_og()
    for i, key in enumerate(("kestrel", "anvilpoint", "brightguard"), 1):
        brand_tile(key).save(out("demo", "brands", f"brand-tile-{i}.png"), optimize=True)
    brand_tile("kestrel").save(out("demo", "brand-placeholder.png"), optimize=True)
    neutral_placeholder(800, 800, "Image coming soon").save(out("demo", "product-placeholder.png"), optimize=True)
    neutral_placeholder(800, 520, "Image coming soon").save(out("demo", "category-placeholder.png"), optimize=True)
    preview = app_preview()
    if preview is not None:
        preview.save(out("demo", "banner", "app-preview.png"), optimize=True)
    print("assets generated in", PUBLIC)


if __name__ == "__main__":
    main()
