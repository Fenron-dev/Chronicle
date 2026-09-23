---
name: vault-format
description: >-
  Die On-Disk-Spezifikation eines Chronicle-Vaults — Ordnerlayout (systems/, games/, media/,
  .chronicle/index.db), Frontmatter-Keys, Wikilink- und Embed-Syntax, die Index-Rebuild-Regel
  (Dateien = Wahrheit, DB = regenerierbarer Index), UUID-Primärschlüssel und Medien-Handling.
  Dieser Skill ist bei allem zu lesen, was Dateien im Vault schreibt, liest, scannt, indiziert,
  migriert, exportiert oder importiert — also auch dann, wenn nur „eine Notiz gespeichert",
  „ein Frontmatter-Feld ergänzt", „ein neuer Objekttyp angelegt", „die Drift-Tabelle erweitert"
  oder „der Scanner angepasst" werden soll. Im Zweifel lesen: ein falsch geschriebenes Feld
  überlebt den nächsten Index-Rebuild nicht.
---

# Chronicle Vault-Format

## Die eine Regel, aus der alles folgt

**Dateien sind die Wahrheit. Die DB ist ein Index.**

`.chronicle/index.db` (Drift + FTS5) darf jederzeit gelöscht und aus dem Dateibaum vollständig neu
aufgebaut werden. Das ist kein Nice-to-have, sondern die Bedingung dafür, dass ein Vault auf einem
USB-Stick weitergereicht und auf einem fremden Rechner geöffnet werden kann.

Daraus folgt für jede Code-Änderung:

1. **Erst schreiben, dann indizieren.** Nie umgekehrt. Ein DB-Insert ohne vorhergehenden
   Datei-Write erzeugt Daten, die der nächste Rebuild stillschweigend löscht.
2. **Jedes Feld, das der Nutzer verliert, wenn `index.db` weg ist, gehört in die Datei.** Prüfe
   bei jedem neuen Feld: steht es im Frontmatter oder im Body? Wenn nein — warum darf es
   verschwinden? Reine Ableitungen (Backlinks, FTS-Index, Thumbnail-Pfade, Sortier-Caches) dürfen
   DB-only sein, weil sie aus den Dateien wieder herleitbar sind.
3. **UUIDs stehen in der Datei**, nicht nur in der DB. Sonst bekommt dasselbe Objekt nach einem
   Rebuild eine neue Identität und alle Sync-Zuordnungen und Bundle-Referenzen brechen.
4. **`.chronicle/` zu löschen darf nie Nutzerdaten kosten.** Wenn es das täte, liegt etwas am
   falschen Ort.

---

## Ordnerlayout

```
<vault>/
├── .chronicle/
│   ├── index.db          # Drift + FTS5. Regenerierbar. NICHT im Backup.
│   ├── thumbnails/       # Regenerierbar. NICHT im Backup.
│   ├── snapshots/        # Auto-Snapshot vor Migrationen + Versions-History je Notiz.
│   ├── backups/          # Manuelle + automatische Backups (ZIP).
│   └── config.json       # Vault-Einstellungen (Schema-Version, aktives Game, Workspaces).
├── systems/
│   └── <system-slug>/
│       ├── system.json   # Manifest: id, name, version, defaults, theme-Ref
│       ├── rules.md
│       ├── tables/       # *.md (ein Orakel/eine Tabelle je Datei)
│       ├── decks/        # *.md + zugehörige Karten-Medien
│       ├── templates/    # Entity-Templates je Typ
│       ├── sheets/       # Charakterbogen-Vorlagen
│       ├── procedures/   # Gameloops / Workflows
│       └── theme/        # theme.json (+ optionale Assets: Texturen)
├── games/
│   └── <game-slug>/
│       ├── game.json     # Manifest: id, name, systemId, overrides
│       ├── log/          # Play-Log — eine Datei je Thread
│       ├── codex/        # kuratierte Markdown-Seiten
│       ├── entities/     # NPC, Ort, Fraktion, Gegenstand, Szene, Session, Clock
│       ├── sheets/       # ausgefüllte Charakterbögen
│       ├── canvases/     # Canvas-JSON (später)
│       └── media/        # spielspezifische Medien
├── media/                # vaultweit geteilte Medien
└── README.md             # erklärt einem Menschen, was dieser Ordner ist
```

