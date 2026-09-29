#!/usr/bin/env python3
"""
Generates the *synthetic* images shipped in assets/demo-images/:

  * brands/*.png        - minimal wordmark logos for the three fictional brands
  * logo.png            - "TradeHub Demo" wordmark
  * payments/*.png      - a fake payment receipt
  * ../demo-private/*   - fake wholesaler application proofs

Product, category and banner images are real CC0 / public-domain photographs,
processed once with Pillow and committed as JPEG (see assets/demo-images/CREDITS.md).
They are NOT produced by this script.

Requires Pillow. The generated files are committed, so this only needs to be
re-run when the brand fixtures change:

    python3 scripts/demo/generate-images.py
"""
import json
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FIX = os.path.join(ROOT, 'scripts', 'demo', 'fixtures')
OUT = os.path.join(ROOT, 'assets', 'demo-images')
SITE_FONTS = os.path.abspath(os.path.join(ROOT, '..', 'site', 'public', 'fonts', 'cabinet-grotesk'))

SS = 4  # supersampling factor for smooth edges

INK = (22, 28, 38)
BRANDS = {
    'kestrel': {'color': (232, 89, 12), 'word': ('KESTREL', 'WORKS')},
    'anvilpoint': {'color': (28, 126, 214), 'word': ('ANVILPOINT', 'HAND TOOLS')},
    'brightguard': {'color': (47, 158, 68), 'word': ('BRIGHTGUARD', 'SAFETY')},
    'tradehub': {'color': (13, 148, 136), 'word': ('TRADEHUB', 'DEMO')},
}


def font_path(weight='Extrabold'):
    candidates = [
        os.path.join(SITE_FONTS, 'CabinetGrotesk-%s.otf' % weight),
        '/System/Library/Fonts/HelveticaNeue.ttc',
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return None


def font(size, weight='Extrabold'):
    path = font_path(weight)
    return ImageFont.truetype(path, size) if path else ImageFont.load_default()


def text_width(draw, text, fnt, tracking=0):
    return sum(draw.textlength(ch, font=fnt) for ch in text) + tracking * (len(text) - 1)


def draw_tracked(draw, x, y, text, fnt, fill, tracking=0):
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + tracking
    return x


# ---- marks, each designed in a 100x100 box, scaled by s and offset by ox/oy ----
def _pts(ox, oy, s, pts):
    return [(ox + x * s, oy + y * s) for x, y in pts]


def mark_kestrel(d, ox, oy, s, color):
    """A stooping kestrel seen from above: swept wings around a notched head."""
    d.polygon(_pts(ox, oy, s, [(0, 18), (34, 18), (50, 46), (66, 18), (100, 18), (58, 88), (42, 88)]), fill=color)
    d.polygon(_pts(ox, oy, s, [(38, 18), (50, 36), (62, 18)]), fill=(255, 255, 255))


def mark_anvilpoint(d, ox, oy, s, color):
    """Abstract anvil: pointed horn, flat face and base."""
    d.polygon(_pts(ox, oy, s, [(0, 24), (100, 24), (100, 44), (68, 48), (62, 68), (84, 68), (84, 90), (30, 90),
                               (30, 68), (52, 68), (46, 48), (32, 44)]), fill=color)


def mark_brightguard(d, ox, oy, s, color):
    """Shield with a rising sun."""
    d.polygon(_pts(ox, oy, s, [(50, 2), (92, 16), (90, 52), (72, 80), (50, 98), (28, 80), (10, 52), (8, 16)]), fill=color)
    white = (255, 255, 255)
    d.pieslice([ox + 27 * s, oy + 44 * s, ox + 73 * s, oy + 90 * s], 180, 360, fill=white)
    for tri in [((50, 20), (45, 36), (55, 36)), ((28, 30), (31, 43), (40, 37)), ((72, 30), (69, 43), (60, 37))]:
        d.polygon(_pts(ox, oy, s, tri), fill=white)


def mark_tradehub(d, ox, oy, s, color):
    """Stacked crates."""
    d.rounded_rectangle([ox + 4 * s, oy + 52 * s, ox + 48 * s, oy + 96 * s], radius=6 * s, fill=color)
    d.rounded_rectangle([ox + 52 * s, oy + 52 * s, ox + 96 * s, oy + 96 * s], radius=6 * s, fill=color)
    d.rounded_rectangle([ox + 28 * s, oy + 6 * s, ox + 72 * s, oy + 48 * s], radius=6 * s, fill=(94, 234, 212))


MARKS = {'kestrel': mark_kestrel, 'anvilpoint': mark_anvilpoint, 'brightguard': mark_brightguard, 'tradehub': mark_tradehub}


def lockup(key, w, h, horizontal=False):
    """Mark + wordmark lock-up rendered at w x h on white."""
    brand = BRANDS[key]
    color = brand['color']
    main, sub = brand['word']
    big = Image.new('RGB', (w * SS, h * SS), 'white')
    d = ImageDraw.Draw(big)
    if horizontal:
        mark_h = h * SS * 0.5
        f_main = font(int(h * SS * 0.30))
        f_sub = font(int(h * SS * 0.12), 'Bold')
    else:
        mark_h = h * SS * 0.38
        f_main = font(int(w * SS * (0.118 if len(main) > 8 else 0.165)))
        f_sub = font(int(w * SS * 0.052), 'Bold')
    tm = int(f_main.size * 0.04)
    ts = int(f_sub.size * 0.45)
    mw = text_width(d, main, f_main, tm)
    sw = text_width(d, sub, f_sub, ts)
    s = mark_h / 100.0
    text_h = f_main.size * 1.12 + f_sub.size * 1.2
    if horizontal:
        gap = h * SS * 0.14
        block = 100 * s + gap + max(mw, sw)
        x0 = (w * SS - block) / 2
        MARKS[key](d, x0, (h * SS - mark_h) / 2, s, color)
        tx, ty = x0 + 100 * s + gap, (h * SS - text_h) / 2
        draw_tracked(d, tx, ty, main, f_main, INK, tm)
        draw_tracked(d, tx, ty + f_main.size * 1.12, sub, f_sub, color, ts)
    else:
        gap = h * SS * 0.07
        top = (h * SS - (mark_h + gap + text_h)) / 2
        MARKS[key](d, (w * SS - 100 * s) / 2, top, s, color)
        ty = top + mark_h + gap
        draw_tracked(d, (w * SS - mw) / 2, ty, main, f_main, INK, tm)
        draw_tracked(d, (w * SS - sw) / 2, ty + f_main.size * 1.12, sub, f_sub, color, ts)
    return big.resize((w, h), Image.LANCZOS)


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, 'PNG', optimize=True)


