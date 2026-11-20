import 'package:material_ui/material_ui.dart';

/// Centralized color definitions for TypeStudio Light and Dark themes.
class AppColors {
  // Light Mode Palette
  static const charcoal = Color(0xFF292929);
  static const darkGray = Color(0xFF424242);
  static const background = Color(0xFFF4F4F4);
  static const surface = Color(0xFFFFFFFF);
  static const primaryText = Color(0xFF202020);
  static const secondaryText = Color(0xFF777777);
  static const border = Color(0xFFE0E0E0);

  // Dark Mode Palette
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkSecondarySurface = Color(0xFF292929);
  static const darkPrimaryText = Color(0xFFFFFFFF);
  static const darkSecondaryText = Color(0xFFB0B0B0);
  static const darkBorder = Color(0xFF383838);
  static const darkPrimaryAccent = Color(0xFFE0E0E0);

  // Shadow tokens
  static const shadowAmbientLight = Color(0x14000000); // 8% black
  static const shadowKeyLight = Color(0x22000000); // 13% black
  static const shadowAmbientDark = Color(0x52000000); // 32% black
  static const shadowKeyDark = Color(0x6E000000); // 43% black

  // Highlight/inset border token for glassmorphism surfaces
  static const glassHighlightLight = Color(0x33FFFFFF); // 20% white
  static const glassHighlightDark = Color(0x1FFFFFFF); // 12% white
}
