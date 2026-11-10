# sDash — notes pour Claude

- **Toujours communiquer avec l'utilisateur en français.** L'interface, les commentaires
  et les messages de commit sont aussi en français.
- Application Flutter (Android d'abord) : tableau de bord domotique.
- Direction artistique demandée par l'utilisateur : **fonctionnel, clair, simple
  d'utilisation**. Interface à plat (ni texture, ni flou, ni dégradé décoratif), tons chauds,
  thème clair et thème sombre (Réglages → Affichage, automatique par défaut). Ne pas
  réintroduire les anciens styles « verre » et « cuir » (restés dans l'historique git).
  - Couleurs uniquement par rôle : `context.colors` / `context.text` (`lib/ui/theme.dart`),
    jamais de couleur en dur dans un widget.
  - Tuile ambrée = appareil allumé, tuile neutre = éteint (`ToggleTile`, `Tile`).
  - Commandes directes : boutons − / + pour le chauffage, ▲ ■ ▼ pour les volets ; zones
    tactiles d'au moins 44 px ; contraste AA.
  - Composants dans `lib/ui/widgets/` (`controls.dart`, `tiles.dart`, `device_tiles.dart`) ;
    chaque page commence par `PageHeader` (via `AppPage`).
- Vérifications avant de pousser : `flutter analyze` et `flutter test` (les tests d'affichage
  de `test/app_test.dart` parcourent toutes les pages sur 4 tailles d'écran).
- Formatage : `dart format -l 120 lib test`.
- Les sources domotiques implémentent `HomeBackend` (`lib/data/home_backend.dart`) ;
  le mode démo (`DemoBackend`) est la source par défaut.
- L'APK est produit par `.github/workflows/build-apk.yml` (artefact `sdash-apk`) et publié
  en Release (`sdash.apk`) à chaque envoi sur la branche par défaut.
- Logo choisi par l'utilisateur (conservé malgré l'interface à plat) : cuir capitonné,
  « s » gravé (pas cousu, pas de verre).
  Source : `tools/logo/generer_logo.py` → `docs/logo/*.svg` ; les PNG (mipmaps Android,
  icônes web, `assets/branding/logo.png`) sont des exports de ces SVG.
