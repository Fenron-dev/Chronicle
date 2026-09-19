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
import '../../data/vault/vault_providers.dart';
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
          const _VaultLabel(),
          const Expanded(child: _FocusedTrack()),
          const _VaultMenu(),
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

/// Name des offenen Vaults.
class _VaultLabel extends ConsumerWidget {
  const _VaultLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeVaultProvider).valueOrNull;
    if (session == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 15,
            color: context.palette.accent,
          ),
          const SizedBox(width: 6),
          Text(
            session.vault.name,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

/// Vault-Aktionen: Index neu aufbauen, Vault schließen.
class _VaultMenu extends ConsumerWidget {
  const _VaultMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeVaultProvider);
    final session = state.valueOrNull;
    if (session == null) return const SizedBox.shrink();

    final report = session.report;

    return PopupMenuButton<String>(
      tooltip: 'Vault',
      icon: const Icon(Icons.inventory_2_outlined),
      onSelected: (value) {
        final notifier = ref.read(activeVaultProvider.notifier);
        if (value == 'reindex') {
          notifier.reindex();
        } else if (value == 'close') {
          notifier.close();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            '\${report.noteCount} Notizen · \${report.edgeCount} Verweise'
            '\${report.unresolvedLinks > 0 ? " · \${report.unresolvedLinks} offen" : ""}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        if (report.problems.isNotEmpty)
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              '\${report.problems.length} Datei(en) übersprungen',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: context.palette.warning),
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'reindex',
          child: Text('Index neu aufbauen'),
        ),
        const PopupMenuItem<String>(
          value: 'close',
          child: Text('Vault schließen'),
        ),
      ],
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
