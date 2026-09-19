// Datei: chronicle/lib/data/db/tables/edges.dart
//
// ZWECK: Generische Relationstabelle. Ersetzt Fremdschlüssel-Spalten je
//        Beziehungsart.
//
// WARUM GENERISCH: Backlinks kommen so aus EINER Query, und ein neuer
//        Relationstyp braucht keine Migration. Das Muster stammt aus
//        OracleVault und hat sich dort bewährt.
//
// REDUNDANT UND REGENERIERBAR: Jede Kante wird beim Speichern aus dem
//        Rohtext erzeugt. Eine Kante, die sich nicht aus einer Datei
//        herleiten lässt, darf es nicht geben.
//
// SCHRITT: 3

import 'package:drift/drift.dart';

class Edges extends Table {
  TextColumn get id => text()();

  /// Typ der Quelle — derzeit immer `note`.
  TextColumn get fromType => text()();

  /// UUID der Quelle.
  TextColumn get fromId => text()();

  TextColumn get toType => text()();

  /// UUID des Ziels, oder null bei einem noch nicht auflösbaren Link.
  ///
  /// Nutzer schreiben den Link oft, bevor das Ziel existiert. Ein solcher
  /// Link ist kein Fehler, sondern eine Absicht — er wird als unaufgelöste
  /// Kante behalten und aufgelöst, sobald das Ziel angelegt wird.
  TextColumn get toId => text().nullable()();

  /// Der im Text geschriebene Zielname, unverändert.
  TextColumn get toName => text()();

  /// `links_to`, `embeds`, `child_of`, `translation_of`, …
  TextColumn get relation => text()();

  @override
  Set<Column> get primaryKey => {id};
}
