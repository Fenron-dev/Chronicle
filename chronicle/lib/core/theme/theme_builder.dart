// Datei: chronicle/lib/core/theme/theme_builder.dart
//
// ZWECK: Die EINZIGE Umrechnung von Preset nach Flutter. Aus einem
//        ThemePreset entstehen hier ThemeData samt den drei Extensions.
//
// WARUM NUR HIER: Eine zweite Umrechnungsstelle erzeugt Presets, die sich an
//        manchen Stellen anders verhalten als an anderen — und genau das ist
//        der Fehler, den eine Theme-Engine verhindern soll.
//
// SIEHE: Skill `chronicle-theme`
// SCHRITT: 2

import 'package:flutter/material.dart';

import 'chronicle_palette.dart';
import 'chronicle_skin.dart';
import 'chronicle_typography.dart';
import 'theme_preset.dart';

/// Baut das ThemeData für [preset] in [brightness].
ThemeData buildChronicleTheme(ThemePreset preset, Brightness brightness) {
  final palette = preset.paletteFor(brightness);
  final skin = preset.skin;
  final type = preset.typography;

  final scheme = _buildColorScheme(palette, brightness);
  final text = _buildTextTheme(palette, type);

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: palette.surface,
    canvasColor: palette.surface,
    dividerColor: palette.divider,

    // Die Extensions tragen alles, wofür ThemeData keine Slots hat. Jedes von
    // uns gebaute Theme registriert alle drei — ein fehlender Eintrag ist ein
    // Konfigurationsfehler und soll im Widget laut scheitern.
    extensions: <ThemeExtension<dynamic>>[palette, skin, type],

    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: 1,
    ),

    cardTheme: CardThemeData(
      color: palette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: skin.radius(RadiusToken.card),
        side: BorderSide(color: palette.border),
      ),
    ),

    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: palette.surfaceSunken,
      hintStyle: text.bodyMedium?.copyWith(color: palette.textMuted),
      border: OutlineInputBorder(
        borderRadius: skin.radius(RadiusToken.button),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: skin.radius(RadiusToken.button),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: skin.radius(RadiusToken.button),
        borderSide: BorderSide(color: palette.accent, width: 2),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: _filledStyle(palette, skin),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _outlinedStyle(palette, skin),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.accent,
        shape: RoundedRectangleBorder(
          borderRadius: skin.radius(RadiusToken.button),
        ),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surfaceRaised,
      indicatorColor: palette.accentSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.surfaceOverlay,
        borderRadius: skin.radius(RadiusToken.chip),
        border: Border.all(color: palette.border),
      ),
      textStyle: text.bodySmall,
    ),
  );
}

// ── ColorScheme ───────────────────────────────────────────────────────────
//
// Material bekommt aus unserem Token-Set nur, was es wirklich braucht. Alles
// Weitere (surfaceSunken, textMuted, die Eintragstyp-Farben) bleibt in
// ChroniclePalette — dort kann kein Material-Widget es zufällig benutzen.

ColorScheme _buildColorScheme(ChroniclePalette p, Brightness brightness) {
  return ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.accentContrast,
    primaryContainer: p.accentSurface,
    onPrimaryContainer: p.textPrimary,
    secondary: p.accentMuted,
    onSecondary: p.accentContrast,
    secondaryContainer: p.surfaceRaised,
    onSecondaryContainer: p.textPrimary,
    tertiary: p.info,
    onTertiary: p.accentContrast,
    error: p.danger,
    onError: p.accentContrast,
    errorContainer: p.dangerSurface,
    onErrorContainer: p.textPrimary,
    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.surfaceSunken,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surfaceRaised,
    surfaceContainerHigh: p.surfaceRaised,
    surfaceContainerHighest: p.surfaceOverlay,
    outline: p.border,
    outlineVariant: p.divider,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
  );
}

// ── TextTheme ─────────────────────────────────────────────────────────────

TextTheme _buildTextTheme(ChroniclePalette p, ChronicleTypography t) {
  TextStyle heading(double size) => TextStyle(
    fontFamily: t.heading,
    fontWeight: t.headingWeight,
    letterSpacing: t.headingLetterSpacing,
    color: p.textHeading,
    fontSize: size,
    height: 1.25,
  );

  TextStyle body(double size, {Color? color, FontWeight? weight}) => TextStyle(
    fontFamily: t.body,
    fontWeight: weight ?? FontWeight.w400,
    letterSpacing: t.bodyLetterSpacing,
    color: color ?? p.textPrimary,
    fontSize: size,
    height: 1.5,
  );

  return TextTheme(
    displayLarge: heading(40),
    displayMedium: heading(34),
    displaySmall: heading(30),
    headlineLarge: heading(27),
    headlineMedium: heading(24),
    headlineSmall: heading(21),
    titleLarge: heading(18),
    titleMedium: body(15, weight: FontWeight.w600),
    titleSmall: body(13, weight: FontWeight.w600),
    bodyLarge: body(16),
    bodyMedium: body(14),
    bodySmall: body(13, color: p.textSecondary),
    labelLarge: body(14, weight: FontWeight.w500),
    labelMedium: body(12, weight: FontWeight.w500, color: p.textSecondary),
    labelSmall: body(11, weight: FontWeight.w500, color: p.textMuted),
  );
}

// ── Button-Stile nach Skin ────────────────────────────────────────────────
//
// Die drei Button-Stile sind kein Zierrat: sie tragen sichtbar den Mood.
// `engraved` ist in Flutter nicht nachbaubar wie in CSS — wir nähern es über
// eine kräftige Kante auf gefüllter Fläche an, was auf Pergament überzeugend
// wirkt.

ButtonStyle _filledStyle(ChroniclePalette p, ChronicleSkin skin) {
  final shape = RoundedRectangleBorder(
    borderRadius: skin.radius(RadiusToken.button),
    side: switch (skin.button) {
      ButtonShapeStyle.engraved => BorderSide(
        color: p.borderStrong,
        width: 1.5,
      ),
      ButtonShapeStyle.outline => BorderSide(color: p.accent),
      ButtonShapeStyle.softFill => BorderSide.none,
    },
  );

  return FilledButton.styleFrom(
    backgroundColor: switch (skin.button) {
      ButtonShapeStyle.softFill => p.accent,
      ButtonShapeStyle.engraved => p.accentSurface,
      ButtonShapeStyle.outline => Colors.transparent,
    },
    foregroundColor: switch (skin.button) {
      ButtonShapeStyle.softFill => p.accentContrast,
      _ => p.accent,
    },
    shape: shape,
  );
}

ButtonStyle _outlinedStyle(ChroniclePalette p, ChronicleSkin skin) {
  return OutlinedButton.styleFrom(
    foregroundColor: p.accent,
    backgroundColor: skin.button == ButtonShapeStyle.softFill
        ? p.accentSurface
        : Colors.transparent,
    side: BorderSide(
      color: skin.button == ButtonShapeStyle.engraved
          ? p.borderStrong
          : p.accentMuted,
      width: skin.button == ButtonShapeStyle.engraved ? 1.5 : 1,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: skin.radius(RadiusToken.button),
    ),
  );
}
