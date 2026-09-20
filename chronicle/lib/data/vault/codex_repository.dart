// Datei: chronicle/lib/data/vault/codex_repository.dart
//
// ZWECK: Codex-Seiten lesen, anlegen und speichern.
//
// UNTERSCHIED ZUM PLAY-LOG: Das Log wird angehängt, der Codex ersetzt. Ein
//        Speichern überschreibt hier den ganzen Rumpf — deshalb ist genau
//        hier die Stelle, an der vorher eine Fassung in die Versions-History
//        gehört (CLAUDE.md §8, Schritt 5). Den Aufruf macht die
//        Provider-Schicht: `data/` kennt `services/` nicht.
//
// ERST DATEI, DANN INDEX — wie überall (Skill `vault-format`).
//
// SCHRITT: 5

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/frontmatter/frontmatter.dart';
import '../../domain/frontmatter/note_frontmatter.dart';

const Uuid _uuid = Uuid();

/// Eine geladene Codex-Seite.
class CodexPage {
  const CodexPage({
    required this.noteId,
    required this.relPath,
    required this.title,
    required this.body,
    required this.frontmatter,
  });

  final String noteId;
  final String relPath;
  final String title;

  /// Der Markdown-Rumpf ohne Frontmatter — genau das, was im Editor steht.
  final String body;

  /// Das vollständige Frontmatter, unverändert. Mitgeführt, damit fremde
  /// Schlüssel (banner, accent-color, was Obsidian ergänzt hat) beim
  /// Speichern nicht verloren gehen.
  final Map<String, dynamic> frontmatter;
}

/// Liest und schreibt Codex-Dateien im Vault.
class CodexRepository {
  const CodexRepository();

  Future<CodexPage> load(String rootPath, String relPath) async {
    final file = File(p.join(rootPath, relPath));
    final doc = parseDocument(await file.readAsString());

    return CodexPage(
      noteId: doc.frontmatter['id'] as String? ?? '',
      relPath: relPath,
      title:
          doc.frontmatter['title'] as String? ??
          p.basenameWithoutExtension(relPath),
      body: doc.body,
      frontmatter: doc.frontmatter,
    );
  }

  /// Schreibt [body] in die Datei und zieht `updated` mit.
  ///
  /// [title] wird nur gesetzt, wenn er übergeben wird — sonst bliebe eine
  /// Umbenennung im Frontmatter unsichtbar, und der Baum zeigte weiter den
  /// alten Namen.
  Future<void> save(
    String rootPath,
    String relPath, {
    required String body,
    String? title,
  }) async {
    final file = File(p.join(rootPath, relPath));
    final doc = parseDocument(await file.readAsString());

    final frontmatter = Map<String, dynamic>.from(doc.frontmatter)
      ..['updated'] = DateTime.now().toUtc().toIso8601String();
    if (title != null && title.trim().isNotEmpty) {
      frontmatter['title'] = title.trim();
    }

    // Genau ein abschließender Zeilenumbruch: sonst wächst die Datei bei
    // jedem Speichern um eine Leerzeile, und ein git-Diff zeigt Änderungen,
    // die niemand gemacht hat.
    await file.writeAsString(
      serializeDocument(frontmatter, '${body.trimRight()}\n'),
    );
  }

  /// Legt eine neue Seite unter `games/<slug>/codex/` an.
  Future<String> create(
    String rootPath,
    String gameSlug, {
    required String title,
    required String fileStem,
  }) async {
    final relPath = 'games/$gameSlug/codex/$fileStem.md';
    final file = File(p.join(rootPath, relPath));
    await file.parent.create(recursive: true);

    final now = DateTime.now().toUtc();
    final frontmatter = NoteFrontmatter(
      id: _uuid.v4(),
      type: NoteType.codex,
      title: title,
      created: now,
      updated: now,
    );

    // Eine Überschrift als Startpunkt: eine völlig leere Datei sieht im
    // Baum wie ein Fehlschlag aus.
    await file.writeAsString(
      serializeDocument(frontmatter.toMap(), '# $title\n'),
    );
    return relPath;
  }

  /// Löscht eine Seite.
  ///
  /// Die Versions-History bleibt liegen — wer eine Seite versehentlich
  /// löscht, soll ihren Text zurückholen können.
  Future<void> delete(String rootPath, String relPath) async {
    final file = File(p.join(rootPath, relPath));
    if (await file.exists()) await file.delete();
  }
}
