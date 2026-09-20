// Datei: chronicle/lib/features/codex/markdown_view.dart
//
// ZWECK: [MdBlock]-Liste → Widget-Baum. Die Lese-Ansicht des Codex.
//
// WARUM SELBST GEBAUT: Ein fertiges Markdown-Widget kennt weder unsere
//        Theme-Tokens noch Callouts, Wikilinks und Embeds. Es würde mit
//        eigenen Farben rendern und damit alle vier Presets gleichzeitig
//        brechen (Skill `chronicle-theme`). Das Paket `flutter_markdown`
//        wird zudem nicht mehr gepflegt.
//
// KEINE HARTKODIERTE FARBE: jede Farbe kommt aus [ChroniclePalette], jeder
//        Radius aus [ChronicleSkin]. Das ist hier keine Formsache — der
//        Codex ist die Ansicht, an der man ein Preset überhaupt erkennt.
//
// SIEHE: Skills `chronicle-theme`, `vault-format`
// SCHRITT: 5

import 'package:flutter/material.dart';

import '../../core/theme/chronicle_palette.dart';
import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';
import '../../domain/markdown/md_node.dart';
import '../../domain/wikilink/wikilink.dart';

/// Rendert ein geparstes Markdown-Dokument.
class MarkdownView extends StatelessWidget {
  const MarkdownView({
    required this.blocks,
    super.key,
    this.onWikiLinkTap,
    this.embedBuilder,
    this.unresolvedTargets = const {},
  });

  final List<MdBlock> blocks;

  /// Klick auf `[[Seite]]`. Null heißt: Links werden dargestellt, sind aber
  /// nicht anklickbar — etwa in einer Vorschau.
  final void Function(WikiLink link)? onWikiLinkTap;

  /// Baut die Darstellung für `![[bild.png]]`. Null heißt: Platzhalter.
  final Widget Function(BuildContext context, WikiLink link)? embedBuilder;

  /// Ziele, die es (noch) nicht gibt. Sie werden markiert statt versteckt:
  /// Der Nutzer schreibt den Link oft, bevor das Ziel existiert (Skill
  /// `vault-format`).
  final Set<String> unresolvedTargets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) _MdBlockView(block: block, view: this),
      ],
    );
  }
}

class _MdBlockView extends StatelessWidget {
  const _MdBlockView({required this.block, required this.view});

  final MdBlock block;
  final MarkdownView view;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    // Versiegelt: kommt ein Blocktyp dazu, meldet der Analyzer diese Stelle,
    // statt ihn still zu verschlucken.
    switch (block) {
      case MdHeading(:final level, :final content):
        final style = switch (level) {
          1 => textTheme.headlineMedium,
          2 => textTheme.headlineSmall,
          3 => textTheme.titleLarge,
          4 => textTheme.titleMedium,
          _ => textTheme.titleSmall,
        };
        return Padding(
          padding: EdgeInsets.only(top: level <= 2 ? 24 : 18, bottom: 8),
          child: _inlineText(
            context,
            content,
            style?.copyWith(color: palette.textHeading),
          ),
        );

      case MdParagraph(:final content):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _inlineText(context, content, textTheme.bodyLarge),
        );

      case MdRule():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Divider(color: palette.divider, height: 1),
        );

      case MdCode(:final text, :final language):
        return _CodeBlock(text: text, language: language);

      case MdQuote(:final content):
        return _Quote(content: content, view: view);

      case final MdCallout callout:
        return _Callout(callout: callout, view: view);

      case MdList(:final ordered, :final items, :final start):
        return _ListBlock(
          ordered: ordered,
          items: items,
          start: start,
          view: view,
        );

      case MdEmbedBlock(:final link):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child:
              view.embedBuilder?.call(context, link) ??
              _EmbedPlaceholder(link: link),
        );

      case final MdTable table:
        return _TableBlock(table: table, view: view);
    }
  }

  Widget _inlineText(
    BuildContext context,
    List<MdInline> content,
    TextStyle? style,
  ) => SelectableText.rich(
    TextSpan(children: _spans(context, content, view)),
    style: style,
  );
}

// ── Inline ──────────────────────────────────────────────────────────────────

