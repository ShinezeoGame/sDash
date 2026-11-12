"""Exporte les PNG à partir des SVG de `docs/logo`.

Utilisation, depuis la racine du dépôt (nécessite `pip install cairosvg pillow`) :

    python3 tools/logo/exporter.py

Fichiers produits :

    docs/logo/sdash-logo-1024.png                          logo pour le README
    assets/branding/logo.png                               logo affiché dans Réglages → À propos
    android/app/src/main/res/mipmap-*/ic_launcher.png      icône Android classique
    android/…/mipmap-*/ic_launcher_foreground.png          couche avant de l'icône adaptative
    web/favicon.png, web/icons/Icon-*.png                  icônes de la version web
"""

import io

import cairosvg
from PIL import Image

LOGO = 'docs/logo/sdash-logo.svg'
PETIT = 'docs/logo/sdash-logo-petit.svg'
AVANT_PLAN = 'docs/logo/sdash-icone-avant-plan.svg'
PLEINE = 'docs/logo/sdash-icone-pleine.svg'


def rendu(svg, taille):
    png = cairosvg.svg2png(url=svg, output_width=taille, output_height=taille)
    return Image.open(io.BytesIO(png)).convert('RGBA')


rendu(LOGO, 1024).save('docs/logo/sdash-logo-1024.png', optimize=True)
rendu(LOGO, 216).save('assets/branding/logo.png', optimize=True)

# Android : une taille par densité d'écran (icône classique 48 dp, couche adaptative 108 dp).
DENSITES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for nom, facteur in DENSITES.items():
    dossier = f'android/app/src/main/res/mipmap-{nom}'
    rendu(LOGO, round(48 * facteur)).save(f'{dossier}/ic_launcher.png', optimize=True)
    rendu(AVANT_PLAN, round(108 * facteur)).save(f'{dossier}/ic_launcher_foreground.png', optimize=True)

# Web : les icônes « maskable » sont pleines (sans transparence), le navigateur les découpe.
rendu(PETIT, 32).save('web/favicon.png', optimize=True)
for taille in (192, 512):
    rendu(LOGO, taille).save(f'web/icons/Icon-{taille}.png', optimize=True)
    rendu(PLEINE, taille).convert('RGB').save(f'web/icons/Icon-maskable-{taille}.png', optimize=True)
print('PNG exportés')
