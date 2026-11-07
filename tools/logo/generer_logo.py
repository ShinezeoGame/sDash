"""Logo sDash : cuir capitonné (cadre cousu, passepoil, panneau rembourré) et « s » gravé dans le cuir.

Utilisation (nécessite `pip install fonttools`) :

    python3 tools/logo/generer_logo.py assets/fonts docs/logo

Produit sdash-logo.svg, sdash-logotype.svg et les deux couches de l'icône adaptative
Android (sdash-icone-fond.svg, sdash-icone-avant-plan.svg). Les PNG (mipmaps Android,
icônes web, assets/branding/logo.png) sont des exports de ces SVG.
"""
import bisect
import math
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

FONTS, OUT = sys.argv[1], sys.argv[2]
SEMI = TTFont(f'{FONTS}/Outfit_600SemiBold.ttf')
MED = TTFont(f'{FONTS}/Outfit_500Medium.ttf')



def centered_glyph(font, ch, size, cx, cy):
    gs, cmap = font.getGlyphSet(), font.getBestCmap()
    g = gs[cmap[ord(ch)]]
    bp = BoundsPen(gs)
    g.draw(bp)
    xmin, ymin, xmax, ymax = bp.bounds
    scale = size / font['head'].unitsPerEm
    pen = SVGPathPen(gs)
    g.draw(TransformPen(pen, (scale, 0, 0, -scale, cx - (xmin + xmax) / 2 * scale, cy + (ymin + ymax) / 2 * scale)))
    return pen.getCommands()


S_GLYPH = centered_glyph(SEMI, 's', 880, 512, 512)

CX, CY, RX, RY = 512, 512, 172, 134
A0, A1 = -36.0, 144.0
HALF = 54                         # demi-largeur du boudin
SW, SL, SP, SLANT = 17, 30, 40, 18  # fil : épaisseur, longueur, pas, inclinaison


def centerline(n=700):
    pts = []
    for i in range(n + 1):
        t = math.radians(A0 + (-270 - A0) * i / n)
        pts.append((CX + RX * math.cos(t), CY - RY + RY * math.sin(t)))
    for i in range(1, n + 1):
        t = math.radians(-90 + (A1 + 90) * i / n)
        pts.append((CX + RX * math.cos(t), CY + RY + RY * math.sin(t)))
    return pts


def tangents(pts):
    out = []
    for i in range(len(pts)):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        d = math.dist(a, b) or 1
        out.append(((b[0] - a[0]) / d, (b[1] - a[1]) / d))
    return out


C = centerline()
T = tangents(C)
left = [(p[0] - t[1] * HALF, p[1] + t[0] * HALF) for p, t in zip(C, T)]
right = [(p[0] + t[1] * HALF, p[1] - t[0] * HALF) for p, t in zip(C, T)]


def cap(center, frm, to_dir, steps=40):
    """Demi-cercle autour d'une extrémité, du côté de la direction to_dir."""
    a0 = math.atan2(frm[1], frm[0])
    # sens choisi pour passer par to_dir
    for sign in (1, -1):
        mid = a0 + sign * math.pi / 2
        if math.cos(mid) * to_dir[0] + math.sin(mid) * to_dir[1] > 0:
            break
    return [(center[0] + HALF * math.cos(a0 + sign * math.pi * k / steps),
             center[1] + HALF * math.sin(a0 + sign * math.pi * k / steps)) for k in range(1, steps)]


n_end, n_start = (-T[-1][1], T[-1][0]), (-T[0][1], T[0][0])
outline = left + cap(C[-1], n_end, T[-1]) + right[::-1] + cap(C[0], (-n_start[0], -n_start[1]), (-T[0][0], -T[0][1]))
LEN = [0.0]
for a, b in zip(outline, outline[1:] + outline[:1]):
    LEN.append(LEN[-1] + math.dist(a, b))
TOTAL = LEN[-1]


def at(u):
    u %= TOTAL
    i = min(max(bisect.bisect_right(LEN, u), 1), len(outline))
    a, b = outline[i - 1], outline[i % len(outline)]
    f = (u - LEN[i - 1]) / max(LEN[i] - LEN[i - 1], 1e-9)
    d = math.dist(a, b) or 1
    return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f), ((b[0] - a[0]) / d, (b[1] - a[1]) / d)


def poly(pts, close=False):
    return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + (' Z' if close else '')


CENTER_PATH = poly(C)
OUTLINE_PATH = poly(outline, close=True)


