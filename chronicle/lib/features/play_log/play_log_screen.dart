// Datei: chronicle/lib/features/play_log/play_log_screen.dart
//
// ZWECK: Das Play-Log — der chronologische Stream getippter Einträge
//        (Konzept §4.1). Das zentrale Spiel-Primitiv.
//
// DIE EINTRÄGE KOMMEN AUS DER DATEI, nicht aus dem Index. Der Index kennt
//        nur Titel und Pfad; der Verlauf steht im Markdown. Genau so ist es
//        gemeint — die Datei ist die Wahrheit (Skill `vault-format`).
//
// SICHTBARKEITS-TOGGLE: Nicht-narrative Einträge (Würfe, Meta) lassen sich
//        ausblenden — für den sauberen Lesefluss (Konzept §4.1).
//
// SCHRITT: 4

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
import '../../data/vault/log_repository.dart';
import '../../data/vault/vault_providers.dart';
import '../../domain/log/entry_kind.dart';
import '../../domain/log/log_entry.dart';
import '../../widgets/skin_divider.dart';
import 'play_log_providers.dart';

class PlayLogScreen extends ConsumerWidget {
  const PlayLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const _NoGameHint();

    final thread = ref.watch(activeThreadProvider);

    return Column(
      children: [
        const _ThreadBar(),
        Expanded(
          child: thread.when(
            loading: () => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => _LoadError(error: error),
            data: (data) => data == null
                ? const _NoThreadHint()
                : _EntryStream(thread: data),
          ),
        ),
        const _Composer(),
      ],
    );
  }
}

// ── Kopfleiste des Threads ──────────────────────────────────────────────────

class _ThreadBar extends ConsumerWidget {
  const _ThreadBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final threads = ref.watch(gameLogThreadsProvider).value ?? const [];
    final current = ref.watch(activeThreadProvider).value;
    final showMechanical = ref.watch(showMechanicalEntriesProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              current?.title ?? '—',
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (threads.length > 1) ...[
            PopupMenuButton<String>(
              tooltip: 'Thread wechseln',
              icon: const Icon(Icons.list_alt_outlined, size: 18),
              onSelected: (relPath) =>
                  ref.read(selectedThreadProvider.notifier).select(relPath),
              itemBuilder: (context) => [
                for (final t in threads)
                  PopupMenuItem<String>(value: t.relPath, child: Text(t.title)),
              ],
            ),
          ],
          IconButton(
            tooltip: showMechanical
                ? 'Würfe und Meta ausblenden'
                : 'Würfe und Meta einblenden',
            icon: Icon(
              showMechanical ? Icons.visibility : Icons.visibility_off,
              size: 18,
            ),
            onPressed: () =>
                ref.read(showMechanicalEntriesProvider.notifier).toggle(),
          ),
          IconButton(
            tooltip: 'Neuer Thread',
            icon: const Icon(Icons.add_comment_outlined, size: 18),
            onPressed: () => _createThread(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _createThread(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Neuer Thread'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'z. B. Sitzung 2, Gespräch mit Verren, Kampf am Moor',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (title == null || title.isEmpty) return;
    await ref.read(logActionsProvider).createThread(title);
  }
}

// ── Der Eintrags-Stream ─────────────────────────────────────────────────────

class _EntryStream extends ConsumerWidget {
  const _EntryStream({required this.thread});

  final LogThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final showMechanical = ref.watch(showMechanicalEntriesProvider);

    final visible = showMechanical
        ? thread.entries
        : thread.entries.where((e) => e.kind.isNarrative).toList();

    if (thread.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Noch kein Eintrag. Schreib unten los — der erste Satz einer '
            'Partie ist meistens der schwerste.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: palette.textMuted),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxReadingWidth),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            if (thread.preamble.isNotEmpty) ...[
              Text(
                thread.preamble.replaceAll(
                  RegExp(r'^#+\s*', multiLine: true),
                  '',
                ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SkinDivider(),
            ],
            for (final entry in visible) _LogEntryTile(entry: entry),
            if (visible.length < thread.entries.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${thread.entries.length - visible.length} mechanische '
                  'Einträge ausgeblendet.',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;
    final color = palette.colorFor(entry.kind);

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
                      _clockOf(entry.timestamp),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: palette.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SelectableText(
                  entry.text,
                  style: entry.kind.isNarrative
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

  /// Ortszeit, auf die Minute — im Spiel interessiert die Uhrzeit, nicht das
  /// ISO-Format aus der Datei.
  String _clockOf(DateTime utc) {
    final local = utc.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Eingabe ─────────────────────────────────────────────────────────────────

class _Composer extends ConsumerStatefulWidget {
  const _Composer();

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  EntryKind _kind = EntryKind.narration;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() => _busy = true);
    await ref.read(logActionsProvider).appendEntry(kind: _kind, text: text);

    if (!mounted) return;
    _controller.clear();
    setState(() => _busy = false);
    // Zurück ins Feld: beim Spielen schreibt man mehrere Einträge
    // hintereinander, und ein verlorener Fokus bricht den Fluss.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;
    final hasThread = ref.watch(activeThreadProvider).value != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final kind in EntryKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _KindChip(
                    kind: kind,
                    selected: kind == _kind,
                    onTap: () => setState(() => _kind = kind),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: hasThread && !_busy,
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: hasThread
                        ? 'Was passiert?'
                        : 'Erst eine Partie starten',
                    border: OutlineInputBorder(
                      borderRadius: skin.radius(RadiusToken.button),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: hasThread && !_busy ? _submit : null,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Eintragen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final EntryKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;
    final color = palette.colorFor(kind);

    return Material(
      color: selected ? palette.accentSurface : Colors.transparent,
      borderRadius: skin.radius(RadiusToken.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: skin.radius(RadiusToken.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: skin.radius(RadiusToken.chip),
            border: Border.all(
              color: selected ? color : palette.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(kind.name, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hinweise ────────────────────────────────────────────────────────────────

class _NoGameHint extends StatelessWidget {
  const _NoGameHint();

  @override
  Widget build(BuildContext context) => const _CenteredHint(
    icon: Icons.play_circle_outline,
    title: 'Keine Partie aktiv',
    text:
        'Lege unter „Systeme" ein System an und starte eine Partie. '
        'Das Play-Log gehört zu einer Partie.',
  );
}

class _NoThreadHint extends StatelessWidget {
  const _NoThreadHint();

  @override
  Widget build(BuildContext context) => const _CenteredHint(
    icon: Icons.history_edu_outlined,
    title: 'Kein Thread',
    text: 'Diese Partie hat noch keinen Log-Thread. Lege oben rechts einen an.',
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => _CenteredHint(
    icon: Icons.error_outline,
    title: 'Thread nicht lesbar',
    text:
        'Die Datei konnte nicht geladen werden. Der Vault selbst ist davon '
        'nicht betroffen.\n\n$error',
  );
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: palette.textMuted),
              const SizedBox(height: 12),
              Text(
                context.typography.formatHeading(title),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
