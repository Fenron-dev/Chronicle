---
name: flutter-conventions
description: >-
  Die Flutter-/Dart-Konventionen von Chronicle — Riverpod 3 mit @riverpod-Codegen, Drift-Tabellen
  und FTS5, go_router 18 mit StatefulShellRoute, der build_runner-Workflow über GitHub Actions
  (niemals lokal bauen), die Ordnerstruktur unter lib/ und die Fehlerbehandlung. Dieser Skill ist
  bei jeder Code-Änderung an der App zu lesen — also auch dann, wenn nur „ein Provider ergänzt",
  „eine Route hinzugefügt", „eine Tabelle erweitert", „ein Widget gebaut", „ein Test geschrieben"
  oder „ein Paket hinzugefügt" werden soll. Im Zweifel lesen: ein lokaler Build-Versuch verstößt
  gegen einen harten Constraint des Projekts.
---

# Chronicle Flutter-Konventionen

## Das Wichtigste zuerst: keine lokalen Builds

`flutter build`, `flutter run` und `dart run build_runner` laufen **nicht** auf der
Entwicklungsmaschine. Grund ist kein Dogma, sondern chronischer Speicherplatzmangel — ein einzelner
Flutter-Build-Ordner kostet mehrere Gigabyte, und das Projekt ist daran schon gescheitert.

Der Weg stattdessen:

1. Code schreiben.
2. Pushen (Branch `claude/**` oder ein PR löst `ci.yml` aus).
3. Die CI führt `flutter pub get` → `build_runner build` → `flutter analyze` → `flutter test` aus.
4. Build-Artefakte liegen unter **Actions → Lauf → Artifacts**.

Daraus folgt für die Arbeitsweise: **generierte Dateien (`*.g.dart`, `*.freezed.dart`) liegen nicht
im Repo.** Sie entstehen in der CI. Wer Code schreibt, der auf generierte Symbole zugreift, sieht
lokal rote Squiggles — das ist erwartet und kein Grund, den Codegen lokal zu starten. Die
Rückmeldung kommt aus dem CI-Lauf.

Daraus folgt außerdem: **Code muss beim ersten Mal stimmen.** Ein CI-Durchlauf kostet Minuten, kein
Sekundenbruchteil. Vor dem Push den eigenen Diff gegenlesen, als wäre man der Analyzer: fehlende
`part`-Direktive? Falscher Provider-Name? Nicht importiertes Symbol?

### `flutter analyze` scheitert auch an `info`

Es gibt im Gate keine harmlose Stufe: eine Meldung mit `info •` lässt den Lauf genauso scheitern
wie ein `error •`. Jeder Vorschlag ist also zu befolgen oder bewusst abzuschalten — Ignorieren
ist keine Option.

Ein Beispiel, das sicher wiederkommt: Dart kennt seit 3.8 **null-aware Elemente**, und der
Analyzer besteht darauf.

```dart
children: [
  if (trailing != null) trailing!,   // info • use_null_aware_elements
  ?trailing,                         // so ist es gemeint
]
```

Zwei weitere, die regelmäßig auftauchen und dieselbe Wurzel haben — Dart ist seit 3.7/3.8
ausdrucksstärker geworden, und der Analyzer erwartet die neue Form:

```dart
// unnecessary_non_null_assertion: eine lokale Variable wird nach dem
// Null-Check befördert, das `!` ist dann überflüssig. Eine lokale Kopie
// macht die Beförderung sichtbar und kommt ohne `!` aus.
final id = currentId;
if (id == null) return;
use(id);

// unnecessary_underscores: mehrfaches `_` ist seit Dart 3.7 als Wildcard
// erlaubt — `__` und `___` braucht niemand mehr.
builder: (context, _, _) => …
```

### Paket-APIs nicht aus dem Gedächtnis schreiben

Zwei Beispiele aus diesem Projekt, beide auf demselben Weg gefunden — Quelltext des Pakets lesen,
nicht erinnern:

