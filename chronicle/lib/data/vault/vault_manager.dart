// Datei: chronicle/lib/data/vault/vault_manager.dart
//
// ZWECK: Vaults anlegen, öffnen und prüfen. Die einzige Stelle, die die
//        Ordnerstruktur erzeugt.
//
// WARUM SO VIEL FEHLERBEHANDLUNG: Ein Vault kann auf einem USB-Stick liegen,
//        der mitten im Schreiben abgezogen wird. Das ist hier kein Randfall,
//        sondern der Regelfall, für den die App gebaut ist.
//
// SIEHE: Skill `vault-format`
// SCHRITT: 3

import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/dev_log.dart';

import 'vault.dart';
import 'vault_config.dart';
import 'vault_layout.dart';

const Uuid _uuid = Uuid();

/// Legt Vaults an und öffnet sie.
class VaultManager {
  const VaultManager();

  /// Ob [rootPath] wie ein Chronicle-Vault aussieht.
  ///
  /// Geprüft wird nur `.chronicle/` — nicht config.json. Ein Vault mit
  /// kaputter Konfiguration ist immer noch ein Vault, dessen Dateien gerettet
  /// werden können.
  Future<bool> isVault(String rootPath) =>
      Directory(VaultLayout.meta(rootPath)).exists();

  /// Legt einen neuen Vault in [rootPath] an.
  ///
  /// Der Ordner darf existieren und Inhalt haben — so lässt sich ein
  /// bestehender Notizordner zum Vault machen, wie in Obsidian.
  Future<Vault> create(String rootPath, {required String name}) async {
    final root = Directory(rootPath);
    try {
      await root.create(recursive: true);
    } on FileSystemException catch (error) {
      devLog.error('vault', 'Ordner nicht anlegbar', error: error);
      throw VaultException(VaultOpenFailure.notWritable, rootPath, error);
    }

    if (!await _isWritable(rootPath)) {
      throw VaultException(VaultOpenFailure.notWritable, rootPath);
    }

    for (final dir in VaultLayout.topLevelDirs) {
      await Directory('$rootPath/$dir').create(recursive: true);
    }
    await Directory(VaultLayout.meta(rootPath)).create(recursive: true);
    for (final dir in VaultLayout.metaSubDirs) {
      await Directory('${VaultLayout.meta(rootPath)}/$dir').create();
    }

    final config = VaultConfig(
      id: _uuid.v4(),
      name: name,
      created: DateTime.now().toUtc(),
    );
    await File(VaultLayout.config(rootPath)).writeAsString(config.encode());

    // Eine README, die einem Menschen erklärt, was der Ordner ist — er kann
    // auf einem fremden Rechner landen, auf dem Chronicle nicht installiert
    // ist.
    final readme = File(VaultLayout.readme(rootPath));
    if (!await readme.exists()) {
      await readme.writeAsString(_readmeFor(name));
    }

    return Vault(rootPath: rootPath, config: config);
  }

  /// Öffnet den Vault in [rootPath].
  Future<Vault> open(String rootPath) async {
    devLog.info('vault', 'Öffne $rootPath');

    // Die Prüfungen einzeln protokollieren: auf macOS scheitert der Zugriff
    // auf einen Ordner aus der Zuletzt-Liste an der Sandbox, und dann sieht
    // `exists() == false` wie „gelöscht" aus, obwohl der Ordner da ist.
    final exists = await Directory(rootPath).exists();
    devLog.debug('vault', 'Ordner existiert: $exists');
    if (!exists) {
      throw VaultException(VaultOpenFailure.missing, rootPath);
    }

    final looksLikeVault = await isVault(rootPath);
    devLog.debug('vault', '.chronicle/ vorhanden: $looksLikeVault');
    if (!looksLikeVault) {
      throw VaultException(VaultOpenFailure.notAVault, rootPath);
    }

    final configFile = File(VaultLayout.config(rootPath));
    VaultConfig config;
    if (await configFile.exists()) {
      try {
        final raw = jsonDecode(await configFile.readAsString());
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('config.json ist kein Objekt');
        }
        config = VaultConfig.fromJson(raw);
      } on FormatException catch (error) {
        throw VaultException(VaultOpenFailure.brokenConfig, rootPath, error);
      }
    } else {
      // `.chronicle/` da, config.json weg: kein Datenverlust, denn die
      // Dateien sind die Wahrheit. Wir legen eine neue an, statt den Vault
      // zu verweigern.
      config = VaultConfig(
        id: _uuid.v4(),
        name: _nameFromPath(rootPath),
        created: DateTime.now().toUtc(),
      );
      await configFile.writeAsString(config.encode());
    }

    if (config.schemaVersion > VaultConfig.currentSchemaVersion) {
      throw VaultException(VaultOpenFailure.futureSchema, rootPath);
    }

    // Fehlende Ordner nachziehen: ein weitergereichter Vault kann leere
    // Ordner verloren haben, weil viele Packprogramme sie nicht mitnehmen.
    for (final dir in VaultLayout.topLevelDirs) {
      await Directory('$rootPath/$dir').create(recursive: true);
    }
    for (final dir in VaultLayout.metaSubDirs) {
      await Directory('${VaultLayout.meta(rootPath)}/$dir')
          .create(recursive: true);
    }

    devLog.info('vault', 'Geöffnet: ${config.name} (${config.id})');
    return Vault(rootPath: rootPath, config: config);
  }

  /// Schreibt die Konfiguration zurück.
  Future<void> saveConfig(Vault vault) async {
    await File(VaultLayout.config(vault.rootPath))
        .writeAsString(vault.config.encode());
  }

  /// Prüft Schreibrechte, indem tatsächlich geschrieben wird.
  ///
  /// Ein reiner Rechte-Check täuscht bei schreibgeschützten Sticks und
  /// Netzlaufwerken — dort sagt das Dateisystem „darfst du", und der Schreib-
  /// versuch scheitert trotzdem.
  Future<bool> _isWritable(String rootPath) async {
    final probe = File('$rootPath/.chronicle-write-test');
    try {
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on FileSystemException catch (error) {
      devLog.warn('vault', 'Schreibprobe fehlgeschlagen', error: error);
      return false;
    }
  }

  String _nameFromPath(String rootPath) {
    final parts = rootPath.split(RegExp(r'[/\\]'))
      ..removeWhere((s) => s.isEmpty);
    return parts.isEmpty ? 'Vault' : parts.last;
  }

  String _readmeFor(String name) =>
      '# $name\n'
      '\n'
      'Dies ist ein **Chronicle-Vault** — ein portabler Ordner für '
      'Journaling-Solo-RPGs.\n'
      '\n'
      '- `systems/` — Spielsysteme: Regeln, Tabellen, Decks, Vorlagen, Themes\n'
      '- `games/` — laufende Partien: Play-Log, Codex, Entities, Bögen\n'
      '- `media/` — geteilte Bilder, Audio, Video, Dokumente\n'
      '- `.chronicle/` — Index, Cache und Einstellungen\n'
      '\n'
      'Die Markdown-Dateien in diesem Ordner sind die Wahrheit. '
      '`.chronicle/index.db` ist nur ein Suchindex und wird beim Öffnen aus '
      'den Dateien neu aufgebaut — der Ordner lässt sich also gefahrlos '
      'kopieren, weitergeben oder ohne Chronicle in jedem Texteditor lesen.\n';
}
