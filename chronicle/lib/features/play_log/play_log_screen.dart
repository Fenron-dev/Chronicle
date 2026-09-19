// Datei: chronicle/lib/features/play_log/play_log_screen.dart
//
// ZWECK: Das Play-Log — der chronologische Stream getippter Einträge
//        (Konzept §4.1).
//
// STAND: Schritt 2 zeigt einen Beispiel-Stream mit allen sieben
//        Eintragstypen. Das ist kein Dekor: es ist der Prüfstein für die
//        Theme-Engine. Wenn sich hier in einem Preset zwei Eintragstypen
//        nicht unterscheiden lassen, ist das Preset kaputt — und das fällt
//        nur auf, wenn man sie nebeneinander sieht.
//
//        Ab Schritt 4 kommen die Einträge aus dem Vault.
//
// SCHRITT: 2

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/entry_kind.dart';
import '../../core/theme/theme_access.dart';

/// Ein Eintrag im Beispiel-Stream.
class _SampleEntry {
  const _SampleEntry(this.kind, this.time, this.text);

  final EntryKind kind;
  final String time;
  final String text;
}

const List<_SampleEntry> _sampleEntries = [
  _SampleEntry(
    EntryKind.narration,
    '20:14',
    'Der Nebel über dem Moor wird dichter. Zwischen den Binsen steht ein '
        'Grenzstein, den auf keiner Karte verzeichnet ist.',
  ),
  _SampleEntry(
    EntryKind.roll,
    '20:15',
    '**2d6+1** → 4, 5 (+1) = **10** · Erfolg mit Kosten',
  ),
  _SampleEntry(
    EntryKind.oracle,
    '20:15',
    'Ist jemand vor mir hier gewesen? → **Ja, und** — die Spuren sind frisch.',
  ),
  _SampleEntry(
    EntryKind.card,
    '20:17',
    'Gezogen: **Der Turm** (umgekehrt) · Tarot-Deck, 22 Karten verbleibend',
  ),
  _SampleEntry(
    EntryKind.plotbeat,
    '20:19',
    'Die Grenze ist verschoben worden. Jemand wollte, dass Mörwald kleiner '
        'wird.',
  ),
  _SampleEntry(
    EntryKind.ai,
    '20:21',
    'Drei mögliche Urheber: das Haus Verren, die Zollgilde, oder das Moor '
        'selbst.',
  ),
  _SampleEntry(
    EntryKind.meta,
    '20:22',
    'Szene beendet. Nächste Session: Rückweg nach Mörwald.',
  ),
];

class PlayLogScreen extends StatelessWidget {
  const PlayLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxReadingWidth),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const _LogHeader(),
            const SizedBox(height: 16),
            for (final entry in _sampleEntries) _LogEntryTile(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _LogHeader extends StatelessWidget {
  const _LogHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          typography.formatHeading('Das Moor von Mörwald'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Beispiel-Stream · dient in Schritt 2 als Prüfstein für die Presets',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final _SampleEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;
    final color = palette.colorFor(entry.kind);
    final isNarrative = entry.kind.isNarrative;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Der farbige Balken ist die eigentliche Lesehilfe: er macht beim
          // Überfliegen sichtbar, was Erzählung ist und was Mechanik.
          Container(
            width: 3,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: skin.radius(RadiusToken.chip),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.kind.name,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: color, letterSpacing: 0.8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.time,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: palette.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.text,
                  style: isNarrative
                      ? Theme.of(context).textTheme.bodyLarge
                      : Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
