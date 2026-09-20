// Datei: chronicle/lib/features/codex/codex_providers.dart
//
// ZWECK: Zustand und Aktionen des Codex — Seitenliste, offene Seite,
//        Speichern, Anlegen, Löschen, Wikilink-Auflösung.
//
// HIER WIRD DIE FASSUNG GESICHERT: Speichern ersetzt den ganzen Rumpf.
//        `NoteSnapshots.record` läuft davor — das ist die Stelle, auf die
//        CLAUDE.md §8 bei Schritt 5 verweist. Der Aufruf steht bewusst hier
//        und nicht im Repository: `data/` darf `services/` nicht kennen.
//
// SCHRITT: 5

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/db/vault_note.dart';
import '../../data/vault/codex_repository.dart';
import '../../data/vault/vault_providers.dart';
import '../../domain/markdown/markdown_parser.dart';
import '../../domain/markdown/md_node.dart';
import '../../domain/slug.dart';
import '../../domain/wikilink/wikilink.dart';
import '../../services/backup/backup_providers.dart';

part 'codex_providers.g.dart';

@Riverpod(keepAlive: true)
CodexRepository codexRepository(Ref ref) => const CodexRepository();

/// Alle Codex-Seiten der aktiven Partie, alphabetisch.
///
/// Alphabetisch und nicht nach Datum: der Codex ist ein Nachschlagewerk. Im
/// Play-Log zählt die Zeit, hier der Name.
@riverpod
Future<List<VaultNote>> codexPages(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  final game = await ref.watch(activeGameProvider.future);
  if (session == null || game == null) return const [];

  final notes = await session.database.notesOfType('codex');
  final mine = notes.where((n) => n.ownerSlug == game.slug).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return mine;
}

/// Welche Seite offen ist. Null heißt: keine — die Liste steht dann allein.
@Riverpod(keepAlive: true)
class SelectedCodexPage extends _$SelectedCodexPage {
  @override
  String? build() => null;

  void select(String? relPath) => state = relPath;
}

/// Die offene Seite, aus der DATEI gelesen.
///
/// Nicht aus dem Index: der kennt nur Titel und Pfad. Der Text steht im
/// Markdown, und die Datei ist die Wahrheit (CLAUDE.md §2.5).
@riverpod
Future<CodexPage?> activeCodexPage(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  final selected = ref.watch(selectedCodexPageProvider);
  if (session == null || selected == null) return null;

  final pages = await ref.watch(codexPagesProvider.future);
  if (!pages.any((p) => p.relPath == selected)) return null;

  return ref
      .read(codexRepositoryProvider)
      .load(session.vault.rootPath, selected);
}

/// Die geparste Fassung der offenen Seite.
///
/// Eigener Provider, damit das Parsen nicht bei jedem Rebuild des Widget-
/// Baums erneut läuft — beim Tippen wäre das pro Tastendruck.
@riverpod
Future<List<MdBlock>> activeCodexBlocks(Ref ref) async {
  final page = await ref.watch(activeCodexPageProvider.future);
  if (page == null) return const [];
  return parseMarkdown(page.body);
}

/// Titel → Pfad, für die Auflösung von `[[Seite]]`.
///
/// Auflösung nach NAMEN, nicht nach Pfad: so überlebt ein Link das
/// Verschieben der Zieldatei (Skill `vault-format`). Kleingeschrieben, weil
/// niemand beim Tippen auf Großschreibung achtet.
@riverpod
Future<Map<String, VaultNote>> linkTargets(Ref ref) async {
  final session = ref.watch(activeVaultProvider).value;
  if (session == null) return const {};

  final notes = await session.database.allNotes();
  final out = <String, VaultNote>{};
  for (final note in notes) {
    // Erster Treffer gewinnt; die Liste kommt sortiert aus dem Index, das
    // Ergebnis ist damit stabil statt zufällig.
    out.putIfAbsent(note.title.toLowerCase(), () => note);
  }
  return out;
}

/// Schreibaktionen auf dem Codex.
@Riverpod(keepAlive: true)
CodexActions codexActions(Ref ref) => CodexActions(ref);

class CodexActions {
  const CodexActions(this._ref);

  final Ref _ref;

  /// Speichert den Rumpf der offenen Seite.
  ///
  /// Reihenfolge: Fassung sichern → Datei schreiben → Index neu aufbauen.
  /// Die Fassung zuerst, weil danach der alte Text weg ist.
  Future<void> save({required String body, String? title}) async {
    final session = _ref.read(activeVaultProvider).value;
    final page = await _ref.read(activeCodexPageProvider.future);
    if (session == null || page == null) return;

    final root = session.vault.rootPath;
    await _ref.read(noteSnapshotsProvider).record(root, page.relPath);
    await _ref
        .read(codexRepositoryProvider)
        .save(root, page.relPath, body: body, title: title);

    _ref.invalidate(activeCodexPageProvider);
    await _ref.read(activeVaultProvider.notifier).reindex();
    _ref.invalidate(codexPagesProvider);
    _ref.invalidate(linkTargetsProvider);
  }

  /// Legt eine Seite an und öffnet sie.
  Future<void> create(String title) async {
    final session = _ref.read(activeVaultProvider).value;
    final game = await _ref.read(activeGameProvider.future);
    if (session == null || game == null) return;

    final existing = await _ref.read(codexPagesProvider.future);
    final stem = uniqueSlug(title, {
      for (final page in existing)
        page.relPath.split('/').last.replaceAll('.md', ''),
    });

    final relPath = await _ref
        .read(codexRepositoryProvider)
        .create(
          session.vault.rootPath,
          game.slug,
          title: title,
          fileStem: stem,
        );

    await _ref.read(activeVaultProvider.notifier).reindex();
    _ref.invalidate(codexPagesProvider);
    _ref.invalidate(linkTargetsProvider);
    _ref.read(selectedCodexPageProvider.notifier).select(relPath);
  }

  /// Löscht eine Seite.
  Future<void> delete(String relPath) async {
    final session = _ref.read(activeVaultProvider).value;
    if (session == null) return;

    await _ref
        .read(codexRepositoryProvider)
        .delete(session.vault.rootPath, relPath);

    if (_ref.read(selectedCodexPageProvider) == relPath) {
      _ref.read(selectedCodexPageProvider.notifier).select(null);
    }
    await _ref.read(activeVaultProvider.notifier).reindex();
    _ref.invalidate(codexPagesProvider);
    _ref.invalidate(linkTargetsProvider);
  }

  /// Öffnet das Ziel eines Wikilinks, oder legt es an, wenn es fehlt.
  ///
  /// Ein Link auf eine noch nicht existierende Seite ist kein Fehler,
  /// sondern die übliche Schreibweise: erst verweisen, dann füllen. Der
  /// Klick macht daraus eine Seite, statt eine Meldung zu zeigen.
  Future<void> openOrCreate(WikiLink link) async {
    final targets = await _ref.read(linkTargetsProvider.future);
    final note = targets[link.target.toLowerCase()];

    if (note == null) {
      await create(link.target);
      return;
    }
    if (note.type == 'codex') {
      _ref.read(selectedCodexPageProvider.notifier).select(note.relPath);
    }
    // Andere Typen (Log-Threads, Regeln) bekommen ihre Navigation, sobald
    // es dafür Ansichten gibt. Bis dahin passiert bewusst nichts, statt den
    // Nutzer auf einen Bildschirm zu werfen, der die Seite nicht zeigt.
  }
}
