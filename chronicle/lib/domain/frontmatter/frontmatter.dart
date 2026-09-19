// Datei: chronicle/lib/domain/frontmatter/frontmatter.dart
//
// ZWECK: YAML-Frontmatter von Markdown trennen, lesen und zurückschreiben.
//
// WARUM DAS GENAU SEIN MUSS: Das Frontmatter trägt die `id` — den
//        Primärschlüssel, der einen Index-Rebuild überlebt. Wer es beim
//        Speichern verstümmelt, erzeugt beim nächsten Scan ein neues Objekt
//        und verliert alle Verweise darauf (siehe Skill `vault-format`).
//
// REINE DART-LOGIK: kein Flutter, keine DB — damit in Isolates lauffähig und
//        ohne Widget-Test prüfbar.
//
// SCHRITT: 3

import 'package:yaml/yaml.dart';

/// Ein zerlegtes Vault-Dokument.
class ParsedDocument {
  const ParsedDocument({
    required this.frontmatter,
    required this.body,
    required this.hadFrontmatter,
  });

  /// Die Frontmatter-Schlüssel als einfache Dart-Werte.
  final Map<String, dynamic> frontmatter;

  /// Der Markdown-Teil ohne den Frontmatter-Block.
  final String body;

  /// Ob die Datei überhaupt einen Frontmatter-Block hatte.
  ///
  /// Wichtig beim Rebuild: eine Datei ohne Block bekommt eine neue `id`, die
  /// zurückgeschrieben werden muss — sonst bekommt sie beim nächsten Rebuild
  /// wieder eine andere.
  final bool hadFrontmatter;
}

/// Erkennt einen Frontmatter-Block am Dateianfang.
///
/// Verlangt `---` in der ersten Zeile und einen schließenden `---` bzw. `...`
/// auf einer eigenen Zeile. Windows-Zeilenenden sind erlaubt: Vaults wandern
/// per USB-Stick zwischen Betriebssystemen.
final RegExp _frontmatterPattern = RegExp(
  r'^---[ \t]*\r?\n(.*?)\r?\n(?:---|\.\.\.)[ \t]*(?:\r?\n|$)',
  dotAll: true,
);

/// Zerlegt [source] in Frontmatter und Body.
///
/// Ist der Block fehlerhaft, wird die Datei als reiner Body behandelt statt
/// zu werfen: eine kaputte Notiz darf den Scan nicht abbrechen — sie würde
/// sonst den ganzen Vault unbenutzbar machen.
ParsedDocument parseDocument(String source) {
  final match = _frontmatterPattern.firstMatch(source);
  if (match == null) {
    return ParsedDocument(
      frontmatter: const {},
      body: source,
      hadFrontmatter: false,
    );
  }

  final yamlText = match.group(1)!;
  final body = source.substring(match.end);

  Map<String, dynamic> map;
  try {
    final parsed = loadYaml(yamlText);
    map = parsed is YamlMap ? _toPlainMap(parsed) : <String, dynamic>{};
  } on YamlException {
    // Ungültiges YAML: lieber ohne Frontmatter weiterarbeiten, als die Datei
    // zu verlieren. Der Aufrufer sammelt solche Dateien und meldet sie am
    // Ende gebündelt.
    return ParsedDocument(
      frontmatter: const {},
      body: source,
      hadFrontmatter: false,
    );
  }

  return ParsedDocument(frontmatter: map, body: body, hadFrontmatter: true);
}

/// Setzt [frontmatter] und [body] wieder zu einer Datei zusammen.
///
/// Ein leeres Frontmatter wird weggelassen — ein Block mit nichts darin ist
/// für einen Menschen, der die Datei in Obsidian öffnet, nur Rauschen.
String serializeDocument(Map<String, dynamic> frontmatter, String body) {
  if (frontmatter.isEmpty) return body;

  final buffer = StringBuffer('---\n');
  for (final entry in frontmatter.entries) {
    _writeEntry(buffer, entry.key, entry.value, 0);
  }
  buffer.write('---\n');
  buffer.write(body);
  return buffer.toString();
}

void _writeEntry(StringBuffer out, String key, Object? value, int indent) {
  final pad = '  ' * indent;
  if (value == null) {
    out.writeln('$pad$key:');
  } else if (value is List) {
    if (value.isEmpty) {
      out.writeln('$pad$key: []');
    } else {
      // Inline-Liste: kürzer und für Obsidian-Nutzer vertraut.
      final items = value.map((v) => _scalar(v)).join(', ');
      out.writeln('$pad$key: [$items]');
    }
  } else if (value is Map) {
    out.writeln('$pad$key:');
    for (final entry in value.entries) {
      _writeEntry(out, entry.key.toString(), entry.value, indent + 1);
    }
  } else {
    out.writeln('$pad$key: ${_scalar(value)}');
  }
}

/// Zeichen, die einen YAML-Skalar mehrdeutig machen und Anführungszeichen
/// erzwingen.
final RegExp _needsQuotes = RegExp(r'''[:#\-?\[\]{},&*!|>'"%@`]|^\s|\s$''');

String _scalar(Object? value) {
  if (value == null) return '';
  if (value is num || value is bool) return value.toString();
  if (value is DateTime) return value.toUtc().toIso8601String();

  final text = value.toString();
  if (text.isEmpty) return "''";
  if (_needsQuotes.hasMatch(text)) {
    return "'${text.replaceAll("'", "''")}'";
  }
  return text;
}

/// Wandelt YamlMap/YamlList rekursiv in einfache Dart-Strukturen.
///
/// Nötig, weil YamlMap unveränderlich ist und sich nicht serialisieren lässt
/// — und weil der Rest der App nichts über das yaml-Paket wissen soll.
Map<String, dynamic> _toPlainMap(YamlMap map) {
  final result = <String, dynamic>{};
  for (final entry in map.entries) {
    result[entry.key.toString()] = _toPlainValue(entry.value);
  }
  return result;
}

dynamic _toPlainValue(dynamic value) {
  if (value is YamlMap) return _toPlainMap(value);
  if (value is YamlList) return value.map(_toPlainValue).toList();
  return value;
}
