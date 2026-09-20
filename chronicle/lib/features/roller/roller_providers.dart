// Datei: chronicle/lib/features/roller/roller_providers.dart
//
// ZWECK: Würfeln und auf Tabellen würfeln — und das Ergebnis als Eintrag ins
//        Play-Log schreiben.
//
// DAS ROLL-LOG IST NICHT SEPARAT (Konzept §4.1): Würfe erscheinen formatiert
//        im Log, mit Zeitstempel und Provenienz. Ein eigenes Wurf-Fenster
//        neben dem Journal hätte genau die Reibung erzeugt, die das Projekt
//        vermeiden will — würfeln, deuten, schreiben soll ein Fluss sein.
//
// SCHRITT: 6

import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/vault/table_repository.dart';
import '../../data/vault/vault_providers.dart';
import '../../domain/log/entry_kind.dart';
import '../../domain/roll_engine/dice.dart';
import '../../domain/roll_engine/oracle_table.dart';

part 'roller_providers.g.dart';

@Riverpod(keepAlive: true)
TableRepository tableRepository(Ref ref) => const TableRepository();

/// Alle Tabellen und Decks des Systems, auf das die aktive Partie zeigt.
///
/// Über den Index gefunden, aus den Dateien gelesen: der Index kennt Titel
/// und Pfad, die Einträge stehen im Markdown (CLAUDE.md §2.5).
@riverpod
Future<List<VaultTable>> systemTables(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  final game = await ref.watch(activeGameProvider.future);
  if (session == null || game == null) return const [];

  final systems = await ref.watch(vaultSystemsProvider.future);
  String? slug;
  for (final system in systems) {
    if (system.id == game.systemId) {
      slug = system.slug;
      break;
    }
  }
  if (slug == null) return const [];

  final notes = [
    ...await session.database.notesOfType('table'),
    ...await session.database.notesOfType('deck'),
  ];
  final mine = notes.where((n) => n.ownerSlug == slug).toList();

  final tables = await ref
      .read(tableRepositoryProvider)
      .loadAll(session.vault.rootPath, mine.map((n) => n.relPath));

  tables.sort(
    (a, b) =>
        a.table.title.toLowerCase().compareTo(b.table.title.toLowerCase()),
  );
  return tables;
}

/// Der zuletzt eingegebene Würfelausdruck.
///
/// keepAlive, damit er einen Bereichswechsel überlebt: wer `2d6+1` wirft,
/// wirft es gleich nochmal.
@Riverpod(keepAlive: true)
class LastDiceExpression extends _$LastDiceExpression {
  @override
  String build() => '2d6';

  void remember(String value) => state = value;
}

/// Würfelaktionen.
@Riverpod(keepAlive: true)
RollerActions rollerActions(Ref ref) => RollerActions(ref);

class RollerActions {
  const RollerActions(this._ref);

  final Ref _ref;

  /// Wirft [expression] und schreibt das Ergebnis ins Play-Log.
  ///
  /// Wirft [DiceParseException] weiter: ein Tippfehler ist ein Nutzerfehler
  /// und gehört ins Eingabefeld gemeldet, nicht als Eintrag ins Journal.
  Future<DiceRoll> rollDice(String expression) async {
    final roll = DiceExpression.parse(expression).roll();
    _ref.read(lastDiceExpressionProvider.notifier).remember(expression);

    await _ref
        .read(logActionsProvider)
        .appendEntry(kind: EntryKind.roll, text: roll.describe());
    return roll;
  }

  /// Würfelt auf [table] und schreibt Ergebnis samt Weg ins Play-Log.
  Future<TableRollResult> rollTable(VaultTable table) async {
    final all = await _ref.read(systemTablesProvider.future);
    final roller = TableRoller(
      tables: {for (final entry in all) entry.table.lookupKey: entry.table},
    );

    final result = roller.roll(table.table, Random());

    // Ein Deck zieht Karten, eine Tabelle liefert ein Orakel — die beiden
    // bekommen im Log unterschiedliche Farben (Skill `chronicle-theme`).
    final kind = table.table.kind == TableKind.deck
        ? EntryKind.card
        : EntryKind.oracle;

    await _ref
        .read(logActionsProvider)
        .appendEntry(kind: kind, text: _describe(table, result));
    return result;
  }

  /// Formt den Eintrag: Ergebnis zuerst, Herkunft darunter.
  ///
  /// Die Zwischenschritte kommen nur mit, wenn es welche GAB — bei einer
  /// einfachen Tabelle wäre „Wetter → Wetter" nur Lärm.
  String _describe(VaultTable table, TableRollResult result) {
    final buffer = StringBuffer()
      ..writeln('**${table.table.title}** — ${result.text}');

    final dice = result.steps
        .map((step) => step.dice)
        .whereType<DiceRoll>()
        .toList();
    if (dice.isNotEmpty) {
      buffer.writeln();
      for (final roll in dice) {
        buffer.writeln(roll.describe());
      }
    }

    if (result.steps.length > 1) {
      buffer
        ..writeln()
        ..writeln('über ${result.steps.map((s) => s.table).join(' → ')}');
    }

    return buffer.toString().trimRight();
  }
}
