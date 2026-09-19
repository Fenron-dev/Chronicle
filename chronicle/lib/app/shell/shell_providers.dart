// Datei: chronicle/lib/app/shell/shell_providers.dart
//
// ZWECK: Sichtbarkeit der kollabierbaren Panels. Alle drei Panels des
//        Desktop-Layouts lassen sich einklappen (Konzept §7.1).
//
// WARUM keepAlive: Ein eingeklapptes Panel soll eingeklappt bleiben, wenn
//        der Nutzer den Tab wechselt — sonst klappt es bei jedem Wechsel
//        wieder auf.
//
// SCHRITT: 2

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_providers.g.dart';

/// Ob der Navigations-Baum links sichtbar ist.
@Riverpod(keepAlive: true)
class NavPanelVisible extends _$NavPanelVisible {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

/// Ob das Kontext-Panel rechts sichtbar ist.
@Riverpod(keepAlive: true)
class ContextPanelVisible extends _$ContextPanelVisible {
  @override
  bool build() => true;

  void toggle() => state = !state;
}
