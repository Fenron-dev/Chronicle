// Datei: chronicle/lib/data/vault/vault_layout.dart
//
// ZWECK: Das On-Disk-Layout eines Vaults an einer Stelle. Jeder Pfad im Vault
//        wird hier gebildet — nirgends sonst ein zusammengesetzter String.
//
// WARUM: Ein hartkodierter Pfad an einer zweiten Stelle bricht beim nächsten
//        Layout-Wechsel genau dort, wo niemand sucht.
//
// SIEHE: Skill `vault-format`
// SCHRITT: 3

import 'package:path/path.dart' as p;

/// Ordner- und Dateinamen eines Vaults.
abstract final class VaultLayout {
  /// Alles Regenerierbare und alle Vault-Einstellungen.
  static const String metaDir = '.chronicle';

  static const String indexDb = 'index.db';
  static const String thumbnailsDir = 'thumbnails';
  static const String snapshotsDir = 'snapshots';
  static const String backupsDir = 'backups';
  static const String configFile = 'config.json';

  static const String systemsDir = 'systems';
  static const String gamesDir = 'games';
  static const String mediaDir = 'media';
  static const String readmeFile = 'README.md';

  /// Ordner, die beim Anlegen eines Vaults entstehen.
  static const List<String> topLevelDirs = [systemsDir, gamesDir, mediaDir];

  /// Ordner unterhalb von [metaDir].
  static const List<String> metaSubDirs = [
    thumbnailsDir,
    snapshotsDir,
    backupsDir,
  ];

  static String meta(String root) => p.join(root, metaDir);
  static String config(String root) => p.join(root, metaDir, configFile);
  static String database(String root) => p.join(root, metaDir, indexDb);
  static String thumbnails(String root) => p.join(root, metaDir, thumbnailsDir);
  static String snapshots(String root) => p.join(root, metaDir, snapshotsDir);
  static String backups(String root) => p.join(root, metaDir, backupsDir);
  static String systems(String root) => p.join(root, systemsDir);
  static String games(String root) => p.join(root, gamesDir);
  static String media(String root) => p.join(root, mediaDir);
  static String readme(String root) => p.join(root, readmeFile);

  /// Ob [relativePath] beim Scan übersprungen wird.
  ///
  /// `.chronicle/` ist Cache und Einstellungen, nicht Inhalt. Versteckte
  /// Ordner gehören anderen Werkzeugen (`.git`, `.obsidian`) und sind nicht
  /// unsere.
  static bool isIgnored(String relativePath) {
    for (final segment in p.split(relativePath)) {
      if (segment.startsWith('.')) return true;
    }
    return false;
  }

  /// Pfad relativ zum Vault-Wurzelverzeichnis, immer mit `/` als Trenner.
  ///
  /// Absolute Pfade brechen die Portabilität (CLAUDE.md §2.2), und ein unter
  /// Windows gespeicherter Backslash-Pfad wäre auf dem Stick unter Linux
  /// nicht auffindbar.
  static String relativeTo(String root, String absolutePath) =>
      p.split(p.relative(absolutePath, from: root)).join('/');
}
