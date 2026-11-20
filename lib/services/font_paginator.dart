import 'dart:math' as math;

/// Widget-free pagination cursor over an already-fetched font catalogue.
///
/// The catalogue itself is downloaded once (the Google Fonts `webfonts/v1`
/// endpoint has no pagination parameters); this class only reveals a growing
/// prefix of that in-memory list, [defaultPageSize] items at a time, so the
/// Explore screen can append batches without ever re-fetching or discarding
/// already-loaded items.
///
/// It owns no timers, performs no I/O, and imports no widgets, which keeps it
/// directly unit-testable.
class FontPaginator<T> {
  FontPaginator({required this.idOf, this.pageSize = defaultPageSize})
    : assert(pageSize > 0, 'pageSize must be greater than zero');

  /// Identifier extractor used for de-duplicating items.
  final String Function(T) idOf;

  /// Number of items revealed per batch.
  static const int defaultPageSize = 5;

  /// Number of items revealed per batch by this instance.
  final int pageSize;

  List<T> _items = const [];

  int _visibleCount = 0;

  /// Bumped on every [reset]; lets a suspended [loadNextPage] detect that the
  /// source it started against has been replaced and abandon its batch.
  int _generation = 0;

  /// Unmodifiable view of the currently revealed items, in source order.
  List<T> get visibleItems =>
      List<T>.unmodifiable(_items.sublist(0, _visibleCount));

  /// Number of de-duplicated items in the current source list.
  int get totalCount => _items.length;

  /// Number of items currently revealed.
  int get visibleCount => _visibleCount;

  /// Whether any items are still hidden.
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
  ///
  /// Throws a [StateError] when every item is already visible. The
  /// zero-duration delay yields to the event loop so the caller can paint a
  /// loading frame before the batch is appended; it is not an artificial delay.
  ///
  /// If [reset] runs during that yield, this call returns an empty list and
  /// leaves the cursor untouched: the batch belongs to a source list that no
  /// longer exists, and advancing the new cursor would reveal rows the caller
  /// never asked for.
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
