// Datei: chronicle/lib/features/dev_log/dev_log_sheet.dart
//
// ZWECK: Das Dev-Log anzeigen, in die Zwischenablage kopieren und als Datei
//        speichern.
//
// WARUM ZWISCHENABLAGE ZUERST: Der häufigste Weg ist „kopieren und in den
//        Chat einfügen". Der Dateiweg ist für lange Sitzungen und für den
//        Fall, dass die Zwischenablage nicht reicht.
//
// SCHRITT: 4

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dev_log.dart';
import '../../core/theme/chronicle_skin.dart';
import '../../core/theme/theme_access.dart';

/// Öffnet das Dev-Log als Dialog.
Future<void> showDevLog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _DevLogDialog(),
  );
}

class _DevLogDialog extends StatefulWidget {
  const _DevLogDialog();

  @override
  State<_DevLogDialog> createState() => _DevLogDialogState();
}

class _DevLogDialogState extends State<_DevLogDialog> {
  /// Rückmeldung auf die letzte Aktion — ohne sie bleibt unklar, ob das
  /// Kopieren geklappt hat.
  String? _status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final skin = context.skin;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.typography.formatHeading('Dev-Log'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Enthält Pfade, Zähler und Fehler — keine Vault-Inhalte und '
                'keine API-Schlüssel.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.surfaceSunken,
                    borderRadius: skin.radius(RadiusToken.card),
                    border: Border.all(color: palette.border),
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: devLog.revision,
                    builder: (context, _, __) => Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          devLog.render(),
                          style: TextStyle(
                            fontFamily: context.typography.mono,
                            fontSize: 11,
                            height: 1.45,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  if (_status != null)
                    Expanded(
                      child: Text(
                        _status!,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.success),
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton(
                    onPressed: () {
                      devLog.clear();
                      setState(() => _status = 'Log geleert.');
                    },
                    child: const Text('Leeren'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _saveToFile,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Als Datei speichern…'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('In die Zwischenablage'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    final text = devLog.render();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _status = '${text.length} Zeichen kopiert.');
  }

  Future<void> _saveToFile() async {
    // Über die Ordner-Auswahl statt über einen Speichern-Dialog: dieselbe
    // API, die schon für den Vault benutzt wird, und damit dieselben
    // Sandbox-Rechte.
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Wohin soll das Log?',
    );
    if (dir == null) return;

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final path = '$dir/chronicle-devlog-$stamp.txt';

    try {
      await File(path).writeAsString(devLog.render());
      if (!mounted) return;
      setState(() => _status = 'Gespeichert: $path');
    } on FileSystemException catch (error) {
      devLog.error('ui', 'Log konnte nicht geschrieben werden', error: error);
      if (!mounted) return;
      setState(() => _status = 'Fehlgeschlagen: ${error.message}');
    }
  }
}
