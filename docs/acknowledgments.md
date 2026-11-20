# Acknowledgments and External Resources

This document acknowledges all external packages, APIs, fonts, and tools utilized in TypeStudio.

---

## 1. External APIs

- **Google Fonts Developer API (Web Fonts API v1)**
  - **Source:** [https://developers.google.com/fonts/docs/developer_api](https://developers.google.com/fonts/docs/developer_api)
  - **Usage:** Provides metadata for 1,500+ font families, including family names, categories, available variants, subsets, and direct font file download URLs (`.ttf`).
  - **Endpoint:** `https://www.googleapis.com/webfonts/v1/webfonts`

---

## 2. Dependencies and Packages

- **Flutter SDK**
  - **Source:** [https://flutter.dev](https://flutter.dev)
  - **Usage:** Cross-platform UI toolkit, rendering engine, animation framework, and engine-level font loading (`FontLoader`).

- **material_ui**
  - **Source:** [https://pub.dev/packages/material_ui](https://pub.dev/packages/material_ui)
  - **Usage:** Material Design component library and theming framework for Flutter.

- **google_fonts (^9.0.0)**
  - **Source:** [https://pub.dev/packages/google_fonts](https://pub.dev/packages/google_fonts)
  - **Usage:** Provides fast loading and typography style definitions for popular bundled typefaces.

- **http (^1.2.0)**
  - **Source:** [https://pub.dev/packages/http](https://pub.dev/packages/http)
  - **Usage:** Performs asynchronous HTTP GET requests to fetch font catalogue metadata and binary font files (`.ttf`) from Google servers.

- **shared_preferences (^2.5.6)**
  - **Source:** [https://pub.dev/packages/shared_preferences](https://pub.dev/packages/shared_preferences)
  - **Usage:** Persists the last retrieved font catalogue response locally on disk to provide instant warm launches and offline availability.

- **flutter_test & flutter_lints**
  - **Source:** Flutter SDK and [https://pub.dev/packages/flutter_lints](https://pub.dev/packages/flutter_lints)
  - **Usage:** Automated unit and widget test runner and recommended Dart static analysis lint rules.

---

## 3. Bundled Fallback Fonts

The application includes twelve starter font families with static fallback TTF download references hosted on Google's official static CDN (`fonts.gstatic.com`):
1. **Roboto** (Google / Christian Robertson)
2. **Poppins** (Indian Type Foundry)
3. **Montserrat** (Julieta Ulanovsky)
4. **Open Sans** (Steve Matteson)
5. **Lato** (Lukasz Dziedzic)
6. **Nunito** (Vernon Adams)
7. **Raleway** (Matt McInerney)
8. **Oswald** (Vernon Adams)
9. **Merriweather** (Sorkin Type)
10. **Playfair Display** (Claus Eggers Sorensen)
11. **Inter** (Rasmus Andersson)
12. **Ubuntu** (Dalton Maag / Canonical)

---

## 4. Design and Architecture References

- **Material 3 Design Guidelines**
  - **Source:** [https://m3.material.io](https://m3.material.io)
  - **Usage:** Guided the monochromatic palette, high-contrast typography hierarchy, and accessible interactive touch targets.
- **OpenType Font File Specification**
  - **Source:** [https://learn.microsoft.com/en-us/typography/opentype/spec/fvar](https://learn.microsoft.com/en-us/typography/opentype/spec/fvar)
  - **Usage:** Guided the binary parser for the `fvar` (Font Variations) table in `FontFileAxes`.
