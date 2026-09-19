// Datei: chronicle/lib/core/theme/presets/nocturne.dart
//
// MOOD: Ein aufgeräumter Schreibtisch nach Mitternacht — nichts lenkt ab.
//
// Kühle Neutraltöne, Grotesk, keine Ornamentik, weiche Radien.
//
// SCHRITT: 2

import 'package:flutter/material.dart';

import '../chronicle_palette.dart';
import '../chronicle_skin.dart';
import '../chronicle_typography.dart';
import '../theme_preset.dart';

const ChroniclePalette _dark = ChroniclePalette(
  surface: Color(0xFF14161A),
  surfaceRaised: Color(0xFF1C1F25),
  surfaceSunken: Color(0xFF0E1013),
  surfaceOverlay: Color(0xFF232830),
  border: Color(0xFF2C313A),
  borderStrong: Color(0xFF424A57),
  divider: Color(0xFF232830),
  textPrimary: Color(0xFFE3E7EC),
  textSecondary: Color(0xFFA4AEBB),
  textMuted: Color(0xFF7D8896),
  textHeading: Color(0xFFF2F5F8),
  textBold: Color(0xFFFFFFFF),
  textHighlight: Color(0xFF8FD0FF),
  textLink: Color(0xFF6FB3F2),
  accent: Color(0xFF4C8EF7),
  accentMuted: Color(0xFF35619F),
  accentContrast: Color(0xFF0E1013),
  accentSurface: Color(0xFF17263C),
  success: Color(0xFF4ECB8D),
  successSurface: Color(0xFF12261E),
  danger: Color(0xFFEC5B60),
  dangerSurface: Color(0xFF2A1315),
  warning: Color(0xFFE8AC54),
  warningSurface: Color(0xFF2A2113),
  info: Color(0xFF4C8EF7),
  infoSurface: Color(0xFF14202F),
  entryNarration: Color(0xFFE3E7EC),
  entryRoll: Color(0xFFA1863D),
  entryOracle: Color(0xFFC35AED),
  entryCard: Color(0xFF3A9A7A),
  entryPlotbeat: Color(0xFFE85869),
  entryAi: Color(0xFF4C8FC9),
  entryMeta: Color(0xFF838A92),
);

const ChroniclePalette _light = ChroniclePalette(
  surface: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFF7F9FB),
  surfaceSunken: Color(0xFFEDF1F5),
  surfaceOverlay: Color(0xFFFFFFFF),
  border: Color(0xFFDCE3EA),
  borderStrong: Color(0xFFB6C1CD),
  divider: Color(0xFFE6EBF0),
  textPrimary: Color(0xFF1A1D22),
  textSecondary: Color(0xFF4D5661),
  textMuted: Color(0xFF6F7883),
  textHeading: Color(0xFF0D1015),
  textBold: Color(0xFF000000),
  textHighlight: Color(0xFF1A6FC4),
  textLink: Color(0xFF1A6FC4),
  accent: Color(0xFF1A6FC4),
  accentMuted: Color(0xFF7FA9D6),
  accentContrast: Color(0xFFFFFFFF),
  accentSurface: Color(0xFFE3EEFA),
  success: Color(0xFF1B6B45),
  successSurface: Color(0xFFDDF0E6),
  danger: Color(0xFFB02428),
  dangerSurface: Color(0xFFFADDDE),
  warning: Color(0xFF8A5F10),
  warningSurface: Color(0xFFF8EBD2),
  info: Color(0xFF1A6FC4),
  infoSurface: Color(0xFFE3EEFA),
  entryNarration: Color(0xFF1A1D22),
  entryRoll: Color(0xFF886810),
  entryOracle: Color(0xFFAC1BE4),
  entryCard: Color(0xFF0F7B57),
  entryPlotbeat: Color(0xFFD51A30),
  entryAi: Color(0xFF176FBC),
  entryMeta: Color(0xFF686D74),
);

/// Nocturne — klar, minimal, modern.
const ThemePreset nocturnePreset = ThemePreset(
  id: 'nocturne',
  name: 'Nocturne',
  mood: 'Ein aufgeräumter Schreibtisch nach Mitternacht — nichts lenkt ab.',
  light: _light,
  dark: _dark,
  skin: ChronicleSkin(
    ornament: OrnamentLevel.none,
    divider: DividerStyle.line,
    button: ButtonShapeStyle.softFill,
    texture: SurfaceTexture.none,
    accentMode: AccentMode.line,
    radiusScale: 1.2,
  ),
  typography: ChronicleTypography(
    heading: 'Inter',
    body: 'Inter',
    mono: 'JetBrains Mono',
    headingWeight: FontWeight.w600,
    headingCaps: false,
    headingLetterSpacing: -0.2,
    bodyLetterSpacing: 0,
  ),
);
