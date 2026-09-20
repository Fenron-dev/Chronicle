// Datei: chronicle/lib/domain/roll_engine/oracle_table.dart
//
// ZWECK: „Alles ist eine Tabelle" (Konzept §4.4). Vier Arten —
//        uniform, weighted, dice, deck — plus rekursive Subtabellen.
//
// WARUM EIN MODELL FÜR ALLE VIER: Ein Orakel, eine Zufallstabelle, ein
//        Generator und ein Kartendeck unterscheiden sich nur darin, WIE ein
//        Eintrag gewählt wird. Vier getrennte Typen hätten vier Parser, vier
//        Editoren und vier Importwege nach sich gezogen — und das Modell von
//        OracleVault, aus dem importiert wird, kennt diese Trennung nicht.
//
// SUBTABELLEN MIT ZYKLUS-ERKENNUNG: Ein Generator ruft Tabellen auf, die
//        Tabellen aufrufen. Zeigt eine davon auf sich zurück, läuft die App
//        ohne Erkennung bis zum Stapelüberlauf — beim Schreiben eigener
//        Tabellen ist das kein Randfall, sondern der zweite Nachmittag.
//
// REINE DART-LOGIK ohne Flutter-Import (CLAUDE.md §7).
//
// SIEHE: Konzept §4.4, Skill `vault-format`
// SCHRITT: 6

import 'dart:math';

import 'dice.dart';

/// Wie ein Eintrag gewählt wird.
enum TableKind {
  /// Gleichverteilt.
  uniform,

  /// Nach `weight` gewichtet.
  weighted,

  /// Über einen Würfelwurf und `range`-Angaben — `2d6` mit 2–12.
  dice,

  /// Ziehen ohne Zurücklegen, mit Hand und Ablage.
  deck;

  static TableKind? tryParse(Object? raw) {
    final text = raw?.toString().trim().toLowerCase();
    for (final value in TableKind.values) {
      if (value.name == text) return value;
    }
    return null;
  }
}

/// Ein Tabelleneintrag.
class TableEntry {
  const TableEntry({
    required this.text,
    this.weight = 1,
    this.min,
    this.max,
    this.subtable,
  });

  /// Der Text. Darf `[Tabelle]`-Platzhalter enthalten, die beim Würfeln
  /// aufgelöst werden (Konzept §4.4, „Templated Generators").
  final String text;

  /// Gewicht bei [TableKind.weighted]. Muss > 0 sein, sonst ist der Eintrag
  /// unerreichbar.
  final int weight;

  /// Trefferbereich bei [TableKind.dice], einschließlich.
  final int? min;
  final int? max;

  /// Statt [text]: auf dieser Tabelle weiterwürfeln.
  final String? subtable;

  bool covers(int value) =>
      min != null && max != null && value >= min! && value <= max!;
}

/// Eine Tabelle, ein Orakel oder ein Deck.
class OracleTable {
  const OracleTable({
    required this.id,
    required this.title,
    required this.kind,
    required this.entries,
    this.dice,
    this.reversible = false,
  });

  final String id;
  final String title;
  final TableKind kind;
  final List<TableEntry> entries;

  /// Der Würfelausdruck bei [TableKind.dice], etwa `2d6`.
  final String? dice;

  /// Tarot und ähnliche Decks kennen umgekehrte Karten.
  final bool reversible;

  /// Nachschlagename für Subtabellen-Verweise.
  String get lookupKey => title.toLowerCase();
}

/// Eine Tabelle verweist im Kreis auf sich selbst.
///
/// Typisiert, damit das UI den Pfad anzeigen kann, statt „Stack overflow".
class CycleDetectedException implements Exception {
  const CycleDetectedException(this.path);

  /// Die Aufrufkette bis zum Zyklus, in Reihenfolge.
  final List<String> path;

  String get message =>
      'Die Tabellen verweisen im Kreis: ${path.join(' → ')}. '
      'Eine davon muss den Kreis unterbrechen.';

  @override
  String toString() => 'CycleDetectedException(${path.join(' → ')})';
}

/// Eine Tabelle ist nicht auswürfelbar — leer, ohne Gewichte, ohne Bereiche.
class TableRollException implements Exception {
  const TableRollException(this.message, this.table);

  final String message;
  final String table;

  @override
  String toString() => 'TableRollException($message in "$table")';
}

/// Ein Schritt der Auflösung — für die Provenienz im Play-Log.
class TableRollStep {
  const TableRollStep({
    required this.table,
    required this.text,
    this.dice,
    this.index,
  });

  final String table;

  /// Der gewählte Eintrag, noch mit Platzhaltern.
  final String text;

  /// Der Wurf, falls die Tabelle über Würfel entscheidet.
  final DiceRoll? dice;

