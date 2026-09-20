// Datei: chronicle/test/markdown_test.dart
//
// ZWECK: Der Markdown-Parser des Codex. Geprüft wird die Übersetzung in unser
//        Dokumentmodell — besonders das, was Chronicle über CommonMark hinaus
//        kennt: Callouts, Wikilinks und Embeds.
//
// SCHRITT: 5

import 'package:chronicle/domain/markdown/markdown_parser.dart';
import 'package:chronicle/domain/markdown/md_node.dart';
import 'package:chronicle/domain/wikilink/wikilink.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Text aller Inline-Knoten, flach.
String _text(List<MdInline> nodes) {
  final buffer = StringBuffer();
  void walk(List<MdInline> list) {
    for (final node in list) {
      switch (node) {
        case MdText(:final text):
          buffer.write(text);
        case MdCodeSpan(:final text):
          buffer.write(text);
        case MdStyled(:final content):
          walk(content);
        case MdLink(:final content):
          walk(content);
        case MdWikiLink(:final link):
          buffer.write(link.displayText);
        case MdEmbed(:final link):
          buffer.write(link.target);
        case MdImage(:final alt):
          buffer.write(alt ?? '');
        case MdLineBreak():
          buffer.write('\n');
      }
    }
  }

  walk(nodes);
  return buffer.toString();
}

