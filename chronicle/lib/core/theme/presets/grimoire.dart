// Datei: chronicle/lib/core/theme/presets/grimoire.dart
//
// MOOD: Kerzenlicht auf Pergament, ein Foliant in einer zugigen Bibliothek.
//
// Default-Preset (Konzept §5.3). Warme Dunkeltöne, Serifen-Versalien,
// reiche Ornamentik, scharfe Radien.
//
// SCHRITT: 2

import 'package:flutter/material.dart';

import '../chronicle_palette.dart';
import '../chronicle_skin.dart';
import '../chronicle_typography.dart';
import '../theme_preset.dart';

const ChroniclePalette _dark = ChroniclePalette(
  surface: Color(0xFF14110E),
  surfaceRaised: Color(0xFF1E1A15),
  surfaceSunken: Color(0xFF0D0B09),
  surfaceOverlay: Color(0xFF262119),
  border: Color(0xFF3A3228),
  borderStrong: Color(0xFF574B3B),
  divider: Color(0xFF2E2820),
  textPrimary: Color(0xFFE8DFCE),
  textSecondary: Color(0xFFB5A88E),
  textMuted: Color(0xFF8D8270),
  textHeading: Color(0xFFE3C88A),
  textBold: Color(0xFFF2E9D6),
  textHighlight: Color(0xFFF0C96B),
  textLink: Color(0xFFD4B03A),
  accent: Color(0xFFB8894A),
  accentMuted: Color(0xFF8A6636),
  accentContrast: Color(0xFF14110E),
  accentSurface: Color(0xFF2A2117),
  success: Color(0xFF8FB468),
  successSurface: Color(0xFF1E2417),
  danger: Color(0xFFCF5B41),
  dangerSurface: Color(0xFF2A1512),
  warning: Color(0xFFD9A648),
  warningSurface: Color(0xFF2B2011),
  info: Color(0xFF79A2C4),
  infoSurface: Color(0xFF141E26),
  entryNarration: Color(0xFFE8DFCE),
  entryRoll: Color(0xFF9D8442),
  entryOracle: Color(0xFFBC5EE0),
  entryCard: Color(0xFF3F9679),
  entryPlotbeat: Color(0xFFDC5D6B),
  entryAi: Color(0xFF508CBF),
  entryMeta: Color(0xFF8B867D),
);

const ChroniclePalette _light = ChroniclePalette(
  surface: Color(0xFFF4EDDE),
  surfaceRaised: Color(0xFFFBF6EA),
  surfaceSunken: Color(0xFFE8DFC9),
  surfaceOverlay: Color(0xFFFFFBF0),
  border: Color(0xFFD3C6AA),
  borderStrong: Color(0xFFB3A287),
  divider: Color(0xFFDCD1B8),
  textPrimary: Color(0xFF2A2318),
  textSecondary: Color(0xFF574B38),
  textMuted: Color(0xFF7A6C55),
  textHeading: Color(0xFF5C3E12),
  textBold: Color(0xFF1C1710),
  textHighlight: Color(0xFF8A5E12),
  textLink: Color(0xFF7A5C12),
  accent: Color(0xFF8A6224),
  accentMuted: Color(0xFFB49560),
  accentContrast: Color(0xFFFBF6EA),
  accentSurface: Color(0xFFEADFC2),
  success: Color(0xFF41631F),
  successSurface: Color(0xFFE4EBD6),
  danger: Color(0xFF8E3019),
  dangerSurface: Color(0xFFF3DCD6),
  warning: Color(0xFF8A5F0C),
  warningSurface: Color(0xFFF6E8CB),
  info: Color(0xFF2B5170),
  infoSurface: Color(0xFFD9E5EF),
  entryNarration: Color(0xFF2A2318),
  entryRoll: Color(0xFF7A5F12),
  entryOracle: Color(0xFF9B1FCD),
  entryCard: Color(0xFF117151),
  entryPlotbeat: Color(0xFFC01D30),
  entryAi: Color(0xFF1965A7),
  entryMeta: Color(0xFF66625C),
);

/// Grimoire — das Default-Preset.
const ThemePreset grimoirePreset = ThemePreset(
  id: 'grimoire',
  name: 'Grimoire',
  mood: 'Kerzenlicht auf Pergament, ein Foliant in einer zugigen Bibliothek.',
  light: _light,
  dark: _dark,
  skin: ChronicleSkin(
    ornament: OrnamentLevel.rich,
    divider: DividerStyle.ornament,
    button: ButtonShapeStyle.engraved,
    texture: SurfaceTexture.parchment,
    accentMode: AccentMode.line,
    radiusScale: 0.4,
  ),
  typography: ChronicleTypography(
    heading: 'Cormorant Garamond',
    body: 'Crimson Pro',
    mono: 'JetBrains Mono',
    headingWeight: FontWeight.w600,
    headingCaps: true,
    headingLetterSpacing: 1.6,
    bodyLetterSpacing: 0,
  ),
);
