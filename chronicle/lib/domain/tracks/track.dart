// Datei: chronicle/lib/domain/tracks/track.dart
//
// ZWECK: Clocks und Step-Tracks (Konzept §4.5).
//        Clock  = radial, füllt sich — UNGEWISSER Fortschritt, Spannung (FitD).
//        Track  = horizontal, abhakbar — GEORDNETE Folge (Kapitel, Szenen).
//
// WO DER ZUSTAND STEHT: in der Datei, nicht im Index (CLAUDE.md §2.5).
//        Eine Clock trägt `segments`/`filled` im Frontmatter. Ein Track ist
//        eine gewöhnliche Aufgabenliste im Rumpf:
//
//          - [x] Ankunft in Mörwald
//          - [ ] Der Turm im Moor
//            - [ ] Den Wächter bestechen      ← eingerückt: Unter-Beat
//
//        Damit ist ein Track in Obsidian abhakbar, ohne dass Chronicle läuft.
//
// ABHAKEN ÄNDERT GENAU EINE ZEILE: [toggleBeat] kippt das Kästchen in der
//        einen Zeile und fasst sonst nichts an. Den Rumpf aus dem Modell neu zu
//        schreiben würde Prosa, Überschriften und eigene Einrückung zwischen
//        den Beats vernichten — Text, den der Nutzer selbst dort hingeschrieben
//        hat.
//
// REINE DART-LOGIK ohne Flutter-Import (CLAUDE.md §7).
//
// SIEHE: Skill `vault-format`, Konzept §4.5
// SCHRITT: 8

/// Kleinste und größte erlaubte Segmentzahl einer Clock.
///
/// FitD nutzt 4, 6 und 8; 12 kommt vor. Mehr als 24 ist keine Clock mehr,
/// sondern ein Track, und liest sich als Kreis nicht mehr.
const int kMinClockSegments = 2;
const int kMaxClockSegments = 24;

/// Der Zustand einer Clock. Unveränderlich — jede Änderung liefert eine neue.
class ClockState {
  const ClockState({required this.segments, this.filled = 0});

  /// Liest aus Frontmatter-Werten und klemmt, was außerhalb liegt.
  ///
  /// Eine von Hand auf `filled: 9` gesetzte 6er-Clock ist ein Tippfehler,
  /// kein Grund, die Datei abzulehnen.
  factory ClockState.fromValues(Object? segments, Object? filled) {
    final s = _asInt(segments, 4).clamp(kMinClockSegments, kMaxClockSegments);
    final f = _asInt(filled, 0).clamp(0, s);
    return ClockState(segments: s, filled: f);
  }

  final int segments;
  final int filled;

  bool get isComplete => filled >= segments;
  bool get isEmpty => filled <= 0;

  /// Anteil gefüllt, 0.0 bis 1.0.
  double get progress => segments == 0 ? 0 : filled / segments;

  /// Füllt [by] Segmente (negativ leert). Bleibt in den Grenzen.
  ClockState advance([int by = 1]) =>
      ClockState(segments: segments, filled: (filled + by).clamp(0, segments));

  ClockState reset() => ClockState(segments: segments);

  static int _asInt(Object? raw, int fallback) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString().trim() ?? '') ?? fallback;
  }
}

/// Ein Beat eines Step-Tracks — eine Zeile der Aufgabenliste.
class TrackBeat {
  const TrackBeat({
    required this.text,
    required this.done,
    required this.line,
    required this.depth,
  });

  final String text;
  final bool done;

  /// Zeilennummer im Rumpf, 0-basiert. Über sie wird abgehakt — nicht über
  /// den Text, denn zwei Beats dürfen gleich heißen.
  final int line;

  /// Einrückungstiefe. 0 = Haupt-Beat, 1 = Unter-Beat usw.
  final int depth;
}

/// Matcht eine Aufgabenzeile: `- [ ] Text`, `* [x] Text`, eingerückt oder nicht.
final RegExp _taskLine = RegExp(r'^([ \t]*)[-*+][ \t]+\[([ xX])\][ \t]+(.*)$');

