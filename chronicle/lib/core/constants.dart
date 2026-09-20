// Datei: chronicle/lib/core/constants.dart
//
// ZWECK: App-weite Konstanten, die kein Theme-Token sind — Breakpoints und
//        Panel-Geometrie. Farben, Radien und Fonts gehören NICHT hierher,
//        sondern ins Theme-Layer (siehe Skill `chronicle-theme`).
//
// SCHRITT: 2

/// Ab dieser Breite gilt das Desktop-Layout (3 Panels).
///
/// Unterhalb rendert [ResponsiveShell] die Mobile-Variante mit Bottom-Nav.
/// Der Wert stammt aus MediaShelf und hat sich dort bewährt.
const double kDesktopBreakpoint = 900;

/// Ab dieser Breite ist zusätzlich Platz für das rechte Kontext-Panel.
///
/// Zwischen [kDesktopBreakpoint] und diesem Wert zeigen wir nur Baum und
/// Mitte — drei Spalten auf 1000 px machen alle drei unbenutzbar.
const double kContextPanelBreakpoint = 1280;

/// Startbreite des linken Navigations-Baums.
const double kLeftPanelWidth = 260;

/// Startbreite des rechten Kontext-Panels.
const double kRightPanelWidth = 320;

/// Höhe der oberen Leiste (fokussierter Track).
const double kTopBarHeight = 48;

/// Maximale Lesebreite im mittleren Panel.
///
/// Journal-Text über die volle Bildschirmbreite ist auf einem 27-Zoll-Monitor
/// unlesbar; der Editor bekommt deshalb eine Obergrenze.
const double kMaxReadingWidth = 760;

/// Die Version, die in Backup-Manifeste und ins Dev-Log geschrieben wird.
///
/// Doppelt gepflegt — hier und in `pubspec.yaml`. Die Alternative wäre
/// `package_info_plus`, ein Paket mit nativer Konfiguration auf fünf
/// Plattformen, nur um eine Zeichenkette zu lesen. Beim Anheben der Version
/// also beide Stellen ändern.
const String kAppVersion = '0.1.0';
