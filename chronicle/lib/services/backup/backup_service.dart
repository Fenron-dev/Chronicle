// Datei: chronicle/lib/services/backup/backup_service.dart
//
// ZWECK: Vault sichern und zurückspielen. ZIP im Vault unter
//        `.chronicle/backups/`, zusätzlich exportierbar an einen beliebigen
//        Ort außerhalb.
//
// WAS NICHT INS ARCHIV GEHT: `index.db`, `thumbnails/`, die Backups selbst
//        und `.git/`. Der Index ist aus den Dateien vollständig neu
//        aufbaubar (CLAUDE.md §2.5) — ihn mitzunehmen würde das Archiv
//        vervielfachen, ohne eine einzige Information zu retten.
//
// WARUM GESTREAMT: Ein Vault enthält Medien. `ZipFileEncoder` schreibt Datei
//        für Datei auf die Platte, statt das ganze Archiv im Speicher
//        aufzubauen — ein Vault mit ein paar hundert Megabyte Bildern soll
//        die App nicht umbringen.
//
// SIEHE: Skill `vault-format`, Abschnitt „Backup, Snapshots, Migration"
// SCHRITT: 3b

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../core/dev_log.dart';
import '../../data/vault/vault.dart';
import '../../data/vault/vault_config.dart';
import '../../data/vault/vault_layout.dart';
import 'backup_entry.dart';

/// Was eine Wiederherstellung bewegt hat.
class RestoreReport {
  const RestoreReport({
    required this.filesWritten,
    required this.filesRemoved,
    required this.byteSize,
    this.safetyBackup,
  });

  final int filesWritten;
  final int filesRemoved;
  final int byteSize;

  /// Das automatisch angelegte Netz vor dem Zurückspielen — der Weg zurück,
  /// wenn das falsche Archiv erwischt wurde.
  final BackupEntry? safetyBackup;
}

/// Eine zu sichernde Datei mit ihrem Pfad relativ zum Vault-Wurzelverzeichnis.
class _Candidate {
  const _Candidate(this.relPath, this.file, this.size);

  final String relPath;
  final File file;
  final int size;
}

/// Sichert Vaults und spielt sie zurück.
class BackupService {
  const BackupService({this.appVersion});

  /// Landet im Manifest. Hilft, ein Archiv später einer Version zuzuordnen.
  final String? appVersion;

  /// Legt ein Backup des Vaults in [vaultRoot] an.
  ///
  /// [kind] entscheidet über den Ablageort: Migrations-Snapshots landen in
  /// `.chronicle/snapshots/`, alles andere in `.chronicle/backups/`. Der
  /// Unterschied ist keine Formalie — ein Snapshot gehört zur Migration und
  /// soll nicht zwischen den Sicherungen des Nutzers untergehen.
  Future<BackupEntry> create(
    String vaultRoot, {
    BackupKind kind = BackupKind.manual,
    String? label,
  }) async {
    final config = await _readConfig(vaultRoot);
    final candidates = await _collect(vaultRoot);

    final targetDir = Directory(_dirFor(vaultRoot, kind));
    await targetDir.create(recursive: true);

    final created = DateTime.now().toUtc();
    // Über _freeName, weil zwei Sicherungen in derselben Sekunde denselben
    // Namen bekämen — und die zweite die erste stillschweigend überschriebe.
    final target = _freeName(
      targetDir.path,
      'chronicle-${kind.slug}-${_stamp(created)}.zip',
    );

    final manifest = BackupManifest(
      created: created,
      kind: kind,
      vaultId: config?.id ?? '',
      vaultName: config?.name ?? _nameFromPath(vaultRoot),
      vaultSchemaVersion:
          config?.schemaVersion ?? VaultConfig.currentSchemaVersion,
      fileCount: candidates.length,
      byteSize: candidates.fold(0, (sum, c) => sum + c.size),
      label: label,
      appVersion: appVersion,
    );

    final encoder = ZipFileEncoder();
    try {
      encoder.create(target);
      encoder.addArchiveFile(
        ArchiveFile.string(BackupManifest.fileName, manifest.encode()),
      );
      for (final candidate in candidates) {
        await encoder.addFile(candidate.file, candidate.relPath);
      }
      await encoder.close();
    } on FileSystemException catch (error) {
      // Ein halbes Archiv ist schlimmer als keines: es sieht in der Liste
      // wie eine Sicherung aus und ist keine.
      await _deleteQuietly(target);
      devLog.error('backup', 'Sicherung fehlgeschlagen', error: error);
      throw BackupException(BackupFailure.notWritable, target, error);
    }

    devLog.info(
      'backup',
      'Gesichert: ${p.basename(target)} '
          '(${manifest.fileCount} Dateien, ${manifest.byteSize} Byte roh)',
    );

    return BackupEntry(
      path: target,
      fileName: p.basename(target),
      archiveBytes: await File(target).length(),
      manifest: manifest,
    );
  }

