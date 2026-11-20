import 'package:material_ui/material_ui.dart';

import '../utils/font_weight_utils.dart';

/// Represents a font family in TypeStudio, supporting both built-in fonts
/// and live fonts retrieved from the Google Fonts Developer API.
class FontModel {
  const FontModel({
    required this.name,
    required this.category,
    required this.description,
    required this.weights,
    this.variants = const [],
    this.files = const {},
    this.subsets = const [],
    this.version = '',
    this.lastModified = '',
  });

  /// The font family name (e.g., 'Roboto', 'Playfair Display').
  final String name;

  /// The font category (e.g., 'Sans Serif', 'Serif', 'Display', 'Handwriting', 'Monospace').
  final String category;

  /// A brief human-readable description or note about the typeface.
  final String description;

  /// Available font weights for this typeface.
  final List<FontWeight> weights;

  /// Raw variant strings as returned by Google Fonts API (e.g., ['regular', 'italic', '700']).
  final List<String> variants;

  /// Map of variant key to font file download URL (e.g., {'regular': 'https://...'}).
  final Map<String, String> files;

  /// Supported character subsets (e.g., ['latin', 'cyrillic']).
  final List<String> subsets;

  /// Font version identifier from Google Fonts API.
  final String version;

  /// Last modification timestamp from Google Fonts API.
  final String lastModified;

  /// Human-readable label for available weights.
  String get weightsLabel {
    if (weights.isEmpty) {
      return 'Regular';
    }
    return weights.map(formatWeightName).toSet().join(', ');
  }

  /// Human-readable label for available variants (e.g. "12 variants: Regular, Bold...").
  String get variantsLabel {
    if (variants.isEmpty) {
      return weightsLabel;
    }
    final formatted = variants.map(_formatVariantName).take(6).join(', ');
    final suffix = variants.length > 6 ? ' +${variants.length - 6} more' : '';
    return '${variants.length} ${variants.length == 1 ? 'variant' : 'variants'} ($formatted$suffix)';
  }

  /// Returns the most suitable font file URL for a given weight and style.
  String? getFileUrl({FontWeight weight = FontWeight.w400, bool italic = false}) {
    if (files.isEmpty) {
      return null;
    }

    final targetNum = _weightToNumber(weight);
    final targetKey = italic ? '${targetNum}italic' : '$targetNum';
    if (files.containsKey(targetKey)) {
      return files[targetKey];
    }

    if (targetNum == 400) {
      if (italic && files.containsKey('italic')) {
        return files['italic'];
      }
      if (!italic && files.containsKey('regular')) {
        return files['regular'];
      }
    }

    // Try without italic
    if (files.containsKey('$targetNum')) {
      return files['$targetNum'];
    }

    // Fall back to regular or 400
    if (files.containsKey('regular')) {
      return files['regular'];
    }
    if (files.containsKey('400')) {
      return files['400'];
    }

    // Fall back to first available URL
    return files.values.firstOrNull;
  }

  /// The catalogue key used for a weight and italic combination.
  ///
  /// Google Fonts uses `regular`, `italic`, `700`, and `700italic`. A few
  /// hand-written entries use `400` and `400italic`, which are accepted by
  /// [exactFileUrl] and [hasExactFace].
  String variantKeyFor({required int weight, required bool italic}) {
    if (weight == 400) {
      return italic ? 'italic' : 'regular';
    }
    return italic ? '${weight}italic' : '$weight';
  }

  /// Returns the URL for exactly this face, or `null` when the family does not
  /// publish it.
  ///
  /// Unlike [getFileUrl], this never falls back to another weight or style, so
  /// callers can tell a genuine variant from a substitute.
  String? exactFileUrl({required int weight, required bool italic}) {
    final key = variantKeyFor(weight: weight, italic: italic);
    final url = files[key];
    if (url != null && url.isNotEmpty) {
      return url;
    }

    if (weight == 400) {
      final numericKey = italic ? '400italic' : '400';
      final numericUrl = files[numericKey];
      if (numericUrl != null && numericUrl.isNotEmpty) {
        return numericUrl;
      }
    }

    return null;
  }

  /// Whether the catalogue advertises exactly this weight and italic style.
  bool hasExactFace({required int weight, required bool italic}) {
    if (exactFileUrl(weight: weight, italic: italic) != null) {
      return true;
    }

    final key = variantKeyFor(weight: weight, italic: italic);
    if (variants.contains(key)) {
      return true;
    }

    if (weight == 400) {
      final numericKey = italic ? '400italic' : '400';
      return variants.contains(numericKey);
    }

    return false;
  }

  /// Whether the family publishes at least one italic face.
  bool get hasItalicFace {
    return variants.any(_variantIsItalic) || files.keys.any(_variantIsItalic);
  }

