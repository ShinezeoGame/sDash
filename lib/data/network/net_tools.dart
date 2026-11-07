// Outils réseau locaux. L'implémentation réelle utilise `dart:io` (Android) ;
// sur le web (aperçu navigateur) ces fonctions ne sont pas disponibles.
export 'net_tools_stub.dart' if (dart.library.io) 'net_tools_io.dart';
