// ignore_for_file: deprecated_member_use

// =============================================================================
// TypeStudio – Google Fonts Explorer & Discovery (Single-File DartPad Edition)
// =============================================================================
//
// DARTPAD USAGE INSTRUCTIONS:
// 1. Copy the entire contents of this file.
// 2. Open https://dartpad.dev (Flutter environment).
// 3. Ensure your pubspec.yaml has:
//      dependencies:
//        flutter:
//          sdk: flutter
//        google_fonts: ^6.2.0
//        http: ^1.2.0
// 4. Paste and run!
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TypeStudioApp());
}

// =============================================================================
// CONFIGURATION
// =============================================================================

class FontApiConfig {
  static const String apiKey = String.fromEnvironment(
    'GOOGLE_FONTS_API_KEY',
    defaultValue: 'AIzaSyA4hjNT12szf3Zc6IMlY4yq0vemlKVHeMI',
  );

  static bool get hasValidApiKey =>
      apiKey.isNotEmpty &&
      apiKey != 'YOUR_GOOGLE_FONTS_API_KEY_HERE' &&
      !apiKey.contains('YOUR_');

  static const String apiBaseUrl =
      'https://www.googleapis.com/webfonts/v1/webfonts';
}

// =============================================================================
// THEME & COLORS (Light & Dark Monochromatic Palettes)
// =============================================================================

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
}

class AppTheme {
  static ThemeData get lightTheme {
    final scheme = ColorScheme.light(
      primary: AppColors.charcoal,
      onPrimary: Colors.white,
      secondary: AppColors.darkGray,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.primaryText,
      onSurfaceVariant: AppColors.secondaryText,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.charcoal, width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.charcoal,
        thumbColor: AppColors.charcoal,
        inactiveTrackColor: AppColors.border,
        overlayColor: AppColors.charcoal.withValues(alpha: 0.12),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFE2E2E2);
            }
            return AppColors.surface;
          }),
          foregroundColor: WidgetStateProperty.all(AppColors.primaryText),
          side: WidgetStateProperty.all(const BorderSide(color: AppColors.border)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEBEBEB),
        selectedColor: const Color(0xFFD6D6D6),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.primaryText),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: const Color(0xFFE8E8E8),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.charcoal
                : AppColors.secondaryText,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.charcoal
                : AppColors.secondaryText,
          );
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.dark(
      primary: AppColors.darkPrimaryAccent,
      onPrimary: AppColors.darkBackground,
      secondary: AppColors.darkSecondaryText,
      onSecondary: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkPrimaryText,
      onSurfaceVariant: AppColors.darkSecondaryText,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      dividerColor: AppColors.darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkPrimaryText,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        hintStyle: const TextStyle(color: AppColors.darkSecondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkPrimaryAccent, width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.darkPrimaryAccent,
        thumbColor: AppColors.darkPrimaryAccent,
        inactiveTrackColor: AppColors.darkBorder,
        overlayColor: AppColors.darkPrimaryAccent.withValues(alpha: 0.12),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.darkSecondarySurface;
            }
            return AppColors.darkSurface;
          }),
          foregroundColor: WidgetStateProperty.all(AppColors.darkPrimaryText),
          side: WidgetStateProperty.all(const BorderSide(color: AppColors.darkBorder)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSecondarySurface,
        selectedColor: AppColors.darkBorder,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.darkPrimaryText),
        side: const BorderSide(color: AppColors.darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.darkSecondarySurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.darkPrimaryText
                : AppColors.darkSecondaryText,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.darkPrimaryText
                : AppColors.darkSecondaryText,
          );
        }),
      ),
    );
  }
}

// =============================================================================
// MODELS
// =============================================================================

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

  final String name;
  final String category;
  final String description;
  final List<FontWeight> weights;
  final List<String> variants;
  final Map<String, String> files;
  final List<String> subsets;
  final String version;
  final String lastModified;

  String get weightsLabel {
    if (weights.isEmpty) {
      return 'Regular';
    }
    return weights.map(_formatWeightName).toSet().join(', ');
  }

  String get variantsLabel {
    if (variants.isEmpty) {
      return weightsLabel;
    }
    final formatted = variants.map(_formatVariantName).take(5).join(', ');
    final suffix = variants.length > 5 ? ' +${variants.length - 5} more' : '';
    return '${variants.length} ${variants.length == 1 ? 'variant' : 'variants'} ($formatted$suffix)';
  }

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

    if (files.containsKey('$targetNum')) {
      return files['$targetNum'];
    }
    if (files.containsKey('regular')) {
      return files['regular'];
    }
    if (files.containsKey('400')) {
      return files['400'];
    }
    return files.values.firstOrNull;
  }

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
      if (url.startsWith('http://')) {
        url = 'https://${url.substring(7)}';
      }
      filesMap[entry.key] = url;
    }

    final parsedWeights = _parseWeights(variantsList);

    return FontModel(
      name: family,
      category: category,
      description: 'Google Fonts catalogue typeface with ${variantsList.length} variants.',
      weights: parsedWeights.isEmpty ? const [FontWeight.w400] : parsedWeights,
      variants: variantsList,
      files: filesMap,
      subsets: (json['subsets'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      version: json['version'] as String? ?? '',
      lastModified: json['lastModified'] as String? ?? '',
    );
  }

  static String _formatWeightName(FontWeight weight) {
    switch (weight) {
      case FontWeight.w100: return 'Thin';
      case FontWeight.w200: return 'Extra Light';
      case FontWeight.w300: return 'Light';
      case FontWeight.w400: return 'Regular';
      case FontWeight.w500: return 'Medium';
      case FontWeight.w600: return 'Semi Bold';
      case FontWeight.w700: return 'Bold';
      case FontWeight.w800: return 'Extra Bold';
      case FontWeight.w900: return 'Black';
      default: return 'Regular';
    }
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
      case '300': return 'Light';
      case '500': return 'Medium';
      case '700': return 'Bold';
      case '900': return 'Black';
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

class CatalogueEntry {
  CatalogueEntry.fromJson(Map<String, dynamic> json)
      : name = json['family'] as String? ?? 'Unknown',
        category = FontModel.formatCategory(
          json['category'] as String? ?? 'sans-serif',
        ),
        searchName = (json['family'] as String? ?? 'Unknown').toLowerCase(),
        searchCategory = FontModel.formatCategory(
          json['category'] as String? ?? 'sans-serif',
        ).toLowerCase(),
        raw = json,
        _providedModel = null;

  CatalogueEntry.fromModel(FontModel model)
      : name = model.name,
        category = model.category,
        searchName = model.name.toLowerCase(),
        searchCategory = model.category.toLowerCase(),
        raw = null,
        _providedModel = model;

  final String name;
  final String category;
  final String searchName;
  final String searchCategory;
  final Map<String, dynamic>? raw;
  final FontModel? _providedModel;

  bool get hasFileUrl {
    if (_providedModel != null) {
      return true;
    }
    final files = raw?['files'];
    return files is Map && files.isNotEmpty;
  }

  late final FontModel model = _providedModel ?? FontModel.fromJson(raw!);
}

class FontCatalogue {
  const FontCatalogue({
    required this.entries,
    required this.rawBody,
    this.isFromCache = false,
  });

  final List<CatalogueEntry> entries;
  final String rawBody;
  final bool isFromCache;
}

abstract class CatalogueStore {
  Future<String?> read(FontSortOrder sort);
  Future<void> write(FontSortOrder sort, String body);
  Future<void> clear();
}

class MemoryCatalogueStore implements CatalogueStore {
  final Map<FontSortOrder, String> _store = {};

  @override
  Future<String?> read(FontSortOrder sort) async => _store[sort];

  @override
  Future<void> write(FontSortOrder sort, String body) async {
    _store.clear();
    _store[sort] = body;
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}

// =============================================================================
// DATA (Bundled Offline Catalogue)
// =============================================================================

const commonWeights = <FontWeight>[
  FontWeight.w300,
  FontWeight.w400,
  FontWeight.w500,
  FontWeight.w600,
  FontWeight.w700,
];

const standardVariants = <String>['300', 'regular', '500', '600', '700'];

const availableFonts = <FontModel>[
  FontModel(
    name: 'Roboto',
    category: 'Sans Serif',
    description: 'A clean and versatile everyday typeface.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Mu4mxKKTU1Kg.ttf',
      '700': 'https://fonts.gstatic.com/s/roboto/v30/KFOlCnqEu92Fr1MmWUlfBBc4AMP6lQ.ttf',
    },
  ),
  FontModel(
    name: 'Poppins',
    category: 'Geometric Sans',
    description: 'Rounded geometric shapes with a modern feel.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/poppins/v20/pxiEyp8kv8JHgFVrFJA.ttf',
    },
  ),
  FontModel(
    name: 'Montserrat',
    category: 'Geometric Sans',
    description: 'Strong, contemporary lettering for headlines and UI.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/montserrat/v25/JTUSjIg1_i6t8kCHKm459Wlhyw.ttf',
    },
  ),
  FontModel(
    name: 'Open Sans',
    category: 'Humanist Sans',
    description: 'Friendly and highly readable at many sizes.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/opensans/v34/memSYaGs126MiZpBA-UvWbX2vVnXBbObj2OVZyOOSr4dVJWUgsjZ0B4gaVQUwaEQbjA.ttf',
    },
  ),
  FontModel(
    name: 'Lato',
    category: 'Sans Serif',
    description: 'Warm, balanced, and comfortable for long reading.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/lato/v24/S6uyw4BMUTPHjx4wXiWtFCc.ttf',
    },
  ),
  FontModel(
    name: 'Nunito',
    category: 'Rounded Sans',
    description: 'Soft rounded terminals and approachable character.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/nunito/v25/XRXI3I6Li01BKofiOc5wtlZ2di8HDLshdTQ3jw.ttf',
    },
  ),
  FontModel(
    name: 'Raleway',
    category: 'Sans Serif',
    description: 'An elegant family with distinctive letterforms.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/raleway/v28/1Ptxg8zYS_SKggPN4iEgvnHyvveLxVvaorCFPrcVIT9d0c8.ttf',
    },
  ),
  FontModel(
    name: 'Oswald',
    category: 'Condensed Sans',
    description: 'A compact display style for bold statements.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/oswald/v49/TK3_WkUHHAIjg75cFRf3bXL8LICs13FvgUFoZAaRliE.ttf',
    },
  ),
  FontModel(
    name: 'Merriweather',
    category: 'Serif',
    description: 'A sturdy serif designed for comfortable reading.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/merriweather/v30/u-440qyYrRw-PfUBy7mq9HNfc4-lldUb.ttf',
    },
  ),
  FontModel(
    name: 'Playfair Display',
    category: 'Display Serif',
    description: 'High contrast and editorial-inspired elegance.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/playfairdisplay/v30/nuFvD-vYSZviVYUb_rj3ij__anPXJzDwcbmjWBN2PKdFvXDXbtM.ttf',
    },
  ),
  FontModel(
    name: 'Inter',
    category: 'Sans Serif',
    description: 'A practical interface typeface with clear shapes.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/inter/v12/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hjp-Ek-_EeA.ttf',
    },
  ),
  FontModel(
    name: 'Ubuntu',
    category: 'Humanist Sans',
    description: 'Distinctive, friendly, and open letterforms.',
    weights: commonWeights,
    variants: standardVariants,
    files: {
      'regular': 'https://fonts.gstatic.com/s/ubuntu/v20/4iCs6KVjbNBYlgoKcg72nU6AF7xm.ttf',
    },
  ),
];

