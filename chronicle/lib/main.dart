// Datei: chronicle/lib/main.dart
//
// ZWECK: Einstiegspunkt. In Schritt 1 nur ein Platzhalter, damit das CI-Gate
//        (analyze + test) etwas Echtes zu prüfen hat.
//
// NÄCHSTER SCHRITT: Schritt 2 ersetzt den Platzhalter durch das Theme-Layer
//        (4 Presets → ThemeData + ChronicleSkin) und die App-Shell
//        (ResponsiveShell + go_router StatefulShellRoute).
//
// SCHRITT: 1

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // ProviderScope umschließt die gesamte App — Riverpod braucht genau einen.
  runApp(const ProviderScope(child: ChronicleApp()));
}
