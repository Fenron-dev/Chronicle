// Datei: chronicle/test/codex_test.dart
//
// ZWECK: Die Codex-Datei. Geprüft wird vor allem, was beim Speichern NICHT
//        passieren darf — fremde Frontmatter-Schlüssel verlieren oder die
//        Datei bei jedem Durchgang um eine Leerzeile wachsen lassen.
//
// SCHRITT: 5

import 'dart:io';

import 'package:chronicle/data/vault/codex_repository.dart';
import 'package:chronicle/domain/frontmatter/frontmatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const repo = CodexRepository();
  late Directory vault;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('chronicle-codex-');
    await Directory(p.join(vault.path, 'games/moor/codex'))
        .create(recursive: true);
  });

  tearDown(() => vault.delete(recursive: true));

  Future<String> newPage(String title) =>
      repo.create(vault.path, 'moor', title: title, fileStem: 'seite');

  test('legt eine Seite mit vollständigem Frontmatter an', () async {
    final relPath = await newPage('Die Grafschaft Mörwald');
    expect(relPath, 'games/moor/codex/seite.md');

    final page = await repo.load(vault.path, relPath);
    expect(page.title, 'Die Grafschaft Mörwald');
    expect(page.noteId, isNotEmpty);
    expect(page.frontmatter['type'], 'codex');
    // Eine völlig leere Datei sähe im Baum wie ein Fehlschlag aus.
    expect(page.body.trim(), '# Die Grafschaft Mörwald');
  });

  test('ein Doppelpunkt im Titel zerlegt das YAML nicht', () async {
    // Über serializeDocument geschrieben; handgeschriebenes YAML wäre hier
    // auseinandergefallen.
    final relPath = await newPage('Ironsworn: Starforged');
    final page = await repo.load(vault.path, relPath);
    expect(page.title, 'Ironsworn: Starforged');
  });

  test('Speichern ersetzt den Rumpf und zieht updated mit', () async {
    final relPath = await newPage('Mörwald');
    final before = await repo.load(vault.path, relPath);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.save(vault.path, relPath, body: '# Neu\n\nAnderer Text.');

    final after = await repo.load(vault.path, relPath);
    expect(after.body.trim(), '# Neu\n\nAnderer Text.');
    expect(after.noteId, before.noteId, reason: 'die id bleibt');
    expect(
      DateTime.parse(after.frontmatter['updated'].toString())
          .isAfter(DateTime.parse(before.frontmatter['updated'].toString())),
      isTrue,
    );
  });

  test('fremde Frontmatter-Schlüssel überleben das Speichern', () async {
    final relPath = await newPage('Mörwald');
    final file = File(p.join(vault.path, relPath));

    // So, als hätte Obsidian oder eine neuere Chronicle-Version die Datei
    // angefasst. Diese Schlüssel dürfen wir nicht auffressen.
    final doc = parseDocument(await file.readAsString());
    final extended = Map<String, dynamic>.from(doc.frontmatter)
      ..['banner'] = '../media/moor.jpg'
      ..['accent-color'] = 'moss';
    await file.writeAsString(serializeDocument(extended, doc.body));

    await repo.save(vault.path, relPath, body: 'Neuer Text.');

    final page = await repo.load(vault.path, relPath);
    expect(page.frontmatter['banner'], '../media/moor.jpg');
    expect(page.frontmatter['accent-color'], 'moss');
  });

  test('Speichern setzt den Titel nur, wenn einer kommt', () async {
    final relPath = await newPage('Mörwald');

    await repo.save(vault.path, relPath, body: 'Text.');
    expect((await repo.load(vault.path, relPath)).title, 'Mörwald');

    await repo.save(vault.path, relPath, body: 'Text.', title: 'Nebelmoor');
    expect((await repo.load(vault.path, relPath)).title, 'Nebelmoor');

    // Leerer Titel ist kein Titel — sonst löscht ein versehentlich geleertes
    // Feld den Namen der Seite.
    await repo.save(vault.path, relPath, body: 'Text.', title: '   ');
    expect((await repo.load(vault.path, relPath)).title, 'Nebelmoor');
  });

  test('mehrfaches Speichern lässt die Datei nicht wachsen', () async {
    final relPath = await newPage('Mörwald');
    final file = File(p.join(vault.path, relPath));

    await repo.save(vault.path, relPath, body: 'Ein Absatz.\n\n\n');
    final firstLength = (await file.readAsString()).length;

    await repo.save(vault.path, relPath, body: 'Ein Absatz.\n\n\n');
    final secondLength = (await file.readAsString()).length;

    // updated ändert sich, die Länge des Zeitstempels nicht — wächst die
    // Datei trotzdem, sammeln sich Leerzeilen an und jeder git-Diff zeigt
    // Änderungen, die niemand gemacht hat.
    expect(secondLength, firstLength);
    expect(await file.readAsString(), endsWith('Ein Absatz.\n'));
  });

  test('Löschen entfernt die Datei', () async {
    final relPath = await newPage('Mörwald');
    await repo.delete(vault.path, relPath);
    expect(await File(p.join(vault.path, relPath)).exists(), isFalse);
    // Zweites Löschen ist kein Fehler.
    await repo.delete(vault.path, relPath);
  });
}
