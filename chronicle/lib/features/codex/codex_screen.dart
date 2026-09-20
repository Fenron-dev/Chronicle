// Datei: chronicle/lib/features/codex/codex_screen.dart
//
// ZWECK: Codex-Seiten (Konzept §4.2) — kuratiertes Markdown mit zwei Ansichten:
//        Quelltext zum Schreiben, Lesefassung zum Nachschlagen.
//
// ZWEI ANSICHTEN, KEIN WYSIWYG: Die Datei bleibt gewöhnliches Markdown und
//        damit in Obsidian und jedem Texteditor lesbar (CLAUDE.md §2.2). Ein
//        WYSIWYG-Editor müsste beim Tippen zurückschreiben und würde genau
//        diese Zusage aufweichen.
//
// UNGESPEICHERTES WIRD NICHT STILL VERWORFEN: Wer die Seite wechselt, während
//        etwas offen ist, wird gefragt. Im Journal steht oft der einzige
//        Absatz, den jemand heute geschrieben hat.
//
// SCHRITT: 5

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
import '../../data/db/vault_note.dart';
import '../../data/vault/codex_repository.dart';
import '../../domain/markdown/md_node.dart';
import '../../domain/wikilink/wikilink.dart';
import 'codex_providers.dart';
import 'markdown_view.dart';

/// Quelltext oder Lesefassung.
enum CodexMode { source, reading }

class CodexScreen extends ConsumerStatefulWidget {
  const CodexScreen({super.key});

  @override
  ConsumerState<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends ConsumerState<CodexScreen> {
  final TextEditingController _editor = TextEditingController();
  final FocusNode _focus = FocusNode();

  CodexMode _mode = CodexMode.reading;

  /// Der Stand, wie er in der Datei steht. Der Vergleich damit entscheidet,
  /// ob es etwas zu speichern gibt — ein reines „wurde getippt"-Flag bliebe
  /// auch dann gesetzt, wenn man die Änderung wieder zurücknimmt.
  String _saved = '';
  String _savedPath = '';
  bool _busy = false;

  bool get _dirty => _editor.text != _saved;

  @override
  void dispose() {
    _editor.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Übernimmt den Dateiinhalt in den Editor, wenn eine andere Seite kommt.
  ///
  /// Nur beim Pfadwechsel: sonst würde jeder Rebuild — etwa nach dem
  /// Speichern — die Einfügemarke an den Anfang zurückwerfen.
  void _syncEditor(CodexPage? page) {
    if (page == null) {
      if (_savedPath.isEmpty) return;
      _savedPath = '';
      _saved = '';
      _editor.clear();
      return;
    }
    if (page.relPath == _savedPath) return;
    _savedPath = page.relPath;
    _saved = page.body;
    _editor.text = page.body;
  }

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(codexPagesProvider);
    final page = ref.watch(activeCodexPageProvider);

    // In build statt in einem Listener: der Editor muss zu der Seite passen,
    // die gerade gerendert wird.
    _syncEditor(page.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PageBar(
          pages: pages.value ?? const [],
          current: page.value,
          mode: _mode,
          dirty: _dirty,
          busy: _busy,
          onSelect: _select,
          onMode: (mode) => setState(() => _mode = mode),
          onCreate: _create,
          onSave: _save,
          onDelete: _delete,
        ),
        Expanded(
          child: switch ((pages, page.value)) {
            (AsyncLoading(), _) => const Center(
              child: CircularProgressIndicator(),
            ),
            (AsyncError(:final error), _) => _Notice(message: '$error'),
            (AsyncData(:final value), null) when value.isEmpty => const _Notice(
              message:
                  'Noch keine Codex-Seite. Hier entstehen Orte, Personen '
                  'und alles, was du wiederfinden willst — kuratiert, nicht '
                  'chronologisch wie das Play-Log.',
            ),
            (AsyncData(), null) => const _Notice(
              message: 'Wähle oben eine Seite.',
            ),
            (AsyncData(), CodexPage()) =>
              _mode == CodexMode.source
                  ? _SourceEditor(controller: _editor, focus: _focus)
                  : _Reading(onWikiLinkTap: _openLink),
            // Kein Default-Zweig: AsyncValue ist versiegelt, und die fünf
            // Fälle decken es vollständig ab. Ein `_` wäre unerreichbar —
            // und würde einen sechsten Fall später stumm verschlucken.
          },
        ),
      ],
    );
  }

