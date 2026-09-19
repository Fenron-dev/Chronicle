// Datei: chronicle/lib/app/shell/nav_panel.dart
//
// ZWECK: Linkes Panel — Bereichswechsel oben, Navigations-Baum darunter.
//
// STAND: Der Baum ist in Schritt 2 ein Platzhalter. Er wird ab Schritt 3 aus
//        dem Vault-Dateibaum gespeist.
//
// SCHRITT: 2

import 'package:flutter/material.dart';

import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
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
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Noch kein Vault geöffnet.\n'
                  'Der Navigations-Baum erscheint ab Schritt 3.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ),
            ),
          ),
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
