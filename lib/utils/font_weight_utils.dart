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
