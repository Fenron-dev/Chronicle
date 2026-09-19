// Datei: chronicle/lib/data/db/vault_note.dart
//
// ZWECK: Eine indizierte Notiz, wie die UI sie sieht — handgeschrieben, nicht
//        von Drift generiert.
//
// WARUM NICHT DIREKT DIE DRIFT-ZEILE: Zwei Gründe, die in dieselbe Richtung
//        zeigen.
//
//        1. Schichtung: Widgets sollen die Datenbank nicht kennen (Skill
//           `flutter-conventions`). Eine Drift-Zeile im Widget-Baum macht
//           jede Schema-Änderung zu einer UI-Änderung.
//        2. Build-Reihenfolge: riverpod_generator läuft VOR drift_dev. Eine
//           von Drift generierte Klasse in der Signatur eines
//           @riverpod-Providers existiert zu diesem Zeitpunkt noch nicht,
//           und der Generator bricht mit InvalidTypeException ab.
//
// SCHRITT: 3

import 'dart:convert';

/// Eine Notiz aus dem Index, entkoppelt vom Drift-Schema.
class VaultNote {
  const VaultNote({
    required this.id,
    required this.type,
    required this.title,
    required this.relPath,
    required this.scope,
    required this.ownerSlug,
    required this.updated,
    required this.tags,
  });

  final String id;
  final String type;
  final String title;
  final String relPath;

  /// `vault`, `system` oder `game`.
  final String scope;

  /// Slug des Systems bzw. der Partie, oder null im Vault-Scope.
  final String? ownerSlug;

  final DateTime updated;
  final List<String> tags;

  /// Liest die Tag-Liste aus der JSON-Spalte des Index.
  ///
  /// Kaputtes JSON ergibt eine leere Liste statt eines Wurfs: der Index ist
  /// regenerierbar, und eine Notiz ohne Tags ist besser als ein Baum, der
  /// sich nicht aufbauen lässt.
  static List<String> parseTags(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return [for (final item in decoded) item.toString()];
    } on FormatException {
      return const [];
    }
  }
}
