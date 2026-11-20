# app.dart

**Purpose:** Constructs the top-level application shell, MaterialApp configuration, theme bindings, and persistent tab navigation.

**How it works:** Wraps the app with AppStateProvider and uses an IndexedStack to preserve screen state across Home, Explore, and Preview tabs while rendering a FloatingPillNavigation capsule.

**Key components:** `TypeStudioApp`, `_TypeStudioShell`
