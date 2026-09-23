// Datei: chronicle/lib/core/dev_log.dart
//
// ZWECK: Ein Ringpuffer für Diagnose-Meldungen, den der Nutzer als Text
//        herausgeben kann.
//
// WARUM ÜBERHAUPT: Chronicle läuft lokal auf fremden Rechnern; eine
//        Fehlermeldung aus der Konsole sieht dort niemand. Ohne ein Log, das
//        sich kopieren lässt, kostet jede Rückfrage einen kompletten
//        CI-Durchlauf — Bauen, Herunterladen, Ausprobieren, Beschreiben.
//
// WAS NICHT HINEINGEHÖRT: Vault-Inhalte und API-Keys. Das Log wird
//        weitergereicht; es enthält Pfade und Zähler, keine Spielinhalte und
//        keine Secrets (CLAUDE.md §2.4).
//
// SCHRITT: 4

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

extension LogLevelLabel on LogLevel {
  String get label => switch (this) {
    LogLevel.debug => 'DEBUG',
    LogLevel.info => 'INFO ',
    LogLevel.warning => 'WARN ',
    LogLevel.error => 'ERROR',
  };
}

/// Eine einzelne Meldung.
class LogRecord {
  LogRecord({
    required this.time,
    required this.level,
    required this.source,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime time;
  final LogLevel level;

  /// Woher die Meldung kommt — `vault`, `catalog`, `log`, `ui`, `flutter`.
  final String source;

  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  String render() {
    final stamp = time.toIso8601String().substring(11, 23);
    final buffer = StringBuffer('$stamp ${level.label} [$source] $message');
    if (error != null) buffer.write('\n         → $error');
    if (stackTrace != null) {
      // Nur die obersten Rahmen: der Rest ist Framework-Rauschen und macht
      // das Log unlesbar, gerade wenn es jemand in einen Chat einfügt.
      final frames = stackTrace.toString().split('\n').take(8);
      for (final frame in frames) {
        if (frame.trim().isEmpty) continue;
        buffer.write('\n           $frame');
      }
    }
    return buffer.toString();
  }
}

/// Der Diagnose-Puffer der App.
class DevLog {
  DevLog._();

  static final DevLog instance = DevLog._();

  /// Genug für eine Sitzung, wenig genug, um es in einen Chat einzufügen.
  static const int maxRecords = 1000;

  final Queue<LogRecord> _records = Queue<LogRecord>();

  /// Zählt hoch, wenn sich etwas geändert hat — daran hängt die Anzeige.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  int get length => _records.length;

  List<LogRecord> get records => List.unmodifiable(_records);

  void add(
    LogLevel level,
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _records.add(
      LogRecord(
        time: DateTime.now(),
        level: level,
        source: source,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
    while (_records.length > maxRecords) {
      _records.removeFirst();
    }
    _notify();

    // Zusätzlich auf die Konsole, falls jemand die App aus dem Terminal
    // startet. Über die Root-Zone, nicht über debugPrint: `main` leitet
    // `print` der App-Zone ins Log um (captureZonePrint), und ein debugPrint
    // von hier aus käme dort wieder an — eine Endlosschleife.
    Zone.root.print(_records.last.render());
  }

  void debug(String source, String message) =>
      add(LogLevel.debug, source, message);

  void info(String source, String message) =>
      add(LogLevel.info, source, message);

  void warn(String source, String message, {Object? error}) =>
      add(LogLevel.warning, source, message, error: error);

  void error(
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => add(
    LogLevel.error,
    source,
    message,
    error: error,
    stackTrace: stackTrace,
  );

  void clear() {
    _records.clear();
    _notify();
  }

  bool _notifyPending = false;

  /// Meldet Änderungen gebündelt NACH dem laufenden Frame.
  ///
  /// Seit `print` ins Log umgeleitet wird, kommen Meldungen auch mitten aus
  /// build/layout (Framework-Warnungen). Ein sofortiges `revision.value++`
  /// ließe dann die offene Log-Anzeige neu bauen, während gebaut wird — ein
  /// Assert, der selbst wieder im Log landet.
  void _notify() {
    if (_notifyPending) return;
    _notifyPending = true;
    scheduleMicrotask(() {
      _notifyPending = false;
      revision.value++;
    });
  }

  /// Das komplette Log als Text, mit Kopfzeilen zur Umgebung.
  ///
  /// Die Kopfzeilen sind der halbe Wert: „funktioniert bei mir nicht" ist
  /// ohne Betriebssystem und Version kaum zu beantworten.
  String render() {
    final buffer = StringBuffer()
      ..writeln('Chronicle Dev-Log')
      ..writeln('erzeugt:      ${DateTime.now().toIso8601String()}')
      ..writeln(
        'Plattform:    ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}',
      )
      ..writeln('Dart:         ${Platform.version.split(' ').first}')
      ..writeln('Modus:        ${kReleaseMode ? "release" : "debug"}')
      ..writeln(
        'Meldungen:    ${_records.length}'
        '${_records.length >= maxRecords ? " (älteste verworfen)" : ""}',
      )
      ..writeln('─' * 72);

    for (final record in _records) {
      buffer.writeln(record.render());
    }
    return buffer.toString();
  }

  /// Fängt Fehler ab, die sonst nur in der Konsole landen.
  ///
  /// Ohne das fehlt im Log genau das, was am meisten interessiert: der
  /// Absturz, den der Nutzer gerade gesehen hat.
  static void installErrorHandlers() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      instance.error(
        'flutter',
        details.context?.toDescription() ?? 'Unbehandelter Widget-Fehler',
        error: details.exception,
        stackTrace: details.stack,
      );
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      instance.error(
        'dart',
        'Unbehandelter Fehler außerhalb des Widget-Baums',
        error: error,
        stackTrace: stack,
      );
      return false;
    };
  }
}

/// Leitet `print` der umschlossenen Zone zusätzlich ins Dev-Log.
///
/// WARUM: Plugins melden Fehler oft nur per `print` und liefern dann einen
/// harmlosen Rückgabewert. `file_picker` etwa fängt auf macOS ein fehlendes
/// Entitlement selbst ab, druckt die Ursache und gibt `null` zurück — für
/// die App sieht das aus wie „Dialog abgebrochen". Auf der Konsole steht
/// es, aber die sieht bei einer per Doppelklick gestarteten App niemand.
ZoneSpecification captureZonePrint() => ZoneSpecification(
  print: (self, parent, zone, line) {
    DevLog.instance.add(LogLevel.info, 'print', line);
    // Keine eigene Konsolen-Ausgabe hier: add() schreibt schon über die
    // Root-Zone auf die Konsole.
  },
);

/// Kurzform für den Zugriff aus dem restlichen Code.
DevLog get devLog => DevLog.instance;