/// Übersetzt Inline-Knoten in [InlineSpan]s.
///
/// Als freie Funktion statt als Widget: Text muss in EINEM [RichText] landen,
/// sonst bricht er nicht sauber um und lässt sich nicht am Stück markieren.
List<InlineSpan> _spans(
  BuildContext context,
  List<MdInline> nodes,
  MarkdownView view,
) {
  final palette = context.palette;
  final typography = context.typography;
  final spans = <InlineSpan>[];

  for (final node in nodes) {
    switch (node) {
      case MdText(:final text):
        spans.add(TextSpan(text: text));

      case MdLineBreak():
        spans.add(const TextSpan(text: '\n'));

      case MdStyled(:final style, :final content):
        spans.add(
          TextSpan(
            style: switch (style) {
              MdStyle.bold => TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.textBold,
              ),
              MdStyle.italic => const TextStyle(fontStyle: FontStyle.italic),
              MdStyle.strikethrough => TextStyle(
                decoration: TextDecoration.lineThrough,
                color: palette.textMuted,
              ),
            },
            children: _spans(context, content, view),
          ),
        );

      case MdCodeSpan(:final text):
        spans.add(
          TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: typography.mono,
              fontSize: 13,
              color: palette.textHighlight,
              backgroundColor: palette.surfaceSunken,
            ),
          ),
        );

      case MdLink(:final href, :final content):
        // Bewusst NICHT anklickbar: ein Klick würde den Browser öffnen, und
        // das verletzt offline-first (CLAUDE.md §2.3). Die Adresse steht im
        // Tooltip, kopieren kann man sie aus der Quelltext-Ansicht.
        spans.add(
          TextSpan(
            style: TextStyle(
              color: palette.textLink,
              decoration: TextDecoration.underline,
              decorationColor: palette.textLink.withValues(alpha: 0.4),
            ),
            children: _spans(context, content, view),
            semanticsLabel: href,
          ),
        );

      case MdWikiLink(:final link):
        spans.add(_wikiLinkSpan(context, link, view));

      case MdEmbed(:final link):
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child:
                view.embedBuilder?.call(context, link) ??
                _EmbedChip(link: link),
          ),
        );

      case MdImage(:final alt, :final src):
        // Ein Markdown-Bild zeigt seinen Alternativtext. Bilder kommen im
        // Vault über `![[…]]`; `![](…)` ist der Import-Fall aus fremden
        // Dateien und soll wenigstens lesbar bleiben.
        spans.add(
          TextSpan(
            text: alt?.isNotEmpty ?? false ? alt : src,
            style: TextStyle(color: palette.textMuted),
          ),
        );
    }
  }

  return spans;
}

InlineSpan _wikiLinkSpan(
  BuildContext context,
  WikiLink link,
  MarkdownView view,
) {
  final palette = context.palette;
  final unresolved = view.unresolvedTargets.contains(link.target);

  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: _WikiLinkChip(
      link: link,
      unresolved: unresolved,
      onTap: view.onWikiLinkTap == null
          ? null
          : () => view.onWikiLinkTap!(link),
      color: unresolved ? palette.textMuted : palette.textLink,
    ),
  );
}

class _WikiLinkChip extends StatelessWidget {
  const _WikiLinkChip({
    required this.link,
    required this.unresolved,
    required this.color,
    this.onTap,
  });

  final WikiLink link;
  final bool unresolved;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.copyWith(
      color: color,
      decoration: TextDecoration.underline,
      // Gestrichelt für ein Ziel, das es noch nicht gibt — sichtbar, aber
      // nicht wie ein Fehler. Der Link wird oft vor dem Ziel geschrieben.
      decorationStyle: unresolved
          ? TextDecorationStyle.dashed
          : TextDecorationStyle.solid,
      decorationColor: color.withValues(alpha: 0.5),
    );

    return Tooltip(
      message: unresolved
          ? '${link.target} — noch nicht angelegt'
          : link.target,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Text(link.displayText, style: style),
        ),
      ),
    );
  }
}

// ── Blöcke ──────────────────────────────────────────────────────────────────

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text, this.language});

  final String text;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.surfaceSunken,
          borderRadius: context.skin.radius(RadiusToken.card),
          border: Border.all(color: palette.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (language != null) ...[
              Text(
                language!,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.textMuted),
              ),
              const SizedBox(height: 6),
            ],
            SelectableText(
              text,
              style: TextStyle(
                fontFamily: context.typography.mono,
                fontSize: 13,
                height: 1.45,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.content, required this.view});

  final List<MdBlock> content;
  final MarkdownView view;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: palette.borderStrong, width: 3),
          ),
        ),
        padding: const EdgeInsets.only(left: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final block in content) _MdBlockView(block: block, view: view),
          ],
        ),
      ),
    );
  }
}

/// Ein Callout. Klappbar, wenn `> [!note]-` geschrieben wurde.
class _Callout extends StatefulWidget {
  const _Callout({required this.callout, required this.view});

  final MdCallout callout;
  final MarkdownView view;

  @override
  State<_Callout> createState() => _CalloutState();
}