  /// Alle Sicherungen des Vaults, neueste zuerst.
  ///
  /// Gelesen wird nur das Manifest, nicht das ganze Archiv — die Liste soll
  /// auch bei einem Gigabyte Medien sofort stehen.
  Future<List<BackupEntry>> list(String vaultRoot) async {
    final entries = <BackupEntry>[];
    for (final kind in [BackupKind.manual, BackupKind.beforeMigration]) {
      final dir = Directory(_dirFor(vaultRoot, kind));
      if (!await dir.exists()) continue;
      await for (final item in dir.list(followLinks: false)) {
        if (item is! File || p.extension(item.path).toLowerCase() != '.zip') {
          continue;
        }
        final entry = await _describe(item.path);
        if (entry != null) entries.add(entry);
      }
    }
    entries.sort((a, b) => b.created.compareTo(a.created));
    return entries;
  }

  /// Liest ein Archiv von einem beliebigen Ort ein — für „Aus Datei
  /// wiederherstellen…".
  Future<BackupEntry> describe(String archivePath) async {
    final entry = await _describe(archivePath);
    if (entry == null) {
      throw BackupException(BackupFailure.missingArchive, archivePath);
    }
    if (entry.manifest == null) {
      throw BackupException(BackupFailure.notABackup, archivePath);
    }
    return entry;
  }

  /// Spielt [archivePath] in den Vault [vaultRoot] zurück.
  ///
  /// Der Vault wird auf den Stand des Archivs gebracht: alles, was das
  /// Backup abdecken würde, wird zuvor entfernt. Eine Wiederherstellung ist
  /// also ein Ersetzen, kein Zusammenführen — ein Mischen aus zwei Ständen
  /// ließe niemanden mehr sagen, was jetzt eigentlich im Vault steht.
  ///
  /// Unberührt bleiben `backups/`, `snapshots/` und `thumbnails/`: das
  /// Sicherheitsnetz darf beim Zurückspielen nicht mit weggeräumt werden —
  /// erst recht nicht das Archiv, aus dem gerade gelesen wird.
  Future<RestoreReport> restore(
    String vaultRoot,
    String archivePath, {
    bool safetyBackup = true,
  }) async {
    final source = File(archivePath);
    if (!await source.exists()) {
      throw BackupException(BackupFailure.missingArchive, archivePath);
    }

    final described = await describe(archivePath);
    final manifest = described.manifest!;
    if (manifest.schemaVersion > BackupManifest.currentSchemaVersion ||
        manifest.vaultSchemaVersion > VaultConfig.currentSchemaVersion) {
      throw BackupException(BackupFailure.futureSchema, archivePath);
    }

    BackupEntry? safety;
    if (safetyBackup) {
      safety = await create(
        vaultRoot,
        kind: BackupKind.beforeRestore,
        label: 'Vor dem Zurückspielen von ${described.fileName}',
      );
    }

    final input = InputFileStream(archivePath);
    Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } on ArchiveException catch (error) {
      await input.close();
      throw BackupException(BackupFailure.notABackup, archivePath, error);
    }

