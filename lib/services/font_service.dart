import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show compute, debugPrint, kDebugMode, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart'
    show FontStyle, FontVariation, FontWeight, TextStyle;

import '../config/google_fonts_config.dart';
import '../data/font_data.dart';
import '../models/catalogue_entry.dart';
import '../models/font_face.dart';
import '../models/font_model.dart';
import 'catalogue_store.dart';

/// Top-level JSON decoder used by [compute] on native platforms.
List<dynamic> _parseItemsJson(String body) {
  final data = json.decode(body) as Map<String, dynamic>;
  return (data['items'] as List<dynamic>?) ?? const [];
}

/// Supported sort orders for the Google Fonts Developer API and local catalogue.
enum FontSortOrder {
  popularity('popularity', 'Popular'),
  alphabetical('alpha', 'A–Z'),
  trending('trending', 'Trending');

  const FontSortOrder(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// Service managing Google Fonts API discovery, dynamic font file loading via
/// Flutter's [FontLoader], in-memory font caching, concurrency limiting, and font state registry.
class FontService {
  FontService._internal() {
    // Register bundled fonts in registry and preserve them as bundled fallback
    for (final font in availableFonts) {
      final entry = CatalogueEntry.fromModel(font);
      _bundledRegistry[font.name] = entry;
      _entryRegistry[font.name] = entry;
    }
  }

  static final FontService instance = FontService._internal();

  /// Optional injectable HTTP client for tests.
  @visibleForTesting
  http.Client? debugHttpClient;

  CatalogueStore _catalogueStore = SharedPreferencesCatalogueStore();

  /// Injectable catalogue store for tests.
  @visibleForTesting
  set debugCatalogueStore(CatalogueStore? store) {
    _catalogueStore = store ?? SharedPreferencesCatalogueStore();
  }

  /// Maximum number of downloaded font files kept in the byte cache.
  ///
  /// Entries are evicted least-recently-used first, so browsing a long
  /// catalogue cannot grow the cache without bound.
  static const int fontFileCacheLimit = 64;

  /// In-memory cache of downloaded font file bytes keyed by download URL.
  ///
  /// Insertion order doubles as LRU recency: [LinkedHashMap] (the default for
  /// a Dart map literal) preserves it, so the first key is the least recent.
  final Map<String, Uint8List> _downloadCache = {};

  /// Number of font files currently held in the byte cache.
  int get cachedFontFileCount => _downloadCache.length;

  /// Family names that have at least one face registered with the engine.
  ///
  /// This is a convenience flag for legacy callers. It never means every face
  /// of the family is loaded; use [isFaceLoaded] for that question.
  final Set<String> _loadedFamilies = {};

  /// Genuine faces that have completed loading, keyed by [faceKey].
  final Map<String, LoadedFontFace> _faces = {};

  /// In-flight face loads, keyed by [faceKey].
  ///
  /// Concurrent requests for the same face share this future instead of
  /// starting another download. Failed entries are removed so a later request
  /// can retry.
  final Map<String, Future<LoadedFontFace>> _pendingFaces = {};

  /// Font file bytes currently being downloaded, keyed by URL.
  final Map<String, Future<Uint8List>> _byteFetches = {};

  /// Parsed variation axes for downloaded files, keyed by URL.
  final Map<String, FontFileAxes> _fileAxes = {};

  /// Family aliases already registered with Flutter's [FontLoader].
  final Set<String> _registeredAliases = {};

  /// Face keys whose cache HIT has already been logged.
  final Set<String> _loggedFaceHits = {};

  /// Face keys whose pending reuse has already been logged.
  final Set<String> _loggedPendingHits = {};

  /// Disables the `google_fonts` fallback in tests that must stay offline.
  @visibleForTesting
  bool debugGoogleFallbackEnabled = true;

  /// Serialises `google_fonts` fallback loads.
  ///
  /// `GoogleFonts.pendingFonts()` waits for every pending google load, so
  /// overlapping calls can let one family's failure surface in another. A
  /// single queue keeps each fallback independent.
  Future<void> _googleTail = Future<void>.value();

  /// Registry of known fonts (built-in + discovered from API) keyed by family name.
  final Map<String, CatalogueEntry> _entryRegistry = {};

  /// Immutable backup of bundled fonts so clearCache does not remove them.
  final Map<String, CatalogueEntry> _bundledRegistry = {};

  /// Cache of API catalogue lists keyed by [FontSortOrder].
  final Map<FontSortOrder, FontCatalogue> _catalogueCache = {};

  /// In-flight prefetch URLs to avoid duplicate prefetch requests.
  final Set<String> _inFlightPrefetches = {};

  /// Memoised preview loads keyed by face key.
  ///
  /// Widgets call [previewFont] from `build`, so the identical future has to be
  /// handed back for a face that is already loading (or loaded). An entry is
  /// dropped when its future fails, which keeps a failed face retryable.
  final Map<String, Future<void>> _previewFutures = {};


  /// Cached answers for [isGoogleFontsSupported], which is called per build.
  static final Map<String, bool> _googleFontsSupport = {};

  /// Concurrency limiter for network font downloads (max 3 concurrent HTTP downloads).
  int _activeHttpDownloads = 0;
  final List<Completer<void>> _downloadQueue = [];

  Future<http.Response> _httpGet(Uri uri, {Duration? timeout}) {
    final client = debugHttpClient;
    if (client != null) {
      final req = client.get(uri);
      return timeout != null ? req.timeout(timeout) : req;
    }
    final req = http.get(uri);
    return timeout != null ? req.timeout(timeout) : req;
  }

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

  /// Stores [bytes] for [url] and evicts the least-recently-used entries past
  /// [fontFileCacheLimit].
  void _putFontBytes(String url, Uint8List bytes) {
    // Re-inserting moves the key to the newest position in insertion order.
    _downloadCache.remove(url);
    _downloadCache[url] = bytes;
    while (_downloadCache.length > fontFileCacheLimit) {
      _downloadCache.remove(_downloadCache.keys.first);
    }
  }

  /// Returns the cached bytes for [url], or `null` when absent.
  ///
  /// A hit is re-inserted so it becomes the most recently used entry.
  Uint8List? _cachedFontBytes(String url) {
    final bytes = _downloadCache.remove(url);
    if (bytes == null) {
      return null;
    }
    _downloadCache[url] = bytes;
    return bytes;
  }

  /// Seeds the byte cache for tests without performing a network download.
  ///
  /// Routes through [_putFontBytes] so the LRU cap and eviction order are the
  /// same ones real downloads use.
  @visibleForTesting
  void debugCacheFontBytes(String url, Uint8List bytes) {
    _putFontBytes(url, bytes);
  }

  /// Returns whether a given font family is supported by the `google_fonts` package.
  static bool isGoogleFontsSupported(String familyName) {
    return _googleFontsSupport.putIfAbsent(
      familyName,
      () => GoogleFonts.asMap().containsKey(familyName),
    );
  }

  /// Whether at least one face of [familyName] is loaded.
  ///
  /// Family level only. Check [isFaceLoaded] before assuming a specific weight
  /// or italic face is available.
  bool isFontLoaded(String familyName) {
    if (_loadedFamilies.contains(familyName)) {
      return true;
    }
    final normalized = _normalizeFamily(familyName);
    return _faces.values.any((face) => face.normalizedFamily == normalized);
  }

  /// Whether the exact genuine face is already loaded.
  bool isFaceLoaded(
    String familyName, {
    required int weight,
    bool italic = false,
  }) {
    return _faces.containsKey(faceKey(familyName, weight, italic: italic));
  }

  /// Returns the exact loaded face, or `null` when it is not cached.
  LoadedFontFace? loadedFace(
    String familyName, {
    required int weight,
    bool italic = false,
  }) {
    return _faces[faceKey(familyName, weight, italic: italic)];
  }

  /// Stable cache key for one genuine face.
  ///
  /// Example: `roboto_700_normal`, `roboto_400_italic`.
  static String faceKey(String family, int weight, {bool italic = false}) {
    final normalized = family
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_');
    return '${normalized}_${weight}_${italic ? 'italic' : 'normal'}';
  }

  /// Looks up a [FontModel] in the registry by its family name.
  FontModel? getFont(String familyName) => _entryRegistry[familyName]?.model;

  /// Looks up a [CatalogueEntry] in the registry by its family name.
  CatalogueEntry? getEntry(String familyName) => _entryRegistry[familyName];

  /// Registers a list of fonts into the active registry.
  void registerFonts(Iterable<FontModel> fonts) {
    for (final font in fonts) {
      _entryRegistry[font.name] = CatalogueEntry.fromModel(font);
    }
  }

  /// Registers a list of catalogue entries into the active registry.
  void registerEntries(Iterable<CatalogueEntry> entries) {
    for (final entry in entries) {
      _entryRegistry[entry.name] = entry;
    }
  }

  /// Clears in-memory caches (useful for testing or cache reset).
  ///
  /// Clears only the in-memory API catalogue and entries; the bundled registry
  /// and the persisted body survive so an offline fallback remains functional.
  void clearCache() {
    _downloadCache.clear();
    _loadedFamilies.clear();
    _catalogueCache.clear();
    _activeFontLoads.clear();
    _previewFutures.clear();
    _previewStyleCache.clear();
    _inFlightPrefetches.clear();
    _entryRegistry.clear();
    _entryRegistry.addAll(_bundledRegistry);
  }

  Future<List<dynamic>> _decodeItems(String body) async {
    if (kIsWeb) {
      // On web/DartPad: yield to the event loop so the UI skeleton paints first
      await Future<void>.delayed(Duration.zero);
      final data = json.decode(body) as Map<String, dynamic>;
      return (data['items'] as List<dynamic>?) ?? const [];
    } else {
      return compute(_parseItemsJson, body);
    }
  }

  FontCatalogue _buildCatalogueFromItems(
    String body,
    List<dynamic> items, {
    bool isFromCache = false,
  }) {
    final entries = items.map((item) {
      if (item is Map<String, dynamic>) {
        return CatalogueEntry.fromJson(item);
      }
      return CatalogueEntry.fromJson((item as Map).cast<String, dynamic>());
    }).toList();

    registerEntries(entries);
    return FontCatalogue(
      entries: entries,
      rawBody: body,
      isFromCache: isFromCache,
    );
  }

  /// Fetches the font catalogue from cache or Google Fonts Developer API.
  ///
  /// Returns a [FontCatalogue]. If [forceRefresh] is false and catalogue is
  /// already in memory for [sort], returns immediately. If in persistent store,
  /// returns cached catalogue marked [FontCatalogue.isFromCache] = true.
  Future<FontCatalogue> fetchCatalogue({
    FontSortOrder sort = FontSortOrder.popularity,
    bool forceRefresh = false,
  }) async {
    // 1. In-memory cache
    if (!forceRefresh && _catalogueCache.containsKey(sort)) {
      return _catalogueCache[sort]!;
    }

    // 2. Try the persistent store if not forcing refresh
    if (!forceRefresh) {
      try {
        final cachedBody = await _catalogueStore.read(sort);
        if (cachedBody != null && cachedBody.isNotEmpty) {
          final items = await _decodeItems(cachedBody);
          final catalogue = _buildCatalogueFromItems(
            cachedBody,
            items,
            isFromCache: true,
          );
          _catalogueCache[sort] = catalogue;
          return catalogue;
        }
      } catch (_) {
        // Corrupted cache body; fall through to live fetch
      }
    }

    // 4. Missing API key: check if cached body exists before throwing
    if (!FontApiConfig.hasValidApiKey) {
      try {
        final cachedBody = await _catalogueStore.read(sort);
        if (cachedBody != null && cachedBody.isNotEmpty) {
          final items = await _decodeItems(cachedBody);
          final catalogue = _buildCatalogueFromItems(
            cachedBody,
            items,
            isFromCache: true,
          );
          _catalogueCache[sort] = catalogue;
          return catalogue;
        }
      } catch (_) {}

      throw const FontApiException(
        'Google Fonts Developer API key is not configured. '
        'Please set your API key in lib/config/google_fonts_config.dart or pass '
        '--dart-define=GOOGLE_FONTS_API_KEY=your_key.',
        isMissingApiKey: true,
      );
    }

    // 3. Fetch live
    final uri = Uri.parse(
      '${FontApiConfig.apiBaseUrl}?key=${FontApiConfig.apiKey}&sort=${sort.apiValue}',
    );

    try {
      final response = await _httpGet(
        uri,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final body = response.body;
        final items = await _decodeItems(body);
        final catalogue = _buildCatalogueFromItems(
          body,
          items,
          isFromCache: false,
        );

        _catalogueCache[sort] = catalogue;
        unawaited(_catalogueStore.write(sort, body));
        return catalogue;
      } else if (response.statusCode == 400 || response.statusCode == 403) {
        throw FontApiException(
          'Google Fonts API authentication failed (${response.statusCode}). '
          'Please verify that your Google Fonts Developer API key is valid and has Web Fonts Developer API enabled in Google Cloud Console.',
          statusCode: response.statusCode,
          isMissingApiKey: true,
        );
      } else {
        throw FontApiException(
          'Failed to retrieve font catalogue (HTTP ${response.statusCode}): ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
    } on FontApiException {
      rethrow;
    } catch (e) {
      throw FontApiException(
        'Network error connecting to Google Fonts API: $e. Please verify your internet connection and retry.',
      );
    }
  }

  /// Ensures that a font family is loaded and ready for rendering in Flutter.
  ///
  /// Chooses the engine in this order:
  /// 1. If the family's [FontModel.files] has a URL -> [_loadCustomFont] (FontLoader).
  ///    Each family completes independently and never calls `GoogleFonts.pendingFonts()`.
  /// 2. Otherwise, if `google_fonts` supports it -> existing google_fonts path.
  /// 3. Otherwise -> missing-URL error with Retry.
  Future<void> ensureFontLoaded(
    String familyName, {
    FontModel? font,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
  }) async {
    final targetFont = font ?? getFont(familyName);
    final fileUrl = targetFont?.getFileUrl(weight: weight, italic: italic);

    // 1. If font has a downloadable file URL -> FontLoader path
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

    // 2. Otherwise, if google_fonts supports it -> google_fonts path
    if (isGoogleFontsSupported(familyName)) {
      try {
        GoogleFonts.getFont(familyName);
        await GoogleFonts.pendingFonts();
        return;
      } catch (_) {
        // Fall through
      }
    }

    // 3. Otherwise -> missing-URL error with Retry
    throw FontApiException(
      'No font file URL available for "$familyName" to load via FontLoader.',
    );
  }

  /// Loads the regular weight of [familyName] for a preview, memoised per family.
  ///
  /// Widgets call this from `build`, so repeat calls must return the identical
  /// [Future] object instead of queuing another load. A failed load removes its
  /// entry, so the next call retries the family rather than caching the error.
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

  /// Returns a preview [TextStyle] for [font] without doing load work per call.
  ///
  /// The regular face of a family that has a downloadable file uses the
  /// [FontLoader] family name, so the screen does not download the same file a
  /// second time through `google_fonts`. Other weights and italics resolve
  /// through `google_fonts` when the package supports the family, which keeps
  /// real bold and italic faces instead of synthetic ones.
  ///
  /// The resolved family is cached per family, weight, and italic. The changing
  /// fields from [base] (size, colour, leading, tracking) are applied on every
  /// call, so the cache stores no per-frame state.
  TextStyle previewStyle(
    FontModel font,
    TextStyle base, {
    required FontWeight weight,
    required bool italic,
  }) {
    final key = '${font.name}|${weight.value}|$italic';
    final resolved = _previewStyleCache.putIfAbsent(key, () {
      final fileUrl = font.getFileUrl(weight: weight, italic: italic);
      final hasFile = fileUrl != null && fileUrl.isNotEmpty;
      final usesLoaderRegular =
          weight == FontWeight.w400 && !italic && hasFile;

      if (!usesLoaderRegular && isGoogleFontsSupported(font.name)) {
        try {
          return GoogleFonts.getFont(font.name, textStyle: base);
        } catch (_) {
          // Fall through to the FontLoader family or system fallback.
        }
      }
      return base.copyWith(fontFamily: font.name);
    });

    return resolved.copyWith(
      fontSize: base.fontSize,
      fontWeight: base.fontWeight,
      fontStyle: base.fontStyle,
      color: base.color,
      height: base.height,
      letterSpacing: base.letterSpacing,
    );
  }

  /// Prefetches the regular-weight font bytes for [model] into the byte cache.
  ///
  /// Does not call `FontLoader.load`. Best-effort and swallows errors.
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
        final response = await _httpGet(
          Uri.parse(secureUrl),
          timeout: const Duration(seconds: 20),
        );
        if (response.statusCode == 200) {
          _putFontBytes(secureUrl, response.bodyBytes);
        }
      } finally {
        _releaseDownloadSlot();
      }
    } catch (_) {
      // Best-effort; swallow prefetch errors
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
          final response = await _httpGet(
            Uri.parse(secureUrl),
            timeout: const Duration(seconds: 20),
          );

          if (response.statusCode != 200) {
            throw FontApiException(
              'Failed to download font file for "$familyName" (HTTP ${response.statusCode}).',
              statusCode: response.statusCode,
            );
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

/// Exception representing an error communicating with the Google Fonts API
/// or downloading/loading font files.
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
