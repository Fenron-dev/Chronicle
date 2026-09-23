// Datei: chronicle/test/backup_test.dart
//
// ZWECK: Sichern und Zurückspielen. Ohne funktionierendes Restore wird keine
//        Migration gemergt (CLAUDE.md §5.3) — diese Datei ist die Stelle, an
//        der „funktionierend" nachgewiesen wird.
//
// SCHRITT: 3b

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:chronicle/data/vault/vault_layout.dart';
import 'package:chronicle/services/backup/backup_entry.dart';
import 'package:chronicle/services/backup/backup_service.dart';
import 'package:chronicle/services/backup/note_snapshots.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Legt ein Vault-Gerüst ohne VaultManager an.
///
/// Bewusst von Hand: der Test soll die Sicherung prüfen, nicht das
/// Zusammenspiel mit dem Manager. Fällt der Manager aus, sollen diese Tests
/// trotzdem eine klare Aussage treffen.
Future<Directory> _makeVault(String name) async {
  final dir = await Directory.systemTemp.createTemp('chronicle-backup-');
  for (final sub in VaultLayout.topLevelDirs) {
    await Directory(p.join(dir.path, sub)).create(recursive: true);
  }
  for (final sub in VaultLayout.metaSubDirs) {
    await Directory(p.join(VaultLayout.meta(dir.path), sub))
        .create(recursive: true);
  }
  await File(VaultLayout.config(dir.path)).writeAsString(
    jsonEncode({
      'schemaVersion': 1,
      'id': 'vault-$name',
      'name': name,
      'created': '2026-09-19T12:00:00.000Z',
    }),
  );
  return dir;
}

