#!/usr/bin/env python3
"""Generate all generic demo images for the TradeHub Demo site with Pillow.

Run from the site/ directory:  python3 scripts/generate_assets.py
Outputs go to public/ (logo, favicon, OG image) and public/demo/** (banners, tiles, placeholders).
Every graphic is a simple flat, synthetic illustration in an indigo/teal palette.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBLIC = os.path.join(ROOT, "public")
FONT_BOLD = os.path.join(PUBLIC, "fonts", "cabinet-grotesk", "CabinetGrotesk-Extrabold.otf")

DEEP = (30, 27, 75)
DARKER = (23, 21, 59)
INDIGO = (55, 48, 163)
MID = (79, 70, 229)
SOFT = (129, 140, 248)
LIGHT = (224, 231, 255)
PALE = (238, 242, 255)
TEAL = (13, 148, 136)
TEAL_D = (15, 118, 110)
TEAL_L = (94, 234, 212)
WHITE = (255, 255, 255)

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

    def cube(self, cx, cy, size, top=SOFT, left=INDIGO, right=DEEP):
        w, h = size * 0.866, size * 0.5
        self.poly([(cx, cy), (cx + w, cy - h), (cx, cy - 2 * h), (cx - w, cy - h)], top)
        self.poly([(cx, cy), (cx + w, cy - h), (cx + w, cy - h + size), (cx, cy + size)], right)
        self.poly([(cx, cy), (cx - w, cy - h), (cx - w, cy - h + size), (cx, cy + size)], left)
        # tape line on top face for a "carton" look
        self.line([(cx - w / 2, cy - 1.25 * h), (cx + w / 2, cy - 0.75 * h)], mix(top, WHITE, 0.55), width=max(2, size * 0.06))

    def finish(self):
        return self.img.resize((self.w, self.h), Image.LANCZOS)


def cube_stack(c, cx, base_y, size, rows, top=SOFT, left=INDIGO, right=DEEP, accent=None):
    """Pyramid of cubes in a simple isometric arrangement (front-facing rows)."""
    w = size * 0.866
    y = base_y
    for r in range(rows):
        n = rows - r
        start = cx - (n - 1) * w
        for i in range(n):
            col = (top, left, right)
            if accent and (r + i) % 3 == 0:
                col = (TEAL_L, TEAL, TEAL_D)
            c.cube(start + i * 2 * w, y, size, *col)
        y -= size * 1.5


def floating_dots(c, seed, count=14, w=1920, h=1080, cols=(TEAL_L, SOFT, WHITE)):
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


def logo_mark(size=512):
    c = Canvas(size, size, transparent=True)
    c.circle(size / 2, size / 2, size / 2, DEEP + (255,))
    c.circle(size / 2, size / 2, size * 0.47, INDIGO + (255,))
    s = size * 0.27
    c.cube(size / 2, size * 0.5, s, top=WHITE, left=LIGHT, right=TEAL_L)
    return c.finish()


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
    img.alpha_composite(mark.resize((220, 220), Image.LANCZOS), (20, 20))
    d = ImageDraw.Draw(img)
    d.text((270, 40), "TradeHub", font=font(120), fill=DEEP + (255,))
    d.text((272, 158), "DEMO  -  Distribution made simple", font=font(50), fill=TEAL + (255,))
    img.save(out("logo.png"))


def build_og():
    w, h = 1200, 630
    c = Canvas(w, h, gradient=(DEEP, INDIGO))
    floating_dots(c, 3, 12, w, h)
    cube_stack(c, 930, 470, 80, 3, accent=True)
    img = c.finish()
    mark = logo_mark(200)
    img.alpha_composite(mark, (70, 90))
    d = ImageDraw.Draw(img)
    d.text((70, 320), "TradeHub Demo", font=font(96), fill=WHITE)
    d.text((72, 440), "Distribution made simple", font=font(46), fill=TEAL_L)
    d.text((72, 530), "Demonstration environment - synthetic data", font=font(30), fill=LIGHT)
    img.convert("RGB").save(out("og-image.png"))


# --------------------------------------------------------------------------- hero banners (1920x1080)


def hero_scene(idx):
    w, h = 1920, 1080
    grads = [(DEEP, INDIGO), (DARKER, TEAL_D), (INDIGO, DEEP), (DEEP, TEAL_D), (DARKER, INDIGO)]
    c = Canvas(w, h, gradient=grads[idx - 1])
    floating_dots(c, idx, 18, w, h)
    if idx == 1:
        cube_stack(c, 1450, 900, 130, 4, accent=True)
        cube_stack(c, 380, 950, 90, 3)
    elif idx == 2:
        # warehouse shelving
        for x0 in (160, 700, 1240):
            for row in range(4):
                y = 250 + row * 190
                c.rect((x0, y + 150, x0 + 470, y + 172), SOFT + (200,), 8)
                bx = x0 + 20
                for k in range(4):
                    bw = 90 + (k * 17 + row * 11) % 40
                    col = [(SOFT), (TEAL_L), (LIGHT), (MID)][(k + row) % 4]
                    c.rect((bx, y + 150 - 110, bx + bw, y + 150), col + (235,), 10)
                    bx += bw + 26
            c.rect((x0 - 8, 240, x0 + 6, 1000), PALE + (180,), 6)
            c.rect((x0 + 464, 240, x0 + 478, 1000), PALE + (180,), 6)
    elif idx == 3:
        # supply network
        pts = [(320, 300), (700, 220), (1080, 340), (1500, 240), (1650, 560), (1250, 720), (820, 640), (420, 720), (960, 480)]
        links = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 0), (8, 2), (8, 6), (8, 1), (8, 5)]
        for a, b in links:
            c.line([pts[a], pts[b]], PALE + (110,), 5)
        for i, (x, y) in enumerate(pts):
            r = 62 if i == 8 else 34
            c.circle(x, y, r + 14, WHITE + (40,))
            c.circle(x, y, r, TEAL_L if i % 2 else SOFT)
            c.circle(x, y, r * 0.42, DEEP)
    elif idx == 4:
        # delivery truck
        c.rect((260, 560, 1120, 860), PALE, 26)
        c.rect((1120, 640, 1560, 860), TEAL_L, 26)
        c.poly([(1330, 640), (1480, 640), (1560, 760), (1330, 760)], DEEP + (200,))
        for x in (480, 820, 1380):
            c.circle(x, 880, 84, DARKER)
            c.circle(x, 880, 44, LIGHT)
        c.rect((330, 620, 1050, 640), SOFT + (120,), 8)
        c.rect((330, 690, 800, 710), SOFT + (120,), 8)
        c.rect((0, 950, w, 1080), DARKER + (140,))
        cube_stack(c, 1700, 940, 60, 2, accent=True)
    else:
        # bar chart + cubes
        xs = [300 + i * 190 for i in range(7)]
        hs = [180, 260, 220, 380, 330, 470, 560]
        for x, hh in zip(xs, hs):
            c.rect((x, 900 - hh, x + 120, 900), SOFT + (230,), 14)
            c.rect((x, 900 - hh, x + 120, 900 - hh + 26), TEAL_L + (230,), 14)
        c.line([(x + 60, 900 - hh - 60) for x, hh in zip(xs, hs)], WHITE + (200,), 8)
        for x, hh in zip(xs, hs):
            c.circle(x + 60, 900 - hh - 60, 14, WHITE)
        cube_stack(c, 1650, 380, 70, 2)
    return c.finish().convert("RGB")


def build_hero():
    for i in range(1, 6):
        hero_scene(i).save(out("demo", "hero", f"hero-{i}.jpg"), quality=82, optimize=True)


# --------------------------------------------------------------------------- tiles


def tile_bg(w, h, variant=0):
    pairs = [(PALE, LIGHT), (LIGHT, (204, 240, 235)), (PALE, (201, 232, 228)), (LIGHT, PALE)]
    return Canvas(w, h, gradient=pairs[variant % len(pairs)])


def icon_drill(c, cx, cy, s):
    c.rect((cx - s * 0.75, cy - s * 0.35, cx + s * 0.35, cy + s * 0.2), INDIGO, s * 0.12)
    c.rect((cx - s * 0.42, cy + s * 0.1, cx - s * 0.05, cy + s * 0.85), DEEP, s * 0.08)
    c.rect((cx + s * 0.35, cy - s * 0.22, cx + s * 0.62, cy + s * 0.07), TEAL, s * 0.04)
    c.rect((cx + s * 0.62, cy - s * 0.1, cx + s * 1.05, cy - s * 0.03), MID, s * 0.02)
    c.rect((cx - s * 0.65, cy - s * 0.25, cx - s * 0.2, cy - s * 0.15), SOFT, s * 0.04)


def icon_wrench(c, cx, cy, s):
    c.line([(cx - s * 0.7, cy + s * 0.7), (cx + s * 0.45, cy - s * 0.45)], INDIGO, s * 0.26)
    c.circle(cx + s * 0.55, cy - s * 0.55, s * 0.4, INDIGO)
    c.circle(cx + s * 0.62, cy - s * 0.62, s * 0.2, PALE)
    c.poly([(cx + s * 0.62, cy - s * 0.62), (cx + s * 1.05, cy - s * 0.95), (cx + s * 0.95, cy - s * 0.5)], PALE)
    c.circle(cx - s * 0.7, cy + s * 0.7, s * 0.24, TEAL)


def icon_bolt(c, cx, cy, s):
    # hex nut
    pts = [(cx - s * 0.9 + s * 0.5 * math.cos(math.radians(a)) * 1.0, cy + s * 0.05 + s * 0.5 * math.sin(math.radians(a))) for a in range(0, 360, 60)]
    c.poly(pts, TEAL)
    c.circle(cx - s * 0.9, cy + s * 0.05, s * 0.2, PALE)
    # bolt
    c.rect((cx - s * 0.1, cy - s * 0.45, cx + s * 0.45, cy + s * 0.55), INDIGO, s * 0.08)
    c.rect((cx + s * 0.45, cy - s * 0.15, cx + s * 1.1, cy + s * 0.25), MID)
    for k in range(4):
        c.line([(cx + s * (0.55 + k * 0.14), cy - s * 0.15), (cx + s * (0.55 + k * 0.14), cy + s * 0.25)], PALE + (200,), s * 0.05)


def icon_helmet(c, cx, cy, s):
    c.pieslice((cx - s * 0.85, cy - s * 0.9, cx + s * 0.85, cy + s * 0.8), 180, 360, INDIGO)
    c.rect((cx - s * 1.05, cy - s * 0.05, cx + s * 1.05, cy + s * 0.2), DEEP, s * 0.1)
    c.rect((cx - s * 0.16, cy - s * 0.85, cx + s * 0.16, cy - s * 0.05), TEAL_L, s * 0.05)
    c.rect((cx - s * 0.62, cy - s * 0.55, cx - s * 0.5, cy - s * 0.1), SOFT, s * 0.03)


def category_tile(kind, variant):
    c = tile_bg(800, 520, variant)
    c.circle(650, 110, 150, WHITE + (110,))
    c.circle(120, 470, 110, TEAL_L + (70,))
    cx, cy, s = 400, 265, 150
    c.circle(cx, cy, 190, WHITE + (170,))
    {"power": icon_drill, "hand": icon_wrench, "fast": icon_bolt, "safe": icon_helmet}[kind](c, cx, cy, s)
    return c.finish().convert("RGB")


def brand_tile(idx):
    c = tile_bg(600, 400, idx)
    c.circle(300, 200, 150, WHITE + (200,))
    if idx == 1:
        c.circle(300, 200, 84, INDIGO)
        c.circle(300, 200, 40, TEAL_L)
    elif idx == 2:
        c.poly([(300, 108), (392, 290), (208, 290)], TEAL)
        c.poly([(300, 168), (350, 270), (250, 270)], PALE)
    else:
        c.rect((228, 128, 372, 272), INDIGO, 24)
        c.rect((262, 162, 338, 238), TEAL_L, 12)
    return c.finish().convert("RGB")


def placeholder_product():
    c = Canvas(800, 800, gradient=(PALE, LIGHT))
    c.circle(400, 400, 260, WHITE + (160,))
    c.cube(400, 380, 190, top=SOFT, left=INDIGO, right=DEEP)
    return c.finish().convert("RGB")


def placeholder_category():
    c = Canvas(800, 520, gradient=(PALE, LIGHT))
    for i in range(2):
        for j in range(2):
            c.rect((290 + i * 120, 150 + j * 120, 390 + i * 120, 250 + j * 120), [INDIGO, TEAL][(i + j) % 2], 20)
    return c.finish().convert("RGB")


# --------------------------------------------------------------------------- misc


def phone(c, x, y, w, h, accent=TEAL):
    c.rect((x, y, x + w, y + h), DEEP, 46)
    c.rect((x + 14, y + 14, x + w - 14, y + h - 14), PALE, 34)
    c.rect((x + w * 0.35, y + 26, x + w * 0.65, y + 40), DEEP, 8)
    c.rect((x + 34, y + 70, x + w - 34, y + 170), accent, 22)
    for k in range(3):
        yy = y + 200 + k * 120
        c.rect((x + 34, yy, x + w - 34, yy + 100), WHITE, 18)
        c.rect((x + 48, yy + 16, x + 118, yy + 84), LIGHT, 12)
        c.rect((x + 136, yy + 24, x + w - 60, yy + 40), SOFT, 6)
        c.rect((x + 136, yy + 52, x + w - 120, yy + 66), LIGHT, 6)


def app_preview():
    c = Canvas(1040, 700, transparent=True)
    phone(c, 120, 90, 330, 640, TEAL)
    phone(c, 430, 210, 330, 640, INDIGO)
    return c.finish().crop((0, 0, 1040, 700))


def dealer_partnership():
    c = Canvas(600, 600, transparent=True)
    c.circle(230, 300, 170, INDIGO + (255,))
    c.circle(370, 300, 170, TEAL + (215,))
    c.circle(300, 300, 96, WHITE + (255,))
    c.rect((262, 268, 338, 332), INDIGO, 12)
    c.line([(262, 300), (338, 300)], PALE, 6)
    for (x, y) in [(120, 120), (480, 130), (110, 480), (490, 470)]:
        c.circle(x, y, 26, SOFT)
    return c.finish()


def about_product():
    c = Canvas(900, 900, gradient=(LIGHT, PALE))
    c.circle(450, 450, 330, WHITE + (170,))
    cube_stack(c, 450, 640, 110, 3, accent=True)
    return c.finish().convert("RGB")


def about_card():
    c = Canvas(900, 900, gradient=(DEEP, INDIGO))
    for row in range(3):
        y = 170 + row * 230
        c.rect((90, y + 150, 810, y + 176), SOFT + (200,), 10)
        bx = 120
        for k in range(5):
            bw = 90 + (k * 23 + row * 13) % 50
            col = [SOFT, TEAL_L, LIGHT, MID, TEAL][(k + row) % 5]
            c.rect((bx, y + 40, bx + bw, y + 150), col, 12)
            bx += bw + 22
    return c.finish().convert("RGB")


def insight(idx):
    w, h = 1200, 750
    c = Canvas(w, h, gradient=[(DEEP, INDIGO), (DARKER, TEAL_D), (INDIGO, DEEP)][idx - 1])
    floating_dots(c, 40 + idx, 10, w, h)
    if idx == 1:  # checklist
        c.rect((380, 110, 820, 650), PALE, 34)
        c.rect((520, 80, 680, 150), TEAL, 22)
        for k in range(4):
            y = 200 + k * 105
            c.circle(450, y + 30, 26, TEAL)
            c.line([(438, y + 30), (448, y + 41), (464, y + 20)], WHITE, 7)
            c.rect((500, y + 12, 760, y + 30), SOFT, 9)
            c.rect((500, y + 40, 690, y + 54), LIGHT, 7)
    elif idx == 2:  # inventory + chart
        cube_stack(c, 380, 560, 100, 3, accent=True)
        for k, hh in enumerate([120, 200, 160, 280]):
            c.rect((700 + k * 100, 560 - hh, 770 + k * 100, 560), SOFT + (235,), 12)
        c.line([(735 + k * 100, 500 - hh) for k, hh in enumerate([120, 200, 160, 280])], TEAL_L, 8)
    else:  # pallet + truck
        c.rect((180, 470, 780, 560), PALE, 18)
        cube_stack(c, 380, 470, 90, 2, top=TEAL_L, left=TEAL, right=TEAL_D)
        c.rect((820, 400, 1030, 560), TEAL_L, 20)
        c.poly([(940, 400), (1000, 400), (1030, 470), (940, 470)], DEEP + (200,))
        for x in (300, 660, 900, 990):
            c.circle(x, 585, 34, DARKER)
            c.circle(x, 585, 16, LIGHT)
    return c.finish().convert("RGB")


def main():
    build_logo()
    build_og()
    build_hero()
    for kind, name, var in [("power", "power-tools", 0), ("hand", "hand-tools", 1), ("fast", "fasteners-fittings", 2), ("safe", "safety-gear", 3)]:
        category_tile(kind, var).save(out("demo", "categories", f"{name}.png"), optimize=True)
    for i in (1, 2, 3):
        brand_tile(i).save(out("demo", "brands", f"brand-tile-{i}.png"), optimize=True)
    placeholder_product().save(out("demo", "product-placeholder.png"), optimize=True)
    placeholder_category().save(out("demo", "category-placeholder.png"), optimize=True)
    brand_tile(1).save(out("demo", "brand-placeholder.png"), optimize=True)
    app_preview().save(out("demo", "banner", "app-preview.png"), optimize=True)
    dealer_partnership().save(out("demo", "banner", "dealer-partnership.png"), optimize=True)
    about_product().save(out("demo", "about", "about-product.png"), optimize=True)
    about_card().save(out("demo", "about", "about-card.png"), optimize=True)
    for i in (1, 2, 3):
        insight(i).save(out("demo", "insights", f"insight-{i}.png"), optimize=True)
    print("assets generated in", PUBLIC)


if __name__ == "__main__":
    main()