// =============================================================================
// SERVICES (API Discovery, Dynamic FontLoader, Limiter & Caching)
// =============================================================================

enum FontSortOrder {
  popularity('popularity', 'Popular'),
  alphabetical('alpha', 'A–Z'),
  trending('trending', 'Trending');

  const FontSortOrder(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// Widget-free pagination cursor over an already-fetched font catalogue.
///
/// The catalogue itself is downloaded once (the Google Fonts `webfonts/v1`
/// endpoint has no pagination parameters); this class only reveals a growing
/// prefix of that in-memory list, [defaultPageSize] families at a time, so the
/// Explore screen can append batches without ever re-fetching or discarding
/// already-loaded families.
///
/// It owns no timers, performs no I/O, and imports no widgets, which keeps it
/// directly unit-testable.
class FontPaginator<T> {
  FontPaginator({
    required this.idOf,
    this.pageSize = defaultPageSize,
  }) : assert(pageSize > 0, 'pageSize must be greater than zero');

  /// Identifier extractor used for de-duplicating items.
  final String Function(T) idOf;

  /// Number of families revealed per batch.
  static const int defaultPageSize = 5;

  /// Number of families revealed per batch by this instance.
  final int pageSize;

  List<T> _items = const [];

  int _visibleCount = 0;

  /// Bumped on every [reset]; lets a suspended [loadNextPage] detect that the
  /// source it started against has been replaced and abandon its batch.
  int _generation = 0;

  /// Unmodifiable view of the currently revealed families, in source order.
  List<T> get visibleItems =>
      List<T>.unmodifiable(_items.sublist(0, _visibleCount));

  /// Number of de-duplicated families in the current source list.
  int get totalCount => _items.length;

  /// Number of families currently revealed.
  int get visibleCount => _visibleCount;

  /// Whether any families are still hidden.
  bool get hasMore => _visibleCount < _items.length;

  /// Whether the current source list is empty.
  bool get isEmpty => _items.isEmpty;

  /// Replaces the source list, de-duplicates it by [idOf]
  /// (case-insensitive, first occurrence wins), and rewinds to the first page.
  void reset(Iterable<T> items) {
    final seenNames = <String>{};
    final uniqueItems = <T>[];
    for (final item in items) {
      if (seenNames.add(idOf(item).toLowerCase())) {
        uniqueItems.add(item);
      }
    }
    _items = List<T>.unmodifiable(uniqueItems);
    _visibleCount = math.min(pageSize, _items.length);
    _generation++;
  }

  /// Reveals the next batch and returns only the newly revealed slice.
  Future<List<T>> loadNextPage() async {
    if (!hasMore) {
      throw StateError('No more font families to load');
    }

    final generation = _generation;

    await Future<void>.delayed(Duration.zero);

    if (generation != _generation) {
      return const [];
    }

    // Clamp the start in case the source was reset while this call yielded.
    final start = math.min(_visibleCount, _items.length);
    _visibleCount = math.min(start + pageSize, _items.length);
    return List<T>.unmodifiable(_items.sublist(start, _visibleCount));
  }
}

class FontService {
  FontService._internal() {
    for (final font in availableFonts) {
      final entry = CatalogueEntry.fromModel(font);
      _bundledRegistry[font.name] = entry;
      _entryRegistry[font.name] = entry;
    }
  }

  static final FontService instance = FontService._internal();

  /// Maximum number of downloaded font files kept in the byte cache.
  static const int fontFileCacheLimit = 64;

  final Map<String, Uint8List> _downloadCache = {};

  int get cachedFontFileCount => _downloadCache.length;

  final Set<String> _loadedFamilies = {};
  final Map<String, CatalogueEntry> _entryRegistry = {};
  final Map<String, CatalogueEntry> _bundledRegistry = {};
  final Map<FontSortOrder, FontCatalogue> _catalogueCache = {};
  final Map<String, Future<void>> _activeFontLoads = {};
  final Set<String> _inFlightPrefetches = {};
  final Map<String, Future<void>> _previewFutures = {};

  int _activeHttpDownloads = 0;
  final List<Completer<void>> _downloadQueue = [];

  Future<void> _acquireDownloadSlot() async {
    if (_activeHttpDownloads < 3) {
      _activeHttpDownloads++;
      return;
    }
    final completer = Completer<void>();
    _downloadQueue.add(completer);
    await completer.future;
  }

  void _releaseDownloadSlot() {
    if (_downloadQueue.isNotEmpty) {
      final next = _downloadQueue.removeAt(0);
      next.complete();
    } else {
      _activeHttpDownloads--;
    }
  }

  void _putFontBytes(String url, Uint8List bytes) {
    _downloadCache.remove(url);
    _downloadCache[url] = bytes;
    while (_downloadCache.length > fontFileCacheLimit) {
      _downloadCache.remove(_downloadCache.keys.first);
    }
  }

  Uint8List? _cachedFontBytes(String url) {
    final bytes = _downloadCache.remove(url);
    if (bytes == null) {
      return null;
    }
    _downloadCache[url] = bytes;
    return bytes;
  }

  static bool isGoogleFontsSupported(String familyName) {
    return GoogleFonts.asMap().containsKey(familyName);
  }

  bool isFontLoaded(String familyName) => _loadedFamilies.contains(familyName);

  FontModel? getFont(String familyName) => _entryRegistry[familyName]?.model;

  CatalogueEntry? getEntry(String familyName) => _entryRegistry[familyName];

  void registerFonts(Iterable<FontModel> fonts) {
    for (final font in fonts) {
      _entryRegistry[font.name] = CatalogueEntry.fromModel(font);
    }
  }

  void registerEntries(Iterable<CatalogueEntry> entries) {
    for (final entry in entries) {
      _entryRegistry[entry.name] = entry;
    }
  }

  void clearCache() {
    _downloadCache.clear();
    _loadedFamilies.clear();
    _catalogueCache.clear();
    _activeFontLoads.clear();
    _previewFutures.clear();
    _inFlightPrefetches.clear();
    _entryRegistry.clear();
    _entryRegistry.addAll(_bundledRegistry);
  }

  Future<FontCatalogue> fetchCatalogue({
    FontSortOrder sort = FontSortOrder.popularity,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _catalogueCache.containsKey(sort)) {
      return _catalogueCache[sort]!;
    }

    if (!FontApiConfig.hasValidApiKey) {
      throw const FontApiException(
        'Google Fonts Developer API key is not configured. '
        'Set your API key in FontApiConfig.apiKey or use the bundled offline catalogue.',
        isMissingApiKey: true,
      );
    }

    final uri = Uri.parse(
      '${FontApiConfig.apiBaseUrl}?key=${FontApiConfig.apiKey}&sort=${sort.apiValue}',
    );

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const FontApiException(
          'Connection timed out reaching Google Fonts API.',
        ),
      );

      if (response.statusCode == 200) {
        // Paint-first decode path for web sandbox
        await Future<void>.delayed(Duration.zero);
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        final entries = items.map((item) {
          if (item is Map<String, dynamic>) {
            return CatalogueEntry.fromJson(item);
          }
          return CatalogueEntry.fromJson((item as Map).cast<String, dynamic>());
        }).toList();

        registerEntries(entries);
        final catalogue = FontCatalogue(
          entries: entries,
          rawBody: response.body,
          isFromCache: false,
        );
        _catalogueCache[sort] = catalogue;
        return catalogue;
      } else if (response.statusCode == 400 || response.statusCode == 403) {
        throw FontApiException(
          'Google Fonts API authentication failed (${response.statusCode}). Check your API key.',
          statusCode: response.statusCode,
          isMissingApiKey: true,
        );
      } else {
        throw FontApiException(
          'Failed to retrieve font catalogue (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    } on FontApiException {
      rethrow;
    } catch (e) {
      throw FontApiException(
        'Network error connecting to Google Fonts API: $e. Please verify internet connection.',
      );
    }
  }

  Future<void> ensureFontLoaded(
    String familyName, {
    FontModel? font,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
  }) async {
    final targetFont = font ?? getFont(familyName);
    final fileUrl = targetFont?.getFileUrl(weight: weight, italic: italic);

    if (fileUrl != null && fileUrl.isNotEmpty) {
      if (_loadedFamilies.contains(familyName)) {
        return;
      }

      if (_activeFontLoads.containsKey(familyName)) {
        return _activeFontLoads[familyName]!;
      }

      final loadFuture = _loadCustomFont(
        familyName,
        fileUrl: fileUrl,
      );

      _activeFontLoads[familyName] = loadFuture;

      try {
        await loadFuture;
      } finally {
        _activeFontLoads.remove(familyName);
      }
      return;
    }

    if (isGoogleFontsSupported(familyName)) {
      try {
        GoogleFonts.getFont(familyName);
        await GoogleFonts.pendingFonts();
        return;
      } catch (_) {}
    }

    throw FontApiException('No font file URL available for "$familyName".');
  }

  Future<void> previewFont(String familyName, {FontModel? font}) {
    return _previewFutures.putIfAbsent(familyName, () {
      final future = ensureFontLoaded(
        familyName,
        font: font,
        weight: FontWeight.w400,
      );
      future.catchError((Object _, StackTrace _) {
        if (identical(_previewFutures[familyName], future)) {
          _previewFutures.remove(familyName);
        }
      });
      return future;
    });
  }

  Future<void> prefetchPreviewBytes(FontModel model) async {
    final fileUrl = model.getFileUrl(weight: FontWeight.w400, italic: false);
    if (fileUrl == null || fileUrl.isEmpty) {
      return;
    }

    final secureUrl = fileUrl.startsWith('http://')
        ? 'https://${fileUrl.substring(7)}'
        : fileUrl;

    if (_cachedFontBytes(secureUrl) != null) {
      return;
    }

    if (!_inFlightPrefetches.add(secureUrl)) {
      return;
    }

    try {
      await _acquireDownloadSlot();
      try {
        if (_cachedFontBytes(secureUrl) != null) {
          return;
        }
        final response = await http.get(Uri.parse(secureUrl)).timeout(
          const Duration(seconds: 20),
        );
        if (response.statusCode == 200) {
          _putFontBytes(secureUrl, response.bodyBytes);
        }
      } finally {
        _releaseDownloadSlot();
      }
    } catch (_) {
    } finally {
      _inFlightPrefetches.remove(secureUrl);
    }
  }

  Future<void> _loadCustomFont(
    String familyName, {
    required String fileUrl,
  }) async {
    final secureUrl = fileUrl.startsWith('http://')
        ? 'https://${fileUrl.substring(7)}'
        : fileUrl;

    Uint8List fontBytes;

    final cachedBytes = _cachedFontBytes(secureUrl);
    if (cachedBytes != null) {
      fontBytes = cachedBytes;
    } else {
      await _acquireDownloadSlot();
      try {
        final racedBytes = _cachedFontBytes(secureUrl);
        if (racedBytes != null) {
          fontBytes = racedBytes;
        } else {
          final response = await http.get(Uri.parse(secureUrl)).timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw FontApiException('Font download timed out for "$familyName".'),
          );

          if (response.statusCode != 200) {
            throw FontApiException('Failed to download font file for "$familyName".');
          }

          fontBytes = response.bodyBytes;
          _putFontBytes(secureUrl, fontBytes);
        }
      } finally {
        _releaseDownloadSlot();
      }
    }

    final fontLoader = FontLoader(familyName);
    fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
    await fontLoader.load();

    _loadedFamilies.add(familyName);
  }
}

class FontApiException implements Exception {
  const FontApiException(
    this.message, {
    this.statusCode,
    this.isMissingApiKey = false,
  });