```dart
// file_picker 13: FilePicker ist `abstract final class` mit STATISCHEN
// Methoden (kein `.platform` mehr), und pickFiles liefert eine LISTE,
// kein nullbares Ergebnis. Abbruch ist die leere Liste.
final picked = await FilePicker.pickFiles(type: FileType.custom,
    allowedExtensions: const ['zip']);
if (picked.isEmpty) return;
final path = picked.first.path;   // String?, auf dem Web null

// archive 4: ZipFileEncoder schreibt Datei für Datei auf die Platte
// (create → addFile → close). ZipDecoder().decodeBytes zieht dagegen das
// ganze Archiv in den Speicher — bei einem Vault mit Medien ein Problem.
final input = InputFileStream(path);
final archive = ZipDecoder().decodeStream(input);
```

Reine Dart-Logik lässt sich dabei **lokal** gegenprüfen: ein Wegwerf-Paket im Scratch-Verzeichnis,
`dart pub get`, die Datei hineinkopieren, `dart analyze` und `dart test`. Das kostet kein
nennenswertes Volumen (§2.1 erlaubt es ausdrücklich) und spart den CI-Durchlauf, in dem sonst ein
falscher Methodenname auffällt. Hängt die Datei an Flutter — etwa über `core/dev_log.dart` — wird
für den lokalen Lauf ein Stub danebengelegt.

Dass das kein Luxus ist, zeigt der Backup-Code: der lokale Lauf fand einen echten Fehler, den kein
Analyzer gesehen hätte — `NoteSnapshots.restore` las die Datei der alten Fassung *nach* dem
Sichern des aktuellen Stands, und bei sekundengenauen Zeitstempeln überschrieb dieses Sichern
genau die Datei, die gleich gelesen werden sollte.

### Formatierung: das CI-Gate prüft `dart format`

`dart format --output=none --set-exit-if-changed lib test` läuft als erster Schritt — ein
Formatierungsfehler kostet denselben Durchlauf wie ein echter Bug.

Die wichtigste Falle ist der **Tall-Style-Formatter** (ab Dart 3.7): **eine abschließende Komma
erzwingt keinen Umbruch mehr.** Der Formatter entscheidet allein nach Zeilenbreite (80 Zeichen).
Ein Widget-Baum, der als mehrzeilige Konstruktion mit Trailing Comma geschrieben ist, wird
zusammengezogen, wenn er in eine Zeile passt:

```dart
// So geschrieben …
return const MaterialApp(
  title: 'Chronicle',
  home: _PlaceholderScreen(),
);

// … so formatiert (passt in 80 Zeichen):
return const MaterialApp(title: 'Chronicle', home: _PlaceholderScreen());
```

Beim Schreiben also mitzählen: passt der Ausdruck inklusive Einrückung in 80 Zeichen, gehört er in
eine Zeile. Wer mehrzeilig formatieren *will*, muss den Ausdruck echt zu lang machen — nicht bloß
ein Komma setzen.

---

## Ordnerstruktur

```
chronicle/lib/
├── main.dart
├── app/            # App-Widget, Router, Shell, Workspaces
├── core/           # theme/, constants.dart, errors.dart, result.dart
├── data/
│   ├── db/         # database.dart, tables/, daos/
│   └── vault/      # VaultManager, Scanner, Rebuild, RecentVaultsStore
├── domain/         # reine Dart-Logik — importiert NIE package:flutter/*
│   ├── roll_engine/  wikilink/  frontmatter/  filter/
├── features/       # je Feature: screens + widgets + provider beieinander
│   └── play_log/  codex/  roller/  systems/  games/  vault_picker/  settings/
├── services/       # llm/, media/, backup/, sync/
└── widgets/        # app-weite, feature-unabhängige Widgets
```

**`domain/` ohne Flutter-Import** ist die einzige Struktur-Regel mit echten Konsequenzen: sie hält
die Logik in Isolates lauffähig, ohne Widget-Test testbar, und macht die Roll-Engine weiterhin von
anderen Apps importierbar — genau so, wie wir sie aus OracleVault übernehmen.

