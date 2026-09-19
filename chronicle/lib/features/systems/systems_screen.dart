// Datei: chronicle/lib/features/systems/systems_screen.dart
//
// ZWECK: System-Verwaltung. Enthält den Theme-Manager (Konzept §5.3):
//        Preset-Auswahl als Karten mit Swatch und Schriftprobe.
//
// STAND: Der Scope-Umschalter „pro System" vs. „für dieses Spiel" fehlt noch
//        — ohne Vaults gibt es weder Systeme noch Spiele. Er kommt in
//        Schritt 3, sobald die Scope-Kette echte Werte hat.
//
// SCHRITT: 2

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/chronicle_palette.dart';
import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/entry_kind.dart';
import '../../core/theme/presets.dart';
import '../../core/theme/theme_access.dart';
import '../../core/theme/theme_preset.dart';
import '../../core/theme/theme_provider.dart';
import '../../widgets/skin_divider.dart';

class SystemsScreen extends ConsumerWidget {
  const SystemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final typography = context.typography;
    final active = ref.watch(activeThemePresetProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          typography.formatHeading('Theme-Manager'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Ein Theme gehört zum System und ist pro Spiel überschreibbar. '
          'Die Auswahl hier gilt vorläufig app-weit — die Scope-Kette greift '
          'ab Schritt 3.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: palette.textSecondary),
        ),
        const SkinDivider(),
        for (final preset in kThemePresets)
          _PresetCard(
            preset: preset,
            selected: preset.id == active.id,
            onTap: () =>
                ref.read(activeThemePresetProvider.notifier).select(preset.id),
          ),
        const SizedBox(height: 24),
        Text(
          typography.formatHeading('Eintragstyp-Farben'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const _EntryLegend(),
      ],
    );
  }
}

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
