# Guide d'utilisation de sDash

[← Retour à la présentation](../README.md)

## Installer l'application

1. Depuis la tablette, ouvrez la [dernière version](https://github.com/ShinezeoGame/sDash/releases/latest)
   et téléchargez `sdash.apk`.
2. Ouvrez le fichier téléchargé et autorisez l'installation d'applications de sources
   inconnues si Android le demande.

Une nouvelle version est publiée à chaque mise à jour de la branche principale. Les
compilations des autres branches sont disponibles en artefact **sdash-apk** dans l'onglet
**Actions** (connexion à GitHub requise).

## Connecter Home Assistant

1. Dans Home Assistant : **Profil → Sécurité → Jetons d'accès longue durée** → créez un jeton.
2. Dans sDash : **Réglages → Connexion domotique → Home Assistant**, saisissez l'adresse
   (ex. `http://192.168.1.10:8123`) et le jeton, puis **Enregistrer**.

La connexion utilise l'API WebSocket : les changements d'état arrivent en temps réel et la
connexion se rétablit seule en cas de coupure. Les pièces sont celles définies dans
Home Assistant (zones).

### Appareils pris en charge

| Domaine Home Assistant | Dans sDash |
| --- | --- |
| `light` | Lumières (variation si l'ampoule la gère) |
| `climate` | Thermostats ; modes via les préréglages `comfort`, `eco`, `away` / `frost_protection` |
| `cover` | Volets (position si disponible, sinon ouvrir / fermer) |
| `switch`, `input_boolean` | Prises et appareils |
| `media_player` | Télés et enceintes : marche / arrêt, lecture, volume, sourdine |
| `vacuum` | Aspirateur robot : état, batterie, lancer, pause, retour à la base |
| `scene`, `script` | Scènes |
| `button` | Actions ponctuelles, comme l'extinction d'un ordinateur |
| `weather` | Température extérieure |
| `sensor` | Températures par pièce et consommation d'énergie |

Les entités masquées, désactivées ou techniques (configuration, diagnostic) sont ignorées.
Le champ facultatif **Capteur d'énergie** (ex. `sensor.compteur_energie`) affiche la
consommation des 7 derniers jours ; sans lui, la carte montre les températures par pièce.

Une télé qui ne sait pas s'éteindre seule (ajoutée par DLNA, par exemple) s'allume par le
réseau et s'éteint avec le boîtier de la même pièce (Freebox, Fire TV…), par HDMI-CEC.

## Allumer un ordinateur

**Réglages → Ordinateurs → Ajouter**, deux possibilités :

- **Wake-on-LAN direct** depuis la tablette : renseignez l'adresse MAC de la carte réseau
  (le Wake-on-LAN doit être activé dans le BIOS/UEFI et dans les propriétés de la carte réseau).
  L'adresse IP, facultative, permet d'afficher si la machine est allumée. L'URL d'extinction,
  facultative, est appelée en `POST` (par exemple un petit service d'extinction installé sur le PC).
- **Entité Home Assistant** (ex. `switch.pc_bureau` de l'intégration Wake on LAN) :
  prioritaire en mode Home Assistant, l'allumage et l'extinction passent par Home Assistant.

La tablette doit être sur le même réseau local que l'ordinateur pour le réveil direct.

## Tablette murale

Dans **Réglages → Affichage** : **Garder l'écran allumé** et **Plein écran**. Le thème
**Automatique** suit le mode clair ou sombre de la tablette.

## Interface

Fonctionnelle avant tout : surfaces unies sans texture ni effet, texte grand et contrasté
(niveau AA des règles d'accessibilité WCAG), zones tactiles d'au moins 44 px, une seule
couleur d'accent, et les mêmes composants sur toutes les pages.
