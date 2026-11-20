# app_state.dart

**Purpose:** Manages centralized application state for navigation, theme toggling, font selection, and preview typography settings.

**How it works:** Implements ChangeNotifier and exposes state through an InheritedNotifier scope so only relevant widgets rebuild when values change.

**Key components:** `AppState`, `PreviewState`, `AppStateProvider`, `selectFont`, `toggleTheme`
