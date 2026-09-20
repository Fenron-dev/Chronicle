// Datei: chronicle/lib/domain/roll_engine/table_markdown.dart
//
// ZWECK: Tabellen-Einträge aus dem Markdown-Rumpf lesen und zurückschreiben.
//
// DAS FORMAT IST EINE GEWÖHNLICHE LISTE. Eine Zufallstabelle soll in
//        Obsidian und in jedem Texteditor aussehen wie eine Zufallstabelle —
//        und von Hand erweiterbar sein, ohne Chronicle zu öffnen. Deshalb
//        keine eingebettete JSON-Struktur, sondern Listeneinträge mit einer
//        kleinen, optionalen Annotation vor einem `|`:
//
//          - 2-4 | Dichter Nebel zieht auf      ← Trefferbereich (dice)
//          - 7 | Ein einzelner Wert             ← Bereich 7–7
//          - x3 | Wegelagerer                   ← Gewicht 3 (weighted)
//          - Eine leere Straße                  ← ohne Annotation: Gewicht 1
//          - => Namensliste                     ← ganzer Eintrag aus anderer Tabelle
//          - [Kultur] [Epitheton]               ← Platzhalter im Text
//
// WARUM `|` ALS TRENNER: Es kommt in Tabellentexten praktisch nicht vor, ist
//        auf jeder Tastatur erreichbar, und ein Eintrag OHNE Trenner bleibt
//        gültig. Wer die Annotation weglässt, bekommt einen Eintrag mit
//        Gewicht 1 — das ist der häufigste Fall und braucht keine Syntax.
//
// REINE DART-LOGIK ohne Flutter-Import (CLAUDE.md §7).
//
// SIEHE: Skill `vault-format`, Konzept §4.4
// SCHRITT: 6

import 'dice.dart';
import 'oracle_table.dart';

/// Eine Zeile, die ein Listeneintrag sein könnte: `- …`, `* …`, `1. …`.
final RegExp _listItem = RegExp(r'^\s*(?:[-*+]|\d+[.)])\s+(.*)$');

/// `2-4 |`, `2–4 |` (Gedankenstrich), `7 |`, `x3 |`, `3x |`.
///
/// Der Gedankenstrich ist kein Luxus: Textverarbeitungen und Obsidians
/// Autokorrektur machen aus `2-4` gern `2–4`, und der Eintrag darf dadurch
/// nicht unbrauchbar werden.
final RegExp _annotation = RegExp(
  r'^\s*(?:'
  r'(\d+)\s*[-–—]\s*(\d+)' // Gruppe 1/2: Bereich
  r'|(\d+)' // Gruppe 3: einzelner Wert
  r'|[xX]\s*(\d+)|(\d+)\s*[xX]' // Gruppe 4/5: Gewicht
  r')\s*\|\s*(.*)$',
);

/// `=> Tabelle` oder `→ Tabelle` — der Eintrag kommt aus einer anderen Tabelle.
final RegExp _subtable = RegExp(r'^\s*(?:=>|→)\s*(.+)$');

/// Liest die Einträge aus [body].
///
/// Alles, was keine Listenzeile ist, wird übersprungen: Überschriften,
/// erklärender Text und Leerzeilen gehören in eine handgepflegte Tabelle und
/// dürfen sie nicht unlesbar machen.
List<TableEntry> parseTableEntries(String body) {
  final entries = <TableEntry>[];

  for (final line in body.split('\n')) {
    final item = _listItem.firstMatch(line);
    if (item == null) continue;

    final content = item.group(1)!.trim();
    if (content.isEmpty) continue;

    entries.add(_entry(content));
  }

  return entries;
}

