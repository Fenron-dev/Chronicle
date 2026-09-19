// Datei: chronicle/lib/app/shell/mobile_shell.dart
//
// ZWECK: Mobile-Layout (Konzept §7.5) — Bottom-Nav statt Sidebar.
//
// SCHRITT: 2

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'destinations.dart';

class MobileShell extends StatelessWidget {
  const MobileShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: [
          for (final destination in kShellDestinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
