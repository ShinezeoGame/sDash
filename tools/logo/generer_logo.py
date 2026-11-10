"""Logo sDash : un « S » géométrique dont l'extrémité est un point — une lumière allumée.

Utilisation (nécessite `pip install fonttools`, pour vectoriser le texte du logotype) :

    python3 tools/logo/generer_logo.py assets/fonts docs/logo [orange|ambre|sombre]

Produit, dans le dossier de sortie :

    sdash-logo.svg              icône complète (carré arrondi)
    sdash-icone-avant-plan.svg  le « S » seul, sur fond transparent : couche avant de
                                l'icône adaptative Android (son fond est une couleur unie)
    sdash-icone-pleine.svg      carré plein sans arrondi, pour les icônes web « maskable »
    sdash-logotype.svg          icône + « sDash », pour fond clair
    sdash-logotype-sombre.svg   icône + « sDash », pour fond sombre

Les PNG (mipmaps Android, icônes web, assets/branding/logo.png) sont des exports de ces SVG.
La palette par défaut est « orange » ; son fond doit rester identique à la couleur
`sdash_icon_background` de android/app/src/main/res/values/colors.xml.
"""

import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

FONTS, OUT = sys.argv[1], sys.argv[2]
VARIANTE = sys.argv[3] if len(sys.argv) > 3 else 'orange'

PALETTES = {
    # Couleur d'accent de l'application, « S » clair, point ambre.
    'orange': {'fond': '#C2571A', 'trait': '#FFF6EA', 'point': '#FFC56E'},
    # Comme une tuile allumée de l'application.
    'ambre': {'fond': '#F6B55F', 'trait': '#2A1D14', 'point': '#C2571A'},
    'sombre': {'fond': '#1E1410', 'trait': '#F5F0E8', 'point': '#F0A257'},
}
P = PALETTES[VARIANTE]

# ── Géométrie du « S », dans un carré de 1024 ──
# Un seul trait épais à bouts ronds : barre haute, demi-cercle à gauche, barre médiane,
# demi-cercle à droite, barre basse. L'extrémité haute est détachée en un point.
RAYON = 108  # rayon des demi-cercles (axe du trait)
TRAIT = 120  # épaisseur du trait ; le point a le même diamètre
X_GAUCHE, X_DROITE = 437, 587  # centres des demi-cercles
Y_HAUT, Y_MILIEU, Y_BAS = 296, 512, 728
ESPACE = 36  # vide entre la barre haute et le point

X_POINT = X_DROITE + RAYON
FIN_BARRE_HAUTE = X_POINT - TRAIT - ESPACE
TRACE = (
    f'M{FIN_BARRE_HAUTE} {Y_HAUT} H{X_GAUCHE} '
    f'A{RAYON} {RAYON} 0 0 0 {X_GAUCHE} {Y_MILIEU} H{X_DROITE} '
    f'A{RAYON} {RAYON} 0 0 1 {X_DROITE} {Y_BAS} H{X_GAUCHE - RAYON}'
)

# Échelle du « S » : généreuse dans l'icône complète, réduite dans les couches adaptatives
# pour rester dans la zone sûre (cercle de 61 % du côté) quel que soit le masque du lanceur.
ECHELLE_ICONE = 1.12
ECHELLE_ADAPTATIVE = 0.86


def glyphe(echelle):
    return (
        f'<g transform="translate(512 512) scale({echelle}) translate(-512 -512)">'
        f'<path d="{TRACE}" fill="none" stroke="{P["trait"]}" stroke-width="{TRAIT}" '
        f'stroke-linecap="round" stroke-linejoin="round"/>'
        f'<circle cx="{X_POINT}" cy="{Y_HAUT}" r="{TRAIT / 2:g}" fill="{P["point"]}"/>'
        f'</g>'
    )


def svg(contenu, largeur=1024, hauteur=1024):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {largeur} {hauteur}" '
        f'width="{largeur}" height="{hauteur}">{contenu}</svg>\n'
    )


ICONE = f'<rect width="1024" height="1024" rx="230" fill="{P["fond"]}"/>{glyphe(ECHELLE_ICONE)}'

open(f'{OUT}/sdash-logo.svg', 'w').write(svg(ICONE))
open(f'{OUT}/sdash-icone-avant-plan.svg', 'w').write(svg(glyphe(ECHELLE_ADAPTATIVE)))
open(f'{OUT}/sdash-icone-pleine.svg', 'w').write(
    svg(f'<rect width="1024" height="1024" fill="{P["fond"]}"/>{glyphe(ECHELLE_ADAPTATIVE)}')
)


# ── Logotype : icône + « sDash », lettres converties en tracés (aucune police requise) ──
def texte(police, chaine, taille, x, ligne_de_base, espacement=0.0):
    glyphes, table = police.getGlyphSet(), police.getBestCmap()
    echelle = taille / police['head'].unitsPerEm
    plume, curseur = SVGPathPen(glyphes), x
    for caractere in chaine:
        g = glyphes[table[ord(caractere)]]
        if caractere != ' ':
            g.draw(TransformPen(plume, (echelle, 0, 0, -echelle, curseur, ligne_de_base)))
        curseur += g.width * echelle + espacement
    return plume.getCommands(), curseur - x


SEMI = TTFont(f'{FONTS}/Outfit_600SemiBold.ttf')
MEDIUM = TTFont(f'{FONTS}/Outfit_500Medium.ttf')
s_trace, s_largeur = texte(SEMI, 's', 250, 600, 330)
dash_trace, _ = texte(SEMI, 'Dash', 250, 600 + s_largeur + 4, 330)
devise_trace, _ = texte(MEDIUM, 'TABLEAU DE BORD DOMOTIQUE', 40, 608, 420, espacement=7)


def logotype(couleur_s, couleur_dash, couleur_devise):
    return svg(
        f'<svg x="40" y="40" width="480" height="480" viewBox="0 0 1024 1024">{ICONE}</svg>'
        f'<path d="{s_trace}" fill="{couleur_s}"/>'
        f'<path d="{dash_trace}" fill="{couleur_dash}"/>'
        f'<path d="{devise_trace}" fill="{couleur_devise}"/>',
        1760,
        560,
    )


open(f'{OUT}/sdash-logotype.svg', 'w').write(logotype('#C2571A', '#2A1D14', '#6B5A4C'))
open(f'{OUT}/sdash-logotype-sombre.svg', 'w').write(logotype('#F0A257', '#F7EEE3', '#BCA996'))
print(f'Logo « {VARIANTE} » généré dans {OUT} (fond {P["fond"]})')
