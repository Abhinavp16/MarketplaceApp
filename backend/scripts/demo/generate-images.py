#!/usr/bin/env python3
"""
Generates the placeholder PNGs shipped in assets/demo-images/ from the demo
fixtures (colored tile + product name). Requires Pillow. The generated files
are committed, so this only needs to be re-run when fixtures change:

    python3 scripts/demo/generate-images.py
"""
import json
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FIX = os.path.join(ROOT, 'scripts', 'demo', 'fixtures')
OUT = os.path.join(ROOT, 'assets', 'demo-images')

FONT_CANDIDATES_BOLD = [
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    '/Library/Fonts/Arial Bold.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf',
]
FONT_CANDIDATES = [
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    '/Library/Fonts/Arial.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/dejavu/DejaVuSans.ttf',
]


def font(size, bold=True):
    for path in (FONT_CANDIDATES_BOLD if bold else FONT_CANDIDATES):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


BRAND_COLORS = {
    'kestrel': ('#E8590C', '#FFF4E6'),
    'anvilpoint': ('#1C7ED6', '#E7F5FF'),
    'brightguard': ('#2F9E44', '#EBFBEE'),
    'tradehub': ('#5F3DC4', '#F3F0FF'),
}


def load(name):
    with open(os.path.join(FIX, name), encoding='utf-8') as fh:
        return json.load(fh)


def wrap(draw, text, fnt, max_width):
    words, lines, line = text.split(), [], ''
    for word in words:
        trial = (line + ' ' + word).strip()
        if draw.textlength(trial, font=fnt) <= max_width:
            line = trial
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def centered_block(draw, lines, fnt, cx, top, fill, spacing=10):
    y = top
    for line in lines:
        w = draw.textlength(line, font=fnt)
        draw.text((cx - w / 2, y), line, font=fnt, fill=fill)
        y += fnt.size + spacing
    return y


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, 'PNG', optimize=True)


def tile(size, brand_key, title, subtitle, footer='TradeHub Demo - placeholder image'):
    strong, tint = BRAND_COLORS[brand_key]
    img = Image.new('RGB', (size, size), tint)
    d = ImageDraw.Draw(img)
    bar = int(size * 0.14)
    d.rectangle([0, 0, size, bar], fill=strong)
    d.text((size * 0.05, bar * 0.22), subtitle.upper(), font=font(int(bar * 0.5)), fill='white')
    # decorative ring
    r = int(size * 0.25)
    cx, cy = size // 2, int(size * 0.42)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=strong)
    d.ellipse([cx - r + 18, cy - r + 18, cx + r - 18, cy + r - 18], outline='white', width=6)
    initials = ''.join(w[0] for w in title.replace('(', ' ').split() if w[0].isalpha())[:2].upper()
    f_init = font(int(r * 0.9))
    w = d.textlength(initials, font=f_init)
    d.text((cx - w / 2, cy - f_init.size * 0.6), initials, font=f_init, fill='white')
    f_title = font(int(size * 0.055))
    lines = wrap(d, title, f_title, size * 0.88)[:3]
    centered_block(d, lines, f_title, size / 2, int(size * 0.72), '#1B1B1F', spacing=8)
    f_foot = font(int(size * 0.028), bold=False)
    fw = d.textlength(footer, font=f_foot)
    d.text((size / 2 - fw / 2, size * 0.955), footer, font=f_foot, fill='#5C5F66')
    return img


def banner(width, height, brand_key, headline, sub, tag):
    strong, tint = BRAND_COLORS[brand_key]
    img = Image.new('RGB', (width, height), strong)
    d = ImageDraw.Draw(img)
    d.rectangle([int(width * 0.62), 0, width, height], fill=tint)
    d.ellipse([int(width * 0.66), int(height * 0.12), int(width * 0.98), int(height * 0.12) + int(width * 0.32)], fill=strong)
    d.text((width * 0.05, height * 0.14), tag.upper(), font=font(int(height * 0.07)), fill='#FFE8CC')
    f_head = font(int(height * 0.14))
    y = height * 0.28
    for line in wrap(d, headline, f_head, width * 0.52)[:3]:
        d.text((width * 0.05, y), line, font=f_head, fill='white')
        y += f_head.size + 10
    f_sub = font(int(height * 0.065), bold=False)
    for line in wrap(d, sub, f_sub, width * 0.52)[:3]:
        d.text((width * 0.05, y + 14), line, font=f_sub, fill='#F1F3F5')
        y += f_sub.size + 8
    return img


