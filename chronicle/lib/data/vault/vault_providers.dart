// Datei: chronicle/lib/data/vault/vault_providers.dart
//
// ZWECK: Der aktive Vault samt geöffnetem Index — der Zustand, an dem die
//        halbe App hängt.
//
// ABLAUF BEIM ÖFFNEN: Ordner prüfen → Index-Datenbank öffnen → aus den
//        Dateien neu aufbauen. Der Rebuild läuft bei JEDEM Öffnen, nicht nur
//        beim ersten: genau das ist die Zusage „Vault auf fremdem Rechner
//        öffnen, alles da".
//
// WARUM keepAlive: Der Vault ist App-Zustand. Würde er beim Verlassen eines
//        Screens entsorgt, schlösse sich die Datenbank mitten im Spiel.
//
// SCHRITT: 3

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/database.dart';
import 'index_rebuilder.dart';
import 'recent_vaults_store.dart';
import 'vault.dart';
import 'vault_layout.dart';
import 'vault_manager.dart';
import 'vault_scanner.dart';

part 'vault_providers.g.dart';

/// Ein geöffneter Vault mit seinem Index.
class VaultSession {
  const VaultSession({
    required this.vault,
    required this.database,
    required this.report,
  });

  final Vault vault;
  final ChronicleDatabase database;

  /// Was der letzte Rebuild ergeben hat — Zähler und übersprungene Dateien.
  final RebuildReport report;

  VaultSession withReport(RebuildReport next) =>
      VaultSession(vault: vault, database: database, report: next);
}

@Riverpod(keepAlive: true)
VaultManager vaultManager(Ref ref) => const VaultManager();

@Riverpod(keepAlive: true)
VaultScanner vaultScanner(Ref ref) => const VaultScanner();

@Riverpod(keepAlive: true)
RecentVaultsStore recentVaultsStore(Ref ref) => const RecentVaultsStore();

/// Die Zuletzt-geöffnet-Liste des Vault-Pickers.
@Riverpod(keepAlive: true)
class RecentVaults extends _$RecentVaults {
  @override
  Future<List<RecentVault>> build() =>
      ref.watch(recentVaultsStoreProvider).load();

  Future<void> forget(String path) async {
    final store = ref.read(recentVaultsStoreProvider);
    state = AsyncData(await store.forget(path));
  }
}

/// Der aktive Vault. `null` bedeutet: noch keiner geöffnet.
@Riverpod(keepAlive: true)
class ActiveVault extends _$ActiveVault {
  @override
  Future<VaultSession?> build() async {
    // Beim Start bewusst kein Auto-Open: der Picker ist der erste Screen,
    // und ein Stick, der nicht mehr steckt, darf den Start nicht blockieren.
    ref.onDispose(() => state.valueOrNull?.database.close());
    return null;
  }

  /// Legt einen Vault an und öffnet ihn.
  Future<void> createAndOpen(String path, String name) async {
    await _replaceWith(() async {
      final vault = await ref
          .read(vaultManagerProvider)
          .create(path, name: name);
      return _openSession(vault);
    });
  }

  /// Öffnet einen bestehenden Vault.
  Future<void> openPath(String path) async {
    await _replaceWith(() async {
      final vault = await ref.read(vaultManagerProvider).open(path);
      return _openSession(vault);
    });
  }

  /// Schließt den aktiven Vault.
  Future<void> close() async {
    await state.valueOrNull?.database.close();
    state = const AsyncData(null);
  }

  /// Baut den Index neu auf, ohne den Vault zu schließen.
  ///
  /// Der manuelle Weg zu „Index neu aufbauen" — und der Fallback, wenn etwas
  /// am Index nicht stimmt. Reparieren wäre der falsche Reflex: ein kaputter
  /// Index ist nie ein Datenverlust.
  Future<void> reindex() async {
    final session = state.valueOrNull;
    if (session == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final scan = await ref
          .read(vaultScannerProvider)
          .scan(session.vault.rootPath);
      final report = await IndexRebuilder(session.database).rebuild(scan);
      return session.withReport(report);
    });
  }

  /// Schließt die alte Sitzung und ersetzt sie durch das Ergebnis von [open].
  ///
  /// Die alte Datenbank wird IMMER geschlossen, auch wenn das Öffnen der
  /// neuen scheitert — sonst bleibt eine Datei-Sperre auf einem Stick
  /// zurück, den der Nutzer gleich abziehen will.
  Future<void> _replaceWith(Future<VaultSession> Function() open) async {
    final previous = state.valueOrNull;
    state = const AsyncLoading();
    await previous?.database.close();

    state = await AsyncValue.guard(open);

    final session = state.valueOrNull;
    if (session != null) {
      await ref
          .read(recentVaultsStoreProvider)
          .remember(session.vault.rootPath, session.vault.name);
      ref.invalidate(recentVaultsProvider);
    }
  }

  Future<VaultSession> _openSession(Vault vault) async {
    final database = ChronicleDatabase.forFile(
      File(VaultLayout.database(vault.rootPath)),
    );
    final scan = await ref.read(vaultScannerProvider).scan(vault.rootPath);
    final report = await IndexRebuilder(database).rebuild(scan);
    return VaultSession(vault: vault, database: database, report: report);
  }
}

/// Ob gerade ein Vault offen ist — das Gate des Routers.
@Riverpod(keepAlive: true)
bool hasOpenVault(Ref ref) =>
    ref.watch(activeVaultProvider).valueOrNull != null;

/// Alle indizierten Notizen des aktiven Vaults, für den Navigations-Baum.
///
/// Bewusst autoDispose: die Liste wird neu geladen, wenn der Baum wieder
/// sichtbar wird — sie hängt am Index, der sich bei jedem Rebuild ändert.
@riverpod
Future<List<Note>> vaultNotes(Ref ref) async {
  final session = ref.watch(activeVaultProvider).valueOrNull;
  if (session == null) return const [];

  final db = session.database;
  return (db.select(db.notes)..orderBy([
        (t) => OrderingTerm.asc(t.scope),
        (t) => OrderingTerm.asc(t.relPath),
      ]))
      .get();
}

/// Volltextsuche im aktiven Vault.
@riverpod
Future<List<NoteSearchHit>> vaultSearch(Ref ref, String query) async {
  final session = ref.watch(activeVaultProvider).valueOrNull;
  if (session == null) return const [];
  return session.database.search(query);
}
