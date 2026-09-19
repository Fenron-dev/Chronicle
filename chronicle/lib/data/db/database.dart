// Datei: chronicle/lib/data/db/database.dart
//
// ZWECK: Der Vault-Index. Drift-Datenbank plus FTS5-Volltextindex.
//
// DIESE DATENBANK IST EIN CACHE. Sie darf jederzeit gelöscht und aus dem
//        Dateibaum neu aufgebaut werden. Deshalb gibt es hier auch keine
//        Migrationsketten für Inhaltsänderungen: bei einem Schema-Sprung
//        wird neu gebaut, nicht migriert (Skill `vault-format`).
//
// FTS5 wird per customStatement angelegt, nicht über eine .drift-Datei —
//        eine virtuelle Tabelle lässt sich in Drifts Dart-Schema nicht
//        ausdrücken, und ein zweiter Schema-Dialekt wäre mehr Aufwand als
//        Nutzen.
//
// SCHRITT: 3

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables/edges.dart';
import 'tables/notes.dart';
import 'vault_note.dart';

part 'database.g.dart';

/// Ein Suchtreffer aus dem Volltextindex.
class NoteSearchHit {
  const NoteSearchHit({
    required this.id,
    required this.title,
    required this.relPath,
    required this.snippet,
  });

  final String id;
  final String title;
  final String relPath;

  /// Textausschnitt mit Fundstelle, von FTS5 erzeugt.
  final String snippet;
}

@DriftDatabase(tables: [Notes, Edges])
class ChronicleDatabase extends _$ChronicleDatabase {
  ChronicleDatabase(super.e);

  /// Öffnet den Index eines Vaults.
  ChronicleDatabase.forFile(File file) : super(NativeDatabase(file));

  /// Für Tests und für einen Rebuild, dessen Ergebnis erst am Ende auf Platte
  /// landet.
  ChronicleDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createFtsSchema();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Legt den Volltextindex an.
  ///
  /// `unicode61 remove_diacritics 2` sorgt dafür, dass „Morwald" auch
  /// „Mörwald" findet — bei deutschen Spielnotizen keine Kleinigkeit.
  Future<void> _createFtsSchema() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
        note_id UNINDEXED,
        title,
        body,
        tags,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
  }

  /// Ob SQLite mit FTS5 gebaut wurde.
  ///
  /// Wird im Test geprüft, statt angenommen: ohne FTS5 wäre die Suche kaputt,
  /// und das soll nicht erst beim Nutzer auffallen.
  Future<bool> hasFts5() async {
    final rows = await customSelect(
      "SELECT 1 AS ok FROM pragma_compile_options "
      "WHERE compile_options = 'ENABLE_FTS5'",
    ).get();
    return rows.isNotEmpty;
  }

  /// Ersetzt den gesamten Index durch [notes] und [edges].
  ///
  /// Alles in EINER Transaktion: ein Abbruch mitten im Rebuild darf keinen
  /// halb gefüllten Index hinterlassen.
  Future<void> replaceIndex({
    required List<NotesCompanion> notes,
    required List<EdgesCompanion> edges,
    required List<({String id, String title, String body, String tags})>
    searchRows,
  }) async {
    await transaction(() async {
      await delete(this.notes).go();
      await delete(this.edges).go();
      await customStatement('DELETE FROM notes_fts');

      await batch((b) {
        b.insertAll(this.notes, notes);
        b.insertAll(this.edges, edges);
      });

      for (final row in searchRows) {
        await customInsert(
          'INSERT INTO notes_fts (note_id, title, body, tags) '
          'VALUES (?, ?, ?, ?)',
          variables: [
            Variable<String>(row.id),
            Variable<String>(row.title),
            Variable<String>(row.body),
            Variable<String>(row.tags),
          ],
        );
      }
    });
  }

  /// Volltextsuche über Titel, Text und Tags.
  Future<List<NoteSearchHit>> search(String query, {int limit = 50}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // Präfixsuche auf dem letzten Wort: der Nutzer tippt noch.
    final match = '${_escapeFts(trimmed)}*';

    final rows = await customSelect(
      '''
      SELECT n.id, n.title, n.rel_path,
             snippet(notes_fts, 2, '[', ']', '…', 12) AS snippet
      FROM notes_fts
      JOIN notes n ON n.id = notes_fts.note_id
      WHERE notes_fts MATCH ?
      ORDER BY bm25(notes_fts)
      LIMIT ?
      ''',
      variables: [Variable<String>(match), Variable<int>(limit)],
      readsFrom: {notes},
    ).get();

    return [
      for (final row in rows)
        NoteSearchHit(
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          relPath: row.read<String>('rel_path'),
          snippet: row.read<String>('snippet'),
        ),
    ];
  }

  /// Alle Notizen, die auf [noteId] verweisen.
  ///
  /// Genau eine Query — dafür gibt es die generische Edge-Tabelle.
  Future<List<VaultNote>> backlinksFor(String noteId) async {
    final query = select(notes).join([
      innerJoin(edges, edges.fromId.equalsExp(notes.id)),
    ])..where(edges.toId.equals(noteId));

    final rows = await query.get();
    return [for (final row in rows) _toVaultNote(row.readTable(notes))];
  }

  /// Alle Notizen des Index, gruppierbar nach Scope und Besitzer.
  Future<List<VaultNote>> allNotes() async {
    final rows =
        await (select(notes)..orderBy([
              (t) => OrderingTerm.asc(t.scope),
              (t) => OrderingTerm.asc(t.relPath),
            ]))
            .get();
    return [for (final row in rows) _toVaultNote(row)];
  }

  /// Alle Notizen eines Typs, neueste zuerst.
  Future<List<VaultNote>> notesOfType(String type) async {
    final rows =
        await (select(notes)
              ..where((t) => t.type.equals(type))
              ..orderBy([(t) => OrderingTerm.desc(t.updated)]))
            .get();
    return [for (final row in rows) _toVaultNote(row)];
  }

  /// Übersetzt eine Drift-Zeile in das UI-Modell.
  VaultNote _toVaultNote(Note row) => VaultNote(
    id: row.id,
    type: row.type,
    title: row.title,
    relPath: row.relPath,
    scope: row.scope,
    ownerSlug: row.ownerSlug,
    updated: row.updated,
    tags: VaultNote.parseTags(row.tagsJson),
  );

  Future<int> countNotes() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM notes',
      readsFrom: {notes},
    ).getSingle();
    return row.read<int>('c');
  }
}

/// Entschärft FTS5-Sonderzeichen.
///
/// Ohne das wirft eine Suche nach `"` oder `*` eine SQL-Exception statt
/// einfach nichts zu finden — ein Suchfeld darf nie werfen.
String _escapeFts(String input) {
  final cleaned = input.replaceAll(RegExp(r'["*()^:\-]'), ' ').trim();
  return cleaned.isEmpty ? '""' : '"$cleaned"';
}