/// Liest alle Beats aus [body], in Reihenfolge.
List<TrackBeat> parseBeats(String body) {
  final beats = <TrackBeat>[];
  final lines = body.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final match = _taskLine.firstMatch(lines[i]);
    if (match == null) continue;

    final text = match.group(3)!.trim();
    if (text.isEmpty) continue;

    beats.add(
      TrackBeat(
        text: text,
        done: match.group(2)!.toLowerCase() == 'x',
        line: i,
        depth: _depthOf(match.group(1)!),
      ),
    );
  }
  return beats;
}

/// Tiefe aus der Einrückung. Tab und zwei Leerzeichen zählen je eine Stufe —
/// Obsidian rückt mit Tab ein, von Hand geschriebenes Markdown meist mit
/// zwei oder vier Leerzeichen. Vier Leerzeichen sind dann eben zwei Stufen,
/// was bei konsequenter Schreibweise dieselbe Reihenfolge ergibt.
int _depthOf(String indent) {
  var width = 0;
  for (final char in indent.split('')) {
    width += char == '\t' ? 2 : 1;
  }
  return width ~/ 2;
}

/// Setzt das Kästchen in Zeile [line] auf [done] und ändert sonst nichts.
///
/// Gibt null zurück, wenn in [line] keine Aufgabenzeile (mehr) steht — die
/// Datei wurde dann außerhalb der App geändert, und der Aufrufer muss neu
/// laden, statt eine falsche Zeile zu kippen.
String? toggleBeat(String body, int line, {required bool done}) {
  final lines = body.split('\n');
  if (line < 0 || line >= lines.length) return null;

  final match = _taskLine.firstMatch(lines[line]);
  if (match == null) return null;

  // Nur das eine Zeichen im Kästchen ersetzen. Die Position ergibt sich aus
  // Einrückung + Aufzählungszeichen + Leerraum + `[`.
  final original = lines[line];
  final box = original.indexOf('[', match.group(1)!.length);
  lines[line] =
      original.substring(0, box + 1) +
      (done ? 'x' : ' ') +
      original.substring(box + 2);
  return lines.join('\n');
}

/// Hängt einen Beat ans Ende der Aufgabenliste an.
///
/// Steht schon eine Liste im Rumpf, kommt der neue Beat direkt hinter ihren
/// letzten Eintrag — nicht ans Dateiende, wo er hinter einem abschließenden
/// Absatz landen und optisch nicht mehr zur Liste gehören würde.
String appendBeat(String body, String text) {
  final clean = text.trim();
  if (clean.isEmpty) return body;

  final lines = body.split('\n');
  final beats = parseBeats(body);
  final newLine = '- [ ] $clean';

  if (beats.isEmpty) {
    final trimmed = body.trimRight();
    return trimmed.isEmpty ? '$newLine\n' : '$trimmed\n\n$newLine\n';
  }

  lines.insert(beats.last.line + 1, newLine);
  return lines.join('\n');
}

/// Kennzahlen eines Tracks für die obere Leiste.
class TrackProgress {
  const TrackProgress({required this.done, required this.total, this.next});

  factory TrackProgress.of(List<TrackBeat> beats) {
    // Gezählt werden die HAUPT-Beats: Unter-Beats sind die Schritte eines
    // Kapitels, nicht weitere Kapitel. Sonst sähe ein Track mit einem
    // detaillierten Kapitel weiter fortgeschritten aus, als er ist.
    final top = beats.where((b) => b.depth == 0).toList();
    TrackBeat? next;
    for (final beat in top) {
      if (!beat.done) {
        next = beat;
        break;
      }
    }
    return TrackProgress(
      done: top.where((b) => b.done).length,
      total: top.length,
      next: next,
    );
  }

  final int done;
  final int total;

  /// Der nächste offene Haupt-Beat, oder null, wenn alles erledigt ist.
  final TrackBeat? next;

  bool get isComplete => total > 0 && done >= total;
}
