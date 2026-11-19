# Explore Screen UX & Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Explore tab's search reachable at any scroll position, add a fade-out scroll-to-top button, and reveal the font catalogue in batches of 5 with honest loading, retry, and de-duplication.

**Architecture:** One `CustomScrollView` per screen. The title scrolls away, the search field lives in a `PinnedHeaderSliver` (intrinsic height, so large text never clips), and the card list is a keyed `SliverList.builder` fed by a new widget-free `FontPaginator` that owns all cursor math. `_ExploreScreenState` owns the request token, the in-flight guard, and the FAB timers; `app.dart` keeps owning font selection.

**Tech Stack:** Flutter 3.50 / Dart 3.14, `material_ui` (exported Flutter material), `google_fonts`, `http`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-15-explore-pagination-ux-design.md`

## Global Constraints

- Batch size is exactly **5** — `FontPaginator.defaultPageSize = 5`. No call may reveal more than 5 at once.
- Search debounce is **300 ms** (`kSearchDebounce`), inside the required 300–400 ms window.
- Simultaneous font-file downloads: **max 3** (existing `_downloadQueue` limiter, preserved).
- Font-file byte cache: **max 64 entries**, LRU.
- Scroll-to-top: shown when `offset > 240`, hidden after **1 s** idle, fade **200 ms**, tap animates **480 ms** `Curves.easeOutCubic`.
- Touch targets: **≥ 48 × 48**.
- Reduced motion (`MediaQuery.disableAnimationsOf(context)`) → `jumpTo` instead of `animateTo`, zero-duration opacity, no batch fade.
- **No artificial delays.** The only awaits are the real catalogue HTTP call, real font responses, and a zero-duration event-loop yield so the footer paints a real `_isLoadingMore` frame.
- Never auto-scroll when a batch is appended. Never discard already-loaded families on error.
- The app does not fetch the catalogue per batch: `webfonts/v1` has no pagination parameters. Copy and comments must say the catalogue downloads once.
- This directory is **not a git repository**. Each task therefore ends with `flutter analyze` plus its targeted test run instead of a commit. Do not run `git init`.
- `lib/dartpad_main.dart` is a self-contained 2,200-line DartPad copy of the app and is not imported by `main.dart`. It gets the same behaviour (Task 7).

## Review Focus

1. **A viewport taller than 5 cards.** On a tablet or landscape phone the first page does not overflow, no scroll event ever fires, and the list strands at 5 with no way forward. Expected: the list keeps filling until it scrolls or the catalogue ends.
2. **Typing a new query while a batch is still resolving.** The old batch must not append itself to the new result set. Expected: the stale batch is discarded silently.
3. **Scrolling the moment a card disappears under the FAB.** The faded button must not swallow a card tap. Expected: taps land on the card, not the invisible button.
4. **Sorting or filtering with a font selected.** Expected: the selection check survives, and the list restarts at 5 items of the new result set.
5. **A 1,970-family browse in a long session.** Expected: memory stays bounded (byte cache cap) and no per-batch network call appears.

---

### Task 1: `FontPaginator`

**Files:**
- Create: `lib/services/font_paginator.dart`
- Test: `test/font_paginator_test.dart`

**Interfaces:**
- Consumes: `FontModel` from `lib/models/font_model.dart`.
- Produces: `class FontPaginator` with `FontPaginator({int pageSize = defaultPageSize})`, `static const int defaultPageSize = 5`, `final int pageSize`, `List<FontModel> get visibleItems`, `int get totalCount`, `int get visibleCount`, `bool get hasMore`, `bool get isEmpty`, `void reset(Iterable<FontModel> items)`, `Future<List<FontModel>> loadNextPage()`. Tasks 3–7 use these names exactly.

- [ ] **Step 1: Write the failing test**

```dart
// test/font_paginator_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:type_studio/models/font_model.dart';
import 'package:type_studio/services/font_paginator.dart';

FontModel _font(String name) => FontModel(
      name: name,
      category: 'Sans Serif',
      description: 'd',
      weights: const [FontWeight.w400],
    );

List<FontModel> _fonts(int count) =>
    List.generate(count, (i) => _font('Font ${i + 1}'));

