// Datei: chronicle/lib/data/db/tables/notes.dart
//
// ZWECK: Index-Zeile je Vault-Datei.
//
// WICHTIG: Diese Tabelle ist ein INDEX, kein Speicherort. Jede Spalte hier
//        muss aus der Datei im Vault wiederherstellbar sein — sonst geht die
//        Information beim nächsten Rebuild verloren (Skill `vault-format`).
//
// SCHRITT: 3

import 'package:drift/drift.dart';

class Notes extends Table {
  /// UUID v4 aus dem Frontmatter der Datei — nicht aus der DB.
  TextColumn get id => text()();

  /// NoteType.name: log | codex | entity | table | deck | sheet | procedure | canvas
  TextColumn get type => text()();

  TextColumn get title => text()();

  /// Pfad relativ zum Vault-Wurzelverzeichnis, immer mit `/` als Trenner.
  /// Ein absoluter Pfad bräche die Portabilität (CLAUDE.md §2.2).
  TextColumn get relPath => text()();

  /// `system`, `game` oder `vault` — wo die Datei liegt.
  TextColumn get scope => text()();

  /// Slug des Systems bzw. Games, zu dem die Datei gehört.
  TextColumn get ownerSlug => text().nullable()();

  DateTimeColumn get created => dateTime()();
  DateTimeColumn get updated => dateTime()();

  /// Tags als JSON-Array. Der Index braucht sie abfragbar, die Wahrheit
  /// steht im Frontmatter.
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();

  /// EAV-Properties als JSON-Objekt.
  TextColumn get propertiesJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
