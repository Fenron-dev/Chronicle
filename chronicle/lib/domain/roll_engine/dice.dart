// Datei: chronicle/lib/domain/roll_engine/dice.dart
//
// ZWECK: Würfelausdrücke parsen und werfen — `2d6+1`, `d20`, `4d6kh3`,
//        `2d6kl1` (Forged-in-the-Dark-Pools).
//
// WARUM EIN EIGENER PARSER: Ein Würfelausdruck ist Nutzereingabe. Er darf
//        nicht werfen, wenn jemand sich vertippt, sondern muss sagen, WO es
//        klemmt — deshalb trägt [DiceParseException] eine Position.
//
// WARUM DIE EINZELWÜRFE MITKOMMEN: Im Play-Log steht nicht „9", sondern
//        „4d6kh3 → [5, 3, 1, 6] ⇒ 14". Wer würfelt, will die Würfel sehen;
//        ein blankes Ergebnis wirkt wie eine Behauptung.
//
// REINE DART-LOGIK ohne Flutter-Import (CLAUDE.md §7).
//
// SIEHE: Konzept §4.4, CLAUDE.md §4 (Reuse-Karte)
// SCHRITT: 6

import 'dart:math';

/// Obergrenzen. Nicht gegen Angreifer, sondern gegen Tippfehler: `100d6`
/// ist ein Pool, `100000d6` ist ein verrutschter Finger und würde die
/// Oberfläche einfrieren.
const int kMaxDiceCount = 1000;
const int kMaxDiceSides = 10000;

/// Was mit den geworfenen Würfeln geschieht.
enum KeepMode {
  /// Alle zählen.
  all,

  /// Die höchsten [DiceTerm.keepCount] zählen — `4d6kh3`.
  keepHighest,

  /// Die niedrigsten zählen — `2d6kl1`.
  keepLowest,

  /// Die höchsten fallen weg — `4d6dh1`.
  dropHighest,

  /// Die niedrigsten fallen weg — `4d6dl1`.
  dropLowest,
}

/// Fehler beim Lesen eines Würfelausdrucks.
///
/// Typisiert statt einer rohen Exception, damit das UI die Stelle markieren
/// kann, ohne Fehlertexte zu vergleichen (Skill `flutter-conventions`).
class DiceParseException implements Exception {
  const DiceParseException(this.message, this.source, this.offset);

  final String message;
  final String source;

  /// Zeichenposition in [source], an der es klemmt.
  final int offset;

  @override
  String toString() => 'DiceParseException($message @ $offset in "$source")';
}

/// Ein Summand: entweder Würfel oder eine feste Zahl.
sealed class DiceTerm {
  const DiceTerm({required this.negated});

  /// Ob der Term abgezogen statt addiert wird.
  final bool negated;

  String get notation;
}

/// `NdS` mit optionaler Keep-/Drop-Angabe.
class DiceRollTerm extends DiceTerm {
  const DiceRollTerm({
    required this.count,
    required this.sides,
    required super.negated,
    this.keepMode = KeepMode.all,
    this.keepCount = 1,
  });

  final int count;
  final int sides;
  final KeepMode keepMode;

  /// Wie viele Würfel behalten bzw. verworfen werden.
  final int keepCount;

  @override
  String get notation {
    final suffix = switch (keepMode) {
      KeepMode.all => '',
      KeepMode.keepHighest => 'kh$keepCount',
      KeepMode.keepLowest => 'kl$keepCount',
      KeepMode.dropHighest => 'dh$keepCount',
      KeepMode.dropLowest => 'dl$keepCount',
    };
    return '${count}d$sides$suffix';
  }
}

/// Ein fester Summand, etwa die `+2` in `2d6+2`.
class ConstantTerm extends DiceTerm {
  const ConstantTerm({required this.value, required super.negated});

  final int value;

  @override
  String get notation => '$value';
}

/// Ein geparster Würfelausdruck.
class DiceExpression {
  const DiceExpression({required this.terms, required this.source});

  final List<DiceTerm> terms;

  /// Der Text, wie er eingegeben wurde.
  final String source;

  /// Normalisierte Schreibweise — `d20` wird zu `1d20`.
  String get notation {
    final buffer = StringBuffer();
    for (final (index, term) in terms.indexed) {
      if (index == 0) {
        if (term.negated) buffer.write('-');
      } else {
        buffer.write(term.negated ? ' - ' : ' + ');
      }
      buffer.write(term.notation);
    }
    return buffer.toString();
  }