Future<void> _write(Directory vault, String relPath, String content) async {
  final file = File(p.join(vault.path, relPath));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

Future<String?> _read(Directory vault, String relPath) async {
  final file = File(p.join(vault.path, relPath));
  return await file.exists() ? file.readAsString() : null;
}

List<String> _namesIn(String archivePath) {
  final input = InputFileStream(archivePath);
  try {
    return ZipDecoder().decodeStream(input).map((f) => f.name).toList()..sort();
  } finally {
    input.closeSync();
  }
}

void main() {
  const service = BackupService(appVersion: '0.1.0-test');

  group('Backup-Umfang', () {
    late Directory vault;

    setUp(() async {
      vault = await _makeVault('Moor');
      await _write(vault, 'README.md', '# Moor');
      await _write(vault, 'systems/ironsworn/rules.md', 'Regeln');
      await _write(vault, 'games/moor/log/haupt.md', 'Eintrag');
      await _write(vault, 'media/karte.png', 'BILD');
      // Regenerierbares — gehört nicht ins Archiv.
      await _write(vault, '.chronicle/index.db', 'SQLITE');
      await _write(vault, '.chronicle/thumbnails/karte.jpg', 'THUMB');
      await _write(vault, '.git/config', '[core]');
    });

    tearDown(() => vault.delete(recursive: true));

    test('nimmt den Dateibaum mit, den Index nicht', () async {
      final entry = await service.create(vault.path);
      final names = _namesIn(entry.path);

      expect(names, contains('README.md'));
      expect(names, contains('systems/ironsworn/rules.md'));
      expect(names, contains('games/moor/log/haupt.md'));
      expect(names, contains('media/karte.png'));
      // config.json ist keine Ableitung aus den Dateien — sie muss mit.
      expect(names, contains('.chronicle/config.json'));

      expect(names, isNot(contains('.chronicle/index.db')));
      expect(names, isNot(contains('.chronicle/thumbnails/karte.jpg')));
      expect(names, isNot(contains('.git/config')));
    });

    test('legt das Archiv unter .chronicle/backups/ ab', () async {
      final entry = await service.create(vault.path);
      expect(p.dirname(entry.path), VaultLayout.backups(vault.path));
      expect(entry.fileName, startsWith('chronicle-manual-'));
      expect(entry.fileName, endsWith('.zip'));
    });

    test('Migrations-Snapshots landen unter .chronicle/snapshots/', () async {
      final entry = await service.create(
        vault.path,
        kind: BackupKind.beforeMigration,
        label: 'Schema 1 → 2',
      );
      expect(p.dirname(entry.path), VaultLayout.snapshots(vault.path));
      expect(entry.manifest?.label, 'Schema 1 → 2');
    });

    test('schreibt ein Manifest mit Herkunft und Umfang', () async {
      final entry = await service.create(vault.path, label: 'vor dem Import');
      final manifest = entry.manifest!;

      expect(manifest.vaultId, 'vault-Moor');
      expect(manifest.vaultName, 'Moor');
      expect(manifest.kind, BackupKind.manual);
      expect(manifest.label, 'vor dem Import');
      expect(manifest.appVersion, '0.1.0-test');
      // README + rules.md + haupt.md + karte.png + config.json
      expect(manifest.fileCount, 5);
      expect(manifest.byteSize, greaterThan(0));
    });

    test(
      'zwei Sicherungen in derselben Sekunde überschreiben sich nicht',
      () async {
        final first = await service.create(vault.path);
        final second = await service.create(vault.path);
        expect(first.path, isNot(second.path));
        expect(await File(first.path).exists(), isTrue);
        expect(await File(second.path).exists(), isTrue);
      },
    );

    test('list liest die Manifeste, neueste zuerst', () async {
      await service.create(vault.path, label: 'älter');
      await service.create(vault.path, label: 'neuer');

      final all = await service.list(vault.path);
      expect(all, hasLength(2));
      expect(all.first.manifest?.label, 'neuer');
      expect(all.last.manifest?.label, 'älter');
    });

    test('export kopiert nach außen, ohne zu überschreiben', () async {
      final entry = await service.create(vault.path);
      final outside = await Directory.systemTemp.createTemp('chronicle-out-');
      addTearDown(() => outside.delete(recursive: true));

      final first = await service.export(entry.path, outside.path);
      final second = await service.export(entry.path, outside.path);

      expect(first, isNot(second));
      expect(await File(first).exists(), isTrue);
      expect(await File(second).exists(), isTrue);
    });

    test('prune behält die jüngsten Sicherungen', () async {
      for (var i = 0; i < 4; i++) {
        await service.create(vault.path, kind: BackupKind.beforeMigration);
      }
      final deleted = await service.prune(
        vault.path,
        BackupKind.beforeMigration,
        keep: 2,
      );
      expect(deleted, 2);
      expect(await service.list(vault.path), hasLength(2));
    });
  });

  group('Wiederherstellung', () {
    late Directory vault;

    setUp(() async {
      vault = await _makeVault('Moor');
      await _write(vault, 'games/moor/log/haupt.md', 'Stand A');
      await _write(vault, 'games/moor/codex/npc.md', 'Wird gelöscht');
      await _write(vault, 'systems/ironsworn/rules.md', 'Regeln A');
    });

    tearDown(() => vault.delete(recursive: true));

    test('stellt genau den gesicherten Stand her', () async {
      final backup = await service.create(vault.path);

      // Nach dem Backup: ändern, löschen, hinzufügen.
      await _write(vault, 'games/moor/log/haupt.md', 'Stand B');
      await File(p.join(vault.path, 'games/moor/codex/npc.md')).delete();
      await _write(vault, 'games/moor/codex/neu.md', 'Nach dem Backup');

      final report = await service.restore(vault.path, backup.path);

      expect(await _read(vault, 'games/moor/log/haupt.md'), 'Stand A');
      expect(await _read(vault, 'games/moor/codex/npc.md'), 'Wird gelöscht');
      // Das Zurückspielen ersetzt, es mischt nicht: was nach dem Backup
      // entstand, ist danach weg.
      expect(await _read(vault, 'games/moor/codex/neu.md'), isNull);
      expect(report.filesWritten, 4);
    });

    test('räumt leere Ordner ab, die es im Backup nicht gab', () async {
      final backup = await service.create(vault.path);
      await _write(vault, 'games/spaeter/log/haupt.md', 'Andere Partie');

      await service.restore(vault.path, backup.path);

      expect(
        await Directory(p.join(vault.path, 'games/spaeter')).exists(),
        isFalse,
      );
      // Das Gerüst der obersten Ebene bleibt stehen.
      expect(await Directory(p.join(vault.path, 'games')).exists(), isTrue);
      expect(await Directory(p.join(vault.path, 'media')).exists(), isTrue);
    });

    test('legt vorher ein Sicherheitsnetz an', () async {
      final backup = await service.create(vault.path);
      await _write(vault, 'games/moor/log/haupt.md', 'Stand B');

      final report = await service.restore(vault.path, backup.path);
      final safety = report.safetyBackup;

      expect(safety, isNotNull);
      expect(safety!.kind, BackupKind.beforeRestore);
      expect(_namesIn(safety.path), contains('games/moor/log/haupt.md'));
    });

    test('löscht den Index, damit er neu aufgebaut wird', () async {
      final backup = await service.create(vault.path);
      await _write(vault, '.chronicle/index.db', 'SQLITE');
      await _write(vault, '.chronicle/index.db-wal', 'WAL');

      await service.restore(vault.path, backup.path);

      expect(await File(VaultLayout.database(vault.path)).exists(), isFalse);
      expect(
        await File('${VaultLayout.database(vault.path)}-wal').exists(),
        isFalse,
      );
    });

    test('lässt Sicherungen und Snapshots unberührt', () async {
      final backup = await service.create(vault.path);
      await service.create(vault.path, kind: BackupKind.beforeMigration);

      await service.restore(vault.path, backup.path);

      // Das Archiv, aus dem gerade gelesen wurde, muss den Vorgang überleben.
      expect(await File(backup.path).exists(), isTrue);
      expect(
        await Directory(VaultLayout.snapshots(vault.path)).exists(),
        isTrue,
      );
    });

    test('weist ein Archiv ohne Manifest ab', () async {
      final fremd = p.join(vault.path, 'fremd.zip');
      final encoder = ZipFileEncoder();
      encoder.create(fremd);
      encoder.addArchiveFile(ArchiveFile.string('irgendwas.md', 'Hallo'));
      await encoder.close();

      // expectLater mit await: sonst liefen die folgenden Zeilen, bevor die
      // Prüfung fertig ist. (In testWidgets verweigert flutter_test die
      // synchrone Form sogar ganz.)
      await expectLater(
        service.restore(vault.path, fremd),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.notABackup,
          ),
        ),
      );
    });

    test('weist ein Archiv aus einer neueren Version ab', () async {
      final backup = await service.create(vault.path);
      // Manifest von Hand auf eine Zukunfts-Version heben.
      final input = InputFileStream(backup.path);
      final archive = ZipDecoder().decodeStream(input);
      final rewritten = p.join(vault.path, 'zukunft.zip');
      final encoder = ZipFileEncoder();
      encoder.create(rewritten);
      for (final file in archive) {
        if (!file.isFile) continue;
        if (file.name == BackupManifest.fileName) {
          final raw = jsonDecode(
            utf8.decode(file.readBytes()!),
          ) as Map<String, dynamic>;
          raw['schemaVersion'] = BackupManifest.currentSchemaVersion + 1;
          encoder.addArchiveFile(
            ArchiveFile.string(file.name, jsonEncode(raw)),
          );
        } else {
          encoder.addArchiveFile(ArchiveFile.bytes(file.name, file.content));
        }
      }
      await encoder.close();
      await input.close();

      await expectLater(
        service.restore(vault.path, rewritten),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.futureSchema,
          ),
        ),
      );
    });

    test('ein Eintrag mit ../ landet nicht außerhalb des Vaults', () async {
      // „Zip Slip": Backups kommen auch von fremden Sticks.
      final boese = p.join(vault.path, 'boese.zip');
      final manifest = BackupManifest(
        created: DateTime.now().toUtc(),
        kind: BackupKind.manual,
        vaultId: 'vault-Moor',
        vaultName: 'Moor',
        vaultSchemaVersion: 1,
        fileCount: 1,
        byteSize: 3,
      );
      final encoder = ZipFileEncoder();
      encoder.create(boese);
      encoder.addArchiveFile(
        ArchiveFile.string(BackupManifest.fileName, manifest.encode()),
      );
      encoder.addArchiveFile(
        ArchiveFile.string('../entkommen.md', 'Sollte nie geschrieben werden'),
      );
      await encoder.close();

      await expectLater(
        service.restore(vault.path, boese, safetyBackup: false),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.unsafeEntry,
          ),
        ),
      );

      final escaped = File(p.join(p.dirname(vault.path), 'entkommen.md'));
      expect(await escaped.exists(), isFalse);
      // Abgebrochen wird VOR dem Räumen — der Vault steht unverändert da.
      expect(await _read(vault, 'games/moor/log/haupt.md'), 'Stand A');
    });
  });

  group('isBackedUp', () {
    test('entscheidet für Räumen und Packen dieselbe Frage', () {
      expect(BackupService.isBackedUp('README.md'), isTrue);
      expect(BackupService.isBackedUp('games/moor/log/haupt.md'), isTrue);
      expect(BackupService.isBackedUp('.chronicle/config.json'), isTrue);

      expect(BackupService.isBackedUp('.chronicle/index.db'), isFalse);
      expect(BackupService.isBackedUp('.chronicle/index.db-wal'), isFalse);
      expect(BackupService.isBackedUp('.chronicle/thumbnails/a.jpg'), isFalse);
      expect(BackupService.isBackedUp('.chronicle/backups/a.zip'), isFalse);
      expect(BackupService.isBackedUp('.chronicle/snapshots/a.zip'), isFalse);
      expect(BackupService.isBackedUp('.git/config'), isFalse);
      expect(BackupService.isBackedUp('.chronicle-write-test'), isFalse);
    });
  });

  group('Versions-History je Notiz', () {
    late Directory vault;
    const snapshots = NoteSnapshots(keepPerNote: 3);

    setUp(() async {
      vault = await _makeVault('Moor');
      await _write(vault, 'games/moor/log/haupt.md', 'Fassung 1');
    });

    tearDown(() => vault.delete(recursive: true));

    test('sichert vor dem Überschreiben und holt zurück', () async {
      const rel = 'games/moor/log/haupt.md';
      final version = await snapshots.record(vault.path, rel);
      expect(version, isNotNull);

      await _write(vault, rel, 'Fassung 2');
      await snapshots.restore(vault.path, rel, version!.stamp);

      expect(await _read(vault, rel), 'Fassung 1');
    });

    test('das Zurücknehmen ist selbst umkehrbar', () async {
      const rel = 'games/moor/log/haupt.md';
      final first = await snapshots.record(vault.path, rel);
      await _write(vault, rel, 'Fassung 2');

      await snapshots.restore(vault.path, rel, first!.stamp);

      // „Fassung 2" wurde beim Zurücknehmen selbst zur Fassung — wer sich
      // vertippt hat, verliert seinen Text nicht.
      final all = await snapshots.versions(vault.path, rel);
      final texte = <String>[
        for (final v in all) await File(v.path).readAsString(),
      ];
      expect(texte, contains('Fassung 2'));
    });

    test('unveränderter Inhalt erzeugt keine zweite Fassung', () async {
      const rel = 'games/moor/log/haupt.md';
      expect(await snapshots.record(vault.path, rel), isNotNull);
      expect(await snapshots.record(vault.path, rel), isNull);
      expect(await snapshots.versions(vault.path, rel), hasLength(1));
    });

    test('eine neue Notiz hat nichts zu sichern', () async {
      expect(
        await snapshots.record(vault.path, 'games/moor/log/gibtsnicht.md'),
        isNull,
      );
    });

    test('behält höchstens keepPerNote Fassungen', () async {
      const rel = 'games/moor/log/haupt.md';
      for (var i = 0; i < 6; i++) {
        await _write(vault, rel, 'Fassung $i');
        await snapshots.record(vault.path, rel);
      }
      expect(await snapshots.versions(vault.path, rel), hasLength(3));
    });

    test('spiegelt den Notizpfad als Ordner', () async {
      const rel = 'games/moor/log/haupt.md';
      await snapshots.record(vault.path, rel);
      final dir = Directory(
        p.join(VaultLayout.snapshots(vault.path), 'notes', rel),
      );
      expect(await dir.exists(), isTrue);
    });

    test('forget entfernt die Historie', () async {
      const rel = 'games/moor/log/haupt.md';
      await snapshots.record(vault.path, rel);
      await snapshots.forget(vault.path, rel);
      expect(await snapshots.versions(vault.path, rel), isEmpty);
    });
  });
}