  /// The available weight closest to [target] for the requested style.
  ///
  /// Ties prefer the lighter weight. When the family publishes no face for the
  /// requested style, [target] is returned unchanged so callers can fall back
  /// to the regular face rather than pretending an italic file exists.
  int closestAvailableWeight(int target, {bool italic = false}) {
    final values = <int>{};

    for (final weight in weights) {
      values.add(weight.value);
    }

    for (final key in files.keys) {
      if (_variantIsItalic(key) == italic) {
        final value = _weightFromVariant(key);
        if (value != null) {
          values.add(value);
        }
      }
    }

    for (final variant in variants) {
      if (_variantIsItalic(variant) == italic) {
        final value = _weightFromVariant(variant);
        if (value != null) {
          values.add(value);
        }
      }
    }

    if (values.isEmpty) {
      return target;
    }

    var best = values.first;
    for (final value in values) {
      final bestDistance = (best - target).abs();
      final distance = (value - target).abs();
      if (distance < bestDistance ||
          (distance == bestDistance && value < best)) {
        best = value;
      }
    }
    return best;
  }

  /// Weight used as the initial face when a family is selected.
  int get baseWeight => closestAvailableWeight(400);

  static bool _variantIsItalic(String value) => value.contains('italic');

  static int? _weightFromVariant(String value) {
    final match = RegExp(r'^(\d{3})').stringMatch(value);
    if (match != null) {
      return int.parse(match);
    }
    if (value == 'regular' || value == 'italic') {
      return 400;
    }
    return null;
  }

  /// Parses a Google Fonts Developer API item into a [FontModel].
  factory FontModel.fromJson(Map<String, dynamic> json) {
    final family = json['family'] as String? ?? 'Unknown';
    final category = formatCategory(json['category'] as String? ?? 'sans-serif');
    final variantsList = (json['variants'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const ['regular'];

    final rawFiles = json['files'] as Map<String, dynamic>? ?? {};
    final filesMap = <String, String>{};
    for (final entry in rawFiles.entries) {
      var url = entry.value.toString();
      // Ensure HTTPS to prevent mixed-content blocks on web and secure connections on mobile
      if (url.startsWith('http://')) {
        url = 'https://${url.substring(7)}';
      }
      filesMap[entry.key] = url;
    }

    final parsedWeights = _parseWeights(variantsList);

    return FontModel(
      name: family,
      category: category,
      description: 'Google Fonts catalogue typeface with ${variantsList.length} ${variantsList.length == 1 ? 'variant' : 'variants'}.',
      weights: parsedWeights.isEmpty ? const [FontWeight.w400] : parsedWeights,
      variants: variantsList,
      files: filesMap,
      subsets: (json['subsets'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      version: json['version'] as String? ?? '',
      lastModified: json['lastModified'] as String? ?? '',
    );
  }

  static int _weightToNumber(FontWeight weight) {
    switch (weight) {
      case FontWeight.w100: return 100;
      case FontWeight.w200: return 200;
      case FontWeight.w300: return 300;
      case FontWeight.w400: return 400;
      case FontWeight.w500: return 500;
      case FontWeight.w600: return 600;
      case FontWeight.w700: return 700;
      case FontWeight.w800: return 800;
      case FontWeight.w900: return 900;
      default: return 400;
    }
  }

  static String _formatVariantName(String variant) {
    switch (variant) {
      case 'regular': return 'Regular';
      case 'italic': return 'Italic';
      case '100': return 'Thin';
      case '100italic': return 'Thin Italic';
      case '200': return 'Extra Light';
      case '200italic': return 'Extra Light Italic';
      case '300': return 'Light';
      case '300italic': return 'Light Italic';
      case '500': return 'Medium';
      case '500italic': return 'Medium Italic';
      case '600': return 'Semi Bold';
      case '600italic': return 'Semi Bold Italic';
      case '700': return 'Bold';
      case '700italic': return 'Bold Italic';
      case '800': return 'Extra Bold';
      case '800italic': return 'Extra Bold Italic';
      case '900': return 'Black';
      case '900italic': return 'Black Italic';
      default: return variant;
    }
  }

  static String formatCategory(String raw) {
    switch (raw.toLowerCase()) {
      case 'sans-serif': return 'Sans Serif';
      case 'serif': return 'Serif';
      case 'display': return 'Display';
      case 'handwriting': return 'Handwriting';
      case 'monospace': return 'Monospace';
      default:
        if (raw.isEmpty) {
          return 'Sans Serif';
        }
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  static List<FontWeight> _parseWeights(List<String> rawVariants) {
    final weightSet = <FontWeight>{};
    for (final v in rawVariants) {
      if (v.startsWith('100')) {
        weightSet.add(FontWeight.w100);
      } else if (v.startsWith('200')) {
        weightSet.add(FontWeight.w200);
      } else if (v.startsWith('300')) {
        weightSet.add(FontWeight.w300);
      } else if (v == 'regular' || v == 'italic' || v.startsWith('400')) {
        weightSet.add(FontWeight.w400);
      } else if (v.startsWith('500')) {
        weightSet.add(FontWeight.w500);
      } else if (v.startsWith('600')) {
        weightSet.add(FontWeight.w600);
      } else if (v.startsWith('700')) {
        weightSet.add(FontWeight.w700);
      } else if (v.startsWith('800')) {
        weightSet.add(FontWeight.w800);
      } else if (v.startsWith('900')) {
        weightSet.add(FontWeight.w900);
      }
    }
    final list = weightSet.toList()..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }
}
