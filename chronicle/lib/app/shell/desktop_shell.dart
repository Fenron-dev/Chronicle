// Datei: chronicle/lib/app/shell/desktop_shell.dart
//
// ZWECK: Das 3-Panel-Desktop-Layout (Konzept §7.1). Alle Panels sind
//        kollabierbar.
//
// WARUM DAS RECHTE PANEL EINEN EIGENEN BREAKPOINT HAT: Drei Spalten auf
//        1000 px machen alle drei unbenutzbar. Unterhalb von
//        kContextPanelBreakpoint bleiben Baum und Mitte.
//
// SCHRITT: 2

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/theme_access.dart';
import 'context_panel.dart';
import 'nav_panel.dart';
import 'shell_providers.dart';
import 'top_bar.dart';

class DesktopShell extends ConsumerWidget {
  const DesktopShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final width = MediaQuery.sizeOf(context).width;

    final showNav = ref.watch(navPanelVisibleProvider);
    final showContext =
        ref.watch(contextPanelVisibleProvider) &&
        width >= kContextPanelBreakpoint;

    return Scaffold(
      body: Column(
        children: [
          const ChronicleTopBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showNav) ...[
                  SizedBox(
                    width: kLeftPanelWidth,
                    child: NavPanel(
                      currentIndex: navigationShell.currentIndex,
                      onSelect: navigationShell.goBranch,
                    ),
                  ),
                  Container(width: 1, color: palette.border),
                ],
                Expanded(child: navigationShell),
                if (showContext) ...[
                  Container(width: 1, color: palette.border),
                  const SizedBox(
                    width: kRightPanelWidth,
                    child: ContextPanel(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
