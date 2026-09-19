---
name: chronicle-theme
description: >-
  Wie ein Chronicle-Theme-Preset auf ThemeData plus die ChronicleSkin-ThemeExtension abgebildet
  wird — semantische Token-Namen, die Skin-Parameter (ornament, divider, button, texture,
  accentMode, radiusScale), die Scope-Kette System → Game → Notiz und die Schritte, um ein neues
  Preset anzulegen. Dieser Skill ist bei allem zu lesen, was Farben, Fonts, Radien, Ornamentik,
  Texturen oder Trenner betrifft — also auch dann, wenn nur „eine Farbe angepasst", „ein Widget
  gestylt", „ein Screen gebaut", „ein Eintragstyp eingefärbt" oder „der Theme-Manager erweitert"
  werden soll. Im Zweifel lesen: eine hartkodierte Farbe im Widget bricht alle vier Presets auf
  einmal.
---

# Chronicle Theme-Engine

## Wofür das hier da ist

Ein **Theme** ist in Chronicle nicht „die Farben", sondern ein austauschbares Token-Set, das das
*Mood* eines Spielsystems trägt: Grimoire soll nach Pergament und Kerzenlicht aussehen, Terminal
nach Phosphor-Röhre. Umschalten ändert sichtbar **Farben + Fonts + Ornamentik zugleich** — sonst
fühlt es sich nach Dark-Mode-Toggle an, nicht nach einem anderen Spiel.

Deshalb entsteht das Theme-Layer **vor den Screens** (`CLAUDE.md` §6). Ein Screen, der auf
`Colors.grey.shade800` zugreift, ist in allen vier Presets kaputt und muss später angefasst werden.

## Die zwei Hälften

Material's `ThemeData` deckt Farben und Typografie ab. Was es nicht kennt — Ornamentik-Stufe,
Trenner-Stil, Textur, Akzent-Nutzung — lebt in einer `ThemeExtension`:

```
ThemePreset ──┬──> ThemeData        (ColorScheme, TextTheme, Radien)
              └──> ChronicleSkin    (ThemeExtension: Mood-Regler)
```

Beide entstehen aus **derselben** Preset-Definition. Ein Preset ist reine Daten; die Umrechnung
nach Flutter passiert an genau einer Stelle. Wer eine zweite Umrechnungsstelle einführt, bekommt
Presets, die sich an manchen Stellen anders verhalten als an anderen.

---

## Token-Namen: semantisch, nie preset-gebunden

Ein Token heißt nach seiner **Rolle**, nicht nach seinem Aussehen im Default-Preset.

| Gut | Schlecht | Warum |
|---|---|---|
| `entryOracle` | `grimoirePurple` | Im Terminal-Preset ist es grün. |
| `surfaceRaised` | `parchment` | Nocturne hat kein Pergament. |
| `accent` | `gold` | Dossier ist blau. |
| `dividerOrnate` | `filigree` | Sagt nichts über die Rolle. |

Ein preset-gebundener Name verführt dazu, Widgets preset-spezifisch zu schreiben — und genau das
soll die Engine verhindern.

### Token-Gruppen

**Flächen & Struktur** — `surface`, `surfaceRaised`, `surfaceSunken`, `surfaceOverlay`, `border`,
`borderStrong`, `divider`

**Text** — `textPrimary`, `textSecondary`, `textMuted`, `textHeading`, `textBold`, `textHighlight`,
`textLink`

**Akzent** — `accent`, `accentMuted`, `accentContrast`, `accentSurface`

**Status** — `success`, `danger`, `warning`, `info` (jeweils mit `…Surface`-Variante für Hintergründe)

**Eintragstypen** — `entryNarration`, `entryRoll`, `entryOracle`, `entryCard`, `entryPlotbeat`,
`entryAi`, `entryMeta`

Die Eintragstyp-Farben sind der Kern des Play-Logs: sie machen beim Überfliegen sofort sichtbar,
was Erzählung ist und was Mechanik. Sie müssen in jedem Preset klar unterscheidbar bleiben — auch
in Terminal, wo die Palette schmal ist.

**Farbtöne weit streuen, nicht nach Bedeutung wählen.** Beim ersten Anlegen der vier Presets lagen
elf Paare zu dicht beieinander, weil die Zuordnung naheliegend gewählt war: Gold für Würfe neben
Orange für Plot-Beats, Violett für Orakel neben Blau für KI, Türkis für Karten neben demselben
Blau. Jede Zuordnung für sich plausibel — zusammen unlesbar. Die tragfähige Verteilung streut die
Farbtöne über den Kreis:

| Token | Farbton | |
|---|---|---|
| `entryRoll` | 44° | Gold |
| `entryPlotbeat` | 353° | Karmin |
| `entryOracle` | 283° | Violett |
| `entryAi` | 208° | Azur |
| `entryCard` | 160° | Grünblau |

