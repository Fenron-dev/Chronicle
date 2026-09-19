// Datei: chronicle/lib/widgets/skin_divider.dart
//
// ZWECK: Ein Trenner, der den Skin-Regler `divider` tatsächlich umsetzt.
//
// WARUM EIN EIGENES WIDGET: Material's Divider kennt nur „Linie". Die
//        Ornament- und Glyph-Varianten sind der sichtbarste Beleg dafür,
//        dass ein Preset-Wechsel mehr ändert als Farben — genau der Anspruch
//        aus Konzept §5.3.
//
// SIEHE: Skill `chronicle-theme`
// SCHRITT: 2

import 'package:flutter/material.dart';

import '../core/theme/chronicle_skin.dart';
import '../core/theme/theme_access.dart';

/// Waagerechter Trenner im Stil des aktiven Skins.
class SkinDivider extends StatelessWidget {
  const SkinDivider({super.key, this.indent = 0});

  /// Einzug links und rechts.
  final double indent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent, vertical: 8),
      child: switch (skin.divider) {
        DividerStyle.line => Container(height: 1, color: palette.divider),
        DividerStyle.doubleLine => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 1, color: palette.divider),
            const SizedBox(height: 2),
            Container(height: 1, color: palette.divider),
          ],
        ),
        DividerStyle.ornament => Row(
          children: [
            Expanded(child: Container(height: 1, color: palette.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.auto_awesome,
                size: 12,
                color: palette.accentMuted,
              ),
            ),
            Expanded(child: Container(height: 1, color: palette.divider)),
          ],
        ),
        DividerStyle.glyph => Row(
          children: [
            Text(
              '//',
              style: TextStyle(
                fontFamily: context.typography.mono,
                fontSize: 11,
                color: palette.accentMuted,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 1, color: palette.divider)),
          ],
        ),
      },
    );
  }
}
