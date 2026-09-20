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

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/database.dart';
import '../../domain/log/entry_kind.dart';
import '../../domain/slug.dart';
import '../db/vault_note.dart';
import 'index_rebuilder.dart';
import 'recent_vaults_store.dart';
import 'vault.dart';
import 'log_repository.dart';
import 'vault_catalog.dart';
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
VaultCatalog vaultCatalog(Ref ref) => const VaultCatalog();

@Riverpod(keepAlive: true)
LogRepository logRepository(Ref ref) => const LogRepository();

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
  /// Die offene Index-Datenbank, unabhängig vom Provider-Zustand gehalten.
  ///
  /// Beim Entsorgen des Providers ist der Zugriff auf `state` nicht mehr
  /// zulässig — die Datei-Sperre muss aber trotzdem fallen, sonst bleibt sie
  /// auf einem Stick liegen, den der Nutzer gerade abziehen will.
  ChronicleDatabase? _database;

  @override
  Future<VaultSession?> build() async {
    // Beim Start bewusst kein Auto-Open: der Picker ist der erste Screen,
    // und ein Stick, der nicht mehr steckt, darf den Start nicht blockieren.
    ref.onDispose(() {
      _database?.close();
      _database = null;
    });
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
    await _closeDatabase();
    state = const AsyncData(null);
  }

  /// Schreibt die aktive Partie in `.chronicle/config.json`.
  ///
  /// Sie gehört in den Vault und nicht in shared_preferences: Wer den Stick
  /// weiterreicht, soll dort weitermachen, wo der Vorbesitzer war.
  Future<void> setActiveGame(String? gameId) async {
    final session = state.value;
    if (session == null) return;

    final updated = session.vault.withConfig(
      session.vault.config.copyWith(
        activeGameId: gameId,
        clearActiveGame: gameId == null,
      ),
    );
    await ref.read(vaultManagerProvider).saveConfig(updated);

    state = AsyncData(
      VaultSession(
        vault: updated,
        database: session.database,
        report: session.report,
      ),
    );
  }

  /// Baut den Index neu auf, ohne den Vault zu schließen.
  ///
  /// Der manuelle Weg zu „Index neu aufbauen" — und der Fallback, wenn etwas
  /// am Index nicht stimmt. Reparieren wäre der falsche Reflex: ein kaputter
  /// Index ist nie ein Datenverlust.
  Future<void> reindex() async {
    final session = state.value;
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
  /// neuen scheitert — sonst bleibt eine Datei-Sperre zurück.
  Future<void> _replaceWith(Future<VaultSession> Function() open) async {
    state = const AsyncLoading();
    await _closeDatabase();

    state = await AsyncValue.guard(open);

    final session = state.value;
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
    _database = database;

    final scan = await ref.read(vaultScannerProvider).scan(vault.rootPath);
    final report = await IndexRebuilder(database).rebuild(scan);
    return VaultSession(vault: vault, database: database, report: report);
  }

  Future<void> _closeDatabase() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}

/// Ob gerade ein Vault offen ist — das Gate des Routers.
@Riverpod(keepAlive: true)
bool hasOpenVault(Ref ref) => ref.watch(activeVaultProvider).value != null;

/// Alle indizierten Notizen des aktiven Vaults, für den Navigations-Baum.
///
/// Bewusst autoDispose: die Liste wird neu geladen, wenn der Baum wieder
/// sichtbar wird — sie hängt am Index, der sich bei jedem Rebuild ändert.
@riverpod
Future<List<VaultNote>> vaultNotes(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  if (session == null) return const [];
  return session.database.allNotes();
}

/// Volltextsuche im aktiven Vault.
@riverpod
Future<List<NoteSearchHit>> vaultSearch(Ref ref, String query) async {
  final session = ref.watch(activeVaultProvider).value;
  if (session == null) return const [];
  return session.database.search(query);
}

// ── Systeme und Partien ─────────────────────────────────────────────────────

/// Alle Systeme des aktiven Vaults.
@riverpod
Future<List<SystemEntry>> vaultSystems(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  if (session == null) return const [];
  return ref.watch(vaultCatalogProvider).listSystems(session.vault.rootPath);
}

/// Alle Partien des aktiven Vaults, neueste zuerst.
@riverpod
Future<List<GameEntry>> vaultGames(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  if (session == null) return const [];
  return ref.watch(vaultCatalogProvider).listGames(session.vault.rootPath);
}

/// Die aktive Partie, oder null.
///
/// Sie steht in `.chronicle/config.json` und überlebt damit das Schließen der
/// App — aber nicht das Weiterreichen an einen anderen Rechner, denn sie ist
/// eine Vault-Eigenschaft, keine Maschinen-Eigenschaft.
@riverpod
Future<GameEntry?> activeGame(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  if (session == null) return null;

  final activeId = session.vault.config.activeGameId;
  if (activeId == null) return null;

  final games = await ref.watch(vaultGamesProvider.future);
  for (final game in games) {
    if (game.id == activeId) return game;
  }
  // Die Partie wurde außerhalb der App gelöscht. Kein Fehler — der Vault ist
  // ein Ordner, in dem Nutzer arbeiten dürfen.
  return null;
}

