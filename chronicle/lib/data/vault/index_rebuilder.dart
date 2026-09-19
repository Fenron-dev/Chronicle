// Datei: chronicle/lib/data/vault/index_rebuilder.dart
//
// ZWECK: Baut den Index aus dem Scan-Ergebnis neu auf — die Referenz-
//        Implementierung der obersten Vault-Regel.
//
// „Vault auf fremdem Rechner öffnen → Index rebuild → alles da" muss
//        jederzeit gelten. Deshalb ist der vollständige Rebuild kein
//        Notbehelf, sondern der getestete Normalfall.
//
// SIEHE: Skill `vault-format`
// SCHRITT: 3

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/wikilink/wikilink.dart';
import '../db/database.dart';
import 'vault_scanner.dart';

const Uuid _uuid = Uuid();

/// Was ein Rebuild erbracht hat.
class RebuildReport {
  const RebuildReport({
    required this.noteCount,
    required this.edgeCount,
    required this.unresolvedLinks,
    required this.problems,
  });

  final int noteCount;
  final int edgeCount;

  /// Links, deren Ziel (noch) nicht existiert.
  ///
  /// Kein Fehler: Nutzer schreiben den Link oft, bevor sie die Seite anlegen.
  final int unresolvedLinks;

  final List<ScanProblem> problems;
}

/// Baut den Volltext- und Relationsindex aus den Dateien auf.
class IndexRebuilder {
  const IndexRebuilder(this.database);

  final ChronicleDatabase database;

  /// Ersetzt den gesamten Index durch den Inhalt von [scan].
  Future<RebuildReport> rebuild(ScanResult scan) async {
    // Auflösungstabelle: Titel und Dateiname zeigen beide auf die id.
    // Links werden nach NAMEN aufgelöst, nicht nach Pfad — so überlebt ein
    // Link das Verschieben der Zieldatei (Skill `vault-format`).
    final byName = <String, String>{};
    for (final note in scan.notes) {
      byName.putIfAbsent(
        _key(note.frontmatter.title),
        () => note.frontmatter.id,
      );
      byName.putIfAbsent(_key(note.fileStem), () => note.frontmatter.id);
    }

    final noteRows = <NotesCompanion>[];
    final edgeRows = <EdgesCompanion>[];
    final searchRows =
        <({String id, String title, String body, String tags})>[];
    var unresolved = 0;

    for (final note in scan.notes) {
      final fm = note.frontmatter;

      noteRows.add(
        NotesCompanion.insert(
          id: fm.id,
          type: fm.type.name,
          title: fm.title,
          relPath: note.relPath,
          scope: note.scope.name,
          ownerSlug: Value(note.ownerSlug),
          created: fm.created,
          updated: fm.updated,
          tagsJson: Value(jsonEncode(fm.tags)),
          propertiesJson: Value(jsonEncode(fm.properties)),
        ),
      );

      searchRows.add((
        id: fm.id,
        title: fm.title,
        body: note.body,
        tags: fm.tags.join(' '),
      ));

      // Doppelte Links auf dasselbe Ziel erzeugen nur eine Kante: das
      // Backlink-Panel soll eine Seite einmal nennen, nicht siebenmal.
      final seen = <String>{};
      for (final link in note.links) {
        final targetId = byName[_key(link.target)];
        if (targetId == null) unresolved++;

        final relation = link.isEmbed ? 'embeds' : 'links_to';
        final dedupeKey = '$relation:${targetId ?? _key(link.target)}';
        if (!seen.add(dedupeKey)) continue;

        edgeRows.add(
          EdgesCompanion.insert(
            id: _uuid.v4(),
            fromType: 'note',
            fromId: fm.id,
            toType: link.isEmbed ? 'media' : 'note',
            toId: Value(targetId),
            toName: link.target,
            relation: relation,
          ),
        );
      }
    }

    await database.replaceIndex(
      notes: noteRows,
      edges: edgeRows,
      searchRows: searchRows,
    );

    return RebuildReport(
      noteCount: noteRows.length,
      edgeCount: edgeRows.length,
      unresolvedLinks: unresolved,
      problems: scan.problems,
    );
  }

  /// Normalisiert einen Namen für die Auflösung.
  ///
  /// Links sollen unabhängig von Groß-/Kleinschreibung und Randleerzeichen
  /// treffen — `[[mörwald]]` und `[[Mörwald]]` meinen dasselbe.
  static String _key(String name) => name.trim().toLowerCase();
}
