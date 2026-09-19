# CLAUDE.md

Leitfaden für Claude Code (claude.ai/code) in diesem Repository.
**Diese Datei ist die Quelle der Wahrheit.** Bei Widersprüchen zwischen Code, Chat und dieser Datei
gilt diese Datei — oder das Konzept-Dokument (`docs/Konzept.md`), wenn es hier um eine inhaltliche
Frage geht, die CLAUDE.md nicht beantwortet.

---

## 1. Projektziel

**Chronicle** ist eine portable, lokal-first Flutter-App zum **Spielen von Journaling-Solo-RPGs**
(Desktop primär, Mobile mitgedacht). Sie verwaltet beliebige Spielsysteme (Regeln, Tabellen,
Gameloops), führt durchs Spiel (Würfeln, Orakel, Karten, Clocks) und hält den Verlauf als schön
gestaltbares Journal fest. Alles liegt in einem **Vault** (Obsidian-artig), der auf einen USB-Stick
passt.

**Einordnung im Ökosystem:** Chronicle ist der **Play-/Journal-Layer**. OracleVault ist die
Daten-Grundlage (Tabellen, Orakel, Decks, Roll-Engine) und explizit *kein* Play-Tool. Chronicle
beginnt genau dort, wo OracleVaults „Out of Scope"-Liste endet: Würfeln mit History, Scene-Trigger,
Generatoren-Nutzung, VTT-light, Charakterbögen, Kampagnen-Management.

**Leitprinzipien**
- Local-first & portabel — ein Vault = ein Ordner, kein Server.
- Flow beim Spielen — Würfeln → interpretieren → schreiben ohne Reibung.
- Schön dokumentieren — deklarativ über Themes/Frontmatter, nicht durch Hand-Layout pro Notiz.
- KI als Werkzeug, nicht als Zwang — optional, BYOK, immer abschaltbar.
- Nichts doppelt bauen — bestehende Projekte des Ökosystems werden wiederverwendet.

---

## 2. Harte Constraints

Diese fünf Regeln werden **nicht** verletzt. Sie sind keine Stilfragen, sondern tragen das
Projekt-Design:

### 2.1 Builds ausschließlich über GitHub Actions
**Niemals lokal kompilieren.** Kein `flutter build`, kein `flutter run`, kein `dart run
build_runner` auf der Entwicklungsmaschine. Grund: chronische lokale Speicherplatz-Probleme.

Stattdessen: Code + Workflow schreiben, per CI bauen lassen, Artefakt herunterladen.
`flutter analyze`, `flutter test` und die Codegen laufen in `.github/workflows/ci.yml`.
Wer einen Build braucht, pusht auf einen Branch oder startet den Workflow per `workflow_dispatch`.

*Ausnahme:* reine Dart-Logik ohne Flutter-Abhängigkeit darf mit `dart test` lokal geprüft werden,
wenn ein Dart-SDK ohne Flutter-Toolchain vorhanden ist — das kostet kein nennenswertes Volumen.
Im Zweifel: CI.

### 2.2 Local-first & portabel
Ein Vault = ein Ordner. Der Ordner ist auf einem USB-Stick lauffähig und lässt sich weiterreichen.
Keine absoluten Pfade im Vault, keine Referenz auf App-Installationsverzeichnisse, keine
Datenbank-Handles außerhalb des Vaults.

### 2.3 Offline-first
Zur Laufzeit keine Cloud-Abhängigkeit — außer den vom Nutzer selbst konfigurierten LLM-APIs, die
per globalem Schalter komplett abschaltbar sind. Kein Remote-Asset, kein Remote-Script, kein
Telemetrie-Call. Eingebettetes Roh-HTML wird sanitized (kein Script, keine Remote-Requests).

### 2.4 API-Keys niemals im Vault
Keys liegen ausschließlich im OS-Secure-Storage (`flutter_secure_storage`). Im Vault steht nur die
**Profil-Struktur** (`name`, `kind`, `baseUrl`, `defaultModel`, `temperature`, `maxTokens`,
`hasApiKey`, `tier`, `isLocal`) — nie ein Secret. Ein weitergereichter Vault darf keinen Key
enthalten.

