// Datei: chronicle/lib/features/roller/roller_panel.dart
//
// ZWECK: Der Roller im rechten Kontext-Panel (Konzept §7.1) — Würfelfeld und
//        die Tabellen des Systems.
//
// JEDER WURF LANDET IM PLAY-LOG, nicht in diesem Panel. Das Panel zeigt nur
//        den letzten Wurf als Quittung; die Aufzeichnung ist das Journal
//        (Konzept §4.1). Eine zweite Wurf-Historie daneben würde sofort von
//        der ersten abweichen.
//
// SCHRITT: 6

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
import '../../data/vault/table_repository.dart';
import '../../data/vault/vault_providers.dart';
import '../../domain/roll_engine/dice.dart';
import '../../domain/roll_engine/oracle_table.dart';
import 'roller_providers.dart';

class RollerPanel extends ConsumerStatefulWidget {
  const RollerPanel({super.key});

  @override
  ConsumerState<RollerPanel> createState() => _RollerPanelState();
}

class _RollerPanelState extends ConsumerState<RollerPanel> {
  late final TextEditingController _input = TextEditingController(
    text: ref.read(lastDiceExpressionProvider),
  );

  /// Die letzte Quittung — Ergebnis oder Fehler.
  String? _result;
  bool _failed = false;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasGame = ref.watch(activeGameProvider).value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.typography.formatHeading('Roller'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: palette.textHeading,
            letterSpacing: context.typography.headingLetterSpacing,
          ),
        ),
        const SizedBox(height: 8),

        if (!hasGame)
          Text(
            'Ohne laufende Partie gibt es kein Log, in das ein Wurf gehört.',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.textMuted),
          )
        else ...[
          _DiceField(controller: _input, enabled: !_busy, onRoll: _rollDice),
          if (_result != null) ...[
            const SizedBox(height: 8),
            Text(
              _result!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontFamily: _failed ? null : context.typography.mono,
                color: _failed ? palette.danger : palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _TableList(enabled: !_busy, onRoll: _rollTable),
        ],
      ],
    );
  }

  Future<void> _rollDice() async {
    final expression = _input.text.trim();
    if (expression.isEmpty) return;

    setState(() => _busy = true);
    try {
      final roll = await ref.read(rollerActionsProvider).rollDice(expression);
      if (!mounted) return;
      setState(() {
        _result = roll.describe();
        _failed = false;
      });
    } on DiceParseException catch (error) {
      // Nutzerfehler: im Feld melden, nicht ins Journal schreiben.
      if (!mounted) return;
      setState(() {
        _result = error.message;
        _failed = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rollTable(VaultTable table) async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(rollerActionsProvider).rollTable(table);
      if (!mounted) return;
      setState(() {
        _result = result.text;
        _failed = false;
      });
    } on CycleDetectedException catch (error) {
      if (!mounted) return;
      setState(() {
        _result = error.message;
        _failed = true;
      });
    } on TableRollException catch (error) {
      if (!mounted) return;
      setState(() {
        _result = error.message;
        _failed = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _DiceField extends StatelessWidget {
  const _DiceField({
    required this.controller,
    required this.enabled,
    required this.onRoll,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            style: TextStyle(fontFamily: context.typography.mono, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '2d6+1, 4d6kh3, d20',
            ),
            onSubmitted: (_) => onRoll(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: enabled ? onRoll : null,
          child: const Text('Würfeln'),
        ),
      ],
    );
  }
}

class _TableList extends ConsumerWidget {
  const _TableList({required this.enabled, required this.onRoll});

  final bool enabled;
  final ValueChanged<VaultTable> onRoll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tables = ref.watch(systemTablesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.typography.formatHeading('Tabellen'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: palette.textHeading,
            letterSpacing: context.typography.headingLetterSpacing,
          ),
        ),
        const SizedBox(height: 6),
        switch (tables) {
          AsyncData(:final value) when value.isEmpty => Text(
            'Das System bringt noch keine Tabellen mit. Sie liegen unter '
            'systems/<system>/tables/ und sind gewöhnliche Markdown-Listen.',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.textMuted),
          ),
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final table in value)
                _TableTile(
                  table: table,
                  enabled: enabled && table.isUsable,
                  onRoll: () => onRoll(table),
                ),
            ],
          ),
          AsyncError(:final error) => Text(
            '$error',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.danger),
          ),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        },
      ],
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.table,
    required this.enabled,
    required this.onRoll,
  });

  final VaultTable table;
  final bool enabled;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;
    final problems = table.problems;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: palette.surfaceSunken,
        borderRadius: skin.radius(RadiusToken.chip),
        child: InkWell(
          borderRadius: skin.radius(RadiusToken.chip),
          onTap: enabled ? onRoll : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  table.table.kind == TableKind.deck
                      ? Icons.style_outlined
                      : Icons.casino_outlined,
                  size: 15,
                  color: enabled ? palette.accent : palette.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.table.title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        _subtitle(table),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.textMuted),
                      ),
                    ],
                  ),
                ),
                // Eine unfertige Tabelle wird gezeigt, nicht versteckt: sonst
                // sucht der Nutzer den Fehler im Vault statt in der Tabelle.
                if (problems.isNotEmpty)
                  Tooltip(
                    message: problems.join('\n'),
                    child: Icon(
                      Icons.error_outline,
                      size: 15,
                      color: palette.warning,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _subtitle(VaultTable table) {
    final parts = <String>[
      table.table.kind.name,
      if (table.table.dice case final String dice) dice,
      '${table.table.entries.length} Einträge',
    ];
    return parts.join(' · ');
  }
}
