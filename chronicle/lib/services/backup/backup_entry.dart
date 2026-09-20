// Datei: chronicle/lib/services/backup/backup_entry.dart
//
// ZWECK: Ein Backup als Wert — Datei, Zeitpunkt, Anlass, Umfang.
//
// WARUM EIN MANIFEST IM ZIP: Der Dateiname allein trägt zu wenig. Wer ein
//        halbes Jahr später vor drei Archiven steht, muss erkennen können,
//        aus welchem Vault sie stammen und warum sie angelegt wurden —
//        ohne sie auszupacken.
//
// SIEHE: Skill `vault-format`, Abschnitt „Backup, Snapshots, Migration"
// SCHRITT: 3b

import 'dart:convert';

/// Warum ein Backup angelegt wurde.
enum BackupKind {
  /// Vom Nutzer ausgelöst.
  manual,

  /// Automatisch vor einer Wiederherstellung — das Sicherheitsnetz für den
  /// Fall, dass das falsche Archiv erwischt wurde.
  beforeRestore,

  /// Automatisch vor einer Format-Migration (CLAUDE.md §5.3).
  beforeMigration;

  /// Der Name im Dateinamen. Bewusst ASCII: der Vault liegt auf einem Stick,
  /// der zwischen Betriebssystemen wandert.
  String get slug => switch (this) {
    BackupKind.manual => 'manual',
    BackupKind.beforeRestore => 'pre-restore',
    BackupKind.beforeMigration => 'pre-migration',
  };

  String get label => switch (this) {
    BackupKind.manual => 'Manuell',
    BackupKind.beforeRestore => 'Vor Wiederherstellung',
    BackupKind.beforeMigration => 'Vor Migration',
  };

  static BackupKind fromSlug(String? slug) => switch (slug) {
    'pre-restore' => BackupKind.beforeRestore,
    'pre-migration' => BackupKind.beforeMigration,
    _ => BackupKind.manual,
  };
}

/// Das Manifest im Archiv, unter [BackupManifest.fileName].
class BackupManifest {
  const BackupManifest({
    required this.created,
    required this.kind,
    required this.vaultId,
    required this.vaultName,
    required this.vaultSchemaVersion,
    required this.fileCount,
    required this.byteSize,
    this.label,
    this.appVersion,
    this.schemaVersion = currentSchemaVersion,
  });

  /// Der Name im Archiv-Wurzelverzeichnis.
  ///
  /// Mit Punkt-Präfix, damit ein von Hand entpacktes Archiv keine fremde
  /// Datei sichtbar im Vault-Wurzelverzeichnis hinterlässt. Beim
  /// Wiederherstellen wird sie ohnehin übersprungen.
  static const String fileName = '.chronicle-backup.json';

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime created;
  final BackupKind kind;

  /// Aus welchem Vault das Archiv stammt. Erlaubt die Warnung „das gehört zu
  /// einem anderen Vault", bevor etwas überschrieben wird.
  final String vaultId;
  final String vaultName;

  /// Die Formatversion des gesicherten Vaults — ein Archiv aus einer neueren
  /// Chronicle-Version darf nicht in einen älteren Vault zurückgespielt
  /// werden.
  final int vaultSchemaVersion;

  final int fileCount;

  /// Summe der ungepackten Größen. Als Orientierung, was zurückkommt.
  final int byteSize;

  final String? label;
  final String? appVersion;

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
    schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    created:
        DateTime.tryParse(json['created'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    kind: BackupKind.fromSlug(json['kind'] as String?),
    vaultId: json['vaultId'] as String? ?? '',
    vaultName: json['vaultName'] as String? ?? 'Vault',
    vaultSchemaVersion: (json['vaultSchemaVersion'] as num?)?.toInt() ?? 1,
    fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
    byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
    label: json['label'] as String?,
    appVersion: json['appVersion'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'created': created.toUtc().toIso8601String(),
    'kind': kind.slug,
    'vaultId': vaultId,
    'vaultName': vaultName,
    'vaultSchemaVersion': vaultSchemaVersion,
    'fileCount': fileCount,
    'byteSize': byteSize,
    if (label != null) 'label': label,
    if (appVersion != null) 'appVersion': appVersion,
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Ein Backup, wie es in der Liste erscheint.
class BackupEntry {
  const BackupEntry({
    required this.path,
    required this.fileName,
    required this.archiveBytes,
    required this.manifest,
  });

  /// Absoluter Pfad zur ZIP-Datei auf DIESEM Rechner.
  final String path;
  final String fileName;

  /// Größe des gepackten Archivs.
  final int archiveBytes;

  /// Null, wenn das Archiv kein Chronicle-Manifest trägt — etwa ein von Hand
  /// gepackter Ordner. Dann steht in der Liste nur, was die Datei hergibt.
  final BackupManifest? manifest;

  DateTime get created =>
      manifest?.created ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  BackupKind get kind => manifest?.kind ?? BackupKind.manual;
}

/// Warum ein Backup oder eine Wiederherstellung nicht möglich war.
enum BackupFailure {
  /// Die Archivdatei fehlt oder ist unlesbar.
  missingArchive,

  /// Kein ZIP oder ohne Chronicle-Manifest.
  notABackup,

  /// Das Archiv stammt aus einer neueren Chronicle-Version.
  futureSchema,

  /// Ein Eintrag im Archiv zeigt aus dem Vault heraus (`../`).
  unsafeEntry,

  /// Schreiben fehlgeschlagen — voller Datenträger, abgezogener Stick.
  notWritable,
}

/// Fehler beim Sichern oder Wiederherstellen.
class BackupException implements Exception {
  const BackupException(this.failure, this.path, [this.cause]);

  final BackupFailure failure;
  final String path;
  final Object? cause;

  String get message => switch (failure) {
    BackupFailure.missingArchive => 'Die Sicherungsdatei fehlt: $path',
    BackupFailure.notABackup =>
      'Diese Datei ist kein Chronicle-Backup. Erwartet wird ein ZIP-Archiv, '
          'das Chronicle selbst angelegt hat.',
    BackupFailure.futureSchema =>
      'Dieses Backup stammt aus einer neueren Chronicle-Version. '
          'Bitte aktualisiere Chronicle, bevor du es zurückspielst.',
    BackupFailure.unsafeEntry =>
      'Das Archiv enthält einen Eintrag außerhalb des Vaults und wurde '
          'nicht zurückgespielt.',
    BackupFailure.notWritable =>
      'Auf den Vault kann nicht geschrieben werden: $path',
  };

  @override
  String toString() => 'BackupException(${failure.name}, $path)';
}
