// Datei: chronicle/lib/features/tracks/track_providers.dart
//
// ZWECK: Clocks und Tracks der aktiven Partie, der fokussierte Track der
//        oberen Leiste, und die Aktionen darauf.
//
// ZUSTAND KOMMT AUS DER DATEI: Der Index findet nur die Kandidaten
//        (`type: entity` der Partie). Füllstand und Häkchen stehen in der
//        Datei und werden dort gelesen (CLAUDE.md §2.5). Ein Abhaken löst
//        deshalb auch keinen Index-Rebuild aus — es ändert nichts, was der
//        Index kennt.
//
// INS LOG GEHT NUR, WAS ERZÄHLT: Ein abgehakter Beat und eine volle Clock
//        werden Plot-Beat-Einträge (Konzept §4.1). Jeder einzelne Tick einer
//        Clock nicht — das wäre Rauschen im Journal.
//
// SCHRITT: 8

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/vault/track_repository.dart';
import '../../data/vault/vault_providers.dart';
import '../../domain/log/entry_kind.dart';
import '../../domain/slug.dart';
import '../../domain/tracks/track.dart';

part 'track_providers.g.dart';

@Riverpod(keepAlive: true)
TrackRepository trackRepository(Ref ref) => const TrackRepository();

/// Alle Clocks und Tracks der aktiven Partie, alphabetisch.
@riverpod
Future<List<GameTrack>> gameTracks(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  final game = await ref.watch(activeGameProvider.future);
  if (session == null || game == null) return const [];

  final notes = await session.database.notesOfType('entity');
  final mine = notes.where((n) => n.ownerSlug == game.slug);

  final tracks = await ref
      .read(trackRepositoryProvider)
      .loadAll(session.vault.rootPath, mine.map((n) => n.relPath));
  tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return tracks;
}

/// Der Track in der oberen Leiste.
///
/// Reihenfolge (Konzept §4.5, „Default: Kampagne"): der ausdrücklich
/// fokussierte → ein Track namens „Kampagne" → der erste Step-Track → die
/// erste Clock. Laufende Procedures übernehmen die Leiste erst ab Schritt 9.
@riverpod
Future<GameTrack?> focusedTrack(Ref ref) async {
  final game = await ref.watch(activeGameProvider.future);
  final tracks = await ref.watch(gameTracksProvider.future);
  if (game == null || tracks.isEmpty) return null;

  final focused = game.focusedTrackId;
  if (focused != null) {
    for (final track in tracks) {
      if (track.id == focused) return track;
    }
    // Die fokussierte Datei wurde gelöscht — kein Fehler, einfach weiter
    // mit dem Default.
  }

  for (final track in tracks) {
    if (track.title.toLowerCase() == 'kampagne') return track;
  }
  for (final track in tracks) {
    if (track.kind == TrackKind.track) return track;
  }
  return tracks.first;
}

@Riverpod(keepAlive: true)
TrackActions trackActions(Ref ref) => TrackActions(ref);

class TrackActions {
  const TrackActions(this._ref);

  final Ref _ref;

  Future<void> createClock(String title, int segments) async {
    final (root, slug, stem) = await _target(title);
    await _ref
        .read(trackRepositoryProvider)
        .createClock(
          root,
          slug,
          title: title,
          fileStem: stem,
          segments: segments,
        );
    await _afterCreate();
  }

  Future<void> createTrack(
    String title, {
    List<String> beats = const [],
  }) async {
    final (root, slug, stem) = await _target(title);
    await _ref
        .read(trackRepositoryProvider)
        .createTrack(root, slug, title: title, fileStem: stem, beats: beats);
    await _afterCreate();
  }

  /// Füllt oder leert eine Clock um [by] Segmente.
  Future<void> advanceClock(GameTrack track, int by) async {
    final clock = track.clock;
    if (clock == null) return;

    final next = clock.advance(by);
    if (next.filled == clock.filled) return;

    await _ref
        .read(trackRepositoryProvider)
        .setClock(_root(), track.relPath, next);
    _ref.invalidate(gameTracksProvider);

    // Nur der Moment, in dem die Clock VOLL wird, gehört ins Journal: das
    // ist das Ereignis, auf das sie hingetickt hat.
    if (next.isComplete && !clock.isComplete) {
      await _log('**${track.title}** — die Clock ist voll.');
    }
  }

  /// Hakt [beat] ab oder hebt das Häkchen auf.
  Future<void> setBeat(
    GameTrack track,
    TrackBeat beat, {
    required bool done,
  }) async {
    if (beat.done == done) return;

    await _ref
        .read(trackRepositoryProvider)
        .setBeat(_root(), track.relPath, beat.line, done: done);
    _ref.invalidate(gameTracksProvider);

    // Abhaken erzählt etwas, Zurücknehmen korrigiert nur — das Journal
    // bekommt deshalb nur den Schritt nach vorn.
    if (done) await _log('**${track.title}** — ${beat.text}');
  }

  /// Hakt den nächsten offenen Haupt-Beat ab.
  Future<void> advanceTrack(GameTrack track) async {
    final next = track.progress.next;
    if (next == null) return;
    await setBeat(track, next, done: true);
  }

  Future<void> addBeat(GameTrack track, String text) async {
    if (text.trim().isEmpty) return;
    await _ref
        .read(trackRepositoryProvider)
        .addBeat(_root(), track.relPath, text);
    _ref.invalidate(gameTracksProvider);
  }

  /// Macht [track] zum Track der oberen Leiste.
  Future<void> focus(GameTrack track) async {
    final session = _ref.read(activeVaultProvider).value;
    final game = await _ref.read(activeGameProvider.future);
    if (session == null || game == null) return;

    await _ref.read(vaultCatalogProvider).updateGameManifest(
      session.vault.rootPath,
      game.slug,
      {'focusedTrackId': track.id},
    );
    _ref.invalidate(vaultGamesProvider);
  }

  // ── Intern ────────────────────────────────────────────────────────────────

  String _root() {
    final session = _ref.read(activeVaultProvider).value;
    if (session == null) throw StateError('Kein Vault geöffnet');
    return session.vault.rootPath;
  }

  Future<(String, String, String)> _target(String title) async {
    final game = await _ref.read(activeGameProvider.future);
    if (game == null) {
      // Die UI bietet das Anlegen nur mit laufender Partie an.
      throw StateError('Keine Partie aktiv');
    }
    final existing = await _ref.read(gameTracksProvider.future);
    final stem = uniqueSlug(title, {
      for (final t in existing) t.relPath.split('/').last.replaceAll('.md', ''),
    });
    return (_root(), game.slug, stem);
  }

  Future<void> _afterCreate() async {
    // Eine neue Datei muss in den Index, sonst findet gameTracks sie nicht.
    await _ref.read(activeVaultProvider.notifier).reindex();
    _ref.invalidate(gameTracksProvider);
  }

  Future<void> _log(String text) => _ref
      .read(logActionsProvider)
      .appendEntry(kind: EntryKind.plotbeat, text: text);
}
