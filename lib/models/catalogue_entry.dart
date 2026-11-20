import 'font_model.dart';

/// Lightweight catalogue entry representing a font before full parsing.
///
/// Holds cheap precomputed search keys and the raw JSON map so [FontModel]
/// is only instantiated lazily when revealed in the UI or selected.
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

  /// Whether font file download URLs are available for this entry.
  bool get hasFileUrl {
    if (_providedModel != null) {
      return true;
    }
    final files = raw?['files'];
    return files is Map && files.isNotEmpty;
  }

  /// Lazily constructed full [FontModel]. Evaluated once on first access.
  late final FontModel model = _providedModel ?? FontModel.fromJson(raw!);
}

/// A parsed catalogue of [CatalogueEntry] items, together with its raw response
/// body for persistence and equality checks.
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