    try {
      // Erst alle Ziele prüfen, dann erst löschen. Ein Archiv mit einem
      // `../`-Eintrag darf den Vault nicht halb geleert zurücklassen.
      final targets = <ArchiveFile, String>{};
      for (final file in archive) {
        if (!file.isFile) continue;
        if (file.name == BackupManifest.fileName) continue;
        final target = _safeTarget(vaultRoot, file.name);
        if (target == null) {
          throw BackupException(BackupFailure.unsafeEntry, file.name);
        }
        targets[file] = target;
      }

      final removed = await _clearBackedUpContent(vaultRoot);

      var written = 0;
      var bytes = 0;
      for (final MapEntry(key: file, value: target) in targets.entries) {
        await Directory(p.dirname(target)).create(recursive: true);
        final out = OutputFileStream(target);
        try {
          file.writeContent(out);
        } finally {
          await out.close();
        }
        written++;
        bytes += file.size;
      }

      // Der Index beschreibt jetzt einen Stand, den es nicht mehr gibt.
      // Löschen statt migrieren: er ist aus den Dateien neu aufbaubar, und
      // der nächste Öffnen-Vorgang tut genau das (CLAUDE.md §2.5).
      await _dropIndex(vaultRoot);

      devLog.info(
        'backup',
        'Zurückgespielt: ${described.fileName} '
            '($written Dateien geschrieben, $removed entfernt)',
      );

      return RestoreReport(
        filesWritten: written,
        filesRemoved: removed,
        byteSize: bytes,
        safetyBackup: safety,
      );
    } finally {
      await input.close();
    }
  }

  /// Löscht eine Sicherung.
  Future<void> delete(String archivePath) async {
    await _deleteQuietly(archivePath);
    devLog.info('backup', 'Gelöscht: ${p.basename(archivePath)}');
  }

  /// Kopiert eine Sicherung nach [targetDir] — auf eine zweite Platte, in
  /// eine Cloud, irgendwohin außerhalb des Vaults.
  ///
  /// Ein Backup, das nur im Vault liegt, stirbt mit dem Stick. Deshalb ist
  /// der Export kein Zusatz, sondern der eigentliche Zweck der Liste.
  Future<String> export(String archivePath, String targetDir) async {
    final source = File(archivePath);
    if (!await source.exists()) {
      throw BackupException(BackupFailure.missingArchive, archivePath);
    }
    final target = _freeName(targetDir, p.basename(archivePath));
    try {
      await source.copy(target);
    } on FileSystemException catch (error) {
      throw BackupException(BackupFailure.notWritable, target, error);
    }
    devLog.info('backup', 'Exportiert nach $targetDir');
    return target;
  }

  /// Behält die [keep] jüngsten Sicherungen einer Art und löscht den Rest.
  ///
  /// Nur für die automatisch angelegten Arten gedacht. Was der Nutzer selbst
  /// angelegt hat, löscht die App nicht ungefragt weg.
  Future<int> prune(String vaultRoot, BackupKind kind, {int keep = 5}) async {
    final dir = Directory(_dirFor(vaultRoot, kind));
    if (!await dir.exists()) return 0;

    final matching = <File>[];
    await for (final item in dir.list(followLinks: false)) {
      if (item is File &&
          p.basename(item.path).startsWith('chronicle-${kind.slug}-')) {
        matching.add(item);
      }
    }
    if (matching.length <= keep) return 0;

    // Der Zeitstempel steckt im Dateinamen und ist sortierbar — das spart
    // das Öffnen jedes Archivs nur zum Datumlesen.
    matching.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    var deleted = 0;
    for (final file in matching.skip(keep)) {
      await _deleteQuietly(file.path);
      deleted++;
    }
    return deleted;
  }

  // ── Intern ────────────────────────────────────────────────────────────────

  String _dirFor(String vaultRoot, BackupKind kind) =>
      kind == BackupKind.beforeMigration
      ? VaultLayout.snapshots(vaultRoot)
      : VaultLayout.backups(vaultRoot);

  Future<BackupEntry?> _describe(String archivePath) async {
    final file = File(archivePath);
    if (!await file.exists()) return null;

    BackupManifest? manifest;
    final input = InputFileStream(archivePath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final entry = archive.findFile(BackupManifest.fileName);
      final bytes = entry?.readBytes();
      if (bytes != null) {
        final raw = jsonDecode(utf8.decode(bytes));
        if (raw is Map<String, dynamic>) {
          manifest = BackupManifest.fromJson(raw);
        }
      }
    } on ArchiveException catch (error) {
      devLog.warn('backup', 'Kein lesbares Archiv: $archivePath', error: error);
    } on FormatException catch (error) {
      devLog.warn('backup', 'Manifest unlesbar: $archivePath', error: error);
    } finally {
      await input.close();
    }

    return BackupEntry(
      path: archivePath,
      fileName: p.basename(archivePath),
      archiveBytes: await file.length(),
      manifest: manifest,
    );
  }

  Future<VaultConfig?> _readConfig(String vaultRoot) async {
    final file = File(VaultLayout.config(vaultRoot));
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map<String, dynamic>) return VaultConfig.fromJson(raw);
    } on FormatException catch (error) {
      // Eine kaputte config.json ist kein Grund, das Backup zu verweigern —
      // die Dateien sind die Wahrheit, und genau die sollen gerettet werden.
      devLog.warn('backup', 'config.json unlesbar', error: error);
    }
    return null;
  }

  /// Alle zu sichernden Dateien, Pfade relativ zum Vault-Wurzelverzeichnis.
  Future<List<_Candidate>> _collect(String vaultRoot) async {
    final root = Directory(vaultRoot);
    final out = <_Candidate>[];
    if (!await root.exists()) {
      throw BackupException(BackupFailure.missingArchive, vaultRoot);
    }

    await for (final item in root.list(recursive: true, followLinks: false)) {
      // Symlinks bleiben draußen: ihnen zu folgen könnte halbe Dateisysteme
      // ins Archiv ziehen, und ein Link auf einen Pfad außerhalb des Vaults
      // ist beim Auspacken auf einem anderen Rechner ohnehin tot (§2.2).
      if (item is! File) continue;
      final rel = VaultLayout.relativeTo(vaultRoot, item.path);
      if (!isBackedUp(rel)) continue;
      try {
        out.add(_Candidate(rel, item, await item.length()));
      } on FileSystemException catch (error) {
        // Eine einzelne unlesbare Datei darf das Backup nicht verhindern.
        // Sie fehlt dann im Archiv — sichtbar an der Dateizahl im Manifest.
        devLog.warn('backup', 'Übersprungen: $rel', error: error);
      }
    }
    out.sort((a, b) => a.relPath.compareTo(b.relPath));
    return out;
  }

  /// Entfernt alles, was ein Backup abdecken würde, und räumt leere Ordner ab.
  Future<int> _clearBackedUpContent(String vaultRoot) async {
    var removed = 0;
    for (final candidate in await _collect(vaultRoot)) {
      await _deleteQuietly(candidate.file.path);
      removed++;
    }

    // Leere Ordner von innen nach außen: sonst bleibt nach dem Zurückspielen
    // eines älteren Stands die Ordnerstruktur eines neueren stehen, und im
    // Baum hängen Partien, die es nicht mehr gibt.
    final dirs = <String>[];
    await for (final item in Directory(
      vaultRoot,
    ).list(recursive: true, followLinks: false)) {
      if (item is! Directory) continue;
      final rel = VaultLayout.relativeTo(vaultRoot, item.path);
      if (_isProtectedDir(rel)) continue;
      dirs.add(item.path);
    }
    dirs.sort((a, b) => b.length.compareTo(a.length));
    for (final dir in dirs) {
      final directory = Directory(dir);
      if (await directory.list(followLinks: false).isEmpty) {
        await directory.delete();
      }
    }
    return removed;
  }

  Future<void> _dropIndex(String vaultRoot) async {
    final base = VaultLayout.database(vaultRoot);
    for (final suffix in ['', '-wal', '-shm']) {
      await _deleteQuietly('$base$suffix');
    }
  }

  /// Der Zielpfad für einen Archiv-Eintrag, oder null, wenn er aus dem Vault
  /// herauszeigt.
  ///
  /// „Zip Slip": ein Archiv mit `../../.ssh/authorized_keys` würde beim
  /// naiven Auspacken außerhalb des Vaults schreiben. Backups kommen auch von
  /// fremden Sticks — die Prüfung ist hier kein Theoriefall.
  String? _safeTarget(String vaultRoot, String entryName) {
    final normalized = p.normalize(entryName.replaceAll('\\', '/'));
    if (normalized.isEmpty || p.isAbsolute(normalized)) return null;
    if (p.split(normalized).contains('..')) return null;

    final target = p.normalize(p.join(vaultRoot, normalized));
    final root = p.normalize(vaultRoot);
    if (!p.isWithin(root, target)) return null;
    return target;
  }

  String _freeName(String dir, String fileName) {
    var candidate = p.join(dir, fileName);
    if (!File(candidate).existsSync()) return candidate;

    final stem = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    for (var i = 2; i < 1000; i++) {
      candidate = p.join(dir, '$stem-$i$ext');
      if (!File(candidate).existsSync()) return candidate;
    }
    return candidate;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      devLog.warn('backup', 'Nicht löschbar: $path', error: error);
    }
  }

  String _nameFromPath(String vaultRoot) {
    final parts = p.split(vaultRoot)..removeWhere((s) => s.isEmpty);
    return parts.isEmpty ? 'Vault' : parts.last;
  }

  static String _stamp(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}'
        '-${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }

  /// Ob [relPath] (relativ zum Vault-Wurzelverzeichnis, mit `/`) ins Backup
  /// gehört.
  ///
  /// Die eine Stelle, an der das entschieden wird — sie bestimmt zugleich,
  /// was beim Zurückspielen geräumt wird. Zwei getrennte Listen wären
  /// garantiert irgendwann uneinig, und das Ergebnis wäre ein Vault, in dem
  /// nach der Wiederherstellung Reste eines anderen Stands liegen.
  static bool isBackedUp(String relPath) {
    final segments = p.split(relPath.replaceAll('\\', '/'));
    if (segments.isEmpty) return false;

    // Die Schreibprobe aus VaultManager — ein Artefakt, kein Inhalt.
    if (segments.first == '.chronicle-write-test') return false;

    // Versionsverwaltung bringt ihre eigene Historie mit und würde das
    // Archiv vervielfachen.
    if (segments.first == '.git') return false;

    if (segments.first != VaultLayout.metaDir) return true;

    // Aus `.chronicle/` kommt nur mit, was NICHT regenerierbar ist.
    if (segments.length < 2) return false;
    final inner = segments[1];
    if (inner == VaultLayout.thumbnailsDir) return false;
    if (inner == VaultLayout.backupsDir) return false;
    if (inner == VaultLayout.snapshotsDir) return false;
    if (inner.startsWith(VaultLayout.indexDb)) return false;
    return true;
  }

  /// Ordner, die beim Räumen stehen bleiben, auch wenn sie leer sind.
  static bool _isProtectedDir(String relPath) {
    final segments = p.split(relPath.replaceAll('\\', '/'));
    if (segments.isEmpty) return true;
    if (segments.first == '.git') return true;
    if (segments.first != VaultLayout.metaDir) {
      // Die drei Ordner der obersten Ebene gehören zum Vault-Gerüst und
      // werden beim Öffnen ohnehin wieder angelegt — sie jetzt zu löschen,
      // nur um sie gleich neu zu erzeugen, ist sinnlose Schreiblast.
      return segments.length == 1 &&
          VaultLayout.topLevelDirs.contains(segments.first);
    }
    return true;
  }
}

/// Ein Wert, der im UI erklärt, warum eine Sicherung scheiterte.
extension BackupExceptionMessage on Object {
  /// Der Text für eine Fehlermeldung, egal welcher Fehlertyp ankommt.
  String get backupMessage => switch (this) {
    BackupException(:final message) => message,
    VaultException(:final message) => message,
    _ => toString(),
  };
}