def s_stitches():
    count = int(TOTAL // SP)
    pitch = TOTAL / count
    holes, shadows, threads = [], [], []
    for i in range(count):
        (x, y), (tx, ty) = at(i * pitch)
        deg = math.degrees(math.atan2(ty, tx)) + SLANT
        place = f'transform="translate({x:.1f} {y:.1f}) rotate({deg:.1f})"'
        holes.append(f'<g {place}><circle cx="{-SL / 2 - 2}" r="{SW * .32:.1f}"/><circle cx="{SL / 2 + 2}" r="{SW * .32:.1f}"/></g>')
        shadows.append(f'<rect {place} x="{-SL / 2}" y="{-SW / 2}" width="{SL}" height="{SW}" rx="{SW / 2}"/>')
        threads.append(f'<g {place}><rect x="{-SL / 2}" y="{-SW / 2}" width="{SL}" height="{SW}" rx="{SW / 2}" fill="url(#thread)"/>'
                       f'<rect x="{-SL / 2 + 5}" y="{-SW * .3:.1f}" width="{SL - 10}" height="{SW * .2:.1f}" rx="{SW * .1:.1f}" fill="#FFFBF3" fill-opacity=".7"/></g>')
    return (f'<g fill="#080301" fill-opacity=".55">{"".join(holes)}</g>'
            f'<g fill="#000" fill-opacity=".55" filter="url(#thr)"><g transform="translate(1 4)">{"".join(shadows)}</g></g>'
            + ''.join(threads))


def grain_filter(fid, freq, seed, bump, slope, icpt):
    return f'''
  <filter id="{fid}" x="0" y="0" width="1" height="1" color-interpolation-filters="sRGB">
    <feTurbulence type="fractalNoise" baseFrequency="{freq}" numOctaves="3" seed="{seed}" stitchTiles="stitch" result="n"/>
    <feDiffuseLighting in="n" surfaceScale="{bump}" diffuseConstant="1" lighting-color="#fff" result="lit">
      <feDistantLight azimuth="235" elevation="58"/>
    </feDiffuseLighting>
    <feColorMatrix in="lit" type="saturate" values="0" result="gray"/>
    <feComponentTransfer in="gray" result="soft">
      <feFuncR type="linear" slope="{slope}" intercept="{icpt}"/><feFuncG type="linear" slope="{slope}" intercept="{icpt}"/><feFuncB type="linear" slope="{slope}" intercept="{icpt}"/>
    </feComponentTransfer>
    <feBlend in="SourceGraphic" in2="soft" mode="multiply" result="m"/>
    <feComposite in="m" in2="SourceAlpha" operator="in"/>
  </filter>'''


DEFS = f'''
  <clipPath id="tile"><rect width="1024" height="1024" rx="232"/></clipPath>
  <clipPath id="panelClip"><rect x="92" y="92" width="840" height="840" rx="156"/></clipPath>
  {grain_filter('grain', 0.5, 3, 3.4, .52, .54)}
  {grain_filter('grainFine', 0.62, 9, 2.6, .44, .6)}
  <filter id="blur4" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="4"/></filter>
  <filter id="blur10" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="10"/></filter>
  <filter id="blur18" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="18"/></filter>
  <filter id="haze" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="80"/></filter>
  <filter id="thr" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="2"/></filter>
  <radialGradient id="frame" cx="30%" cy="20%" r="100%">
    <stop offset="0" stop-color="#5E321A"/><stop offset=".55" stop-color="#3A1D0E"/><stop offset="1" stop-color="#1A0C06"/>
  </radialGradient>
  <radialGradient id="panel" cx="40%" cy="34%" r="80%">
    <stop offset="0" stop-color="#A2602F"/><stop offset=".5" stop-color="#7A421F"/><stop offset="1" stop-color="#4A2612"/>
  </radialGradient>
  <linearGradient id="thread" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFF3DE"/><stop offset=".45" stop-color="#F0D9B2"/><stop offset="1" stop-color="#B9946A"/>
  </linearGradient>
  <linearGradient id="edge" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity=".34"/><stop offset=".45" stop-color="#fff" stop-opacity=".04"/><stop offset="1" stop-color="#000" stop-opacity=".4"/>
  </linearGradient>
  <radialGradient id="floor" cx="40%" cy="30%" r="80%">
    <stop offset="0" stop-color="#6A3517"/><stop offset="1" stop-color="#3C1C0A"/>
  </radialGradient>
  <filter id="carve" x="-15%" y="-15%" width="130%" height="130%">
    <feOffset in="SourceAlpha" dx="7" dy="12" result="o1"/>
    <feGaussianBlur in="o1" stdDeviation="7" result="b1"/>
    <feComposite in="SourceAlpha" in2="b1" operator="out" result="m1"/>
    <feFlood flood-color="#0E0401" flood-opacity=".92"/>
    <feComposite in2="m1" operator="in" result="shadowWall"/>
    <feOffset in="SourceAlpha" dx="-5" dy="-8" result="o2"/>
    <feGaussianBlur in="o2" stdDeviation="3.5" result="b2"/>
    <feComposite in="SourceAlpha" in2="b2" operator="out" result="m2"/>
    <feFlood flood-color="#FFD3A1" flood-opacity=".42"/>
    <feComposite in2="m2" operator="in" result="litWall"/>
    <feMorphology in="SourceAlpha" operator="dilate" radius="2" result="d"/>
    <feOffset in="d" dy="5" result="o3"/>
    <feComposite in="o3" in2="SourceAlpha" operator="out" result="m3"/>
    <feGaussianBlur in="m3" stdDeviation="1.6" result="b3"/>
    <feFlood flood-color="#FFE6C6" flood-opacity=".5"/>
    <feComposite in2="b3" operator="in" result="lip"/>
    <feMerge><feMergeNode in="lip"/><feMergeNode in="SourceGraphic"/><feMergeNode in="shadowWall"/><feMergeNode in="litWall"/></feMerge>
  </filter>
  <mask id="tubeMask"><path d="{CENTER_PATH}" fill="none" stroke="#fff" stroke-width="{HALF * 2}" stroke-linecap="round"/></mask>'''


def border_stitch(inset, rx, width=9, dash='18 12', color='#EBD3AD', op='.7'):
    r = f'x="{inset}" y="{inset}" width="{1024 - 2 * inset}" height="{1024 - 2 * inset}" rx="{rx}" fill="none"'
    return (f'<rect {r} stroke="#000" stroke-opacity=".45" stroke-width="{width}" stroke-dasharray="{dash}" stroke-linecap="round" transform="translate(0 3)"/>'
            f'<rect {r} stroke="{color}" stroke-opacity="{op}" stroke-width="{width}" stroke-dasharray="{dash}" stroke-linecap="round"/>')


FRAME = f'''
  <rect width="1024" height="1024" fill="url(#frame)" filter="url(#grain)"/>
  <ellipse cx="300" cy="190" rx="380" ry="240" fill="#FFD9A8" opacity=".10" filter="url(#haze)"/>
  {border_stitch(46, 190)}'''

PANEL = f'''
  <rect x="92" y="92" width="840" height="840" rx="156" fill="#000" opacity=".55" filter="url(#blur10)" transform="translate(0 8)"/>
  <g clip-path="url(#panelClip)">
    <rect x="92" y="92" width="840" height="840" fill="url(#panel)" filter="url(#grainFine)"/>
    <ellipse cx="470" cy="420" rx="330" ry="300" fill="#FFD7A6" opacity=".16" filter="url(#haze)"/>
    <rect x="92" y="92" width="840" height="840" rx="156" fill="none" stroke="#1A0B04" stroke-opacity=".55" stroke-width="60" filter="url(#blur18)"/>
  </g>
  <rect x="92" y="92" width="840" height="840" rx="156" fill="none" stroke="#2A1409" stroke-width="22"/>
  <rect x="92" y="92" width="840" height="840" rx="156" fill="none" stroke="#FFDDB5" stroke-opacity=".28" stroke-width="6" transform="translate(-2 -4)" filter="url(#blur4)"/>
  {border_stitch(124, 128, width=8, dash='16 11', op='.55')}'''

CARVED = f'''
  <path d="{S_GLYPH}" fill="none" stroke="#1A0903" stroke-opacity=".38" stroke-width="34" stroke-linejoin="round" filter="url(#blur10)"/>
  <g filter="url(#carve)"><path d="{S_GLYPH}" fill="url(#floor)" filter="url(#grainFine)"/></g>'''


def doc(body, w=1024, h=1024, defs=DEFS):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">\n<defs>{defs}\n</defs>{body}\n</svg>\n'


TILE = f'<g clip-path="url(#tile)">{FRAME}{PANEL}{CARVED}</g>\n<rect width="1024" height="1024" rx="232" fill="none" stroke="url(#edge)" stroke-width="5"/>'
open(f'{OUT}/sdash-logo.svg', 'w').write(doc(TILE))
# Icône adaptative : fond = panneau capitonné plein cadre, avant-plan = le « s » piqué.
BG = f'''<rect width="1024" height="1024" fill="url(#panel)" filter="url(#grainFine)"/>
  <ellipse cx="470" cy="420" rx="360" ry="330" fill="#FFD7A6" opacity=".16" filter="url(#haze)"/>'''
open(f'{OUT}/sdash-icone-fond.svg', 'w').write(doc(BG))
open(f'{OUT}/sdash-icone-avant-plan.svg', 'w').write(doc(f'<g transform="translate(512 512) scale(.9) translate(-512 -512)">{CARVED}</g>'))


def glyphs(font, text, size, x, baseline, spacing=0.0):
    gs, cmap = font.getGlyphSet(), font.getBestCmap()
    scale = size / font['head'].unitsPerEm
    pen, cursor = SVGPathPen(gs), x
    for ch in text:
        g = gs[cmap[ord(ch)]]
        if ch != ' ':
            g.draw(TransformPen(pen, (scale, 0, 0, -scale, cursor, baseline)))
        cursor += g.width * scale + spacing
    return pen.getCommands(), cursor - x


s_path, s_w = glyphs(SEMI, 's', 250, 600, 330)
d_path, _ = glyphs(SEMI, 'Dash', 250, 600 + s_w + 4, 330)
t_path, _ = glyphs(MED, 'TABLEAU DE BORD DOMOTIQUE', 40, 608, 420, spacing=7)
lockup = f'''<svg x="40" y="40" width="480" height="480" viewBox="0 0 1024 1024"><defs>{DEFS}</defs>{TILE}</svg>
<path d="{s_path}" fill="#D59B5E"/><path d="{d_path}" fill="#F3E3CF"/><path d="{t_path}" fill="#A98F79"/>'''
open(f'{OUT}/sdash-logotype.svg', 'w').write(doc(lockup, 1760, 560, defs=''))
print('ok')