`entryNarration` und `entryMeta` bleiben neutral und heben sich allein über die Helligkeit ab.
**`entryMeta` ist dabei nicht `textMuted`**: in warmen Presets kollidiert der gedämpfte Textton mit
Gold, im Terminal mit Grünblau. Es ist ein eigener Token mit fast herausgenommener Sättigung.

Den Preset-Charakter trägt die **Sättigung**, nicht der Farbton: Grimoire gedämpft, Terminal neon.
Die Helligkeit wird gegen den Kontrast zur Grundfläche gelöst, nicht nach Gefühl gesetzt.

**Typografie** — `heading`, `body`, `mono` (je aus einer kuratierten Liste), dazu `headingWeight`,
`headingCaps` (bool), `headingLetterSpacing`, `bodyLetterSpacing`. Liegt in einer eigenen
`ChronicleTypography`-Extension, weil `headingCaps` sich in einem `TextStyle` nicht ausdrücken
lässt — Versalien sind eine Texttransformation, keine Schrifteigenschaft.

**Schriften werden gebündelt, nicht geladen.** Kein `google_fonts`: das Paket holt die Dateien zur
Laufzeit von `fonts.googleapis.com` und verletzt damit offline-first (`CLAUDE.md` §2.3). Die
Presets nennen nur Familiennamen; die Dateien liegen als Assets im Repo. Fehlt eine Familie, fällt
Flutter auf die Plattformschrift zurück — die App bleibt benutzbar.

Die Typografie ist der größte Mood-Hebel: Serifen + Versalien lesen sich mittelalterlich,
Mono + weites Letter-Spacing liest sich nach SciFi. Wer nur die Farben tauscht, bekommt vier mal
dasselbe Preset in anderen Farben.

---

## `ChronicleSkin` — die Skin-Parameter

Sechs Regler. Jeder ist ein Enum oder ein Skalar, nie ein fertiges Widget — die Widgets fragen den
Skin und entscheiden selbst, was sie daraus machen.

| Parameter | Typ | Werte | Wirkung |
|---|---|---|---|
| `ornament` | enum | `none` · `subtle` · `rich` | Filigran-Ecken, Zierrahmen, Kapitel-Vignetten |
| `divider` | enum | `line` · `doubleLine` · `ornament` · `glyph` | Trenner zwischen Abschnitten und Einträgen |
| `button` | enum | `outline` · `softFill` · `engraved` | Grundform aller Buttons |
| `texture` | enum | `none` · `parchment` · `carbon` · `scanline` | Hintergrund-Textur (Asset im Preset-Ordner) |
| `accentMode` | enum | `line` · `glow` | Akzent als Kante/Unterstrich oder als Schein |
| `radiusScale` | double | `0.0`–`2.0` | Multiplikator auf die Basis-Radien (scharf ↔ weich) |

`radiusScale` ist bewusst ein Skalar statt eines Enums: die Basis-Radien stehen an einer Stelle,
das Preset skaliert sie. So bleibt das Größenverhältnis zwischen Button-, Karten- und Dialog-Radius
in jedem Preset erhalten.

### Zugriff im Widget

```dart
final skin = Theme.of(context).extension<ChronicleSkin>()!;
final scheme = Theme.of(context).colorScheme;
```

Das `!` ist vertretbar, weil `ChronicleSkin` in jedem von uns gebauten `ThemeData` registriert ist —
ein fehlender Skin ist ein Konfigurationsfehler, der laut scheitern soll, kein Laufzeitfall, den
jedes Widget behandeln müsste. Für Tests, die ein nacktes `ThemeData` bauen: `ChronicleSkin.fallback`
bereitstellen und im Test explizit setzen.

---

## Die vier mitgelieferten Presets

| Preset | Mood | Charakteristik |
|---|---|---|
| **Grimoire** *(Default)* | grim-dark mittelalterlich | warme Dunkeltöne, Serifen-Headings mit Versalien, `ornament: rich`, `texture: parchment`, kleiner `radiusScale` |
| **Nocturne** | klar, minimal, modern | kühle Neutraltöne, Grotesk, `ornament: none`, `divider: line`, weiche Radien |
| **Terminal** | SciFi | schmale Palette auf Dunkel, Mono als Body-Font, weites Letter-Spacing, `texture: scanline`, `accentMode: glow`, `radiusScale: 0` |
| **Dossier** | moderne Erde | Papierweiß/Aktendeckel, Grotesk + Serifen-Headings, `ornament: subtle`, `button: outline` |

Jedes Preset liefert **hell und dunkel**. „Terminal hell" wirkt konstruiert, ist aber nötig —
Nutzer erwarten, dass der System-Hell/Dunkel-Schalter überall greift.

---

## Scope-Kette

Ein Theme wird ans **System** gebunden (Default), vom **Game** überschreibbar, pro **Notiz** über
Frontmatter feinjustierbar:

```
Notiz-Frontmatter (theme:, accent-color:, layout:)
  └─ überschreibt ─> Game (game.json)
       └─ überschreibt ─> System (systems/<slug>/theme/theme.json)
            └─ überschreibt ─> App-Default (Grimoire)
```

Diese Kette wird **an einer Stelle** aufgelöst und als fertiges `ThemeData` + `ChronicleSkin` in den
Widget-Baum gegeben. Widgets kennen die Kette nicht — sie sehen nur das Ergebnis. Sonst müsste jedes
Widget wissen, ob es gerade in einer Notiz mit Override steckt.

Der Notiz-Scope ist bewusst eng: er darf Akzent, Banner und Layout ändern, aber nicht die
Eintragstyp-Farben oder die Fonts. Eine einzelne Notiz soll sich einfügen, nicht ausbrechen.

---

## Preset-Definition auf Platte

Ein System-Theme liegt als `systems/<slug>/theme/theme.json`:

```json
{
  "id": "018f3c2a-…",
  "name": "Mörwald-Grimoire",
  "basePreset": "grimoire",
  "tokens": {
    "accent": "#B8894A",
    "entryOracle": "#7A5CA8"
  },
  "skin": {
    "ornament": "rich",
    "radiusScale": 0.5
  },
  "fonts": {
    "heading": "Cormorant Garamond",
    "body": "Crimson Pro",
    "mono": "JetBrains Mono"
  }
}
```

**`basePreset` plus Overrides**, nicht das vollständige Token-Set. Das hält die Datei lesbar und
sorgt dafür, dass ein neu hinzugefügtes Token automatisch einen sinnvollen Wert bekommt, statt in
jedem existierenden System-Theme zu fehlen.

Unbekannte Keys werden ignoriert, nicht als Fehler behandelt — ein Theme aus einer neueren
Chronicle-Version soll einen älteren Vault nicht blockieren.

---

## Ein neues Preset anlegen

1. **Mood in einem Satz festhalten.** „Verwaschene Polaroids, 70er-Horror." Wenn das nicht geht,
   ist es kein eigenes Preset, sondern ein Farb-Override auf einem bestehenden.
2. **Preset-Datei** unter `lib/core/theme/presets/<name>.dart` anlegen — reine Daten, kein Widget-Code.
3. **Beide Paletten** definieren (hell + dunkel), vollständig. Ein fehlendes Token fällt auf den
   Default zurück und erzeugt genau die Inkonsistenz, die auffällt, aber schwer zu finden ist.
4. **Skin-Parameter setzen.** Alle sechs, auch die „offensichtlichen" — explizit ist besser als
   geerbt.
5. **Fonts wählen** aus der kuratierten Liste. Neue Fonts dort ergänzen, nicht ad hoc referenzieren:
   die Liste ist das, was der Theme-Editor dem Nutzer anbietet.
6. **In der Preset-Registry registrieren** (`lib/core/theme/presets.dart`).
7. **`flutter test test/theme_test.dart` in der CI laufen lassen.** Der Test prüft das neue Preset
   automatisch mit, sobald es in der Registry steht: WCAG AA für Text, 4.5:1 für jede
   Eintragstyp-Farbe gegen die Grundfläche, und paarweiser RGB-Abstand ≥ 60 zwischen allen sieben.
   Am Bildschirm fällt so etwas erst auf, wenn man die Typen nebeneinander sieht — und dann meist
   zu spät. Ein Preset, das hier rot wird, ist nicht fertig.
8. **Golden-Test** ergänzen, der eine Beispiel-Log-Ansicht im neuen Preset rendert. Der Test
   schützt davor, dass eine spätere Token-Umbenennung ein Preset still zerlegt.

---

## Regeln beim Bauen von Widgets

- **Keine hartkodierten Farben.** Kein `Colors.*`, kein `Color(0xFF…)` außerhalb von
  `lib/core/theme/`. Das ist die Regel, die die ganze Engine trägt.
- **Keine hartkodierten Radien.** `skin.radius(RadiusToken.card)` statt `BorderRadius.circular(8)` —
  sonst greift `radiusScale` nicht.
- **Keine hartkodierten Fonts.** Typografie kommt aus `Theme.of(context).textTheme`.
- **Ornamentik immer prüfen:** `if (skin.ornament == OrnamentLevel.none)` muss einen sauberen,
  schmucklosen Zustand liefern — nicht eine Lücke, wo das Ornament war.
- **Texturen sind Assets im Preset-Ordner**, keine Remote-URLs (offline-first, `CLAUDE.md` §2.3).
- Ein neuer Screen wird gegen **mindestens zwei Presets** angesehen, bevor er als fertig gilt.
  Grimoire und Terminal liegen am weitesten auseinander und decken die meisten Fehler auf.
