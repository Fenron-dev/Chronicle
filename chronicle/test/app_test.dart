// Datei: chronicle/test/app_test.dart
//
// ZWECK: Rauchtest. Belegt, dass das CI-Gate tatsächlich Tests ausführt und
//        die App ohne Exception baut.
//
// SCHRITT: 1

import 'package:chronicle/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChronicleApp baut ohne Fehler', (tester) async {
    await tester.pumpWidget(const ChronicleApp());

    expect(find.text('Chronicle'), findsOneWidget);
  });
}
