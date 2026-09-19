// Datei: chronicle/lib/core/theme/theme_preset.dart
//
// ZWECK: Ein Theme-Preset als reine Daten — beide Paletten, die Skin-Regler
//        und die Typografie.
//
// WARUM REINE DATEN: Die Umrechnung nach Flutter passiert an genau einer
//        Stelle (theme_builder.dart). Eine zweite Umrechnungsstelle erzeugt
//        Presets, die sich irgendwo anders verhalten als überall sonst.
//
// SIEHE: Skill `chronicle-theme`
// SCHRITT: 2

import 'package:flutter/material.dart';

import 'chronicle_palette.dart';
import 'chronicle_skin.dart';
import 'chronicle_typography.dart';

/// Ein vollständiges Theme-Preset.
@immutable
class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.mood,
    required this.light,
    required this.dark,
    required this.skin,
    required this.typography,
  });

  /// Stabiler Schlüssel. Landet als `basePreset` in `theme/theme.json` eines
  /// Systems — daher nicht umbenennen, ohne eine Migration vorzusehen.
  final String id;

  /// Anzeigename im Theme-Manager.
  final String name;

  /// Der Mood in einem Satz.
  ///
  /// Steht hier, weil ein Preset ohne beschreibbaren Mood keines ist, sondern
  /// ein Farb-Override auf einem bestehenden (siehe Skill `chronicle-theme`).
  final String mood;

  final ChroniclePalette light;
  final ChroniclePalette dark;
  final ChronicleSkin skin;
  final ChronicleTypography typography;

  /// Palette für eine Helligkeit.
  ChroniclePalette paletteFor(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
