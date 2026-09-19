// Datei: chronicle/test/domain_test.dart
//
// ZWECK: Die reinen Dart-Parser. Sie sind billig zu testen und tragen das
//        Vault-Format — hier zahlt sich Abdeckung sofort aus.
//
// SCHRITT: 3

import 'package:chronicle/domain/frontmatter/frontmatter.dart';
import 'package:chronicle/domain/frontmatter/note_frontmatter.dart';
import 'package:chronicle/domain/wikilink/wikilink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Frontmatter', () {
    test('trennt Block und Body', () {
      const source = '---\nid: abc\ntitle: Mörwald\n---\n# Mörwald\n\nText.\n';
      final doc = parseDocument(source);

      expect(doc.hadFrontmatter, isTrue);
      expect(doc.frontmatter['id'], 'abc');
      expect(doc.frontmatter['title'], 'Mörwald');
      expect(doc.body, '# Mörwald\n\nText.\n');
    });

    test('behandelt eine Datei ohne Block als reinen Body', () {
      const source = '# Nur Text\n';
      final doc = parseDocument(source);

      expect(doc.hadFrontmatter, isFalse);
      expect(doc.frontmatter, isEmpty);
      expect(doc.body, source);
    });

    test('verliert bei kaputtem YAML die Datei nicht', () {
      // Eine defekte Notiz darf den Scan nicht abbrechen — sonst macht sie
      // den ganzen Vault unbenutzbar.
      const source = '---\n: : :\n  broken\n---\nInhalt bleibt.\n';
      final doc = parseDocument(source);

      expect(doc.body, contains('Inhalt bleibt.'));
    });

    test('kommt mit Windows-Zeilenenden zurecht', () {
      // Vaults wandern per USB-Stick zwischen Betriebssystemen.
      const source = '---\r\nid: abc\r\n---\r\nText\r\n';
      final doc = parseDocument(source);

      expect(doc.hadFrontmatter, isTrue);
      expect(doc.frontmatter['id'], 'abc');
    });

    test(
      'lässt eine Notiz einen Schreib-Lese-Zyklus unverändert überstehen',
      () {
        final original = NoteFrontmatter(
          id: '018f3c2a-7b41-7c3e-9d8a-2f10bb45e901',
          type: NoteType.codex,
          title: 'Die Grafschaft Mörwald: Nordmark',
          created: DateTime.utc(2026, 9, 19, 18, 2, 44),
          updated: DateTime.utc(2026, 9, 19, 20, 31, 7),
          tags: const ['ort', 'kampagne-nebelmoor'],
          properties: const {'region': 'Nordmark', 'einwohner': 1200},
          extra: const {'banner': '../media/moerwald.jpg'},
        );

        final written = serializeDocument(original.toMap(), '# Mörwald\n');
        final reread = parseDocument(written);
        final restored = NoteFrontmatter.fromMap(
          reread.frontmatter,
          fallbackId: 'anders',
          fallbackTitle: 'anders',
          fallbackType: NoteType.log,
          now: DateTime.utc(2000),
        );

        expect(restored.id, original.id);
        expect(restored.type, original.type);
        expect(restored.title, original.title);
        expect(restored.created, original.created);
        expect(restored.updated, original.updated);
        expect(restored.tags, original.tags);
        expect(restored.properties['region'], 'Nordmark');
        expect(restored.properties['einwohner'], 1200);
        // Unbekannte Schlüssel überleben — sonst frisst unser Speichern die
        // Daten anderer Werkzeuge.
        expect(restored.extra['banner'], '../media/moerwald.jpg');
      },
    );

    test('erkennt unvollständiges Frontmatter', () {
      expect(NoteFrontmatter.isComplete(const {}), isFalse);
      expect(
        NoteFrontmatter.isComplete(const {'id': 'a', 'type': 'codex'}),
        isFalse,
      );
      expect(
        NoteFrontmatter.isComplete(const {
          'id': 'a',
          'type': 'codex',
          'title': 'T',
          'created': '2026-01-01T00:00:00Z',
          'updated': '2026-01-01T00:00:00Z',
        }),
        isTrue,
      );
    });

    test('nimmt einen einzelnen Tag ohne Liste an', () {
      // Von Hand geschriebenes Frontmatter sieht oft so aus.
      final fm = NoteFrontmatter.fromMap(
        const {'tags': 'ort'},
        fallbackId: 'a',
        fallbackTitle: 'T',
        fallbackType: NoteType.codex,
        now: DateTime.utc(2026),
      );
      expect(fm.tags, ['ort']);
    });
  });

  group('Wikilinks', () {
    test('liest alle vier Formen plus Embed', () {
      const text =
          'Siehe [[Mörwald]], [[Mörwald#Geschichte]], [[Haus Verren|die '
          'Verren]] und [[Mörwald#Lage|dort]]. ![[karte.png]]';

      final links = parseWikiLinks(text);

      expect(links.length, 5);
      expect(links[0].target, 'Mörwald');
      expect(links[0].section, isNull);
      expect(links[1].section, 'Geschichte');
      expect(links[2].target, 'Haus Verren');
      expect(links[2].alias, 'die Verren');
      expect(links[3].section, 'Lage');
      expect(links[3].alias, 'dort');
      expect(links[4].isEmbed, isTrue);
      expect(links[4].target, 'karte.png');
    });

    test('überspringt halbfertige Links', () {
      // Entstehen beim Tippen und sind kein Fehler.
      final links = parseWikiLinks('[[]] [[   ]] [[#Abschnitt]] [[ok]]');
      expect(links.length, 1);
      expect(links.single.target, 'ok');
    });

    test('überspannt keine Zeilen', () {
      // Ein unbalanciertes [[ darf nicht den halben Text verschlucken.
      final links = parseWikiLinks('[[offen\nnoch offen]]');
      expect(links, isEmpty);
    });

    test('liest ein # im Anzeigetext nicht als Abschnitt', () {
      final links = parseWikiLinks('[[Seite|Kapitel #3]]');
      expect(links.single.target, 'Seite');
      expect(links.single.alias, 'Kapitel #3');
      expect(links.single.section, isNull);
    });

    test('liefert Offsets auf den Rohtext', () {
      const text = 'abc [[Ziel]] def';
      final link = parseWikiLinks(text).single;
      expect(text.substring(link.start, link.end), '[[Ziel]]');
      expect(link.raw, '[[Ziel]]');
    });
  });
}
