// Datei: chronicle/lib/services/backup/note_snapshots.dart
//
// ZWECK: Versions-History je Notiz („git-lite"). Vor jedem Überschreiben
//        wandert der alte Stand nach `.chronicle/snapshots/notes/`.
//
// WOFÜR: Eine Session zurücknehmen. Beim Journaling wird viel überschrieben
//        und umgeschrieben; ohne Historie ist ein versehentlich geleerter
//        Thread endgültig weg — und ein Vault-Backup dafür zu bemühen wäre
//        viel zu grob.
//
// ABLAGE: Der Pfad der Notiz wird als Ordner gespiegelt, der Zeitstempel ist
//        der Dateiname:
//
//          .chronicle/snapshots/notes/games/moor/log/haupt.md/20260920-0730.md
//
//        Spiegeln statt Umkodieren, weil jeder Trenner-Ersatz (`__`) mit
//        echten Dateinamen kollidieren kann — und weil die Ablage so von
//        Hand durchsuchbar bleibt.
//
// NOCH NICHT AM PLAY-LOG: Das Anhängen eines Eintrags zerstört nichts, und
//        eine Fassung je Eintrag würde das Fenster von zwanzig mit fast
//        identischen Kopien füllen — genau die eine Fassung, die jemand
//        sucht, wäre dann herausgefallen. Der Aufruf gehört dorthin, wo eine
//        Datei als Ganzes ersetzt wird: in den Codex-Editor (Schritt 5).
//
// SIEHE: Skill `vault-format`, Abschnitt „Backup, Snapshots, Migration"
// SCHRITT: 3b

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/dev_log.dart';
import '../../data/vault/vault_layout.dart';

/// Eine gespeicherte Fassung einer Notiz.
class NoteVersion {
  const NoteVersion({
    required this.path,
    required this.stamp,
    required this.created,
    required this.byteSize,
  });

  /// Absoluter Pfad zur Snapshot-Datei.
  final String path;

  /// Der Zeitstempel im Dateinamen, sortierbar.
  final String stamp;

  final DateTime created;
  final int byteSize;
}

/// Liest und schreibt die Versions-History einzelner Notizen.
class NoteSnapshots {
  const NoteSnapshots({this.keepPerNote = 20});

  /// Wie viele Fassungen je Notiz behalten werden.
  ///
  /// Endlich, weil die Historie sonst auf einem Stick unbemerkt wächst. Zwanzig
  /// deckt eine Spielsitzung mit Abstand ab.
  final int keepPerNote;

  /// Sichert den aktuellen Stand von [relPath], bevor er überschrieben wird.
  ///
  /// Gibt null zurück, wenn es noch nichts zu sichern gibt (neue Notiz) oder
  /// wenn der Inhalt sich seit der letzten Fassung nicht geändert hat — eine
  /// Historie aus identischen Kopien verdeckt nur die Stelle, die man sucht.
  Future<NoteVersion?> record(String vaultRoot, String relPath) async {
    final source = File(p.join(vaultRoot, relPath));
    if (!await source.exists()) return null;

    final content = await source.readAsBytes();
    final dir = Directory(_dirFor(vaultRoot, relPath));

    final existing = await versions(vaultRoot, relPath);
    if (existing.isNotEmpty) {
      final last = await File(existing.first.path).readAsBytes();
      if (last.length == content.length) {
        var identical = true;
        for (var i = 0; i < last.length; i++) {
          if (last[i] != content[i]) {
            identical = false;
            break;
          }
        }
        if (identical) return null;
      }
    }

    await dir.create(recursive: true);
    final created = DateTime.now().toUtc();
    final target = File(_freeName(dir.path, created, p.extension(relPath)));
    try {
      await target.writeAsBytes(content, flush: true);
    } on FileSystemException catch (error) {
      // Eine fehlgeschlagene Historie darf das Speichern nicht verhindern —
      // die Notiz selbst ist wichtiger als ihre Vorfassung.
      devLog.warn(
        'snapshots',
        'Fassung nicht sicherbar: $relPath',
        error: error,
      );
      return null;
    }

    await _prune(vaultRoot, relPath);
    return NoteVersion(
      path: target.path,
      stamp: _stamp(created),
      created: created,
      byteSize: content.length,
    );
  }

