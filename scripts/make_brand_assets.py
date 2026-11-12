"""Generates Khidma brand rasters and the SVG mark from one geometry.

Mark: a doorway arch (Sidi Bou Said doors) with a saffron lantern dot.

Run from the repo root (pip install -r scripts/requirements.txt):
  python scripts/make_brand_assets.py              # source rasters + SVG
  (cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create)
  python scripts/make_brand_assets.py --maskable   # padded web maskable icons

Outputs in app/assets/brand/: icon-1024.png (opaque, iOS/web), icon-foreground.png
(transparent, Android adaptive), icon-monochrome.png (Android themed icons),
mark-splash.png (transparent), logo-mark.svg. `--maskable` writes
app/web/icons/Icon-maskable-{192,512}.png after the launcher-icons step, because
that tool would otherwise reuse the full-bleed artwork, which the W3C maskable
safe zone (80% circle) clips.

The Dart painter (app/lib/shared/widgets/khidma_logo.dart) mirrors OUTER, INNER
and DOT; test/widgets/brand_test.dart compares the SVG numbers to the script.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

PRIMARY = (0xB0, 0x43, 0x2A, 255)  # terracotta
WHITE = (255, 255, 255, 255)
BONE = (0xF4, 0xEF, 0xE6, 255)
SAFFRON = (0xC9, 0x8E, 0x1F, 255)  # ochre
CLEAR = (0, 0, 0, 0)

# Geometry in a 120x120 grid. Radius of an arch = (x1 - x0) / 2.
OUTER = dict(x0=36, x1=84, spring=52, bottom=92)
INNER = dict(x0=48, x1=72, spring=52, bottom=92)
DOT = dict(cx=60, cy=70, r=5.5)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'app' / 'assets' / 'brand'
WEB_ICONS = ROOT / 'app' / 'web' / 'icons'
SS = 4  # supersampling


def arch(draw, g, scale, fill, ox=0, oy=0):
    r = (g['x1'] - g['x0']) / 2
    x0, x1 = g['x0'] * scale + ox, g['x1'] * scale + ox
    spring = g['spring'] * scale + oy
    bottom = g['bottom'] * scale + oy
    rr = r * scale
    draw.rectangle([x0, spring, x1, bottom], fill=fill)
    draw.ellipse([x0, spring - rr, x1, spring + rr], fill=fill)


def dot(draw, scale, fill, ox=0, oy=0):
    cx, cy, r = DOT['cx'] * scale + ox, DOT['cy'] * scale + oy, DOT['r'] * scale
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def render(size, background, mark_scale, arch_color=WHITE, dot_color=SAFFRON):
    """Mark centered on a size x size canvas. mark_scale = pixels per grid unit."""
    big = size * SS
    img = Image.new('RGBA', (big, big), background)
    d = ImageDraw.Draw(img)
    s = mark_scale * SS
    ox = oy = (big - 120 * s) / 2
    arch(d, OUTER, s, arch_color, ox, oy)
    arch(d, INNER, s, background if background[3] else CLEAR, ox, oy)
    dot(d, s, dot_color, ox, oy)
    return img.resize((size, size), Image.LANCZOS)


def svg_path(g):
    r = (g['x1'] - g['x0']) / 2
    w = g['x1'] - g['x0']
    return f"M{g['x0']} {g['bottom']}V{g['spring']}a{r:g} {r:g} 0 0 1 {w:g} 0V{g['bottom']}Z"


def write_sources():
    OUT.mkdir(parents=True, exist_ok=True)
    unit = 1024 / 120
    # iOS / web icon: opaque, mark fills ~69% of the height.
    render(1024, PRIMARY, unit * 1.3, BONE).convert('RGB').save(OUT / 'icon-1024.png')
    # Android adaptive foreground: transparent; fits the 66% safe zone.
    render(1024, CLEAR, unit * 1.15, BONE).save(OUT / 'icon-foreground.png')
    # Android 13+ themed icon: single-color silhouette (arch + dot), same padding.
    render(1024, CLEAR, unit * 1.15, WHITE, WHITE).save(OUT / 'icon-monochrome.png')
    # Splash mark: transparent, smaller on the canvas.
    render(768, CLEAR, 768 / 120 * 0.9, PRIMARY).save(OUT / 'mark-splash.png')
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="120" height="120">
  <title>Khidma</title>
  <path fill="#B0432A" fill-rule="evenodd" d="{svg_path(OUTER)}{svg_path(INNER)}"/>
  <circle cx="{DOT['cx']}" cy="{DOT['cy']}" r="{DOT['r']}" fill="#C98E1F"/>
</svg>
'''
    (OUT / 'logo-mark.svg').write_text(svg, encoding='utf-8')


def write_maskable():
    """Opaque icons with the mark well inside the 80% maskable safe circle."""
    WEB_ICONS.mkdir(parents=True, exist_ok=True)
    for size in (192, 512):
        # Farthest arch corner from center is ~(24 x 32) grid units; at scale
        # k it must stay inside 40% of the size.
        k = size / 120 * 0.95
        render(size, PRIMARY, k).convert('RGB').save(WEB_ICONS / f'Icon-maskable-{size}.png')


if __name__ == '__main__':
    if '--maskable' in sys.argv:
        write_maskable()
        print('wrote maskable web icons')
    else:
        write_sources()
        print('wrote', sorted(p.name for p in OUT.iterdir()))
