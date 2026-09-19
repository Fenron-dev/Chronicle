// Datei: chronicle/lib/app/router.dart
//
// ZWECK: go_router-Konfiguration mit Vault-Gate und StatefulShellRoute.
//
// WARUM StatefulShellRoute.indexedStack: Jeder Bereich behält seinen eigenen
//        Navigations-Stack. Ein Sprung vom Play-Log in den Codex und zurück
//        verliert die Scroll-Position nicht — bei einem Journaling-Tool, in
//        dem man ständig zwischen Schreiben und Nachschlagen wechselt, ist
//        das kein Detail.
//
// WARUM refreshListenable STATT NEUBAU: Würde der Provider bei jeder
//        Zustandsänderung einen neuen GoRouter liefern, ginge der komplette
//        Navigationsverlauf verloren. Stattdessen lebt EIN Router, dem ein
//        Listenable sagt, wann er seine Redirects neu auswerten soll.
//
// SCHRITT: 3

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/vault/vault_providers.dart';
import '../features/codex/codex_screen.dart';
import '../features/play_log/play_log_screen.dart';
import '../features/systems/systems_screen.dart';
import '../features/vault_picker/vault_picker_screen.dart';
import 'routes.dart';
import 'shell/responsive_shell.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter chronicleRouter(Ref ref) {
  final refresh = ValueNotifier<bool>(ref.read(hasOpenVaultProvider));
  ref.onDispose(refresh.dispose);
  ref.listen<bool>(hasOpenVaultProvider, (_, next) => refresh.value = next);

  return GoRouter(
    initialLocation: Routes.vaultPicker,
    refreshListenable: refresh,
    redirect: (context, state) {
      // Ohne offenen Vault gibt es nichts anzuzeigen — der Picker ist die
      // einzige sinnvolle Route.
      final hasVault = ref.read(hasOpenVaultProvider);
      final onPicker = state.matchedLocation == Routes.vaultPicker;

      if (!hasVault && !onPicker) return Routes.vaultPicker;
      if (hasVault && onPicker) return Routes.play;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.vaultPicker,
        builder: (context, state) => const VaultPickerScreen(),
      ),
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
}
