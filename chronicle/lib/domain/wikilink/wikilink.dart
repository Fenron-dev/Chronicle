// Datei: chronicle/lib/domain/wikilink/wikilink.dart
//
// ZWECK: Datenmodell und Parser für Wikilinks. Unterstützte Formen:
//          [[Seite]]                → Verweis auf eine Seite
//          [[Seite#Abschnitt]]      → Verweis auf einen Abschnitt
//          [[Seite|Anzeigetext]]    → Verweis mit Alias
//          [[Seite#Abschnitt|Alias]]→ kombiniert
//          ![[bild.png]]            → Einbettung eines Media-Assets
//
// HERKUNFT: Portiert aus OracleVault (lib/domain/wikilink/wikilink.dart).
//        Die Regex und die Zerlegungslogik sind dort erprobt; angepasst
//        wurden nur die Begriffe (Seite statt Tabelle).
//
// REINE DART-LOGIK ohne Flutter- oder DB-Abhängigkeit: der Rohtext bleibt
//        unangetastet, der Parser liefert nur die gefundenen Referenzen samt
//        Zeichen-Offsets (für Highlighting und Autocomplete).
//
// SIEHE: Skill `vault-format`
// SCHRITT: 3

/// Art eines Wikilinks.
enum WikiLinkKind {
  /// `[[…]]` — Verweis (Navigation, Backlink).
  link,

  /// `![[…]]` — Einbettung eines Media-Assets.
  embed,
}

/// Ein im Text gefundener Wikilink.
class WikiLink {
  const WikiLink({
    required this.kind,
    required this.target,
    required this.start,
    required this.end,
    required this.raw,
    this.section,
    this.alias,
  });

  final WikiLinkKind kind;

  /// Zielseite bzw. Dateiname bei Embeds.
  final String target;

  /// Abschnitt bei `[[Seite#Abschnitt]]`, sonst null.
  final String? section;

  /// Abweichender Anzeigetext bei `[[…|Alias]]`, sonst null.
  final String? alias;

  /// Offset des ersten Zeichens (`[` bzw. `!`) im Quelltext.
  final int start;

  /// Offset direkt hinter dem schließenden `]]`.
  final int end;

  /// Exakt gematchter Teilstring inklusive Klammern.
  final String raw;

  bool get isEmbed => kind == WikiLinkKind.embed;

  /// Was im Text angezeigt wird.
  String get displayText =>
      alias ?? (section == null ? target : '$target › $section');

  @override
  String toString() =>
      'WikiLink(${kind.name}, target: "$target"'
      '${section != null ? ', section: "$section"' : ''}'
      '${alias != null ? ', alias: "$alias"' : ''})';

  @override
  bool operator ==(Object other) =>
      other is WikiLink &&
      other.kind == kind &&
      other.target == target &&
      other.section == section &&
      other.alias == alias &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(kind, target, section, alias, start, end);
}

/// Matcht `[[…]]` und `![[…]]`.
///
/// Der Inhalt darf keine eckigen Klammern und keinen Zeilenumbruch enthalten
/// — dadurch überspannt ein unbalanciertes `[[` nicht den halben Text.
final RegExp _wikiLinkPattern = RegExp(r'(!?)\[\[([^\[\]\n]+?)\]\]');

/// Findet alle Wikilinks in [text], in Reihenfolge ihres Auftretens.
///
/// Leere Ziele (`[[]]`, `[[  ]]`, `[[#Abschnitt]]`) werden übersprungen: sie
/// entstehen beim Tippen und sind kein Link, sondern ein halbfertiger.
List<WikiLink> parseWikiLinks(String text) {
  final links = <WikiLink>[];

  for (final match in _wikiLinkPattern.allMatches(text)) {
    final isEmbed = match.group(1) == '!';
    final inner = match.group(2)!;

    // Zerlegung: target#section|alias — der Alias bindet am weitesten außen,
    // damit ein `#` im Anzeigetext nicht als Abschnitt gelesen wird.
    var rest = inner;
    String? alias;
    final pipe = rest.indexOf('|');
    if (pipe >= 0) {
      alias = rest.substring(pipe + 1).trim();
      rest = rest.substring(0, pipe);
      if (alias.isEmpty) alias = null;
    }

    var target = rest;
    String? section;
    final hash = rest.indexOf('#');
    if (hash >= 0) {
      section = rest.substring(hash + 1).trim();
      target = rest.substring(0, hash);
      if (section.isEmpty) section = null;
    }

    target = target.trim();
    if (target.isEmpty) continue;

    links.add(
      WikiLink(
        kind: isEmbed ? WikiLinkKind.embed : WikiLinkKind.link,
        target: target,
        section: section,
        alias: alias,
        start: match.start,
        end: match.end,
        raw: match.group(0)!,
      ),
    );
  }

  return links;
}