  final String message;
  final int? statusCode;
  final bool isMissingApiKey;

  @override
  String toString() => message;
}

// =============================================================================
// WIDGETS
// =============================================================================

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class FontText extends StatefulWidget {
  const FontText({
    super.key,
    required this.fontFamily,
    required this.text,
    this.style = const TextStyle(fontSize: 20),
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.showErrorNotice = true,
  });

  final String fontFamily;
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int? maxLines;
  final bool showErrorNotice;

  @override
  State<FontText> createState() => _FontTextState();
}

class _FontTextState extends State<FontText> {
  int _retryKey = 0;
  Future<void>? _pending;
  String? _pendingKey;

  Future<void> _pendingFor(String family) {
    final key = '$family|$_retryKey';
    if (_pendingKey != key) {
      _pendingKey = key;
      _pending = FontService.instance.previewFont(family);
    }
    return _pending!;
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.fontFamily;
    final theme = Theme.of(context);

    if (FontService.instance.isFontLoaded(family)) {
      return Text(
        widget.text,
        style: widget.style.copyWith(fontFamily: family),
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
      );
    }

    final entry = FontService.instance.getEntry(family);
    final hasFileUrl = entry?.hasFileUrl ?? false;
    final isGoogleFonts = FontService.isGoogleFontsSupported(family);

    if (hasFileUrl) {
      return FutureBuilder<void>(
        key: ValueKey('fl-$family-$_retryKey'),
        future: _pendingFor(family),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildFallback(
              context,
              errorMessage:
                  'Font "$family" could not be loaded dynamically. Showing system font.',
              canRetry: true,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Text(
              widget.text,
              style: widget.style.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
            );
          }

          return Text(
            widget.text,
            style: widget.style.copyWith(fontFamily: family),
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
          );
        },
      );
    }