  Future<void> _select(String relPath) async {
    if (!await _confirmDiscard()) return;
    ref.read(selectedCodexPageProvider.notifier).select(relPath);
  }

  Future<void> _create() async {
    if (!await _confirmDiscard()) return;
    if (!mounted) return;

    final title = await _promptForTitle(context);
    if (title == null) return;
    await _run(() => ref.read(codexActionsProvider).create(title));
  }

  Future<void> _save() async {
    await _run(() => ref.read(codexActionsProvider).save(body: _editor.text));
    if (!mounted) return;
    setState(() => _saved = _editor.text);
  }

  Future<void> _delete(VaultNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${note.title}" löschen?'),
        content: const Text(
          'Die Datei wird entfernt. Die gespeicherten Fassungen der Seite '
          'bleiben erhalten — der Text lässt sich also zurückholen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => ref.read(codexActionsProvider).delete(note.relPath));
  }

  Future<void> _openLink(WikiLink link) async {
    if (!await _confirmDiscard()) return;
    await _run(() => ref.read(codexActionsProvider).openOrCreate(link));
  }

  /// Fragt nach, wenn Ungespeichertes offen ist. `true` heißt: weitermachen.
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;

    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ungespeicherte Änderungen'),
        content: const Text(
          'Diese Seite hat Änderungen, die noch nicht in der Datei stehen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Verwerfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (choice == null) return false;
    if (choice) await _save();
    return true;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

Future<String?> _promptForTitle(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Neue Codex-Seite'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Titel',
          hintText: 'z. B. Die Grafschaft Mörwald',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Anlegen'),
        ),
      ],
    ),
  ).then((value) {
    controller.dispose();
    return value == null || value.isEmpty ? null : value;
  });
}

