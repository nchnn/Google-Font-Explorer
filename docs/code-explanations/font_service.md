# font_service.dart

**Purpose:** Coordinates network discovery, binary font file downloading, OpenType axis inspection, dynamic FontLoader registration, and LRU byte caching.

**How it works:** Fetches online font catalogues, deduplicates concurrent downloads, caches up to 64 font files in memory, and registers TTF files with the Flutter engine.

**Key components:** `FontService`, `fetchCatalogue`, `ensureFontLoaded`, `ensureFace`, `resolvePreviewFace`, `previewStyle`