**Features schneiden vertikal.** Screen, Widgets und Provider eines Features liegen beieinander.
Ein `providers/`-Sammelordner quer über alle Features entsteht hier nicht — er wächst zu einer
Datei, die jeder anfasst und niemand versteht.

### Dateikopf-Kommentar

Wie in OracleVault trägt jede nicht triviale Datei einen kurzen Kopf. Er beantwortet, was aus dem
Code allein nicht hervorgeht:

```dart
// Datei: lib/data/vault/vault_scanner.dart
//
// ZWECK: Läuft den Vault-Dateibaum ab und liefert die Roh-Einträge für den
//        Index-Rebuild. Kennt kein Drift — die Persistenz macht der Aufrufer.
//
// WARUM SO: Trennung, weil der Scanner auch für den Bundle-Export (§8 Konzept)
//           gebraucht wird, dort aber nichts indiziert werden soll.
//
// SCHRITT: 3
```

Kommentare und Doku auf **Deutsch**, Code-Bezeichner auf **Englisch**.

---

## Riverpod 3 mit Codegen

Provider werden **generiert**, nicht von Hand deklariert. `@riverpod` erzeugt den passenden
Provider-Typ, die richtige `ref`-Signatur und einen `Ref`-Typ, der nur die Abhängigkeiten dieses
Providers kennt — das fängt eine ganze Klasse von Verdrahtungsfehlern schon beim Generieren ab.

```dart
// lib/features/play_log/play_log_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'play_log_provider.g.dart';   // ohne diese Zeile generiert build_runner nichts

/// Alle Einträge eines Threads, sortiert nach Zeitstempel.
@riverpod
Future<List<LogEntry>> logEntries(Ref ref, String threadId) async {
  final dao = ref.watch(logDaoProvider);
  return dao.entriesForThread(threadId);
}

/// Schreibzugriff auf einen Thread.
@riverpod
class LogThread extends _$LogThread {
  @override
  Future<Thread> build(String threadId) =>
      ref.watch(logDaoProvider).thread(threadId);

  Future<void> append(LogEntry entry) async {
    // Erst Datei, dann Index — die Reihenfolge ist die Vault-Grundregel.
    await ref.read(vaultWriterProvider).appendEntry(threadId, entry);
    ref.invalidateSelf();
  }
}
```

**Konventionen**

- Ein Provider je Zuständigkeit, benannt nach dem, was er liefert (`logEntries`), nicht nach seiner
  Mechanik (`logEntriesFutureProvider`).
- `ref.watch` in `build`, `ref.read` in Callbacks. `ref.read` in `build` ist fast immer ein Bug: der
  Provider baut sich dann nicht neu, wenn die Abhängigkeit sich ändert.
- **Kein `keepAlive` als Reflex.** Standard ist `autoDispose` (bei Codegen ohnehin die Vorgabe).
  `@Riverpod(keepAlive: true)` nur für echte App-Singletons — `VaultManager`, DB-Handle, Settings —
  und mit einem Kommentar, warum.
- Parametrisierte Provider bekommen einfache, vergleichbare Parameter (String/int/Record). Ein
  Objekt ohne `==` erzeugt bei jedem Build eine neue Provider-Instanz und damit ein Speicherleck.
- **Riverpod 3 Hinweis:** `Ref` ist nicht mehr generisch (kein `LogEntriesRef` mehr) — die Signatur
  ist schlicht `Ref ref`. Codebeispiele aus der Riverpod-2-Ära müssen hier angepasst werden.

---

## Drift + FTS5

Die DB ist ein **Index**, kein Speicherort (siehe Skill `vault-format`). Jede Tabelle beantwortet
die Frage: „Ist das aus den Dateien wiederherstellbar?" — wenn nein, gehört das Feld in die Datei.

