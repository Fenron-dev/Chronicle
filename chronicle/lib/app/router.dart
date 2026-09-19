// Datei: chronicle/lib/app/router.dart
//
// ZWECK: go_router-Konfiguration mit StatefulShellRoute.
//
// WARUM StatefulShellRoute.indexedStack: Jeder Bereich behält seinen eigenen
//        Navigations-Stack. Ein Sprung vom Play-Log in den Codex und zurück
//        verliert die Scroll-Position nicht — bei einem Journaling-Tool, in
//        dem man ständig zwischen Schreiben und Nachschlagen wechselt, ist
//        das kein Detail.
//
// STAND: Ab Schritt 3 kommt der Vault-Gate-Redirect dazu (kein Vault →
//        Vault-Picker). Solange es keine Vaults gibt, startet die App direkt
//        im Play-Log.
//
// SCHRITT: 2

import 'package:go_router/go_router.dart';

import '../features/codex/codex_screen.dart';
import '../features/play_log/play_log_screen.dart';
import '../features/systems/systems_screen.dart';
import 'routes.dart';
import 'shell/responsive_shell.dart';

/// Der Router der App.
///
/// Bewusst eine einfache Konstante statt eines Providers: in Schritt 2 hängt
/// die Routenstruktur von keinem Zustand ab. Sobald der Vault-Gate dazukommt,
/// wird daraus ein Provider, der `activeVaultProvider` beobachtet.
final GoRouter chronicleRouter = GoRouter(
  initialLocation: Routes.play,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ResponsiveShell(navigationShell: navigationShell),
      // Reihenfolge muss zu kShellDestinations passen.
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.play,
              builder: (context, state) => const PlayLogScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.codex,
              builder: (context, state) => const CodexScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.systems,
              builder: (context, state) => const SystemsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
