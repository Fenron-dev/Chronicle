// Datei: chronicle/lib/data/vault/vault_catalog.dart
//
// ZWECK: Systeme und Partien anlegen und auflisten — die beiden Container,
//        in denen alles andere lebt (Konzept §3.1).
//
// WARUM NICHT ÜBER DEN INDEX: Ein System ist ein ORDNER, keine Notiz. Der
//        Scanner liest nur .md-Dateien; system.json und game.json würden ihm
//        entgehen. Der Katalog liest deshalb direkt das Dateisystem — und
//        bleibt damit auch dann richtig, wenn der Index gerade neu gebaut
//        wird.
//
// SIEHE: Skill `vault-format`
// SCHRITT: 3c

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/frontmatter/frontmatter.dart';
import '../../domain/frontmatter/note_frontmatter.dart';
import '../../domain/slug.dart';
import 'vault_layout.dart';

const Uuid _uuid = Uuid();

/// Unterordner eines Systems (Konzept §3.1).
const List<String> kSystemSubDirs = [
  'tables',
  'decks',
  'templates',
  'sheets',
  'procedures',
  'theme',
];

/// Unterordner einer Partie (Konzept §3.1).
const List<String> kGameSubDirs = [
  'log',
  'codex',
  'entities',
  'sheets',
  'canvases',
  'media',
];

/// Ein Spielsystem im Vault.
class SystemEntry {
  const SystemEntry({
    required this.id,
    required this.slug,
    required this.name,
    required this.created,
    this.description = '',
  });

  /// UUID aus system.json — die Identität. Der Slug ist nur der Ordnername.
  final String id;
  final String slug;
  final String name;
  final DateTime created;
  final String description;