  /// Position des Eintrags — bei Decks die Karte.
  final int? index;
}

/// Das Ergebnis eines Tabellenwurfs.
class TableRollResult {
  const TableRollResult({required this.text, required this.steps});

  /// Der fertige Text, alle Platzhalter aufgelöst.
  final String text;

  /// Wie es zustande kam, äußerster Schritt zuerst. Im Play-Log steht damit
  /// nicht nur das Ergebnis, sondern der Weg dorthin (Konzept §4.1:
  /// „mit Zeitstempel und Provenienz").
  final List<TableRollStep> steps;
}

/// Würfelt auf Tabellen und löst Subtabellen auf.
class TableRoller {
  const TableRoller({required this.tables, this.maxDepth = 12});

  /// Alle bekannten Tabellen, nach [OracleTable.lookupKey].
  final Map<String, OracleTable> tables;

  /// Obergrenze der Schachtelung. Greift, wenn eine Kette zwar keinen Zyklus
  /// bildet, aber trotzdem ausufert.
  final int maxDepth;

  /// Matcht `[Tabellenname]` im Eintragstext.
  ///
  /// Keine eckigen Klammern im Namen, damit ein `[[Wikilink]]` nicht
  /// versehentlich als Platzhalter gelesen wird.
  static final RegExp _placeholder = RegExp(r'\[([^\[\]\n]+)\]');

  /// Würfelt auf [table].
  TableRollResult roll(OracleTable table, [Random? random]) {
    final rng = random ?? Random();
    final steps = <TableRollStep>[];
    final text = _resolve(table, rng, steps, <String>[]);
    return TableRollResult(text: text, steps: steps);
  }

  String _resolve(
    OracleTable table,
    Random rng,
    List<TableRollStep> steps,
    List<String> stack,
  ) {
    final key = table.lookupKey;
    if (stack.contains(key)) {
      throw CycleDetectedException([...stack, key]);
    }
    if (stack.length >= maxDepth) {
      throw CycleDetectedException([...stack, key]);
    }

    if (table.entries.isEmpty) {
      throw TableRollException('Die Tabelle hat keine Einträge', table.title);
    }

    final (entry, index, dice) = _pick(table, rng);
    steps.add(
      TableRollStep(
        table: table.title,
        text: entry.subtable ?? entry.text,
        dice: dice,
        index: index,
      ),
    );

    final nested = [...stack, key];

    // Ein Eintrag, der auf eine andere Tabelle zeigt, ERSETZT sich durch
    // deren Ergebnis.
    if (entry.subtable case final String name) {
      final target = tables[name.toLowerCase()];
      if (target == null) {
        // Fehlende Tabelle bleibt als Text stehen, statt den Wurf zu
        // verwerfen — beim Bauen eigener Tabellen ist der Verweis oft vor
        // dem Ziel da (dieselbe Haltung wie bei Wikilinks).
        return '[$name?]';
      }
      return _resolve(target, rng, steps, nested);
    }

    return _expand(entry.text, rng, steps, nested);
  }

  /// Ersetzt `[Tabelle]`-Platzhalter im Text.
  String _expand(
    String text,
    Random rng,
    List<TableRollStep> steps,
    List<String> stack,
  ) => text.replaceAllMapped(_placeholder, (match) {
    final name = match.group(1)!.trim();
    final target = tables[name.toLowerCase()];
    if (target == null) return match.group(0)!;
    return _resolve(target, rng, steps, stack);
  });

  /// Wählt einen Eintrag nach der Art der Tabelle.
  (TableEntry, int, DiceRoll?) _pick(OracleTable table, Random rng) {
    switch (table.kind) {
      case TableKind.uniform:
      case TableKind.deck:
        // Ein Deck OHNE Zustand verhält sich wie eine Gleichverteilung.
        // Ziehen ohne Zurücklegen braucht eine Hand, die zwischen Würfen
        // bestehen bleibt — dafür gibt es [DeckState].
        final index = rng.nextInt(table.entries.length);
        return (table.entries[index], index, null);

      case TableKind.weighted:
        final total = table.entries.fold(
          0,
          (sum, e) => sum + (e.weight > 0 ? e.weight : 0),
        );
        if (total <= 0) {
          throw TableRollException(
            'Alle Gewichte sind 0 — kein Eintrag wäre erreichbar',
            table.title,
          );
        }
        var pick = rng.nextInt(total);
        for (final (index, entry) in table.entries.indexed) {
          if (entry.weight <= 0) continue;
          if (pick < entry.weight) return (entry, index, null);
          pick -= entry.weight;
        }
        // Unerreichbar, solange total stimmt — aber ein Fallback ist
        // billiger als ein Absturz mitten im Spiel.
        return (table.entries.last, table.entries.length - 1, null);

      case TableKind.dice:
        final notation = table.dice;
        if (notation == null || notation.trim().isEmpty) {
          throw TableRollException(
            'Würfeltabelle ohne `dice:`-Angabe',
            table.title,
          );
        }
        final roll = DiceExpression.parse(notation).roll(rng);
        for (final (index, entry) in table.entries.indexed) {
          if (entry.covers(roll.total)) return (entry, index, roll);
        }
        throw TableRollException(
          'Kein Eintrag deckt ${roll.total} ab — die Bereiche haben eine Lücke',
          table.title,
        );
    }
  }
}

