// Datei: chronicle/test/roll_engine_test.dart
//
// ZWECK: Würfel und Tabellen. Zufall wird über einen gesetzten Seed
//        reproduzierbar gemacht — ohne das wären die Tests entweder
//        nichtssagend oder sporadisch rot.
//
// SCHRITT: 6

import 'dart:math';

import 'package:chronicle/domain/roll_engine/dice.dart';
import 'package:chronicle/domain/roll_engine/oracle_table.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ein Würfel, der eine vorgegebene Folge liefert.
///
/// Verlässlicher als ein Seed: der Test sagt damit, WELCHE Augen fallen,
/// statt sich auf das Innenleben von Random zu verlassen.
class _ScriptedRandom implements Random {
  _ScriptedRandom(this._values);

  final List<int> _values;
  int _index = 0;

  @override
  int nextInt(int max) {
    final value = _values[_index++ % _values.length];
    return value % max;
  }

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(1000) / 1000;
}

/// Würfelaugen in der Reihenfolge [faces] (1-basiert).
Random _dice(List<int> faces) =>
    _ScriptedRandom([for (final face in faces) face - 1]);

void main() {
  group('Würfel-Parser', () {
    test('liest die Grundformen', () {
      expect(DiceExpression.parse('2d6').notation, '2d6');
      expect(DiceExpression.parse('d20').notation, '1d20');
      expect(DiceExpression.parse('D20').notation, '1d20');
      expect(DiceExpression.parse('2d6+1').notation, '2d6 + 1');
      expect(DiceExpression.parse('2d6 - 3').notation, '2d6 - 3');
      expect(DiceExpression.parse('1d8+1d6+2').notation, '1d8 + 1d6 + 2');
    });

    test('liest Keep- und Drop-Angaben', () {
      expect(DiceExpression.parse('4d6kh3').notation, '4d6kh3');
      expect(DiceExpression.parse('2d6kl1').notation, '2d6kl1');
      expect(DiceExpression.parse('4d6dl1').notation, '4d6dl1');
      // Ohne Zahl heißt: einer.
      expect(DiceExpression.parse('2d6kh').notation, '2d6kh1');
    });

    test('meldet die Stelle, an der es klemmt', () {
      void expectFail(String source) {
        expect(
          () => DiceExpression.parse(source),
          throwsA(isA<DiceParseException>()),
          reason: source,
        );
      }

      expectFail('');
      expectFail('2d');
      expectFail('2d6+');
      expectFail('abc');
      expectFail('2d6 5');
      // Mehr behalten als geworfen ist ein Denkfehler, kein Sonderfall.
      expectFail('2d6kh5');
      // Tippfehler-Bremse.
      expectFail('100000d6');
      expectFail('1d0');
    });

    test('der Fehler nennt Quelle und Position', () {
      try {
        DiceExpression.parse('2d6+');
        fail('sollte werfen');
      } on DiceParseException catch (error) {
        expect(error.source, '2d6+');
        expect(error.offset, greaterThan(0));
        expect(error.message, isNotEmpty);
      }
    });
  });

  group('Würfeln', () {
    test('summiert Würfel und Konstante', () {
      final roll = DiceExpression.parse('2d6+1').roll(_dice([4, 5]));
      expect(roll.terms.first.rolls, [4, 5]);
      expect(roll.total, 10);
    });

    test('zieht einen negativen Term ab', () {
      final roll = DiceExpression.parse('1d6-2').roll(_dice([5]));
      expect(roll.total, 3);
    });

    test('keep-highest behält die höchsten, in Wurfreihenfolge', () {
      final roll = DiceExpression.parse('4d6kh3').roll(_dice([5, 3, 1, 6]));
      final term = roll.terms.single;

      // Die Reihenfolge auf dem Tisch bleibt erhalten …
      expect(term.rolls, [5, 3, 1, 6]);
      // … gewertet wird die 1 nicht.
      expect(term.keptRolls, [5, 3, 6]);
      expect(roll.total, 14);
      expect(term.hasDropped, isTrue);
    });

    test('keep-lowest behält den niedrigsten (FitD-Pool)', () {
      final roll = DiceExpression.parse('2d6kl1').roll(_dice([6, 2]));
      expect(roll.terms.single.keptRolls, [2]);
      expect(roll.total, 2);
    });

    test('drop-lowest wirft den niedrigsten weg', () {
      final roll = DiceExpression.parse('4d6dl1').roll(_dice([5, 3, 1, 6]));
      expect(roll.terms.single.keptRolls, [5, 3, 6]);
      expect(roll.total, 14);
    });

    test('bei Gleichstand fällt genau einer weg', () {
      final roll = DiceExpression.parse('3d6kh2').roll(_dice([4, 4, 4]));
      expect(roll.terms.single.keptRolls, hasLength(2));
      expect(roll.total, 8);
    });

    test('describe zeigt weggefallene Würfel an', () {
      final roll = DiceExpression.parse('4d6kh3').roll(_dice([5, 3, 1, 6]));
      expect(roll.describe(), '4d6kh3: [5, 3, ~1~, 6] = 14');
    });

    test('bleibt in den Grenzen des Würfels', () {
      final rng = Random(42);
      for (var i = 0; i < 200; i++) {
        final roll = DiceExpression.parse('3d6').roll(rng);
        expect(roll.total, inInclusiveRange(3, 18));
        expect(roll.allRolls.every((v) => v >= 1 && v <= 6), isTrue);
      }
    });
  });

  group('Tabellen', () {
    OracleTable table(
      String title,
      TableKind kind,
      List<TableEntry> entries, {
      String? dice,
    }) => OracleTable(
      id: title,
      title: title,
      kind: kind,
      entries: entries,
      dice: dice,
    );

    test('uniform wählt einen Eintrag', () {
      final t = table('Wetter', TableKind.uniform, const [
        TableEntry(text: 'Nebel'),
        TableEntry(text: 'Regen'),
        TableEntry(text: 'Sturm'),
      ]);
      const roller = TableRoller(tables: {});
      final result = roller.roll(t, _ScriptedRandom([1]));
      expect(result.text, 'Regen');
      expect(result.steps.single.table, 'Wetter');
    });

    test('weighted trifft nach Gewicht', () {
      final t = table('Begegnung', TableKind.weighted, const [
        TableEntry(text: 'Selten', weight: 1),
        TableEntry(text: 'Häufig', weight: 9),
      ]);
      const roller = TableRoller(tables: {});

      // Gesamtgewicht 10: 0 trifft „Selten", 1..9 „Häufig".
      expect(roller.roll(t, _ScriptedRandom([0])).text, 'Selten');
      expect(roller.roll(t, _ScriptedRandom([1])).text, 'Häufig');
      expect(roller.roll(t, _ScriptedRandom([9])).text, 'Häufig');
    });

    test('weighted überspringt Einträge ohne Gewicht', () {
      final t = table('Begegnung', TableKind.weighted, const [
        TableEntry(text: 'Aus', weight: 0),
        TableEntry(text: 'An', weight: 1),
      ]);
      const roller = TableRoller(tables: {});
      expect(roller.roll(t, _ScriptedRandom([0])).text, 'An');
    });

    test('weighted ohne jedes Gewicht meldet das, statt zu raten', () {
      final t = table('Kaputt', TableKind.weighted, const [
        TableEntry(text: 'Aus', weight: 0),
      ]);
      const roller = TableRoller(tables: {});
      expect(
        () => roller.roll(t, Random(1)),
        throwsA(isA<TableRollException>()),
      );
    });

    test('dice wählt über den Wurf und merkt sich ihn', () {
      final t = table('Orakel', TableKind.dice, const [
        TableEntry(text: 'Nein, und', min: 2, max: 4),
        TableEntry(text: 'Vielleicht', min: 5, max: 9),
        TableEntry(text: 'Ja, und', min: 10, max: 12),
      ], dice: '2d6');
      const roller = TableRoller(tables: {});

      final result = roller.roll(t, _dice([6, 6]));
      expect(result.text, 'Ja, und');
      // Die Provenienz trägt den Wurf mit — im Log soll stehen, WARUM.
      expect(result.steps.single.dice?.total, 12);
    });

    test('dice meldet eine Lücke in den Bereichen', () {
      final t = table('Lückenhaft', TableKind.dice, const [
        TableEntry(text: 'Nur hoch', min: 10, max: 12),
      ], dice: '2d6');
      const roller = TableRoller(tables: {});
      expect(
        () => roller.roll(t, _dice([1, 1])),
        throwsA(isA<TableRollException>()),
      );
    });

    test('dice ohne dice-Angabe ist ein Fehler in der Tabelle', () {
      final t = table('Ohne', TableKind.dice, const [
        TableEntry(text: 'x', min: 1, max: 6),
      ]);
      const roller = TableRoller(tables: {});
      expect(
        () => roller.roll(t, Random(1)),
        throwsA(isA<TableRollException>()),
      );
    });

    test('leere Tabelle meldet sich, statt leer zurückzukommen', () {
      final t = table('Leer', TableKind.uniform, const []);
      const roller = TableRoller(tables: {});
      expect(
        () => roller.roll(t, Random(1)),
        throwsA(isA<TableRollException>()),
      );
    });
  });

  group('Subtabellen', () {
    const kultur = OracleTable(
      id: 'k',
      title: 'Kultur',
      kind: TableKind.uniform,
      entries: [TableEntry(text: 'Mörwaldisch')],
    );
    const epitheton = OracleTable(
      id: 'e',
      title: 'Epitheton',
      kind: TableKind.uniform,
      entries: [TableEntry(text: 'der Stille')],
    );

    test('löst Platzhalter im Text auf', () {
      const name = OracleTable(
        id: 'n',
        title: 'Name',
        kind: TableKind.uniform,
        entries: [TableEntry(text: '[Kultur], [Epitheton]')],
      );
      const roller = TableRoller(
        tables: {'kultur': kultur, 'epitheton': epitheton, 'name': name},
      );

      final result = roller.roll(name, Random(1));
      expect(result.text, 'Mörwaldisch, der Stille');
      // Jeder Schritt steht in der Provenienz.
      expect(result.steps.map((s) => s.table), ['Name', 'Kultur', 'Epitheton']);
    });

    test('ein subtable-Eintrag ersetzt sich durch das Ergebnis', () {
      const wurzel = OracleTable(
        id: 'w',
        title: 'Wurzel',
        kind: TableKind.uniform,
        entries: [TableEntry(text: '', subtable: 'Kultur')],
      );
      const roller = TableRoller(tables: {'kultur': kultur, 'wurzel': wurzel});
      expect(roller.roll(wurzel, Random(1)).text, 'Mörwaldisch');
    });

    test('unbekannte Tabelle bleibt als Text stehen', () {
      // Wie beim Wikilink: der Verweis ist oft vor dem Ziel da.
      const name = OracleTable(
        id: 'n',
        title: 'Name',
        kind: TableKind.uniform,
        entries: [TableEntry(text: 'Ein [Gibtsnicht]')],
      );
      const roller = TableRoller(tables: {'name': name});
      expect(roller.roll(name, Random(1)).text, 'Ein [Gibtsnicht]');
    });

    test('erkennt einen direkten Zyklus', () {
      const a = OracleTable(
        id: 'a',
        title: 'A',
        kind: TableKind.uniform,
        entries: [TableEntry(text: '[A]')],
      );
      const roller = TableRoller(tables: {'a': a});
      expect(
        () => roller.roll(a, Random(1)),
        throwsA(isA<CycleDetectedException>()),
      );
    });

    test('erkennt einen Zyklus über mehrere Stufen', () {
      const a = OracleTable(
        id: 'a',
        title: 'A',
        kind: TableKind.uniform,
        entries: [TableEntry(text: '[B]')],
      );
      const b = OracleTable(
        id: 'b',
        title: 'B',
        kind: TableKind.uniform,
        entries: [TableEntry(text: '[C]')],
      );
      const c = OracleTable(
        id: 'c',
        title: 'C',
        kind: TableKind.uniform,
        entries: [TableEntry(text: '[A]')],
      );
      const roller = TableRoller(tables: {'a': a, 'b': b, 'c': c});

      try {
        roller.roll(a, Random(1));
        fail('sollte werfen');
      } on CycleDetectedException catch (error) {
        // Der Pfad ist die eigentliche Hilfe: er zeigt, wo zu schneiden ist.
        expect(error.path, ['a', 'b', 'c', 'a']);
        expect(error.message, contains('Kreis'));
      }
    });

    test('dieselbe Tabelle zweimal nebeneinander ist kein Zyklus', () {
      const paar = OracleTable(
        id: 'p',
        title: 'Paar',
        kind: TableKind.uniform,
        entries: [TableEntry(text: '[Kultur] und [Kultur]')],
      );
      const roller = TableRoller(tables: {'kultur': kultur, 'paar': paar});
      expect(roller.roll(paar, Random(1)).text, 'Mörwaldisch und Mörwaldisch');
    });

    test('ein Wikilink im Eintrag bleibt unangetastet', () {
      // `[[Seite]]` darf nicht als Platzhalter gelesen werden.
      const t = OracleTable(
        id: 't',
        title: 'T',
        kind: TableKind.uniform,
        entries: [TableEntry(text: 'Siehe [[Haus Verren]]')],
      );
      const roller = TableRoller(tables: {'t': t});
      expect(roller.roll(t, Random(1)).text, 'Siehe [[Haus Verren]]');
    });
  });

  group('Decks', () {
    const tarot = OracleTable(
      id: 'tarot',
      title: 'Tarot',
      kind: TableKind.deck,
      reversible: true,
      entries: [
        TableEntry(text: 'Der Narr'),
        TableEntry(text: 'Die Hohepriesterin'),
        TableEntry(text: 'Der Turm'),
      ],
    );

    test('zieht ohne Zurücklegen', () {
      var state = DeckState.shuffled(tarot, Random(7));
      expect(state.remaining, 3);

      state = state.draw(2, random: Random(7));
      expect(state.hand, hasLength(2));
      expect(state.remaining, 1);

      final gezogen = state.hand.map((c) => c.index).toSet();
      expect(gezogen, hasLength(2), reason: 'keine Karte doppelt');
    });

    test('füllt einen leeren Stapel NICHT heimlich nach', () {
      // Ein Deck, das sich unbemerkt nachfüllt, macht jede Aussage über
      // „schon gezogen" wertlos.
      var state = DeckState.shuffled(tarot, Random(1)).draw(5);
      expect(state.hand, hasLength(3));
      expect(state.isEmpty, isTrue);

      state = state.draw(1);
      expect(state.hand, hasLength(3), reason: 'nichts mehr zu ziehen');
    });

    test('Ablegen und Neumischen bringt alle Karten zurück', () {
      var state = DeckState.shuffled(tarot, Random(3)).draw(2);
      state = state.discardHand();
      expect(state.hand, isEmpty);
      expect(state.discard, hasLength(2));

      state = state.reshuffle(Random(3));
      expect(state.remaining, 3);
      expect(state.discard, isEmpty);
      expect(state.drawPile.toSet(), {0, 1, 2});
    });

    test('umgekehrte Karten nur, wenn erlaubt', () {
      final ohne = DeckState.shuffled(tarot, Random(1)).draw(3);
      expect(ohne.hand.every((c) => !c.reversed), isTrue);

      final mit = DeckState.shuffled(
        tarot,
        Random(1),
      ).draw(3, random: _ScriptedRandom([1, 1, 1]), allowReversed: true);
      expect(mit.hand.every((c) => c.reversed), isTrue);
    });

    test('überlebt den Weg durch JSON', () {
      // Der Deckzustand gehört in die Partie-Datei — sonst überlebt er den
      // nächsten Index-Rebuild nicht (CLAUDE.md §2.5).
      final state = DeckState.shuffled(tarot, Random(5))
          .draw(1, random: _ScriptedRandom([1]), allowReversed: true)
          .discardHand()
          .draw(1);

      final wieder = DeckState.fromJson(state.toJson());
      expect(wieder.drawPile, state.drawPile);
      expect(wieder.hand.map((c) => c.index), state.hand.map((c) => c.index));
      expect(
        wieder.discard.map((c) => c.reversed),
        state.discard.map((c) => c.reversed),
      );
    });

    test('kaputtes JSON ergibt ein leeres Deck statt eines Absturzes', () {
      final state = DeckState.fromJson(const {'drawPile': 'unsinn'});
      expect(state.drawPile, isEmpty);
      expect(state.hand, isEmpty);
    });
  });
}
