"""Generates Khidma brand rasters and the SVG mark (calm violet identity).

Mark: a violet rounded square with a white "K" drawn in three round-capped
strokes (no font needed). The app icon is the white K on a full violet field.

Run from the repo root (pip install -r scripts/requirements.txt):
  python scripts/make_brand_assets.py              # source rasters + SVG
  (cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create)
  python scripts/make_brand_assets.py --maskable   # padded web maskable icons

Outputs in app/assets/brand/: icon-1024.png (opaque, iOS/web), icon-foreground.png
(transparent white K, Android adaptive; adaptive_icon_background is VIOLET in
pubspec), icon-monochrome.png (Android themed icons), mark-splash.png
(transparent: the violet square with the K), logo-mark.svg. `--maskable`
writes app/web/icons/Icon-maskable-{192,512}.png after the launcher-icons
step, because that tool would otherwise reuse the full-bleed artwork, which
the W3C maskable safe zone (80% circle) clips.

The Dart widget (app/lib/shared/widgets/khidma_logo.dart, KhidmaMarkPainter)
draws the same geometry; test/widgets/brand_test.dart checks the SVG colours.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

VIOLET = (0x5B, 0x3C, 0xC4, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'app' / 'assets' / 'brand'
WEB_ICONS = ROOT / 'app' / 'web' / 'icons'
SS = 4  # supersampling

# Mark geometry in an 80-unit square (same numbers as KhidmaMarkPainter).
SIDE = 80
RADIUS = 20
STROKE = 9
STROKES = [
    (28, 22, 28, 58),  # stem
    (28, 46, 52, 22),  # upper arm
    (37, 37, 53, 58),  # lower leg
]
# The K's own box (stroke caps included), to centre it alone.
K_BOX = (28 - STROKE / 2, 22 - STROKE / 2, 53 + STROKE / 2, 58 + STROKE / 2)


def draw_k(d, s, ox, oy, fill):
    """Round-capped K strokes, s pixels per unit, square origin at (ox, oy)."""
    w = STROKE * s
    for x0, y0, x1, y1 in STROKES:
        a = (ox + x0 * s, oy + y0 * s)
        b = (ox + x1 * s, oy + y1 * s)
        d.line([a, b], fill=fill, width=round(w))
        for x, y in (a, b):
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=fill)


def render(size, background, scale, square=True, k=WHITE):
    """The mark centred on a size x size canvas; scale = pixels per unit.

    square=False draws the K alone, centred on its own box."""
    big = size * SS
    img = Image.new('RGBA', (big, big), background)
    d = ImageDraw.Draw(img)
    s = scale * SS
    if square:
        ox = oy = (big - SIDE * s) / 2
        d.rounded_rectangle(
            [ox, oy, ox + SIDE * s, oy + SIDE * s], radius=RADIUS * s,
            fill=VIOLET)
    else:
        cx = (K_BOX[0] + K_BOX[2]) / 2
        cy = (K_BOX[1] + K_BOX[3]) / 2
        ox = big / 2 - cx * s
        oy = big / 2 - cy * s
    draw_k(d, s, ox, oy, k)
    return img.resize((size, size), Image.LANCZOS)


def k_height():
    return K_BOX[3] - K_BOX[1]


def write_sources():
    OUT.mkdir(parents=True, exist_ok=True)
    # iOS / web icon: opaque full violet field, the K ~46% of the height.
    render(1024, VIOLET, 1024 * 0.46 / k_height(), square=False).convert(
        'RGB').save(OUT / 'icon-1024.png')
    # Android adaptive foreground: transparent white K inside the safe zone.
    render(1024, CLEAR, 1024 * 0.32 / k_height(), square=False).save(
        OUT / 'icon-foreground.png')
    # Android 13+ themed icon: the same single-colour K silhouette.
    render(1024, CLEAR, 1024 * 0.32 / k_height(), square=False).save(
        OUT / 'icon-monochrome.png')
    # Splash mark: transparent, the violet square inside the Android 12 mask.
    render(768, CLEAR, 768 * 0.44 / SIDE).save(OUT / 'mark-splash.png')
    off = 20  # the SVG puts the 80-unit square in a 120 grid
    lines = '\n'.join(
        f'    <line x1="{x0 + off}" y1="{y0 + off}" x2="{x1 + off}" y2="{y1 + off}"/>'
        for x0, y0, x1, y1 in STROKES)
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="120" height="120">
  <title>Khidma</title>
  <rect x="{off}" y="{off}" width="{SIDE}" height="{SIDE}" rx="{RADIUS}" fill="#5B3CC4"/>
  <g stroke="#FFFFFF" stroke-width="{STROKE}" stroke-linecap="round" fill="none">
{lines}
  </g>
</svg>
'''
    (OUT / 'logo-mark.svg').write_text(svg, encoding='utf-8')


def write_maskable():
    """Opaque icons with the K well inside the 80% maskable safe circle."""
    WEB_ICONS.mkdir(parents=True, exist_ok=True)
    for size in (192, 512):
        render(size, VIOLET, size * 0.36 / k_height(), square=False).convert(
            'RGB').save(WEB_ICONS / f'Icon-maskable-{size}.png')


if __name__ == '__main__':
    if '--maskable' in sys.argv:
        write_maskable()
        print('wrote maskable web icons')
    else:
        write_sources()
        print('wrote', sorted(p.name for p in OUT.iterdir()))