def logo(size, brand_key, text):
    strong, tint = BRAND_COLORS[brand_key]
    img = Image.new('RGB', (size, size), tint)
    d = ImageDraw.Draw(img)
    r = int(size * 0.42)
    c = size // 2
    d.ellipse([c - r, c - r, c + r, c + r], fill=strong)
    initials = ''.join(w[0] for w in text.split()[:2]).upper()
    f = font(int(size * 0.34))
    w = d.textlength(initials, font=f)
    d.text((c - w / 2, c - f.size * 0.6), initials, font=f, fill='white')
    f2 = font(int(size * 0.075))
    lines = wrap(d, text, f2, size * 0.9)[:2]
    centered_block(d, lines, f2, c, int(size * 0.90) - len(lines) * f2.size, '#1B1B1F', spacing=4)
    return img


def receipt():
    img = Image.new('RGB', (600, 800), 'white')
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 600, 90], fill=BRAND_COLORS['tradehub'][0])
    d.text((30, 28), 'DEMO PAYMENT PROOF', font=font(32), fill='white')
    y = 130
    for row in ['Transfer reference: DEMO-TRF-0001', 'Amount: 21,600.00 INR', 'Status: SUCCESS', 'Beneficiary: TradeHub Distribution (Demo)', '', 'Sample image - no real transaction.']:
        d.text((30, y), row, font=font(24, bold=False), fill='#1B1B1F')
        y += 44
    return img


def proof(title, lines):
    img = Image.new('RGB', (640, 420), '#F8F9FA')
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 640, 70], fill=BRAND_COLORS['anvilpoint'][0])
    d.text((24, 18), title, font=font(30), fill='white')
    y = 110
    for row in lines:
        d.text((24, y), row, font=font(24, bold=False), fill='#1B1B1F')
        y += 44
    d.text((24, 372), 'Sample document - fictional data', font=font(18, bold=False), fill='#5C5F66')
    return img


def main():
    brands = {b['key']: b for b in load('brands.json')}
    cats = {c['key']: c for c in load('categories.json')}

    def brand_of(cat_key):
        return cats[cat_key]['brand']

    for p in load('products.json'):
        b = brand_of(p['category'])
        img = tile(800, b, p['name'], brands[b]['name'])
        save(img, p['image'])

    for c in cats.values():
        img = tile(600, c['brand'], c['name'], brands[c['brand']]['name'], footer='Category - placeholder image')
        save(img, c['image'])

    for b in brands.values():
        save(logo(400, b['key'], b['name']), b['logo'])

    save(logo(512, 'tradehub', 'TradeHub Demo'), 'logo.png')

    save(banner(1600, 600, 'kestrel', 'Distribution made simple', 'Tools, fasteners and safety gear at trade prices', 'TradeHub Demo'), 'banners/hero-1.png')
    save(banner(1600, 600, 'anvilpoint', 'Negotiate bulk prices', 'Wholesale partners can request a better rate on any product', 'For wholesalers'), 'banners/hero-2.png')
    save(banner(1200, 500, 'brightguard', 'Safety first', 'Helmets, gloves and boots in stock', 'Safety Gear'), 'banners/promo-1.png')
    save(receipt(), 'payments/sample-payment-proof.png')
    # Private wholesaler-application proofs: stored outside the public tree and
    # copied into the private media store by the seed.
    private_dir = os.path.join(ROOT, 'assets', 'demo-private')
    os.makedirs(private_dir, exist_ok=True)
    proof('SHOP FRONT (SAMPLE)', ['NewCo Traders', '9 Station Lane, Sample City', 'Demo State 000000']).save(os.path.join(private_dir, 'proof-shopfront.png'), 'PNG', optimize=True)
    proof('TRADE REGISTRATION (SAMPLE)', ['Registered name: NewCo Traders', 'Registration no: 00DDDDD0000D1Z0', 'Status: ACTIVE']).save(os.path.join(private_dir, 'proof-registration.png'), 'PNG', optimize=True)
    print('Generated images in', OUT)


if __name__ == '__main__':
    main()