class _CalloutState extends State<_Callout> {
  late bool _open = !widget.callout.folded;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;
    final style = _calloutStyle(widget.callout.kind, palette);
    final hasBody = widget.callout.content.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: style.surface,
          borderRadius: skin.radius(RadiusToken.card),
          border: Border(
            left: BorderSide(color: style.accent, width: 3),
            top: BorderSide(color: palette.border),
            right: BorderSide(color: palette.border),
            bottom: BorderSide(color: palette.border),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              // Nur klickbar, wenn es etwas zu klappen gibt — ein Callout
              // ohne Inhalt, das auf Klick nichts tut, wirkt kaputt.
              onTap: hasBody ? () => setState(() => _open = !_open) : null,
              child: Row(
                children: [
                  Icon(style.icon, size: 16, color: style.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.titleSmall!
                          .copyWith(color: style.accent),
                      child: Text.rich(
                        TextSpan(
                          children: widget.callout.title == null
                              ? [TextSpan(text: _label(widget.callout.kind))]
                              : _spans(
                                  context,
                                  widget.callout.title!,
                                  widget.view,
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (hasBody)
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: palette.textMuted,
                    ),
                ],
              ),
            ),
            if (hasBody && _open)
              for (final block in widget.callout.content)
                _MdBlockView(block: block, view: widget.view),
          ],
        ),
      ),
    );
  }
}

/// Aussehen eines Callouts.
class _CalloutStyle {
  const _CalloutStyle(this.accent, this.surface, this.icon);

  final Color accent;
  final Color surface;
  final IconData icon;
}

/// Bildet den Callout-Bezeichner auf Tokens ab.
///
/// Unbekannte Arten bekommen das neutrale Aussehen statt eines Fehlers — ein
/// Spielsystem darf eigene Callouts mitbringen (siehe [MdCallout.kind]).
_CalloutStyle _calloutStyle(String kind, ChroniclePalette palette) =>
    switch (kind) {
      'warning' || 'caution' || 'attention' => _CalloutStyle(
        palette.warning,
        palette.warningSurface,
        Icons.warning_amber_outlined,
      ),
      'danger' || 'error' || 'failure' => _CalloutStyle(
        palette.danger,
        palette.dangerSurface,
        Icons.report_gmailerrorred_outlined,
      ),
      'success' || 'tip' || 'done' => _CalloutStyle(
        palette.success,
        palette.successSurface,
        Icons.check_circle_outline,
      ),
      // Die Eintragstyp-Farben wiederverwenden: im Play-Log steht Violett für
      // das Orakel, und ein Lore-Kasten im Codex soll denselben Sinn tragen.
      'lore' || 'oracle' => _CalloutStyle(
        palette.entryOracle,
        palette.surfaceSunken,
        Icons.auto_stories_outlined,
      ),
      'roll' || 'mechanic' => _CalloutStyle(
        palette.entryRoll,
        palette.surfaceSunken,
        Icons.casino_outlined,
      ),
      _ => _CalloutStyle(palette.info, palette.infoSurface, Icons.info_outline),
    };

String _label(String kind) =>
    kind.isEmpty ? 'Hinweis' : kind[0].toUpperCase() + kind.substring(1);

class _ListBlock extends StatelessWidget {
  const _ListBlock({
    required this.ordered,
    required this.items,
    required this.start,
    required this.view,
  });

  final bool ordered;
  final List<MdListItem> items;
  final int start;
  final MarkdownView view;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, item) in items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: _marker(context, index, item),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final block in item.content)
                          _MdBlockView(block: block, view: view),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _marker(BuildContext context, int index, MdListItem item) {
    final palette = context.palette;

    if (item.checked case final bool checked) {
      return Icon(
        checked ? Icons.check_box_outlined : Icons.check_box_outline_blank,
        size: 16,
        color: checked ? palette.success : palette.textMuted,
      );
    }
    return Text(
      ordered ? '${start + index}.' : '•',
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: palette.textMuted),
    );
  }
}

class _TableBlock extends StatelessWidget {
  const _TableBlock({required this.table, required this.view});

  final MdTable table;
  final MarkdownView view;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: palette.border),
            borderRadius: context.skin.radius(RadiusToken.card),
          ),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.symmetric(
              inside: BorderSide(color: palette.divider),
            ),
            children: [
              if (table.header.isNotEmpty)
                TableRow(
                  decoration: BoxDecoration(color: palette.surfaceSunken),
                  children: [
                    for (final cell in table.header)
                      _cell(context, cell, bold: true),
                  ],
                ),
              for (final row in table.rows)
                TableRow(
                  children: [for (final cell in row) _cell(context, cell)],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    List<MdInline> content, {
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Text.rich(
      TextSpan(children: _spans(context, content, view)),
      style: bold
          ? Theme.of(context).textTheme.titleSmall
          : Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

// ── Embeds ──────────────────────────────────────────────────────────────────

/// Blockplatzhalter, solange kein [MarkdownView.embedBuilder] gesetzt ist.
class _EmbedPlaceholder extends StatelessWidget {
  const _EmbedPlaceholder({required this.link});

  final WikiLink link;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: context.skin.radius(RadiusToken.card),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Row(
        children: [
          Icon(Icons.image_outlined, size: 18, color: palette.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              link.target,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline-Platzhalter für ein Embed mitten im Satz.
class _EmbedChip extends StatelessWidget {
  const _EmbedChip({required this.link});

  final WikiLink link;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: context.skin.radius(RadiusToken.chip),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Text(
        link.target,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: palette.textMuted),
      ),
    );
  }
}
