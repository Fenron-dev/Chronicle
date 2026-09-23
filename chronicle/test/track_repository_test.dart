// Datei: chronicle/test/track_repository_test.dart
//
// ZWECK: Clocks und Tracks in Dateien — und das Versprechen, beim Schreiben
//        nur das Nötige anzufassen.
//
// SCHRITT: 8

import 'dart:convert';
import 'dart:io';

import 'package:chronicle/data/vault/track_repository.dart';
import 'package:chronicle/data/vault/vault_catalog.dart';
import 'package:chronicle/domain/frontmatter/frontmatter.dart';
import 'package:chronicle/domain/tracks/track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const repo = TrackRepository();
  late Directory vault;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('chronicle-tracks-');
  });

  tearDown(() => vault.delete(recursive: true));

  Future<String> read(String relPath) =>
      File(p.join(vault.path, relPath)).readAsString();

  group('Clocks', () {
    test('legt eine Clock an und liest sie wieder', () async {
      final relPath = await repo.createClock(
        vault.path,
        'moor',
        title: 'Der Kult erwacht',
        fileStem: 'kult',
        segments: 6,
      );
      expect(relPath, 'games/moor/entities/kult.md');

      final loaded = (await repo.load(vault.path, relPath))!;
      expect(loaded.kind, TrackKind.clock);
      expect(loaded.title, 'Der Kult erwacht');
      expect((loaded.clock!.segments, loaded.clock!.filled), (6, 0));
    });

    test('klemmt eine absurde Segmentzahl schon beim Anlegen', () async {
      final relPath = await repo.createClock(
        vault.path,
        'moor',
        title: 'Riesig',
        fileStem: 'riesig',
        segments: 500,
      );
      final loaded = (await repo.load(vault.path, relPath))!;
      expect(loaded.clock!.segments, kMaxClockSegments);
    });

    test('setClock ändert nur segments, filled und updated', () async {
      final relPath = await repo.createClock(
        vault.path,
        'moor',
        title: 'Uhr',
        fileStem: 'uhr',
        segments: 4,
      );
      // Von Hand ergänzt — muss das Schreiben überleben.
      final file = File(p.join(vault.path, relPath));
      final doc = parseDocument(await file.readAsString());
      await file.writeAsString(
        serializeDocument({
          ...doc.frontmatter,
          'accent-color': 'blood',
        }, '${doc.body}\nNotizen zur Uhr.\n'),
      );

      await repo.setClock(
        vault.path,
        relPath,
        const ClockState(segments: 4, filled: 3),
      );

      final after = parseDocument(await read(relPath));
      expect(after.frontmatter['filled'], 3);
      expect(after.frontmatter['accent-color'], 'blood');
      expect(after.body, contains('Notizen zur Uhr.'));
    });
  });

  group('Tracks', () {
    test('legt einen Track mit ersten Beats an', () async {
      final relPath = await repo.createTrack(
        vault.path,
        'moor',
        title: 'Kampagne',
        fileStem: 'kampagne',
        beats: ['Ankunft', 'Der Turm'],
      );
      final loaded = (await repo.load(vault.path, relPath))!;
      expect(loaded.kind, TrackKind.track);
      expect(loaded.beats.map((b) => b.text), ['Ankunft', 'Der Turm']);
      expect(loaded.progress.next?.text, 'Ankunft');
    });

    test('setBeat hakt ab und lässt den übrigen Rumpf stehen', () async {
      final relPath = await repo.createTrack(
        vault.path,
        'moor',
        title: 'Kampagne',
        fileStem: 'kampagne',
        beats: ['Ankunft', 'Der Turm'],
      );
      final file = File(p.join(vault.path, relPath));
      await file.writeAsString(
        '${await file.readAsString()}\nEin Absatz des Nutzers.\n',
      );

      final ankunft = (await repo.load(vault.path, relPath))!.beats.first;
      await repo.setBeat(vault.path, relPath, ankunft.line, done: true);

      final loaded = (await repo.load(vault.path, relPath))!;
      expect(loaded.beats.first.done, isTrue);
      expect(loaded.beats.last.done, isFalse);
      expect(await read(relPath), contains('Ein Absatz des Nutzers.'));
    });

    test('setBeat auf einer verschobenen Zeile wirft statt zu raten', () async {
      final relPath = await repo.createTrack(
        vault.path,
        'moor',
        title: 'Kampagne',
        fileStem: 'kampagne',
        beats: ['Ankunft'],
      );
      // Zeile 0 ist nach dem Frontmatter die Überschrift, kein Beat.
      // expectLater mit await: sonst liefen die folgenden Zeilen, bevor die
      // Prüfung fertig ist. (In testWidgets verweigert flutter_test die
      // synchrone Form sogar ganz.)
      await expectLater(
        repo.setBeat(vault.path, relPath, 0, done: true),
        throwsA(isA<StaleTrackException>()),
      );
    });

    test('addBeat hängt an die Liste an', () async {
      final relPath = await repo.createTrack(
        vault.path,
        'moor',
        title: 'Kampagne',
        fileStem: 'kampagne',
        beats: ['Ankunft'],
      );
      await repo.addBeat(vault.path, relPath, 'Die Rückkehr');
      final loaded = (await repo.load(vault.path, relPath))!;
      expect(loaded.beats.map((b) => b.text), ['Ankunft', 'Die Rückkehr']);
    });
  });

  test('eine gewöhnliche Entity ist weder Clock noch Track', () async {
    const relPath = 'games/moor/entities/npc.md';
    final file = File(p.join(vault.path, relPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      serializeDocument({
        'id': 'x',
        'type': 'entity',
        'entity-type': 'npc',
        'title': 'Die Wirtin',
      }, 'Freundlich.\n'),
    );
    expect(await repo.load(vault.path, relPath), isNull);
  });

  group('game.json', () {
    const catalog = VaultCatalog();

    test('updateGameManifest ändert nur, was es soll', () async {
      final dir = Directory(p.join(vault.path, 'games', 'moor'));
      await dir.create(recursive: true);
      final manifest = File(p.join(dir.path, 'game.json'));
      await manifest.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'id': 'g1',
          'name': 'Moor',
          'created': '2026-09-20T12:00:00Z',
          'systemId': 's1',
          // Ein Schlüssel, den unser Modell nicht kennt.
          'futureFeature': {'keep': true},
        }),
      );

      await catalog.updateGameManifest(vault.path, 'moor', {
        'focusedTrackId': 't1',
      });
      var raw =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      expect(raw['focusedTrackId'], 't1');
      expect(raw['futureFeature'], {'keep': true});

      // null entfernt den Schlüssel.
      await catalog.updateGameManifest(vault.path, 'moor', {
        'focusedTrackId': null,
      });
      raw = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      expect(raw.containsKey('focusedTrackId'), isFalse);
      expect(raw['futureFeature'], {'keep': true});
    });

    test('GameEntry liest den Fokus', () {
      final entry = GameEntry.fromJson({
        'id': 'g1',
        'name': 'Moor',
        'systemId': 's1',
        'focusedTrackId': 't1',
      }, 'moor');
      expect(entry.focusedTrackId, 't1');
      expect(entry.toJson()['focusedTrackId'], 't1');
    });
  });
}
