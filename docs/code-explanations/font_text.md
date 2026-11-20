# font_text.dart

**Purpose:** A universal typography text widget capable of rendering via dynamic FontLoader or bundled google_fonts.

**How it works:** Checks whether a font is already loaded, listens to asynchronous font file fetching via FutureBuilder, and falls back to system typography if fetching fails.

**Key components:** `FontText`, `_FontTextState`
