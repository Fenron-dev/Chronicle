// Datei: chronicle/test/vault_test.dart
//
// ZWECK: Sichert die oberste Vault-Regel ab — Dateien sind die Wahrheit, die
//        DB ist ein regenerierbarer Index.
//
// DER WICHTIGSTE TEST hier ist „überlebt das Löschen des Index": er belegt
//        die Zusage „Vault auf fremdem Rechner öffnen → Index rebuild →
//        alles da". Ohne ihn merkt niemand, wenn ein Feld nur in der DB
//        landet.
//
// SIEHE: Skill `vault-format`
// SCHRITT: 3

import 'dart:io';

import 'package:chronicle/data/db/database.dart';
import 'package:chronicle/data/vault/index_rebuilder.dart';
import 'package:chronicle/data/vault/vault.dart';
import 'package:chronicle/data/vault/vault_layout.dart';
import 'package:chronicle/data/vault/vault_manager.dart';
import 'package:chronicle/data/vault/vault_providers.dart';
import 'package:chronicle/data/vault/vault_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // shared_preferences (Zuletzt-geöffnet-Liste) braucht die Test-Bindung,
  // auch außerhalb von Widget-Tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String root;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('chronicle_test');
    root = tempDir.path;
  });

  tearDown(() async {
    // Ein noch offenes Datenbank-Handle darf das Aufräumen nicht zum
    // Testfehler machen — es ist ein Temp-Ordner.
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Das Betriebssystem räumt ihn ohnehin ab.
    }
  });

  /// Legt eine Notiz mit vollständigem Frontmatter an.
  Future<void> writeNote(
    String relPath, {
    required String id,
    required String type,
    required String title,
    String body = '',
    List<String> tags = const [],
  }) async {
    final file = File('$root/$relPath');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '---\n'
      'id: $id\n'
      'type: $type\n'
      'title: $title\n'
      'created: 2026-09-19T10:00:00Z\n'
      'updated: 2026-09-19T10:00:00Z\n'
      '${tags.isEmpty ? '' : 'tags: [${tags.join(', ')}]\n'}'
      '---\n'
      '$body\n',
    );
  }

  group('VaultManager', () {
    test('legt das komplette Layout an', () async {
      final vault = await const VaultManager().create(root, name: 'Testvault');

      expect(vault.name, 'Testvault');
      expect(await Directory(VaultLayout.meta(root)).exists(), isTrue);
      expect(await Directory(VaultLayout.systems(root)).exists(), isTrue);
      expect(await Directory(VaultLayout.games(root)).exists(), isTrue);
      expect(await Directory(VaultLayout.media(root)).exists(), isTrue);
      expect(await File(VaultLayout.config(root)).exists(), isTrue);
      // Die README erklärt einem Menschen, was der Ordner ist — er kann auf
      // einem Rechner ohne Chronicle landen.
      expect(await File(VaultLayout.readme(root)).exists(), isTrue);
    });

    test('lehnt einen Ordner ohne .chronicle ab', () async {
      final plain = Directory('$root/kein_vault')..createSync();

      expect(
        () => const VaultManager().open(plain.path),
        throwsA(
          isA<VaultException>().having(
            (e) => e.failure,
            'failure',
            VaultOpenFailure.notAVault,
          ),
        ),
      );
    });

    test('öffnet einen Vault, dessen config.json fehlt', () async {
      // Kein Datenverlust: die Dateien sind die Wahrheit.
      await const VaultManager().create(root, name: 'Testvault');
      await File(VaultLayout.config(root)).delete();

      final vault = await const VaultManager().open(root);
      expect(await File(VaultLayout.config(root)).exists(), isTrue);
      expect(vault.config.id, isNotEmpty);
    });

    test('zieht fehlende Ordner beim Öffnen nach', () async {
      // Viele Packprogramme nehmen leere Ordner nicht mit.
      await const VaultManager().create(root, name: 'Testvault');
      await Directory(VaultLayout.media(root)).delete(recursive: true);

      await const VaultManager().open(root);
      expect(await Directory(VaultLayout.media(root)).exists(), isTrue);
    });
  });

  group('Scanner', () {
    test('überspringt .chronicle und die README', () async {
      await const VaultManager().create(root, name: 'T');
      await File('${VaultLayout.meta(root)}/notiz.md')
          .writeAsString('# versteckt');
      await writeNote(
        'games/partie/codex/ort.md',
        id: 'note-1',
        type: 'codex',
        title: 'Mörwald',
      );

      final scan = await const VaultScanner().scan(root);

      expect(scan.notes.length, 1);
      expect(scan.notes.single.frontmatter.id, 'note-1');
    });

    test('ergänzt fehlendes Frontmatter und schreibt es zurück', () async {
      await const VaultManager().create(root, name: 'T');
      final file = File('$root/games/partie/codex/roh.md');
      await file.parent.create(recursive: true);
      await file.writeAsString('# Eine rohe Notiz\n\nText.\n');

      final first = await const VaultScanner().scan(root);
      final assignedId = first.notes.single.frontmatter.id;

      expect(assignedId, isNotEmpty);
      // Titel kommt aus der ersten Überschrift, Typ aus dem Ablageort.
      expect(first.notes.single.frontmatter.title, 'Eine rohe Notiz');
      expect(first.notes.single.frontmatter.type.name, 'codex');

      // Entscheidend: beim zweiten Scan dieselbe id. Sonst bekäme die Datei
      // bei jedem Rebuild eine neue Identität.
      final second = await const VaultScanner().scan(root);
      expect(second.notes.single.frontmatter.id, assignedId);
    });

    test('erkennt Scope und Besitzer aus dem Pfad', () async {
      await const VaultManager().create(root, name: 'T');
      await writeNote(
        'systems/ironsworn/tables/orte.md',
        id: 's1',
        type: 'table',
        title: 'Orte',
      );
      await writeNote(
        'games/nebelmoor/log/sitzung-1.md',
        id: 'g1',
        type: 'log',
        title: 'Sitzung 1',
      );

      final scan = await const VaultScanner().scan(root);
      final byId = {for (final n in scan.notes) n.frontmatter.id: n};

      expect(byId['s1']!.scope, NoteScope.system);
      expect(byId['s1']!.ownerSlug, 'ironsworn');
      expect(byId['g1']!.scope, NoteScope.game);
      expect(byId['g1']!.ownerSlug, 'nebelmoor');
    });
  });

  group('Index', () {
    test('SQLite ist mit FTS5 gebaut', () async {
      // Ohne FTS5 wäre die Suche kaputt — das soll nicht erst beim Nutzer
      // auffallen.
      final db = ChronicleDatabase.memory();
      addTearDown(db.close);
      expect(await db.hasFts5(), isTrue);
    });

    test('indiziert Notizen und löst Wikilinks zu Kanten auf', () async {
      await const VaultManager().create(root, name: 'T');
      await writeNote(
        'games/p/codex/moerwald.md',
        id: 'ort-1',
        type: 'codex',
        title: 'Mörwald',
        body: 'Verwaltet von [[Haus Verren]] und [[Gibt Es Nicht]].',
        tags: ['ort'],
      );
      await writeNote(
        'games/p/codex/verren.md',
        id: 'fraktion-1',
        type: 'codex',
        title: 'Haus Verren',
      );

      final db = ChronicleDatabase.memory();
      addTearDown(db.close);

      final scan = await const VaultScanner().scan(root);
      final report = await IndexRebuilder(db).rebuild(scan);

      expect(report.noteCount, 2);
      expect(report.edgeCount, 2);
      // Ein Link auf eine noch nicht existierende Seite ist kein Fehler,
      // sondern eine Absicht.
      expect(report.unresolvedLinks, 1);

      final backlinks = await db.backlinksFor('fraktion-1');
      expect(backlinks.single.id, 'ort-1');
    });

    test('löst Links unabhängig von Groß- und Kleinschreibung auf', () async {
      await const VaultManager().create(root, name: 'T');
      await writeNote(
        'games/p/codex/a.md',
        id: 'a',
        type: 'codex',
        title: 'Mörwald',
        body: 'Siehe [[mörwald]].',
      );

      final db = ChronicleDatabase.memory();
      addTearDown(db.close);
      final report = await IndexRebuilder(db)
          .rebuild(await const VaultScanner().scan(root));

      expect(report.unresolvedLinks, 0);
    });

    test('findet Volltext über die FTS5-Suche', () async {
      await const VaultManager().create(root, name: 'T');
      await writeNote(
        'games/p/codex/moor.md',
        id: 'n1',
        type: 'codex',
        title: 'Das Moor',
        body: 'Der Nebel über dem Moor wird dichter.',
      );

      final db = ChronicleDatabase.memory();
      addTearDown(db.close);
      await IndexRebuilder(db).rebuild(await const VaultScanner().scan(root));

      final hits = await db.search('Nebel');
      expect(hits.single.id, 'n1');
      expect(hits.single.title, 'Das Moor');
    });

    test('wirft bei Sonderzeichen in der Suche nicht', () async {
      // Ein Suchfeld darf nie werfen — der Nutzer tippt beliebiges Zeug.
      final db = ChronicleDatabase.memory();
      addTearDown(db.close);
      expect(await db.search('"*(^:-'), isEmpty);
      expect(await db.search('   '), isEmpty);
    });

    test('überlebt das Löschen des Index vollständig', () async {
      // DIE Kernzusage: die DB ist ein Cache, die Dateien sind die Wahrheit.
      await const VaultManager().create(root, name: 'T');
      await writeNote(
        'games/p/codex/a.md',
        id: 'ort-1',
        type: 'codex',
        title: 'Mörwald',
        body: 'Siehe [[Haus Verren]].',
        tags: ['ort', 'nordmark'],
      );
      await writeNote(
        'games/p/codex/b.md',
        id: 'fraktion-1',
        type: 'codex',
        title: 'Haus Verren',
      );

      final dbFile = File(VaultLayout.database(root));

      final firstDb = ChronicleDatabase.forFile(dbFile);
      final firstReport = await IndexRebuilder(firstDb)
          .rebuild(await const VaultScanner().scan(root));
      final firstNotes = await firstDb.select(firstDb.notes).get();
      await firstDb.close();

      // Index wegwerfen, so als käme der Stick an einem fremden Rechner an.
      await dbFile.delete();
      expect(await dbFile.exists(), isFalse);

      final secondDb = ChronicleDatabase.forFile(dbFile);
      addTearDown(secondDb.close);
      final secondReport = await IndexRebuilder(secondDb)
          .rebuild(await const VaultScanner().scan(root));
      final secondNotes = await secondDb.select(secondDb.notes).get();

      expect(secondReport.noteCount, firstReport.noteCount);
      expect(secondReport.edgeCount, firstReport.edgeCount);
      expect(
        secondNotes.map((n) => n.id).toSet(),
        firstNotes.map((n) => n.id).toSet(),
      );
      expect(
        secondNotes.firstWhere((n) => n.id == 'ort-1').tagsJson,
        contains('nordmark'),
      );
      // Und die Backlinks stehen wieder.
      expect((await secondDb.backlinksFor('fraktion-1')).single.id, 'ort-1');
    });

    test('ein zweiter Rebuild verdoppelt nichts', () async {
      await const VaultManager().create(root, name: 'T');
      await writeNote(
        'games/p/codex/a.md',
        id: 'a',
        type: 'codex',
        title: 'A',
        body: 'Siehe [[A]].',
      );

      final db = ChronicleDatabase.memory();
      addTearDown(db.close);
      final rebuilder = IndexRebuilder(db);

      await rebuilder.rebuild(await const VaultScanner().scan(root));
      final after = await rebuilder.rebuild(
        await const VaultScanner().scan(root),
      );

      expect(after.noteCount, 1);
      expect(await db.countNotes(), 1);
    });
  });

  group('Vault-Gate', () {
    // Ohne Widgets: hier geht es um den Zustandsübergang, nicht ums Rendern.
    // Ein Widget-Test dafür wäre langsamer und würde den eigentlichen Punkt
    // hinter Pump-Zyklen verstecken.
    test('schaltet beim Öffnen und Schließen um', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(hasOpenVaultProvider), isFalse);

      final notifier = container.read(activeVaultProvider.notifier);
      await notifier.createAndOpen(root, 'Testvault');

      expect(container.read(hasOpenVaultProvider), isTrue);
      expect(
        container.read(activeVaultProvider).value?.vault.name,
        'Testvault',
      );

      await notifier.close();
      expect(container.read(hasOpenVaultProvider), isFalse);
    });

    test('meldet einen Ordner ohne Vault als Fehler, ohne zu werfen', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final plain = Directory('$root/kein_vault')..createSync();
      await container.read(activeVaultProvider.notifier).openPath(plain.path);

      final state = container.read(activeVaultProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<VaultException>());
      expect(container.read(hasOpenVaultProvider), isFalse);
    });

    test('merkt sich geöffnete Vaults in der Zuletzt-Liste', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(activeVaultProvider.notifier)
          .createAndOpen(root, 'Testvault');

      final recent = await container.read(recentVaultsProvider.future);
      expect(recent.single.path, root);
      expect(recent.single.name, 'Testvault');
    });
  });
}