  /// Kleinster und größter möglicher Gesamtwert.
  ///
  /// Gebraucht, um eine Würfeltabelle auf Lücken zu prüfen: ohne die
  /// Spannweite wüsste niemand, dass bei `2d6` die 2 und die 12 abgedeckt
  /// sein müssen — und die Lücke fiele erst beim Würfeln auf, mitten im
  /// Spiel.
  (int, int) get range {
    var low = 0;
    var high = 0;

    for (final term in terms) {
      final (termLow, termHigh) = switch (term) {
        ConstantTerm(:final value) => (value, value),
        DiceRollTerm(
          :final count,
          :final sides,
          :final keepMode,
          :final keepCount,
        ) =>
          () {
            final counted = switch (keepMode) {
              KeepMode.all => count,
              KeepMode.keepHighest || KeepMode.keepLowest => keepCount,
              KeepMode.dropHighest ||
              KeepMode.dropLowest => (count - keepCount).clamp(0, count),
            };
            return (counted, counted * sides);
          }(),
      };

      // Bei einem abgezogenen Term tauschen die Grenzen die Rollen.
      if (term.negated) {
        low -= termHigh;
        high -= termLow;
      } else {
        low += termLow;
        high += termHigh;
      }
    }

    return (low, high);
  }

  /// Liest [source]. Wirft [DiceParseException] bei ungültiger Eingabe.
  static DiceExpression parse(String source) => _DiceParser(source).parse();

  /// Wirft die Würfel. [random] injizierbar, damit Tests reproduzierbar sind.
  DiceRoll roll([Random? random]) {
    final rng = random ?? Random();
    final rolled = <DiceTermRoll>[];
    var total = 0;

    for (final term in terms) {
      final result = switch (term) {
        ConstantTerm(:final value) => DiceTermRoll(
          notation: term.notation,
          negated: term.negated,
          rolls: const [],
          kept: const [],
          value: value,
        ),
        DiceRollTerm() => _rollDice(term, rng),
      };
      rolled.add(result);
      total += term.negated ? -result.value : result.value;
    }

    return DiceRoll(expression: this, terms: rolled, total: total);
  }

  DiceTermRoll _rollDice(DiceRollTerm term, Random rng) {
    final rolls = [
      for (var i = 0; i < term.count; i++) rng.nextInt(term.sides) + 1,
    ];

    // Über Indizes sortieren statt über die Werte: die Reihenfolge, in der
    // die Würfel gefallen sind, bleibt in [rolls] erhalten — im Log soll
    // stehen, was auf dem Tisch lag, nicht eine sortierte Fassung.
    final order = [for (var i = 0; i < rolls.length; i++) i]
      ..sort((a, b) => rolls[b].compareTo(rolls[a]));

    final kept = List<bool>.filled(rolls.length, term.keepMode == KeepMode.all);
    final n = term.keepCount.clamp(0, rolls.length);

    switch (term.keepMode) {
      case KeepMode.all:
        break;
      case KeepMode.keepHighest:
        for (final index in order.take(n)) {
          kept[index] = true;
        }
      case KeepMode.keepLowest:
        for (final index in order.reversed.take(n)) {
          kept[index] = true;
        }
      case KeepMode.dropHighest:
        kept.fillRange(0, kept.length, true);
        for (final index in order.take(n)) {
          kept[index] = false;
        }
      case KeepMode.dropLowest:
        kept.fillRange(0, kept.length, true);
        for (final index in order.reversed.take(n)) {
          kept[index] = false;
        }
    }

    var value = 0;
    for (var i = 0; i < rolls.length; i++) {
      if (kept[i]) value += rolls[i];
    }

    return DiceTermRoll(
      notation: term.notation,
      negated: term.negated,
      rolls: rolls,
      kept: kept,
      value: value,
    );
  }
}

/// Das Ergebnis eines Terms.
class DiceTermRoll {
  const DiceTermRoll({
    required this.notation,
    required this.negated,
    required this.rolls,
    required this.kept,
    required this.value,
  });

  final String notation;
  final bool negated;

  /// Alle geworfenen Augen, in Wurfreihenfolge. Leer bei Konstanten.
  final List<int> rolls;

  /// Parallel zu [rolls]: ob der Würfel gezählt hat.
  final List<bool> kept;

  /// Summe der zählenden Würfel, ohne Vorzeichen.
  final int value;

  /// Die Würfel, die gezählt haben.
  List<int> get keptRolls => [
    for (var i = 0; i < rolls.length; i++)
      if (kept[i]) rolls[i],
  ];

  /// Ob mindestens ein Würfel weggefallen ist.
  bool get hasDropped => kept.contains(false);
}

/// Das Ergebnis eines ganzen Ausdrucks.
class DiceRoll {
  const DiceRoll({
    required this.expression,
    required this.terms,
    required this.total,
  });

  final DiceExpression expression;
  final List<DiceTermRoll> terms;
  final int total;

  /// Alle geworfenen Augen über alle Terme — für „höchster Würfel"-Regeln.
  List<int> get allRolls => [for (final term in terms) ...term.rolls];

