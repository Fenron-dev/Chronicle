// Datei: chronicle/lib/features/codex/codex_screen.dart
//
// ZWECK: Codex-/Wiki-Seiten (Konzept §4.2) — kuratiertes Markdown.
//
// STAND: Platzhalter. Der Editor kommt in Schritt 5.
//
// SCHRITT: 2

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/theme_access.dart';
import '../../widgets/skin_divider.dart';

class CodexScreen extends StatelessWidget {
  const CodexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxReadingWidth),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text(
              typography.formatHeading('Codex'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SkinDivider(),
            Text(
              'Kuratierte Markdown-Seiten für NPCs, Orte, Fraktionen und Lore. '
              'Der Editor mit Frontmatter, Callouts, Embeds und Hover-Preview '
              'entsteht in Schritt 5.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
