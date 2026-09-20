// Datei: chronicle/lib/data/vault/log_repository.dart
//
// ZWECK: Log-Threads lesen und Einträge anhängen.
//
// DIE REIHENFOLGE IST DIE REGEL: erst in die Datei schreiben, dann
//        indizieren. Ein Eintrag, der nur im Index landet, ist beim nächsten
//        Rebuild weg — und der Rebuild ist kein Ausnahmefall, er läuft bei
//        jedem Öffnen des Vaults (Skill `vault-format`).
//
// SCHRITT: 4

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/frontmatter/frontmatter.dart';
import '../../domain/frontmatter/note_frontmatter.dart';
import '../../domain/log/entry_kind.dart';
import '../../domain/log/log_entry.dart';

const Uuid _uuid = Uuid();

/// Ein geladener Log-Thread.
class LogThread {
  const LogThread({
    required this.noteId,
    required this.relPath,
    required this.title,
    required this.preamble,
    required this.entries,
  });

  final String noteId;
  final String relPath;
  final String title;

  /// Der Text vor dem ersten Eintrag — meist die Überschrift der Datei.
  final String preamble;

  final List<LogEntry> entries;
}

/// Liest und schreibt Log-Dateien im Vault.
class LogRepository {
  const LogRepository();

  /// Lädt den Thread unter [relPath].
  Future<LogThread> load(String rootPath, String relPath) async {
    final file = File(p.join(rootPath, relPath));
    final source = await file.readAsString();
    final doc = parseDocument(source);

    return LogThread(
      noteId: doc.frontmatter['id'] as String? ?? '',
      relPath: relPath,
      title:
          doc.frontmatter['title'] as String? ??
          p.basenameWithoutExtension(relPath),
      preamble: logPreamble(doc.body),
      entries: parseLogEntries(doc.body),
    );
  }

  /// Hängt einen Eintrag an und schreibt die Datei.
  ///
  /// Gibt den Eintrag zurück, damit der Aufrufer ihn anzeigen kann, ohne neu
  /// laden zu müssen.
  Future<LogEntry> appendEntry(
    String rootPath,
    String relPath, {
    required EntryKind kind,
    required String text,
  }) async {
    final file = File(p.join(rootPath, relPath));
    final source = await file.readAsString();
    final doc = parseDocument(source);

    final entry = LogEntry(
      id: _uuid.v4(),
      kind: kind,
      timestamp: DateTime.now().toUtc(),
      text: text.trim(),
    );

    final body = appendLogEntry(doc.body, entry);

    // `updated` mitziehen: sonst sortiert der Baum nach einem Zeitstempel,
    // der nicht mehr stimmt.
    final frontmatter = Map<String, dynamic>.from(doc.frontmatter)
      ..['updated'] = DateTime.now().toUtc().toIso8601String();

    await file.writeAsString(serializeDocument(frontmatter, '$body\n'));
    return entry;
  }

  /// Legt einen neuen Thread in `log/` der Partie an.
  Future<String> createThread(
    String rootPath,
    String gameSlug, {
    required String title,
    required String fileStem,
  }) async {
    final relPath = 'games/$gameSlug/log/$fileStem.md';
    final file = File(p.join(rootPath, relPath));
    await file.parent.create(recursive: true);

    final now = DateTime.now().toUtc();
    final frontmatter = NoteFrontmatter(
      id: _uuid.v4(),
      type: NoteType.log,
      title: title,
      created: now,
      updated: now,
    );

    await file.writeAsString(
      serializeDocument(frontmatter.toMap(), '# $title\n'),
    );
    return relPath;
  }
}
