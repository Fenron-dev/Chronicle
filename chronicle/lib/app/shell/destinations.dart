// Datei: chronicle/lib/app/shell/destinations.dart
//
// ZWECK: Die Hauptbereiche der App — einmal definiert, von Desktop-Sidebar
//        und Mobile-Bottom-Nav gemeinsam genutzt.
//
// WARUM ZENTRAL: Die Branch-Reihenfolge in router.dart und die Reihenfolge
//        der Navigationsziele müssen übereinstimmen, sonst landet ein Tipp
//        auf „Codex" im Play-Log. Eine Liste, zwei Leser.
//
// SCHRITT: 2

import 'package:flutter/material.dart';

/// Ein Hauptbereich der App.
@immutable
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Reihenfolge = Branch-Reihenfolge in router.dart.
const List<ShellDestination> kShellDestinations = [
  ShellDestination(
    label: 'Play-Log',
    icon: Icons.history_edu_outlined,
    selectedIcon: Icons.history_edu,
  ),
  ShellDestination(
    label: 'Codex',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  ShellDestination(
    label: 'Systeme',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category,
  ),
];
