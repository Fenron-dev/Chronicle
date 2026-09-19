// Datei: chronicle/lib/app/app.dart
//
// ZWECK: Das Wurzel-Widget. Hält derzeit nur einen Platzhalter-Screen.
//
// WARUM GETRENNT VON main.dart: Ein Widget-Test kann ChronicleApp direkt
//        pumpen, ohne runApp() aufzurufen.
//
// SCHRITT: 1

import 'package:flutter/material.dart';

/// Wurzel-Widget von Chronicle.
///
/// Ab Schritt 2 liefert diese Klasse `MaterialApp.router` mit dem aus dem
/// aktiven System/Game aufgelösten Theme. Bis dahin steht hier bewusst nichts
/// Gestaltetes: Farben gehören ins Theme-Layer, nicht in ein Widget
/// (siehe Skill `chronicle-theme`).
class ChronicleApp extends StatelessWidget {
  const ChronicleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Chronicle', home: _PlaceholderScreen());
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Chronicle')));
  }
}