### 2.5 Dateien = Wahrheit, DB = Index
Markdown/JSON im Vault ist maßgeblich. `.chronicle/index.db` (Drift + FTS5) ist ein **aus den
Dateien vollständig neu aufbaubarer Cache**. Daraus folgt konkret:
- Jede Information, die nur in der DB steht, ist verloren. Erst in die Datei schreiben, dann
  indizieren.
- „Vault auf fremdem Rechner öffnen → Index rebuild → alles da" muss jederzeit gelten.
- `index.db` gehört nicht ins Backup (regenerierbar) — der Dateibaum schon.
- Ein Löschen von `.chronicle/` darf nie Nutzerdaten kosten.

---

## 3. Tech-Stack

Geprüft am **2026-09-19** gegen pub.dev. Flutter stable **3.47.5**, Dart **3.13.4**.

> **Abweichung vom Konzept, bewusst:** Das Konzept (§10) nennt „Riverpod 2" und „go_router 14".
> Wir starten auf den aktuellen Majors — **Riverpod 3** (`@riverpod`-Codegen unverändert via
> `riverpod_annotation` 4.x) und **go_router 18** (`StatefulShellRoute` unverändert). Greenfield-
> Projekt, daher kein Migrationsaufwand; ein Start auf veralteten Majors hätte einen gekostet.

| Bereich | Paket | Version |
|---|---|---|
| Framework | Flutter / Dart | 3.47.5 / 3.13.4 |
| DB | `drift` / `drift_dev` | ^2.35.0 |
| DB (nativ) | `sqlite3` | ^3.6.0 |
| State | `flutter_riverpod` | ^3.4.3 |
| State (codegen) | `riverpod_annotation` / `riverpod_generator` | ^4.0.7 / ^4.0.9 |
| Routing | `go_router` | ^18.0.1 |
| Medien | `media_kit` + `media_kit_video` + `media_kit_libs_video` | ^1.2.6 / ^2.0.1 / ^1.0.7 |
| Secure Storage | `flutter_secure_storage` | ^11.2.0 |
| Ordner-Auswahl | `file_picker` | ^13.1.0 |
| App-Settings | `shared_preferences` | ^2.5.5 |
| UUID | `uuid` | ^4.6.0 |
| Backup (ZIP) | `archive` | ^4.3.0 |
| Frontmatter | `yaml` | ^3.1.4 |
| Markdown | `markdown` | ^7.3.1 |
| Fonts | `google_fonts` | ^8.2.1 |
| Hashing | `crypto` | ^3.0.7 |
| HTTP (LLM) | `http` | ^1.6.0 |
| Sync (später) | `shelf` / `shelf_router` | ^1.4.2 / ^1.1.4 |
| Lints | `flutter_lints` | ^6.0.0 |
| Codegen | `build_runner` | ^2.16.1 |

