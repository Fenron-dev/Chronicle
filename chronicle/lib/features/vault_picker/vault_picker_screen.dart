// Datei: chronicle/lib/features/vault_picker/vault_picker_screen.dart
//
// ZWECK: Der erste Screen — Vault öffnen, anlegen, oder einen zuletzt
//        geöffneten wählen. Obsidian-artig (Konzept §3.2).
//
// SCHRITT: 3

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
import '../../data/vault/recent_vaults_store.dart';
import '../../data/vault/vault.dart';
import '../../data/vault/vault_providers.dart';
import '../../widgets/skin_divider.dart';

class VaultPickerScreen extends ConsumerWidget {
  const VaultPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final typography = context.typography;
    final session = ref.watch(activeVaultProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxReadingWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  typography.formatHeading('Chronicle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ein Vault ist ein gewöhnlicher Ordner. Er passt auf einen '
                  'USB-Stick und lässt sich weiterreichen.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: palette.textSecondary),
                ),
                const SkinDivider(),

                if (session.isLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Index wird aus den Dateien aufgebaut …',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],

                if (session.hasError) _ErrorNotice(error: session.error!),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: session.isLoading
                          ? null
                          : () => _openExisting(ref),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Vault öffnen…'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: session.isLoading
                          ? null
                          : () => _createNew(ref),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Neuen Vault anlegen…'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const _RecentVaultsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openExisting(WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Chronicle-Vault öffnen',
    );
    if (path == null) return;
    await ref.read(activeVaultProvider.notifier).openPath(path);
  }

  Future<void> _createNew(WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Ordner für den neuen Vault wählen',
    );
    if (path == null) return;

    // Der Ordnername ist der Vault-Name — wie in Obsidian. Umbenennen geht
    // später in den Einstellungen; hier wäre ein zweiter Dialog nur Reibung.
    final name = path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;
    await ref.read(activeVaultProvider.notifier).createAndOpen(path, name);
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;

    // Eine VaultException weiß, was schiefging, und sagt es in einem Satz
    // mit Handlungsoption. Alles andere ist ein Programmierfehler und wird
    // roh gezeigt — verschleiern hilft beim Debuggen niemandem.
    final message = error is VaultException
        ? (error as VaultException).message
        : error.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.dangerSurface,
        borderRadius: skin.radius(RadiusToken.card),
        border: Border.all(color: palette.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: palette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _RecentVaultsList extends ConsumerWidget {
  const _RecentVaultsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final typography = context.typography;
    final recent = ref.watch(recentVaultsProvider);

    return recent.when(
      loading: () => const SizedBox(height: 40),
      error: (error, _) => Text(
        'Die Liste zuletzt geöffneter Vaults konnte nicht gelesen werden.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: palette.textMuted),
      ),
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              typography.formatHeading('Zuletzt geöffnet'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final entry in entries) _RecentTile(entry: entry),
          ],
        );
      },
    );
  }
}

class _RecentTile extends ConsumerWidget {
  const _RecentTile({required this.entry});

  final RecentVault entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final skin = context.skin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: palette.surfaceRaised,
        borderRadius: skin.radius(RadiusToken.button),
        child: InkWell(
          borderRadius: skin.radius(RadiusToken.button),
          onTap: () =>
              ref.read(activeVaultProvider.notifier).openPath(entry.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: palette.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        entry.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Aus der Liste entfernen',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => ref
                      .read(recentVaultsProvider.notifier)
                      .forget(entry.path),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
