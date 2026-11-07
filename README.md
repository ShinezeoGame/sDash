<p align="center"><img src="docs/logo/sdash-logo-1024.png" width="148" alt="Logo sDash : un « s » gravé dans du cuir capitonné"></p>

# sDash

Tableau de bord domotique pour tablette Android : lumières, chauffage, volets, prises,
scènes et réveil des ordinateurs, dans une interface en verre dépoli aux tons cuir et cognac.

<p align="center">
  <a href="https://github.com/ShinezeoGame/sDash/releases/latest/download/sdash.apk"><img alt="Télécharger la dernière version (APK Android)" src="https://img.shields.io/badge/T%C3%A9l%C3%A9charger-la%20derni%C3%A8re%20version-F0A257?style=for-the-badge&logo=android&logoColor=white&labelColor=3B2516"></a>
  <a href="https://github.com/ShinezeoGame/sDash/releases/latest"><img alt="Version" src="https://img.shields.io/github/v/release/ShinezeoGame/sDash?style=for-the-badge&label=version&color=C2692B&labelColor=3B2516"></a>
</p>

![Accueil de sDash](docs/captures/accueil.jpg)

| Chauffage | Lumières |
| --- | --- |
| ![Page chauffage](docs/captures/chauffage.jpg) | ![Page lumières](docs/captures/lumieres.jpg) |

## Fonctionnalités

- **Accueil** : tout tient sur un écran de tablette en paysage (thermostat, lumières par pièce,
  volets, scènes, ordinateurs, consommation de la semaine). L'interface se réorganise en portrait.
- **Lumières** : interrupteur par lampe et par pièce, variateur de luminosité, « tout éteindre ».
- **Chauffage** : cadran circulaire à manipuler au doigt, réglage par pas de 0,5°, modes
  Confort / Éco / Hors-gel / Arrêt.
- **Volets** : glissez sur la fenêtre pour choisir la position, ou ouvrir / stop / fermer.
- **Appareils** : prises connectées, scènes, et ordinateurs (allumage par Wake-on-LAN,
  état en ligne, extinction facultative).
- **Tablette murale** : écran toujours allumé, plein écran, effet verre allégé pour les
  tablettes peu puissantes.
- **Mode démo** : une maison simulée complète, active par défaut, pour tout essayer sans rien configurer.

## Installer l'application sur la tablette

1. Depuis la tablette, appuyez sur le bouton **Télécharger la dernière version** en haut de
   cette page (fichier `sdash.apk`).
2. Ouvrez le fichier téléchargé et autorisez l'installation d'applications de sources
   inconnues si Android le demande.

L'APK est compilé par GitHub Actions et publié dans les
[Releases](https://github.com/ShinezeoGame/sDash/releases) à chaque envoi sur la branche
par défaut. Les compilations des autres branches restent disponibles en artefact
**sdash-apk** dans l'onglet **Actions** (connexion à GitHub requise).

Pour compiler soi-même : `flutter build apk --release` (Flutter 3.47 et le SDK Android requis).

## Connecter Home Assistant

1. Dans Home Assistant : **Profil → Sécurité → Jetons d'accès longue durée** → créez un jeton.
2. Dans sDash : **Réglages → Connexion domotique → Home Assistant**, saisissez l'adresse
   (ex. `http://192.168.1.10:8123`) et le jeton, puis **Enregistrer**.

La connexion utilise l'API WebSocket : les changements d'état arrivent en temps réel et la
connexion se rétablit seule en cas de coupure. Les pièces sont celles définies dans
Home Assistant (zones). Entités prises en charge :

| Domaine | Dans sDash |
| --- | --- |
| `light` | Lumières (variation si l'ampoule la gère) |
| `climate` | Thermostats ; modes via les préréglages `comfort`, `eco`, `away` / `frost_protection` |
| `cover` | Volets (position si disponible, sinon ouvrir / fermer) |
| `switch` | Prises et appareils |
| `scene`, `script` | Scènes |
| `weather` | Température extérieure |

Les entités masquées, désactivées ou techniques (configuration, diagnostic) sont ignorées.
Le champ facultatif **Capteur d'énergie** (ex. `sensor.compteur_energie`) affiche la
consommation des 7 derniers jours ; sans lui, la carte montre les températures par pièce.

## Allumer un ordinateur

**Réglages → Ordinateurs → Ajouter**, deux possibilités :

- **Wake-on-LAN direct** depuis la tablette : renseignez l'adresse MAC de la carte réseau
  (le Wake-on-LAN doit être activé dans le BIOS/UEFI et dans les propriétés de la carte réseau).
  L'adresse IP, facultative, permet d'afficher si la machine est allumée. L'URL d'extinction,
  facultative, est appelée en `POST` (par exemple un petit service d'extinction installé sur le PC).
- **Entité Home Assistant** (ex. `switch.pc_bureau` de l'intégration Wake on LAN) :
  prioritaire en mode Home Assistant, l'allumage et l'extinction passent par Home Assistant.

La tablette doit être sur le même réseau local que l'ordinateur pour le réveil direct.

## Clé de signature (facultatif)

Sans configuration, l'APK est signé avec une clé de débogage différente à chaque compilation :
il faut alors désinstaller l'ancienne version avant d'installer la nouvelle. Pour des mises à jour
directes, créez une clé une fois pour toutes :

```bash
keytool -genkey -v -keystore sdash.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sdash
```

puis ajoutez ces secrets au dépôt (**Settings → Secrets and variables → Actions**) :
`ANDROID_KEYSTORE_BASE64` (résultat de `base64 -w0 sdash.jks`), `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS` (`sdash`) et `ANDROID_KEY_PASSWORD`. Ne versionnez jamais le fichier `.jks`.

## Développement

```bash
flutter pub get
```

```bash
flutter test
```

```bash
flutter run -d chrome
```

L'aperçu navigateur fonctionne en mode démo et Home Assistant ; le Wake-on-LAN direct n'est
disponible que sur la tablette.

### Organisation du code

| Dossier | Rôle |
| --- | --- |
| `lib/models/` | Modèles de la maison (pièces, appareils, état complet) |
| `lib/data/` | Sources domotiques : démo, Home Assistant, réseau local (Wake-on-LAN), réglages |
| `lib/state/` | `HomeController` : relie l'interface, les réglages et la source domotique |
| `lib/ui/widgets/` | Matériau verre, grain de cuir, cadran, volet, curseurs, histogramme |
| `lib/ui/cards/` | Cartes du tableau de bord |
| `lib/ui/pages/` | Pages détaillées et réglages |

Pour brancher un autre système domotique (Jeedom, Domoticz, MQTT…), il suffit d'implémenter
l'interface `HomeBackend` (`lib/data/home_backend.dart`).

## Logo

Cuir capitonné (cadre cousu, passepoil, panneau rembourré) avec le « s » gravé dans le cuir.
Les sources vectorielles sont dans `docs/logo/` et se régénèrent avec
`python3 tools/logo/generer_logo.py assets/fonts docs/logo`.

## Licences

Police [Outfit](https://github.com/Outfitio/Outfit-Fonts) sous licence SIL Open Font License 1.1
(`assets/fonts/OFL.txt`).
