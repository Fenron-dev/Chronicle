// Datei: chronicle/test/theme_test.dart
//
// ZWECK: Erzwingt die Zusagen der Theme-Engine für JEDES Preset — Kontrast
//        und Unterscheidbarkeit der Eintragstyp-Farben.
//
// WARUM AUTOMATISIERT: Beim Anlegen der vier Presets von Hand lagen elf
//        Farbpaare zu dicht beieinander (Gold neben Orange, Violett neben
//        Blau, Türkis neben Blau). Am Bildschirm fällt so etwas erst auf,
//        wenn man die Typen nebeneinander sieht — und dann meist zu spät.
//        Dieser Test macht daraus einen roten CI-Lauf statt eines
//        unleserlichen Play-Logs.
//
// SIEHE: Skill `chronicle-theme`
// SCHRITT: 2

import 'dart:math' as math;

import 'package:chronicle/core/theme/chronicle_palette.dart';
import 'package:chronicle/core/theme/chronicle_skin.dart';
import 'package:chronicle/core/theme/chronicle_typography.dart';
import 'package:chronicle/domain/log/entry_kind.dart';
import 'package:chronicle/core/theme/presets.dart';
import 'package:chronicle/core/theme/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Relative Leuchtdichte nach WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Kontrastverhältnis zweier Farben nach WCAG 2.1.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Euklidischer RGB-Abstand — grob, aber erklärbar und ausreichend, um
/// „diese beiden sehen gleich aus" zu erwischen.
double _distance(Color a, Color b) {
  final dr = (a.r - b.r) * 255;
  final dg = (a.g - b.g) * 255;
  final db = (a.b - b.b) * 255;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

void main() {
  group('Jedes Preset', () {
    for (final preset in kThemePresets) {
      for (final brightness in Brightness.values) {
        final label = '${preset.name} (${brightness.name})';
        final palette = preset.paletteFor(brightness);

        test('$label erfüllt WCAG AA für Text', () {
          void check(String name, Color fg, Color bg, double min) {
            final value = _contrast(fg, bg);
            expect(
              value,
              greaterThanOrEqualTo(min),
              reason: '$label: $name hat nur ${value.toStringAsFixed(2)}:1',
            );
          }

          check(
            'textPrimary/surface',
            palette.textPrimary,
            palette.surface,
            4.5,
          );
          check(
            'textSecondary/surfaceRaised',
            palette.textSecondary,
            palette.surfaceRaised,
            4.5,
          );
          check(
            'textHeading/surface',
            palette.textHeading,
            palette.surface,
            4.5,
          );
          // textMuted ist bewusst zurückgenommen — 3:1 ist die Grenze, ab der
          // es noch als Text durchgeht.
          check('textMuted/surface', palette.textMuted, palette.surface, 3.0);
          check('accent/surface', palette.accent, palette.surface, 3.0);
          check(
            'accentContrast/accent',
            palette.accentContrast,
            palette.accent,
            4.5,
          );
        });

        test('$label färbt Eintragstypen lesbar', () {
          for (final kind in EntryKind.values) {
            final value = _contrast(palette.colorFor(kind), palette.surface);
            expect(
              value,
              greaterThanOrEqualTo(4.5),
              reason:
                  '$label: ${kind.name} hat nur ${value.toStringAsFixed(2)}:1 '
                  'gegen die Grundfläche',
            );
          }
        });

        test('$label hält Eintragstypen unterscheidbar', () {
          const kinds = EntryKind.values;
          for (var i = 0; i < kinds.length; i++) {
            for (var j = i + 1; j < kinds.length; j++) {
              final value = _distance(
                palette.colorFor(kinds[i]),
                palette.colorFor(kinds[j]),
              );
              expect(
                value,
                greaterThanOrEqualTo(60),
                reason:
                    '$label: ${kinds[i].name} und ${kinds[j].name} liegen nur '
                    '${value.toStringAsFixed(1)} auseinander',
              );
            }
          }
        });

        test('$label registriert alle drei Extensions', () {
          final theme = buildChronicleTheme(preset, brightness);
          expect(theme.extension<ChroniclePalette>(), isNotNull);
          expect(theme.extension<ChronicleSkin>(), isNotNull);
          expect(theme.extension<ChronicleTypography>(), isNotNull);
          expect(theme.brightness, brightness);
        });
      }
    }
  });

  group('Preset-Registry', () {
    test('liefert bei unbekannter id den Default statt zu werfen', () {
      // Ein Vault aus einer neueren Chronicle-Version darf sich öffnen lassen.
      expect(presetById('gibtesnicht').id, kDefaultPreset.id);
      expect(presetById(null).id, kDefaultPreset.id);
    });

    test('kennt jedes mitgelieferte Preset unter seiner id', () {
      for (final preset in kThemePresets) {
        expect(presetById(preset.id).id, preset.id);
      }
    });

    test('vergibt keine id doppelt', () {
      final ids = kThemePresets.map((p) => p.id).toSet();
      expect(ids.length, kThemePresets.length);
    });
  });

  group('ChronicleSkin', () {
    test('skaliert Radien und hält ihr Verhältnis', () {
      const sharp = ChronicleSkin(
        ornament: OrnamentLevel.none,
        divider: DividerStyle.line,
        button: ButtonShapeStyle.outline,
        texture: SurfaceTexture.none,
        accentMode: AccentMode.line,
        radiusScale: 0,
      );
      const soft = ChronicleSkin(
        ornament: OrnamentLevel.none,
        divider: DividerStyle.line,
        button: ButtonShapeStyle.outline,
        texture: SurfaceTexture.none,
        accentMode: AccentMode.line,
        radiusScale: 2,
      );

      expect(sharp.radiusFor(RadiusToken.card), 0);
      expect(
        soft.radiusFor(RadiusToken.card),
        greaterThan(soft.radiusFor(RadiusToken.button)),
      );
      expect(
        soft.radiusFor(RadiusToken.card),
        ChronicleSkin.fallback.radiusFor(RadiusToken.card) * 2,
      );
    });
  });
}
