// Datei: chronicle/lib/data/vault/vault_config.dart
//
// ZWECK: `.chronicle/config.json` — die Einstellungen eines Vaults.
//
// WAS HIER NICHT HINEINGEHÖRT: Maschinenspezifisches (Fensterposition,
//        zuletzt geöffnete Vaults). Der Vault wandert auf einem Stick
//        zwischen Rechnern; solche Werte gehören in shared_preferences.
//        Und niemals API-Keys (CLAUDE.md §2.4).
//
// SIEHE: Skill `vault-format`
// SCHRITT: 3

import 'dart:convert';

/// Einstellungen eines Vaults.
class VaultConfig {
  const VaultConfig({
    required this.id,
    required this.name,
    required this.created,
    this.schemaVersion = currentSchemaVersion,
    this.activeGameId,
    this.themePresetId,
  });

  /// Aktuelle Schema-Version des Vault-Formats.
  ///
  /// Wird bei jeder Formatänderung erhöht; die Migration legt vorher einen
  /// Snapshot an (siehe Skill `vault-format`).
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String name;
  final DateTime created;

  /// Zuletzt geöffnete Partie. Darf auf ein gelöschtes Game zeigen — der
  /// Aufrufer prüft das und fällt sonst auf „keine Partie" zurück.
  final String? activeGameId;

  /// Theme-Override auf Vault-Ebene. Normalerweise null: das Theme kommt vom
  /// System, überschrieben vom Game.
  final String? themePresetId;

  factory VaultConfig.fromJson(Map<String, dynamic> json) => VaultConfig(
    schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Vault',
    created:
        DateTime.tryParse(json['created'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    activeGameId: json['activeGameId'] as String?,
    themePresetId: json['themePresetId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'created': created.toUtc().toIso8601String(),
    if (activeGameId != null) 'activeGameId': activeGameId,
    if (themePresetId != null) 'themePresetId': themePresetId,
  };

  /// Eingerückt geschrieben: die Datei soll von Hand lesbar und in git
  /// zeilenweise diffbar sein.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  VaultConfig copyWith({String? activeGameId, String? themePresetId}) =>
      VaultConfig(
        schemaVersion: schemaVersion,
        id: id,
        name: name,
        created: created,
        activeGameId: activeGameId ?? this.activeGameId,
        themePresetId: themePresetId ?? this.themePresetId,
      );
}
