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
    _faces.clear();
    _pendingFaces.clear();
    _byteFetches.clear();
    _fileAxes.clear();
    _registeredAliases.clear();
    _loggedFaceHits.clear();
    _loggedPendingHits.clear();
    _catalogueCache.clear();
    _previewFutures.clear();
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

  /// Ensures that an exact font face is loaded and registered.
  ///
  /// Faces are cached by family, weight, and italic style. Concurrent requests
  /// for the same face share one download, and a failed face is never cached so
  /// the caller can retry. A variable face already loaded for the family is
  /// reused for other weights instead of downloading a separate file.
  Future<LoadedFontFace> ensureFace(
    FontModel font, {
    required int weight,
    bool italic = false,
  }) {
    final key = faceKey(font.name, weight, italic: italic);

    final cached = _faces[key];
    if (cached != null) {
      if (_loggedFaceHits.add(key)) {
        _logFace('HIT', key);
      }
      return Future.value(cached);
    }

    final pending = _pendingFaces[key];
    if (pending != null) {
      if (_loggedPendingHits.add(key)) {
        _logFace('REUSE_PENDING', key);
      }
      return pending;
    }

    _logFace('LOADING', key);
    final future = _loadFace(font, weight: weight, italic: italic).then((face) {
      final stored = face.forRequest(weight: weight, italic: italic);
      _faces[key] = stored;
      _logFace('LOADED', key, detail: stored.registeredFamily);
      return stored;
    });

    _pendingFaces[key] = future;
    future.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        _logFace('FAILED', key, detail: '$error');
      },
    ).whenComplete(() {
      if (identical(_pendingFaces[key], future)) {
        _pendingFaces.remove(key);
      }
    });

    return future;
  }

  /// Legacy family-level loader kept for callers that only need a face ready.
  Future<void> ensureFontLoaded(
    String familyName, {
    FontModel? font,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
  }) async {
    final targetFont = font ?? getFont(familyName);

    if (targetFont != null) {
      await ensureFace(
        targetFont,
        weight: weight.value,
        italic: italic,
      );
      return;
    }

    if (debugGoogleFallbackEnabled && isGoogleFontsSupported(familyName)) {
      final key = faceKey(familyName, weight.value, italic: italic);
      final existing = _faces[key];
      if (existing != null) {
        return;
      }
      final pending = _pendingFaces[key];
      if (pending != null) {
        await pending;
        return;
      }
      final future = _loadGoogleFace(
        familyName,
        null,
        weight: weight.value,
        italic: italic,
      );
      _pendingFaces[key] = future;
      try {
        _faces[key] = await future;
      } finally {
        if (identical(_pendingFaces[key], future)) {
          _pendingFaces.remove(key);
        }
      }
      return;
    }

    throw FontApiException(
      'No font file URL available for "$familyName" to load via FontLoader.',
    );
  }

  /// Loads the regular weight of [familyName] for a preview, memoised per face.
  ///
  /// Widgets call this from `build`, so repeat calls must return the identical
  /// [Future] object instead of queuing another load. A failed load removes its
  /// entry, so the next call retries the face rather than caching the error.
  Future<void> previewFont(String familyName, {FontModel? font}) {
    final key = faceKey(familyName, 400);
    return _previewFutures.putIfAbsent(key, () {
      final future = ensureFontLoaded(
        familyName,
        font: font,
        weight: FontWeight.w400,
      );
      future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {
          if (identical(_previewFutures[key], future)) {
            _previewFutures.remove(key);
          }
        },
      );
      return future;
    });
  }

  /// Resolves the best face to render for a weight and italic request.
  ///
  /// Reads only the loaded-face cache, so it is safe to call during `build` and
  /// never starts a download. The result distinguishes genuine, variable,
  /// simulated, and approximate previews.
  FontFacePreview resolvePreviewFace(
    FontModel font, {
    required int weight,
    bool italic = false,
  }) {
    final normalized = _normalizeFamily(font.name);
    final faces = _faces.values
        .where((face) => face.normalizedFamily == normalized)
        .toList();

    if (faces.isEmpty) {
      return FontFacePreview(
        status: FontFaceStatus.unloaded,
        family: font.name,
        renderWeight: weight,
        renderItalic: italic,
        simulatedWeight: true,
        simulatedItalic: italic,
      );
    }

    LoadedFontFace? exact;
    for (final face in faces) {
      if (face.requestedWeight == weight &&
          face.requestedItalic == italic) {
        exact = face;
        break;
      }
    }
    if (exact == null) {
      for (final face in faces) {
        if (face.actualWeight == weight && face.actualItalic == italic) {
          exact = face;
          break;
        }
      }
    }
    if (exact != null) {
      return _previewFromFace(
        font,
        font.name,
        exact,
        weight: weight,
        italic: italic,
      );
    }

    if (italic) {
      for (final face in faces) {
        if (face.italicAxis != null) {
          return _previewFromFace(
            font,
            font.name,
            face,
            weight: weight,
            italic: true,
          );
        }
      }
      for (final face in faces) {
        if (face.actualItalic) {
          return _previewFromFace(
            font,
            font.name,
            face,
            weight: weight,
            italic: true,
          );
        }
      }
    }

    for (final face in faces) {
      if (face.weightAxis != null &&
          (face.requestedItalic == italic || face.actualItalic == italic)) {
        return _previewFromFace(
          font,
          font.name,
          face,
          weight: weight,
          italic: italic,
        );
      }
    }
    for (final face in faces) {
      if (face.weightAxis != null) {
        return _previewFromFace(
          font,
          font.name,
          face,
          weight: weight,
          italic: italic,
        );
      }
    }

    final nearest = _nearestFace(font.name, weight, italic);
    return _previewFromFace(
      font,
      font.name,
      nearest!,
      weight: weight,
      italic: italic,
    );
  }

  /// Returns a preview [TextStyle] for [font] without doing load work per call.
  ///
  /// The registered family comes from the loaded-face cache. Variable faces get
  /// a `FontVariation` for the requested weight instead of a new download, and
  /// static faces use the closest loaded face with a clear status on the screen.
  TextStyle previewStyle(
    FontModel font,
    TextStyle base, {
    required FontWeight weight,
    required bool italic,
  }) {
    final preview = resolvePreviewFace(
      font,
      weight: weight.value,
      italic: italic,
    );
    return _applyPreview(base, preview);
  }

  /// Like [previewStyle] but works for google-only families without a model.
  TextStyle previewStyleForFamily(
    String familyName,
    TextStyle base, {
    required FontWeight weight,
    required bool italic,
  }) {
    final model = getFont(familyName);
    if (model != null) {
      return previewStyle(
        model,
        base,
        weight: weight,
        italic: italic,
      );
    }

    final face = _nearestFace(familyName, weight.value, italic);
    if (face == null) {
      return base.copyWith(fontFamily: familyName);
    }

    return _applyPreview(
      base,
      _previewFromFace(
        null,
        familyName,
        face,
        weight: weight.value,
        italic: italic,
      ),
    );
  }

  /// Prefetches the regular-weight font bytes for [model] into the byte cache.
  ///
  /// Does not call `FontLoader.load`. Best-effort and swallows errors.
  Future<void> prefetchPreviewBytes(FontModel model) async {
    final fileUrl = model.exactFileUrl(weight: 400, italic: false) ??
        model.getFileUrl(weight: FontWeight.w400, italic: false);
    if (fileUrl == null || fileUrl.isEmpty) {
      return;
    }

    final secureUrl = _secureUrl(fileUrl);

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

  /// Loads one requested face, preferring genuine catalogue files.
  Future<LoadedFontFace> _loadFace(
    FontModel font, {
    required int weight,
    bool italic = false,
  }) async {
    final variableBase = _findVariableBase(font.name, italic);
    if (variableBase != null) {
      return variableBase.forRequest(weight: weight, italic: italic);
    }

    final exactUrl = font.exactFileUrl(weight: weight, italic: italic);
    Object? exactError;
    if (exactUrl != null) {
      try {
        return await _loadFaceFile(
          font,
          weight: weight,
          italic: italic,
          url: exactUrl,
          registrationWeight: weight,
          registrationItalic: italic,
        );
      } catch (error) {
        exactError = error;
      }
    }

    if (debugGoogleFallbackEnabled && isGoogleFontsSupported(font.name)) {
      try {
        return await _loadGoogleFace(
          font.name,
          font,
          weight: weight,
          italic: italic,
        );
      } catch (_) {
        // Fall back to the closest catalogue face or the regular face.
      }
    }

    final fallback = await _loadFallbackFace(
      font,
      weight: weight,
      italic: italic,
    );
    if (fallback != null) {
      return fallback;
    }

    if (exactError is FontApiException) {
      throw exactError;
    }
    throw FontApiException(
      'No font file URL available for "${font.name}" at weight '
      '$weight${italic ? ' italic' : ''} to load via FontLoader.',
    );
  }

  /// Uses an already loaded or downloadable face close to the request.
  Future<LoadedFontFace?> _loadFallbackFace(
    FontModel font, {
    required int weight,
    required bool italic,
  }) async {
    final closest = font.closestAvailableWeight(weight, italic: italic);
    if (closest != weight) {
      final existing = _faces[faceKey(font.name, closest, italic: italic)];
      if (existing != null) {
        return existing.forRequest(weight: weight, italic: italic);
      }
      final url = font.exactFileUrl(weight: closest, italic: italic);
      if (url != null) {
        return _loadFaceFile(
          font,
          weight: weight,
          italic: italic,
          url: url,
          registrationWeight: closest,
          registrationItalic: italic,
        );
      }
    }

    if (weight == 400 && !italic) {
      return null;
    }

    final baseWeight = font.closestAvailableWeight(400);
    final existingBase = _faces[faceKey(font.name, baseWeight)];
    if (existingBase != null) {
      return existingBase.forRequest(weight: weight, italic: italic);
    }

    final baseUrl = font.exactFileUrl(weight: baseWeight, italic: false);
    if (baseUrl != null && (baseWeight != weight || italic)) {
      return _loadFaceFile(
        font,
        weight: weight,
        italic: italic,
        url: baseUrl,
        registrationWeight: baseWeight,
        registrationItalic: false,
      );
    }

    return null;
  }

  Future<LoadedFontFace> _loadFaceFile(
    FontModel font, {
    required int weight,
    required bool italic,
    required String url,
    required int registrationWeight,
    required bool registrationItalic,
  }) async {
    final secureUrl = _secureUrl(url);
    final bytes = await _fontBytesFor(secureUrl, font.name);
    final axes = _fileAxes.putIfAbsent(
      secureUrl,
      () => FontFileAxes.parse(bytes),
    );

    final alias = _aliasFor(
      font.name,
      registrationWeight,
      registrationItalic,
    );
    if (!_registeredAliases.contains(alias)) {
      final fontLoader = FontLoader(alias);
      fontLoader.addFont(Future.value(ByteData.sublistView(bytes)));
      await fontLoader.load();
      _registeredAliases.add(alias);
      _loadedFamilies.add(alias);
      if (registrationWeight == 400 && !registrationItalic) {
        _loadedFamilies.add(font.name);
      }
    }

    return LoadedFontFace(
      family: font.name,
      requestedWeight: weight,
      requestedItalic: italic,
      registeredFamily: alias,
      actualWeight: registrationWeight,
      actualItalic: registrationItalic,
      axes: axes,
      fileUrl: secureUrl,
    );
  }

  Future<LoadedFontFace> _loadGoogleFace(
    String familyName,
    FontModel? font, {
    required int weight,
    required bool italic,
  }) {
    return _runGoogleSerialized(() async {
      final style = GoogleFonts.getFont(
        familyName,
        fontWeight: _weightFromNumber(weight),
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );
      await GoogleFonts.pendingFonts();

      final registeredFamily = style.fontFamily;
      if (registeredFamily == null || registeredFamily.isEmpty) {
        throw FontApiException(
          'Google Fonts did not resolve a family for "$familyName".',
        );
      }

      return LoadedFontFace(
        family: familyName,
        requestedWeight: weight,
        requestedItalic: italic,
        registeredFamily: registeredFamily,
        fallbacks: style.fontFamilyFallback ?? const [],
        actualWeight: _googleAliasWeight(registeredFamily),
        actualItalic: registeredFamily.endsWith('italic'),
        fromGoogleFonts: true,
      );
    });
  }

  /// Serialises google_fonts fallbacks so one failure cannot block another.
  Future<T> _runGoogleSerialized<T>(Future<T> Function() action) {
    final result = Completer<T>();
    final previous = _googleTail;
    _googleTail = result.future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );

    previous.whenComplete(() {
      action().then(result.complete, onError: result.completeError);
    });

    return result.future;
  }

  Future<Uint8List> _fontBytesFor(String secureUrl, String family) {
    final cached = _cachedFontBytes(secureUrl);
    if (cached != null) {
      return Future.value(cached);
    }

    final existing = _byteFetches[secureUrl];
    if (existing != null) {
      return existing;
    }

    final future = _downloadFontBytes(secureUrl, family);
    _byteFetches[secureUrl] = future;
    future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    ).whenComplete(() {
      if (identical(_byteFetches[secureUrl], future)) {
        _byteFetches.remove(secureUrl);
      }
    });
    return future;
  }

  Future<Uint8List> _downloadFontBytes(
    String secureUrl,
    String family,
  ) async {
    final cached = _cachedFontBytes(secureUrl);
    if (cached != null) {
      return cached;
    }

    await _acquireDownloadSlot();
    try {
      final raced = _cachedFontBytes(secureUrl);
      if (raced != null) {
        return raced;
      }

      final response = await _httpGet(
        Uri.parse(secureUrl),
        timeout: const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        throw FontApiException(
          'Failed to download font file for "$family" (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }

      final bytes = response.bodyBytes;
      _putFontBytes(secureUrl, bytes);
      return bytes;
    } finally {
      _releaseDownloadSlot();
    }
  }

  LoadedFontFace? _findVariableBase(String family, bool italic) {
    final normalized = _normalizeFamily(family);
    if (!italic) {
      for (final face in _faces.values) {
        if (face.normalizedFamily == normalized && face.weightAxis != null) {
          return face;
        }
      }
      return null;
    }

    for (final face in _faces.values) {
      if (face.normalizedFamily == normalized && face.italicAxis != null) {
        return face;
      }
    }
    for (final face in _faces.values) {
      if (face.normalizedFamily == normalized &&
          face.weightAxis != null &&
          face.actualItalic) {
        return face;
      }
    }
    return null;
  }

  LoadedFontFace? _nearestFace(String family, int weight, bool italic) {
    final normalized = _normalizeFamily(family);
    final candidates = _faces.values
        .where((face) => face.normalizedFamily == normalized)
        .toList();
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final aScore = (a.actualWeight - weight).abs() * 2 +
          (a.actualItalic == italic ? 0 : 1000);
      final bScore = (b.actualWeight - weight).abs() * 2 +
          (b.actualItalic == italic ? 0 : 1000);
      return aScore.compareTo(bScore);
    });
    return candidates.first;
  }

  FontFacePreview _previewFromFace(
    FontModel? font,
    String familyName,
    LoadedFontFace face, {
    required int weight,
    required bool italic,
  }) {
    final axis = face.weightAxis;
    final renderWeight = axis == null
        ? weight
        : axis.clamp(weight.toDouble()).round();
    final actualMatch = face.actualWeight == weight && face.actualItalic == italic;
    final hasExact = font?.hasExactFace(weight: weight, italic: italic) ?? false;
    final googleSupported = isGoogleFontsSupported(familyName);

    final FontFaceStatus status;
    if (axis != null) {
      status = FontFaceStatus.variable;
    } else if (actualMatch) {
      status = FontFaceStatus.actual;
    } else if (hasExact || googleSupported) {
      status = FontFaceStatus.simulated;
    } else {
      status = FontFaceStatus.approximate;
    }

    return FontFacePreview(
      status: status,
      face: face,
      family: face.registeredFamily,
      fallbacks: face.fallbacks,
      renderWeight: renderWeight,
      renderItalic: italic,
      weightAxis: axis,
      italicAxis: face.italicAxis,
      actualWeight: face.actualWeight,
      actualItalic: face.actualItalic,
      simulatedWeight: axis == null && face.actualWeight != weight,
      simulatedItalic: italic && !face.actualItalic && face.italicAxis == null,
    );
  }

  TextStyle _applyPreview(TextStyle base, FontFacePreview preview) {
    final variations = <FontVariation>[
      if (preview.weightAxis != null)
        FontVariation('wght', preview.renderWeight.toDouble()),
      if (preview.renderItalic && preview.italicAxis != null)
        const FontVariation('ital', 1),
    ];

    return base.copyWith(
      fontFamily: preview.family,
      fontFamilyFallback: preview.fallbacks,
      fontWeight: _weightFromNumber(preview.renderWeight),
      fontStyle:
          preview.renderItalic ? FontStyle.italic : FontStyle.normal,
      fontVariations: variations,
      fontSize: base.fontSize,
      color: base.color,
      height: base.height,
      letterSpacing: base.letterSpacing,
    );
  }

  /// Inserts a face into the cache for tests that cannot run `FontLoader`.
  @visibleForTesting
  void debugCacheFace(LoadedFontFace face) {
    _faces[faceKey(
      face.family,
      face.requestedWeight,
      italic: face.requestedItalic,
    )] = face;
  }

  static String _normalizeFamily(String family) =>
      family.trim().toLowerCase();

  static String _secureUrl(String url) {
    return url.startsWith('http://')
        ? 'https://${url.substring(7)}'
        : url;
  }

  static String _aliasFor(String family, int weight, bool italic) {
    if (weight == 400 && !italic) {
      return family;
    }
    return '${family}__ts_$weight${italic ? 'i' : ''}';
  }

  static int _googleAliasWeight(String alias) {
    final separator = alias.lastIndexOf('_');
    final variant = separator == -1 ? alias : alias.substring(separator + 1);
    if (variant == 'regular' || variant == 'italic' || variant.isEmpty) {
      return 400;
    }
    final match = RegExp(r'^(\d{3})').stringMatch(variant);
    return match == null ? 400 : int.parse(match);
  }

  static FontWeight _weightFromNumber(int weight) {
    for (final w in FontWeight.values) {
      if (w.value == weight) return w;
    }
    return FontWeight.w400;
  }

  static void _logFace(String event, String key, {String? detail}) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      detail == null
          ? '[FontFace] $event $key'
          : '[FontFace] $event $key ($detail)',
    );
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