  factory SystemEntry.fromJson(Map<String, dynamic> json, String slug) =>
      SystemEntry(
        id: json['id'] as String? ?? '',
        slug: slug,
        name: json['name'] as String? ?? slug,
        created:
            DateTime.tryParse(json['created'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'name': name,
    'created': created.toUtc().toIso8601String(),
    if (description.isNotEmpty) 'description': description,
  };
}

/// Eine laufende Partie im Vault.
class GameEntry {
  const GameEntry({
    required this.id,
    required this.slug,
    required this.name,
    required this.created,
    required this.systemId,
    this.themePresetId,
  });

  final String id;
  final String slug;
  final String name;
  final DateTime created;

  /// UUID des Systems, auf das diese Partie sich bezieht — genau eines.
  final String systemId;

  /// Theme-Override der Partie. Null heißt: das System entscheidet.
  final String? themePresetId;

  factory GameEntry.fromJson(Map<String, dynamic> json, String slug) =>
      GameEntry(
        id: json['id'] as String? ?? '',
        slug: slug,
        name: json['name'] as String? ?? slug,
        created:
            DateTime.tryParse(json['created'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        systemId: json['systemId'] as String? ?? '',
        themePresetId: json['themePresetId'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'name': name,
    'created': created.toUtc().toIso8601String(),
    'systemId': systemId,
    if (themePresetId != null) 'themePresetId': themePresetId,
  };
}

/// Legt Systeme und Partien an und liest sie wieder ein.
class VaultCatalog {
  const VaultCatalog();

  static const String systemManifest = 'system.json';
  static const String gameManifest = 'game.json';

  // ── Lesen ─────────────────────────────────────────────────────────────────

  Future<List<SystemEntry>> listSystems(String rootPath) async {
    final entries = await _readManifests(
      VaultLayout.systems(rootPath),
      systemManifest,
      SystemEntry.fromJson,
    );
    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  Future<List<GameEntry>> listGames(String rootPath) async {
    final entries = await _readManifests(
      VaultLayout.games(rootPath),
      gameManifest,
      GameEntry.fromJson,
    );
    entries.sort((a, b) => b.created.compareTo(a.created));
    return entries;
  }

  /// Liest alle Manifeste eines Ordners.
  ///
  /// Ein unlesbares Manifest wird übersprungen, nicht geworfen: ein kaputter
  /// Ordner darf nicht den ganzen Katalog leeren.
  Future<List<T>> _readManifests<T>(
    String dirPath,
    String manifestName,
    T Function(Map<String, dynamic> json, String slug) parse,
  ) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final result = <T>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final slug = p.basename(entity.path);
      if (slug.startsWith('.')) continue;

      final manifest = File(p.join(entity.path, manifestName));
      if (!await manifest.exists()) continue;

      try {
        final raw = jsonDecode(await manifest.readAsString());
        if (raw is Map<String, dynamic>) result.add(parse(raw, slug));
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return result;
  }

  // ── Schreiben ─────────────────────────────────────────────────────────────

  /// Legt ein System an und liefert es zurück.
  Future<SystemEntry> createSystem(
    String rootPath, {
    required String name,
    String description = '',
  }) async {
    final taken = {for (final s in await listSystems(rootPath)) s.slug};
    final slug = uniqueSlug(name, taken);
    final dir = p.join(VaultLayout.systems(rootPath), slug);

    for (final sub in kSystemSubDirs) {
      await Directory(p.join(dir, sub)).create(recursive: true);
    }

    final entry = SystemEntry(
      id: _uuid.v4(),
      slug: slug,
      name: name.trim().isEmpty ? slug : name.trim(),
      created: DateTime.now().toUtc(),
      description: description.trim(),
    );

    await _writeJson(p.join(dir, systemManifest), entry.toJson());

    // Eine Regeldatei mit vollständigem Frontmatter: sie taucht dadurch
    // sofort im Index und im Navigations-Baum auf. Ein System, das nach dem
    // Anlegen nirgends erscheint, wirkt, als wäre nichts passiert.
    await _writeNote(
      p.join(dir, 'rules.md'),
      type: NoteType.codex,
      title: '${entry.name} — Regeln',
      body:
          '# ${entry.name} — Regeln\n'
          '\n'
          'Hier stehen die Regeltexte dieses Systems.\n'
          '\n'
          'Tabellen und Orakel gehören nach `tables/`, Decks nach `decks/`,\n'
          'Vorlagen für Entities nach `templates/`.\n',
    );

    return entry;
  }

  /// Legt eine Partie an, die sich auf [systemId] bezieht.
  Future<GameEntry> createGame(
    String rootPath, {
    required String name,
    required String systemId,
  }) async {
    final taken = {for (final g in await listGames(rootPath)) g.slug};
    final slug = uniqueSlug(name, taken);
    final dir = p.join(VaultLayout.games(rootPath), slug);

    for (final sub in kGameSubDirs) {
      await Directory(p.join(dir, sub)).create(recursive: true);
    }

    final entry = GameEntry(
      id: _uuid.v4(),
      slug: slug,
      name: name.trim().isEmpty ? slug : name.trim(),
      created: DateTime.now().toUtc(),
      systemId: systemId,
    );

    await _writeJson(p.join(dir, gameManifest), entry.toJson());

    // Ein erster Log-Thread, damit die Partie nicht leer beginnt und der
    // Baum sofort etwas zeigt.
    await _writeNote(
      p.join(dir, 'log', 'sitzung-1.md'),
      type: NoteType.log,
      title: 'Sitzung 1',
      body:
          '# Sitzung 1\n'
          '\n'
          'Der erste Eintrag dieser Partie.\n',
    );

    return entry;
  }

  Future<void> _writeJson(String path, Map<String, dynamic> json) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  /// Schreibt eine Notiz mit vollständigem Frontmatter.
  ///
  /// Vollständig heißt: mit `id`. Ohne sie vergäbe der Scanner beim ersten
  /// Durchlauf eine neue und schriebe die Datei sofort wieder um — unnötig,
  /// wenn wir die Datei ohnehin gerade selbst erzeugen.
  ///
  /// Über serializeDocument statt von Hand: ein Doppelpunkt im Systemnamen
  /// („Ironsworn: Starforged") würde handgeschriebenes YAML zerlegen. Der
  /// Serialisierer setzt die nötigen Anführungszeichen.
  Future<void> _writeNote(
    String path, {
    required NoteType type,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now().toUtc();
    final frontmatter = NoteFrontmatter(
      id: _uuid.v4(),
      type: type,
      title: title,
      created: now,
      updated: now,
    );

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(serializeDocument(frontmatter.toMap(), body));
  }
}
