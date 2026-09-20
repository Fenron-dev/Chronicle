// Datei: chronicle/lib/domain/markdown/md_node.dart
//
// ZWECK: Das Dokumentmodell, das der Codex-Renderer durchläuft — Blöcke und
//        Inline-Knoten, als versiegelte Hierarchie.
//
// WARUM EIN EIGENES MODELL statt der Knoten des markdown-Pakets:
//   1. `domain/` bleibt frei von Rendering-Bibliotheken. Das Paket liefert
//      HTML-Tags („p", „em", „li"); daraus im Widget-Baum zu verzweigen hieße,
//      an jeder Stelle Zeichenketten zu vergleichen.
//   2. Callout, Wikilink und Embed werden damit eigene Knoten statt
//      Sonderfälle, die der Renderer jedes Mal neu erkennen müsste.
//   3. Versiegelt: ein neuer Knotentyp lässt jedes `switch` im Renderer
//      auffallen, statt still in einen Default-Zweig zu rutschen.
//
// SIEHE: Skill `vault-format` (Wikilink-/Embed-Syntax)
// SCHRITT: 5

import '../wikilink/wikilink.dart';

/// Ein Block — steht im Fluss untereinander.
sealed class MdBlock {
  const MdBlock();
}

/// `# Überschrift` bis `###### Überschrift`.
class MdHeading extends MdBlock {
  const MdHeading({required this.level, required this.content});

  /// 1 bis 6.
  final int level;
  final List<MdInline> content;
}

/// Ein Absatz.
class MdParagraph extends MdBlock {
  const MdParagraph(this.content);

  final List<MdInline> content;
}

/// Geordnete oder ungeordnete Liste.
class MdList extends MdBlock {
  const MdList({required this.ordered, required this.items, this.start = 1});

  final bool ordered;
  final List<MdListItem> items;

  /// Startnummer bei `3. …`.
  final int start;
}

/// Ein Listeneintrag. Enthält Blöcke, weil eine Liste Absätze und
/// Unterlisten tragen kann.
class MdListItem {
  const MdListItem({required this.content, this.checked});

  final List<MdBlock> content;

  /// `- [ ]` / `- [x]`; null bei einer gewöhnlichen Liste.
  final bool? checked;
}

/// Ein Zitat ohne Callout-Kopfzeile.
class MdQuote extends MdBlock {
  const MdQuote(this.content);

  final List<MdBlock> content;
}

/// Ein Obsidian-Callout:
///
/// ```markdown
/// > [!lore] Was man sich erzählt
/// > Seit dem Fall von [[Haus Verren]] verwaltet sich Mörwald selbst.
/// ```
///
/// Im Vault-Format ist das ein gewöhnliches Zitat mit Kopfzeile — dadurch
/// bleibt die Datei in Obsidian und in jedem Texteditor lesbar (Skill
/// `vault-format`).
class MdCallout extends MdBlock {
  const MdCallout({
    required this.kind,
    required this.content,
    this.title,
    this.folded = false,
  });

  /// Der Bezeichner aus `[!lore]`, kleingeschrieben. Bewusst nicht als enum:
  /// ein Spielsystem darf eigene Callout-Arten mitbringen, und ein
  /// unbekannter Bezeichner soll als neutraler Kasten erscheinen statt die
  /// Notiz zu zerlegen.
  final String kind;

  /// Der Text hinter `[!kind]`, falls vorhanden.
  final List<MdInline>? title;

  final List<MdBlock> content;

  /// `> [!lore]-` — eingeklappt dargestellt.
  final bool folded;
}

/// Eingerückter oder eingezäunter Codeblock.
class MdCode extends MdBlock {
  const MdCode({required this.text, this.language});

  final String text;
  final String? language;
}

/// `---`
class MdRule extends MdBlock {
  const MdRule();
}

/// Ein Embed, das allein in einer Zeile steht: `![[karte.png]]`.
///
/// Eigener Block, weil ein eingebettetes Bild im Fluss die volle Breite
/// bekommt — als Inline-Knoten in einem Absatz säße es in einer Textzeile.
class MdEmbedBlock extends MdBlock {
  const MdEmbedBlock(this.link);

  final WikiLink link;
}

/// Eine Tabelle.
class MdTable extends MdBlock {
  const MdTable({
    required this.header,
    required this.rows,
    required this.alignments,
  });

  final List<List<MdInline>> header;
  final List<List<List<MdInline>>> rows;
  final List<MdColumnAlign> alignments;
}

enum MdColumnAlign { left, center, right }

// ── Inline ──────────────────────────────────────────────────────────────────

/// Ein Inline-Knoten — steht im Textfluss.
sealed class MdInline {
  const MdInline();
}

/// Reiner Text.
class MdText extends MdInline {
  const MdText(this.text);

  final String text;
}

/// Auszeichnung um weitere Inline-Knoten.
class MdStyled extends MdInline {
  const MdStyled({required this.style, required this.content});

  final MdStyle style;
  final List<MdInline> content;
}

enum MdStyle { bold, italic, strikethrough }

/// `` `code` ``
class MdCodeSpan extends MdInline {
  const MdCodeSpan(this.text);

  final String text;
}

/// Ein gewöhnlicher Markdown-Link `[Text](ziel)`.
class MdLink extends MdInline {
  const MdLink({required this.href, required this.content});

  final String href;
  final List<MdInline> content;
}

/// `[[Seite]]`, `[[Seite#Abschnitt|Alias]]` — Verweis innerhalb des Vaults.
class MdWikiLink extends MdInline {
  const MdWikiLink(this.link);

  final WikiLink link;
}

/// `![[bild.png]]` mitten im Text.
class MdEmbed extends MdInline {
  const MdEmbed(this.link);

  final WikiLink link;
}

/// Ein Markdown-Bild `![alt](pfad)`.
class MdImage extends MdInline {
  const MdImage({required this.src, this.alt});

  final String src;
  final String? alt;
}

/// Harter Zeilenumbruch.
class MdLineBreak extends MdInline {
  const MdLineBreak();
}
