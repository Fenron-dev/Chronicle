// Datei: chronicle/lib/data/vault/recent_vaults_store.dart
//
// ZWECK: Liste zuletzt geöffneter Vaults — der Obsidian-artige Picker.
//
// WARUM shared_preferences UND NICHT DER VAULT: Welche Vaults dieser Rechner
//        kennt, ist maschinenspezifisch. Es im Vault abzulegen würde bedeuten,
//        dass ein weitergereichter Stick die Pfade des Vorbesitzers mitbringt
//        (CLAUDE.md §2.2).
//
// SCHRITT: 3

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ein Eintrag der Zuletzt-geöffnet-Liste.
class RecentVault {
  const RecentVault({
    required this.path,
    required this.name,
    required this.lastOpened,
  });

  final String path;
  final String name;
  final DateTime lastOpened;

  factory RecentVault.fromJson(Map<String, dynamic> json) => RecentVault(
    path: json['path'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lastOpened:
        DateTime.tryParse(json['lastOpened'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'lastOpened': lastOpened.toIso8601String(),
  };
}

/// Speichert die Zuletzt-geöffnet-Liste.
class RecentVaultsStore {
  const RecentVaultsStore();

  static const String _key = 'chronicle.recentVaults';

  /// Mehr als das merkt sich ohnehin niemand, und eine lange Liste macht den
  /// Picker unübersichtlich.
  static const int maxEntries = 10;

  Future<List<RecentVault>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = [
        for (final item in decoded)
          if (item is Map<String, dynamic>) RecentVault.fromJson(item),
      ]..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
      return entries.where((e) => e.path.isNotEmpty).toList();
    } on FormatException {
      // Kaputte Liste ist kein Datenverlust — die Vaults selbst liegen auf
      // Platte. Lieber leer anfangen als den Picker blockieren.
      return const [];
    }
  }

  Future<List<RecentVault>> remember(String path, String name) async {
    final current = await load();
    final updated = [
      RecentVault(path: path, name: name, lastOpened: DateTime.now()),
      ...current.where((e) => e.path != path),
    ].take(maxEntries).toList();

    await _save(updated);
    return updated;
  }

  Future<List<RecentVault>> forget(String path) async {
    final updated = (await load()).where((e) => e.path != path).toList();
    await _save(updated);
    return updated;
  }

  Future<void> _save(List<RecentVault> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final entry in entries) entry.toJson()]),
    );
  }
}