void main() {
  test('first page reveals exactly 5 of 12', () {
    final p = FontPaginator()..reset(_fonts(12));
    expect(p.visibleCount, 5);
    expect(p.visibleItems.length, 5);
    expect(p.totalCount, 12);
    expect(p.hasMore, isTrue);
    expect(p.isEmpty, isFalse);
  });

  test('loadNextPage appends 5 and stops at the end', () async {
    final p = FontPaginator()..reset(_fonts(12));
    await p.loadNextPage();
    expect(p.visibleCount, 10);
    await p.loadNextPage();
    expect(p.visibleCount, 12);
    expect(p.hasMore, isFalse);
  });

  test('loadNextPage on an exhausted paginator throws and does not grow', () async {
    final p = FontPaginator()..reset(_fonts(5));
    expect(p.hasMore, isFalse);
    await expectLater(p.loadNextPage(), throwsStateError);
    expect(p.visibleCount, 5);
  });

  test('reset rewinds and discards the previous source', () async {
    final p = FontPaginator()..reset(_fonts(12));
    await p.loadNextPage();
    expect(p.visibleCount, 10);
    p.reset(_fonts(3));
    expect(p.visibleCount, 3);
    expect(p.totalCount, 3);
    expect(p.hasMore, isFalse);
  });

  test('duplicate family names are dropped, first wins', () {
    final p = FontPaginator()
      ..reset([_font('Roboto'), _font('Lato'), _font('Roboto')]);
    expect(p.totalCount, 2);
    expect(p.visibleItems.map((f) => f.name), ['Roboto', 'Lato']);
  });

  test('empty and short sources behave', () {
    final empty = FontPaginator()..reset(const []);
    expect(empty.isEmpty, isTrue);
    expect(empty.hasMore, isFalse);
    final short = FontPaginator()..reset(_fonts(2));
    expect(short.visibleCount, 2);
    expect(short.hasMore, isFalse);
  });

  test('custom page size is honoured', () async {
    final p = FontPaginator(pageSize: 3)..reset(_fonts(7));
    expect(p.visibleCount, 3);
    await p.loadNextPage();
    expect(p.visibleCount, 6);
  });

  test('default page size is 5', () {
    expect(FontPaginator.defaultPageSize, 5);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/font_paginator_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'type_studio' ... font_paginator.dart` / `Target of URI doesn't exist`.

- [ ] **Step 3: Implement `lib/services/font_paginator.dart`**

Class shape:

```dart
class FontPaginator {
  FontPaginator({this.pageSize = defaultPageSize});
  static const int defaultPageSize = 5;
  final int pageSize;
  List<FontModel> get visibleItems;  // unmodifiable view of the first visibleCount
  int get totalCount;
  int get visibleCount;
  bool get hasMore;                  // visibleCount < totalCount
  bool get isEmpty;                  // totalCount == 0
  void reset(Iterable<FontModel> items);
  Future<List<FontModel>> loadNextPage();
}
```

Implementation notes the signature does not settle:
- `reset` stores the source as an unmodifiable `List` after a case-insensitive name de-dupe (first occurrence wins, `name.toLowerCase()` as the key), sets `_visible = math.min(pageSize, items.length)`.
- `loadNextPage` throws `StateError('No more font families to load')` when `!hasMore` (check *before* any await), then `await Future<void>.delayed(Duration.zero)` so the caller can paint a loading frame, then advances `_visible` by at most `pageSize`, clamped to `totalCount`, and returns only the newly revealed slice.
- No timers, no I/O, no widget imports.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/font_paginator_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Verify analysis**

Run: `flutter analyze lib/services/font_paginator.dart test/font_paginator_test.dart`
Expected: `No issues found!`

---

### Task 2: Memoised preview futures + bounded byte cache

**Files:**
- Modify: `lib/services/font_service.dart` (fields near lines 34–47, `clearCache` at 93, download path at 213–272)
- Test: `test/font_service_cache_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `Future<void> previewFont(String familyName, {FontModel? font})`, `int get cachedFontFileCount`, `static const int fontFileCacheLimit = 64`. Task 6 makes `FontText` use `previewFont`.

- [ ] **Step 1: Write the failing test**

```dart
// test/font_service_cache_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:type_studio/services/font_service.dart';

void main() {
  test('font file cache limit is 64', () {
    expect(FontService.fontFileCacheLimit, 64);
  });

  test('previewFont returns the same future for the same family', () {
    // A family that is not in google_fonts and has no file URL, so this never
    // touches the network: ensureFontLoaded fails fast instead.
    final a = FontService.instance.previewFont('DefinitelyNotAFontXYZ');
    final b = FontService.instance.previewFont('DefinitelyNotAFontXYZ');
    expect(identical(a, b), isTrue);
    return a.catchError((_) {});
  });

  test('previewFont memoises separately per family', () {
    final a = FontService.instance.previewFont('DefinitelyNotAFontXYZ');
    final b = FontService.instance.previewFont('AnotherMissingFontXYZ');
    expect(identical(a, b), isFalse);
    return Future.wait([a.catchError((_) {}), b.catchError((_) {})]);
  });

  test('clearCache empties the byte cache', () {
    FontService.instance.clearCache();
    expect(FontService.instance.cachedFontFileCount, 0);
  });

  test('byte cache evicts past the cap while clearCache empties it', () {
    final service = FontService.instance;
    service.clearCache();
    for (var i = 0; i < FontService.fontFileCacheLimit + 3; i++) {
      service.debugCacheFontBytes('https://example.com/$i.ttf', Uint8List.fromList([i]));
    }
    expect(service.cachedFontFileCount, FontService.fontFileCacheLimit);
    service.clearCache();
    expect(service.cachedFontFileCount, 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/font_service_cache_test.dart`
Expected: FAIL — `previewFont` / `fontFileCacheLimit` / `cachedFontFileCount` / `debugCacheFontBytes` are not defined.

- [ ] **Step 3: Implement in `lib/services/font_service.dart`**

Add a `@visibleForTesting void debugCacheFontBytes(String url, Uint8List bytes)` that routes through the same insert path as real downloads, plus:

- `static const int fontFileCacheLimit = 64;`
- `int get cachedFontFileCount => _downloadCache.length;`
- LRU insert helper `void _putFontBytes(String url, Uint8List bytes)`: remove any existing key, add, then while `length > fontFileCacheLimit` remove `_downloadCache.keys.first`.
- LRU read helper `Uint8List? _cachedFontBytes(String url)`: on hit, remove and re-insert to refresh recency, return the bytes. Replace both `_downloadCache.containsKey(...)` lookups in `_loadCustomFont` with it, and the write with `_putFontBytes`.
- `previewFont`: memoise in `final Map<String, Future<void>> _previewFutures`, keyed by family, returning the cached future when present; on error remove the entry so a retry can re-attempt. Delegate to `ensureFontLoaded(familyName, font: font, weight: FontWeight.w400)`.
- `clearCache` also clears `_previewFutures`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/font_service_cache_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Verify analysis**

Run: `flutter analyze lib/services/font_service.dart test/font_service_cache_test.dart`
Expected: `No issues found!`

---

### Task 3: Pagination core in `ExploreScreen`

**Files:**
- Modify: `lib/screens/explore_screen.dart` (state block 28–168, sliver body 317–405)
- Test: `test/explore_pagination_test.dart`

**Interfaces:**
- Consumes: `FontPaginator` (Task 1).
- Produces, inside `_ExploreScreenState` for Tasks 4–6:
  - `late final FontPaginator _paginator` — assigned in `initState` from `widget.debugPaginator ?? FontPaginator()`, because it cannot be a field initializer that reads `widget`
  - `final ScrollController _scrollController`
  - `List<FontModel> _sortedCatalogue`
  - `bool _isLoadingMore`, `String? _loadMoreError`, `int _requestId`, `int _fadeFromIndex`
  - `void _rebuildResults()`, `Future<void> _loadMore()`, `void _retryLoadMore()`, `void _scheduleViewportFillCheck()`
  - widget keys: `Key('explore-scroll')` on the `CustomScrollView`, `Key('font-list')` on the card `SliverList`, `Key('batch-footer')` on the footer.
  - an optional test seam on `ExploreScreen`: `final FontPaginator? debugPaginator` (constructor parameter, `@visibleForTesting`), used as `_paginator = widget.debugPaginator ?? FontPaginator()`. `app.dart` never passes it.
  - count copy: `'Showing $visibleCount of $totalCount font families'`.

- [ ] **Step 1: Write the failing test**

```dart
// test/explore_pagination_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:type_studio/app.dart';
import 'package:type_studio/data/font_data.dart';
import 'package:type_studio/models/font_model.dart';
import 'package:type_studio/screens/explore_screen.dart';
import 'package:type_studio/services/font_paginator.dart';
import 'package:type_studio/widgets/font_card.dart';

/// Fails every batch so the footer error path can be exercised.
class _ExplodingPaginator extends FontPaginator {
  @override
  Future<List<FontModel>> loadNextPage() async {
    await Future<void>.delayed(Duration.zero);
    throw StateError('injected failure');
  }
}

/// Resolves batches only when [complete] is called, so a query change can
/// race an in-flight batch.
class _SlowPaginator extends FontPaginator {
  Completer<void>? _gate;
  void complete() => _gate?.complete();
  @override
  Future<List<FontModel>> loadNextPage() async {
    _gate = Completer<void>();
    await _gate!.future;
    return super.loadNextPage();
  }
}

Future<void> _openExplore(WidgetTester tester, {Size size = const Size(1080, 1920)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const TypeStudioApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
  await tester.pumpAndSettle();
}

int _listItemCount(WidgetTester tester) {
  final list = tester.widget<SliverList>(find.byKey(const Key('font-list')));
  return (list.delegate as SliverChildBuilderDelegate).childCount!;
}

void main() {
  testWidgets('initial batch reveals 5 families', (tester) async {
    await _openExplore(tester);
    expect(find.textContaining('Showing 5 of'), findsOneWidget);
    expect(_listItemCount(tester), 5);
  });

  testWidgets('reaching the bottom appends 5 more without jumping', (tester) async {
    await _openExplore(tester);
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pumpAndSettle();
    final firstPageCount = _listItemCount(tester);
    expect(firstPageCount, greaterThan(5));

    final offsetBeforeAppend = position.pixels;
    expect(offsetBeforeAppend, greaterThan(0.0));

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(_listItemCount(tester), greaterThan(firstPageCount));
    expect(position.pixels, greaterThan(0.0),
        reason: 'appending a batch must not reset the scroll position');
  });

  testWidgets('the list fills a viewport taller than one batch', (tester) async {
    await _openExplore(tester, size: const Size(1400, 3000));
    expect(_listItemCount(tester), greaterThan(5),
        reason: 'five cards do not overflow this viewport, so the fill check must load more');
  });

  testWidgets('a search resets to the first batch', (tester) async {
    await _openExplore(tester);
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(_listItemCount(tester), greaterThan(5));

    await tester.enterText(find.byType(TextField).first, 'Roboto');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing 1 of 1'), findsOneWidget);
    expect(_listItemCount(tester), 1);
  });

  testWidgets('clearing a search restores the first batch', (tester) async {
    await _openExplore(tester);
    await tester.enterText(find.byType(TextField).first, 'Roboto');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(_listItemCount(tester), 5);
  });

  testWidgets('the cursor stops at the end of the catalogue', (tester) async {
    await _openExplore(tester);
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(_listItemCount(tester), 12);
    expect(find.textContaining('Showing 12 of 12'), findsOneWidget);
    expect(find.textContaining('All 12 font families'), findsOneWidget);
  });

  testWidgets('a failed batch shows Retry and keeps the loaded families', (tester) async {
    final paginator = _ExplodingPaginator();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExploreScreen(
          selectedFont: availableFonts.first,
          onSelectFont: (_) {},
          debugPaginator: paginator,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final before = _listItemCount(tester);
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(_listItemCount(tester), before, reason: 'a failed batch must not advance the cursor');
    expect(paginator.visibleCount, before);
  });

  testWidgets('a batch arriving after a query change is discarded', (tester) async {
    final paginator = _SlowPaginator();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExploreScreen(
          selectedFont: availableFonts.first,
          onSelectFont: (_) {},
          debugPaginator: paginator,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Start a batch, then change the query before it resolves.
    unawaited(paginator.loadNextPage());
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Roboto');
    await tester.pump(const Duration(milliseconds: 350));
    paginator.complete();
    await tester.pumpAndSettle();

    expect(_listItemCount(tester), 1,
        reason: 'the stale batch must not append to the new result set');
  });

  testWidgets('no duplicate families appear after several batches', (tester) async {
    await _openExplore(tester);
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -6000));
      await tester.pumpAndSettle();
    }
    final cards = find.byType(FontCard, skipOffstage: false);
    final names = tester.widgetList<FontCard>(cards).map((c) => c.font.name).toList();
    expect(names.toSet().length, names.length);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/explore_pagination_test.dart`
Expected: FAIL — `find.byKey(const Key('font-list'))` finds nothing; `Showing 5 of` not found.

- [ ] **Step 3: Implement the pagination core**

In `_ExploreScreenState`:
- Replace `List<FontModel> _fonts` with `List<FontModel> _sortedCatalogue = const []` and `final FontPaginator _paginator = FontPaginator()`.
- Add `final ScrollController _scrollController`, `bool _isLoadingMore = false`, `String? _loadMoreError`, `int _requestId = 0`, `int _fadeFromIndex = 0`, and `static const Duration kSearchDebounce = Duration(milliseconds: 300)` used by `_onSearchChanged`.
- `_rebuildResults()`: one pass over `_sortedCatalogue` applying the query (name or category, case-insensitive) and category chip; `_requestId++`; `_paginator.reset(filtered)`; `_fadeFromIndex = 0`; `_loadMoreError = null`; `setState`.
- `_loadMore()`: return early if `_isLoadingMore || !_paginator.hasMore`; capture `final id = _requestId` and `final previous = _paginator.visibleCount`; set `_isLoadingMore = true`; `await _paginator.loadNextPage()`; on success, bail unless `mounted && id == _requestId`, then `_isLoadingMore = false; _fadeFromIndex = previous;`; on error, bail on the same check, then set `_isLoadingMore = false; _loadMoreError = 'Could not load more font families. Please try again.';` — never touch the cursor.
- `_scheduleViewportFillCheck()`: `addPostFrameCallback` that returns unless mounted, then if `_paginator.hasMore && !_isLoadingMore && (_scrollController.hasClients ? _scrollController.position.maxScrollExtent < 240 : true)` calls `_loadMore()`.
- Scroll listener added in `initState`: if `offset >= position.maxScrollExtent - 400` call `_loadMore()`. (The FAB thresholds land in Task 5.)
- `_fetchCatalogue()`: capture `final id = _requestId`, keep the existing `FontService.fetchCatalogue` + `FontApiException` handling, and on success assign `_sortedCatalogue` then call `_rebuildResults()` only when `id == _requestId`. Keep `_useOfflineCatalog` routing `availableFonts` through the same path.
- Wire `_onSearchChanged`, `_onClearSearch`, `_handleSortChanged`, and the category chips' `onSelected` to `_rebuildResults()` in addition to their existing state changes. Sort still refetches for a new `FontSortOrder` via the existing cache.
- Replace `_filteredFonts` with `_paginator.visibleItems`.
- Card sliver: `SliverList.builder` with `key: const Key('font-list')`, `itemCount: _paginator.visibleItems.length`.
- Count row: `'Showing ${_paginator.visibleCount} of ${_paginator.totalCount} font families'`.
- Footer: a fixed-height `SizedBox(height: 76, key: const Key('batch-footer'))` sliver showing, in priority order, the `_isLoadingMore` spinner + "Loading more fonts..." (`CircularProgressIndicator` 18 px), the `_loadMoreError` row with a `Retry` `OutlinedButton` calling `_retryLoadMore`, `All ${total} font families loaded.` when `!hasMore && total > 5`, else nothing.
- `_retryLoadMore()`: if `_sortedCatalogue.isEmpty` re-run the catalogue fetch with `forceRefresh: true`, else `_loadMore()`.
- After a successful fetch, call `_scheduleViewportFillCheck()`.
- `dispose`: remove the listener, dispose `_scrollController`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/explore_pagination_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Confirm the pre-existing suite still passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS, 5 tests. If the empty-state or clear-search test fails, the cause is the reset path — fix `_rebuildResults`, not the test.

- [ ] **Step 6: Verify analysis**

Run: `flutter analyze lib/screens/explore_screen.dart test/explore_pagination_test.dart`
Expected: `No issues found!`

---

### Task 4: Sticky search bar

**Files:**
- Modify: `lib/screens/explore_screen.dart` (sliver list at 176–315, `build` at 170)
- Test: `test/explore_sticky_search_test.dart`

**Interfaces:**
- Consumes: `_scrollController`, `_paginator`, `_rebuildResults` from Task 3.
- Produces: `Key('pinned-search')` on the pinned header and `ValueNotifier<bool> _isScrolled` for the hairline. The count row stays a normal scrolling sliver directly below the pinned bar; only the search bar is pinned.

- [ ] **Step 1: Write the failing test**

```dart
// test/explore_sticky_search_test.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:type_studio/app.dart';
import 'package:type_studio/data/font_data.dart';
import 'package:type_studio/screens/explore_screen.dart';

Future<void> _openExplore(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const TypeStudioApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search stays at a fixed position while the list scrolls', (tester) async {
    await _openExplore(tester);
    expect(find.byKey(const Key('pinned-search')), findsOneWidget);

    // The bar only pins once the title above it has scrolled off, so measure
    // the "fixed" position from an already-scrolled state.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -1200));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byKey(const Key('pinned-search')));

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -300));
    await tester.pumpAndSettle();

    final after = tester.getTopLeft(find.byKey(const Key('pinned-search')));
    expect(after.dy, closeTo(before.dy, 1.0),
        reason: 'the bar must stay pinned while the list scrolls');
  });

  testWidgets('title scrolls away but search remains tappable', (tester) async {
    await _openExplore(tester);
    expect(find.text('Explore fonts'), findsOneWidget);

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Explore fonts'), findsNothing,
        reason: 'the title must scroll away once the bar is pinned');

    final search = find.byType(TextField).first;
    expect(search, findsOneWidget);
    expect(tester.getRect(search).top, greaterThanOrEqualTo(0.0));
    await tester.enterText(search, 'Roboto');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.textContaining('Showing 1 of 1'), findsOneWidget);
  });

  testWidgets('cards scroll beneath the pinned bar, which keeps the taps', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Pumped standalone so a tap that falls through to a card is observable.
    var selections = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExploreScreen(
          selectedFont: availableFonts.first,
          onSelectFont: (_) => selections++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -400));
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byKey(const Key('pinned-search')));
    final underBar = find.byType(Card).evaluate().where((element) {
      return tester.getRect(find.byWidget(element.widget)).overlaps(bar);
    });
    expect(underBar, isNotEmpty,
        reason: 'the list must actually scroll underneath the pinned bar');

    await tester.tapAt(bar.center);
    await tester.pump(const Duration(milliseconds: 300));
    expect(selections, 0,
        reason: 'a tap on the pinned bar must not reach the card beneath it');
  });

  testWidgets('search bar grows with text scale instead of clipping', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // MediaQuery must sit *inside* MaterialApp: MaterialApp builds its own
    // MediaQuery from the view and would discard an ancestor one.
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: Scaffold(
          body: ExploreScreen(
            selectedFont: availableFonts.first,
            onSelectFont: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('pinned-search')), findsOneWidget);
    final bar = tester.getRect(find.byKey(const Key('pinned-search')));
    final field = tester.getRect(find.byType(TextField).first);
    expect(field.bottom, lessThanOrEqualTo(bar.bottom + 1.0),
        reason: 'the pinned bar must be tall enough for the scaled field');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/explore_sticky_search_test.dart`
Expected: FAIL — `find.byKey(const Key('pinned-search'))` finds nothing.

- [ ] **Step 3: Implement the pinned header**

- Extract the search `TextField` (with its decoration, hint, prefix icon, and clear `suffixIcon`) into a private widget `_SearchBar` that takes `controller`, `onChanged`, `onClear`, and `showClear`.
- Wrap it in `PinnedHeaderSliver(child: Material(key: const Key('pinned-search'), color: theme.colorScheme.surface, child: Padding(...)))` placed directly after the title/subtitle sliver and before the count row. The key goes on the `Material` box, not the sliver: `tester.getRect` needs a `RenderBox`, and a keyed `PinnedHeaderSliver` resolves to a `RenderSliver`.
- The `Material` must be the default (non-transparent) type with an opaque colour: that is what absorbs taps aimed at the bar's padding, so cards scrolling under it are not tappable through it.
- Add a `ValueNotifier<bool> _isScrolled` updated by the scroll listener (`offset > 4`); the bar's bottom edge uses a 1 px `Container` keyed `Key('pinned-search-hairline')` whose colour is `dividerColor` with alpha 0 when unscrolled, via `ValueListenableBuilder` so only the hairline rebuilds.
- Set a 320 px cache extent with `scrollCacheExtent: const ScrollCacheExtent.pixels(320)` (`cacheExtent` is deprecated since v3.41; `ScrollCacheExtent.pixels` is its exact replacement).
- Add `Semantics(label: 'Search font family or category')` and `textInputAction: TextInputAction.search` to the field; keep the existing hint text verbatim.
- Move the sort row and category chips out of the pinned area so they scroll with the content. Return the count row (pinned in Task 3) to the scrolling slivers, directly below the pinned bar, so it scrolls away instead of consuming a second pinned band.
- Do not add a `_pinnedSearchVisible` getter: nothing reads it, and `flutter analyze` flags unused private members.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/explore_sticky_search_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Re-run the pagination and legacy suites**

Run: `flutter test test/explore_pagination_test.dart test/widget_test.dart`
Expected: PASS both.

- [ ] **Step 6: Verify analysis**

Run: `flutter analyze lib/screens/explore_screen.dart test/explore_sticky_search_test.dart`
Expected: `No issues found!`

---

### Task 5: Scroll-to-top button

**Files:**
- Modify: `lib/screens/explore_screen.dart` (`build` return, scroll listener, `dispose`)
- Test: `test/explore_scroll_top_test.dart`

**Interfaces:**
- Consumes: `_scrollController`, `_rebuildResults`.
- Produces: `bool _showScrollTop`, `Timer? _fabHideTimer`, `void _scrollToTop()`, and keys `Key('scroll-top-button')`, `Key('scroll-top-opacity')`, `Key('scroll-top-ignore')`.

- [ ] **Step 1: Write the failing test**

```dart
// test/explore_scroll_top_test.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:type_studio/app.dart';
import 'package:type_studio/data/font_data.dart';
import 'package:type_studio/screens/explore_screen.dart';

Future<void> _openExplore(WidgetTester tester) async {
  // Shorter than a phone so the twelve bundled families genuinely overflow:
  // on a 1920-high viewport the fill check can reveal the whole catalogue and
  // leave nothing to scroll, which would make every drag below a no-op.
  tester.view.physicalSize = const Size(1080, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const TypeStudioApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
  await tester.pumpAndSettle();
}

double _opacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byKey(const Key('scroll-top-opacity'))).opacity;

bool _ignoring(WidgetTester tester) =>
    tester.widget<IgnorePointer>(find.byKey(const Key('scroll-top-ignore'))).ignoring;

void main() {
  testWidgets('hidden at the top and non-interactive', (tester) async {
    await _openExplore(tester);
    expect(_opacity(tester), 0);
    expect(_ignoring(tester), isTrue);
  });

  testWidgets('appears after scrolling down, interactive', (tester) async {
    await _openExplore(tester);
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_opacity(tester), 1);
    expect(_ignoring(tester), isFalse);
  });

  testWidgets('fades out and becomes non-interactive after 1s idle', (tester) async {
    await _openExplore(tester);
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_opacity(tester), 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_opacity(tester), 0);
    expect(_ignoring(tester), isTrue);
  });

  testWidgets('hidden button does not intercept a tap', (tester) async {
    tester.view.physicalSize = const Size(1080, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Pumped standalone so a tap that falls through to a card cannot navigate away.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExploreScreen(
          selectedFont: availableFonts.first,
          onSelectFont: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -600));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_ignoring(tester), isTrue);

    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final offsetBefore = position.pixels;
    await tester.tapAt(tester.getCenter(find.byKey(const Key('scroll-top-button'))));
    await tester.pumpAndSettle();
    expect(position.pixels, offsetBefore,
        reason: 'a faded button must not swallow the tap and scroll to the top');
  });

  testWidgets('tapping it animates back to the top', (tester) async {
    await _openExplore(tester);
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 250));
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels, greaterThan(0));

    await tester.tap(find.byKey(const Key('scroll-top-button')));
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
  });

  testWidgets('unmounting leaves no live timers', (tester) async {
    await _openExplore(tester);
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -600));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion jumps to the top instead of animating', (tester) async {
    tester.view.physicalSize = const Size(1080, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // copyWith, not a bare MediaQueryData: a bare one would zero the size and
    // break layout. The MediaQuery must also sit inside MaterialApp.
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Scaffold(
            body: ExploreScreen(
              selectedFont: availableFonts.first,
              onSelectFont: (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 250));
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels, greaterThan(0));

    await tester.tap(find.byKey(const Key('scroll-top-button')));
    await tester.pump();
    expect(position.pixels, 0,
        reason: 'reduced motion must jump, not animate, back to the top');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/explore_scroll_top_test.dart`
Expected: FAIL — `find.byKey(const Key('scroll-top-opacity'))` finds nothing.

- [ ] **Step 3: Implement the button**

- In `build`, return `Stack(children: [CustomScrollView(...), Positioned(right: 16, bottom: 16, child: ...)])`.
- The overlay: `IgnorePointer(key: const Key('scroll-top-ignore'), ignoring: !_showScrollTop, child: AnimatedOpacity(key: const Key('scroll-top-opacity'), opacity: _showScrollTop ? 1 : 0, duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200), curve: Curves.easeOut, child: Tooltip(message: 'Scroll to top', child: Semantics(button: true, label: 'Scroll to top', child: Material(key: const Key('scroll-top-button'), elevation: 3, color: theme.colorScheme.surface, shape: const CircleBorder(), clipBehavior: Clip.antiAlias, child: InkWell(onTap: _scrollToTop, customBorder: const CircleBorder(), child: const SizedBox(width: 48, height: 48, child: Icon(Icons.keyboard_arrow_up_rounded)))))))`.
- Scroll listener additions: `if (offset > 240 && !_showScrollTop) setState(() => _showScrollTop = true);` restart `_fabHideTimer = Timer(const Duration(seconds: 1), () { if (mounted) setState(() => _showScrollTop = false); })` on every scroll event; if `offset <= 240` and `_showScrollTop`, cancel the timer and hide immediately.
- `_scrollToTop()`: `final position = _scrollController.position; if (MediaQuery.disableAnimationsOf(context)) position.jumpTo(0) else _scrollController.animateTo(0, duration: const Duration(milliseconds: 480), curve: Curves.easeOutCubic);` then `_fabHideTimer?.cancel();` and hide.
- Guard `animateTo` with `hasClients`; cancel the timer in `dispose`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/explore_scroll_top_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Verify analysis**

Run: `flutter analyze lib/screens/explore_screen.dart test/explore_scroll_top_test.dart`
Expected: `No issues found!`

---

### Task 6: Batch fade, reduced motion, and selection safety

**Files:**
- Create: `lib/widgets/fade_in_batch.dart`
- Modify: `lib/widgets/font_card.dart` (preview weight), `lib/widgets/font_text.dart` (use `previewFont`), `lib/screens/explore_screen.dart` (wrap items)
- Test: `test/explore_selection_fade_test.dart`

**Interfaces:**
- Consumes: `_fadeFromIndex` (Task 3), `FontService.previewFont` (Task 2).
- Produces: `class FadeInBatch extends StatefulWidget` with `const FadeInBatch({super.key, required this.index, required this.fadeFrom, required this.child})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/explore_selection_fade_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:type_studio/app.dart';
import 'package:type_studio/widgets/fade_in_batch.dart';
import 'package:type_studio/widgets/font_text.dart';

Future<void> _openExplore(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const TypeStudioApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
  await tester.pumpAndSettle();
}

Future<void> _pumpFadeInBatch(
  WidgetTester tester, {
  required int index,
  required int fadeFrom,
  bool disableAnimations = false,
}) async {
  // copyWith, not a bare MediaQueryData: a bare one would zero the size.
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: FadeInBatch(
          index: index,
          fadeFrom: fadeFrom,
          child: const Text('card'),
        ),
      ),
    ),
  ));
  await tester.pump();
}

