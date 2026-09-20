# Chronicle

Portable, lokal-first App zum **Spielen von Journaling-Solo-RPGs**.

Chronicle verwaltet beliebige Spielsysteme (Regeln, Tabellen, Gameloops), führt durch das Spiel
(Würfeln, Orakel, Karten, Clocks) und hält den Verlauf als schön gestaltbares Journal fest.
Alles liegt in einem **Vault** — einem gewöhnlichen Ordner, der auf einen USB-Stick passt und
weitergereicht werden kann.

**Status:** Schritte 1–4 — Theme-Layer, App-Shell, Vault-Format mit Index-Rebuild, Systeme und
Partien, Backup/Restore und das Play-Log stehen. Lauffähig auf allen fünf Plattformen; Binaries
unter *Actions → Lauf → Artifacts*.

---

## Leitprinzipien

- **Local-first & portabel** — ein Vault = ein Ordner. Kein Server.
- **Offline-first** — keine Cloud-Abhängigkeit zur Laufzeit außer selbst konfigurierten LLM-APIs.
- **Dateien = Wahrheit** — Markdown/JSON im Vault ist maßgeblich; die Datenbank ist ein daraus
  neu aufbaubarer Index.
- **Flow beim Spielen** — Würfeln → interpretieren → schreiben ohne Reibung.
- **KI als Werkzeug, nicht als Zwang** — optional, mit eigenen Modellen, immer abschaltbar.

---

## Ökosystem

Chronicle ist der **Play-/Journal-Layer**. [OracleVault](https://github.com/Fenron-dev/OracleVault)
ist die Daten-Grundlage (Tabellen, Orakel, Decks, Roll-Engine) und ausdrücklich *kein* Play-Tool —
Chronicle beginnt genau dort, wo dessen „Out of Scope"-Liste endet.

Tabellen und Decks werden aus OracleVault **importiert** (Bundle-Kopie), nicht live referenziert:
die laufende Partie bleibt damit autark. Nur die Roll-Engine wird als Code übernommen.

Weitere Bausteine kommen aus **MediaShelf** (portables Vault-Index-Muster, `ResponsiveShell`),
**MindFeed** (LLM-Profile, Fallback-Ketten, FTS5-Suche, Backup/Restore) und **PomTechFlow**
(Sync via QR + mDNS, CI-Vorlagen).

---

## Tech-Stack

Flutter 3.47 / Dart 3.13 · Drift 2.35 + FTS5 · Riverpod 3 (`@riverpod`-Codegen) · go_router 18
(`StatefulShellRoute`) · media_kit · `flutter_secure_storage` für API-Keys · shelf (Sync, später).

Vollständige Versionstabelle in [`CLAUDE.md`](CLAUDE.md) §3.

---

## Builds

**Alle Builds laufen über GitHub Actions — niemals lokal.** Das ist kein Stilmittel, sondern eine
harte Projektregel (chronische lokale Speicherplatz-Probleme).

| Workflow | Auslöser | Ergebnis |
|---|---|---|
| `ci.yml` | Push auf `main`/`claude/**`/`ci/**`, jeder PR, manuell | Analyzer + Tests, dann Builds für macOS, iOS, Android, Windows, Linux als Artefakte. Bei `v*`-Tag zusätzlich ein Release. |
| `scaffold.yml` | manuell | Erzeugt die nativen Plattform-Ordner per `flutter create` in der CI und committet sie zurück. |

Fertige Binaries: **Actions → Lauf → Artifacts**.

> **macOS:** Die Artefakte sind ad-hoc-signiert, nicht notarisiert. Nach dem Entpacken einmal
> `xattr -dr com.apple.quarantine Chronicle.app` ausführen, sonst weigert sich Gatekeeper.
> Die App-Sandbox ist abgeschaltet: `files.user-selected.read-write` gilt nur für Ordner, die der
> Nutzer in *dieser* Sitzung im Dialog gewählt hat — ein Vault aus der Zuletzt-Liste wäre beim
> nächsten Start nicht mehr zugänglich. Der sandbox-konforme Weg (security-scoped bookmarks) wird
> erst für den App Store gebraucht; Chronicle wird direkt verteilt.

---

## Repo-Aufbau

```
.
├── CLAUDE.md              # Quelle der Wahrheit: Constraints, Stack, Architektur, Baureihenfolge
├── .claude/skills/        # Projekt-Skills: vault-format, chronicle-theme, flutter-conventions
├── .github/workflows/     # ci.yml, scaffold.yml
├── chronicle/             # das Flutter-Projekt
└── docs/                  # Konzept-Dokument (lokal, nicht im Repo)
```

Wer hier mitarbeitet — Mensch oder Agent — liest zuerst [`CLAUDE.md`](CLAUDE.md).
