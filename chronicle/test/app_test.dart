// Datei: chronicle/test/app_test.dart
//
// ZWECK: Die App-Shell von außen — Vault-Gate, Desktop-/Mobile-Umschaltung,
//        Theme-Anwendung.
//
// WARUM MIT ECHTEM VAULT: Das Gate ist der Kern von Schritt 3. Einen
//        gefälschten Vault-Zustand zu injizieren würde genau die Verdrahtung
//        überspringen, die hier schiefgehen kann.
//
// SCHRITT: 3

import 'dart:io';

import 'package:chronicle/app/app.dart';
import 'package:chronicle/data/vault/vault_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('chronicle_app_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Setzt eine Desktop-Fenstergröße für diesen Test.
  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('startet ohne Vault im Picker', (tester) async {
    useSize(tester, const Size(1600, 1000));

    await tester.pumpWidget(const ProviderScope(child: ChronicleApp()));
    await tester.pumpAndSettle();

    expect(find.text('Vault öffnen…'), findsOneWidget);
    expect(find.text('Neuen Vault anlegen…'), findsOneWidget);
  });

  testWidgets('zeigt nach dem Öffnen das 3-Panel-Desktop-Layout', (
    tester,
  ) async {
    useSize(tester, const Size(1600, 1000));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ChronicleApp(),
      ),
    );
    await tester.pumpAndSettle();

    await container
        .read(activeVaultProvider.notifier)
        .createAndOpen(tempDir.path, 'Testvault');
    await tester.pumpAndSettle();

    // Das Gate hat umgeschaltet: Play-Log statt Picker.
    expect(find.text('Vault öffnen…'), findsNothing);
    expect(find.textContaining('Prüfstein'), findsOneWidget);

    // Grimoire ist das Default-Preset und setzt Überschriften in Versalien —
    // genau das ist die Aufgabe von ChronicleTypography.formatHeading.
    expect(find.text('DAS MOOR VON MÖRWALD'), findsOneWidget);

    // Der Vault-Name steht in der oberen Leiste.
    expect(find.text('Testvault'), findsOneWidget);
  });

  testWidgets('zeigt im schmalen Fenster die Bottom-Nav', (tester) async {
    useSize(tester, const Size(500, 900));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ChronicleApp(),
      ),
    );
    await tester.pumpAndSettle();

    await container
        .read(activeVaultProvider.notifier)
        .createAndOpen(tempDir.path, 'Testvault');
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('schließt den Vault zurück in den Picker', (tester) async {
    useSize(tester, const Size(1600, 1000));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ChronicleApp(),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = container.read(activeVaultProvider.notifier);
    await notifier.createAndOpen(tempDir.path, 'Testvault');
    await tester.pumpAndSettle();

    await notifier.close();
    await tester.pumpAndSettle();

    expect(find.text('Vault öffnen…'), findsOneWidget);
  });
}
