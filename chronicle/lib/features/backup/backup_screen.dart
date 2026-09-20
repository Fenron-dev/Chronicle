// Datei: chronicle/lib/features/backup/backup_screen.dart
//
// ZWECK: Sicherungen verwalten — anlegen, exportieren, zurückspielen,
//        löschen.
//
// WARUM ALS DIALOG: Backup ist keine Tätigkeit, für die man einen Bereich
//        verlässt. Man sichert vor etwas Riskantem und spielt weiter.
//
// DER BESTÄTIGUNGSDIALOG IST PFLICHT: Zurückspielen ersetzt den Vault. Er
//        nennt deshalb den Stand, der kommt, den Stand, der geht, und das
//        Netz, das vorher gespannt wird — statt „Sicher? [Ja]".
//
// SCHRITT: 3b

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
import '../../data/vault/vault_providers.dart';
import '../../services/backup/backup_entry.dart';
import '../../services/backup/backup_providers.dart';
import '../../services/backup/backup_service.dart';

/// Öffnet die Sicherungs-Verwaltung als Dialog.
Future<void> showBackupManager(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _BackupDialog(),
  );
}

class _BackupDialog extends ConsumerStatefulWidget {
  const _BackupDialog();

  @override
  ConsumerState<_BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends ConsumerState<_BackupDialog> {
  /// Läuft gerade eine Sicherung oder Wiederherstellung?
  ///
  /// Während dessen sind alle Aktionen gesperrt: ein zweites Zurückspielen
  /// mitten im ersten wäre der sicherste Weg zu einem halben Vault.
  bool _busy = false;
  String? _status;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final backups = ref.watch(vaultBackupsProvider);
    final vaultName = ref.watch(activeVaultProvider).value?.vault.name ?? '';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.typography.formatHeading('Sicherungen'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    icon: const Icon(Icons.close),
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Gesichert wird der Dateibaum von „$vaultName". Der Suchindex '
                'und die Vorschaubilder bleiben draußen — sie werden beim '
                'Öffnen ohnehin neu aufgebaut.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: switch (backups) {
                  AsyncData(:final value) when value.isEmpty =>
                    const _EmptyHint(),
                  AsyncData(:final value) => _BackupList(
                    entries: value,
                    enabled: !_busy,
                    onRestore: _confirmRestore,
                    onExport: _export,
                    onDelete: _delete,
                  ),
                  AsyncError(:final error) => _ErrorHint(
                    message: error.backupMessage,
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),

              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(
                  _status!,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.success),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.danger),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _restoreFromFile,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Aus Datei…'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _createBackup,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Jetzt sichern'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    await _run(() async {
      final entry = await ref.read(backupActionsProvider).create();
      return '${entry.fileName} angelegt '
          '(${entry.manifest?.fileCount ?? 0} Dateien, '
          '${_formatBytes(entry.archiveBytes)}).';
    });
  }

  /// Fragt nach, bevor der Vault ersetzt wird.
  Future<void> _confirmRestore(BackupEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diesen Stand zurückspielen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Der Vault wird auf den Stand vom '
              '${_formatDate(entry.created)} gebracht.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Alles, was seitdem entstanden ist, wird dabei entfernt — '
              'zurückspielen ersetzt, es mischt nicht.',
            ),
            const SizedBox(height: 12),
            Text(
              'Vorher legt Chronicle automatisch eine Sicherung des jetzigen '
              'Stands an. Der Weg zurück bleibt also offen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Zurückspielen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() async {
      final report = await ref.read(backupActionsProvider).restore(entry.path);
      return '${report.filesWritten} Dateien zurückgespielt, '
          '${report.filesRemoved} ersetzt. Der Index wurde neu aufgebaut.';
    });
  }

  /// Spielt ein Archiv von außerhalb des Vaults zurück.
  Future<void> _restoreFromFile() async {
    // file_picker 13 liefert eine LISTE, kein nullbares Ergebnis mehr —
    // Abbruch ist die leere Liste.
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Welche Sicherung?',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (picked.isEmpty) return;
    // Auf dem Web gäbe es nur Bytes und keinen Pfad. Chronicle ist eine
    // Desktop-App auf einem Ordner — ohne Pfad ist hier nichts zu tun.
    final path = picked.first.path;
    if (path == null) return;

    // Erst beschreiben, dann fragen: die Rückfrage soll den Stand nennen,
    // nicht nur den Dateinamen.
    try {
      final entry = await ref.read(backupServiceProvider).describe(path);
      if (!mounted) return;
      await _confirmRestore(entry);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.backupMessage);
    }
  }

  Future<void> _export(BackupEntry entry) async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Wohin soll die Sicherung?',
    );
    if (dir == null) return;

    await _run(() async {
      final target = await ref
          .read(backupActionsProvider)
          .export(entry.path, dir);
      return 'Exportiert: $target';
    });
  }

  Future<void> _delete(BackupEntry entry) async {
    await _run(() async {
      await ref.read(backupActionsProvider).delete(entry.path);
      return '${entry.fileName} gelöscht.';
    });
  }

  /// Führt [action] aus und zeigt Ergebnis oder Fehler an.
  ///
  /// An einer Stelle, weil sonst jede der fünf Aktionen ihre eigene
  /// Sperr-, Melde- und Fehlerbehandlung bekäme — und eine davon sie
  /// vergäße.
  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _status = null;
      _error = null;
    });
    try {
      final message = await action();
      if (!mounted) return;
      setState(() => _status = message);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.backupMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _BackupList extends StatelessWidget {
  const _BackupList({
    required this.entries,
    required this.enabled,
    required this.onRestore,
    required this.onExport,
    required this.onDelete,
  });

  final List<BackupEntry> entries;
  final bool enabled;
  final ValueChanged<BackupEntry> onRestore;
  final ValueChanged<BackupEntry> onExport;
  final ValueChanged<BackupEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final manifest = entry.manifest;

        return Container(
          decoration: BoxDecoration(
            color: palette.surfaceRaised,
            borderRadius: skin.radius(RadiusToken.card),
            border: Border.all(color: palette.border),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(entry.created),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        entry.kind.label,
                        if (manifest != null) '${manifest.fileCount} Dateien',
                        _formatBytes(entry.archiveBytes),
                        ?manifest?.label,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: enabled,
                tooltip: 'Aktionen',
                onSelected: (value) {
                  switch (value) {
                    case 'restore':
                      onRestore(entry);
                    case 'export':
                      onExport(entry);
                    case 'delete':
                      onDelete(entry);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'restore',
                    child: Text('Zurückspielen…'),
                  ),
                  PopupMenuItem(value: 'export', child: Text('Exportieren…')),
                  PopupMenuItem(value: 'delete', child: Text('Löschen')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Noch keine Sicherung. Eine lohnt sich, bevor etwas Größeres '
          'passiert — ein Import, eine Umbenennung, das Aufräumen einer '
          'Partie.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.palette.textMuted),
        ),
      ),
    );
  }
}

class _ErrorHint extends StatelessWidget {
  const _ErrorHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.palette.danger),
        ),
      ),
    );
  }
}

String _formatDate(DateTime utc) {
  final local = utc.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}, '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} kB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
