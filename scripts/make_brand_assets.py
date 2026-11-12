"""Generates Khidma brand rasters and the SVG mark ("Signal" identity).

Mark: a hard ink block carrying a yellow Anton "K", like a workshop sign. The
icon is that block on a flat signage-yellow field. No gradients, no terracotta.

Run from the repo root (pip install -r scripts/requirements.txt):
  python scripts/make_brand_assets.py              # source rasters + SVG
  (cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create)
  python scripts/make_brand_assets.py --maskable   # padded web maskable icons

Outputs in app/assets/brand/: icon-1024.png (opaque, iOS/web), icon-foreground.png
(transparent, Android adaptive: ink block + K; set adaptive_icon_background to
YELLOW in pubspec), icon-monochrome.png (Android themed icons), mark-splash.png
(transparent), logo-mark.svg. `--maskable` writes app/web/icons/Icon-maskable-
{192,512}.png after the launcher-icons step, because that tool would otherwise
reuse the full-bleed artwork, which the W3C maskable safe zone (80% circle)
clips.

The Dart widget (app/lib/shared/widgets/khidma_logo.dart) draws the same mark
with the same Anton font; test/widgets/brand_test.dart checks the SVG colours.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

INK = (0x0E, 0x0E, 0x0E, 255)
YELLOW = (0xF5, 0xC4, 0x00, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'app' / 'assets' / 'brand'
WEB_ICONS = ROOT / 'app' / 'web' / 'icons'
FONT = ROOT / 'app' / 'assets' / 'fonts' / 'Anton-Regular.ttf'
SS = 4  # supersampling

# Mark geometry in a 120x120 grid: the ink block, and the K's height.
BLOCK = dict(x0=20, y0=20, x1=100, y1=100, r=6)
K_HEIGHT = 50  # cap height of the K, in grid units


def _k_metrics(font_px):
    font = ImageFont.truetype(str(FONT), font_px)
    return font, font.getbbox('K')


def draw_k(draw, scale, fill, ox, oy):
    """Draws the Anton K centered in the block (grid units * scale)."""
    # Pick a font size whose K bbox height equals K_HEIGHT * scale.
    probe, bb = _k_metrics(200)
    px = 200 * (K_HEIGHT * scale) / (bb[3] - bb[1])
    font, bb = _k_metrics(max(1, round(px)))
    cx = (BLOCK['x0'] + BLOCK['x1']) / 2 * scale + ox
    cy = (BLOCK['y0'] + BLOCK['y1']) / 2 * scale + oy
    x = cx - (bb[0] + bb[2]) / 2
    y = cy - (bb[1] + bb[3]) / 2
    draw.text((x, y), 'K', font=font, fill=fill)


def render(size, background, mark_scale, block=INK, k=YELLOW, block_on=True):
    """Mark centered on a size x size canvas. mark_scale = pixels per grid unit."""
    big = size * SS
    img = Image.new('RGBA', (big, big), background)
    d = ImageDraw.Draw(img)
    s = mark_scale * SS
    ox = oy = (big - 120 * s) / 2
    if block_on:
        d.rounded_rectangle(
            [BLOCK['x0'] * s + ox, BLOCK['y0'] * s + oy,
             BLOCK['x1'] * s + ox, BLOCK['y1'] * s + oy],
            radius=BLOCK['r'] * s, fill=block)
    draw_k(d, s, k, ox, oy)
    return img.resize((size, size), Image.LANCZOS)


def k_svg_path():
    """The K outline from the Anton font, in grid units, centered in the block."""
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.ttLib import TTFont

    f = TTFont(str(FONT))
    gs = f.getGlyphSet()
    name = f.getBestCmap()[ord('K')]
    bp = BoundsPen(gs)
    gs[name].draw(bp)
    x0, y0, x1, y1 = bp.bounds
    k = K_HEIGHT / (y1 - y0)
    cx = (BLOCK['x0'] + BLOCK['x1']) / 2
    cy = (BLOCK['y0'] + BLOCK['y1']) / 2
    # Flip y (font y is up) and center the bbox on the block center.
    t = (k, 0, 0, -k, cx - (x0 + x1) / 2 * k, cy + (y0 + y1) / 2 * k)
    pen = SVGPathPen(gs, ntos=lambda v: f'{v:.2f}'.rstrip('0').rstrip('.'))
    gs[name].draw(TransformPen(pen, t))
    return pen.getCommands()


def write_sources():
    OUT.mkdir(parents=True, exist_ok=True)
    unit = 1024 / 120
    # iOS / web icon: opaque, flat yellow field, ink block ~75% of the height.
    render(1024, YELLOW, unit * 1.12).convert('RGB').save(OUT / 'icon-1024.png')
    # Android adaptive foreground: transparent; block fits the 66% safe zone.
    render(1024, CLEAR, unit * 0.98).save(OUT / 'icon-foreground.png')
    # Android 13+ themed icon: single-colour K silhouette.
    render(1024, CLEAR, unit * 1.3, k=WHITE, block_on=False).save(
        OUT / 'icon-monochrome.png')
    # Splash mark: transparent, smaller on the canvas.
    render(768, CLEAR, 768 / 120 * 0.72).save(OUT / 'mark-splash.png')
    b = BLOCK
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="120" height="120">
  <title>Khidma</title>
  <rect x="{b['x0']}" y="{b['y0']}" width="{b['x1'] - b['x0']}" height="{b['y1'] - b['y0']}" rx="{b['r']}" fill="#0E0E0E"/>
  <path fill="#F5C400" d="{k_svg_path()}"/>
</svg>
'''
    (OUT / 'logo-mark.svg').write_text(svg, encoding='utf-8')


def write_maskable():
    """Opaque icons with the block well inside the 80% maskable safe circle."""
    WEB_ICONS.mkdir(parents=True, exist_ok=True)
    for size in (192, 512):
        # Block half-diagonal is 40*sqrt2 grid units; at scale k it must stay
        # inside 40% of the size.
        k = size / 120 * 0.68
        render(size, YELLOW, k).convert('RGB').save(
            WEB_ICONS / f'Icon-maskable-{size}.png')


if __name__ == '__main__':
    if '--maskable' in sys.argv:
        write_maskable()
        print('wrote maskable web icons')
    else:
        write_sources()
        print('wrote', sorted(p.name for p in OUT.iterdir()))