    if (isGoogleFonts) {
      try {
        final googleStyle =
            GoogleFonts.getFont(family, textStyle: widget.style);
        return FutureBuilder<void>(
          key: ValueKey('gf-$family-$_retryKey'),
          future: _pendingFor(family),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildFallback(
                context,
                errorMessage:
                    'Google Font "$family" could not be loaded. Showing system font.',
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text(
                widget.text,
                style: widget.style.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
                textAlign: widget.textAlign,
                maxLines: widget.maxLines,
              );
            }

            return Text(
              widget.text,
              style: googleStyle,
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
            );
          },
        );
      } catch (_) {}
    }

    return _buildFallback(
      context,
      errorMessage: 'Font "$family" is not available. Showing system font.',
    );
  }

  Widget _buildFallback(
    BuildContext context, {
    required String errorMessage,
    bool canRetry = false,
  }) {
    if (!widget.showErrorNotice) {
      return Text(widget.text, style: widget.style, textAlign: widget.textAlign, maxLines: widget.maxLines);
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.text, style: widget.style, textAlign: widget.textAlign, maxLines: widget.maxLines),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(child: Text(errorMessage, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant))),
            if (canRetry) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _retryKey++),
                child: Text('Retry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.primary, decoration: TextDecoration.underline)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class FontCard extends StatelessWidget {
  const FontCard({
    super.key,
    required this.font,
    required this.isSelected,
    required this.onTap,
  });

  final FontModel font;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      font.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20)
                  else
                    Icon(
                      Icons.circle_outlined,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFEBEBEB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      font.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      font.variantsLabel,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FontText(
                fontFamily: font.name,
                text: 'Typography that speaks.',
                style: TextStyle(
                  fontSize: 22,
                  // List previews always show the regular weight; requesting
                  // anything heavier would download an extra variant per card.
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                showErrorNotice: false,
              ),
              const SizedBox(height: 8),
              Text(
                font.description,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SCREENS
// =============================================================================

/// Fades a card into view when it belongs to a newly appended list batch.
///
/// The Explore screen reveals the catalogue a batch at a time. Existing cards
/// must not replay their entrance animation when the list rebuilds, so the
/// screen hands every card [fadeFrom] — the index where the most recently
/// appended batch starts. The boundary is captured when the card is created,
/// not re-evaluated on rebuild: a card that started fading keeps its
/// `FadeTransition` even if a later batch moves [fadeFrom] past it. Cards
/// created before the boundary (and every card when the platform asks for
/// reduced motion) render their [child] untouched.
///
/// The animation runs once per [State], so an ordinary rebuild of an already
/// faded card leaves it fully opaque. Reduced motion is read in [build] rather
/// than here, because the ambient [MediaQuery] can change while the widget is
/// alive.
class FadeInBatch extends StatefulWidget {
  const FadeInBatch({
    super.key,
    required this.index,
    required this.fadeFrom,
    required this.child,
  });

  /// Position of this card in the revealed list.
  final int index;

  /// Index at which the most recently appended batch starts.
  ///
  /// Cards with `index >= fadeFrom` animate; earlier cards do not.
  final int fadeFrom;

  /// The card to fade in.
  final Widget child;

  /// How long a newly appended card takes to reach full opacity.
  static const Duration duration = Duration(milliseconds: 220);

  @override
  State<FadeInBatch> createState() => _FadeInBatchState();
}

class _FadeInBatchState extends State<FadeInBatch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _opacity;
  late final bool _animates;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: FadeInBatch.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _animates = widget.index >= widget.fadeFrom;
    if (_animates) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    // The curve listens to the controller, so it is torn down first.
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      !_animates || MediaQuery.disableAnimationsOf(context)
          ? widget.child
          : FadeTransition(opacity: _opacity, child: widget.child);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.selectedFont,
    required this.onExplore,
    required this.onPreview,
    required this.onSelectFont,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final FontModel selectedFont;
  final VoidCallback onExplore;
  final VoidCallback onPreview;
  final ValueChanged<FontModel> onSelectFont;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondarySurface : AppColors.charcoal,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: const Icon(Icons.text_fields_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TypeStudio',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'GOOGLE FONTS EXPLORER',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Theme Switcher Button (Requirement 4)
                  IconButton(
                    onPressed: onToggleTheme,
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    icon: Icon(
                      isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      color: theme.colorScheme.onSurface,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text('Make every word', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.1, color: theme.colorScheme.onSurface)),
              Text('feel different.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, height: 1.1, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 12),
              Text(
                'Explore typefaces, test your own text, and discover the right typography for every idea.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onExplore,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explore fonts'),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimaryAccent : AppColors.charcoal,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeading(title: 'Your current font', subtitle: 'Selected typeface preview'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedFont.name,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: theme.colorScheme.onSurface),
                            ),
                          ),
                          Icon(Icons.check_circle, size: 19, color: theme.colorScheme.primary),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FontText(
                        fontFamily: selectedFont.name,
                        text: 'Aa Bb Cc 123',
                        style: TextStyle(fontSize: 38, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      Text(selectedFont.description, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: onPreview,
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Customize preview'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeading(
                title: 'Popular typefaces',
                subtitle: 'A few styles to get you started',
                trailing: TextButton(onPressed: onExplore, child: const Text('See all')),
              ),
              const SizedBox(height: 12),
              ...availableFonts.take(3).map(
                (font) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FontCard(
                    font: font,
                    isSelected: selectedFont.name == font.name,
                    onTap: () => onSelectFont(font),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const SectionHeading(title: 'Typography styles', subtitle: 'One family, many levels of hierarchy'),
              const SizedBox(height: 12),
              _StyleSample(font: selectedFont.name, label: 'Display', size: 34, weight: FontWeight.w700),
              _StyleSample(font: selectedFont.name, label: 'Heading 1', size: 28, weight: FontWeight.w700),
              _StyleSample(font: selectedFont.name, label: 'Heading 2', size: 23, weight: FontWeight.w600),
              _StyleSample(font: selectedFont.name, label: 'Heading 3', size: 19, weight: FontWeight.w600),
              _StyleSample(font: selectedFont.name, label: 'Subtitle', size: 16, weight: FontWeight.w500),
              _StyleSample(font: selectedFont.name, label: 'Body text', size: 14, weight: FontWeight.w400),
              _StyleSample(font: selectedFont.name, label: 'Caption', size: 12, weight: FontWeight.w400),
              _StyleSample(font: selectedFont.name, label: 'Bold / Italic', size: 15, weight: FontWeight.w700, italic: true),
            ]),
          ),
        ),
      ],
    );
  }
}

