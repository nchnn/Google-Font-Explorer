/// Configuration for the Google Fonts Developer API in TypeStudio.
///
/// ============================================================================
/// DEVELOPER API KEY CONFIGURATION
/// ============================================================================
///
/// To enable live Google Fonts discovery from the full Google Fonts catalogue:
/// 1. Get a free Google Fonts API key from the Google Cloud Console:
///    https://developers.google.com/fonts/docs/developer_api
///
/// 2. Paste your API key into the [apiKey] constant below:
///    static const String apiKey = 'YOUR_ACTUAL_API_KEY';
///
/// 3. OR pass it at run time without modifying code:
///    flutter run --dart-define=GOOGLE_FONTS_API_KEY=your_key_here
///
/// If no API key is set, TypeStudio will gracefully fall back to the bundled
/// offline font catalogue with a non-blocking prompt explaining how to enable
/// live discovery.
class FontApiConfig {
  /// The Google Fonts Developer API key.
  ///
  /// Defaults to reading from the compile-time environment variable
  /// `GOOGLE_FONTS_API_KEY`. If not provided, you can replace the default value
  /// below with your API key.
  static const String apiKey = String.fromEnvironment(
    'GOOGLE_FONTS_API_KEY',
    defaultValue: 'AIzaSyA4hjNT12szf3Zc6IMlY4yq0vemlKVHeMI',
  );

 
  static bool get hasValidApiKey =>
      apiKey.isNotEmpty &&
      apiKey != 'YOUR_GOOGLE_FONTS_API_KEY_HERE' &&
      !apiKey.contains('YOUR_');

  /// Base URL for the Google Fonts Developer API.
  static const String apiBaseUrl =
      'https://www.googleapis.com/webfonts/v1/webfonts';
}
