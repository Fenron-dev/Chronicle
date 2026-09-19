// Datei: chronicle/lib/app/shell/responsive_shell.dart
//
// ZWECK: Entscheidet allein anhand der Fensterbreite zwischen Desktop- und
//        Mobile-Layout. Muster aus MediaShelf.
//
// WARUM BREITE STATT PLATTFORM: Ein schmales Fenster auf dem Desktop soll
//        sich wie Mobile verhalten — und ein Tablet im Querformat wie
//        Desktop. Die Plattform sagt darüber nichts aus.
//
// SCHRITT: 2

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import 'desktop_shell.dart';
import 'mobile_shell.dart';

class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return width >= kDesktopBreakpoint
        ? DesktopShell(navigationShell: navigationShell)
        : MobileShell(navigationShell: navigationShell);
  }
}
