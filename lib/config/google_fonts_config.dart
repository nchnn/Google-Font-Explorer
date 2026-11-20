class FontApiConfig {

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
