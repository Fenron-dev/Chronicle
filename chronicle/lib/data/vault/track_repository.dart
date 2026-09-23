// Datei: chronicle/lib/data/vault/track_repository.dart
//
// ZWECK: Clocks und Step-Tracks einer Partie lesen, anlegen und ändern.
//
// ABLAGE: `games/<slug>/entities/` als `type: entity` mit `entity-type:
//        clock` bzw. `track` (Skill `vault-format`). Clocks und Tracks
//        gehören zur PARTIE, nicht zum System: ein System liefert Regeln, die
//        Spannung einer laufenden Geschichte ist Zustand dieser einen Partie.
//
// SCHREIBEN ÄNDERT SO WENIG WIE MÖGLICH: eine Clock ändert nur `filled` und
//        `updated` im Frontmatter, ein Track nur die eine Kästchen-Zeile. Der
//        Rest der Datei gehört dem Nutzer.
//
// SCHRITT: 8

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/dev_log.dart';
import '../../domain/frontmatter/frontmatter.dart';
import '../../domain/frontmatter/note_frontmatter.dart';
import '../../domain/tracks/track.dart';

const Uuid _uuid = Uuid();

/// Clock oder Track.
enum TrackKind { clock, track }

/// Eine geladene Clock oder ein geladener Track.
class GameTrack {
  const GameTrack({
    required this.id,
    required this.relPath,
    required this.title,
    required this.kind,
    this.clock,
    this.beats = const [],
  });

  final String id;
  final String relPath;
  final String title;
  final TrackKind kind;

  /// Nur bei [TrackKind.clock].
  final ClockState? clock;

  /// Nur bei [TrackKind.track].
  final List<TrackBeat> beats;

  TrackProgress get progress => TrackProgress.of(beats);
}

/// Wurde eine Datei zwischen Lesen und Schreiben außerhalb geändert, und das
/// Ziel des Schreibens steht nicht mehr da, wo es war.
class StaleTrackException implements Exception {
  const StaleTrackException(this.relPath);

  final String relPath;

  String get message =>
      'Die Datei wurde zwischenzeitlich geändert. Bitte neu laden und '
      'noch einmal versuchen.';

  @override
  String toString() => 'StaleTrackException($relPath)';
}

class TrackRepository {
  const TrackRepository();

  /// Lädt [relPath], oder null, wenn die Datei keine Clock und kein Track ist.
  Future<GameTrack?> load(String rootPath, String relPath) async {
    final file = File(p.join(rootPath, relPath));
    if (!await file.exists()) return null;

    try {
      final doc = parseDocument(await file.readAsString());
      return _fromDocument(doc, relPath);
    } on FileSystemException catch (error) {
      devLog.warn('tracks', 'Nicht lesbar: $relPath', error: error);
      return null;
    } on FormatException catch (error) {
      devLog.warn('tracks', 'Frontmatter kaputt: $relPath', error: error);
      return null;
    }
  }

  Future<List<GameTrack>> loadAll(
    String rootPath,
    Iterable<String> relPaths,
  ) async {
    final out = <GameTrack>[];
    for (final relPath in relPaths) {
      final track = await load(rootPath, relPath);
      if (track != null) out.add(track);
    }
    return out;
  }

  GameTrack? _fromDocument(ParsedDocument doc, String relPath) {
    final fm = doc.frontmatter;
    final entityType = fm['entity-type']?.toString().toLowerCase();
    final title = fm['title'] as String? ?? p.basenameWithoutExtension(relPath);
    final id = fm['id'] as String? ?? relPath;

    return switch (entityType) {
      'clock' => GameTrack(
        id: id,
        relPath: relPath,
        title: title,
        kind: TrackKind.clock,
        clock: ClockState.fromValues(fm['segments'], fm['filled']),
      ),
      'track' => GameTrack(
        id: id,
        relPath: relPath,
        title: title,
        kind: TrackKind.track,
        beats: parseBeats(doc.body),
      ),
      _ => null,
    };
  }

  /// Legt eine Clock an.
  Future<String> createClock(
    String rootPath,
    String gameSlug, {
    required String title,
    required String fileStem,
    required int segments,
  }) async {
    final clamped = segments.clamp(kMinClockSegments, kMaxClockSegments);
    return _create(
      rootPath,
      gameSlug,
      fileStem: fileStem,
      frontmatter: {
        ..._base(title),
        'entity-type': 'clock',
        'segments': clamped,
        'filled': 0,
      },
      body: '# $title\n',
    );
  }

  /// Legt einen Track an, optional mit ersten Beats.
  Future<String> createTrack(
    String rootPath,
    String gameSlug, {
    required String title,
    required String fileStem,
    List<String> beats = const [],
  }) async {
    var body = '# $title\n';
    for (final beat in beats) {
      body = appendBeat(body, beat);
    }
    return _create(
      rootPath,
      gameSlug,
      fileStem: fileStem,
      frontmatter: {..._base(title), 'entity-type': 'track'},
      body: body,
    );
  }

  /// Setzt den Füllstand einer Clock.
  Future<void> setClock(
    String rootPath,
    String relPath,
    ClockState clock,
  ) async {
    await _rewrite(rootPath, relPath, (doc) {
      final fm = Map<String, dynamic>.from(doc.frontmatter)
        ..['segments'] = clock.segments
        ..['filled'] = clock.filled;
      return (fm, doc.body);
    });
  }

  /// Hakt den Beat in Zeile [line] ab oder hebt das Häkchen auf.
  ///
  /// Wirft [StaleTrackException], wenn in der Zeile kein Beat mehr steht —
  /// dann wurde die Datei außerhalb geändert, und eine andere Zeile zu
  /// kippen wäre schlimmer als nichts zu tun.
  Future<void> setBeat(
    String rootPath,
    String relPath,
    int line, {
    required bool done,
  }) async {
    await _rewrite(rootPath, relPath, (doc) {
      final body = toggleBeat(doc.body, line, done: done);
      if (body == null) throw StaleTrackException(relPath);
      return (doc.frontmatter, body);
    });
  }

  /// Hängt einen Beat an.
  Future<void> addBeat(String rootPath, String relPath, String text) async {
    await _rewrite(
      rootPath,
      relPath,
      (doc) => (doc.frontmatter, appendBeat(doc.body, text)),
    );
  }

  // ── Intern ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _base(String title) {
    final now = DateTime.now().toUtc();
    return NoteFrontmatter(
      id: _uuid.v4(),
      type: NoteType.entity,
      title: title,
      created: now,
      updated: now,
    ).toMap();
  }

  Future<String> _create(
    String rootPath,
    String gameSlug, {
    required String fileStem,
    required Map<String, dynamic> frontmatter,
    required String body,
  }) async {
    final relPath = 'games/$gameSlug/entities/$fileStem.md';
    final file = File(p.join(rootPath, relPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(serializeDocument(frontmatter, body));
    return relPath;
  }

  /// Liest, ändert, schreibt — und zieht `updated` mit.
  Future<void> _rewrite(
    String rootPath,
    String relPath,
    (Map<String, dynamic>, String) Function(ParsedDocument doc) change,
  ) async {
    final file = File(p.join(rootPath, relPath));
    final doc = parseDocument(await file.readAsString());
    final (frontmatter, body) = change(doc);
    final updated = Map<String, dynamic>.from(frontmatter)
      ..['updated'] = DateTime.now().toUtc().toIso8601String();
    await file.writeAsString(serializeDocument(updated, body));
  }
}