**Slugs** (`<system-slug>`, `<game-slug>`) sind menschenlesbar, kleingeschrieben, ASCII,
Bindestrich-getrennt. Sie sind **kein** Identitätsmerkmal — die UUID im Manifest ist es. Ein
umbenannter Ordner bleibt dasselbe System. ASCII ist keine Pedanterie: ein Vault wandert per
USB-Stick zwischen Betriebssystemen, und macOS normalisiert Umlaute in Dateinamen anders als Linux.
`slugify()` schreibt deshalb um (`ö` → `oe`), und `uniqueSlug()` hängt eine Zahl an, wenn der Name
schon vergeben ist — zwei Systeme dürfen gleich heißen, zwei Ordner nicht.

### Die Manifeste

**`systems/<slug>/system.json`** — `schemaVersion`, `id` (UUID), `name`, `created`, `description`.

**`games/<slug>/game.json`** — `schemaVersion`, `id`, `name`, `created`, `systemId` (die UUID des
Systems, auf das sich die Partie bezieht — genau eines), optional `themePresetId`.

**Manifeste sind keine Notizen.** Der Scanner liest nur `.md`-Dateien; `system.json` und `game.json`
entgehen ihm. Wer Systeme oder Partien auflisten will, liest deshalb direkt das Dateisystem, nicht
den Index — und bleibt damit auch dann richtig, wenn der Index gerade neu gebaut wird.

Ein neu angelegtes System bekommt eine `rules.md`, eine neue Partie einen ersten Log-Thread, jeweils
mit vollständigem Frontmatter. Sonst erscheint das eben Angelegte nirgends im Baum, und es sieht
aus, als wäre nichts passiert.

**Die Defaults-Regel:** Ablageorte und Layouts kommen vom System, das Game darf sie überschreiben.
Beim Auflösen eines Werts immer in dieser Reihenfolge suchen: **Game → System → App-Default**.
Schreibe diese Kette nicht an jeder Aufrufstelle neu, sondern löse sie an einer Stelle auf.

---

## Frontmatter

Jede Markdown-Datei im Vault beginnt mit YAML-Frontmatter. Das Dreischicht-Modell aus dem Konzept
(§5.1) bestimmt, was wohin gehört:

- **Inhalt** → reines Markdown im Body (portabel, git-freundlich, Obsidian-kompatibel).
- **Präsentation** → Frontmatter, nie im Fließtext.
- **Layout-Vokabular** → kuratierte MD-freundliche Blöcke im Body (Callouts, Spalten, Galerien).
- **Roh-HTML** → nur als Notausgang für Power-User, sanitized, nichts Wichtiges darauf aufbauen.

### Kern-Keys (jede Datei)

| Key | Typ | Pflicht | Bedeutung |
|---|---|---|---|
| `id` | UUID v4 | **ja** | Primärschlüssel. Überlebt Umbenennen, Verschieben, Rebuild. |
| `type` | enum | **ja** | `log` \| `codex` \| `entity` \| `table` \| `deck` \| `sheet` \| `procedure` \| `canvas` |
| `title` | string | ja | Anzeigename. Nicht zwingend gleich dem Dateinamen. |
| `created` | ISO-8601 | ja | Erstellzeitpunkt, UTC. |
| `updated` | ISO-8601 | ja | Letzte Änderung, UTC. |
| `tags` | string[] | nein | Freie Tags. |
| `properties` | map | nein | EAV-Properties (beliebige Schlüssel/Werte). |

### Präsentations-Keys (optional, überall erlaubt)

`banner:` · `cover:` · `theme:` · `accent-color:` · `layout:`

Diese steuern die Reading-View. Sie sind **Overrides** — fehlen sie, gilt das Theme aus Game bzw.
System. So entstehen schöne Seiten deklarativ, statt durch Hand-Layout pro Notiz.

### Typ-spezifische Keys

**`type: log`** — ein Thread (Kampagnen-Play-Log, Szenen-Log, NPC-Dialog, Kampflog, Brainstorm;
alle derselbe Typ, das ist Absicht):
`parent:` (UUID des übergeordneten Threads bei Sub-Threads) · `game:` (UUID)

Einträge stehen im Body als Sequenz. Jeder Eintrag trägt seinen Typ, damit die Sichtbarkeits-Toggle
nicht-narrative Einträge ausblenden kann und der Story-Export „nur Narration" filtern kann:

```markdown
> [!entry] narration | 2026-09-19T20:14:03Z | id: 3f2a…
Der Nebel über dem Moor wird dichter.

> [!entry] roll | 2026-09-19T20:15:11Z | id: 7b1c…
**2d6+1** → 4, 5 (+1) = **10** · Erfolg mit Kosten
```

Eintragstypen: `narration` · `roll` · `oracle` · `card` · `plotbeat` · `ai` · `meta`.
Jeder Eintrag ist Markdown-fähig, verlinkbar und trägt eine eigene UUID — Sub-Threads und
Querverweise brauchen sie.

