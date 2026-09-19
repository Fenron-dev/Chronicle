// Datei: chronicle/lib/domain/frontmatter/note_frontmatter.dart
//
// ZWECK: Die Kern-Frontmatter-Schlüssel typisiert — id, type, title, created,
//        updated, tags, properties.
//
// WARUM `extra` MITGEFÜHRT WIRD: Unbekannte Schlüssel gehen beim
//        Zurückschreiben nicht verloren. Ein Vault, den eine neuere
//        Chronicle-Version oder Obsidian angefasst hat, darf hier keine
//        Felder einbüßen — sonst frisst unser Speichern fremde Daten.
//
// SIEHE: Skill `vault-format`
// SCHRITT: 3

/// Objekttypen des Vaults.
///
/// Der `name` landet als `type:` im Frontmatter — Werte nicht umbenennen,
/// ohne eine Migration vorzusehen.
enum NoteType {
  log,
  codex,
  entity,
  table,
  deck,
  sheet,
  procedure,
  canvas;

  static NoteType? tryParse(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim().toLowerCase();
    for (final value in NoteType.values) {
      if (value.name == text) return value;
    }
    return null;
  }
}

/// Die Kern-Schlüssel einer Vault-Notiz.
class NoteFrontmatter {
  const NoteFrontmatter({
    required this.id,
    required this.type,
    required this.title,
    required this.created,
    required this.updated,
    this.tags = const [],
    this.properties = const {},
    this.extra = const {},
  });

  /// UUID v4. Primärschlüssel, überlebt Umbenennen und Rebuild.
  final String id;

  final NoteType type;
  final String title;
  final DateTime created;
  final DateTime updated;
  final List<String> tags;

  /// EAV-Properties — beliebige Schlüssel/Werte.
  final Map<String, dynamic> properties;

  /// Alle übrigen Schlüssel, unverändert durchgereicht (banner, cover,
  /// theme, accent-color, layout, und was ein anderes Werkzeug ergänzt hat).
  final Map<String, dynamic> extra;

  /// Liest die Kern-Schlüssel aus einer geparsten Frontmatter-Map.
  ///
  /// Fehlt etwas, wird es ergänzt statt zu werfen: eine von Hand angelegte
  /// oder aus Obsidian stammende Datei soll sich einlesen lassen. Der
  /// Aufrufer erkennt an [wasComplete], ob die Datei zurückgeschrieben werden
  /// muss.
  factory NoteFrontmatter.fromMap(
    Map<String, dynamic> map, {
    required String fallbackId,
    required String fallbackTitle,
    required NoteType fallbackType,
    required DateTime now,
  }) {
    const known = {
      'id',
      'type',
      'title',
      'created',
      'updated',
      'tags',
      'properties',
    };

    return NoteFrontmatter(
      id: _nonEmptyString(map['id']) ?? fallbackId,
      type: NoteType.tryParse(map['type']) ?? fallbackType,
      title: _nonEmptyString(map['title']) ?? fallbackTitle,
      created: _dateTime(map['created']) ?? now,
      updated: _dateTime(map['updated']) ?? now,
      tags: _stringList(map['tags']),
      properties: _stringMap(map['properties']),
      extra: {
        for (final entry in map.entries)
          if (!known.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// Ob [map] alle Kern-Schlüssel gültig enthielt.
  ///
  /// Ist das nicht der Fall, muss die Datei nach dem Einlesen einmal
  /// zurückgeschrieben werden — sonst bekommt sie beim nächsten Rebuild
  /// erneut eine andere id.
  static bool isComplete(Map<String, dynamic> map) =>
      _nonEmptyString(map['id']) != null &&
      NoteType.tryParse(map['type']) != null &&
      _nonEmptyString(map['title']) != null &&
      _dateTime(map['created']) != null &&
      _dateTime(map['updated']) != null;

  /// Zurück in eine Map — Kern-Schlüssel zuerst, dann die durchgereichten.
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'created': created.toUtc().toIso8601String(),
    'updated': updated.toUtc().toIso8601String(),
    if (tags.isNotEmpty) 'tags': tags,
    if (properties.isNotEmpty) 'properties': properties,
    ...extra,
  };

  NoteFrontmatter copyWith({String? title, DateTime? updated}) =>
      NoteFrontmatter(
        id: id,
        type: type,
        title: title ?? this.title,
        created: created,
        updated: updated ?? this.updated,
        tags: tags,
        properties: properties,
        extra: extra,
      );
}

String? _nonEmptyString(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _dateTime(Object? raw) {
  if (raw == null) return null;
  // Das yaml-Paket parst ISO-Zeitstempel bereits selbst.
  if (raw is DateTime) return raw.toUtc();
  return DateTime.tryParse(raw.toString().trim())?.toUtc();
}

List<String> _stringList(Object? raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (_nonEmptyString(item) case final String value) value,
    ];
  }
  // Einzelner Tag ohne Liste geschrieben — kommt von Hand oft vor.
  final single = _nonEmptyString(raw);
  return single == null ? const [] : [single];
}

Map<String, dynamic> _stringMap(Object? raw) {
  if (raw is Map) {
    return {for (final entry in raw.entries) entry.key.toString(): entry.value};
  }
  return const {};
}
