// Datei: chronicle/lib/domain/markdown/markdown_parser.dart
//
// ZWECK: Markdown-Quelltext → [MdBlock]-Liste. Die einzige Stelle, die das
//        markdown-Paket kennt.
//
// WARUM DIE ÜBERSETZUNG: Das Paket liefert einen HTML-nahen Baum aus
//        Tag-Zeichenketten. Ihn direkt im Widget-Baum zu verzweigen hieße,
//        überall `if (element.tag == 'em')` zu schreiben — und beim nächsten
//        Paket-Wechsel alles anzufassen. Hier wird einmal übersetzt.
//
// ENCODEHTML IST AUS: sonst kämen Text-Knoten HTML-maskiert zurück (`&amp;`,
//        `&lt;`). Wir rendern kein HTML, sondern Flutter-Widgets — die
//        Maskierung wäre im Journal sichtbarer Unsinn.
//
// SIEHE: Skill `vault-format`
// SCHRITT: 5

import 'package:markdown/markdown.dart' as md;

import '../wikilink/wikilink.dart';
import 'md_node.dart';

/// Übersetzt [source] in unser Dokumentmodell.
///
/// Wirft nicht: unbekannte Konstrukte landen als Absatz mit ihrem Rohtext.
/// Eine halbfertig getippte Notiz darf den Editor nicht leeren.
List<MdBlock> parseMarkdown(String source) {
  final document = md.Document(
    // Unsere Syntaxen zuerst — das Paket wertet benutzerdefinierte
    // Inline-Syntaxen vor den eingebauten aus. Nötig, damit `[[Seite]]` nicht
    // vorher als Referenz-Link zerlegt wird.
    inlineSyntaxes: [_WikiLinkSyntax()],
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );

  final nodes = document.parse(source);
  return _blocks(nodes);
}

// ── Inline-Syntax für Wikilinks ─────────────────────────────────────────────

/// Erkennt `[[…]]` und `![[…]]` und hängt sie als eigenes Element ein.
///
/// Die Zerlegung macht bewusst nicht diese Klasse, sondern der erprobte
/// Parser aus `domain/wikilink/` — es soll genau eine Stelle geben, die
/// entscheidet, was `[[Seite#Abschnitt|Alias]]` bedeutet.
class _WikiLinkSyntax extends md.InlineSyntax {
  _WikiLinkSyntax() : super(r'(!?)\[\[([^\[\]\n]+?)\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final raw = match.group(0)!;
    final links = parseWikiLinks(raw);
    if (links.isEmpty) {
      // Leeres Ziel (`[[]]`, `[[#Abschnitt]]`) — beim Tippen der Normalfall.
      // Als Text stehen lassen, statt etwas zu erfinden.
      parser.addNode(md.Text(raw));
      return true;
    }

    final link = links.first;
    final element = md.Element.empty(link.isEmbed ? _embedTag : _wikiLinkTag);
    element.attributes['target'] = link.target;
    if (link.section != null) element.attributes['section'] = link.section!;
    if (link.alias != null) element.attributes['alias'] = link.alias!;
    parser.addNode(element);
    return true;
  }
}

const String _wikiLinkTag = 'chronicle-wikilink';
const String _embedTag = 'chronicle-embed';

WikiLink _linkFrom(md.Element element) => WikiLink(
  kind: element.tag == _embedTag ? WikiLinkKind.embed : WikiLinkKind.link,
  target: element.attributes['target'] ?? '',
  section: element.attributes['section'],
  alias: element.attributes['alias'],
  // Die Offsets sind nach dem Parsen bedeutungslos: sie zeigten in den
  // Rohtext, und der Renderer arbeitet auf dem Baum. Null statt falscher
  // Zahlen.
  start: 0,
  end: 0,
  raw: '',
);

// ── Blöcke ──────────────────────────────────────────────────────────────────

List<MdBlock> _blocks(List<md.Node> nodes) {
  final out = <MdBlock>[];
  for (final node in nodes) {
    final block = _block(node);
    if (block != null) out.add(block);
  }
  return out;
}