**`type: entity`** — `entity-type:` (`npc`|`place`|`faction`|`item`|`scene`|`session`|`clock`|`track`) ·
`template:` (UUID der Vorlage) · Freitext im Body.

#### Clocks und Step-Tracks (Schritt 8)

Beide liegen unter `games/<slug>/entities/` — sie sind Zustand **dieser** Partie, nicht Teil des
Regelwerks.

**Clock** (`entity-type: clock`) — `segments:` (2–24, üblich 4/6/8) · `filled:` (0–segments).
Werte außerhalb werden beim Lesen geklemmt, nicht abgelehnt: eine von Hand auf `filled: 9` gesetzte
6er-Clock ist ein Tippfehler. Der Rumpf ist freier Text.

**Step-Track** (`entity-type: track`) — der Rumpf ist eine **gewöhnliche Aufgabenliste**:

```markdown
- [x] Ankunft in Mörwald
- [ ] Der Turm im Moor
  - [ ] Den Wächter bestechen        ← eingerückt: Unter-Beat
```

Damit ist ein Track in Obsidian abhakbar, ohne dass Chronicle läuft. Tab und zwei Leerzeichen
zählen je eine Einrückungsstufe. Fortschritt und „nächster Beat" zählen nur die **Haupt-Beats** —
Unter-Beats sind die Schritte eines Kapitels, nicht weitere Kapitel.

**Abhaken ändert genau eine Zeile** (`toggleBeat`): nur das Zeichen im Kästchen. Den Rumpf aus dem
Modell neu zu schreiben würde Prosa, Überschriften und eigene Einrückung zwischen den Beats
vernichten. Steht in der gemerkten Zeile kein Beat mehr, wurde die Datei außerhalb geändert — dann
wird **nichts** geschrieben (`StaleTrackException`), statt die falsche Zeile zu kippen.

**Fokus der oberen Leiste** — `focusedTrackId:` in `game.json`. Fehlt er, gilt: ein Track namens
„Kampagne" → der erste Step-Track → die erste Clock (Konzept §4.5, „Default: Kampagne"). `game.json`
wird dafür **roh** gelesen, gemergt und geschrieben (`VaultCatalog.updateGameManifest`), nicht über
`GameEntry.toJson` — das kennt nur unsere Schlüssel und würde fremde verwerfen.