/// Kopfzeile: Seitenwahl, Ansicht, Speichern.
class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.pages,
    required this.current,
    required this.mode,
    required this.dirty,
    required this.busy,
    required this.onSelect,
    required this.onMode,
    required this.onCreate,
    required this.onSave,
    required this.onDelete,
  });

  final List<VaultNote> pages;
  final CodexPage? current;
  final CodexMode mode;
  final bool dirty;
  final bool busy;
  final ValueChanged<String> onSelect;
  final ValueChanged<CodexMode> onMode;
  final VoidCallback onCreate;
  final VoidCallback onSave;
  final ValueChanged<VaultNote> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    current?.title ?? 'Codex',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (dirty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Tooltip(
                      message: 'Nicht gespeichert',
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: palette.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (pages.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Seite wählen',
              icon: const Icon(Icons.menu_book_outlined),
              enabled: !busy,
              onSelected: onSelect,
              itemBuilder: (_) => [
                for (final page in pages)
                  PopupMenuItem<String>(
                    value: page.relPath,
                    child: Text(page.title),
                  ),
              ],
            ),
          SegmentedButton<CodexMode>(
            segments: const [
              ButtonSegment(
                value: CodexMode.reading,
                icon: Icon(Icons.chrome_reader_mode_outlined, size: 18),
                tooltip: 'Lesen',
              ),
              ButtonSegment(
                value: CodexMode.source,
                icon: Icon(Icons.code, size: 18),
                tooltip: 'Quelltext',
              ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: current == null
                ? null
                : (value) => onMode(value.first),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Neue Seite',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: busy ? null : onCreate,
          ),
          IconButton(
            tooltip: 'Speichern',
            icon: const Icon(Icons.save_outlined),
            onPressed: busy || !dirty ? null : onSave,
          ),
          if (current != null)
            PopupMenuButton<String>(
              tooltip: 'Mehr',
              enabled: !busy,
              onSelected: (_) {
                final open = current;
                if (open == null) return;
                for (final note in pages) {
                  if (note.relPath == open.relPath) {
                    onDelete(note);
                    return;
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Seite löschen'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Die Lesefassung.
class _Reading extends ConsumerWidget {
  const _Reading({required this.onWikiLinkTap});

  final void Function(WikiLink link) onWikiLinkTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(activeCodexBlocksProvider);
    final targets = ref.watch(linkTargetsProvider).value ?? const {};

    return switch (blocks) {
      AsyncData(:final value) => _ReadingBody(
        blocks: value,
        // Was der Index nicht kennt, gibt es noch nicht. Solche Links werden
        // markiert statt versteckt (Skill `vault-format`).
        unresolved: {
          for (final target in _targetsIn(value))
            if (!targets.containsKey(target.toLowerCase())) target,
        },
        onWikiLinkTap: onWikiLinkTap,
      ),
      AsyncError(:final error) => _Notice(message: '$error'),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// Sammelt alle Wikilink-Ziele eines Dokuments.
Set<String> _targetsIn(List<MdBlock> blocks) {
  final out = <String>{};

  void walkInline(List<MdInline> nodes) {
    for (final node in nodes) {
      switch (node) {
        case MdWikiLink(:final link):
          out.add(link.target);
        case MdStyled(:final content):
          walkInline(content);
        case MdLink(:final content):
          walkInline(content);
        case MdText() ||
            MdCodeSpan() ||
            MdEmbed() ||
            MdImage() ||
            MdLineBreak():
          break;
      }
    }
  }

  void walkBlocks(List<MdBlock> list) {
    for (final block in list) {
      switch (block) {
        case MdHeading(:final content):
          walkInline(content);
        case MdParagraph(:final content):
          walkInline(content);
        case MdQuote(:final content):
          walkBlocks(content);
        case MdCallout(:final title, :final content):
          if (title != null) walkInline(title);
          walkBlocks(content);
        case MdList(:final items):
          for (final item in items) {
            walkBlocks(item.content);
          }
        case MdTable(:final header, :final rows):
          for (final cell in header) {
            walkInline(cell);
          }
          for (final row in rows) {
            for (final cell in row) {
              walkInline(cell);
            }
          }
        case MdCode() || MdRule() || MdEmbedBlock():
          break;
      }
    }
  }

  walkBlocks(blocks);
  return out;
}

class _ReadingBody extends StatelessWidget {
  const _ReadingBody({
    required this.blocks,
    required this.unresolved,
    required this.onWikiLinkTap,
  });

  final List<MdBlock> blocks;
  final Set<String> unresolved;
  final void Function(WikiLink link) onWikiLinkTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxReadingWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          child: MarkdownView(
            blocks: blocks,
            unresolvedTargets: unresolved,
            onWikiLinkTap: onWikiLinkTap,
          ),
        ),
      ),
    );
  }
}

/// Der Quelltext-Editor.
class _SourceEditor extends StatelessWidget {
  const _SourceEditor({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxReadingWidth),
          // SizedBox.expand ist hier Pflicht, kein Layout-Geschmack:
          // `expands: true` verlangt eine feste Höhe, und Center gibt lose
          // Constraints weiter. Ohne das bricht der Editor mit einer
          // Assertion statt zu rendern.
          child: SizedBox.expand(
            child: Container(
              decoration: BoxDecoration(
                color: palette.surfaceSunken,
                borderRadius: context.skin.radius(RadiusToken.card),
                border: Border.all(color: palette.border),
              ),
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: controller,
                focusNode: focus,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontFamily: context.typography.mono,
                  fontSize: 13,
                  height: 1.5,
                  color: palette.textPrimary,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: '# Überschrift\n\nText, [[Verweise]], > [!lore] …',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.palette.textMuted),
        ),
      ),
    );
  }
}
