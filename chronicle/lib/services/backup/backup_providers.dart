// Datei: chronicle/lib/services/backup/backup_providers.dart
//
// ZWECK: Sichern und Zurückspielen als Aktionen für das UI.
//
// WARUM DER VAULT DAZWISCHEN GESCHLOSSEN WIRD: Beim Zurückspielen
//        verschwindet `index.db`. Drift hält darauf ein offenes Handle —
//        unter Windows schlägt das Löschen einer offenen Datei schlicht
//        fehl, und unter macOS bliebe eine verwaiste Sperre auf einem Stick
//        liegen, den der Nutzer abziehen will. Also: schließen, zurückspielen,
//        wieder öffnen. Das Öffnen baut den Index ohnehin neu auf.
//
// SCHRITT: 3b

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants.dart';
import '../../data/vault/vault_providers.dart';
import 'backup_entry.dart';
import 'backup_service.dart';
import 'note_snapshots.dart';

part 'backup_providers.g.dart';

@Riverpod(keepAlive: true)
BackupService backupService(Ref ref) =>
    const BackupService(appVersion: kAppVersion);

@Riverpod(keepAlive: true)
NoteSnapshots noteSnapshots(Ref ref) => const NoteSnapshots();

/// Alle Sicherungen des aktiven Vaults, neueste zuerst.
///
/// Bewusst autoDispose: die Liste wird gelesen, wenn die Verwaltung offen
/// ist, und darf danach vergessen werden.
@riverpod
Future<List<BackupEntry>> vaultBackups(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  if (session == null) return const [];
  return ref.watch(backupServiceProvider).list(session.vault.rootPath);
}

/// Schreibaktionen auf den Sicherungen.
///
/// Wie [CatalogActions] eine schlichte Klasse hinter einem Provider: hier
/// gibt es keinen eigenen Zustand, nur Abläufe, die andere Provider anstoßen.
@Riverpod(keepAlive: true)
BackupActions backupActions(Ref ref) => BackupActions(ref);

class BackupActions {
  const BackupActions(this._ref);

  final Ref _ref;

  /// Legt eine Sicherung des aktiven Vaults an.
  Future<BackupEntry> create({String? label}) async {
    final root = _requireRoot();
    final entry = await _ref
        .read(backupServiceProvider)
        .create(root, label: label);
    _ref.invalidate(vaultBackupsProvider);
    return entry;
  }

  /// Legt einen Snapshot vor einer Format-Migration an und räumt alte weg.
  ///
  /// Noch ruft das niemand auf — es gibt bislang nur Schema-Version 1. Die
  /// Stelle steht trotzdem schon, weil die Regel lautet: ohne Snapshot keine
  /// Migration (CLAUDE.md §5.3). Wer die erste Migration schreibt, soll sie
  /// vorfinden und nicht erfinden müssen.
  Future<BackupEntry> snapshotBeforeMigration(String label) async {
    final root = _requireRoot();
    final service = _ref.read(backupServiceProvider);
    final entry = await service.create(
      root,
      kind: BackupKind.beforeMigration,
      label: label,
    );
    await service.prune(root, BackupKind.beforeMigration);
    _ref.invalidate(vaultBackupsProvider);
    return entry;
  }

  /// Spielt [archivePath] zurück und öffnet den Vault danach neu.
  Future<RestoreReport> restore(String archivePath) async {
    final root = _requireRoot();
    final notifier = _ref.read(activeVaultProvider.notifier);

    await notifier.close();
    try {
      return await _ref.read(backupServiceProvider).restore(root, archivePath);
    } finally {
      // Auch im Fehlerfall: einen geschlossenen Vault zurückzulassen wäre
      // aus Nutzersicht ein zweiter Schaden nach dem ersten.
      await notifier.openPath(root);
      _ref.invalidate(vaultBackupsProvider);
    }
  }

  Future<void> delete(String archivePath) async {
    await _ref.read(backupServiceProvider).delete(archivePath);
    _ref.invalidate(vaultBackupsProvider);
  }

  Future<String> export(String archivePath, String targetDir) =>
      _ref.read(backupServiceProvider).export(archivePath, targetDir);

  String _requireRoot() {
    final session = _ref.read(activeVaultProvider).value;
    if (session == null) {
      // Die Verwaltung ist nur mit offenem Vault erreichbar. Kommt es
      // trotzdem hierher, ist das ein Programmierfehler.
      throw StateError('Kein Vault geöffnet');
    }
    return session.vault.rootPath;
  }
}
