// Datei: chronicle/lib/core/theme/chronicle_typography.dart
//
// ZWECK: Die Typografie-Tokens eines Presets.
//
// WARUM EIGENE EXTENSION: Familien, Gewicht und Laufweite landen zwar im
//        TextTheme, aber `headingCaps` lässt sich in einem TextStyle nicht
//        ausdrücken — Versalien sind eine Texttransformation, keine
//        Schrifteigenschaft. Ein Widget, das eine Überschrift rendert, muss
//        den Wert also lesen können.
//
// TYPOGRAFIE IST DER GRÖSSTE MOOD-HEBEL: Serifen + Versalien lesen sich
//        mittelalterlich, Mono + weite Laufweite nach SciFi. Wer nur Farben
//        tauscht, bekommt vier Mal dasselbe Preset in anderen Farben.
//
// OFFLINE-FIRST: Hier stehen nur Familiennamen. Die Schriftdateien werden als
//        Assets gebündelt (siehe CLAUDE.md §3) — kein Laufzeit-Download.
//        Fehlt eine Familie, fällt Flutter auf die Plattformschrift zurück;
//        die App bleibt benutzbar.
//
// SIEHE: Skill `chronicle-theme`
// SCHRITT: 2

import 'package:flutter/material.dart';

/// Typografie-Tokens eines Themes.
@immutable
class ChronicleTypography extends ThemeExtension<ChronicleTypography> {
  const ChronicleTypography({
    required this.heading,
    required this.body,
    required this.mono,
    required this.headingWeight,
    required this.headingCaps,
    required this.headingLetterSpacing,
    required this.bodyLetterSpacing,
  });

  /// Familienname der Überschriftenschrift.
  final String heading;

  /// Familienname der Fließtextschrift.
  final String body;

  /// Familienname der Monospace-Schrift (Würfelausdrücke, Code, Terminal).
  final String mono;

  final FontWeight headingWeight;

  /// Ob Überschriften in Versalien gesetzt werden.
  final bool headingCaps;

  final double headingLetterSpacing;
  final double bodyLetterSpacing;

  /// Neutrale Typografie für Tests.
  static const ChronicleTypography fallback = ChronicleTypography(
    heading: 'Roboto',
    body: 'Roboto',
    mono: 'RobotoMono',
    headingWeight: FontWeight.w600,
    headingCaps: false,
    headingLetterSpacing: 0,
    bodyLetterSpacing: 0,
  );

  /// Wendet [headingCaps] auf einen Überschriftentext an.
  String formatHeading(String text) => headingCaps ? text.toUpperCase() : text;

  @override
  ChronicleTypography copyWith({
    String? heading,
    String? body,
    String? mono,
    FontWeight? headingWeight,
    bool? headingCaps,
    double? headingLetterSpacing,
    double? bodyLetterSpacing,
  }) {
    return ChronicleTypography(
      heading: heading ?? this.heading,
      body: body ?? this.body,
      mono: mono ?? this.mono,
      headingWeight: headingWeight ?? this.headingWeight,
      headingCaps: headingCaps ?? this.headingCaps,
      headingLetterSpacing: headingLetterSpacing ?? this.headingLetterSpacing,
      bodyLetterSpacing: bodyLetterSpacing ?? this.bodyLetterSpacing,
    );
  }

  @override
  ChronicleTypography lerp(covariant ChronicleTypography? other, double t) {
    if (other == null) return this;
    // Schriftfamilien lassen sich nicht überblenden — sie kippen zur Hälfte.
    return ChronicleTypography(
      heading: t < 0.5 ? heading : other.heading,
      body: t < 0.5 ? body : other.body,
      mono: t < 0.5 ? mono : other.mono,
      headingWeight: t < 0.5 ? headingWeight : other.headingWeight,
      headingCaps: t < 0.5 ? headingCaps : other.headingCaps,
      headingLetterSpacing:
          headingLetterSpacing +
          (other.headingLetterSpacing - headingLetterSpacing) * t,
      bodyLetterSpacing:
          bodyLetterSpacing + (other.bodyLetterSpacing - bodyLetterSpacing) * t,
    );
  }
}
