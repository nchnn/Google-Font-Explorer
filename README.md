# TypeStudio - Google Fonts Explorer & Discovery

A Flutter application for discovering, previewing, and experimenting with typography from the Google Fonts catalogue.

## Features

- **Live Google Fonts Discovery**: Connects directly to the Google Fonts Developer API to retrieve 1,500+ font families.
- **Searchable Font Explorer**: Real-time live search by font family name and category with clear action.
- **Rich Font Details**: Displays font family names, categories, and available font variants/weights on every font card.
- **Multi-Order Sorting**: Sort by popularity (default), alphabetical order (A–Z), or trending fonts.
- **Dual-Engine Font Loading**:
  - Uses `google_fonts: ^9.0.0` for bundled fonts.
  - Dynamically downloads and registers newly discovered fonts with Flutter's `FontLoader` when not bundled in `google_fonts`.
- **Immediate Live Preview**: Selected fonts apply immediately to sample text with interactive controls for font size (12–64px), weights, and alignment (left, center, right).
- **Warm-Start Persistence & In-Memory Caching**: Caches downloaded font bytes in a 64-entry LRU cache, and persists the last-used font catalogue in `SharedPreferencesCatalogueStore` for instant warm starts, paired with background revalidation.
- **Error Handling & Offline Resilience**: Loading indicators, empty search state, network/API error handling with Retry and fallback to bundled offline fonts.
- **Monochromatic Gray Aesthetic**: Preserves TypeStudio's minimalist, editorial layout and theme.

---

## Catalogue Paging

The Google Fonts Developer API has no `offset`/`limit` parameters. TypeStudio therefore downloads the catalogue **once per sort order** and caches it in memory; warm launches read the cached catalogue response directly from local storage (`SharedPreferencesCatalogueStore`) for instant presentation while revalidating fresh data in the background. The 5-family batches are client-side windowing over that cached list. Paging does not reduce the number of records downloaded from the API. Font files use a 64-entry LRU byte cache, and at most 3 font downloads run concurrently. On viewports taller than one batch, the list loads additional whole batches to fill the screen without auto-scrolling.

---

## Google Fonts Developer API Key Configuration

To enable live discovery of the full 1,500+ Google Fonts catalogue:

1. Obtain a free API key from the [Google Cloud Console](https://developers.google.com/fonts/docs/developer_api) with the **Web Fonts Developer API** enabled.
2. Provide your key in one of two ways:
   - **Option A (No code modification)**: Pass it at run time:
     ```bash
     flutter run --dart-define=GOOGLE_FONTS_API_KEY=your_api_key_here
     ```
   - **Option B (Configuration file)**: Edit `lib/config/google_fonts_config.dart` and update:
     ```dart
     static const String apiKey = 'your_actual_api_key_here';
     ```

*Note: If no API key is configured, TypeStudio automatically falls back to its bundled offline catalogue, allowing the app to remain completely functional without requiring end-users to enter an API key.*

---

## How to Run

### Regular Flutter Project
```bash
flutter pub get
flutter run
```

### DartPad Single-File Alternative
For running in [DartPad](https://dartpad.dev):
1. Open [`lib/dartpad_main.dart`](lib/dartpad_main.dart).
2. Copy the entire file content and paste it into DartPad (Flutter environment).
3. Set your API key in `FontApiConfig.apiKey` if you wish to query the live API in DartPad.

---

## DartPad Technical Limitations vs. Regular Flutter Project

| Capability | Regular Flutter Project | DartPad (Web Sandbox) |
| :--- | :--- | :--- |
| **Project Structure** | Modular multi-file architecture (`lib/screens`, `lib/models`, etc.) | Single-file only (`main.dart`) |
| **Compile-time flags** | `--dart-define=GOOGLE_FONTS_API_KEY=...` fully supported | Not supported; key must be hardcoded in file |
| **Network & CORS** | Native HTTP (no CORS restrictions on Mobile/Desktop) | Subject to browser CORS & iframe security policies |
| **Dynamic Font Loading** | Native engine `FontLoader` binary registration | `FontLoader` via CanvasKit / HTML renderer in web sandbox |
| **Disk Storage / Caching** | Local disk (`SharedPreferencesCatalogueStore`) and in-memory LRU byte caching | In-memory caching only (`MemoryCatalogueStore`; no persistent disk storage in sandbox) |

---

## Project Structure

```
lib/
├── config/
│   └── google_fonts_config.dart   # API key and endpoint configuration
├── data/
│   └── font_data.dart             # Bundled starter / offline fonts
├── models/
│   ├── catalogue_entry.dart       # Lightweight catalogue entry with lazy model parsing
│   └── font_model.dart            # Font metadata, JSON parser, and variant weighting
├── screens/
│   ├── explore_screen.dart        # Searchable explorer with live filtering and sorting
│   ├── home_screen.dart           # Hero overview, current font, and type hierarchy
│   └── preview_screen.dart        # Interactive typography tester & live controls
├── services/
│   ├── catalogue_store.dart       # Persistent & in-memory cache stores for catalogue JSON
│   ├── font_paginator.dart        # Generic incremental batching and client-side paging
│   └── font_service.dart          # API fetching, caching, and FontLoader dynamic loader
├── state/
│   └── app_state.dart             # Global application and preview state management
├── theme/
│   ├── app_colors.dart            # Monochromatic palette definitions
│   └── app_theme.dart             # Material 3 light theme configuration
├── utils/
│   └── font_weight_utils.dart     # Font weight name formatting helpers
├── widgets/
│   ├── error_banner.dart          # Error message display with retry and offline fallback
│   ├── explore_search_bar.dart    # Pinned search bar with keyboard shortcuts
│   ├── fade_in_batch.dart         # Staggered batch reveal animation wrapper
│   ├── floating_pill_navigation.dart # Floating capsule navigation bar
│   ├── font_card.dart             # Card showing family, category, variants & preview
│   ├── font_shelf_tile.dart       # Horizontal-scroll font showcase tile
│   ├── font_text.dart             # Universal text widget supporting google_fonts + FontLoader
│   ├── offline_banner.dart        # Offline indicator banner
│   ├── style_sample.dart          # Typography hierarchy sample row
│   └── typography_controls_card.dart # Precision slider and alignment controls
├── app.dart                       # Navigation and root shell
├── dartpad_main.dart              # Single-file runnable version for DartPad (standalone)
└── main.dart                      # App entry point
```
