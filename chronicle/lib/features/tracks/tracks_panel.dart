// Datei: chronicle/lib/features/tracks/tracks_panel.dart
//
// ZWECK: Clocks und Tracks der Partie im rechten Kontext-Panel — anzeigen,
//        weiterschalten, anlegen, in die obere Leiste holen.
//
// SCHRITT: 8

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
import '../../data/vault/track_repository.dart';
import '../../data/vault/vault_providers.dart';
import 'clock_face.dart';
import 'track_providers.dart';

class TracksPanel extends ConsumerWidget {
  const TracksPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final hasGame = ref.watch(activeGameProvider).value != null;
    final tracks = ref.watch(gameTracksProvider);
    final focusedId = ref.watch(focusedTrackProvider).value?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.typography.formatHeading('Clocks & Tracks'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.textHeading,
                  letterSpacing: context.typography.headingLetterSpacing,
                ),
              ),
            ),
            if (hasGame)
              PopupMenuButton<String>(
                tooltip: 'Anlegen',
                icon: Icon(Icons.add, size: 18, color: palette.accent),
                onSelected: (value) => switch (value) {
                  'clock' => _newClock(context, ref),
                  _ => _newTrack(context, ref),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'clock', child: Text('Neue Clock')),
                  PopupMenuItem(value: 'track', child: Text('Neuer Track')),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (!hasGame)
          _hint(context, 'Clocks und Tracks gehören zu einer Partie.')
        else
          switch (tracks) {
            AsyncData(:final value) when value.isEmpty => _hint(
              context,
              'Noch keine. Eine Clock zeigt ungewisse Spannung, ein Track die '
              'geordnete Folge einer Geschichte (Konzept §4.5).',
            ),
            AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final track in value)
                  _TrackTile(track: track, focused: track.id == focusedId),
              ],
            ),
            AsyncError(:final error) => _hint(context, '$error'),
            _ => const LinearProgressIndicator(),
          },
      ],
    );
  }

  Widget _hint(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: context.palette.textMuted),
  );

  Future<void> _newClock(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (_) => const _NewClockDialog(),
    );
    if (result == null) return;
    await ref.read(trackActionsProvider).createClock(result.$1, result.$2);
  }

  Future<void> _newTrack(BuildContext context, WidgetRef ref) async {
    final title = await _askTitle(context, 'Neuer Track', 'z. B. Kampagne');
    if (title == null) return;
    await ref.read(trackActionsProvider).createTrack(title);
  }
}

class _TrackTile extends ConsumerWidget {
  const _TrackTile({required this.track, required this.focused});

  final GameTrack track;
  final bool focused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final skin = context.skin;
    final actions = ref.read(trackActionsProvider);

    final subtitle = switch (track.kind) {
      TrackKind.clock => '${track.clock!.filled} / ${track.clock!.segments}',
      TrackKind.track =>
        '${track.progress.done} / ${track.progress.total}'
            '${track.progress.next != null ? ' · ${track.progress.next!.text}' : ''}',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: focused ? palette.accentSurface : palette.surfaceSunken,
        borderRadius: skin.radius(RadiusToken.chip),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(
            children: [
              if (track.kind == TrackKind.clock)
                ClockFace(clock: track.clock!, size: 22)
              else
                Icon(Icons.linear_scale, size: 18, color: palette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: palette.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: track.kind == TrackKind.clock
                    ? 'Segment füllen'
                    : 'Nächsten Beat abhaken',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: switch (track.kind) {
                  TrackKind.clock when !track.clock!.isComplete =>
                    () => actions.advanceClock(track, 1),
                  TrackKind.track when track.progress.next != null =>
                    () => actions.advanceTrack(track),
                  _ => null,
                },
                icon: const Icon(Icons.chevron_right),
              ),
              PopupMenuButton<String>(
                tooltip: 'Mehr',
                iconSize: 16,
                onSelected: (value) async {
                  switch (value) {
                    case 'focus':
                      await actions.focus(track);
                    case 'minus':
                      await actions.advanceClock(track, -1);
                    case 'beat':
                      if (!context.mounted) return;
                      final text = await _askTitle(
                        context,
                        'Beat hinzufügen',
                        'z. B. Der Turm im Moor',
                      );
                      if (text != null) await actions.addBeat(track, text);
                  }
                },
                itemBuilder: (_) => [
                  if (!focused)
                    const PopupMenuItem(
                      value: 'focus',
                      child: Text('In die obere Leiste'),
                    ),
                  if (track.kind == TrackKind.clock)
                    const PopupMenuItem(
                      value: 'minus',
                      child: Text('Segment leeren'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'beat',
                      child: Text('Beat hinzufügen…'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewClockDialog extends StatefulWidget {
  const _NewClockDialog();

  @override
  State<_NewClockDialog> createState() => _NewClockDialogState();
}

class _NewClockDialogState extends State<_NewClockDialog> {
  final TextEditingController _title = TextEditingController();
  int _segments = 6;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Clock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Titel',
              hintText: 'z. B. Der Kult erwacht',
            ),
          ),
          const SizedBox(height: 16),
          // Die üblichen Größen als Auswahl statt als Zahlenfeld: FitD kennt
          // 4, 6 und 8, und ein Tippfeld lädt zu 37 ein.
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 4, label: Text('4')),
              ButtonSegment(value: 6, label: Text('6')),
              ButtonSegment(value: 8, label: Text('8')),
              ButtonSegment(value: 12, label: Text('12')),
            ],
            selected: {_segments},
            onSelectionChanged: (value) =>
                setState(() => _segments = value.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.of(context).pop((title, _segments));
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}

Future<String?> _askTitle(BuildContext context, String heading, String hint) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(heading),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Anlegen'),
        ),
      ],
    ),
  ).then((value) {
    controller.dispose();
    return value == null || value.isEmpty ? null : value;
  });
}
