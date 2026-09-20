// Datei: chronicle/lib/features/systems/systems_screen.dart
//
// ZWECK: Die Verwaltung der beiden Container, in denen alles andere lebt
//        (Konzept §3.1): Systeme (Regelwerk, wiederverwendbar) und Partien
//        (laufendes Spiel, bezieht sich auf genau ein System). Darunter der
//        Theme-Manager (Konzept §5.3).
//
// WARUM DIE REIHENFOLGE: Ohne System keine Partie, ohne Partie kein Play-Log.
//        Wer einen frischen Vault öffnet, muss hier oben anfangen — nicht
//        beim Theme.
//
// SCHRITT: 3c
//
// STAND: Der Scope-Umschalter des Themes („pro System" vs. „für dieses
//        Spiel") fehlt noch; die Auswahl gilt vorläufig app-weit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/chronicle_palette.dart';
import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/entry_kind.dart';
import '../../core/theme/presets.dart';
import '../../core/theme/theme_access.dart';
import '../../core/theme/theme_preset.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/vault/vault_catalog.dart';
import '../../data/vault/vault_providers.dart';

class SystemsScreen extends ConsumerWidget {
  const SystemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        _SystemsSection(),
        SizedBox(height: 28),
        _GamesSection(),
        SizedBox(height: 28),
        _ThemeSection(),
      ],
    );
  }
}

// ── Systeme ─────────────────────────────────────────────────────────────────

class _SystemsSection extends ConsumerWidget {
  const _SystemsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final systems = ref.watch(vaultSystemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Systeme',
          subtitle:
              'Ein System ist das wiederverwendbare Regelwerk: Regeltexte, '
              'Tabellen, Decks, Vorlagen. Ein System trägt beliebig viele '
              'Partien.',
          actionLabel: 'System anlegen…',
          onAction: () => _createSystem(context, ref),
        ),
        const SizedBox(height: 12),
        systems.when(
          loading: () => const _SectionLoading(),
          error: (error, _) => _SectionError(error: error),
          data: (entries) => entries.isEmpty
              ? const _EmptyHint(
                  icon: Icons.category_outlined,
                  text:
                      'Noch kein System. Lege eines an — danach lässt sich '
                      'eine Partie starten.',
                )
              : Column(
                  children: [
                    for (final system in entries)
                      _CatalogTile(
                        icon: Icons.category_outlined,
                        title: system.name,
                        subtitle: 'systems/${system.slug}',
                        accent: palette.accent,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _createSystem(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(
      context,
      title: 'Neues System',
      hint: 'z. B. Ironsworn, Mythic GME, Eigenbau',
    );
    if (name == null) return;
    await ref.read(catalogActionsProvider).createSystem(name);
  }
}

// ── Partien ─────────────────────────────────────────────────────────────────

class _GamesSection extends ConsumerWidget {
  const _GamesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final games = ref.watch(vaultGamesProvider);
    final systems = ref.watch(vaultSystemsProvider).value ?? const [];
    final activeGame = ref.watch(activeGameProvider).value;

    // Eine Partie bezieht sich auf genau ein System (Konzept §3.1) — ohne
    // System gibt es nichts, worauf sie sich beziehen könnte.
    final canCreate = systems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Partien',
          subtitle:
              'Eine Partie ist ein laufendes Spiel: Play-Log, Codex, '
              'Entities, Tracker. Sie bezieht sich auf genau ein System.',
          actionLabel: 'Partie starten…',
          onAction: canCreate ? () => _createGame(context, ref, systems) : null,
          disabledHint: canCreate ? null : 'Erst ein System anlegen',
        ),
        const SizedBox(height: 12),
        games.when(
          loading: () => const _SectionLoading(),
          error: (error, _) => _SectionError(error: error),
          data: (entries) => entries.isEmpty
              ? const _EmptyHint(
                  icon: Icons.play_circle_outline,
                  text: 'Noch keine Partie.',
                )
              : Column(
                  children: [
                    for (final game in entries)
                      _CatalogTile(
                        icon: Icons.play_circle_outline,
                        title: game.name,
                        subtitle: _systemNameFor(game, systems),
                        accent: palette.accent,
                        selected: game.id == activeGame?.id,
                        trailing: game.id == activeGame?.id
                            ? Text(
                                'aktiv',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: palette.accent),
                              )
                            : null,
                        onTap: () => ref
                            .read(catalogActionsProvider)
                            .selectGame(game.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  String _systemNameFor(GameEntry game, List<SystemEntry> systems) {
    for (final system in systems) {
      if (system.id == game.systemId) return 'System: ${system.name}';
    }
    // Das System wurde außerhalb der App gelöscht oder noch nicht indiziert.
    return 'System nicht gefunden';
  }

  Future<void> _createGame(
    BuildContext context,
    WidgetRef ref,
    List<SystemEntry> systems,
  ) async {
    final system = systems.length == 1
        ? systems.single
        : await _promptForSystem(context, systems);
    if (system == null) return;
    if (!context.mounted) return;

    final name = await _promptForName(
      context,
      title: 'Neue Partie',
      hint: 'z. B. Das Moor von Mörwald',
    );
    if (name == null) return;

    await ref.read(catalogActionsProvider).createGame(name, system.id);
  }
}

// ── Theme ───────────────────────────────────────────────────────────────────

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeThemePresetProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Theme',
          subtitle:
              'Ein Theme gehört zum System und ist pro Partie '
              'überschreibbar. Die Auswahl hier gilt vorläufig app-weit.',
        ),
        const SizedBox(height: 12),
        for (final preset in kThemePresets)
          _PresetCard(
            preset: preset,
            selected: preset.id == active.id,
            onTap: () =>
                ref.read(activeThemePresetProvider.notifier).select(preset.id),
          ),
        const SizedBox(height: 20),
        Text(
          context.typography.formatHeading('Eintragstyp-Farben'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const _EntryLegend(),
      ],
    );
  }
}

// ── Gemeinsame Bausteine ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.disabledHint,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Wird statt des Buttons gezeigt, wenn die Aktion gerade nicht geht —
  /// ein grauer Button ohne Begründung ist eine Sackgasse.
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.typography.formatHeading(title),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
              if (disabledHint != null) ...[
                const SizedBox(height: 4),
                Text(
                  disabledHint!,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.selected = false,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? palette.accentSurface : palette.surfaceRaised,
        borderRadius: skin.radius(RadiusToken.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: skin.radius(RadiusToken.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: skin.radius(RadiusToken.card),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.textMuted),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: skin.radius(RadiusToken.card),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Text(
    'Konnte nicht gelesen werden: $error',
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.palette.danger),
  );
}

// ── Dialoge ─────────────────────────────────────────────────────────────────

/// Fragt nach einem Namen. Liefert null bei Abbruch.
Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      void submit() {
        final value = controller.text.trim();
        if (value.isEmpty) return;
        Navigator.of(dialogContext).pop(value);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(onPressed: submit, child: const Text('Anlegen')),
        ],
      );
    },
  );

  // Der Controller lebt nur für diesen Dialog; ohne dispose bleibt sein
  // Listener hängen.
  controller.dispose();
  return result;
}

/// Fragt, auf welches System sich eine neue Partie bezieht.
Future<SystemEntry?> _promptForSystem(
  BuildContext context,
  List<SystemEntry> systems,
) {
  return showDialog<SystemEntry>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Welches System?'),
      children: [
        for (final system in systems)
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(system),
            child: Text(system.name),
          ),
      ],
    ),
  );
}