  /// Eine Zeile für das Play-Log, etwa `4d6kh3: [5, 3, ~1~, 6] = 14`.
  ///
  /// Weggefallene Würfel in Tilden statt gelöscht: wer einen Pool wirft,
  /// will sehen, was danebenlag.
  String describe() {
    final parts = <String>[];
    for (final term in terms) {
      if (term.rolls.isEmpty) {
        parts.add(term.notation);
        continue;
      }
      final shown = [
        for (var i = 0; i < term.rolls.length; i++)
          term.kept[i] ? '${term.rolls[i]}' : '~${term.rolls[i]}~',
      ];
      parts.add('${term.notation}: [${shown.join(', ')}]');
    }
    return '${parts.join('  ')} = $total';
  }
}

// ── Parser ──────────────────────────────────────────────────────────────────

class _DiceParser {
  _DiceParser(this.source);

  final String source;
  int _pos = 0;

  DiceExpression parse() {
    final terms = <DiceTerm>[];
    var negated = false;

    _skipSpace();
    if (_peek() == '+' || _peek() == '-') {
      negated = _next() == '-';
      _skipSpace();
    }

    while (true) {
      terms.add(_term(negated));
      _skipSpace();
      if (_atEnd) break;

      final sign = _peek();
      if (sign != '+' && sign != '-') {
        throw DiceParseException('Erwartet + oder -', source, _pos);
      }
      negated = _next() == '-';
      _skipSpace();
      if (_atEnd) {
        throw DiceParseException(
          'Ausdruck endet nach dem Vorzeichen',
          source,
          _pos,
        );
      }
    }

    if (terms.isEmpty) {
      throw DiceParseException('Leerer Ausdruck', source, 0);
    }
    return DiceExpression(terms: terms, source: source);
  }

  DiceTerm _term(bool negated) {
    final start = _pos;
    final count = _optionalInt();

    if (_peekLower() != 'd') {
      if (count == null) {
        throw DiceParseException('Zahl oder Würfel erwartet', source, start);
      }
      return ConstantTerm(value: count, negated: negated);
    }
    _next(); // 'd'

    final sides = _optionalInt();
    if (sides == null) {
      throw DiceParseException('Seitenzahl fehlt nach „d"', source, _pos);
    }
    if (sides < 1 || sides > kMaxDiceSides) {
      throw DiceParseException(
        'Seitenzahl muss zwischen 1 und $kMaxDiceSides liegen',
        source,
        _pos,
      );
    }

    // `d20` heißt 1d20 — die gebräuchlichste Schreibweise überhaupt.
    final dice = count ?? 1;
    if (dice < 1 || dice > kMaxDiceCount) {
      throw DiceParseException(
        'Würfelzahl muss zwischen 1 und $kMaxDiceCount liegen',
        source,
        start,
      );
    }

    var mode = KeepMode.all;
    var keep = 1;
    final marker = _keepMarker();
    if (marker != null) {
      mode = marker;
      keep = _optionalInt() ?? 1;
      if (keep < 1) {
        throw DiceParseException('Anzahl muss mindestens 1 sein', source, _pos);
      }
      if (keep > dice) {
        throw DiceParseException(
          'Es sollen $keep von $dice Würfeln gewertet werden',
          source,
          _pos,
        );
      }
    }

    return DiceRollTerm(
      count: dice,
      sides: sides,
      negated: negated,
      keepMode: mode,
      keepCount: keep,
    );
  }

  /// Liest `kh`/`kl`/`dh`/`dl`, oder null.
  KeepMode? _keepMarker() {
    if (_pos + 1 >= source.length) return null;
    final two = source.substring(_pos, _pos + 2).toLowerCase();
    final mode = switch (two) {
      'kh' => KeepMode.keepHighest,
      'kl' => KeepMode.keepLowest,
      'dh' => KeepMode.dropHighest,
      'dl' => KeepMode.dropLowest,
      _ => null,
    };
    if (mode != null) _pos += 2;
    return mode;
  }

  int? _optionalInt() {
    final start = _pos;
    while (!_atEnd && _isDigit(source.codeUnitAt(_pos))) {
      _pos++;
    }
    if (_pos == start) return null;
    return int.parse(source.substring(start, _pos));
  }

  bool get _atEnd => _pos >= source.length;
  String? _peek() => _atEnd ? null : source[_pos];
  String? _peekLower() => _peek()?.toLowerCase();
  String _next() => source[_pos++];

  void _skipSpace() {
    while (!_atEnd && (source[_pos] == ' ' || source[_pos] == '\t')) {
      _pos++;
    }
  }

  static bool _isDigit(int code) => code >= 0x30 && code <= 0x39;
}