  /// Alle gespeicherten Fassungen von [relPath], neueste zuerst.
  Future<List<NoteVersion>> versions(String vaultRoot, String relPath) async {
    final dir = Directory(_dirFor(vaultRoot, relPath));
    if (!await dir.exists()) return const [];

    final out = <NoteVersion>[];
    await for (final item in dir.list(followLinks: false)) {
      if (item is! File) continue;
      final stamp = p.basenameWithoutExtension(item.path);
      final parsed = _parseStamp(stamp);
      if (parsed == null) continue;
      out.add(
        NoteVersion(
          path: item.path,
          stamp: stamp,
          created: parsed,
          byteSize: await item.length(),
        ),
      );
    }
    out.sort((a, b) => b.stamp.compareTo(a.stamp));
    return out;
  }

  /// Stellt die Fassung [stamp] von [relPath] wieder her.
  ///
  /// Der aktuelle Stand wird vorher selbst zur Fassung — ein Zurücknehmen
  /// ist damit umkehrbar, und niemand verliert beim Stöbern seinen Text.
  Future<void> restore(String vaultRoot, String relPath, String stamp) async {
    final all = await versions(vaultRoot, relPath);
    NoteVersion? wanted;
    for (final version in all) {
      if (version.stamp == stamp) {
        wanted = version;
        break;
      }
    }
    if (wanted == null) return;

    // Erst lesen, dann sichern. Andersherum wäre der Inhalt, den wir gleich
    // zurückschreiben wollen, schon vom Sichern des aktuellen Stands
    // überschrieben — ein Fehler, der genau dann zuschlägt, wenn beides in
    // dieselbe Sekunde fällt, also beim schnellen Probieren im UI.
    final content = await File(wanted.path).readAsBytes();

    await record(vaultRoot, relPath);

    final target = File(p.join(vaultRoot, relPath));
    await target.parent.create(recursive: true);
    await target.writeAsBytes(content, flush: true);
    devLog.info('snapshots', 'Fassung $stamp zurückgeholt: $relPath');
  }

  /// Entfernt die Historie einer Notiz — etwa, wenn die Notiz gelöscht wurde.
  Future<void> forget(String vaultRoot, String relPath) async {
    final dir = Directory(_dirFor(vaultRoot, relPath));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> _prune(String vaultRoot, String relPath) async {
    final all = await versions(vaultRoot, relPath);
    if (all.length <= keepPerNote) return;
    for (final version in all.skip(keepPerNote)) {
      try {
        await File(version.path).delete();
      } on FileSystemException catch (error) {
        devLog.warn('snapshots', 'Alte Fassung bleibt liegen', error: error);
      }
    }
  }

  String _dirFor(String vaultRoot, String relPath) => p.joinAll([
    VaultLayout.snapshots(vaultRoot),
    'notes',
    ...p.split(relPath.replaceAll('\\', '/')),
  ]);

  /// Ein freier Dateiname im Ordner der Notiz.
  ///
  /// Millisekunden im Stempel, plus ein Zähler als letzte Rückfallebene:
  /// Zwei Fassungen in derselben Sekunde sind beim Tippen der Normalfall,
  /// und die zweite darf die erste nicht stillschweigend überschreiben.
  static String _freeName(String dir, DateTime created, String extension) {
    final stamp = _stamp(created);
    var candidate = p.join(dir, '$stamp$extension');
    for (var i = 2; File(candidate).existsSync() && i < 1000; i++) {
      candidate = p.join(dir, '$stamp-$i$extension');
    }
    return candidate;
  }

  static String _stamp(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    final millis = time.millisecond.toString().padLeft(3, '0');
    return '${time.year}${two(time.month)}${two(time.day)}'
        '-${two(time.hour)}${two(time.minute)}${two(time.second)}'
        '-$millis';
  }

  static DateTime? _parseStamp(String stamp) {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})-(\d{3})',
    ).firstMatch(stamp);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
      int.parse(match.group(7)!),
    );
  }
}