// ── Theme-Bausteine (unverändert aus Schritt 2) ─────────────────────────────

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;

    // Die Vorschau zeigt die DUNKLE Palette des jeweiligen Presets, nicht die
    // aktive. Sonst sähen alle vier Karten gleich aus — und die Auswahl wäre
    // sinnlos.
    final preview = preset.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? palette.accentSurface : palette.surfaceRaised,
        borderRadius: skin.radius(RadiusToken.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: skin.radius(RadiusToken.card),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: skin.radius(RadiusToken.card),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Swatches(preview: preview, skin: skin),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            preset.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (selected) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: palette.accent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.mood,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      // Schriftprobe in den Familien des Presets.
                      Text(
                        preset.typography.headingCaps
                            ? 'KAPITEL EINS'
                            : 'Kapitel Eins',
                        style: TextStyle(
                          fontFamily: preset.typography.heading,
                          fontWeight: preset.typography.headingWeight,
                          letterSpacing: preset.typography.headingLetterSpacing,
                          color: palette.textHeading,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        'Der Nebel über dem Moor wird dichter.',
                        style: TextStyle(
                          fontFamily: preset.typography.body,
                          letterSpacing: preset.typography.bodyLetterSpacing,
                          color: palette.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
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

class _Swatches extends StatelessWidget {
  const _Swatches({required this.preview, required this.skin});

  final ChroniclePalette preview;
  final ChronicleSkin skin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: preview.surface,
        borderRadius: skin.radius(RadiusToken.chip),
        border: Border.all(color: preview.borderStrong),
      ),
      child: Center(
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _dot(preview.accent),
            _dot(preview.entryOracle),
            _dot(preview.entryRoll),
            _dot(preview.entryCard),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Legende aller Eintragstypen im aktiven Theme.
///
/// Macht sofort sichtbar, ob ein Preset zwei Typen ununterscheidbar färbt.
class _EntryLegend extends StatelessWidget {
  const _EntryLegend();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in EntryKind.values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceRaised,
              borderRadius: skin.radius(RadiusToken.chip),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: palette.colorFor(kind),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(kind.name, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
      ],
    );
  }
}
