#!/usr/bin/env python3
"""Generate packaging/AppIcon-1024.png.

Uses the branded 5IN1 icon (packaging/icon-source-1024.png) when present.
Falls back to the procedural "?" tile when it is missing.

Runs in CI (pip install pillow) so the icon binary is committed once and reused.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "icon-source-1024.png")
OUT = os.path.join(HERE, "AppIcon-1024.png")

if os.path.exists(SRC):
    img = Image.open(SRC).convert("RGB")
    if img.size != (1024, 1024):
        img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(OUT)
    print("saved", OUT, "(branded 5IN1 icon)")
    raise SystemExit(0)

# --- Fallback: procedural "?" tile (original behavior) ---
S = 1024
BG = (13, 15, 20)          # #0D0F14
GRID = (26, 29, 38)
NEON = (51, 153, 255)      # #3399FF
NEON_HOT = (150, 205, 255)

img = Image.new("RGB", (S, S), BG)
d = ImageDraw.Draw(img)

step = S // 12
for i in range(1, 12):
    d.line([(i * step, 0), (i * step, S)], fill=GRID, width=2)
    d.line([(0, i * step), (S, i * step)], fill=GRID, width=2)

glow = Image.new("L", (S, S), 0)
gd = ImageDraw.Draw(glow)
gd.ellipse([S * 0.18, S * 0.16, S * 0.82, S * 0.84], fill=70)
glow = glow.filter(ImageFilter.GaussianBlur(120))
blue = Image.new("RGB", (S, S), (20, 60, 130))
img = Image.composite(blue, img, glow)

def load_bold_font(size):
    candidates = [
        ("/System/Library/Fonts/Helvetica.ttc", 1),   # Helvetica Bold
        ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
        ("/System/Library/Fonts/Helvetica.ttc", 0),
        ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 0),  # linux fallback
    ]
    for path, index in candidates:
        try:
            return ImageFont.truetype(path, size, index=index)
        except Exception:
            continue
    return ImageFont.load_default()


font = load_bold_font(640)
glyph = "?"
d2 = ImageDraw.Draw(img)
bbox = d2.textbbox((0, 0), glyph, font=font)
w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
x, y = (S - w) / 2 - bbox[0], (S - h) / 2 - bbox[1] - 20

layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(layer).text((x, y), glyph, font=font, fill=NEON + (255,))
layer = layer.filter(ImageFilter.GaussianBlur(46))
img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")

layer2 = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(layer2).text((x, y), glyph, font=font, fill=NEON + (255,))
layer2 = layer2.filter(ImageFilter.GaussianBlur(14))
img = Image.alpha_composite(img.convert("RGBA"), layer2).convert("RGB")

ImageDraw.Draw(img).text((x, y), glyph, font=font, fill=NEON_HOT)

img.save(OUT)
print("saved", OUT, "(procedural fallback)")
