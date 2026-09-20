// Datei: chronicle/lib/app/shell/context_panel.dart
//
// ZWECK: Rechtes Panel — kontextuelle Werkzeuge (Konzept §7.1): KI-Companion,
//        Properties, Backlinks, Roller, aktive Clocks, laufende Procedure.
//
// STAND: Der Roller ist seit Schritt 6 echt. Die übrigen Abschnitte sind
//        benannte Platzhalter — bewusst schon da, weil sie im Theme-Test
//        zeigen, wie Karten und Trenner in jedem Preset wirken.
//
// SCHRITT: 2, Roller aus 6

import 'package:flutter/material.dart';

import '../../core/theme/theme_access.dart';
import '../../features/roller/roller_panel.dart';
import '../../widgets/skin_divider.dart';

class ContextPanel extends StatelessWidget {
  const ContextPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      color: palette.surfaceRaised,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          RollerPanel(),
          SkinDivider(),
          _PanelSection(
            title: 'Backlinks',
            hint: 'Verweise auf diese Seite — Schritt 12',
          ),
          SkinDivider(),
          _PanelSection(
            title: 'Aktive Clocks',
            hint: 'Fortschritt und Spannung — Schritt 8',
          ),
          SkinDivider(),
          _PanelSection(
            title: 'KI-Companion',
            hint: 'Orakel-Deutung, Writing-Tools — Schritt 11',
          ),
        ],
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          typography.formatHeading(title),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: palette.textHeading,
            letterSpacing: typography.headingLetterSpacing,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}
