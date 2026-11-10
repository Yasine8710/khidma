"""Generates Khidma brand rasters and the SVG mark from one geometry.

Mark: a doorway arch (Sidi Bou Said doors) with a saffron lantern dot.
Run from the repo root:  python scripts/make_brand_assets.py
Outputs (app/assets/brand/): icon-1024.png (opaque, iOS/web), icon-foreground.png
(transparent, Android adaptive), mark-splash.png (transparent), logo-mark.svg.
"""
from pathlib import Path

from PIL import Image, ImageDraw

PRIMARY = (0x1F, 0x5A, 0xA6, 255)
WHITE = (255, 255, 255, 255)
SAFFRON = (0xE8, 0xA3, 0x3D, 255)
CLEAR = (0, 0, 0, 0)

# Geometry in a 120x120 grid.
OUTER = dict(x0=36, x1=84, spring=52, bottom=92)  # radius = 24
INNER = dict(x0=48, x1=72, spring=52, bottom=92)  # radius = 12
DOT = dict(cx=60, cy=70, r=5.5)

OUT = Path(__file__).resolve().parent.parent / 'app' / 'assets' / 'brand'
SS = 4  # supersampling


def arch(draw, g, scale, fill, ox=0, oy=0):
    r = (g['x1'] - g['x0']) / 2
    x0, x1 = (g['x0'] * scale) + ox, (g['x1'] * scale) + ox
    spring = g['spring'] * scale + oy
    bottom = g['bottom'] * scale + oy
    rr = r * scale
    draw.rectangle([x0, spring, x1, bottom], fill=fill)
    draw.ellipse([x0, spring - rr, x1, spring + rr], fill=fill)


def dot(draw, scale, fill, ox=0, oy=0):
    cx, cy, r = DOT['cx'] * scale + ox, DOT['cy'] * scale + oy, DOT['r'] * scale
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def render(size, background, mark_scale):
    """Mark centered on a size x size canvas. mark_scale = pixels per grid unit."""
    big = size * SS
    img = Image.new('RGBA', (big, big), background)
    d = ImageDraw.Draw(img)
    s = mark_scale * SS
    # Center the 120-grid on the canvas.
    ox = (big - 120 * s) / 2
    oy = (big - 120 * s) / 2
    arch(d, OUTER, s, WHITE, ox, oy)
    arch(d, INNER, s, background if background[3] else CLEAR, ox, oy)
    dot(d, s, SAFFRON, ox, oy)
    return img.resize((size, size), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # iOS / web icon: opaque, mark fills ~69% of the height.
    render(1024, PRIMARY, 1024 / 120 * 1.3).convert('RGB').save(OUT / 'icon-1024.png')
    # Android adaptive foreground: transparent; mark inside the 66% safe zone.
    render(1024, CLEAR, 1024 / 120 * 1.15).save(OUT / 'icon-foreground.png')
    # Splash mark: transparent, smaller on the canvas.
    render(768, CLEAR, 768 / 120 * 0.9).save(OUT / 'mark-splash.png')
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="120" height="120">
  <title>Khidma</title>
  <path fill="#1F5AA6" fill-rule="evenodd" d="M{OUTER['x0']} {OUTER['bottom']}V{OUTER['spring']}a24 24 0 0 1 48 0V{OUTER['bottom']}ZM{INNER['x0']} {INNER['bottom']}V{INNER['spring']}a12 12 0 0 1 24 0V{INNER['bottom']}Z"/>
  <circle cx="{DOT['cx']}" cy="{DOT['cy']}" r="{DOT['r']}" fill="#E8A33D"/>
</svg>
'''
    (OUT / 'logo-mark.svg').write_text(svg, encoding='utf-8')
    print('wrote', sorted(p.name for p in OUT.iterdir()))


if __name__ == '__main__':
    main()
