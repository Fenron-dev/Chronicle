// Datei: chronicle/lib/core/theme/presets/terminal.dart
//
// MOOD: Phosphor-Röhre in einem Frachtraum, drei Systeme laufen im Notmodus.
//
// Schmale Palette, Mono als Fließtextschrift, weite Laufweite, Scanline,
// Akzent als Schein, harte Kanten.
//
// HINWEIS ZUR HELLEN VARIANTE: „Terminal hell" wirkt konstruiert, ist aber
//        nötig — Nutzer erwarten, dass der Hell/Dunkel-Schalter überall
//        greift. Sie liest als Phosphorgrün auf Papier.
//
// SCHRITT: 2

import 'package:flutter/material.dart';

import '../chronicle_palette.dart';
import '../chronicle_skin.dart';
import '../chronicle_typography.dart';
import '../theme_preset.dart';

const ChroniclePalette _dark = ChroniclePalette(
  surface: Color(0xFF050A07),
  surfaceRaised: Color(0xFF0A140E),
  surfaceSunken: Color(0xFF020604),
  surfaceOverlay: Color(0xFF0E1C14),
  border: Color(0xFF14301F),
  borderStrong: Color(0xFF1F4A31),
  divider: Color(0xFF102618),
  textPrimary: Color(0xFF8CF5B4),
  textSecondary: Color(0xFF5BC489),
  textMuted: Color(0xFF3E9460),
  textHeading: Color(0xFFB6FFD2),
  textBold: Color(0xFFDFFFEA),
  textHighlight: Color(0xFFB6FFD2),
  textLink: Color(0xFF4FE08A),
  accent: Color(0xFF23E07A),
  accentMuted: Color(0xFF148046),
  accentContrast: Color(0xFF020604),
  accentSurface: Color(0xFF0B2417),
  success: Color(0xFF23E07A),
  successSurface: Color(0xFF07220F),
  danger: Color(0xFFFF6A5A),
  dangerSurface: Color(0xFF2A0C08),
  warning: Color(0xFFFFC244),
  warningSurface: Color(0xFF2A2008),
  info: Color(0xFF44D9FF),
  infoSurface: Color(0xFF072229),
  entryNarration: Color(0xFF8CF5B4),
  entryRoll: Color(0xFF9D7F2C),
  entryOracle: Color(0xFFC344F5),
  entryCard: Color(0xFF29926F),
  entryPlotbeat: Color(0xFFEC4256),
  entryAi: Color(0xFF3986CB),
  entryMeta: Color(0xFF78867E),
);

const ChroniclePalette _light = ChroniclePalette(
  surface: Color(0xFFF2F6F1),
  surfaceRaised: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFE3EBE2),
  surfaceOverlay: Color(0xFFFFFFFF),
  border: Color(0xFFC2D3C2),
  borderStrong: Color(0xFF98B39A),
  divider: Color(0xFFD2E0D1),
  textPrimary: Color(0xFF0C2A16),
  textSecondary: Color(0xFF2D5738),
  textMuted: Color(0xFF4F7257),
  textHeading: Color(0xFF06200F),
  textBold: Color(0xFF041A0C),
  textHighlight: Color(0xFF046B34),
  textLink: Color(0xFF046B34),
  accent: Color(0xFF05803D),
  accentMuted: Color(0xFF6FAF8A),
  accentContrast: Color(0xFFFFFFFF),
  accentSurface: Color(0xFFDDEFE3),
  success: Color(0xFF05803D),
  successSurface: Color(0xFFDDEFE3),
  danger: Color(0xFFA81F10),
  dangerSurface: Color(0xFFF7DCD8),
  warning: Color(0xFF7D5700),
  warningSurface: Color(0xFFF7EBCB),
  info: Color(0xFF0A6178),
  infoSurface: Color(0xFFD7EDF4),
  entryNarration: Color(0xFF0C2A16),
  entryRoll: Color(0xFF836207),
  entryOracle: Color(0xFFA40BE0),
  entryCard: Color(0xFF067550),
  entryPlotbeat: Color(0xFFCF0A21),
  entryAi: Color(0xFF0967BA),
  entryMeta: Color(0xFF5F6A62),
);

/// Terminal — SciFi.
const ThemePreset terminalPreset = ThemePreset(
  id: 'terminal',
  name: 'Terminal',
  mood: 'Phosphor-Röhre in einem Frachtraum, Systeme im Notmodus.',
  light: _light,
  dark: _dark,
  skin: ChronicleSkin(
    ornament: OrnamentLevel.none,
    divider: DividerStyle.glyph,
    button: ButtonShapeStyle.outline,
    texture: SurfaceTexture.scanline,
    accentMode: AccentMode.glow,
    radiusScale: 0,
  ),
  typography: ChronicleTypography(
    heading: 'JetBrains Mono',
    body: 'JetBrains Mono',
    mono: 'JetBrains Mono',
    headingWeight: FontWeight.w700,
    headingCaps: true,
    headingLetterSpacing: 3,
    bodyLetterSpacing: 0.4,
  ),
);
