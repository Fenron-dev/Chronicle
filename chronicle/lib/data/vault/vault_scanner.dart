// Datei: chronicle/lib/data/vault/vault_scanner.dart
//
// ZWECK: Läuft den Vault-Dateibaum ab und liefert die Roh-Einträge für den
//        Index-Rebuild.
//
// WARUM GETRENNT VOM REBUILDER: Der Scanner kennt kein Drift. Er wird auch
//        für den Bundle-Export (Konzept §8) gebraucht, wo nichts indiziert
//        werden soll.
//
// EINE KAPUTTE DATEI BLOCKIERT NIE DEN SCAN. Sie wird übersprungen,
//        gesammelt und am Ende als Liste gemeldet — sonst macht eine defekte
//        Notiz den kompletten Vault unbenutzbar.
//
// SIEHE: Skill `vault-format`
// SCHRITT: 3

import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../domain/frontmatter/frontmatter.dart';
import '../../domain/frontmatter/note_frontmatter.dart';
import '../../domain/wikilink/wikilink.dart';
import 'vault_layout.dart';

const Uuid _uuid = Uuid();

/// Wo eine Datei im Vault liegt.
enum NoteScope { vault, system, game }

/// Eine eingelesene Notiz.
class ScannedNote {
  const ScannedNote({
    required this.frontmatter,
    required this.relPath,
    required this.scope,
    required this.ownerSlug,
    required this.body,
    required this.links,
  });

  final NoteFrontmatter frontmatter;
  final String relPath;
  final NoteScope scope;

  /// Slug des Systems bzw. Games, oder null im Vault-Scope.
  final String? ownerSlug;

  final String body;
  final List<WikiLink> links;

  /// Dateiname ohne Endung — das zweite Ziel, unter dem ein Wikilink
  /// auflösen kann.
  String get fileStem {
    final name = relPath.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}

/// Eine Datei, die nicht eingelesen werden konnte.
class ScanProblem {
  const ScanProblem(this.relPath, this.reason);

  final String relPath;
  final String reason;
}

/// Ergebnis eines Scans.
class ScanResult {
  const ScanResult({required this.notes, required this.problems});

  final List<ScannedNote> notes;
  final List<ScanProblem> problems;

  bool get hasProblems => problems.isNotEmpty;
}

/// Liest alle Markdown-Dateien eines Vaults ein.
class VaultScanner {
  const VaultScanner();

  /// Scannt den Vault unter [rootPath].
  ///
  /// Dateien ohne vollständiges Frontmatter werden ergänzt und
  /// zurückgeschrieben — sonst bekämen sie bei jedem Rebuild eine neue `id`
  /// und verlören ihre Identität.
  Future<ScanResult> scan(String rootPath) async {
    final notes = <ScannedNote>[];
    final problems = <ScanProblem>[];
    final now = DateTime.now().toUtc();

    final root = Directory(rootPath);
    if (!await root.exists()) {
      return const ScanResult(notes: [], problems: []);
    }

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.md')) continue;

      final relPath = VaultLayout.relativeTo(rootPath, entity.path);
      if (VaultLayout.isIgnored(relPath)) continue;
      // Die README erklärt den Ordner einem Menschen; sie ist kein Inhalt.
      if (relPath == VaultLayout.readmeFile) continue;

      try {
        final source = await entity.readAsString();
        final parsed = parseDocument(source);
        final (scope, ownerSlug) = _scopeOf(relPath);

        final frontmatter = NoteFrontmatter.fromMap(
          parsed.frontmatter,
          fallbackId: _uuid.v4(),
          fallbackTitle: _titleFrom(relPath, parsed.body),
          fallbackType: _typeFrom(relPath),
          now: now,
        );

        if (!NoteFrontmatter.isComplete(parsed.frontmatter)) {
          await _writeBack(entity, frontmatter, parsed.body);
        }

        notes.add(
          ScannedNote(
            frontmatter: frontmatter,
            relPath: relPath,
            scope: scope,
            ownerSlug: ownerSlug,
            body: parsed.body,
            links: parseWikiLinks(parsed.body),
          ),
        );
      } on FileSystemException catch (error) {
        problems.add(ScanProblem(relPath, 'Nicht lesbar: ${error.message}'));
      } on FormatException catch (error) {
        problems.add(
          ScanProblem(relPath, 'Kein gültiger Text: ${error.message}'),
        );
      }
    }

    notes.sort((a, b) => a.relPath.compareTo(b.relPath));
    return ScanResult(notes: notes, problems: problems);
  }

  /// Schreibt ergänztes Frontmatter zurück in die Datei.
  ///
  /// Fehlschläge sind hier nicht fatal: ein schreibgeschützter Vault soll
  /// lesbar bleiben. Die Notiz bekommt dann bei jedem Rebuild eine neue id —
  /// unschön, aber besser als gar kein Zugriff.
  Future<void> _writeBack(
    File file,
    NoteFrontmatter frontmatter,
    String body,
  ) async {
    try {
      await file.writeAsString(serializeDocument(frontmatter.toMap(), body));
    } on FileSystemException {
      // bewusst verschluckt — siehe Doc-Kommentar
    }
  }

  (NoteScope, String?) _scopeOf(String relPath) {
    final parts = relPath.split('/');
    if (parts.length >= 2 && parts[0] == VaultLayout.systemsDir) {
      return (NoteScope.system, parts[1]);
    }
    if (parts.length >= 2 && parts[0] == VaultLayout.gamesDir) {
      return (NoteScope.game, parts[1]);
    }
    return (NoteScope.vault, null);
  }

  /// Rät den Typ aus dem Ablageort.
  ///
  /// Das Frontmatter gewinnt immer; das hier greift nur bei einer von Hand
  /// angelegten Datei. Die Ablageorte sind die aus dem System-Layout, also
  /// ist die Vermutung meistens richtig.
  NoteType _typeFrom(String relPath) {
    final parts = relPath.split('/');
    for (final segment in parts) {
      switch (segment) {
        case 'log':
          return NoteType.log;
        case 'codex':
          return NoteType.codex;
        case 'entities':
          return NoteType.entity;
        case 'tables':
          return NoteType.table;
        case 'decks':
          return NoteType.deck;
        case 'sheets':
          return NoteType.sheet;
        case 'procedures':
          return NoteType.procedure;
        case 'canvases':
          return NoteType.canvas;
      }
    }
    return NoteType.codex;
  }

  /// Titel aus der ersten Überschrift, sonst aus dem Dateinamen.
  String _titleFrom(String relPath, String body) {
    for (final line in body.split('\n')) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('# ')) {
        final heading = trimmed.substring(2).trim();
        if (heading.isNotEmpty) return heading;
      }
      // Nur die ersten Zeilen ansehen — eine Überschrift auf Seite drei ist
      // nicht der Titel der Notiz.
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) break;
    }

    final name = relPath.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}
