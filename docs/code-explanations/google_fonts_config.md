# google_fonts_config.dart

**Purpose:** Maintains configuration constants and environment variable retrieval for the Google Fonts Developer API.

**How it works:** Reads the compile-time GOOGLE_FONTS_API_KEY definition and verifies whether a valid API key has been supplied before issuing web requests.

**Key components:** `FontApiConfig`, `apiKey`, `hasValidApiKey`, `apiBaseUrl`