```dart
// lib/data/db/tables/notes.dart
class Notes extends Table {
  /// UUID v4 — kommt aus dem Frontmatter der Datei, nicht aus der DB.
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  /// Relativ zum Vault-Root. Absolute Pfade brechen die Portabilität.
  TextColumn get relPath => text()();
  DateTimeColumn get created => dateTime()();
  DateTimeColumn get updated => dateTime()();
  TextColumn get frontmatterJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Regeln**

- **UUID-Primärschlüssel überall**, als `TextColumn`. Kein `autoIncrement` — Sync und Bundle-Export
  brauchen stabile, maschinenübergreifende IDs.
- **Keine FK-Spalte je Beziehungsart.** Relationen laufen über die generische `Edges`-Tabelle
  (`fromType`/`fromId` → `toType`/`toId` + `relation`). Backlinks kommen so aus *einer* Query, und
  ein neuer Relationstyp braucht keine Migration.
- **FTS5** als virtuelle Tabelle, im Drift-Schema über eine `.drift`-Datei deklariert. Der
  FTS-Inhalt wird beim Schreiben mitgepflegt und beim Rebuild komplett neu befüllt.
- **Migrationen:** `schemaVersion` erhöhen, `MigrationStrategy` schreiben — und **davor** einen
  Auto-Snapshot nach `.chronicle/snapshots/`. Ohne Snapshot wird die Migration nicht gemergt.
- Für konsistente Backup-Snapshots `VACUUM INTO` über das `sqlite3`-Paket nutzen; es läuft nicht in
  einer Transaktion und damit nicht aus einer Drift-Migration heraus.
- DB-Zugriff kapselt ein **DAO**. Widgets sehen nie eine Drift-Query — sie sehen einen Provider.
- Die DB wird über `drift/native.dart` geöffnet, weil der Pfad aus dem nutzer-gewählten Vault
  kommt. **Kein `sqlite3_flutter_libs`** — EOL, `sqlite3` 3.x bringt die nativen Bibliotheken selbst.

---

## go_router 18 mit `StatefulShellRoute`

`StatefulShellRoute.indexedStack` gibt jedem Bereich einen eigenen Navigations-Stack. Ein Wechsel
von Play-Log zu Codex und zurück verliert die Scroll-Position nicht — bei einem
Journaling-Tool, in dem man ständig zwischen Log und Nachschlagen springt, ist das kein Detail.

```dart
// lib/app/router.dart
final routerProvider = Provider<GoRouter>((ref) {
  final vault = ref.watch(activeVaultProvider);

  return GoRouter(
    initialLocation: Routes.vaultPicker,
    // Ohne offenen Vault gibt es nichts anzuzeigen — der Picker ist die einzige
    // sinnvolle Route.
    redirect: (context, state) {
      final onPicker = state.matchedLocation == Routes.vaultPicker;
      if (vault == null && !onPicker) return Routes.vaultPicker;
      if (vault != null && onPicker) return Routes.play;
      return null;
    },
    routes: [
      GoRoute(path: Routes.vaultPicker, builder: (_, __) => const VaultPickerScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ResponsiveShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.play,  builder: …)]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.codex, builder: …)]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.systems, builder: …)]),
        ],
      ),
    ],
  );
});
```

**Regeln**

- Routen-Pfade als Konstanten in `lib/app/routes.dart`. Kein String-Literal im Aufrufcode.
- Der Router hängt an `activeVaultProvider`, damit ein Vault-Wechsel die Redirect-Logik neu
  auswertet.
- **`ResponsiveShell` entscheidet Desktop vs. Mobile** anhand eines Breakpoints und rendert
  `DesktopShell` (3-Panel) oder `MobileShell` (Bottom-Nav) — Muster aus MediaShelf. Die Routen
  wissen davon nichts.
- Tiefe Verlinkung (`[[Seite]]` → Navigation) läuft über benannte Routen mit UUID-Parameter, nicht
  über Dateipfade: Pfade ändern sich, UUIDs nicht.

---

## build_runner-Workflow

Generiert werden Riverpod-Provider (`*.g.dart`) und Drift-Code (`*.g.dart` / `*.drift.dart`).

- Ausführung **ausschließlich in der CI**: `dart run build_runner build --delete-conflicting-outputs`.
- Generierte Dateien sind in `.gitignore` — sie sind reproduzierbar und würden jeden Diff fluten.
- Jede Datei mit `@riverpod` braucht `part '<dateiname>.g.dart';`. Fehlt die Zeile, wird still
  nichts generiert, und der Fehler erscheint erst als „Undefined name …Provider" im Analyzer.
- Datei umbenannt → `part`-Direktive mit umbenennen.

---

## Die Build-Reihenfolge der Generatoren

`riverpod_generator` läuft **vor** `drift_dev`. Eine von Drift generierte Klasse — `Note`,
`Edge`, `NotesCompanion` — existiert also noch nicht, wenn Riverpod seinen Code schreibt. Taucht
eine davon in der **Signatur** eines `@riverpod`-Providers auf, bricht der Lauf ab mit:

```
E riverpod_generator on lib/…: InvalidTypeException: The type is invalid
  and cannot be converted to code.
