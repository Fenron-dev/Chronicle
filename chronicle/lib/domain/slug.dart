// Datei: chronicle/lib/domain/slug.dart
//
// ZWECK: Aus einem Anzeigenamen einen Ordnernamen machen.
//
// WARUM ÜBERHAUPT EIN SLUG: Der Ordnername ist das, was ein Mensch im Finder
//        sieht, wenn er den Vault ohne Chronicle öffnet. Er soll lesbar sein.
//        Die Identität hängt aber an der UUID im Manifest — ein umbenannter
//        Ordner bleibt dasselbe System (siehe Skill `vault-format`).
//
// WARUM ASCII: Vaults wandern per USB-Stick zwischen Betriebssystemen und
//        Dateisystemen. Umlaute und Sonderzeichen in Ordnernamen überleben
//        das nicht zuverlässig — macOS normalisiert anders als Linux, und
//        exFAT wiederum anders.
//
// REINE DART-LOGIK, ohne Flutter.
//
// SCHRITT: 3c

/// Umschrift für den deutschsprachigen Regelfall.
const Map<String, String> _transliterations = {
  'ä': 'ae',
  'ö': 'oe',
  'ü': 'ue',
  'ß': 'ss',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'å': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ø': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Macht aus [name] einen Ordnernamen: kleingeschrieben, ASCII,
/// Bindestrich-getrennt.
///
/// Liefert `unbenannt`, wenn nichts Verwertbares übrig bleibt — ein leerer
/// Ordnername wäre ein Fehler, den der Nutzer nicht versteht.
String slugify(String name) {
  final buffer = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final replacement = _transliterations[char];
    if (replacement != null) {
      buffer.write(replacement);
    } else if (RegExp(r'[a-z0-9]').hasMatch(char)) {
      buffer.write(char);
    } else {
      buffer.write('-');
    }
  }

  final slug = buffer
      .toString()
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  return slug.isEmpty ? 'unbenannt' : slug;
}

/// Hängt eine Zahl an, bis der Slug nicht mehr in [taken] vorkommt.
///
/// Zwei Systeme dürfen denselben Anzeigenamen tragen — zwei Ordner nicht.
String uniqueSlug(String name, Set<String> taken) {
  final base = slugify(name);
  if (!taken.contains(base)) return base;

  for (var i = 2; i < 1000; i++) {
    final candidate = '$base-$i';
    if (!taken.contains(candidate)) return candidate;
  }
  // Praktisch unerreichbar; lieber ein hässlicher Name als eine Endlosschleife.
  return '$base-${DateTime.now().millisecondsSinceEpoch}';
}
