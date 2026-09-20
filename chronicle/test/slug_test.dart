// Datei: chronicle/test/slug_test.dart
//
// ZWECK: Ordnernamen aus Anzeigenamen. Reine Dart-Logik.
//
// WARUM WICHTIG: Der Slug wird zum Ordnernamen im Vault, und der Vault wandert
//        per USB-Stick zwischen Betriebssystemen. Ein Umlaut oder ein
//        Doppelpunkt im Ordnernamen überlebt das nicht zuverlässig.
//
// SCHRITT: 3c

import 'package:chronicle/domain/slug.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('slugify', () {
    test('schreibt deutsche Umlaute um', () {
      expect(slugify('Mörwald'), 'moerwald');
      expect(slugify('Über den Fluss'), 'ueber-den-fluss');
      expect(slugify('Straße'), 'strasse');
      expect(slugify('ÄÖÜ'), 'aeoeue');
    });

    test('ersetzt Sonderzeichen durch Bindestriche', () {
      expect(slugify('Ironsworn: Starforged'), 'ironsworn-starforged');
      expect(slugify('Blades / in the Dark'), 'blades-in-the-dark');
      expect(slugify('Mythic  GME   2e'), 'mythic-gme-2e');
    });

    test('lässt keine führenden oder folgenden Bindestriche stehen', () {
      expect(slugify('  Rand  '), 'rand');
      expect(slugify('—Kapitel—'), 'kapitel');
    });

    test('liefert einen brauchbaren Namen statt einer leeren Zeichenkette', () {
      // Ein leerer Ordnername wäre ein Fehler, den niemand versteht.
      expect(slugify(''), 'unbenannt');
      expect(slugify('———'), 'unbenannt');
      expect(slugify('   '), 'unbenannt');
    });

    test('erzeugt ausschließlich ASCII', () {
      final slug = slugify('Nebelmoor — Kapitel Ⅲ · 日本語');
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(slug), isTrue, reason: slug);
    });
  });

  group('uniqueSlug', () {
    test('gibt den Basis-Slug zurück, wenn er frei ist', () {
      expect(uniqueSlug('Mörwald', {}), 'moerwald');
    });

    test('zählt hoch, wenn der Name schon vergeben ist', () {
      // Zwei Systeme dürfen gleich heißen — zwei Ordner nicht.
      expect(uniqueSlug('Mörwald', {'moerwald'}), 'moerwald-2');
      expect(uniqueSlug('Mörwald', {'moerwald', 'moerwald-2'}), 'moerwald-3');
    });

    test('kollidiert nicht mit einem bereits nummerierten Namen', () {
      expect(uniqueSlug('Test', {'test', 'test-3'}), 'test-2');
    });
  });
}
