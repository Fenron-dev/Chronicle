// Datei: chronicle/lib/core/theme/presets/dossier.dart
//
// MOOD: Ein Aktendeckel auf einem Behördentisch, Kaffeerand inklusive.
//
// Papierweiß und Aktenrot, Serifen-Überschriften auf Grotesk-Fließtext,
// dezente Ornamentik, Outline-Buttons.
//
// SCHRITT: 2

import 'package:flutter/material.dart';

import '../chronicle_palette.dart';
import '../chronicle_skin.dart';
import '../chronicle_typography.dart';
import '../theme_preset.dart';

const ChroniclePalette _light = ChroniclePalette(
  surface: Color(0xFFFAF8F4),
  surfaceRaised: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFEFEBE3),
  surfaceOverlay: Color(0xFFFFFFFF),
  border: Color(0xFFDAD3C7),
  borderStrong: Color(0xFFB5AB99),
  divider: Color(0xFFE5DFD4),
  textPrimary: Color(0xFF22201C),
  textSecondary: Color(0xFF565049),
  textMuted: Color(0xFF7B7469),
  textHeading: Color(0xFF14120F),
  textBold: Color(0xFF000000),
  textHighlight: Color(0xFF8A2C2C),
  textLink: Color(0xFF1F5B8A),
  accent: Color(0xFF9C3B32),
  accentMuted: Color(0xFFC99089),
  accentContrast: Color(0xFFFFFFFF),
  accentSurface: Color(0xFFF5E2DF),
  success: Color(0xFF2A6138),
  successSurface: Color(0xFFDFEDE2),
  danger: Color(0xFF9C3B32),
  dangerSurface: Color(0xFFF5E2DF),
  warning: Color(0xFF7D5A0F),
  warningSurface: Color(0xFFF6EBD0),
  info: Color(0xFF1F5B8A),
  infoSurface: Color(0xFFDEEAF3),
  entryNarration: Color(0xFF22201C),
  entryRoll: Color(0xFF826412),
  entryOracle: Color(0xFFA51FDA),
  entryCard: Color(0xFF117755),
  entryPlotbeat: Color(0xFFCD1D31),
  entryAi: Color(0xFF196BB4),
  entryMeta: Color(0xFF6D6862),
);

const ChroniclePalette _dark = ChroniclePalette(
  surface: Color(0xFF1A1917),
  surfaceRaised: Color(0xFF23221F),
  surfaceSunken: Color(0xFF121110),
  surfaceOverlay: Color(0xFF2B2A26),
  border: Color(0xFF3A3833),
  borderStrong: Color(0xFF565349),
  divider: Color(0xFF2E2D28),
  textPrimary: Color(0xFFE8E5DE),
  textSecondary: Color(0xFFADA89C),
  textMuted: Color(0xFF858075),
  textHeading: Color(0xFFF5F3ED),
  textBold: Color(0xFFFFFFFF),
  textHighlight: Color(0xFFE8918A),
  textLink: Color(0xFF7FB3DB),
  accent: Color(0xFFD4645A),
  accentMuted: Color(0xFF8A4039),
  accentContrast: Color(0xFF1A1917),
  accentSurface: Color(0xFF33211F),
  success: Color(0xFF7ABD8B),
  successSurface: Color(0xFF172317),
  danger: Color(0xFFD4645A),
  dangerSurface: Color(0xFF2B1613),
  warning: Color(0xFFD9A94A),
  warningSurface: Color(0xFF2A2213),
  info: Color(0xFF7FB3DB),
  infoSurface: Color(0xFF16222B),
  entryNarration: Color(0xFFE8E5DE),
  entryRoll: Color(0xFFA28947),
  entryOracle: Color(0xFFC064E4),
  entryCard: Color(0xFF449B7E),
  entryPlotbeat: Color(0xFFE06371),
  entryAi: Color(0xFF5690C4),
  entryMeta: Color(0xFF908C81),
);

/// Dossier — moderne Erde.
const ThemePreset dossierPreset = ThemePreset(
  id: 'dossier',
  name: 'Dossier',
  mood: 'Ein Aktendeckel auf einem Behördentisch, Kaffeerand inklusive.',
  light: _light,
  dark: _dark,
  skin: ChronicleSkin(
    ornament: OrnamentLevel.subtle,
    divider: DividerStyle.doubleLine,
    button: ButtonShapeStyle.outline,
    texture: SurfaceTexture.none,
    accentMode: AccentMode.line,
    radiusScale: 0.6,
  ),
  typography: ChronicleTypography(
    heading: 'Source Serif 4',
    body: 'Inter',
    mono: 'JetBrains Mono',
    headingWeight: FontWeight.w600,
    headingCaps: false,
    headingLetterSpacing: 0,
    bodyLetterSpacing: 0,
  ),
);
