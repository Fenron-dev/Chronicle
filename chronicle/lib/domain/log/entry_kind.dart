// Datei: chronicle/lib/domain/log/entry_kind.dart
//
// ZWECK: Die Eintragstypen des Play-Logs (Konzept §4.1).
//
// WARUM IN domain/ UND NICHT IM THEME: Der Eintragstyp ist ein fachlicher
//        Begriff — er steht im Dateiformat und entscheidet über den
//        Narration-Filter des Story-Exports. Dass jeder Typ auch eine Farbe
//        hat, ist eine Darstellungsfrage; das Theme importiert deshalb von
//        hier, nicht umgekehrt. (Lag bis Schritt 4 unter core/theme/.)
//
// SCHRITT: 2, verschoben in Schritt 4

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
