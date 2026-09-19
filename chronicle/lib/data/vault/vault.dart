// Datei: chronicle/lib/data/vault/vault.dart
//
// ZWECK: Ein geöffneter Vault — Wurzelpfad plus Einstellungen.
//
// SCHRITT: 3

import 'vault_config.dart';

/// Ein geöffneter Vault.
class Vault {
  const Vault({required this.rootPath, required this.config});

  /// Absoluter Pfad zum Vault-Ordner auf DIESEM Rechner.
  ///
  /// Der Pfad selbst wird nie im Vault gespeichert — er ändert sich, sobald
  /// der Stick an einem anderen Rechner steckt (CLAUDE.md §2.2).
  final String rootPath;

  final VaultConfig config;

  String get name => config.name;

  Vault withConfig(VaultConfig next) => Vault(rootPath: rootPath, config: next);
}

/// Warum ein Ordner nicht als Vault geöffnet werden konnte.
enum VaultOpenFailure {
  /// Der Ordner existiert nicht.
  missing,

  /// Der Ordner enthält kein `.chronicle/`.
  notAVault,

  /// `config.json` ist unlesbar oder kein gültiges JSON.
  brokenConfig,

  /// Der Vault stammt aus einer neueren Chronicle-Version.
  futureSchema,

  /// Kein Schreibrecht — etwa ein schreibgeschützter Stick.
  notWritable,
}

/// Fehler beim Öffnen oder Anlegen eines Vaults.
///
/// Typisiert statt einer rohen Exception, damit das UI unterscheiden kann,
/// ohne Fehlertexte zu vergleichen (siehe Skill `flutter-conventions`).
class VaultException implements Exception {
  const VaultException(this.failure, this.path, [this.cause]);

  final VaultOpenFailure failure;
  final String path;
  final Object? cause;

  /// Für den Nutzer lesbar, mit Handlungsoption statt Schuldzuweisung.
  String get message => switch (failure) {
    VaultOpenFailure.missing => 'Der Ordner existiert nicht mehr: $path',
    VaultOpenFailure.notAVault =>
      'In diesem Ordner liegt kein Chronicle-Vault. '
          'Du kannst hier einen neuen anlegen.',
    VaultOpenFailure.brokenConfig =>
      'Die Vault-Einstellungen sind beschädigt. Der Inhalt ist davon nicht '
          'betroffen — die Dateien im Ordner bleiben die Wahrheit.',
    VaultOpenFailure.futureSchema =>
      'Dieser Vault stammt aus einer neueren Chronicle-Version. '
          'Bitte aktualisiere Chronicle, bevor du ihn öffnest.',
    VaultOpenFailure.notWritable =>
      'Auf diesen Ordner kann nicht geschrieben werden: $path',
  };

  @override
  String toString() => 'VaultException(${failure.name}, $path)';
}
