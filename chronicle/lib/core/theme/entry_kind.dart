// Datei: chronicle/lib/core/theme/entry_kind.dart
//
// ZWECK: Die Eintragstypen des Play-Logs. Liegt im Theme-Layer, weil jeder
//        Typ eine eigene Farbe im Token-Set hat — und weil das Play-Log
//        (Schritt 4) denselben Enum für die Serialisierung braucht.
//
// WARUM HIER UND NICHT IN features/play_log: Das Theme darf nicht von einem
//        Feature abhängen, das Feature aber vom Theme. Also wohnt der Enum
//        unten.
//
// SCHRITT: 2

/// Art eines Log-Eintrags.
///
/// Die Reihenfolge ist die Anzeigereihenfolge in Legenden und Filtern.
/// Der `name` jedes Werts landet so im Frontmatter der Log-Datei
/// (siehe Skill `vault-format`) — Werte deshalb nicht umbenennen, ohne eine
/// Migration vorzusehen.
enum EntryKind {
  narration,
  roll,
  oracle,
  card,
  plotbeat,
  ai,
  meta;

  /// Ob der Typ zur eigentlichen Erzählung gehört.
  ///
  /// Steuert den Sichtbarkeits-Toggle im Play-Log und den Filter
  /// „nur Narration" im Story-Export (Konzept §8).
  bool get isNarrative =>
      this == EntryKind.narration || this == EntryKind.plotbeat;
}