def sysfont(size, bold=False):
    for path in ['/System/Library/Fonts/Supplemental/Arial%s.ttf' % (' Bold' if bold else ''),
                 '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if bold else '')]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def receipt():
    img = Image.new('RGB', (600, 800), 'white')
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 600, 90], fill=BRANDS['tradehub']['color'])
    d.text((30, 28), 'DEMO PAYMENT PROOF', font=sysfont(32, True), fill='white')
    y = 130
    for row in ['Transfer reference: DEMO-TRF-0001', 'Amount: 21,600.00 INR', 'Status: SUCCESS',
                'Beneficiary: TradeHub Distribution (Demo)', '', 'Sample image - no real transaction.']:
        d.text((30, y), row, font=sysfont(24), fill='#1B1B1F')
        y += 44
    return img


def proof(title, lines):
    img = Image.new('RGB', (640, 420), '#F8F9FA')
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 640, 70], fill=BRANDS['anvilpoint']['color'])
    d.text((24, 18), title, font=sysfont(30, True), fill='white')
    y = 110
    for row in lines:
        d.text((24, y), row, font=sysfont(24), fill='#1B1B1F')
        y += 44
    d.text((24, 372), 'Sample document - fictional data', font=sysfont(18), fill='#5C5F66')
    return img


def main():
    with open(os.path.join(FIX, 'brands.json'), encoding='utf-8') as fh:
        brands = json.load(fh)
    for b in brands:
        save(lockup(b['key'], 600, 600), b['logo'])
    save(lockup('tradehub', 1000, 300, horizontal=True), 'logo.png')
    save(receipt(), 'payments/sample-payment-proof.png')
    private_dir = os.path.join(ROOT, 'assets', 'demo-private')
    os.makedirs(private_dir, exist_ok=True)
    proof('SHOP FRONT (SAMPLE)', ['NewCo Traders', '9 Station Lane, Sample City', 'Demo State 000000']).save(os.path.join(private_dir, 'proof-shopfront.png'), 'PNG', optimize=True)
    proof('TRADE REGISTRATION (SAMPLE)', ['Registered name: NewCo Traders', 'Registration no: 00DDDDD0000D1Z0', 'Status: ACTIVE']).save(os.path.join(private_dir, 'proof-registration.png'), 'PNG', optimize=True)
    print('Generated synthetic images in', OUT)


if __name__ == '__main__':
    main()
