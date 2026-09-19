// Datei: chronicle/lib/core/theme/chronicle_skin.dart
//
// ZWECK: Die sechs Skin-Regler als ThemeExtension — alles, was den Mood eines
//        Presets ausmacht und wofür Material's ThemeData keinen Platz hat.
//
// WARUM EINE EXTENSION: Ornamentik, Textur und Trenner-Stil sind keine Farben
//        und keine Typografie. Sie über ColorScheme zu schmuggeln würde
//        Tokens ihrer Bedeutung berauben; sie global abzulegen würde die
//        Scope-Kette (Notiz → Game → System) brechen.
//
// SIEHE: Skill `chronicle-theme`
// SCHRITT: 2

import 'package:flutter/material.dart';

/// Wie viel Zierrat ein Preset erlaubt.
enum OrnamentLevel { none, subtle, rich }

/// Wie Abschnitte und Log-Einträge getrennt werden.
enum DividerStyle { line, doubleLine, ornament, glyph }

/// Grundform aller Buttons.
enum ButtonShapeStyle { outline, softFill, engraved }

/// Hintergrund-Textur. Das zugehörige Asset liegt im Preset-Ordner —
/// niemals eine Remote-URL (offline-first, CLAUDE.md §2.3).
enum SurfaceTexture { none, parchment, carbon, scanline }

/// Ob der Akzent als Kante oder als Schein auftritt.
enum AccentMode { line, glow }

/// Benannte Radien-Stufen.
///
/// Die Basiswerte stehen an genau einer Stelle und werden vom Preset per
/// [ChronicleSkin.radiusScale] skaliert. So bleibt das Größenverhältnis
/// zwischen Chip, Button, Karte und Dialog in jedem Preset erhalten — genau
/// das ginge verloren, wenn jedes Preset absolute Radien angäbe.
enum RadiusToken { none, chip, button, card, panel, dialog }

const Map<RadiusToken, double> _baseRadii = {
  RadiusToken.none: 0,
  RadiusToken.chip: 4,
  RadiusToken.button: 6,
  RadiusToken.card: 10,
  RadiusToken.panel: 12,
  RadiusToken.dialog: 16,
};

/// Die Skin-Parameter eines Themes.
@immutable
class ChronicleSkin extends ThemeExtension<ChronicleSkin> {
  const ChronicleSkin({
    required this.ornament,
    required this.divider,
    required this.button,
    required this.texture,
    required this.accentMode,
    required this.radiusScale,
  });

  final OrnamentLevel ornament;
  final DividerStyle divider;
  final ButtonShapeStyle button;
  final SurfaceTexture texture;
  final AccentMode accentMode;

  /// Multiplikator auf die Basis-Radien. 0 = scharfkantig, 2 = sehr weich.
  final double radiusScale;

  /// Neutraler Skin für Tests, die ein nacktes ThemeData bauen.
  ///
  /// In der App ist ein fehlender Skin ein Konfigurationsfehler und soll laut
  /// scheitern — deshalb ist dies bewusst kein Default im Widget-Zugriff.
  static const ChronicleSkin fallback = ChronicleSkin(
    ornament: OrnamentLevel.none,
    divider: DividerStyle.line,
    button: ButtonShapeStyle.outline,
    texture: SurfaceTexture.none,
    accentMode: AccentMode.line,
    radiusScale: 1,
  );

  /// Skalierter Radius in Logikpunkten.
  double radiusFor(RadiusToken token) => _baseRadii[token]! * radiusScale;

  /// Fertiger [BorderRadius] — der übliche Aufruf im Widget.
  BorderRadius radius(RadiusToken token) =>
      BorderRadius.circular(radiusFor(token));

  @override
  ChronicleSkin copyWith({
    OrnamentLevel? ornament,
    DividerStyle? divider,
    ButtonShapeStyle? button,
    SurfaceTexture? texture,
    AccentMode? accentMode,
    double? radiusScale,
  }) {
    return ChronicleSkin(
      ornament: ornament ?? this.ornament,
      divider: divider ?? this.divider,
      button: button ?? this.button,
      texture: texture ?? this.texture,
      accentMode: accentMode ?? this.accentMode,
      radiusScale: radiusScale ?? this.radiusScale,
    );
  }

  @override
  ChronicleSkin lerp(covariant ChronicleSkin? other, double t) {
    if (other == null) return this;
    // Enums lassen sich nicht sinnvoll interpolieren — ab der Hälfte kippt
    // der Wert. Nur die Radien-Skala wird weich überblendet, damit ein
    // Theme-Wechsel nicht springt.
    return ChronicleSkin(
      ornament: t < 0.5 ? ornament : other.ornament,
      divider: t < 0.5 ? divider : other.divider,
      button: t < 0.5 ? button : other.button,
      texture: t < 0.5 ? texture : other.texture,
      accentMode: t < 0.5 ? accentMode : other.accentMode,
      radiusScale: lerpDouble(radiusScale, other.radiusScale, t),
    );
  }
}

/// Lineare Interpolation ohne Import von dart:ui.
double lerpDouble(double a, double b, double t) => a + (b - a) * t;