Finder _fadeInside() => find.descendant(
      of: find.byType(FadeInBatch),
      matching: find.byType(FadeTransition),
    );

void main() {
  testWidgets('selection survives a search and clearing it', (tester) async {
    await _openExplore(tester);
    // Roboto is selected by default (availableFonts.first).
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Lato');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing,
        reason: 'Lato is shown, Roboto is filtered out, but the selection is kept');

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget,
        reason: 'clearing the search restores Roboto and its selected state');
  });

  testWidgets('selection survives a category change and a page reset', (tester) async {
    await _openExplore(tester);

    final serif = find.widgetWithText(FilterChip, 'Serif');
    await tester.ensureVisible(serif);
    await tester.tap(serif);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing,
        reason: 'Roboto is not a serif, so the selection has no visible card');

    final all = find.widgetWithText(FilterChip, 'All');
    await tester.ensureVisible(all);
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('appended batch items are inside a fade range', (tester) async {
    await _openExplore(tester);
    final cards = tester
        .widgetList<FadeInBatch>(find.byType(FadeInBatch, skipOffstage: false))
        .toList();
    expect(cards.length, greaterThan(5),
        reason: 'the viewport fill check must have appended a batch');

    final boundaries = cards.map((card) => card.fadeFrom).toSet();
    expect(boundaries.length, 1, reason: 'every card must share one fade boundary');
    final fadeFrom = boundaries.single;
    expect(fadeFrom, greaterThan(0),
        reason: 'an appended batch must mark where the fade starts');
    expect(cards.where((card) => card.index >= fadeFrom), isNotEmpty,
        reason: 'the newly appended cards must be inside the fade range');
  });

  testWidgets('batch items fade in when animations are enabled', (tester) async {
    await _pumpFadeInBatch(tester, index: 2, fadeFrom: 0);
    expect(_fadeInside(), findsOneWidget);

    final fade = tester.widget<FadeTransition>(_fadeInside());
    expect(fade.opacity.value, 0.0);
    await tester.pump(const Duration(milliseconds: 240));
    expect(fade.opacity.value, 1.0);
  });

  testWidgets('items before the fade boundary never animate', (tester) async {
    await _pumpFadeInBatch(tester, index: 1, fadeFrom: 2);
    expect(_fadeInside(), findsNothing);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('reduced motion renders batch items without a fade', (tester) async {
    await _pumpFadeInBatch(tester, index: 2, fadeFrom: 0, disableAnimations: true);
    expect(_fadeInside(), findsNothing);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('list previews request regular weight only', (tester) async {
    await _openExplore(tester);
    final preview =
        tester.widgetList<FontText>(find.byType(FontText, skipOffstage: false)).first;
    expect(preview.style.fontWeight, FontWeight.w400,
        reason: 'list previews must not request a heavier variant');
    expect(preview.showErrorNotice, isFalse);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/explore_selection_fade_test.dart`
Expected: FAIL — `fade_in_batch.dart` does not exist.

- [ ] **Step 3: Implement**

- `FadeInBatch`: a `StatefulWidget` holding an `AnimationController` (220 ms, `Curves.easeOut`) started in `initState`; returns plain `child` when `index < fadeFrom` or when `MediaQuery.disableAnimationsOf(context)`; otherwise `FadeTransition(opacity: _controller, child: child)`. Read reduced motion in `build`, not `initState`. Dispose the controller.
- In the card sliver, wrap each `FontCard` with `FadeInBatch(index: index, fadeFrom: _fadeFromIndex, child: ...)`.
- `FontCard`: pass `fontWeight: FontWeight.w400` explicitly to the preview `FontText` and keep `showErrorNotice: false`.
- `FontText`: in the `isGoogleFonts` branch, replace `future: GoogleFonts.pendingFonts()` with `future: FontService.instance.previewFont(family)` so the future is memoised across rebuilds. Leave the `FontLoader` branch's `ensureFontLoaded` call as-is (it dedupes internally).
- `_selectFont` in `app.dart` is unchanged; do not move selection state.
- **Binding carry-over from Task 5**: inside `_rebuildResults`, clear the scroll-to-top button in the same `setState` that resets the paginator (`_fabHideTimer?.cancel(); _fabHideTimer = null; _showScrollTop = false;`). A reset clamps the scroll offset silently, so without this the button can stay visible and interactive over a card for up to a second after a search, chip tap or sort change.
- **Binding carry-over from Task 5**: move the scroll-to-top overlay above the floating navigation pill (`bottom: kFloatingPillNavigationClearance + 16` instead of `bottom: 16`). The plan's `16` predates the pill; at 360 dp they collide. Do not modify the pill itself.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/explore_selection_fade_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Run the whole suite**

Run: `flutter test`
Expected: PASS, all files.

- [ ] **Step 6: Verify analysis**

Run: `flutter analyze`
Expected: `No issues found!`

---

### Task 7: Mirror into the DartPad edition

**Files:**
- Modify: `lib/dartpad_main.dart` (`FontService` around 662–760, `FontText` around 891–990, `FontCard` around 1120, Explore screen around 1810–2000)

**Interfaces:**
- Consumes: nothing from `lib/`; this file is self-contained and must not import project files.
- Produces: the same user-visible behaviour in DartPad.

- [ ] **Step 1: Add the paginator and cached-preview helpers inside the file**

Copy the `FontPaginator` class body from `lib/services/font_paginator.dart` into `dartpad_main.dart` verbatim (it has no imports beyond `dart:math`). Add `previewFont`, `fontFileCacheLimit`, `cachedFontFileCount`, `_putFontBytes`, `_cachedFontBytes`, and `_previewFutures` to the file's `FontService`, matching Task 2.

- [ ] **Step 2: Replace the Explore screen's body with the paginated, pinned version**

Port the `build` structure from `lib/screens/explore_screen.dart`: `Stack` + `CustomScrollView` with `PinnedHeaderSliver`, keyed card list, fixed footer, FAB overlay, and the same state fields and guards. Keep the file's existing widget names.

- [ ] **Step 3: Verify the copy compiles**

Run: `flutter analyze lib/dartpad_main.dart`
Expected: `No issues found!` (this file carries `// ignore_for_file: deprecated_member_use` at the top and is analysed as part of the project).

- [ ] **Step 4: Diff the behaviour by inspection**

Confirm by reading that both files have: `defaultPageSize = 5`, a 1 s FAB hide timer, `IgnorePointer(ignoring: !_showScrollTop)`, a `_requestId` token, and `Showing $visible of $total font families`.

---

### Task 8: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Analyse the whole project**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run every test**

Run: `flutter test`
Expected: all files pass, 0 failures.

- [ ] **Step 3: Build for web**

Run: `flutter build web --release`
Expected: `✓ Built build\web`.

- [ ] **Step 4: Run the app and exercise the acceptance list**

Run: `flutter run -d chrome --web-port 8080`
Check, in order: search pinned while scrolling; search from mid-list; FAB appears on scroll, fades after ~1 s, is untappable when faded; tap returns smoothly to the top; 5 cards initially; bottom triggers 5 more; footer spinner on each batch; cards never swallowed; sort A–Z and Trending still reorder; each category chip filters; selecting a font still opens Preview and keeps its check; clearing the search restores 5 items.

- [ ] **Step 5: Record the honest limits in the README**

Append a short "Catalogue paging" note: the Google Fonts Developer API has no offset/limit parameters, so the catalogue is downloaded once per sort and cached; the 5-per-batch behaviour is client-side windowing and does not reduce downloaded records. Mention the 64-entry font byte cache and the 3-download cap.
