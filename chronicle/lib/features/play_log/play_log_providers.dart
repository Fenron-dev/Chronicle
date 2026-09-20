// Datei: chronicle/lib/features/play_log/play_log_providers.dart
//
// ZWECK: Anzeige-Zustand des Play-Logs.
//
// WARUM KEIN StateProvider: Riverpod 3 führt ihn nur noch als Legacy. Der
//        Skill `flutter-conventions` verlangt ohnehin generierte Provider —
//        das hier ist derselbe Zustand in zwei Zeilen mehr und ohne
//        Altlast.
//
// SCHRITT: 4

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'play_log_providers.g.dart';

/// Ob Würfe, Orakel und Meta-Einträge mitlaufen.
///
/// Der Sichtbarkeits-Toggle aus Konzept §4.1: nicht-narrative Einträge
/// einklappen für den sauberen Lesefluss.
///
/// keepAlive, weil die Einstellung eine Lesegewohnheit ist — sie soll einen
/// Thread-Wechsel überleben.
@Riverpod(keepAlive: true)
class ShowMechanicalEntries extends _$ShowMechanicalEntries {
  @override
  bool build() => true;

  void toggle() => state = !state;
}
