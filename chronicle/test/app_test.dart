// Datei: chronicle/test/app_test.dart
//
// ZWECK: Rauchtest der App-Shell.
//
// SCHRITT: 2

import 'package:chronicle/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App startet im Play-Log', (tester) async {
    // Desktop-Breite, damit die 3-Panel-Variante greift.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: ChronicleApp()));
    await tester.pumpAndSettle();

    expect(find.text('Das Moor von Mörwald'), findsOneWidget);
  });

  testWidgets('Schmales Fenster zeigt die Bottom-Nav', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: ChronicleApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
