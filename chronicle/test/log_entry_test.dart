// Datei: chronicle/test/log_entry_test.dart
//
// ZWECK: Das Dateiformat des Play-Logs. Reine Dart-Logik, deshalb billig und
//        gründlich testbar.
//
// WARUM GRÜNDLICH: Hier steht der eigentliche Spielverlauf. Ein Parser, der
//        einen Eintrag verschluckt, verliert, was jemand beim Spielen
//        geschrieben hat — und der Index kann ihn nicht rekonstruieren, weil
//        die Datei die Wahrheit ist.
//
// SCHRITT: 4

import 'package:chronicle/domain/log/entry_kind.dart';
import 'package:chronicle/domain/log/log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLogEntries', () {
    test('liest Kopf und Rumpf eines Eintrags', () {
      const body =
          '> [!entry] narration | 2026-09-19T20:14:03Z | id: abc-1\n'
          'Der Nebel über dem Moor wird dichter.';

      final entries = parseLogEntries(body);

      expect(entries, hasLength(1));
      expect(entries.single.id, 'abc-1');
      expect(entries.single.kind, EntryKind.narration);
      expect(entries.single.timestamp, DateTime.utc(2026, 9, 19, 20, 14, 3));
      expect(entries.single.text, 'Der Nebel über dem Moor wird dichter.');
    });

    test('trennt mehrere Einträge und behält die Reihenfolge', () {
      const body =
          '# Sitzung 1\n'
          '\n'
          '> [!entry] narration | 2026-09-19T20:14:03Z | id: a\n'
          'Erster Absatz.\n'
          '\n'
          'Zweiter Absatz desselben Eintrags.\n'
          '\n'
          '> [!entry] roll | 2026-09-19T20:15:11Z | id: b\n'
          '**2d6+1** → 10\n';

      final entries = parseLogEntries(body);

      expect(entries.map((e) => e.id), ['a', 'b']);
      expect(entries.first.text, contains('Zweiter Absatz'));
      expect(entries.last.kind, EntryKind.roll);
      expect(entries.last.text, '**2d6+1** → 10');
    });

    test('überspringt Text vor dem ersten Eintrag', () {
      const body = '# Sitzung 1\n\nEine Vorbemerkung.\n';
      expect(parseLogEntries(body), isEmpty);
      expect(logPreamble(body), '# Sitzung 1\n\nEine Vorbemerkung.');
    });

    test('toleriert von Hand veränderte Abstände', () {
      // Der Vault gehört dem Nutzer — die Datei darf im Editor bearbeitet
      // werden.
      const body =
          '>   [!entry]  oracle  |  2026-09-19T20:15:00Z  |  id:  x\n'
          'Ja, und.';

      final entries = parseLogEntries(body);
      expect(entries.single.id, 'x');
      expect(entries.single.kind, EntryKind.oracle);
    });

    test('behält einen unbekannten Typ als Meta-Eintrag', () {
      // Lieber sichtbar und falsch eingefärbt als verschwunden.
      const body = '> [!entry] zeitreise | 2026-09-19T20:15:00Z | id: y\nText.';

      final entries = parseLogEntries(body);
      expect(entries.single.kind, EntryKind.meta);
      expect(entries.single.text, 'Text.');
    });

    test('ignoriert einen gewöhnlichen Callout', () {
      const body = '> [!lore]\n> Etwas Hintergrund.\n';
      expect(parseLogEntries(body), isEmpty);
    });
  });

  group('Schreiben', () {
    test('übersteht einen Schreib-Lese-Zyklus unverändert', () {
      final original = LogEntry(
        id: '018f3c2a-7b41-7c3e-9d8a-2f10bb45e901',
        kind: EntryKind.plotbeat,
        timestamp: DateTime.utc(2026, 9, 19, 20, 19),
        text: 'Die Grenze ist verschoben worden.\n\nJemand wollte das.',
      );

      final reread = parseLogEntries(serializeLogEntry(original)).single;

      expect(reread.id, original.id);
      expect(reread.kind, original.kind);
      expect(reread.timestamp, original.timestamp);
      expect(reread.text, original.text);
    });

    test('hängt an, ohne Bestehendes zu verlieren', () {
      const body =
          '# Sitzung 1\n'
          '\n'
          '> [!entry] narration | 2026-09-19T20:14:03Z | id: a\n'
          'Erster.';

      final updated = appendLogEntry(
        body,
        LogEntry(
          id: 'b',
          kind: EntryKind.meta,
          timestamp: DateTime.utc(2026, 9, 19, 20, 30),
          text: 'Zweiter.',
        ),
      );

      final entries = parseLogEntries(updated);
      expect(entries.map((e) => e.id), ['a', 'b']);
      // Die Überschrift der Datei bleibt stehen.
      expect(logPreamble(updated), '# Sitzung 1');
    });

    test('baut den Rumpf aus einer geänderten Liste neu auf', () {
      final entries = [
        LogEntry(
          id: 'a',
          kind: EntryKind.narration,
          timestamp: DateTime.utc(2026),
          text: 'Eins.',
        ),
        LogEntry(
          id: 'b',
          kind: EntryKind.roll,
          timestamp: DateTime.utc(2026, 1, 2),
          text: 'Zwei.',
        ),
      ];

      final body = serializeLogBody('# Sitzung 1', entries);
      final reread = parseLogEntries(body);

      expect(reread.map((e) => e.id), ['a', 'b']);
      expect(logPreamble(body), '# Sitzung 1');
    });

    test('kommt mit einem leeren Rumpf zurecht', () {
      final entry = LogEntry(
        id: 'a',
        kind: EntryKind.narration,
        timestamp: DateTime.utc(2026),
        text: 'Erster Eintrag überhaupt.',
      );

      final body = appendLogEntry('', entry);
      expect(parseLogEntries(body).single.id, 'a');
    });
  });

  group('EntryKind', () {
    test('unterscheidet narrative von mechanischen Einträgen', () {
      // Steuert den Sichtbarkeits-Toggle und den Story-Export.
      expect(EntryKind.narration.isNarrative, isTrue);
      expect(EntryKind.plotbeat.isNarrative, isTrue);
      expect(EntryKind.roll.isNarrative, isFalse);
      expect(EntryKind.meta.isNarrative, isFalse);
    });
  });
}
