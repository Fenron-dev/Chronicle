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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/dev_log.dart';

void main() {
  // Alles in einer Zone, deren `print` im Dev-Log landet (captureZonePrint).
  // Die Bindung entsteht erst in runApp, also ebenfalls in dieser Zone —
  // sonst meldet Flutter einen Zone-Mismatch.
  runZoned(() {
    // Vor runApp: sonst entgeht dem Log genau der Fehler, der beim Start
    // auftritt — und das ist erfahrungsgemäß der interessanteste.
    DevLog.installErrorHandlers();
    devLog.info('app', 'Chronicle startet');

    // ProviderScope umschließt die gesamte App — Riverpod braucht genau einen.
    runApp(const ProviderScope(child: ChronicleApp()));
  }, zoneSpecification: captureZonePrint());
}
