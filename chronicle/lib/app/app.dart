// Datei: chronicle/lib/app/app.dart
//
// ZWECK: Das Wurzel-Widget. Verdrahtet das aktive Preset mit MaterialApp und
//        dem Router.
//
// WARUM ConsumerWidget: Ein Preset-Wechsel muss die gesamte App neu
//        einfärben. Das Theme hängt deshalb an einem Provider, nicht an
//        einem lokalen Zustand.
//
// SCHRITT: 2 (Vault-Gate ergänzt in Schritt 3)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_builder.dart';
import '../core/theme/theme_provider.dart';
import 'router.dart';

/// Wurzel-Widget von Chronicle.
class ChronicleApp extends ConsumerWidget {
  const ChronicleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(activeThemePresetProvider);
    final mode = ref.watch(activeThemeModeProvider);

    return MaterialApp.router(
      title: 'Chronicle',
      debugShowCheckedModeBanner: false,
      theme: buildChronicleTheme(preset, Brightness.light),
      darkTheme: buildChronicleTheme(preset, Brightness.dark),
      themeMode: mode,
      routerConfig: ref.watch(chronicleRouterProvider),
    );
  }
}
