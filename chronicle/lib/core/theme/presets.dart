// Datei: chronicle/lib/core/theme/presets.dart
//
// ZWECK: Registry der mitgelieferten Presets. Ein neues Preset wird hier
//        eingetragen, sonst findet der Theme-Manager es nicht.
//
// SCHRITT: 2

import 'presets/dossier.dart';
import 'presets/grimoire.dart';
import 'presets/nocturne.dart';
import 'presets/terminal.dart';
import 'theme_preset.dart';

export 'presets/dossier.dart';
export 'presets/grimoire.dart';
export 'presets/nocturne.dart';
export 'presets/terminal.dart';

/// Alle mitgelieferten Presets in Anzeigereihenfolge.
const List<ThemePreset> kThemePresets = [
  grimoirePreset,
  nocturnePreset,
  terminalPreset,
  dossierPreset,
];

/// Das Preset, das gilt, solange weder System noch Game etwas anderes sagen.
const ThemePreset kDefaultPreset = grimoirePreset;

/// Preset nach [id], oder [kDefaultPreset], wenn die id unbekannt ist.
///
/// Bewusst kein Wurf: ein Vault aus einer neueren Chronicle-Version kann ein
/// Preset nennen, das diese Version nicht kennt. Der Vault soll sich trotzdem
/// öffnen lassen (siehe Skill `chronicle-theme`).
ThemePreset presetById(String? id) {
  for (final preset in kThemePresets) {
    if (preset.id == id) return preset;
  }
  return kDefaultPreset;
}
