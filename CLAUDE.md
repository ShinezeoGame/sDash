# sDash — notes pour Claude

- **Toujours communiquer avec l'utilisateur en français.** L'interface, les commentaires
  et les messages de commit sont aussi en français.
- Application Flutter (Android d'abord) : tableau de bord domotique aux tons cuir / cognac
  (palette dans `lib/ui/theme.dart`). Deux matières : **cuir** (par défaut) et verre dépoli,
  choisies dans Réglages → Affichage. Les composants ne dessinent jamais leur matière
  eux-mêmes : ils passent par `AppLook.of(context)` (`surface()`, `active()`) et
  `SurfaceCard` / `SurfacePill` (`lib/ui/widgets/surface.dart`).
- Vérifications avant de pousser : `flutter analyze` et `flutter test` (les tests d'affichage
  de `test/app_test.dart` parcourent toutes les pages sur 4 tailles d'écran).
- Formatage : `dart format -l 120 lib test`.
- Les sources domotiques implémentent `HomeBackend` (`lib/data/home_backend.dart`) ;
  le mode démo (`DemoBackend`) est la source par défaut.
- L'APK est produit par `.github/workflows/build-apk.yml` (artefact `sdash-apk`) et publié
  en Release (`sdash.apk`) à chaque envoi sur la branche par défaut.
- Logo choisi par l'utilisateur : cuir capitonné, « s » gravé (pas cousu, pas de verre).
  Source : `tools/logo/generer_logo.py` → `docs/logo/*.svg` ; les PNG (mipmaps Android,
  icônes web, `assets/branding/logo.png`) sont des exports de ces SVG.