void main() {
  group('Blöcke', () {
    test('Überschriften tragen ihre Ebene', () {
      final blocks = parseMarkdown('# Mörwald\n\n### Bewohner');
      expect(blocks, hasLength(2));
      expect((blocks[0] as MdHeading).level, 1);
      expect(_text((blocks[0] as MdHeading).content), 'Mörwald');
      expect((blocks[1] as MdHeading).level, 3);
    });

    test('Absatz, Trenner und Codeblock', () {
      final blocks = parseMarkdown(
        'Ein Absatz.\n\n---\n\n```dart\nfinal x = 1;\n```',
      );
      expect(blocks[0], isA<MdParagraph>());
      expect(blocks[1], isA<MdRule>());
      final code = blocks[2] as MdCode;
      expect(code.language, 'dart');
      expect(code.text, 'final x = 1;');
    });

    test('Listen, geordnet und ungeordnet', () {
      final blocks = parseMarkdown('- eins\n- zwei\n\n1. erstens\n2. zweitens');
      final bullet = blocks[0] as MdList;
      expect(bullet.ordered, isFalse);
      expect(bullet.items, hasLength(2));

      final numbered = blocks[1] as MdList;
      expect(numbered.ordered, isTrue);
      expect(
        _text((numbered.items.first.content.first as MdParagraph).content),
        'erstens',
      );
    });

    test('Aufgabenliste merkt sich den Haken', () {
      final list = parseMarkdown('- [x] erledigt\n- [ ] offen')[0] as MdList;
      expect(list.items[0].checked, isTrue);
      expect(list.items[1].checked, isFalse);
    });

    test('gewöhnliche Liste hat keinen Haken', () {
      final list = parseMarkdown('- eins')[0] as MdList;
      expect(list.items.single.checked, isNull);
    });

    test('Tabelle mit Kopfzeile', () {
      final table =
          parseMarkdown('| Ort | Rolle |\n|---|---|\n| Mörwald | Sitz |')[0]
              as MdTable;
      expect(_text(table.header[0]), 'Ort');
      expect(table.rows, hasLength(1));
      expect(_text(table.rows[0][1]), 'Sitz');
    });
  });

  group('Auszeichnungen', () {
    test('fett, kursiv, durchgestrichen, Code', () {
      final content =
          (parseMarkdown('**fett** *kursiv* ~~weg~~ `code`')[0] as MdParagraph)
              .content;

      final styles = [
        for (final node in content)
          if (node is MdStyled) node.style,
      ];
      expect(styles, [MdStyle.bold, MdStyle.italic, MdStyle.strikethrough]);
      expect(content.whereType<MdCodeSpan>().single.text, 'code');
    });

    test('Text kommt unmaskiert an', () {
      // encodeHtml ist aus — sonst stünde hier `Mut &amp; Ehre`, und das
      // wäre im Journal sichtbar.
      final blocks = parseMarkdown('Mut & Ehre <nicht html>');
      expect(_text((blocks[0] as MdParagraph).content), contains('Mut & Ehre'));
      expect(
        _text((blocks[0] as MdParagraph).content),
        isNot(contains('&amp;')),
      );
    });

    test('gewöhnlicher Link behält sein Ziel', () {
      final link =
          (parseMarkdown('[Doku](https://example.org)')[0] as MdParagraph)
              .content
              .whereType<MdLink>()
              .single;
      expect(link.href, 'https://example.org');
      expect(_text(link.content), 'Doku');
    });
  });

  group('Wikilinks', () {
    test('einfacher Verweis', () {
      final node = (parseMarkdown('Siehe [[Haus Verren]].')[0] as MdParagraph)
          .content
          .whereType<MdWikiLink>()
          .single;
      expect(node.link.target, 'Haus Verren');
      expect(node.link.kind, WikiLinkKind.link);
    });

    test('Abschnitt und Alias', () {
      final node =
          (parseMarkdown('[[Mörwald#Bewohner|die Leute]]')[0] as MdParagraph)
              .content
              .whereType<MdWikiLink>()
              .single;
      expect(node.link.target, 'Mörwald');
      expect(node.link.section, 'Bewohner');
      expect(node.link.alias, 'die Leute');
      expect(node.link.displayText, 'die Leute');
    });

    test('wird nicht als Markdown-Link zerlegt', () {
      // Ohne eigene Inline-Syntax würde das Paket die inneren Klammern
      // anfassen. Genau deshalb steht unsere Syntax vor den eingebauten.
      final content = (parseMarkdown('[[Seite]]')[0] as MdParagraph).content;
      expect(content.single, isA<MdWikiLink>());
    });

    test('leeres Ziel bleibt Text', () {
      // Entsteht beim Tippen. Darf keinen halben Link erzeugen.
      final content =
          (parseMarkdown('[[]] und [[#nur-abschnitt]]')[0] as MdParagraph)
              .content;
      expect(content.whereType<MdWikiLink>(), isEmpty);
      expect(_text(content), contains('[[]]'));
    });

    test('Embed allein in einer Zeile wird ein Block', () {
      final blocks = parseMarkdown('Text davor.\n\n![[karte.png]]');
      expect(blocks[0], isA<MdParagraph>());
      final embed = blocks[1] as MdEmbedBlock;
      expect(embed.link.target, 'karte.png');
      expect(embed.link.kind, WikiLinkKind.embed);
    });

    test('Embed im Satz bleibt inline', () {
      final content =
          (parseMarkdown('Hier ![[wappen.png]] im Text.')[0] as MdParagraph)
              .content;
      expect(content.whereType<MdEmbed>().single.link.target, 'wappen.png');
      expect(_text(content), contains('im Text'));
    });
  });

  group('Callouts', () {
    test('erkennt Art und Inhalt', () {
      final callout =
          parseMarkdown('> [!lore]\n> Seit dem Fall.')[0] as MdCallout;
      expect(callout.kind, 'lore');
      expect(callout.title, isNull);
      expect(callout.folded, isFalse);
      expect(
        _text((callout.content.first as MdParagraph).content),
        contains('Seit dem Fall'),
      );
    });

    test('nimmt den Titel aus der Kopfzeile', () {
      final callout =
          parseMarkdown('> [!warning] Vorsicht\n> Der Weg ist unsicher.')[0]
              as MdCallout;
      expect(callout.kind, 'warning');
      expect(_text(callout.title!), 'Vorsicht');
      expect(
        _text((callout.content.first as MdParagraph).content),
        contains('unsicher'),
      );
    });

    test('merkt sich eingeklappt', () {
      final callout =
          parseMarkdown('> [!note]- Später\n> Inhalt.')[0] as MdCallout;
      expect(callout.folded, isTrue);
    });

    test('unbekannte Art bleibt erhalten statt zu scheitern', () {
      // Ein Spielsystem darf eigene Arten mitbringen.
      final callout =
          parseMarkdown('> [!hausregel]\n> Gilt nur hier.')[0] as MdCallout;
      expect(callout.kind, 'hausregel');
    });

    test('ausgezeichneter Titel bleibt erhalten', () {
      // Der Titel wird über die Inline-Knoten abgetrennt, nicht über den
      // Rohtext — sonst ginge die Auszeichnung beim Schnitt verloren.
      final callout =
          parseMarkdown('> [!note] **Wichtig**\n> Der Rest.')[0] as MdCallout;
      expect(callout.title!.single, isA<MdStyled>());
      expect(_text(callout.title!), 'Wichtig');
      expect(
        _text((callout.content.first as MdParagraph).content),
        'Der Rest.',
      );
    });

    test('Kopfzeile ohne Inhalt ergibt einen leeren Callout', () {
      final callout = parseMarkdown('> [!tip]')[0] as MdCallout;
      expect(callout.kind, 'tip');
      expect(callout.title, isNull);
      expect(callout.content, isEmpty);
    });

    test('Zitat ohne Kopfzeile bleibt Zitat', () {
      final quote = parseMarkdown('> Nur ein Zitat.')[0] as MdQuote;
      expect(
        _text((quote.content.first as MdParagraph).content),
        'Nur ein Zitat.',
      );
    });

    test('Wikilinks im Callout funktionieren', () {
      final callout =
          parseMarkdown('> [!lore]\n> Nach [[Haus Verren]].')[0] as MdCallout;
      final links = (callout.content.first as MdParagraph).content
          .whereType<MdWikiLink>();
      expect(links.single.link.target, 'Haus Verren');
    });
  });

  group('Robustheit', () {
    test('leerer Text ergibt keine Blöcke', () {
      expect(parseMarkdown(''), isEmpty);
      expect(parseMarkdown('   \n\n  '), isEmpty);
    });

    test('unfertige Syntax wirft nicht', () {
      // Beim Tippen ist jeder Zwischenstand kaputt. Der Editor darf davon
      // nichts merken.
      for (final source in [
        '[[',
        '> [!',
        '```dart',
        '| a |',
        '**fett',
        '![[',
      ]) {
        expect(() => parseMarkdown(source), returnsNormally, reason: source);
      }
    });
  });
}
