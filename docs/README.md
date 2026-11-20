# Code Explanations Index

This directory contains individual, beginner-friendly Markdown explanations for every active source-code file in the TypeStudio application.

Each file provides a concise description of the file's single responsibility, how it works with the rest of the application, and its key classes or functions.

---

## Root

- [main.dart](main.md): Serves as the main entry point that initializes the Flutter framework binding and starts the application.
- [app.dart](app.md): Constructs the top-level application shell, MaterialApp configuration, theme bindings, and persistent tab navigation.

## Config

- [google_fonts_config.dart](google_fonts_config.md): Maintains configuration constants and environment variable retrieval for the Google Fonts Developer API.

## Data

- [font_data.dart](font_data.md): Supplies a curated set of starter and offline fallback font models.

## Models

- [catalogue_entry.dart](catalogue_entry.md): Represents a lightweight font catalogue item with precomputed lowercase search keys.
- [font_face.dart](font_face.md): Models font variation axes and OpenType font file metadata parsed from binary font bytes.
- [font_model.dart](font_model.md): Encapsulates detailed metadata, available variants, download URLs, and category formatting for a font family.

## Screens

- [home_screen.dart](home_screen.md): Provides the editorial dashboard screen displaying hero animations, active font highlights, popular font shelves, and typography hierarchy ramps.
- [explore_screen.dart](explore_screen.md): Provides a searchable and filterable font explorer connecting directly to the Google Fonts API catalogue.
- [preview_screen.dart](preview_screen.md): Provides an interactive typography playground for testing custom copy against live typography controls.

## Services

- [catalogue_store.dart](catalogue_store.md): Defines the storage contract and implementations for caching font catalogue JSON payloads.
- [font_paginator.dart](font_paginator.md): Manages incremental client-side windowing and batch pagination over an in-memory font catalogue.
- [font_service.dart](font_service.md): Coordinates network discovery, binary font file downloading, OpenType axis inspection, dynamic FontLoader registration, and LRU byte caching.

## State

- [app_state.dart](app_state.md): Manages centralized application state for navigation, theme toggling, font selection, and preview typography settings.

## Theme

- [app_colors.dart](app_colors.md): Centralizes color tokens and monochromatic palettes for both light and dark modes.
- [app_theme.dart](app_theme.md): Configures Material 3 light and dark ThemeData for the entire application.

## Utils

- [font_weight_utils.dart](font_weight_utils.md): Provides utility functions for converting FontWeight enum values into human-readable typography labels.

## Widgets

- [error_banner.dart](error_banner.md): Displays a card informing the user when a network error occurs or an API key is missing.
- [explore_search_bar.dart](explore_search_bar.md): Renders an accessible search input field pinned to the top of the Explore screen.
- [fade_in_batch.dart](fade_in_batch.md): Animates newly appended list items with a gentle entrance fade transition.
- [floating_pill_navigation.dart](floating_pill_navigation.md): Renders a floating capsule bottom navigation bar with an animated active sliding indicator.
- [font_card.dart](font_card.md): Displays a single font family card inside the Explore screen catalogue list.
- [font_shelf_tile.dart](font_shelf_tile.md): Renders a compact horizontal tile highlighting a typeface on the Home screen font shelf.
- [font_text.dart](font_text.md): A universal typography text widget capable of rendering via dynamic FontLoader or bundled google_fonts.
- [offline_banner.dart](offline_banner.md): Informs the user when the application is browsing the bundled offline catalogue rather than the live API.
- [style_sample.dart](style_sample.md): Renders a single row representing a hierarchy level inside the Home screen typography ramp.
- [typography_controls_card.dart](typography_controls_card.md): Houses interactive typography controls for font size, weight, leading, tracking, and text alignment.

## Legacy / Sandbox

- [dartpad_main.dart](dartpad_main.md): Contains a self-contained, single-file edition of TypeStudio structured specifically for running inside the browser-based DartPad sandbox.
