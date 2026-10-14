"""Generates src/assets/receipt-watermark.jpg: a plain 'DM' monogram (600x600 RGB JPEG)
that the receipt PDF stamps faintly in the middle of each page."""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'assets', 'receipt-watermark.jpg')
SIZE = 600

def load_font(size):
    for candidate in ('/System/Library/Fonts/HelveticaNeue.ttc', '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
                      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        if os.path.exists(candidate):
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()

img = Image.new('RGB', (SIZE, SIZE), (255, 255, 255))
d = ImageDraw.Draw(img)
d.ellipse((40, 40, SIZE - 40, SIZE - 40), outline=(20, 20, 20), width=28)
f = load_font(260)
box = d.textbbox((0, 0), 'DM', font=f)
d.text(((SIZE - (box[2] - box[0])) / 2 - box[0], (SIZE - (box[3] - box[1])) / 2 - box[1]), 'DM', font=f, fill=(20, 20, 20))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, 'JPEG', quality=85)
print('wrote', os.path.abspath(OUT))
