// Datei: chronicle/lib/app/shell/nav_panel.dart
//
// ZWECK: Linkes Panel — Bereichswechsel oben, Navigations-Baum darunter.
//
// STAND: Der Baum ist in Schritt 2 ein Platzhalter. Er wird ab Schritt 3 aus
//        dem Vault-Dateibaum gespeist.
//
// SCHRITT: 2

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
import '../../data/db/vault_note.dart';
import '../../data/vault/vault_providers.dart';
import '../../widgets/skin_divider.dart';
import 'destinations.dart';

class NavPanel extends StatelessWidget {
  const NavPanel({
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      color: palette.surfaceRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          for (var i = 0; i < kShellDestinations.length; i++)
            _DestinationTile(
              destination: kShellDestinations[i],
              selected: i == currentIndex,
              onTap: () => onSelect(i),
            ),
          const SkinDivider(indent: 12),
          const Expanded(child: _VaultTree()),
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? palette.accentSurface : Colors.transparent,
        borderRadius: skin.radius(RadiusToken.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: skin.radius(RadiusToken.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 18,
                  color: selected ? palette.accent : palette.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  destination.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? palette.accent : palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Der Navigations-Baum, gespeist aus dem Vault-Index.
///
/// Gruppiert nach Scope und Besitzer: ein System oder Game ist die Einheit,
/// in der Nutzer denken — nicht der Dateipfad.
class _VaultTree extends ConsumerWidget {
  const _VaultTree();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final notes = ref.watch(vaultNotesProvider);

    return notes.when(
      loading: () => const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Der Index konnte nicht gelesen werden. '
          'Die Dateien im Vault sind davon nicht betroffen — '
          'ein Neuaufbau behebt das.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: palette.textMuted),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Der Vault ist noch leer. Lege ein System unter systems/ '
              'und eine Partie unter games/ an — oder kopiere einen '
              'bestehenden Ordner hinein und baue den Index neu auf.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.textMuted),
            ),
          );
        }

        final groups = <String, List<VaultNote>>{};
        for (final note in rows) {
          final label = switch (note.scope) {
            'system' => 'System · \${note.ownerSlug ?? "?"}',
            'game' => 'Partie · \${note.ownerSlug ?? "?"}',
            _ => 'Vault',
          };
          groups.putIfAbsent(label, () => []).add(note);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            for (final entry in groups.entries)
              _TreeGroup(label: entry.key, notes: entry.value),
          ],
        );
      },
    );
  }
}

class _TreeGroup extends StatelessWidget {
  const _TreeGroup({required this.label, required this.notes});

  final String label;
  final List<VaultNote> notes;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            context.typography.formatHeading(label),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.textMuted),
          ),
        ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: Row(
              children: [
                Icon(_iconFor(note.type), size: 14, color: palette.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _iconFor(String type) => switch (type) {
    'log' => Icons.history_edu_outlined,
    'codex' => Icons.menu_book_outlined,
    'entity' => Icons.person_outline,
    'table' => Icons.casino_outlined,
    'deck' => Icons.style_outlined,
    'sheet' => Icons.assignment_outlined,
    'procedure' => Icons.checklist_outlined,
    'canvas' => Icons.dashboard_outlined,
    _ => Icons.description_outlined,
  };
}
