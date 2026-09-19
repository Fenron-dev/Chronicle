// Datei: chronicle/lib/app/routes.dart
//
// ZWECK: Alle Routen-Pfade an einer Stelle. Kein String-Literal im
//        Aufrufcode — ein Tippfehler in einem `context.go('/codx')` fällt
//        sonst erst zur Laufzeit auf.
//
// SCHRITT: 2

abstract final class Routes {
  /// Vault-Auswahl. Der Einstieg, solange kein Vault offen ist.
  static const String vaultPicker = '/vault';

  /// Play-Log der laufenden Partie — der Standard-Einstieg mit Vault.
  static const String play = '/play';

  /// Codex-/Wiki-Seiten.
  static const String codex = '/codex';

  /// System-Verwaltung inklusive Theme-Manager.
  static const String systems = '/systems';
}
