import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'font_service.dart' show FontSortOrder;

/// Store contract for persisting and retrieving cached font catalogue responses.
abstract class CatalogueStore {
  Future<String?> read(FontSortOrder sort);
  Future<void> write(FontSortOrder sort, String body);
  Future<void> clear();
}

/// In-memory implementation of [CatalogueStore] for tests and DartPad.
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

/// Persistent [CatalogueStore] backed by [SharedPreferences].
///
/// Stores only the last-used sort under a versioned key to remain within quota.
/// Writes are best-effort: storage and quota errors are caught and swallowed,
/// and responses over ~4 MB on web are skipped.
class SharedPreferencesCatalogueStore implements CatalogueStore {
  static const String _keyPrefix = 'type_studio.catalogue.v1.';
  static const int _maxWebPayloadSize = 4 * 1024 * 1024; // 4 MB

  String _keyFor(FontSortOrder sort) => '$_keyPrefix${sort.apiValue}';

  Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> read(FontSortOrder sort) async {
    try {
      final prefs = await _getPrefs();
      return prefs?.getString(_keyFor(sort));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(FontSortOrder sort, String body) async {
    if (kIsWeb && body.length > _maxWebPayloadSize) {
      return;
    }
    try {
      final prefs = await _getPrefs();
      if (prefs == null) return;
      for (final s in FontSortOrder.values) {
        if (s != sort) {
          await prefs.remove(_keyFor(s));
        }
      }
      await prefs.setString(_keyFor(sort), body);
    } catch (_) {
      // Best-effort write; fail silently on storage/quota issues.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) return;
      for (final s in FontSortOrder.values) {
        await prefs.remove(_keyFor(s));
      }
    } catch (_) {}
  }
}
