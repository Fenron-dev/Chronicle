// Datei: chronicle/lib/core/theme/chronicle_palette.dart
//
// ZWECK: Das vollständige semantische Farb-Token-Set eines Themes.
//
// WARUM NEBEN ColorScheme: Material's ColorScheme hat keine Slots für
//        surfaceSunken, textMuted oder die sieben Eintragstyp-Farben. Diese
//        Tokens in vorhandene Slots zu quetschen (etwa entryOracle nach
//        tertiary) würde bedeuten, dass ein Material-Widget sie zufällig
//        benutzt. Deshalb ein eigenes Set, und ColorScheme bekommt daraus
//        nur die Werte, die Material wirklich braucht.
//
// TOKEN-NAMEN sind semantisch, nie preset-gebunden: `entryOracle`, nicht
//        `grimoirePurple` — im Terminal-Preset ist derselbe Token grün.
//
// SIEHE: Skill `chronicle-theme`
// SCHRITT: 2

import 'package:flutter/material.dart';

import '../../domain/log/entry_kind.dart';

/// Semantische Farb-Tokens eines Themes, für eine Helligkeit.
@immutable
class ChroniclePalette extends ThemeExtension<ChroniclePalette> {
  const ChroniclePalette({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.surfaceOverlay,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textHeading,
    required this.textBold,
    required this.textHighlight,
    required this.textLink,
    required this.accent,
    required this.accentMuted,
    required this.accentContrast,
    required this.accentSurface,
    required this.success,
    required this.successSurface,
    required this.danger,
    required this.dangerSurface,
    required this.warning,
    required this.warningSurface,
    required this.info,
    required this.infoSurface,
    required this.entryNarration,
    required this.entryRoll,
    required this.entryOracle,
    required this.entryCard,
    required this.entryPlotbeat,
    required this.entryAi,
    required this.entryMeta,
  });

  // ── Flächen & Struktur ────────────────────────────────────────────────────

  /// Grundfläche des Fensters.
  final Color surface;

  /// Angehobene Fläche: Panels, Karten, Dialoge.
  final Color surfaceRaised;

  /// Vertiefte Fläche: Eingabefelder, Code-Blöcke, inaktive Bereiche.
  final Color surfaceSunken;

  /// Fläche über allem: Menüs, Popover, Hover-Preview von Wikilinks.
  final Color surfaceOverlay;

  final Color border;
  final Color borderStrong;
  final Color divider;

  // ── Text ──────────────────────────────────────────────────────────────────

  final Color textPrimary;
  final Color textSecondary;

  /// Für Zeitstempel, Provenienz-Angaben, deaktivierte Labels.
  final Color textMuted;

  final Color textHeading;
  final Color textBold;
  final Color textHighlight;
  final Color textLink;

  // ── Akzent ────────────────────────────────────────────────────────────────

  final Color accent;
  final Color accentMuted;

  /// Text auf [accent] — muss darauf lesbar sein.
  final Color accentContrast;

  /// Flächige, dezente Akzent-Variante für Chips und Auswahl-Zustände.
  final Color accentSurface;

  // ── Status ────────────────────────────────────────────────────────────────

  final Color success;
  final Color successSurface;
  final Color danger;
  final Color dangerSurface;
  final Color warning;
  final Color warningSurface;
  final Color info;
  final Color infoSurface;

  // ── Eintragstypen ─────────────────────────────────────────────────────────
  //
  // Der Kern des Play-Logs: sie machen beim Überfliegen sofort sichtbar, was
  // Erzählung ist und was Mechanik. Müssen in JEDEM Preset klar
  // unterscheidbar bleiben — auch im Terminal-Preset, wo die Palette schmal
  // ist.

  final Color entryNarration;
  final Color entryRoll;
  final Color entryOracle;
  final Color entryCard;
  final Color entryPlotbeat;
  final Color entryAi;
  final Color entryMeta;

  /// Farbe eines Eintragstyps — der übliche Zugriff aus dem Play-Log.
  Color colorFor(EntryKind kind) => switch (kind) {
    EntryKind.narration => entryNarration,
    EntryKind.roll => entryRoll,
    EntryKind.oracle => entryOracle,
    EntryKind.card => entryCard,
    EntryKind.plotbeat => entryPlotbeat,
    EntryKind.ai => entryAi,
    EntryKind.meta => entryMeta,
  };

  @override
  ChroniclePalette copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? surfaceOverlay,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textHeading,
    Color? textBold,
    Color? textHighlight,
    Color? textLink,
    Color? accent,
    Color? accentMuted,
    Color? accentContrast,
    Color? accentSurface,
    Color? success,
    Color? successSurface,
    Color? danger,
    Color? dangerSurface,
    Color? warning,
    Color? warningSurface,
    Color? info,
    Color? infoSurface,
    Color? entryNarration,
    Color? entryRoll,
    Color? entryOracle,
    Color? entryCard,
    Color? entryPlotbeat,
    Color? entryAi,
    Color? entryMeta,
  }) {
    return ChroniclePalette(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textHeading: textHeading ?? this.textHeading,
      textBold: textBold ?? this.textBold,
      textHighlight: textHighlight ?? this.textHighlight,
      textLink: textLink ?? this.textLink,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      accentContrast: accentContrast ?? this.accentContrast,
      accentSurface: accentSurface ?? this.accentSurface,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      entryNarration: entryNarration ?? this.entryNarration,
      entryRoll: entryRoll ?? this.entryRoll,
      entryOracle: entryOracle ?? this.entryOracle,
      entryCard: entryCard ?? this.entryCard,
      entryPlotbeat: entryPlotbeat ?? this.entryPlotbeat,
      entryAi: entryAi ?? this.entryAi,
      entryMeta: entryMeta ?? this.entryMeta,
    );
  }

  @override
  ChroniclePalette lerp(covariant ChroniclePalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return ChroniclePalette(
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      surfaceOverlay: c(surfaceOverlay, other.surfaceOverlay),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      divider: c(divider, other.divider),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      textHeading: c(textHeading, other.textHeading),
      textBold: c(textBold, other.textBold),
      textHighlight: c(textHighlight, other.textHighlight),
      textLink: c(textLink, other.textLink),
      accent: c(accent, other.accent),
      accentMuted: c(accentMuted, other.accentMuted),
      accentContrast: c(accentContrast, other.accentContrast),
      accentSurface: c(accentSurface, other.accentSurface),
      success: c(success, other.success),
      successSurface: c(successSurface, other.successSurface),
      danger: c(danger, other.danger),
      dangerSurface: c(dangerSurface, other.dangerSurface),
      warning: c(warning, other.warning),
      warningSurface: c(warningSurface, other.warningSurface),
      info: c(info, other.info),
      infoSurface: c(infoSurface, other.infoSurface),
      entryNarration: c(entryNarration, other.entryNarration),
      entryRoll: c(entryRoll, other.entryRoll),
      entryOracle: c(entryOracle, other.entryOracle),
      entryCard: c(entryCard, other.entryCard),
      entryPlotbeat: c(entryPlotbeat, other.entryPlotbeat),
      entryAi: c(entryAi, other.entryAi),
      entryMeta: c(entryMeta, other.entryMeta),
    );
  }
}