**`type: table`** — `table-type:` (`uniform`|`weighted`|`dice`|`deck`) · `dice:` (z. B. `2d6`) ·
Einträge als Liste im Body mit `weight`/`range`/`subtable`-Annotationen. Das Modell folgt
OracleVault („Alles ist eine Tabelle"), damit importierte Bundles ohne Übersetzung passen.

**`type: deck`** — wie `table` mit `table-type: deck`, zusätzlich `reversible:` (bool, für Tarot).

#### Der Rumpf einer Tabelle (Schritt 6)

**Eine gewöhnliche Markdown-Liste.** Eine Zufallstabelle soll in Obsidian aussehen wie eine
Zufallstabelle und sich von Hand erweitern lassen, ohne Chronicle zu öffnen — deshalb keine
eingebettete JSON-Struktur. Vor dem Text steht eine **optionale** Annotation, abgetrennt durch `|`:

| Schreibweise | Bedeutung |
|---|---|
| `- 2-4 \| Dichter Nebel` | Trefferbereich 2–4 (`table-type: dice`) |
| `- 7 \| Ein Wert` | Bereich 7–7 |
| `- x3 \| Wegelagerer` | Gewicht 3 (`table-type: weighted`) |
| `- Eine leere Straße` | ohne Annotation: Gewicht 1 |
| `- => Namensliste` | der ganze Eintrag kommt aus einer anderen Tabelle (auch `→`) |
| `- [Kultur] [Epitheton]` | Platzhalter im Text, beim Würfeln aufgelöst |

**Warum `|`:** Es kommt in Tabellentexten praktisch nicht vor und ist auf jeder Tastatur
erreichbar. Vor allem aber bleibt ein Eintrag **ohne** Trenner gültig — der häufigste Fall braucht
damit gar keine Syntax. Ein `2-4` ohne `|` ist deshalb Text („2-4 Wachen am Tor"), kein Bereich.

Der Bindestrich im Bereich darf auch ein Gedankenstrich sein (`2–4`): jede Autokorrektur macht das
irgendwann, und der Eintrag darf dadurch nicht unbrauchbar werden. Ein verdrehter Bereich (`9-5`)
wird umgedreht statt verworfen.

Alles, was keine Listenzeile ist, wird übersprungen — Überschriften und erklärender Text gehören
in eine handgepflegte Tabelle.

**Lücken sind eine Meldung, kein Fehler.** `validateTable()` prüft, ob die Bereiche einer
Würfeltabelle die ganze Spannweite des Ausdrucks abdecken (bei `2d6` also 2 bis 12). Eine Tabelle
mit Lücke ist nicht kaputt, sondern unfertig: der Editor zeigt das an, verweigert das Öffnen aber
nicht.

### Beispiel

```markdown
---
id: 018f3c2a-7b41-7c3e-9d8a-2f10bb45e901
type: codex
title: Die Grafschaft Mörwald
created: 2026-09-19T18:02:44Z
updated: 2026-09-19T20:31:07Z
tags: [ort, kampagne-nebelmoor]
properties:
  region: Nordmark
  einwohner: 1200
banner: ../media/moerwald-banner.jpg
accent-color: moss
---

# Die Grafschaft Mörwald

> [!lore]
> Seit dem Fall von [[Haus Verren]] verwaltet sich Mörwald selbst.

![[moerwald-karte.png]]
```

---

## Wikilinks & Embeds

Obsidian-kompatible Syntax. Der **Rohtext bleibt unangetastet** — der Parser materialisiert
lediglich zusätzlich `Edge`-Zeilen in der DB.

| Form | Bedeutung |
|---|---|
| `[[Seite]]` | Link auf eine Seite |
| `[[Seite#Abschnitt]]` | Link auf einen Abschnitt/Eintrag |
| `[[Seite\|Anzeigetext]]` | Link mit Alias |
| `[[Seite#Abschnitt\|Alias]]` | kombiniert |
| `![[bild.png]]` | Embed eines Media-Assets |

**Auflösung nach Namen, nicht nach Pfad** — so überlebt ein Link das Verschieben der Zieldatei.
Reihenfolge: aktuelles Game → dessen System → Vault-weit. Bei Mehrdeutigkeit gewinnt der nähere
Treffer; ein unauflösbarer Link bleibt als Text stehen und wird im Editor markiert, statt einen
Fehler zu werfen — der Nutzer schreibt oft den Link, bevor das Ziel existiert.

**Edges werden beim Speichern materialisiert.** Die Edge-Tabelle ist generisch
(`from_type`/`from_id` → `to_type`/`to_id` + `relation`), damit Backlinks aus *einer* Query kommen
und beliebige Relationstypen möglich sind — keine FK-Spalte je Beziehungsart.

Edges sind **redundant**: sie werden beim Rebuild aus dem Rohtext neu erzeugt. Nie eine Edge
anlegen, die nicht aus einer Datei herleitbar ist.

---

## Index-Rebuild

Der Rebuild ist die Referenz-Implementierung der obersten Regel. Ablauf:

1. `.chronicle/index.db` verwerfen (oder in eine frische Datei bauen und atomar tauschen — sicherer,
   weil ein Absturz mitten im Rebuild dann keinen halben Index hinterlässt).
2. Dateibaum scannen: `systems/`, `games/`, `media/`. `.chronicle/` überspringen.
3. Je Datei Frontmatter parsen → Kern-Zeile schreiben. Fehlt `id`, eine UUID erzeugen und **in die
   Datei zurückschreiben** — sonst bekommt die Datei beim nächsten Rebuild wieder eine andere.
4. Body parsen → Log-Einträge, Tabellen-Einträge, Wikilinks → Edges.
5. FTS5-Tabellen befüllen.
6. Medien: Pfad, MIME, SHA-256-Hash (Dublettenerkennung). Thumbnails in `.chronicle/thumbnails/`
   erst bei Bedarf.

**Inkrementell im Normalbetrieb:** Beim Speichern einer Datei nur deren Zeilen und Edges
aktualisieren. Der vollständige Rebuild ist der Fallback (Vault-Wechsel, Schema-Migration,
manueller „Index neu aufbauen"-Befehl) — er muss existieren und getestet sein, auch wenn er selten
läuft.

**Ein defekter Index ist nie ein Datenverlust.** Bei Schema-Mismatch oder Korruption: rebuilden,
nicht reparieren.

---

## Medien

- Bilder, Audio, Video, Dokumente. Wiedergabe über `media_kit`.
- **Vaultweit** in `media/`, **spielspezifisch** in `games/<game>/media/`. Beim Import fragen bzw.
  dem System-Default folgen.
- **SHA-256-Hash** je Datei zur Dublettenerkennung — gestreamt berechnen, nicht die ganze Datei in
  den RAM laden.
- **Relative Pfade, immer.** Ein absoluter Pfad bricht die Portabilität und ist ein Bug (§2.2 in
  `CLAUDE.md`).
- **Externe Einbettungen** (YouTube o. Ä.) sind erlaubt, laden aber offline nicht. Sie dürfen nie
  Voraussetzung für Kerninhalte sein.
- Thumbnails sind Cache: `.chronicle/thumbnails/`, regenerierbar, nicht im Backup.

---

## Backup, Snapshots, Migration

- **Backup ab Tag 1.** Ohne funktionierendes Restore wird keine Migration gemergt.
- **Auto-Snapshot vor jeder Migration** nach `.chronicle/snapshots/`.
- Ins Backup gehört der **Dateibaum**. `index.db` und `thumbnails/` bleiben draußen — sie sind
  regenerierbar, und sie aufzunehmen würde das Backup ohne Gewinn vervielfachen.
- **Versions-Snapshots je Notiz** (git-lite) ermöglichen, eine Session zurückzunehmen.
- Format: ZIP (`archive`-Paket), plus JSON-Export für maschinelle Weiterverarbeitung.

### Wie es umgesetzt ist (Schritt 3b)

```
.chronicle/
├── backups/
│   └── chronicle-manual-20260920-0731.zip
│   └── chronicle-pre-restore-20260920-0733.zip
└── snapshots/
    ├── chronicle-pre-migration-20260920-0730.zip
    └── notes/
        └── games/moor/log/haupt.md/        ← der Notizpfad, als Ordner gespiegelt
            └── 20260920-073012-345.md
```

**Ein Manifest je Archiv**, unter `.chronicle-backup.json` im Archiv-Wurzelverzeichnis: Anlass,
Zeitpunkt, Vault-Id und -Name, Formatversion, Dateizahl, Rohgröße, optionales Label. Der Punkt im
Namen ist Absicht — wer das ZIP von Hand entpackt, soll keine fremde Datei sichtbar im Vault
liegen haben. Beim Zurückspielen wird sie übersprungen.

**Eine Stelle entscheidet, was dazugehört:** `BackupService.isBackedUp(relPath)`. Sie bestimmt
zugleich, was beim Zurückspielen geräumt wird. Zwei getrennte Listen wären irgendwann uneinig, und
das Ergebnis wäre ein Vault mit Resten eines anderen Stands. Draußen bleiben `index.db` (samt
`-wal`/`-shm`), `thumbnails/`, `backups/`, `snapshots/`, `.git/` und die Schreibprobe.

**Zurückspielen ersetzt, es mischt nicht.** Ablauf: Manifest prüfen → Sicherheitssicherung des
jetzigen Stands anlegen → alle Ziele prüfen (ein Eintrag mit `../` bricht ab, *bevor* etwas
gelöscht wird) → räumen → auspacken → `index.db` löschen. Der nächste Öffnen-Vorgang baut den
Index aus den Dateien neu auf — und genau das ist die Zusage aus §2.5, hier als Ablauf.

**Der Vault wird dafür geschlossen und neu geöffnet.** Drift hält ein offenes Handle auf
`index.db`; unter Windows lässt sich eine offene Datei nicht löschen, und auf einem Stick bliebe
sonst eine Sperre zurück.

---

## Was nicht in den Vault gehört

- **API-Keys.** Niemals. Nur die Profil-Struktur (`name`, `kind`, `baseUrl`, `defaultModel`,
  `temperature`, `maxTokens`, `hasApiKey`, `tier`, `isLocal`). Keys liegen im OS-Secure-Storage.
  Ein weitergereichter Vault darf keinen Key enthalten — das ist der Testfall.
- **Absolute Pfade.**
- **Maschinenspezifische Einstellungen** (Fensterposition, zuletzt geöffnete Vaults, UI-Zustand) —
  die gehören in `shared_preferences`, nicht in `config.json`.

---

## Änderungen am Format

Das Format ist ein Versprechen an alte Vaults. Vor einer Änderung durchgehen:

1. Öffnet ein Vault im alten Format noch, ohne Datenverlust?
2. Gibt es eine Migration, und läuft davor ein Auto-Snapshot?
3. Ist `config.json`s Schema-Version erhöht?
4. Überlebt die neue Information einen vollständigen Index-Rebuild?
5. Bleibt die Datei ohne Chronicle lesbar — also in Obsidian oder einem Texteditor?

Wenn Frage 4 oder 5 mit Nein beantwortet wird, ist der Entwurf noch nicht fertig.
