// Datei: chronicle/lib/data/vault/table_repository.dart
//
// ZWECK: Tabellen, Orakel und Decks aus den Dateien des Vaults lesen.
//
// TABELLEN LEBEN IM SYSTEM-LAYER (Konzept §4.4). Ein Orakel gehört zum
//        Regelwerk, nicht zur Partie — sonst müsste es für jede neue Partie
//        kopiert werden, und eine Korrektur erreichte die alten nie.
//
// GELESEN WIRD AUS DER DATEI, nicht aus dem Index: der kennt Titel und Pfad,
//        die Einträge stehen im Markdown (CLAUDE.md §2.5). Der Index liefert
//        nur die Liste der Kandidaten.
//
// SIEHE: Skill `vault-format` (Abschnitt „Der Rumpf einer Tabelle")
// SCHRITT: 6

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/dev_log.dart';
import '../../domain/frontmatter/frontmatter.dart';
import '../../domain/roll_engine/oracle_table.dart';
import '../../domain/roll_engine/table_markdown.dart';

/// Eine geladene Tabelle samt Herkunft.
class VaultTable {
  const VaultTable({
    required this.table,
    required this.relPath,
    required this.systemSlug,
    this.problems = const [],
  });

  final OracleTable table;
  final String relPath;

  /// Zu welchem System sie gehört.
  final String? systemSlug;

  /// Was beim Prüfen auffiel — Lücken, fehlende Angaben. Nicht fatal.
  final List<String> problems;

  bool get isUsable => table.entries.isNotEmpty;
}

/// Liest Tabellendateien.
class TableRepository {
  const TableRepository();

  /// Lädt die Tabelle unter [relPath].
  ///
  /// Gibt null zurück, wenn die Datei fehlt oder kein Frontmatter trägt —
  /// eine einzelne kaputte Tabelle darf nicht den ganzen Roller lahmlegen.
  Future<VaultTable?> load(String rootPath, String relPath) async {
    final file = File(p.join(rootPath, relPath));
    if (!await file.exists()) return null;

    try {
      final doc = parseDocument(await file.readAsString());
      return _fromDocument(doc, relPath);
    } on FileSystemException catch (error) {
      devLog.warn('tables', 'Nicht lesbar: $relPath', error: error);
      return null;
    } on FormatException catch (error) {
      devLog.warn('tables', 'Frontmatter kaputt: $relPath', error: error);
      return null;
    }
  }

  /// Lädt mehrere Tabellen und überspringt, was nicht lesbar ist.
  Future<List<VaultTable>> loadAll(
    String rootPath,
    Iterable<String> relPaths,
  ) async {
    final out = <VaultTable>[];
    for (final relPath in relPaths) {
      final table = await load(rootPath, relPath);
      if (table != null) out.add(table);
    }
    return out;
  }

  VaultTable _fromDocument(ParsedDocument doc, String relPath) {
    final frontmatter = doc.frontmatter;
    final type = frontmatter['type']?.toString().toLowerCase();

    // `type: deck` ist die Kurzform für `table-type: deck` — im Skill so
    // festgelegt, damit ein Deck im Baum als Deck erscheint.
    final kind =
        TableKind.tryParse(frontmatter['table-type']) ??
        (type == 'deck' ? TableKind.deck : TableKind.uniform);

    final table = OracleTable(
      id: frontmatter['id'] as String? ?? relPath,
      title:
          frontmatter['title'] as String? ??
          p.basenameWithoutExtension(relPath),
      kind: kind,
      dice: frontmatter['dice']?.toString(),
      reversible: frontmatter['reversible'] == true,
      entries: parseTableEntries(doc.body),
    );

    return VaultTable(
      table: table,
      relPath: relPath,
      systemSlug: _systemOf(relPath),
      problems: validateTable(table),
    );
  }

  /// Der System-Ordner, in dem die Tabelle liegt.
  String? _systemOf(String relPath) {
    final parts = p.split(relPath.replaceAll('\\', '/'));
    if (parts.length >= 2 && parts[0] == 'systems') return parts[1];
    return null;
  }
}