// ── Decks ───────────────────────────────────────────────────────────────────

/// Eine gezogene Karte.
class DrawnCard {
  const DrawnCard({required this.index, required this.reversed});

  /// Position in [OracleTable.entries].
  final int index;

  /// Umgekehrt gezogen (Tarot).
  final bool reversed;

  Map<String, dynamic> toJson() => {'index': index, 'reversed': reversed};

  factory DrawnCard.fromJson(Map<String, dynamic> json) => DrawnCard(
    index: (json['index'] as num?)?.toInt() ?? 0,
    reversed: json['reversed'] as bool? ?? false,
  );
}

/// Der Zustand eines Decks: Stapel, Hand, Ablage.
///
/// UNVERÄNDERLICH, und jede Aktion liefert einen neuen Zustand. Das ist kein
/// Stilmittel: der Deckzustand gehört in die Partie-Datei (sonst überlebt er
/// den nächsten Index-Rebuild nicht, CLAUDE.md §2.5), und ein veränderlicher
/// Zustand ließe sich nicht verlässlich serialisieren, während gezogen wird.
class DeckState {
  const DeckState({
    required this.drawPile,
    this.hand = const [],
    this.discard = const [],
  });

  /// Noch im Stapel, oberste Karte zuletzt.
  final List<int> drawPile;

  /// Aufgedeckt vor dem Spieler.
  final List<DrawnCard> hand;

  /// Abgelegt.
  final List<DrawnCard> discard;

  /// Ein frisch gemischtes Deck über alle Einträge von [table].
  factory DeckState.shuffled(OracleTable table, [Random? random]) {
    final rng = random ?? Random();
    final pile = [for (var i = 0; i < table.entries.length; i++) i]
      ..shuffle(rng);
    return DeckState(drawPile: pile);
  }

  bool get isEmpty => drawPile.isEmpty;
  int get remaining => drawPile.length;

  /// Zieht [count] Karten auf die Hand.
  ///
  /// Ist der Stapel leer, wird NICHT automatisch neu gemischt: ein Tarot-Deck,
  /// das sich unbemerkt nachfüllt, macht jede Aussage über „schon gezogen"
  /// wertlos. Der Aufrufer entscheidet und sieht es an [remaining].
  DeckState draw(int count, {Random? random, bool allowReversed = false}) {
    final rng = random ?? Random();
    final pile = [...drawPile];
    final drawn = <DrawnCard>[];

    for (var i = 0; i < count && pile.isNotEmpty; i++) {
      drawn.add(
        DrawnCard(
          index: pile.removeLast(),
          reversed: allowReversed && rng.nextBool(),
        ),
      );
    }

    return DeckState(
      drawPile: pile,
      hand: [...hand, ...drawn],
      discard: discard,
    );
  }

  /// Legt die ganze Hand ab.
  DeckState discardHand() => DeckState(
    drawPile: drawPile,
    hand: const [],
    discard: [...discard, ...hand],
  );

  /// Mischt Hand und Ablage zurück in den Stapel.
  DeckState reshuffle([Random? random]) {
    final rng = random ?? Random();
    final pile = [
      ...drawPile,
      ...hand.map((c) => c.index),
      ...discard.map((c) => c.index),
    ]..shuffle(rng);
    return DeckState(drawPile: pile);
  }

  Map<String, dynamic> toJson() => {
    'drawPile': drawPile,
    'hand': [for (final card in hand) card.toJson()],
    'discard': [for (final card in discard) card.toJson()],
  };

  factory DeckState.fromJson(Map<String, dynamic> json) => DeckState(
    drawPile: _ints(json['drawPile']),
    hand: _cards(json['hand']),
    discard: _cards(json['discard']),
  );

  static List<int> _ints(Object? raw) => raw is List
      ? [
          for (final item in raw)
            if (item is num) item.toInt(),
        ]
      : const [];

  static List<DrawnCard> _cards(Object? raw) => raw is List
      ? [
          for (final item in raw)
            if (item is Map<String, dynamic>) DrawnCard.fromJson(item),
        ]
      : const [];
}