TableEntry _entry(String content) {
  var text = content;
  int? min;
  int? max;
  var weight = 1;

  final annotated = _annotation.firstMatch(content);
  if (annotated != null) {
    final rangeFrom = annotated.group(1);
    final single = annotated.group(3);
    final weightValue = annotated.group(4) ?? annotated.group(5);

    if (rangeFrom != null) {
      min = int.parse(rangeFrom);
      max = int.parse(annotated.group(2)!);
      // Verdrehte Bereiche (`9-5`) drehen wir um, statt den Eintrag zu
      // verwerfen — der Tippfehler ist offensichtlich, die Absicht auch.
      if (min > max) (min, max) = (max, min);
    } else if (single != null) {
      min = int.parse(single);
      max = min;
    } else if (weightValue != null) {
      weight = int.parse(weightValue);
    }
    text = annotated.group(6)!.trim();
  }

  final sub = _subtable.firstMatch(text);
  if (sub != null) {
    return TableEntry(
      text: '',
      weight: weight,
      min: min,
      max: max,
      subtable: sub.group(1)!.trim(),
    );
  }

  return TableEntry(text: text, weight: weight, min: min, max: max);
}

/// Schreibt Einträge zurück in Listenform.
///
/// Die Annotation wird nur gesetzt, wenn sie etwas aussagt — ein Gewicht von
/// 1 überall hinzuschreiben bläht die Datei auf und macht sie unleserlicher,
/// ohne etwas zu bedeuten.
String serializeTableEntries(List<TableEntry> entries) {
  final buffer = StringBuffer();
  for (final entry in entries) {
    buffer.write('- ');
    if (entry.min != null && entry.max != null) {
      buffer.write(
        entry.min == entry.max
            ? '${entry.min} | '
            : '${entry.min}-${entry.max} | ',
      );
    } else if (entry.weight != 1) {
      buffer.write('x${entry.weight} | ');
    }
    buffer.write(entry.subtable != null ? '=> ${entry.subtable}' : entry.text);
    buffer.write('\n');
  }
  return buffer.toString();
}

/// Prüft eine Tabelle auf Fehler, die erst beim Würfeln auffallen würden.
///
/// Bewusst als Liste von Meldungen statt einer Ausnahme: eine Tabelle mit
/// einer Lücke ist nicht kaputt, sie ist unfertig. Der Editor soll das
/// anzeigen, ohne das Öffnen zu verweigern.
List<String> validateTable(OracleTable table) {
  final problems = <String>[];

  if (table.entries.isEmpty) {
    problems.add('Die Tabelle hat keine Einträge.');
    return problems;
  }

  switch (table.kind) {
    case TableKind.uniform:
    case TableKind.deck:
      break;

    case TableKind.weighted:
      final total = table.entries.fold(
        0,
        (sum, e) => sum + (e.weight > 0 ? e.weight : 0),
      );
      if (total <= 0) {
        problems.add('Alle Gewichte sind 0 — kein Eintrag wäre erreichbar.');
      }

    case TableKind.dice:
      final notation = table.dice;
      if (notation == null || notation.trim().isEmpty) {
        problems.add('Es fehlt die `dice:`-Angabe, etwa `2d6`.');
        break;
      }
      final missing = <int>[];
      final (low, high) = _rangeOf(notation);
      for (var value = low; value <= high; value++) {
        if (!table.entries.any((e) => e.covers(value))) missing.add(value);
      }
      if (missing.isNotEmpty) {
        problems.add(
          'Kein Eintrag deckt ${missing.join(', ')} ab — '
          'ein Wurf darauf hätte kein Ergebnis.',
        );
      }
  }

  return problems;
}

/// Kleinster und größter möglicher Wurf eines Ausdrucks.
///
/// Bei einem Ausdruck, den der Parser nicht versteht, wird NICHTS gemeldet
/// statt geraten: der Fehler liegt dann in der `dice:`-Angabe, und eine
/// erfundene Lückenmeldung obendrauf würde nur vom eigentlichen Problem
/// ablenken.
(int, int) _rangeOf(String notation) {
  try {
    return DiceExpression.parse(notation).range;
  } on DiceParseException {
    return (1, 0); // leerer Bereich → keine Schleife, keine Meldung
  }
}