MdBlock? _block(md.Node node) {
  if (node is md.Text) {
    // Loser Text zwischen Blöcken — meist Leerzeilen.
    final text = node.textContent.trim();
    return text.isEmpty ? null : MdParagraph([MdText(text)]);
  }
  if (node is! md.Element) return null;

  switch (node.tag) {
    case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
      return MdHeading(
        level: int.parse(node.tag.substring(1)),
        content: _inlines(node.children),
      );

    case 'p':
      return _paragraphOrEmbed(node);

    case 'blockquote':
      return _quoteOrCallout(node);

    case 'pre':
      return _code(node);

    case 'ul':
      return MdList(ordered: false, items: _listItems(node));

    case 'ol':
      return MdList(
        ordered: true,
        items: _listItems(node),
        start: int.tryParse(node.attributes['start'] ?? '') ?? 1,
      );

    case 'hr':
      return const MdRule();

    case 'table':
      return _table(node);

    default:
      // Unbekannt — lieber der Rohtext als ein verschluckter Absatz.
      final text = node.textContent.trim();
      return text.isEmpty ? null : MdParagraph([MdText(text)]);
  }
}

/// Ein Absatz, der nur aus einem Embed besteht, wird zum Block.
///
/// `![[karte.png]]` allein in einer Zeile soll die volle Breite bekommen.
/// Steht es mitten im Satz, bleibt es ein Inline-Knoten.
MdBlock _paragraphOrEmbed(md.Element node) {
  final content = _inlines(node.children);
  // Listen-Pattern statt `length == 1 && first is …`: `&&` und `case` lassen
  // sich in einem if nicht verbinden, und so steht die Bedingung als Form da.
  if (content case [final MdEmbed embed]) {
    return MdEmbedBlock(embed.link);
  }
  return MdParagraph(content);
}

/// Matcht den Kopf eines Callouts — `[!kind]`, optional mit `+`/`-`.
///
/// Bewusst nur das PRÄFIX, nicht die ganze Zeile: der markdown-Parser fasst
/// Kopfzeile und Folgezeilen zu EINEM Text-Knoten mit `\n` zusammen. Eine
/// Regex mit `$` findet darin nichts, weil `.` keinen Umbruch überquert —
/// genau daran ist die erste Fassung gescheitert.
final RegExp _calloutHeader = RegExp(r'^\[!([A-Za-z0-9_-]+)\]([+-]?)[ \t]*');

MdBlock _quoteOrCallout(md.Element node) {
  final inner = _blocks(node.children ?? const <md.Node>[]);
  if (inner.isEmpty) return MdQuote(inner);

  final first = inner.first;
  if (first is! MdParagraph || first.content.isEmpty) return MdQuote(inner);

  final leading = first.content.first;
  if (leading is! MdText) return MdQuote(inner);

  final match = _calloutHeader.firstMatch(leading.text);
  if (match == null) return MdQuote(inner);

  // Alles nach dem Kopf, dann am ersten Umbruch trennen: davor der Titel,
  // danach der Inhalt. Über die Inline-Knoten statt über den Rohtext, damit
  // ein ausgezeichneter Titel (`[!note] **Wichtig**`) erhalten bleibt.
  final remainder = leading.text.substring(match.end);
  final (title, body) = _splitAtFirstNewline([
    if (remainder.isNotEmpty) MdText(remainder),
    ...first.content.skip(1),
  ]);

  return MdCallout(
    kind: match.group(1)!.toLowerCase(),
    folded: match.group(2) == '-',
    title: title.isEmpty ? null : title,
    content: [if (body.isNotEmpty) MdParagraph(body), ...inner.skip(1)],
  );
}

/// Teilt [nodes] am ersten Zeilenumbruch.
(List<MdInline>, List<MdInline>) _splitAtFirstNewline(List<MdInline> nodes) {
  final before = <MdInline>[];
  final after = <MdInline>[];
  var split = false;

  for (final node in nodes) {
    if (split) {
      after.add(node);
      continue;
    }
    if (node is MdText) {
      final index = node.text.indexOf('\n');
      if (index >= 0) {
        split = true;
        final head = node.text.substring(0, index).trimRight();
        final tail = node.text.substring(index + 1);
        if (head.isNotEmpty) before.add(MdText(head));
        if (tail.isNotEmpty) after.add(MdText(tail));
        continue;
      }
    }
    before.add(node);
  }
  return (before, after);
}

