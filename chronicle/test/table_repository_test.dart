// Datei: chronicle/test/table_repository_test.dart
//
// ZWECK: Tabellendateien einlesen — Frontmatter auf das Modell abbilden und
//        das tun, was bei einer kaputten Datei richtig ist: überspringen,
//        nicht abstürzen.
//
// SCHRITT: 6

import 'dart:io';

import 'package:chronicle/data/vault/table_repository.dart';
import 'package:chronicle/domain/roll_engine/oracle_table.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const repo = TableRepository();
  late Directory vault;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('chronicle-tables-');
    await Directory(p.join(vault.path, 'systems/ironsworn/tables'))
        .create(recursive: true);
  });

  tearDown(() => vault.delete(recursive: true));

  Future<String> write(String name, String content) async {
    final relPath = 'systems/ironsworn/tables/$name.md';
    await File(p.join(vault.path, relPath)).writeAsString(content);
    return relPath;
  }

  test('liest eine Würfeltabelle vollständig', () async {
    final relPath = await write('orakel', '''
---
id: 018f-aaa
type: table
title: Frage-Orakel
table-type: dice
dice: 2d6
---

# Frage-Orakel

- 2-6 | Nein
- 7-9 | Ja, aber
- 10-12 | Ja, und
''');

    final loaded = (await repo.load(vault.path, relPath))!;
    expect(loaded.table.title, 'Frage-Orakel');
    expect(loaded.table.kind, TableKind.dice);
    expect(loaded.table.dice, '2d6');
    expect(loaded.table.entries, hasLength(3));
    expect(loaded.systemSlug, 'ironsworn');
    // Die Bereiche decken 2–12 lückenlos ab.
    expect(loaded.problems, isEmpty);
  });

  test('meldet eine Lücke, ohne die Tabelle zu verweigern', () async {
    final relPath = await write('lueckig', '''
---
id: 018f-bbb
type: table
title: Lückig
table-type: dice
dice: 2d6
---

- 2-6 | Nein
- 10-12 | Ja
''');

    final loaded = (await repo.load(vault.path, relPath))!;
    expect(loaded.isUsable, isTrue, reason: 'unfertig ist nicht kaputt');
    expect(loaded.problems.single, contains('7, 8, 9'));
  });

  test('`type: deck` reicht — table-type darf fehlen', () async {
    final relPath = await write('tarot', '''
---
id: 018f-ccc
type: deck
title: Tarot
reversible: true
---

- Der Narr
- Der Turm
''');

    final loaded = (await repo.load(vault.path, relPath))!;
    expect(loaded.table.kind, TableKind.deck);
    expect(loaded.table.reversible, isTrue);
  });

  test('ohne table-type gilt uniform', () async {
    final relPath = await write('schlicht', '''
---
id: 018f-ddd
type: table
title: Schlicht
---

- Eins
- Zwei
''');

    final loaded = (await repo.load(vault.path, relPath))!;
    expect(loaded.table.kind, TableKind.uniform);
  });

  test('ohne title gilt der Dateiname', () async {
    final relPath = await write('namenlos', '''
---
id: 018f-eee
type: table
---

- Eins
''');

    final loaded = (await repo.load(vault.path, relPath))!;
    expect(loaded.table.title, 'namenlos');
  });

  test('eine fehlende Datei ergibt null statt einer Ausnahme', () async {
    expect(await repo.load(vault.path, 'systems/x/tables/weg.md'), isNull);
  });

  test('loadAll überspringt, was nicht lesbar ist', () async {
    final gut = await write('gut', '''
---
id: 018f-fff
type: table
title: Gut
---

- Eins
''');

    // Eine einzelne kaputte Tabelle darf nicht den ganzen Roller lahmlegen.
    final tables = await repo.loadAll(vault.path, [
      gut,
      'systems/ironsworn/tables/gibtsnicht.md',
    ]);
    expect(tables, hasLength(1));
    expect(tables.single.table.title, 'Gut');
  });

  test('eine Tabelle ohne Einträge ist nicht benutzbar', () async {
    final relPath = await write('leer', '''
---
id: 018f-ggg
type: table
title: Leer
---

Nur erklärender Text, keine Liste.
''');

    final loaded = (await repo.load(vault.path, relPath))!;
    expect(loaded.isUsable, isFalse);
    expect(loaded.problems, isNotEmpty);
  });
}
