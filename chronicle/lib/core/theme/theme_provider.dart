// Datei: chronicle/lib/core/theme/theme_provider.dart
//
// ZWECK: Welches Preset und welche Helligkeit gerade gelten.
//
// SCOPE-KETTE: Ab Schritt 3 löst der Provider die Kette
//        Notiz → Game → System → App-Default auf und liefert das Ergebnis.
//        Solange es noch keine Vaults gibt, ist der Wert schlicht die
//        manuelle Auswahl aus dem Theme-Manager.
//
// WARUM keepAlive: Das aktive Theme ist echter App-Zustand. Würde es beim
//        Verlassen des Theme-Managers entsorgt, spränge die App beim
//        Zurücknavigieren aufs Default-Preset.
//
// SCHRITT: 2

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'presets.dart';
import 'theme_preset.dart';

part 'theme_provider.g.dart';

/// Das aktuell gewählte Theme-Preset.
@Riverpod(keepAlive: true)
class ActiveThemePreset extends _$ActiveThemePreset {
  @override
  ThemePreset build() => kDefaultPreset;

  /// Wechselt auf das Preset mit [id]. Unbekannte ids fallen auf den
  /// Default zurück, statt zu werfen (siehe presetById).
  void select(String id) => state = presetById(id);
}

/// Hell, dunkel oder der Systemwert.
@Riverpod(keepAlive: true)
class ActiveThemeMode extends _$ActiveThemeMode {
  @override
  ThemeMode build() => ThemeMode.dark;

  void choose(ThemeMode mode) => state = mode;

  /// Schaltet zwischen hell und dunkel um.
  ///
  /// [platformBrightness] entscheidet die Richtung, wenn gerade
  /// [ThemeMode.system] aktiv ist — sonst wüsste der Nutzer nicht, wohin
  /// der erste Tastendruck führt.
  void toggle(Brightness platformBrightness) {
    final isDark = switch (state) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
    state = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}