```

Die Fehlermeldung nennt die Datei, nicht die Zeile — gesucht wird der Provider, dessen Rückgabetyp
ganz aus generiertem Code stammt. Handgeschriebene Klassen sind unproblematisch, auch wenn ihre
*Oberklasse* generiert ist: `ChronicleDatabase extends _$ChronicleDatabase` steht als Klasse im
Quelltext und löst auf; `Note` steht ausschließlich in der `part`-Datei und löst nicht auf.

**Die Lösung ist keine Notlösung, sondern die richtige Schichtung:** Ein Provider gibt ein
handgeschriebenes Modell zurück (`VaultNote`), und das DAO übersetzt die Drift-Zeile dorthin.
Genau das verlangt die Regel „Widgets sehen nie eine Drift-Query" ohnehin — eine Drift-Zeile im
Widget-Baum macht jede Schema-Änderung zu einer UI-Änderung. Die Build-Reihenfolge erzwingt hier
nur, was sonst Disziplin wäre.

Drift-Typen bleiben damit auf die Datenschicht beschränkt: `database.dart` und was direkt für sie
schreibt. Keine dieser Dateien enthält `@riverpod`.

---

## Fehlerbehandlung

Die Leitfrage: **Ist das ein Nutzerfehler, ein Umgebungsfehler oder ein Programmierfehler?**
Die drei werden unterschiedlich behandelt, und sie zu vermischen ist die häufigste Ursache dafür,
dass echte Bugs in einem Meer von SnackBars untergehen.

| Art | Beispiel | Behandlung |
|---|---|---|
| **Nutzerfehler** | Ungültiger Würfelausdruck, kaputtes Frontmatter | Typisierter Fehlerwert, im UI erklärt. Kein Throw. |
| **Umgebungsfehler** | Datei weg, Ordner schreibgeschützt, LLM-Endpoint down | Gefangen, in eine Domänen-Exception übersetzt, mit Handlungsoption angeboten. |
| **Programmierfehler** | Provider fehlt, Schema inkonsistent, Invariante verletzt | `assert` / laut scheitern. Nicht wegfangen. |

**Konkret**

- `domain/` wirft **typisierte Exceptions** (`DiceParseException`, `CycleDetectedException`), nie
  rohe `Exception`. Der Aufrufer soll unterscheiden können, ohne Strings zu vergleichen.
- **Datei-I/O bekommt immer einen Fallback.** Ein Vault kann auf einem USB-Stick liegen, der mitten
  im Schreiben abgezogen wird — das ist hier ein realistischer Fall, kein Randfall.
- **Ein kaputter Index ist nie fatal.** Bei Parse- oder Schema-Fehler: rebuilden, nicht reparieren,
  nicht abstürzen.
- **Eine kaputte Datei blockiert nie den ganzen Scan.** Sie wird übersprungen, gesammelt und am
  Ende als Liste gemeldet — sonst macht eine defekte Notiz den kompletten Vault unbenutzbar.
- `AsyncValue.when` im UI mit *allen drei* Fällen. Ein `error: (_, __) => const SizedBox()`
  versteckt genau die Information, die man beim Debuggen braucht.
- **Kein `print`.** Logging über eine zentrale Stelle in `core/`.

---

## Tests

- **`domain/` hat echte Unit-Tests.** Roll-Engine, Dice-Parser, Wikilink-Parser, Frontmatter-Parser
  sind reine Funktionen und billig zu testen — hier zahlt sich Abdeckung sofort aus.
- **Vault-Round-Trip-Tests:** schreiben → Index rebuilden → gleicher Zustand. Das ist der Test, der
  die Grundregel des Projekts absichert; ohne ihn merkt niemand, wenn ein Feld nur in der DB landet.
- **Golden-Tests je Theme-Preset** für die zentralen Ansichten (siehe Skill `chronicle-theme`).
- Widget-Tests für Logik im Widget, nicht für Layout-Details — Layout-Tests brechen bei jeder
  Design-Änderung und werden dann pauschal aktualisiert, was ihren Wert aufhebt.

### Zwei Fallen in Widget-Tests, die nicht scheitern, sondern hängen

Beide kosten kein rotes Kreuz, sondern das Job-Limit — und damit die Rückmeldung.

**`pumpAndSettle` wird nie fertig, wenn eine Endlos-Animation im Baum steht.** Ein unbestimmter
`LinearProgressIndicator` oder `CircularProgressIndicator` plant für immer neue Frames ein; der
Baum wird nie „ruhig". Genau das ist in Chronicle der Normalfall, denn der Vault-Picker zeigt
während des Index-Aufbaus einen Fortschrittsbalken. Statt `pumpAndSettle` also eine feste Zahl
Durchläufe:

```dart
for (var i = 0; i < 6; i++) {
  await tester.pump(const Duration(milliseconds: 16));
}
```

**Echte Datei-I/O gehört in `tester.runAsync`.** Der Rumpf von `testWidgets` läuft in einer
Fake-Async-Zone. Ein Future, das auf die Platte wartet, wird dort nie fertig — der Test steht,
bis das Zeitlimit greift.

```dart
await tester.runAsync(() async {
  await container.read(activeVaultProvider.notifier).createAndOpen(dir.path, 'Test');
});
```

**Und die Konsequenz daraus:** Zustandslogik gehört gar nicht in einen Widget-Test. Ob das
Vault-Gate umschaltet, prüft ein `ProviderContainer` in einem gewöhnlichen `test()` — schneller,
ohne Pump-Zyklen, und der eigentliche Punkt steht im Code statt dahinter. Der Widget-Test prüft
dann nur noch, dass das Ergebnis auch gerendert wird.

`flutter test --timeout 90s` in der CI sorgt dafür, dass ein Hänger nach anderthalb Minuten
scheitert statt nach zehn.
- Tests laufen in der CI (`flutter test --reporter expanded`).

---

## Pakete hinzufügen

1. Aktuelle Version auf pub.dev prüfen — nicht aus dem Gedächtnis pinnen.
2. Prüfen, ob es das Paket für **alle fünf Zielplattformen** gibt (macOS, iOS, Android, Windows,
   Linux). Ein Desktop-Loch fällt erst im CI-Build auf, also spät.
3. Prüfen, ob es **offline** funktioniert (`CLAUDE.md` §2.3).
4. In `pubspec.yaml` eintragen, **mit Kommentar warum** — so wie in OracleVault. In sechs Monaten
   weiß sonst niemand mehr, wofür `pasteboard` da war.
5. Version in der Tabelle in `CLAUDE.md` §3 nachtragen.
6. Braucht das Paket native Konfiguration (`media_kit`!), gehört sie in die committeten
   Plattform-Ordner — nicht in einen CI-Schritt, der sie bei jedem Lauf nachrüstet.