/// Legt Systeme und Partien an und hält die aktive Partie fest.
///
/// Bewusst eine schlichte Klasse hinter einem Provider statt eines Notifiers:
/// hier gibt es keinen eigenen Zustand zu halten — nur Aktionen, die andere
/// Provider anstoßen. Ein Notifier mit `void`-Zustand wäre eine Attrappe.
@Riverpod(keepAlive: true)
CatalogActions catalogActions(Ref ref) => CatalogActions(ref);

class CatalogActions {
  const CatalogActions(this._ref);

  final Ref _ref;

  /// Legt ein System an und baut den Index neu auf, damit `rules.md` sofort
  /// im Navigations-Baum erscheint.
  Future<SystemEntry> createSystem(String name) async {
    final session = _requireSession();
    final entry = await _ref
        .read(vaultCatalogProvider)
        .createSystem(session.vault.rootPath, name: name);

    _ref.invalidate(vaultSystemsProvider);
    await _ref.read(activeVaultProvider.notifier).reindex();
    return entry;
  }

  /// Legt eine Partie an und macht sie zur aktiven.
  Future<GameEntry> createGame(String name, String systemId) async {
    final session = _requireSession();
    final entry = await _ref
        .read(vaultCatalogProvider)
        .createGame(session.vault.rootPath, name: name, systemId: systemId);

    _ref.invalidate(vaultGamesProvider);
    await selectGame(entry.id);
    await _ref.read(activeVaultProvider.notifier).reindex();
    return entry;
  }

  /// Macht die Partie mit [gameId] zur aktiven und schreibt das in den Vault.
  Future<void> selectGame(String? gameId) async {
    await _ref.read(activeVaultProvider.notifier).setActiveGame(gameId);
    _ref.invalidate(activeGameProvider);
  }

  VaultSession _requireSession() {
    final session = _ref.read(activeVaultProvider).value;
    if (session == null) {
      // Die UI bietet diese Aktionen nur mit offenem Vault an. Kommt es
      // trotzdem hierher, ist das ein Programmierfehler und soll laut
      // scheitern.
      throw StateError('Kein Vault geöffnet');
    }
    return session;
  }
}

// ── Play-Log ────────────────────────────────────────────────────────────────

/// Die Log-Threads der aktiven Partie, neueste zuerst.
@riverpod
Future<List<VaultNote>> gameLogThreads(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  final game = await ref.watch(activeGameProvider.future);
  if (session == null || game == null) return const [];

  final notes = await session.database.notesOfType('log');
  return notes.where((n) => n.ownerSlug == game.slug).toList();
}

/// Der gerade geöffnete Thread. Null heißt: der erste der Partie.
@Riverpod(keepAlive: true)
class SelectedThread extends _$SelectedThread {
  @override
  String? build() => null;

  void select(String? relPath) => state = relPath;
}

/// Der geladene Thread samt Einträgen.
///
/// Liest die DATEI, nicht den Index: der Index kennt nur Titel und Pfad, die
/// Einträge stehen im Markdown. Genau so ist es gemeint — die Datei ist die
/// Wahrheit.
@riverpod
Future<LogThread?> activeThread(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  if (session == null) return null;

  final threads = await ref.watch(gameLogThreadsProvider.future);
  if (threads.isEmpty) return null;

  final selected = ref.watch(selectedThreadProvider);
  final relPath = threads.any((t) => t.relPath == selected)
      ? selected!
      : threads.first.relPath;

  return ref.read(logRepositoryProvider).load(session.vault.rootPath, relPath);
}

/// Schreibaktionen auf dem Play-Log.
@Riverpod(keepAlive: true)
LogActions logActions(Ref ref) => LogActions(ref);

class LogActions {
  const LogActions(this._ref);

  final Ref _ref;

  /// Hängt einen Eintrag an den offenen Thread an.
  ///
  /// Erst Datei, dann Index — in dieser Reihenfolge, sonst überlebt der
  /// Eintrag den nächsten Rebuild nicht.
  Future<void> appendEntry({
    required EntryKind kind,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final session = _ref.read(activeVaultProvider).value;
    final thread = await _ref.read(activeThreadProvider.future);
    if (session == null || thread == null) return;

    await _ref
        .read(logRepositoryProvider)
        .appendEntry(
          session.vault.rootPath,
          thread.relPath,
          kind: kind,
          text: text,
        );

    _ref.invalidate(activeThreadProvider);
    await _ref.read(activeVaultProvider.notifier).reindex();
  }

  /// Legt einen weiteren Thread in der aktiven Partie an.
  Future<void> createThread(String title) async {
    final session = _ref.read(activeVaultProvider).value;
    final game = await _ref.read(activeGameProvider.future);
    if (session == null || game == null) return;

    final existing = await _ref.read(gameLogThreadsProvider.future);
    final stem = uniqueSlug(title, {
      for (final t in existing) t.relPath.split('/').last.replaceAll('.md', ''),
    });

    final relPath = await _ref
        .read(logRepositoryProvider)
        .createThread(
          session.vault.rootPath,
          game.slug,
          title: title,
          fileStem: stem,
        );

    await _ref.read(activeVaultProvider.notifier).reindex();
    _ref.invalidate(gameLogThreadsProvider);
    _ref.read(selectedThreadProvider.notifier).select(relPath);
  }
}