class _StyleSample extends StatelessWidget {
  const _StyleSample({required this.font, required this.label, required this.size, required this.weight, this.italic = false});

  final String font;
  final String label;
  final double size;
  final FontWeight weight;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 94,
            child: Text('$label\n${size.toInt()} px', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: FontText(
              fontFamily: font,
              text: 'The art of type.',
              style: TextStyle(
                fontSize: size,
                fontWeight: weight,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.selectedFont,
    required this.onSelectFont,
  });

  final FontModel selectedFont;
  final ValueChanged<FontModel> onSelectFont;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

/// Clearance for the DartPad edition's standard bottom [NavigationBar].
///
/// The project uses a floating pill with the same 96 dp constant. The
/// NavigationBar occupies the scaffold's bottom slot (about 80 dp plus the
/// safe-area inset), so this local mirror keeps the scroll-to-top button and
/// the last cards clear of the nav instead of relying on the project file.
const double _kBottomNavClearance = 96;

class _ExploreScreenState extends State<ExploreScreen> {
  static const Duration kSearchDebounce = Duration(milliseconds: 300);

  /// Height of the fixed footer slot that hosts the batch loading state.
  static const double _footerHeight = 76;

  /// Distance from the bottom at which a scroll requests the next batch.
  static const double _loadMoreTriggerDistance = 400;

  /// Below this much remaining scroll extent the list is treated as too short
  /// to generate a scroll event, so the viewport fill check loads another batch.
  static const double _viewportFillThreshold = 240;

  /// Scroll offset past which the scroll-to-top button is offered.
  static const double _scrollTopThreshold = 240;

  /// How long the scroll-to-top button stays visible after the last scroll
  /// event before it fades away again.
  static const Duration _scrollTopIdleTimeout = Duration(seconds: 1);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Whether the list has left the top, which shows the pinned bar's hairline.
  ///
  /// Kept in a notifier so only the 1 px hairline rebuilds on a scroll; the
  /// pinned bar and the card list are untouched.
  final ValueNotifier<bool> _isScrolled = ValueNotifier<bool>(false);

  /// Normalized scroll progress (0.0 at rest to 1.0 when scrolled past 60px)
  /// driving smooth sticky compression, frosted glass, and elevation transitions.
  final ValueNotifier<double> _scrollRatio = ValueNotifier<double>(0.0);

  late final FontPaginator<CatalogueEntry> _paginator;

  Timer? _debounceTimer;
  Timer? _prefetchTimer;
  String _query = '';
  String _selectedCategory = 'All';
  FontSortOrder _sortOrder = FontSortOrder.popularity;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isMissingApiKey = false;
  bool _useOfflineCatalog = false;

  List<CatalogueEntry> _catalogueEntries = const [];
  List<CatalogueEntry> _results = const [];

  bool _isLoadingMore = false;
  String? _loadMoreError;

  /// Whether the scroll-to-top button is revealed.
  ///
  /// Kept as plain state rather than alongside [_isScrolled]: the hairline
  /// flips on the first pixel and only rebuilds itself, while this changes at
  /// most twice per gesture and repaints the overlay.
  bool _showScrollTop = false;

  /// Hides the scroll-to-top button once scrolling has been idle for
  /// [_scrollTopIdleTimeout]. Restarted by every scroll event past
  /// [_scrollTopThreshold] and cancelled on dispose.
  Timer? _fabHideTimer;

  /// Monotonic token compared by every async batch completion before it
  /// touches state, so a query/sort/filter change discards results it no
  /// longer owns.
  int _requestId = 0;

  /// Monotonic token identifying the catalogue fetch itself.
  ///
  /// Catalogue identity and result-set identity are different things: a
  /// query/sort/filter change replaces the result set (bumping [_requestId])
  /// but does not invalidate a catalogue download that is still in flight, so
  /// the fetch compares this token instead. Only a newer *fetch* supersedes an
  /// older one.
  int _catalogueRequestId = 0;

  /// Index at which the most recently revealed batch starts.
  ///
  /// Every card at or after it fades in via [FadeInBatch]; earlier cards are
  /// already settled and never replay the animation on a rebuild.
  int _fadeFromIndex = 0;

  static const List<String> _categories = [
    'All',
    'Sans Serif',
    'Serif',
    'Display',
    'Handwriting',
    'Monospace',
  ];

  @override
  void initState() {
    super.initState();
    _paginator = FontPaginator<CatalogueEntry>(idOf: (e) => e.name);
    _scrollController.addListener(_handleScroll);
    _fetchCatalogue();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _prefetchTimer?.cancel();
    _fabHideTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _isScrolled.dispose();
    _scrollRatio.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _prefetchTimer?.cancel();
    _debounceTimer = Timer(kSearchDebounce, () {
      if (!mounted) return;
      _query = value.trim();
      _rebuildResults();
    });
  }

  void _onClearSearch() {
    _debounceTimer?.cancel();
    _prefetchTimer?.cancel();
    _searchController.clear();
    _query = '';
    _rebuildResults();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Drives the pinned bar's hairline. ValueNotifier only notifies on change,
    // so this is a no-op for every frame where the offset crosses nothing.
    _isScrolled.value = position.pixels > 4;
    _scrollRatio.value = (position.pixels / 60.0).clamp(0.0, 1.0);
    _updateScrollTop(position.pixels);
    if (position.pixels >= position.maxScrollExtent - _loadMoreTriggerDistance) {
      unawaited(_loadMore());
    }
  }

  /// Reveals the scroll-to-top button past [_scrollTopThreshold] and keeps
  /// pushing its idle-hide timer back while the list moves, so the button
  /// survives a long drag and only fades once scrolling actually stops.
  void _updateScrollTop(double offset) {
    if (offset > _scrollTopThreshold) {
      if (!_showScrollTop) {
        setState(() => _showScrollTop = true);
      }
      _fabHideTimer?.cancel();
      _fabHideTimer = Timer(_scrollTopIdleTimeout, () {
        if (!mounted) return;
        setState(() => _showScrollTop = false);
      });
      return;
    }

    // Back near the top: no idle wait, the button is simply not needed.
    _fabHideTimer?.cancel();
    _fabHideTimer = null;
    if (_showScrollTop) {
      setState(() => _showScrollTop = false);
    }
  }

  /// Returns the list to the top, honouring the platform's reduce-motion
  /// preference by jumping instead of animating.
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      if (MediaQuery.disableAnimationsOf(context)) {
        position.jumpTo(0);
      } else {
        unawaited(_scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
        ));
      }
    }
    _fabHideTimer?.cancel();
    _fabHideTimer = null;
    if (_showScrollTop) {
      setState(() => _showScrollTop = false);
    }
  }

  Future<void> _fetchCatalogue({bool forceRefresh = false}) async {
    final catalogueId = ++_catalogueRequestId;

    if (_useOfflineCatalog) {
      _catalogueEntries = _sortEntries(availableFonts.map(CatalogueEntry.fromModel).toList());
      _rebuildResults();
      _scheduleViewportFillCheck();
      return;
    }

    if (_catalogueEntries.isEmpty && !forceRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _isMissingApiKey = false;
      });
    }

    try {
      final catalogue = await FontService.instance.fetchCatalogue(
        sort: _sortOrder,
        forceRefresh: forceRefresh,
      );
      if (!mounted || catalogueId != _catalogueRequestId) return;
      _isLoading = false;
      _catalogueEntries = _sortEntries(catalogue.entries);
      _rebuildResults();
      _scheduleViewportFillCheck();
    } on FontApiException catch (e) {
      if (!mounted || catalogueId != _catalogueRequestId) return;
      _isLoading = false;
      _errorMessage = e.message;
      _isMissingApiKey = e.isMissingApiKey;
      _catalogueEntries = _sortEntries(availableFonts.map(CatalogueEntry.fromModel).toList());
      _rebuildResults();
      _scheduleViewportFillCheck();
    } catch (e) {
      if (!mounted || catalogueId != _catalogueRequestId) return;
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred: $e';
      _catalogueEntries = _sortEntries(availableFonts.map(CatalogueEntry.fromModel).toList());
      _rebuildResults();
      _scheduleViewportFillCheck();
    }
  }

  List<CatalogueEntry> _sortEntries(List<CatalogueEntry> entries) {
    final copy = List<CatalogueEntry>.from(entries);
    switch (_sortOrder) {
      case FontSortOrder.popularity:
        break;
      case FontSortOrder.alphabetical:
        copy.sort((a, b) => a.searchName.compareTo(b.searchName));
        break;
      case FontSortOrder.trending:
        copy.sort((a, b) => b.searchName.compareTo(a.searchName));
        break;
    }
    return copy;
  }

  /// Re-applies the query and category filter to the current catalogue and
  /// rewinds the paginator to its first batch.
  void _rebuildResults() {
    _prefetchTimer?.cancel();
    final normalizedQuery = _query.toLowerCase();
    final normalizedCategory = _selectedCategory.toLowerCase();
    final filtered = <CatalogueEntry>[];
    final seenNames = <String>{};

    for (final entry in _catalogueEntries) {
      final matchesQuery = normalizedQuery.isEmpty ||
          entry.searchName.contains(normalizedQuery) ||
          entry.searchCategory.contains(normalizedQuery);
      final matchesCategory = _selectedCategory == 'All' ||
          entry.searchCategory == normalizedCategory;
      if (matchesQuery && matchesCategory && seenNames.add(entry.searchName)) {
        filtered.add(entry);
      }
    }

    _results = filtered;
    _requestId++;
    _paginator.reset(filtered);
    _fadeFromIndex = 0;
    _loadMoreError = null;
    _isLoadingMore = false;
    setState(() {
      _fabHideTimer?.cancel();
      _fabHideTimer = null;
      _showScrollTop = false;
    });
    _scheduleViewportFillCheck();
    _schedulePrefetch();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_paginator.hasMore) return;

    final id = _requestId;
    final previous = _paginator.visibleCount;
    assert(_fadeFromIndex <= _paginator.visibleCount);

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      await _paginator.loadNextPage();
      if (!mounted || id != _requestId) return;
      setState(() {
        _isLoadingMore = false;
        _fadeFromIndex = previous;
      });
      _scheduleViewportFillCheck();
      _schedulePrefetch();
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = 'Could not load more font families. Please try again.';
      });
    }
  }

  void _retryLoadMore() {
    if (_catalogueEntries.isEmpty) {
      unawaited(_fetchCatalogue(forceRefresh: true));
    } else {
      unawaited(_loadMore());
    }
  }

  /// Loads another batch when the current one is too short to scroll, so a
  /// tall viewport can never strand the list on the first five families.
  void _scheduleViewportFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isTooShortToScroll = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent < _viewportFillThreshold
          : true;
      if (_paginator.hasMore && !_isLoadingMore && isTooShortToScroll) {
        unawaited(_loadMore());
      }
    });
  }

  void _schedulePrefetch() {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_isLoadingMore) return;
      final currentRequestId = _requestId;

      final visibleCount = _paginator.visibleCount;
      final total = _results.length;
      if (visibleCount >= total) return;

      final nextSlice = _results.sublist(
        visibleCount,
        math.min(visibleCount + FontPaginator.defaultPageSize, total),
      );

      for (final entry in nextSlice) {
        if (!mounted || _requestId != currentRequestId) return;
        unawaited(FontService.instance.prefetchPreviewBytes(entry.model));
      }
    });
  }

  void _handleSortChanged(FontSortOrder newSort) {
    if (_sortOrder == newSort) return;
    _sortOrder = newSort;
    _prefetchTimer?.cancel();
    if (_useOfflineCatalog || _errorMessage != null) {
      _catalogueEntries = _sortEntries(_catalogueEntries);
      _rebuildResults();
    } else {
      _rebuildResults();
      unawaited(_fetchCatalogue());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visibleEntries = _paginator.visibleItems;
    final totalCount = _paginator.totalCount;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Stack(
      children: [
        CustomScrollView(
          key: const Key('explore-scroll'),
          controller: _scrollController,
          // Keep a little over a third of a screenful of slivers alive beyond the
          // viewport in both directions, so scrolling back over a batch boundary
          // reuses the cards instead of rebuilding them from scratch.
          scrollCacheExtent: const ScrollCacheExtent.pixels(320),
          slivers: [
            // Title and subtitle. These scroll away; only the search bar below is
            // pinned.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Explore fonts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Discover typography from the live Google Fonts catalogue.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ]),
              ),
            ),

            // Search bar, pinned to the top of the viewport so it stays reachable
            // at any scroll position while the cards scroll beneath it.
            //
            // The key sits on the bar's box rather than on the sliver: test
            // helpers that measure or tap the bar (`tester.getRect`) need a
            // RenderBox, and a keyed [PinnedHeaderSliver] resolves to a RenderSliver.
            PinnedHeaderSliver(
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollRatio,
                builder: (context, ratio, child) {
                  final isDark = theme.brightness == Brightness.dark;
                  final surfaceColor = theme.colorScheme.surface;
                  final bgAlpha = (1.0 - (0.15 * ratio)).clamp(0.0, 1.0);

                  return ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 16.0 * ratio,
                        sigmaY: 16.0 * ratio,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: ratio > 0.02
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: (isDark ? 0.35 : 0.08) * ratio,
                                    ),
                                    blurRadius: 14.0 * ratio,
                                    offset: Offset(0, 4.0 * ratio),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          key: const Key('pinned-search'),
                          color: surfaceColor.withValues(alpha: bgAlpha),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: _SearchBar(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onClear: _onClearSearch,
                        showClear: _searchController.text.isNotEmpty,
                      ),
                    ),
                    // 1 px separator, drawn only once the list has scrolled so
                    // the bar stays flush with the content at rest.
                    ValueListenableBuilder<bool>(
                      valueListenable: _isScrolled,
                      builder: (context, isScrolled, _) => Container(
                        key: const Key('pinned-search-hairline'),
                        height: 1,
                        color: theme.dividerColor.withValues(
                          alpha: isScrolled ? 1.0 : 0.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sorting control, category chips and any error/offline banner. These
            // are content, not chrome, so they scroll with the card list.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Sorting Segmented Control
                  Row(
                    children: [
                      Text(
                        'SORT BY:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SegmentedButton<FontSortOrder>(
                          segments: const [
                            ButtonSegment(
                              value: FontSortOrder.popularity,
                              label: Text('Popular', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.star_outline_rounded, size: 14),
                            ),
                            ButtonSegment(
                              value: FontSortOrder.alphabetical,
                              label: Text('A–Z', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.sort_by_alpha_rounded, size: 14),
                            ),
                            ButtonSegment(
                              value: FontSortOrder.trending,
                              label: Text('Trending', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.trending_up_rounded, size: 14),
                            ),
                          ],
                          selected: {_sortOrder},
                          onSelectionChanged: (values) => _handleSortChanged(values.first),
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (_) {
                              _selectedCategory = cat;
                              _rebuildResults();
                            },
                            selectedColor: isDark ? AppColors.darkBorder : const Color(0xFFE2E2E2),
                            checkmarkColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Error or Notice Banner
                  if (_errorMessage != null)
                    _buildErrorCard(context)
                  else if (_useOfflineCatalog)
                    _buildOfflineBanner(context),
                ]),
              ),
            ),

            // Results counter. A normal scrolling sliver directly below the pinned
            // bar: a second pinned band would eat the height a five-card batch
            // needs, so this scrolls away with the content.
            if (!_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        'Showing ${_paginator.visibleCount} of $totalCount font families',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (!FontApiConfig.hasValidApiKey && !_useOfflineCatalog)
                        Text(
                          'Demo / Offline mode',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),

            // Body Content: Loading indicator, Empty Results, or Lazy Loaded Font Cards
            if (_isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: theme.colorScheme.primary),
                        const SizedBox(height: 20),
                        Text(
                          'Fetching Google Fonts catalogue...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Connecting to Google Fonts Developer API',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_paginator.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: theme.disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          'No matching font families found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No fonts matched "$_query" with category "$_selectedCategory".',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            _selectedCategory = 'All';
                            _onClearSearch();
                          },
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          label: const Text('Clear search & filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // High-performance lazy-loading list builder for font cards. Only the
              // families the paginator has revealed are built.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  24,
                ),
                sliver: SliverList.builder(
                  key: const Key('font-list'),
                  itemCount: visibleEntries.length,
                  itemBuilder: (context, index) {
                    final entry = visibleEntries[index];
                    return FadeInBatch(
                      index: index,
                      fadeFrom: _fadeFromIndex,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FontCard(
                          font: entry.model,
                          isSelected: widget.selectedFont.name == entry.name,
                          onTap: () => widget.onSelectFont(entry.model),
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (!_isLoading && !_paginator.isEmpty) _buildBatchFooter(context),

            // Keep the pagination footer clear of the bottom NavigationBar. The
            // project uses a floating pill with the same 96 dp clearance.
            const SliverToBoxAdapter(
              child: SizedBox(height: _kBottomNavClearance),
            ),
          ],
        ),
        // Overlay, not chrome: it is hidden and inert until the list has
        // scrolled past [_scrollTopThreshold], so it never blocks a tap on a
        // card at rest. Positioned above the bottom NavigationBar via the same
        // local clearance constant the project uses for its floating pill.
        Positioned(
          right: 16,
          bottom: _kBottomNavClearance + 16,
          child: _buildScrollTopButton(context, reduceMotion: reduceMotion),
        ),
      ],
    );
  }

  /// The floating scroll-to-top button.
  ///
  /// [IgnorePointer] wraps the whole overlay, so a faded button is
  /// non-interactive from the first frame of its fade rather than after it.
  Widget _buildScrollTopButton(
    BuildContext context, {
    required bool reduceMotion,
  }) {
    final theme = Theme.of(context);

    return IgnorePointer(
      key: const Key('scroll-top-ignore'),
      ignoring: !_showScrollTop,
      child: AnimatedOpacity(
        key: const Key('scroll-top-opacity'),
        opacity: _showScrollTop ? 1 : 0,
        // Reduced motion gets the state change with none of the movement.
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Tooltip(
          message: 'Scroll to top',
          child: Semantics(
            button: true,
            label: 'Scroll to top',
            child: Material(
              key: const Key('scroll-top-button'),
              elevation: 3,
              color: theme.colorScheme.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _scrollToTop,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.keyboard_arrow_up_rounded),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fixed footer slot: batch spinner, batch error with Retry, or the
  /// end-of-catalogue notice, in that priority order.
  Widget _buildBatchFooter(BuildContext context) {
    final theme = Theme.of(context);
    final totalCount = _paginator.totalCount;

    Widget content;
    if (_isLoadingMore) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading more fonts...',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    } else if (_loadMoreError != null) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              _loadMoreError!,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _retryLoadMore,
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Retry'),
          ),
        ],
      );
    } else if (!_paginator.hasMore && totalCount > FontPaginator.defaultPageSize) {
      content = Text(
        'All $totalCount font families loaded.',
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
      );
    } else {
      content = const SizedBox.shrink();
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        key: const Key('batch-footer'),
        height: _footerHeight,
        child: Center(child: content),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkSurface : const Color(0xFFF9F9F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_isMissingApiKey ? Icons.key_outlined : Icons.cloud_off_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isMissingApiKey ? 'Google Fonts API key required for live catalogue' : 'Could not connect to Google Fonts API',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Network error.', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface, height: 1.4)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => unawaited(_fetchCatalogue(forceRefresh: true)),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkPrimaryAccent : AppColors.charcoal,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _useOfflineCatalog = true;
                    _errorMessage = null;
                    _catalogueEntries =
                        _sortEntries(availableFonts.map(CatalogueEntry.fromModel).toList());
                    _rebuildResults();
                    _scheduleViewportFillCheck();
                  },
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Use offline catalogue'),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFEEEEEE),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Browsing bundled offline fonts. Connect with your API key to search the entire online catalogue.',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _useOfflineCatalog = false);
                unawaited(_fetchCatalogue(forceRefresh: true));
              },
              child: const Text('Connect API', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The search field that lives in the pinned header.
///
/// Only the query input is pinned; the sort control and category chips below
/// it scroll with the cards so they cannot crowd the fixed bar.
class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.showClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showClear;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const cornerRadius = 12.0;

    // Modern layered dark theme colors
    final fillColor = isDark
        ? (_isFocused ? const Color(0xFF1E212B) : const Color(0xFF161820))
        : (_isFocused ? Colors.white : const Color(0xFFF1F2F6));

    final baseBorderColor = isDark
        ? Colors.white.withValues(alpha: _isFocused ? 0.35 : 0.09)
        : Colors.black.withValues(alpha: _isFocused ? 0.40 : 0.10);

    final accentColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    final borderColor = _isFocused ? accentColor : baseBorderColor;

    final isApple = theme.platform == TargetPlatform.macOS || theme.platform == TargetPlatform.iOS;
    final shortcutLabel = isApple ? '⌘K' : 'Ctrl+K';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _focusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _focusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_focusNode.hasFocus) {
            widget.onClear();
            _focusNode.unfocus();
          }
        },
      },
      child: Semantics(
        label: 'Search font family or category',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 46),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(cornerRadius),
            border: Border.all(
              color: borderColor,
              width: _isFocused ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              else if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                AnimatedRotation(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  turns: _isFocused ? 0.02 : 0.0,
                  child: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _isFocused
                        ? accentColor
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search font family or category...',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                // Animated clear button & keyboard shortcut cue
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: widget.showClear
                      ? IconButton(
                          key: const ValueKey('clear-btn'),
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: theme.colorScheme.onSurfaceVariant,
                          splashRadius: 16,
                          tooltip: 'Clear search',
                          onPressed: widget.onClear,
                        )
                      : (!_isFocused
                          ? Container(
                              key: const ValueKey('kbd-tag'),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Text(
                                shortcutLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            )
                          : const SizedBox(key: ValueKey('empty'), width: 4)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PREVIEW SCREEN (Fixed Live Preview Header + Scrollable Controls with Scrollbar)
// =============================================================================

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.selectedFont,
    required this.controller,
    required this.fontSize,
    required this.fontWeight,
    required this.textAlign,
    required this.onFontSizeChanged,
    required this.onFontWeightChanged,
    required this.onTextAlignChanged,
    required this.onReset,
    required this.onChooseFont,
  });

  final FontModel selectedFont;
  final TextEditingController controller;
  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<FontWeight> onFontWeightChanged;
  final ValueChanged<TextAlign> onTextAlignChanged;
  final VoidCallback onReset;
  final VoidCallback onChooseFont;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String get _weightLabel {
    switch (widget.fontWeight) {
      case FontWeight.w100: return 'Thin';
      case FontWeight.w200: return 'Extra Light';
      case FontWeight.w300: return 'Light';
      case FontWeight.w400: return 'Regular';
      case FontWeight.w500: return 'Medium';
      case FontWeight.w600: return 'Semi Bold';
      case FontWeight.w700: return 'Bold';
      case FontWeight.w800: return 'Extra Bold';
      case FontWeight.w900: return 'Black';
      default: return 'Regular';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final previewText = widget.controller.text.trim().isEmpty
        ? 'The quick brown fox jumps over the lazy dog.'
        : widget.controller.text;

    final isBuiltIn = FontService.isGoogleFontsSupported(widget.selectedFont.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // FIXED LIVE PREVIEW SECTION
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          color: theme.scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Typography tester',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onChooseFont,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Change font'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'LIVE PREVIEW',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const Spacer(),
                          Text(
                            widget.selectedFont.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFECECEC),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.selectedFont.category,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF2F2F2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isBuiltIn ? 'google_fonts' : 'FontLoader',
                              style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52, maxHeight: 130),
                        child: Center(
                          child: SingleChildScrollView(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: FontText(
                                key: ValueKey('${widget.selectedFont.name}-${widget.fontSize.toInt()}-${widget.fontWeight}-${widget.textAlign}-$previewText'),
                                fontFamily: widget.selectedFont.name,
                                text: previewText,
                                textAlign: widget.textAlign,
                                style: TextStyle(fontSize: widget.fontSize, fontWeight: widget.fontWeight, color: theme.colorScheme.onSurface, height: 1.25),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // VISUAL SEPARATION
        Container(
          height: 1,
          decoration: BoxDecoration(
            color: theme.dividerColor,
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: isDark ? 0.35 : 0.08),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),

        // SCROLLABLE CONTROLS SECTION WITH SCROLLBAR
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            thickness: 6,
            radius: const Radius.circular(3),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                _ControlCard(
                  title: 'YOUR TEXT',
                  trailing: '${previewText.length} characters',
                  child: TextField(
                    controller: widget.controller,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Type something to preview...', isDense: true),
                  ),
                ),
                const SizedBox(height: 12),
                _ControlCard(
                  title: 'Font size',
                  trailing: '${widget.fontSize.toInt()} px',
                  child: Slider(
                    value: widget.fontSize,
                    min: 12,
                    max: 64,
                    divisions: 52,
                    onChanged: widget.onFontSizeChanged,
                  ),
                ),
                const SizedBox(height: 12),
                _ControlCard(
                  title: 'Font weight',
                  trailing: _weightLabel,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (widget.selectedFont.weights.isEmpty ? const [FontWeight.w400] : widget.selectedFont.weights).map((weight) {
                      final label = _formatWeightChip(weight);
                      return ChoiceChip(
                        label: Text(label),
                        selected: widget.fontWeight == weight,
                        onSelected: (_) => widget.onFontWeightChanged(weight),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _ControlCard(
                  title: 'Text alignment',
                  child: SegmentedButton<TextAlign>(
                    segments: const [
                      ButtonSegment(value: TextAlign.left, icon: Icon(Icons.format_align_left), label: Text('Left')),
                      ButtonSegment(value: TextAlign.center, icon: Icon(Icons.format_align_center), label: Text('Center')),
                      ButtonSegment(value: TextAlign.right, icon: Icon(Icons.format_align_right), label: Text('Right')),
                    ],
                    selected: {widget.textAlign},
                    onSelectionChanged: (values) => widget.onTextAlignChanged(values.first),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: widget.onReset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset preview settings'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Fonts are dynamically fetched when requested and cached in memory to eliminate duplicate downloads. '
                  'Newly discovered Google Fonts catalogue families are dynamically registered via Flutter\'s FontLoader.',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatWeightChip(FontWeight weight) {
    switch (weight) {
      case FontWeight.w100: return 'Thin (100)';
      case FontWeight.w200: return 'Extra Light (200)';
      case FontWeight.w300: return 'Light (300)';
      case FontWeight.w400: return 'Regular (400)';
      case FontWeight.w500: return 'Medium (500)';
      case FontWeight.w600: return 'Semi Bold (600)';
      case FontWeight.w700: return 'Bold (700)';
      case FontWeight.w800: return 'Extra Bold (800)';
      case FontWeight.w900: return 'Black (900)';
      default: return 'Regular';
    }
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.title, required this.child, this.trailing});

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface))),
                if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MAIN APP COMPONENT (3 Tabs: Home, Explore, Preview)
// =============================================================================

class TypeStudioApp extends StatefulWidget {
  const TypeStudioApp({super.key});

  @override
  State<TypeStudioApp> createState() => _TypeStudioAppState();
}

class _TypeStudioAppState extends State<TypeStudioApp> {
  int _selectedTab = 0;
  bool _isDarkMode = false;
  late FontModel _selectedFont;

  final TextEditingController _previewController = TextEditingController(
    text: 'The quick brown fox jumps over the lazy dog.',
  );

  double _fontSize = thirtyTwo;
  FontWeight _fontWeight = FontWeight.w400;
  TextAlign _textAlign = TextAlign.left;

  static const double thirtyTwo = 32;

  @override
  void initState() {
    super.initState();
    _selectedFont = availableFonts.first;
    _previewController.addListener(_handlePreviewTextChanged);
  }

  void _handlePreviewTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _previewController.removeListener(_handlePreviewTextChanged);
    _previewController.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _selectFont(FontModel font) {
    setState(() {
      _selectedFont = font;
      if (!font.weights.contains(_fontWeight)) {
        _fontWeight = font.weights.contains(FontWeight.w400)
            ? FontWeight.w400
            : (font.weights.isNotEmpty ? font.weights.first : FontWeight.w400);
      }
      _selectedTab = 2;
    });

    FontService.instance.ensureFontLoaded(font.name, font: font).then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  void _resetPreview() {
    setState(() {
      _previewController.text = 'The quick brown fox jumps over the lazy dog.';
      _fontSize = thirtyTwo;
      _fontWeight = FontWeight.w400;
      _textAlign = TextAlign.left;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        selectedFont: _selectedFont,
        onExplore: () => setState(() => _selectedTab = 1),
        onPreview: () => setState(() => _selectedTab = 2),
        onSelectFont: _selectFont,
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
      ExploreScreen(
        selectedFont: _selectedFont,
        onSelectFont: _selectFont,
      ),
      PreviewScreen(
        selectedFont: _selectedFont,
        controller: _previewController,
        fontSize: _fontSize,
        fontWeight: _fontWeight,
        textAlign: _textAlign,
        onFontSizeChanged: (value) => setState(() => _fontSize = value),
        onFontWeightChanged: (value) => setState(() => _fontWeight = value),
        onTextAlignChanged: (value) => setState(() => _textAlign = value),
        onReset: _resetPreview,
        onChooseFont: () => setState(() => _selectedTab = 1),
      ),
    ];

    return MaterialApp(
      title: 'TypeStudio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: _selectedTab,
            children: pages,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedTab,
          onDestinationSelected: (index) {
            setState(() => _selectedTab = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.text_fields_rounded),
              selectedIcon: Icon(Icons.text_fields_rounded),
              label: 'Preview',
            ),
          ],
        ),
      ),
    );
  }
}
