// Datei: chronicle/lib/features/tracks/focused_track_bar.dart
//
// ZWECK: Der fokussierte Track in der oberen Leiste (Konzept §4.5).
//
// EIN KLICK, EIN SCHRITT: Beim Spielen soll das Weiterschalten keine
//        Suche erfordern. Ein Klick auf ein Segment hakt genau diesen Beat
//        ab (oder nimmt ihn zurück); ein Klick auf eine Clock füllt ein
//        Segment. Der Titel öffnet die Auswahl, welcher Track oben steht.
//
// SCHRITT: 8

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
import '../../data/vault/track_repository.dart';
import 'clock_face.dart';
import 'track_providers.dart';

class FocusedTrackBar extends ConsumerWidget {
  const FocusedTrackBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(focusedTrackProvider).value;
    final all = ref.watch(gameTracksProvider).value ?? const <GameTrack>[];

    if (focused == null) return const _EmptyTrack();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TrackTitle(track: focused, all: all),
        const SizedBox(width: 12),
        Flexible(
          child: switch (focused.kind) {
            TrackKind.track => _BeatSegments(track: focused),
            TrackKind.clock => _ClockControl(track: focused),
          },
        ),
      ],
    );
  }
}

class _EmptyTrack extends StatelessWidget {
  const _EmptyTrack();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.typography.formatHeading('Kein Track'),
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: context.palette.textMuted),
      ),
    );
  }
}

/// Titel mit Auswahl, welcher Track oben steht.
class _TrackTitle extends ConsumerWidget {
  const _TrackTitle({required this.track, required this.all});

  final GameTrack track;
  final List<GameTrack> all;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final title = Text(
      context.typography.formatHeading(track.title),
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: palette.textHeading),
    );

    // Nur ein Track: keine Auswahl anbieten, die nichts zu wählen hat.
    if (all.length < 2) return title;

    return PopupMenuButton<String>(
      tooltip: 'Anderen Track in die Leiste holen',
      onSelected: (id) {
        for (final candidate in all) {
          if (candidate.id == id) {
            ref.read(trackActionsProvider).focus(candidate);
            return;
          }
        }
      },
      itemBuilder: (_) => [
        for (final candidate in all)
          CheckedPopupMenuItem<String>(
            value: candidate.id,
            checked: candidate.id == track.id,
            child: Text(candidate.title),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: title),
          Icon(Icons.arrow_drop_down, size: 18, color: palette.textMuted),
        ],
      ),
    );
  }
}

/// Ein Segment je Haupt-Beat.
class _BeatSegments extends ConsumerWidget {
  const _BeatSegments({required this.track});

  final GameTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final skin = context.skin;
    final top = track.beats.where((b) => b.depth == 0).toList();
    final next = track.progress.next;

    if (top.isEmpty) {
      return Text(
        'Noch keine Beats',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: palette.textMuted),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final beat in top)
          Tooltip(
            message: beat.done ? '✓ ${beat.text}' : beat.text,
            child: InkWell(
              borderRadius: skin.radius(RadiusToken.chip),
              onTap: () => ref
                  .read(trackActionsProvider)
                  .setBeat(track, beat, done: !beat.done),
              child: Container(
                width: 26,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                decoration: BoxDecoration(
                  color: beat.done ? palette.accent : palette.surfaceSunken,
                  borderRadius: skin.radius(RadiusToken.chip),
                  // Der nächste offene Beat trägt einen Rand: man sieht, wo
                  // die Geschichte gerade steht, ohne zu zählen.
                  border: beat.line == next?.line
                      ? Border.all(color: palette.accent)
                      : null,
                ),
              ),
            ),
          ),
        if (next != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              next.text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

class _ClockControl extends ConsumerWidget {
  const _ClockControl({required this.track});

  final GameTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = track.clock!;
    final actions = ref.read(trackActionsProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Segment leeren',
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          onPressed: clock.isEmpty
              ? null
              : () => actions.advanceClock(track, -1),
          icon: const Icon(Icons.remove),
        ),
        Tooltip(
          message: '${clock.filled} / ${clock.segments} — klicken zum Füllen',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: clock.isComplete
                ? null
                : () => actions.advanceClock(track, 1),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClockFace(clock: clock),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Segment füllen',
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          onPressed: clock.isComplete
              ? null
              : () => actions.advanceClock(track, 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