**Wichtig:** `sqlite3_flutter_libs` ist **EOL** („Not used anymore, update to version 3.x of
package:sqlite3 instead"). `sqlite3` 3.x bringt die nativen Bibliotheken selbst mit — nicht mehr
hinzufügen. Aus demselben Grund verzichten wir auf `drift_flutter` (hängt noch an den EOL-Paketen)
und öffnen die DB direkt über `drift/native.dart`; das passt ohnehin besser, weil der Pfad aus einem
nutzer-gewählten Vault-Ordner kommt und nicht aus dem App-Dokumentenverzeichnis.

Versionen bei größeren Abhängigkeits-Änderungen hier aktualisieren, nicht nur in `pubspec.yaml`.

---

## 4. Reuse-Karte

**Nicht neu bauen — portieren.** Die Quellen liegen in eigenen Repos; bewährte Muster übernehmen,
inklusive ihrer `CLAUDE.md`-Struktur.

| Quelle | Was übernommen wird | Ziel in Chronicle |
|---|---|---|
| **OracleVault** | Roll-Engine (`uniform`/`weighted`/`dice`/`deck` inkl. Tarot, `XdY+Z`-Parser mit keep-highest/lowest, rekursive Subtables mit Cycle-Detection) | `lib/domain/roll_engine/` |
| OracleVault | Wikilink-Parser (`[[Seite]]`, `[[Seite#Abschnitt]]`, `[[Seite\|Alias]]`, `![[bild.png]]`) | `lib/domain/wikilink/` |
| OracleVault | Vault-Format-Muster (`.oraclevault/` → `.chronicle/`), `VaultManager`, `RecentVaultsStore`, `VaultRecovery` | `lib/data/vault/` |
| OracleVault | Datenmodell Tabellen/Entries/Decks, Edge-Tabelle, `Source` mit `ai_generation` | `lib/data/db/tables/` |
| OracleVault | `LLMProfile`-Grundmuster, `ApiKeyStore` (mit SharedPreferences-Fallback bei Keychain-Fehler) | `lib/services/llm/` |
| OracleVault | CI-Workflow-Aufbau (Gate → Matrix-Build → Release-on-Tag) | `.github/workflows/ci.yml` |
| **MediaShelf** | Portables `.vault/index.db`-Muster | `lib/data/db/` |
| MediaShelf | Isolate-Thumbnailer (Pool) | `lib/services/media/` |
| MediaShelf | `ResponsiveShell` (Breakpoint → `DesktopShell` / `MobileShell`) | `lib/app/shell/` |
| MediaShelf | `SmartFilter {logic, rules}`-JSON-Schema — **kompatibel halten** | `lib/domain/filter/` |
| **MindFeed** | LLM-Profile + Fallback-Ketten, `analyzeImage` (Vision) | `lib/services/llm/` |
| MindFeed | FTS5-Suche, Tags/EAV-Properties, Backup/Restore (ZIP) | `lib/data/db/`, `lib/services/backup/` |
| **PomTechFlow** | Sync: QR- + mDNS-Pairing, UUID-Sync, Konflikt-UI (später) | `lib/services/sync/` |
| PomTechFlow | JSON-Backup-Muster, Multi-Plattform-CI-Vorlage | `lib/services/backup/` |
| **BiNo** | App-Struktur Riverpod + go_router + `StatefulShellRoute`, Sharing-Intent, `local_auth` | `lib/app/` |

**Import statt Live-Referenz:** OracleVault liegt nicht garantiert im selben Netzwerk vor.
Tabellen/Decks/Medien werden **in unseren Vault kopiert** (Bundle-Snapshot, z. B. `.orcl`). Die
laufende Partie ist damit autark. Nur die Roll-Engine wird als *Code* importiert.

---

## 5. Vault-Architektur

### 5.1 Drei Ebenen

```
Vault  ⊃  System (Regelwerk, wiederverwendbar)  ⊃  Game (laufende Partie)
```

- **Vault** — der portable Container. Enthält alles.
- **System** — wiederverwendbares Regelwerk: Regeltexte, Tabellen/Orakel/Decks, Entity-Templates,
  Charakterbogen-Vorlagen, Procedures/Gameloops, Theme, **Default-Ablageorte**. Ein System → viele
  Spiele. Als `.zip` teilbar.
- **Game / Playthrough** — konkrete Partie: Play-Log, Entities, Tracker/Clocks, KI-Grounding.
  Referenziert **genau ein** System.

**Defaults-Regel:** Standard-Ablageorte und -Layouts kommen vom **System**; das einzelne **Game**
darf sie überschreiben. Beim Auflösen eines Werts also immer: Game → System → App-Default.

### 5.2 On-Disk-Layout

```
<vault>/
├── .chronicle/
│   ├── index.db          # Drift + FTS5 — aus Dateien neu aufbaubar (Cache/Index)
│   ├── thumbnails/       # regenerierbar, nicht im Backup
│   ├── snapshots/        # Auto-Snapshots vor Migrationen + Versions-History pro Notiz
│   ├── backups/          # manuelle/automatische Backups
│   └── config.json       # Vault-Einstellungen
├── systems/              # ein Unterordner je Spielsystem (teilbar)
│   └── <system>/
│       ├── system.json   rules.md  tables/  decks/  templates/
│       ├── sheets/  procedures/  theme/
├── games/                # ein Unterordner je Partie
│   └── <game>/
│       ├── game.json  log/  codex/  entities/
│       ├── sheets/  canvases/  media/
├── media/                # geteilte Medien (Bilder/Audio/Video/Dokumente)
└── README.md
```

Details (Frontmatter-Keys, Wikilink-Syntax, Rebuild-Regel, Medien-Handling) stehen im Skill
**`vault-format`** — dort nachschlagen, bevor etwas am Dateiformat geändert wird.

### 5.3 Invarianten

- **UUID-Primärschlüssel überall.** Nötig für Sync und Bundle-Export. Die UUID steht im
  Frontmatter der Datei (`id:`), nicht nur in der DB — sonst überlebt sie kein Rebuild.
- **Wikilinks werden beim Speichern geparst** und als `Edge`-Zeilen materialisiert. Der Rohtext
  bleibt unangetastet; Edges sind redundant, aber abfragbar (Backlinks aus *einer* Query).
- **Multi-Vault** mit Vault-Picker (Obsidian-artig) plus Liste zuletzt geöffneter Vaults.
- **Backup ab Tag 1.** Auto-Snapshot **vor jeder Migration**. Ohne funktionierendes Restore wird
  keine Migration gemergt.
- **Zwei Schreib-Oberflächen**, bewusst getrennt: **Play-Log** (chronologischer Stream getippter
  Einträge, roh) und **Codex-Seiten** (kuratiertes Markdown, schön). Überführung Log→Codex ist eine
  Aktion, kein Automatismus.

---

## 6. Theme-Architektur

Ein **Theme** ist ein austauschbares Token-Set, gebunden ans **System** (Default), überschreibbar
pro **Game**, feinjustierbar pro Notiz via Frontmatter.

**Flutter-Mapping:** jedes Preset → eine `ThemeData`-Variante; die Skin-Regler → eine
`ChronicleSkin`-`ThemeExtension`. **Tokens sind semantisch benannt**, nie an ein Preset gebunden —
also `entryOracle`, nicht `grimoirePurple`.

**Mitgelieferte Presets:** *Grimoire* (grim-dark mittelalterlich, Default) · *Nocturne* (klar,
minimal, modern) · *Terminal* (SciFi) · *Dossier* (moderne Erde). Umschalten ändert sichtbar
**Farben + Fonts + Ornamentik** zugleich.

**Skin-Parameter** (`ChronicleSkin`): `ornament` · `divider` · `button` · `texture` · `accentMode`
· `radiusScale`.

Details und die Anleitung „neues Preset anlegen" stehen im Skill **`chronicle-theme`**.

**Reihenfolge-Regel:** Das Theme-Layer entsteht **vor** den Screens. Jeder Screen wird damit von
Anfang an korrekt geskinnt gebaut — Nachrüsten ist teurer und erzeugt hartkodierte Farben.

---

## 7. Ordnerstruktur (`chronicle/lib/`)

```
lib/
├── main.dart
├── app/            # App-Widget, Router, Shell (Responsive/Desktop/Mobile), Workspaces
├── core/           # theme/, constants, Fehler-Typen, Ergebnis-Typen
├── data/
│   ├── db/         # Drift: database.dart, tables/, daos/
│   └── vault/      # VaultManager, Scanner, Rebuild, RecentVaultsStore
├── domain/         # reine Dart-Logik, ohne Flutter-Import
│   ├── roll_engine/  wikilink/  frontmatter/  filter/
├── features/       # je Feature ein Ordner: screens + widgets + provider
│   └── play_log/  codex/  roller/  systems/  games/  vault_picker/  settings/
├── services/       # llm/, media/, backup/, sync/
└── widgets/        # app-weite, feature-unabhängige Widgets
```

`domain/` importiert **nie** `package:flutter/*` — das hält die Logik isolate- und testbar und
macht die Roll-Engine weiterhin downstream-importierbar.

---

## 8. Baureihenfolge

Kleine, überprüfbare Schritte. **Je Feature ein eigener Branch/PR.** Nach jedem Schritt:
Analyzer/Tests in CI grün, kurze Zusammenfassung, dann weiter.

| Schritt | Inhalt | Status |
|---|---|---|
| **1** | Repo-Setup, `CLAUDE.md`, Skills, CI-Workflows (Analyzer/Test/Build), Dart-Scaffold | **aktuell** |
| **2** | Theme-Layer (4 Presets → `ThemeData` + `ChronicleSkin`) + App-Shell (`ResponsiveShell`, 3-Panel-Desktop, go_router `StatefulShellRoute`) | offen |
| **3** | Vault-Format: Ordner öffnen/anlegen, Datei-Scan, `index.db`-Rebuild (Drift + FTS5), Multi-Vault-Picker, Backup/Restore | offen |
| **4** | Play-Log (getippte Einträge, Sichtbarkeits-Toggle, Wikilinks) | offen |
| **5** | Codex-/Markdown-Editor (Source/Reading, Frontmatter, Callouts, Embeds, Hover-Preview) | offen |
| **6** | Roll-Engine-Portierung + Dice/Oracle/Deck-Roller + Roll-Log im Play-Log | offen |
| **7** | OracleVault-Import (`.orcl`/Bundle) | offen |
| **8** | Clocks & Step-Tracks + obere Leiste | offen |
| **9** | Procedures/Loops (Basis) | offen |
| **10** | Charakterbögen (Custom-Form + Markdown) | offen |
| **11** | LLM-Profile + Fallback-Ketten + Writing-Tools + Orakel-Anreicherung, globaler AI-Schalter | offen |
| **12** | Command-Palette, Slash-Commands, Workspaces, Tags/Properties/Backlinks, FTS5-Suche | offen |
| **13** | Story-Export (Markdown/HTML/PDF, Narration-Filter) | offen |

**Später (nach MVP):** Canvas-Engine (Token-Board + Layout-Seiten), KI-gestütztes Styling, Vision
(`analyzeImage`), Embeddings/RAG, Graph-View, Sync-Modul (PomTechFlow), Mobile-Polish.

Beim Abschluss eines Schritts: Status-Spalte hier aktualisieren.

---

## 9. Arbeitsweise

- **Bei Unklarheiten das Konzept-Dokument zitieren und nachfragen, statt zu raten.** `docs/Konzept.md`
  ist in inhaltlichen Fragen maßgeblich; CLAUDE.md in technischen.
- Kommentare und Doku auf **Deutsch**, Code-Bezeichner auf **Englisch** — wie in OracleVault.
- Jede nicht offensichtliche Entscheidung bekommt einen Kommentar mit dem **Warum**, nicht dem Was.
- Kein `flutter build` / `flutter run` lokal (§2.1).
- Vor dem Push: passt die Änderung zu den fünf harten Constraints? Wenn nicht, ist die Änderung
  falsch, nicht der Constraint.

### Skills

Drei Projekt-Skills unter `.claude/skills/`. Vor Arbeiten am jeweiligen Bereich lesen:

| Skill | Zuständig für |
|---|---|
| `vault-format` | On-Disk-Spezifikation: Ordnerlayout, Frontmatter-Keys, Wikilink-/Embed-Syntax, Index-Rebuild-Regel, UUID-PKs, Medien-Handling |
| `chronicle-theme` | Preset → `ThemeData` + `ChronicleSkin`-`ThemeExtension`, Token-Namen, Skin-Parameter, neues Preset anlegen |
| `flutter-conventions` | Riverpod-Codegen, Drift-Tabellen + FTS5, go_router `StatefulShellRoute`, `build_runner`-Workflow, Ordnerstruktur, Fehlerbehandlung |

Weitere Skills bei Bedarf (`roll-engine-integration`, `sync`, `llm-profiles`).

---

## 10. CI

| Workflow | Auslöser | Zweck |
|---|---|---|
| `ci.yml` | Push auf `main`/`claude/**`/`ci/**`, jeder PR, `workflow_dispatch`, `v*`-Tags | **Gate:** `flutter analyze` + `flutter test` nach Codegen. Dann Matrix-Builds (macOS, iOS, Android, Windows, Linux) als Artefakte. Bei `v*`-Tag: Release mit allen Artefakten. |
| `scaffold.yml` | nur `workflow_dispatch` | Erzeugt die nativen Plattform-Ordner per `flutter create` **in der CI** und committet sie zurück — weil lokale Builds verboten sind (§2.1). Einmalig bzw. wenn eine Plattform dazukommt. |

Die Build-Jobs legen fehlende Plattform-Ordner bei Bedarf per `flutter create` selbst an, damit ein
Build auch vor dem Scaffold-Lauf funktioniert. Sobald die Ordner im Repo liegen (native Anpassungen
für `media_kit`, Icons, Entitlements), ist der Schritt ein No-op.

**Build-Artefakte liegen unter „Actions → Lauf → Artifacts".** Niemals lokal bauen, um an ein
Binary zu kommen.
