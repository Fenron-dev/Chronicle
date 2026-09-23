// Datei: chronicle/test/track_test.dart
//
// ZWECK: Clocks und Step-Tracks. Der wichtigste Test ist der, der NICHTS
//        prüft außer Unverändertheit: Abhaken darf keine Zeile anfassen
//        außer der einen.
//
// SCHRITT: 8

import 'package:chronicle/domain/tracks/track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Clock', () {
    test('füllt und leert in den Grenzen', () {
      var clock = const ClockState(segments: 4);
      clock = clock.advance().advance();
      expect(clock.filled, 2);
      expect(clock.progress, 0.5);

      clock = clock.advance(10);
      expect(clock.filled, 4, reason: 'nicht über die Segmente hinaus');
      expect(clock.isComplete, isTrue);

      clock = clock.advance(-10);
      expect(clock.filled, 0, reason: 'nicht unter null');
      expect(clock.isEmpty, isTrue);
    });

    test('reset leert, behält die Segmente', () {
      final clock = const ClockState(segments: 6, filled: 5).reset();
      expect((clock.segments, clock.filled), (6, 0));
    });

    test('liest Frontmatter-Werte tolerant', () {
      // Von Hand geschrieben — als Zahl, als Text, oder zu groß.
      expect(ClockState.fromValues(6, 2).filled, 2);
      expect(ClockState.fromValues('8', '3').segments, 8);
      expect(ClockState.fromValues(6, 9).filled, 6, reason: 'geklemmt');
      expect(ClockState.fromValues(1, 0).segments, kMinClockSegments);
      expect(ClockState.fromValues(99, 0).segments, kMaxClockSegments);
      expect(ClockState.fromValues(null, null).segments, 4);
      expect(ClockState.fromValues('unsinn', -3).filled, 0);
    });
  });

  group('Beats lesen', () {
    const body = '''
# Kampagne

Die großen Stationen dieser Partie.

- [x] Ankunft in Mörwald
- [ ] Der Turm im Moor
  - [ ] Den Wächter bestechen
  - [x] Den Schlüssel finden
- [ ] Die Rückkehr

Ein abschließender Absatz.
''';

    test('findet alle Aufgabenzeilen mit Tiefe und Zeile', () {
      final beats = parseBeats(body);
      expect(beats.map((b) => b.text), [
        'Ankunft in Mörwald',
        'Der Turm im Moor',
        'Den Wächter bestechen',
        'Den Schlüssel finden',
        'Die Rückkehr',
      ]);
      expect(beats.map((b) => b.depth), [0, 0, 1, 1, 0]);
      expect(beats.map((b) => b.done), [true, false, false, true, false]);
      expect(beats.first.line, 4);
    });

    test('Tab zählt als eine Stufe', () {
      final beats = parseBeats('- [ ] Oben\n\t- [ ] Unten\n');
      expect(beats.map((b) => b.depth), [0, 1]);
    });

    test('eine gewöhnliche Liste ist kein Track', () {
      expect(parseBeats('- Nur ein Punkt\n- Noch einer\n'), isEmpty);
    });

    test('Fortschritt zählt nur Haupt-Beats', () {
      // Unter-Beats sind die Schritte eines Kapitels, nicht weitere Kapitel.
      final progress = TrackProgress.of(parseBeats(body));
      expect((progress.done, progress.total), (1, 3));
      expect(progress.next?.text, 'Der Turm im Moor');
      expect(progress.isComplete, isFalse);
    });

    test('ein erledigter Track hat keinen nächsten Beat', () {
      final progress = TrackProgress.of(parseBeats('- [x] A\n- [X] B\n'));
      expect(progress.isComplete, isTrue);
      expect(progress.next, isNull);
    });
  });

  group('Abhaken', () {
    const body = '''
# Kampagne

Prosa, die niemand verlieren will.

- [x] Ankunft
- [ ] Der Turm
    - [ ] Unter-Beat, vier Leerzeichen eingerückt

Schluss.''';

    test('ändert genau die eine Zeile', () {
      final turm = parseBeats(body).firstWhere((b) => b.text == 'Der Turm');
      final after = toggleBeat(body, turm.line, done: true)!;

      final before = body.split('\n');
      final changed = after.split('\n');
      expect(changed, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        if (i == turm.line) {
          expect(changed[i], '- [x] Der Turm');
        } else {
          expect(changed[i], before[i], reason: 'Zeile $i unverändert');
        }
      }
    });

    test('lässt die Einrückung eines Unter-Beats stehen', () {
      final sub = parseBeats(body).firstWhere((b) => b.depth > 0);
      final after = toggleBeat(body, sub.line, done: true)!;
      expect(
        after.split('\n')[sub.line],
        '    - [x] Unter-Beat, vier Leerzeichen eingerückt',
      );
    });

    test('hebt ein Häkchen wieder auf', () {
      final ankunft = parseBeats(body).first;
      final after = toggleBeat(body, ankunft.line, done: false)!;
      expect(after.split('\n')[ankunft.line], '- [ ] Ankunft');
    });

    test('verweigert eine Zeile, die kein Beat (mehr) ist', () {
      // Die Datei wurde außerhalb geändert — lieber null als die falsche
      // Zeile kippen.
      expect(toggleBeat(body, 0, done: true), isNull);
      expect(toggleBeat(body, 999, done: true), isNull);
      expect(toggleBeat(body, -1, done: true), isNull);
    });
  });

  group('Beat anhängen', () {
    test('hängt direkt hinter die Liste, nicht ans Dateiende', () {
      const body = '- [ ] Eins\n- [ ] Zwei\n\nAbschließender Absatz.\n';
      final after = appendBeat(body, 'Drei');
      expect(
        after,
        '- [ ] Eins\n- [ ] Zwei\n- [ ] Drei\n\nAbschließender Absatz.\n',
      );
    });

    test('beginnt eine Liste, wo noch keine ist', () {
      expect(appendBeat('', 'Erster'), '- [ ] Erster\n');
      expect(appendBeat('# Titel\n', 'Erster'), '# Titel\n\n- [ ] Erster\n');
    });

    test('ignoriert leeren Text', () {
      expect(appendBeat('- [ ] Eins\n', '   '), '- [ ] Eins\n');
    });
  });
}
