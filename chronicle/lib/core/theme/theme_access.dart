// Datei: chronicle/lib/core/theme/theme_access.dart
//
// ZWECK: Bequemer Zugriff auf die drei Chronicle-Extensions im Widget.
//
// WARUM DAS `!`: Jedes von buildChronicleTheme gebaute ThemeData registriert
//        alle drei Extensions. Fehlt eine, ist das ein Konfigurationsfehler,
//        der laut scheitern soll — kein Laufzeitfall, den jedes Widget
//        einzeln behandeln müsste. Tests, die ein nacktes ThemeData bauen,
//        setzen die `fallback`-Werte explizit.
//
// SCHRITT: 2

import 'package:flutter/material.dart';

import 'chronicle_palette.dart';
import 'chronicle_skin.dart';
import 'chronicle_typography.dart';

extension ChronicleThemeAccess on BuildContext {
  /// Semantische Farb-Tokens des aktiven Themes.
  ChroniclePalette get palette => Theme.of(this).extension<ChroniclePalette>()!;

  /// Skin-Regler des aktiven Themes.
  ChronicleSkin get skin => Theme.of(this).extension<ChronicleSkin>()!;

  /// Typografie-Tokens des aktiven Themes.
  ChronicleTypography get typography =>
      Theme.of(this).extension<ChronicleTypography>()!;
}