MdBlock _code(md.Element node) {
  final children = node.children ?? const <md.Node>[];
  if (children case [final md.Element code]) {
    // Die Sprache steht als `language-dart` in der Klasse.
    final classes = code.attributes['class'] ?? '';
    final language = classes.startsWith('language-')
        ? classes.substring('language-'.length)
        : null;
    return MdCode(
      text: _stripTrailingNewline(code.textContent),
      language: language?.isEmpty ?? true ? null : language,
    );
  }
  return MdCode(text: _stripTrailingNewline(node.textContent));
}

String _stripTrailingNewline(String text) =>
    text.endsWith('\n') ? text.substring(0, text.length - 1) : text;

List<MdListItem> _listItems(md.Element node) {
  final out = <MdListItem>[];
  for (final child in node.children ?? const <md.Node>[]) {
    if (child is! md.Element || child.tag != 'li') continue;

    bool? checked;
    final children = <md.Node>[];
    for (final item in child.children ?? const <md.Node>[]) {
      // GitHub-Flavored macht aus `- [x]` ein input-Element.
      if (item is md.Element && item.tag == 'input') {
        checked = item.attributes['checked'] == 'true';
        continue;
      }
      children.add(item);
    }

    // Ein Listeneintrag ohne Absatz ist der Normalfall („lose" Liste): seine
    // Kinder sind direkt Inline-Knoten.
    final blocks = _blocks(children);
    final content = blocks.isEmpty && children.isNotEmpty
        ? <MdBlock>[MdParagraph(_inlines(children))]
        : blocks;

    out.add(MdListItem(content: content, checked: checked));
  }
  return out;
}

MdBlock _table(md.Element node) {
  final header = <List<MdInline>>[];
  final rows = <List<List<MdInline>>>[];
  final alignments = <MdColumnAlign>[];

  for (final section in node.children ?? const <md.Node>[]) {
    if (section is! md.Element) continue;
    for (final row in section.children ?? const <md.Node>[]) {
      if (row is! md.Element || row.tag != 'tr') continue;
      final cells = <List<MdInline>>[];
      for (final cell in row.children ?? const <md.Node>[]) {
        if (cell is! md.Element) continue;
        cells.add(_inlines(cell.children));
        if (section.tag == 'thead') {
          alignments.add(_align(cell.attributes['style']));
        }
      }
      if (section.tag == 'thead') {
        header.addAll(cells);
      } else {
        rows.add(cells);
      }
    }
  }

  return MdTable(header: header, rows: rows, alignments: alignments);
}

MdColumnAlign _align(String? style) {
  if (style == null) return MdColumnAlign.left;
  if (style.contains('center')) return MdColumnAlign.center;
  if (style.contains('right')) return MdColumnAlign.right;
  return MdColumnAlign.left;
}

// ── Inline ──────────────────────────────────────────────────────────────────

List<MdInline> _inlines(List<md.Node>? nodes) {
  final out = <MdInline>[];
  for (final node in nodes ?? const <md.Node>[]) {
    final inline = _inline(node);
    if (inline != null) out.add(inline);
  }
  return out;
}

MdInline? _inline(md.Node node) {
  if (node is md.Text) {
    final text = node.textContent;
    return text.isEmpty ? null : MdText(text);
  }
  if (node is! md.Element) return null;

  switch (node.tag) {
    case _wikiLinkTag:
      return MdWikiLink(_linkFrom(node));
    case _embedTag:
      return MdEmbed(_linkFrom(node));
    case 'strong':
      return MdStyled(style: MdStyle.bold, content: _inlines(node.children));
    case 'em':
      return MdStyled(style: MdStyle.italic, content: _inlines(node.children));
    case 'del':
      return MdStyled(
        style: MdStyle.strikethrough,
        content: _inlines(node.children),
      );
    case 'code':
      return MdCodeSpan(node.textContent);
    case 'a':
      return MdLink(
        href: node.attributes['href'] ?? '',
        content: _inlines(node.children),
      );
    case 'img':
      return MdImage(
        src: node.attributes['src'] ?? '',
        alt: node.attributes['alt'],
      );
    case 'br':
      return const MdLineBreak();
    default:
      final text = node.textContent;
      return text.isEmpty ? null : MdText(text);
  }
}
