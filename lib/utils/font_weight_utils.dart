import 'package:material_ui/material_ui.dart';

/// Maps a [FontWeight] to its short human-readable name (e.g. 'Thin', 'Bold').
String formatWeightName(FontWeight weight) {
  switch (weight) {
    case FontWeight.w100:
      return 'Thin';
    case FontWeight.w200:
      return 'Extra Light';
    case FontWeight.w300:
      return 'Light';
    case FontWeight.w400:
      return 'Regular';
    case FontWeight.w500:
      return 'Medium';
    case FontWeight.w600:
      return 'Semi Bold';
    case FontWeight.w700:
      return 'Bold';
    case FontWeight.w800:
      return 'Extra Bold';
    case FontWeight.w900:
      return 'Black';
    default:
      return 'Regular';
  }
}

/// Maps a [FontWeight] to a chip label with numeric value (e.g. 'Thin (100)', 'Bold (700)').
String formatWeightChip(FontWeight weight) {
  switch (weight) {
    case FontWeight.w100:
      return 'Thin (100)';
    case FontWeight.w200:
      return 'Extra Light (200)';
    case FontWeight.w300:
      return 'Light (300)';
    case FontWeight.w400:
      return 'Regular (400)';
    case FontWeight.w500:
      return 'Medium (500)';
    case FontWeight.w600:
      return 'Semi Bold (600)';
    case FontWeight.w700:
      return 'Bold (700)';
    case FontWeight.w800:
      return 'Extra Bold (800)';
    case FontWeight.w900:
      return 'Black (900)';
    default:
      return 'Regular';
  }
}
