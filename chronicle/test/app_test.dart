// Datei: chronicle/test/app_test.dart
//
// ZWECK: Die App-Shell von außen — Vault-Gate, Desktop-/Mobile-Umschaltung,
//        Theme-Anwendung.
//
// ZWEI REGELN FÜR WIDGET-TESTS IN DIESEM PROJEKT, teuer gelernt:
//
//   1. Echte Datei-I/O gehört in `tester.runAsync`. Der Rumpf von
//      `testWidgets` läuft in einer Fake-Async-Zone; ein Future, das auf die
//      Platte wartet, wird dort nie fertig.
//   2. Kein `pumpAndSettle`, solange ein unbestimmter Fortschrittsindikator
//      sichtbar sein kann. Der animiert endlos, also wird der Baum nie
//      „ruhig" — der Test lief zehn Minuten in den Timeout, statt zu
//      scheitern. Stattdessen eine feste Zahl `pump`-Durchläufe.
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
    // Die Index-Datenbank kann die Datei noch offen halten; ein
    // fehlgeschlagenes Aufräumen darf den Test nicht rot färben.
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Temp-Ordner, das Betriebssystem räumt ihn ohnehin ab.
    }
  });

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Pumpt eine feste Zahl Frames — der Ersatz für `pumpAndSettle`, wenn eine
  /// Endlos-Animation im Baum stehen kann.
  Future<void> pumpFrames(WidgetTester tester, {int count = 6}) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Baut die App auf einem Container, in dem der Vault bereits offen ist.
  Future<ProviderContainer> pumpWithOpenVault(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Vor dem Pumpen und in echter Async-Zone: hier wird wirklich ein Ordner
    // angelegt und ein Index gebaut.
    await tester.runAsync(() async {
      await container
          .read(activeVaultProvider.notifier)
          .createAndOpen(tempDir.path, 'Testvault');
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ChronicleApp(),
      ),
    );
    await pumpFrames(tester);
    return container;
  }

  testWidgets('startet ohne Vault im Picker', (tester) async {
    useSize(tester, const Size(1600, 1000));

    await tester.pumpWidget(const ProviderScope(child: ChronicleApp()));
    await pumpFrames(tester);

    expect(find.text('Vault öffnen…'), findsOneWidget);
    expect(find.text('Neuen Vault anlegen…'), findsOneWidget);
  });

  testWidgets('zeigt nach dem Öffnen das 3-Panel-Desktop-Layout', (
    tester,
  ) async {
    useSize(tester, const Size(1600, 1000));
    await pumpWithOpenVault(tester);

    // Das Gate hat umgeschaltet: Play-Log statt Picker.
    expect(find.text('Vault öffnen…'), findsNothing);

    // Ein frischer Vault hat noch keine Partie — das Play-Log sagt das und
    // verweist auf den Weg dorthin, statt leer zu bleiben.
    expect(find.textContaining('Systeme'), findsWidgets);

    // Grimoire ist das Default-Preset und setzt Überschriften in Versalien —
    // genau das ist die Aufgabe von ChronicleTypography.formatHeading.
    expect(find.text('KEINE PARTIE AKTIV'), findsOneWidget);

    // Der Vault-Name steht in der oberen Leiste.
    expect(find.text('Testvault'), findsOneWidget);
  });

  testWidgets('zeigt im schmalen Fenster die Bottom-Nav', (tester) async {
    useSize(tester, const Size(500, 900));
    await pumpWithOpenVault(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
