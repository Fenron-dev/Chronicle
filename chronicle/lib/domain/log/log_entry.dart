// Datei: chronicle/lib/domain/log/log_entry.dart
//
// ZWECK: Ein Log-Eintrag und seine Darstellung in Markdown. Das Play-Log ist
//        das zentrale Spiel-Primitiv (Konzept §4.1): ein chronologischer
//        Stream getippter Einträge.
//
// FORMAT auf Platte, eine Zeile Kopf plus Rumpf:
//
//   > [!entry] narration | 2026-09-19T20:14:03Z | id: 018f3c2a-…
//   Der Nebel über dem Moor wird dichter.
//
//        Ein Callout, weil es in Obsidian als solcher rendert: der Vault
//        bleibt ohne Chronicle lesbar (Skill `vault-format`). Kind,
//        Zeitstempel und UUID stehen im Kopf, damit der Rumpf reines
//        Markdown bleibt.
//
// REINE DART-LOGIK, ohne Flutter und ohne Dateisystem.
//
// SCHRITT: 4

import 'entry_kind.dart';

/// Ein Eintrag im Play-Log.
class LogEntry {
  const LogEntry({
    required this.id,
    required this.kind,
    required this.timestamp,
    required this.text,
  });

  /// UUID. Sub-Threads und Querverweise brauchen sie.
  final String id;

  final EntryKind kind;
  final DateTime timestamp;

  /// Markdown-Rumpf, ohne Kopfzeile.
  final String text;

  LogEntry copyWith({String? text}) => LogEntry(
    id: id,
    kind: kind,
    timestamp: timestamp,
    text: text ?? this.text,
  );
}

/// Kopfzeile eines Eintrags.
///
/// Toleriert unterschiedlich viele Leerzeichen, weil die Datei auch von Hand
/// bearbeitet werden darf — der Vault gehört dem Nutzer, nicht uns.
final RegExp _headerPattern = RegExp(
  r'^>\s*\[!entry\]\s*([a-z]+)\s*\|\s*([^|]+?)\s*\|\s*id:\s*(\S+)\s*$',
);

/// Liest alle Einträge aus dem Rumpf einer Log-Datei.
///
/// Text vor dem ersten Kopf (etwa eine Überschrift) wird übersprungen: er
/// gehört zur Datei, nicht zu einem Eintrag.
List<LogEntry> parseLogEntries(String body) {
  final entries = <LogEntry>[];
  final lines = body.split('\n');

  String? currentKindName;
  String? currentId;
  DateTime? currentTime;
  final buffer = <String>[];

  void flush() {
    final id = currentId;
    if (id == null) return;
    final kind = _kindFrom(currentKindName);
    entries.add(
      LogEntry(
        id: id,
        kind: kind,
        timestamp: currentTime ?? DateTime.fromMillisecondsSinceEpoch(0),
        text: _trimBlankEdges(buffer).join('\n'),
      ),
    );
    buffer.clear();
  }

  for (final line in lines) {
    final match = _headerPattern.firstMatch(line.trimRight());
    if (match != null) {
      flush();
      currentKindName = match.group(1);
      currentTime = DateTime.tryParse(match.group(2)!.trim())?.toUtc();
      currentId = match.group(3);
      continue;
    }
    if (currentId != null) buffer.add(line);
  }
  flush();

  return entries;
}

/// Schreibt einen Eintrag als Markdown.
String serializeLogEntry(LogEntry entry) {
  final header =
      '> [!entry] ${entry.kind.name} | '
      '${entry.timestamp.toUtc().toIso8601String()} | '
      'id: ${entry.id}';
  return '$header\n${entry.text.trim()}\n';
}

/// Hängt [entry] an den Rumpf einer Log-Datei an.
///
/// Genau eine Leerzeile zwischen den Einträgen: so rendert der Callout in
/// Obsidian korrekt, und die Datei bleibt beim Lesen im Editor übersichtlich.
String appendLogEntry(String body, LogEntry entry) {
  final trimmed = body.trimRight();
  final block = serializeLogEntry(entry);
  return trimmed.isEmpty ? block : '$trimmed\n\n$block';
}

/// Baut den kompletten Rumpf aus [entries] neu auf.
///
/// Für das Ersetzen oder Löschen eines Eintrags: erst die Liste ändern, dann
/// den Rumpf neu schreiben. [preamble] bleibt erhalten — meist die
/// Überschrift der Datei.
String serializeLogBody(String preamble, List<LogEntry> entries) {
  final blocks = entries.map(serializeLogEntry).join('\n');
  final head = preamble.trimRight();
  if (head.isEmpty) return blocks;
  return blocks.isEmpty ? '$head\n' : '$head\n\n$blocks';
}

/// Der Text einer Log-Datei vor dem ersten Eintrag.
String logPreamble(String body) {
  final lines = body.split('\n');
  final head = <String>[];
  for (final line in lines) {
    if (_headerPattern.hasMatch(line.trimRight())) break;
    head.add(line);
  }
  return _trimBlankEdges(head).join('\n');
}

EntryKind _kindFrom(String? name) {
  for (final kind in EntryKind.values) {
    if (kind.name == name) return kind;
  }
  // Ein unbekannter Typ stammt aus einer neueren Chronicle-Version oder von
  // Hand. Als Meta-Eintrag bleibt er sichtbar, statt verloren zu gehen.
  return EntryKind.meta;
}

List<String> _trimBlankEdges(List<String> lines) {
  var start = 0;
  var end = lines.length;
  while (start < end && lines[start].trim().isEmpty) {
    start++;
  }
  while (end > start && lines[end - 1].trim().isEmpty) {
    end--;
  }
  return lines.sublist(start, end);
}
