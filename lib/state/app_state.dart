import 'package:material_ui/material_ui.dart';

import '../data/font_data.dart';
import '../models/font_model.dart';
import '../services/font_service.dart';

/// Application-level state: navigation, theme, and font selection.
///
/// Owns the cross-screen concerns that the old `_TypeStudioAppState` held
/// inline: tab index, dark-mode flag, and the currently selected font.
/// Screens read this via [AppState.of] and only the subtree that calls
/// [ListenableBuilder] on it rebuilds when a value changes.
class AppState extends ChangeNotifier {
  AppState() : _selectedFont = availableFonts.first;

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  int _selectedTab = 0;
  int get selectedTab => _selectedTab;
  set selectedTab(int value) {
    if (_selectedTab == value) return;
    _selectedTab = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Font selection
  // ---------------------------------------------------------------------------

  FontModel _selectedFont;
  FontModel get selectedFont => _selectedFont;

  /// Selects a font and navigates to the Preview tab.
  ///
  /// If the preview's current weight is not available in the new font, it falls
  /// back to w400 or the font's first weight. The font is pre-loaded via
  /// [FontService] so it is ready when the preview screen paints.
  void selectFont(FontModel font, {required PreviewState preview}) {
    _selectedFont = font;

    // Adjust the preview weight if needed.
    if (!font.weights.contains(preview.fontWeight)) {
      preview.fontWeight = font.weights.contains(FontWeight.w400)
          ? FontWeight.w400
          : (font.weights.isNotEmpty ? font.weights.first : FontWeight.w400);
    }

    _selectedTab = 2; // Jump to Preview
    notifyListeners();

    // Best-effort pre-load.
    FontService.instance
        .ensureFontLoaded(font.name, font: font)
        .then((_) => notifyListeners())
        .catchError((_) {});
  }

  // ---------------------------------------------------------------------------
  // InheritedWidget look-up
  // ---------------------------------------------------------------------------

  /// Retrieves the nearest [AppState] from the widget tree.
  static AppState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AppStateScope>()!
        .notifier!;
  }

  /// Like [of] but does not register a dependency; avoids unnecessary rebuilds
  /// when the caller only needs to call a method (e.g. `selectFont`).
  static AppState read(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_AppStateScope>()!
        .notifier!;
  }
}

/// Preview-screen state: font size, weight, alignment, and custom text.
///
/// Separated from [AppState] so that dragging the font-size slider only
/// rebuilds the preview, not every screen in the app. Text edits do not
/// notify this notifier: the field listens to [controller] directly, so
/// typing never rebuilds the controls card.
class PreviewState extends ChangeNotifier {
  static const double defaultFontSize = 32;
  static const double defaultLeading = 1.30;
  static const double defaultTracking = 0.00;
  static const String defaultText =
      'The quick brown fox jumps over the lazy dog.';

  final TextEditingController controller = TextEditingController(
    text: defaultText,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Font size
  // ---------------------------------------------------------------------------

  double _fontSize = defaultFontSize;
  double get fontSize => _fontSize;
  set fontSize(double value) {
    if (_fontSize == value) return;
    _fontSize = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Font weight
  // ---------------------------------------------------------------------------

  FontWeight _fontWeight = FontWeight.w400;
  FontWeight get fontWeight => _fontWeight;
  set fontWeight(FontWeight value) {
    if (_fontWeight == value) return;
    _fontWeight = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Text alignment
  // ---------------------------------------------------------------------------

  TextAlign _textAlign = TextAlign.left;
  TextAlign get textAlign => _textAlign;
  set textAlign(TextAlign value) {
    if (_textAlign == value) return;
    _textAlign = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Italic style
  // ---------------------------------------------------------------------------

  bool _isItalic = false;
  bool get isItalic => _isItalic;
  set isItalic(bool value) {
    if (_isItalic == value) return;
    _isItalic = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Leading (line height multiplier)
  // ---------------------------------------------------------------------------

  double _leading = defaultLeading;
  double get leading => _leading;
  set leading(double value) {
    if (_leading == value) return;
    _leading = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Tracking / Kerning Offset (in em units)
  // ---------------------------------------------------------------------------

  double _tracking = defaultTracking;
  double get tracking => _tracking;
  set tracking(double value) {
    if (_tracking == value) return;
    _tracking = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  void reset() {
    controller.text = defaultText;
    _fontSize = defaultFontSize;
    _fontWeight = FontWeight.w400;
    _textAlign = TextAlign.left;
    _isItalic = false;
    _leading = defaultLeading;
    _tracking = defaultTracking;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // InheritedWidget look-up
  // ---------------------------------------------------------------------------

  static PreviewState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PreviewStateScope>()!
        .notifier!;
  }

  static PreviewState read(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_PreviewStateScope>()!
        .notifier!;
  }
}

// =============================================================================
// InheritedNotifier wrappers: the DI mechanism
// =============================================================================

class _AppStateScope extends InheritedNotifier<AppState> {
  const _AppStateScope({required AppState notifier, required super.child})
      : super(notifier: notifier);
}

class _PreviewStateScope extends InheritedNotifier<PreviewState> {
  const _PreviewStateScope({required PreviewState notifier, required super.child})
      : super(notifier: notifier);
}

/// Provides [AppState] and [PreviewState] to the subtree.
///
/// Place this above `MaterialApp` so every screen can look up state via
/// `AppState.of(context)` / `PreviewState.of(context)`.
class AppStateProvider extends StatefulWidget {
  const AppStateProvider({super.key, required this.child});
  final Widget child;

  @override
  State<AppStateProvider> createState() => _AppStateProviderState();
}

class _AppStateProviderState extends State<AppStateProvider> {
  late final AppState _appState;
  late final PreviewState _previewState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _previewState = PreviewState();
  }

  @override
  void dispose() {
    _appState.dispose();
    _previewState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppStateScope(
      notifier: _appState,
      child: _PreviewStateScope(
        notifier: _previewState,
        child: widget.child,
      ),
    );
  }
}
