// Datei: chronicle/lib/features/tracks/clock_face.dart
//
// ZWECK: Eine Clock als Kreis mit Segmenten (Konzept §4.5, FitD).
//
// FARBEN AUS DER PALETTE, NICHT AUS DEM PAINTER: Der Painter bekommt fertige
//        Farben übergeben. Hartkodiert wäre die Clock in drei von vier
//        Presets falsch (Skill `chronicle-theme`).
//
// SCHRITT: 8

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme_access.dart';
import '../../domain/tracks/track.dart';

class ClockFace extends StatelessWidget {
  const ClockFace({required this.clock, super.key, this.size = 28});

  final ClockState clock;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      label: '${clock.filled} von ${clock.segments} Segmenten gefüllt',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ClockPainter(
            clock: clock,
            // Eine volle Clock ist ein Ereignis, kein weiterer Fortschritt —
            // sie bekommt deshalb die Warnfarbe statt des Akzents.
            fill: clock.isComplete ? palette.warning : palette.accent,
            empty: palette.surfaceSunken,
            line: palette.borderStrong,
          ),
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  const _ClockPainter({
    required this.clock,
    required this.fill,
    required this.empty,
    required this.line,
  });

  final ClockState clock;
  final Color fill;
  final Color empty;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi / clock.segments;

    // Bei zwölf Uhr beginnen, im Uhrzeigersinn füllen — so liest man
    // Clocks am Spieltisch.
    const start = -math.pi / 2;

    for (var i = 0; i < clock.segments; i++) {
      canvas.drawArc(
        rect,
        start + i * sweep,
        sweep,
        true,
        Paint()..color = i < clock.filled ? fill : empty,
      );
    }

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < clock.segments; i++) {
      final angle = start + i * sweep;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        stroke,
      );
    }
    canvas.drawCircle(center, radius, stroke);
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.clock.filled != clock.filled ||
      old.clock.segments != clock.segments ||
      old.fill != fill ||
      old.empty != empty ||
      old.line != line;
}
