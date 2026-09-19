// Datei: chronicle/lib/app/shell/top_bar.dart
//
// ZWECK: Die obere Leiste. Zeigt den fokussierten Track (Konzept §7.1) und
//        hält den Theme-Schnellumschalter (Konzept §5.3).
//
// STAND: Der Track ist in Schritt 2 noch ein Platzhalter — Clocks und
//        Step-Tracks kommen in Schritt 8. Die Leiste existiert trotzdem
//        schon, weil das Desktop-Layout ohne sie anders proportioniert ist.
//
// SCHRITT: 2

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/presets.dart';
import '../../core/theme/theme_access.dart';
import '../../core/theme/theme_provider.dart';
import 'shell_providers.dart';

class ChronicleTopBar extends ConsumerWidget {
  const ChronicleTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final navVisible = ref.watch(navPanelVisibleProvider);
    final contextVisible = ref.watch(contextPanelVisibleProvider);

    return Container(
      height: kTopBarHeight,
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: navVisible ? 'Baum einklappen' : 'Baum ausklappen',
            icon: Icon(navVisible ? Icons.menu_open : Icons.menu),
            onPressed: () =>
                ref.read(navPanelVisibleProvider.notifier).toggle(),
          ),
          const Expanded(child: _FocusedTrack()),
          const _ThemeQuickSwitcher(),
          const _BrightnessToggle(),
          IconButton(
            tooltip: contextVisible
                ? 'Kontext-Panel einklappen'
                : 'Kontext-Panel ausklappen',
            icon: Icon(
              contextVisible ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            ),
            onPressed: () =>
                ref.read(contextPanelVisibleProvider.notifier).toggle(),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Der fokussierte Track mit abhakbaren Beats.
///
/// Platzhalter bis Schritt 8 — die Struktur (Titel plus Beat-Kette) steht
/// aber schon, damit das Layout stimmt.
class _FocusedTrack extends StatelessWidget {
  const _FocusedTrack();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          typography.formatHeading('Kein Track'),
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: palette.textMuted),
        ),
        const SizedBox(width: 12),
        for (var i = 0; i < 4; i++) ...[
          Container(
            width: 26,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              borderRadius: context.skin.radius(RadiusToken.chip),
            ),
          ),
        ],
      ],
    );
  }
}

/// Schnellumschalter für das Preset (Konzept §5.3).
class _ThemeQuickSwitcher extends ConsumerWidget {
  const _ThemeQuickSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeThemePresetProvider);

    return PopupMenuButton<String>(
      tooltip: 'Theme wechseln',
      icon: const Icon(Icons.palette_outlined),
      initialValue: active.id,
      onSelected: (id) =>
          ref.read(activeThemePresetProvider.notifier).select(id),
      itemBuilder: (context) => [
        for (final preset in kThemePresets)
          PopupMenuItem<String>(
            value: preset.id,
            child: Row(
              children: [
                // Swatch aus der dunklen Palette — erkennbar auch dann, wenn
                // das Menü selbst im hellen Theme steht.
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: preset.dark.accent,
                    border: Border.all(color: preset.dark.borderStrong),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(preset.name),
              ],
            ),
          ),
      ],
    );
  }
}

class _BrightnessToggle extends ConsumerWidget {
  const _BrightnessToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Helles Theme' : 'Dunkles Theme',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ref
          .read(activeThemeModeProvider.notifier)
          .toggle(Theme.of(context).brightness),
    );
  }
}
