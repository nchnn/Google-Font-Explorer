# Explore screen: sticky search, scroll-to-top, 5-per-batch pagination

Date: 2026-11-15
Status: awaiting approval
Scope: `lib/screens/explore_screen.dart` (primary), `lib/services/font_paginator.dart` (new),
`lib/services/font_service.dart` (small additions), `test/`, `lib/dartpad_main.dart` (mirror)

## Intent and why

The Explore tab is the only place to browse the Google Fonts catalogue, and browsing it is
currently awkward: the search field and all filters scroll out of view behind a ~190 px
header block, there is no way back to the top of a long list, and the whole ~1,970-family
catalogue is rendered at once. A user who scrolls 40 cards down cannot search without
scrolling all the way back, and every mounted card fires its own font-file request.

The goal is navigation ergonomics and request economy, not a redesign. Every existing
feature — cards, selection, sort, category filters, variant labels, sample preview, bottom
navigation — must keep working exactly as it does now.

## Goals

1. Search bar stays reachable at any scroll position, without overlapping cards.
2. One-tap, animated return to the top that never blocks a radio button or card tap.
3. The list is revealed in batches of 5, never more, with a footer loading state.
4. Failed fetches are retryable and never discard already-loaded families.
5. No duplicate requests, no duplicate families, no stale results.
6. Font previews load lazily, at most 3 files at a time, cached, regular weight only.
7. Font selection is independent of paging, search, sorting, and filtering.
8. Animations respect reduced-motion; the header tolerates large text without clipping.

## Non-goals

- Restyling the header, cards, chips, or bottom navigation.
- Changing the API key flow, theming, or offline-fallback UX.
- Adding a backend/proxy (see Rejected approaches).

## Anti-goals

- A sticky bar that visually covers cards.
- A FAB that keeps intercepting taps after it fades out.
- A "Loading more..." spinner that is decoration around synchronous work, or an artificial
  delay that makes the app feel slower than it is.
- Claiming in code comments or UI copy that batching reduces downloaded records.

## Constraints found in the codebase

- **The Google Fonts Developer API has no pagination.** `webfonts/v1/webfonts` accepts
  `key`, `sort`, `capability`, `subset` and `family`, but no `offset`, `limit`, `page`, or
  `pageToken`. One response contains the entire catalogue. This is why the screenshot reads
  "1970 of 1970 font families".
- `FontService.fetchCatalogue` already caches per `FontSortOrder`, so a sort change costs at
  most one request, and repeats cost none.
- `ExploreScreen` is body content inside `app.dart`'s `Scaffold`, so a `Positioned` FAB at
  `bottom: 16` already clears the `NavigationBar`.
- `FontModel.category` is already normalized to `Sans Serif` / `Serif` / `Display` /
  `Handwriting` / `Monospace`, matching the existing chip labels.
- Tests run offline; the fetch throws, `_fonts` falls back to the 12 bundled `availableFonts`.
  Paging over 12 items still exercises every batch path (5 → 10 → 12).
- `lib/dartpad_main.dart` is a self-contained 2,200-line copy of the app for DartPad and is
  not imported by `main.dart`. It will diverge unless mirrored.
- `PinnedHeaderSliver` ships in Flutter 3.50 (`packages/flutter/lib/src/widgets/
  pinned_header_sliver.dart`) and pins an arbitrary child at *its intrinsic height* — "no need
  to create a `SliverPersistentHeaderDelegate` or to predict the header's size". This removes
  the fixed-extent/clipping risk of a hand-computed header height.
- Selection state lives in `_TypeStudioAppState._selectedFont` (`app.dart`) and is compared by
  family name inside `FontCard`. It is outside the Explore screen's state, so pagination and
  filtering cannot reset it. This must stay true.
- `PreviewScreen` already passes the chosen `fontWeight` into `FontText`, which forwards it to
  `ensureFontLoaded`; the non-`google_fonts` path therefore downloads exactly the variant
  being previewed. The list path must similarly not request more than regular.

## Approaches considered

### Sticky search

| | Approach | Trade-off |
|---|---|---|
| **A (chosen)** | One `CustomScrollView`; title in a normal sliver, search in a `PinnedHeaderSliver`, cards below | Title scrolls away like the screenshot, search stays, intrinsic header height so large text never clips, single scroll view, one controller, no layout shift |
| B | `Column` with fixed header + `Expanded(ListView)` | Search pinned by construction, but the ~200 px title block never scrolls away and the structure moves away from the current design |
| C | `NestedScrollView` + `SliverAppBar` | Heavier, pinning quirks with horizontally-scrolling chips, no benefit at this scale |

Chosen: **A**. Sorting controls and category chips scroll with the content; only the search
field is pinned. That satisfies every stated requirement, keeps the pinned strip to ~68 px
so the list stays tall, and stays robust under large text scaling. Chips pinned too would
require a fixed-height header containing a horizontal scroller — fragile and worth more
visual weight than the requirement asks for.

### Batching

| | Approach | Trade-off |
|---|---|---|
| **P1 (chosen)** | One cached catalogue fetch per sort; a `FontPaginator` reveals 5 at a time over the filtered+sorted list | Zero network per batch, instant appends, works offline, fully testable; the single catalogue download remains, stated plainly |
| P2 | Proxy that pages the upstream dataset server-side | Real 5-record responses, but needs new infrastructure and moves the API key off the client — out of scope |
| P3 | `offset`/`limit` API parameters | Do not exist on this endpoint |

Chosen: **P1**. Batching is honest client-side windowing: the network still fetches the
catalogue once, and the UI says so ("Showing 5 of 1,970 font families"). It is also the
faster option, because it removes per-batch latency and caps how many cards — each of which
triggers a font-file load — can mount at once.

### Batch loading indicator

No artificial delay (chosen). `_isLoadingMore` is genuine: the batch runs through an async
event-loop yield so the footer paints a real loading frame, and the state resets in `finally`.
Nothing sleeps for effect.

### DartPad copy

Mirror all changes (chosen). `lib/dartpad_main.dart` gets the same sticky header, FAB, and
paginator so both editions behave identically.

## Design

### 1. `FontPaginator` (new, `lib/services/font_paginator.dart`)

Plain, widget-free, unit-testable. Owns cursor math only.

```dart
class FontPaginator {
  static const int defaultPageSize = 5;
  FontPaginator({this.pageSize = defaultPageSize});

  final int pageSize;
  List<FontModel> _items = const [];
  int _visible = 0;

  List<FontModel> get visibleItems;   // _items.take(_visible)
  int get totalCount;
  int get visibleCount;
  bool get hasMore;                   // _visible < _items.length
  bool get isEmpty;

  void reset(List<FontModel> items);  // rewinds to first page
  Future<List<FontModel>> loadNextPage(); // appends pageSize, returns the new slice
}
```

- `reset` clamps the first page to `min(pageSize, items.length)`.
- `loadNextPage` throws `StateError` if `!hasMore`, so a stray call can never grow past the
  source. It yields once (`await Future<void>.delayed(Duration.zero)`) so the caller can
  paint a loading frame, then advances `_visible` and returns only the new slice.
- `reset` truncates and rewinds; it is the only path that changes the source, so no stale
  slice can ever be appended.

Deduplication happens when the source list is built (see below), so the paginator cannot
produce duplicate families.

### 2. Screen state in `_ExploreScreenState`

| Field | Purpose |
|---|---|
| `ScrollController _scrollController` | scrolling, FAB threshold, `animateTo(0)` |
| `FontPaginator _paginator` | cursor (page size 5) |
| `List<FontModel> _sortedCatalogue` | full result of the current fetch/sort |
| `bool _isLoadingMore` | in-flight batch guard (also drives footer) |
| `String? _loadMoreError` | footer error + Retry |
| `int _requestId` | monotonic token; async completions compare before `setState` |
| `bool _showScrollTop` | FAB visibility |
| `Timer? _fabHideTimer` | 1 s inactivity timer |
| `int _fadeFromIndex` | index at which the newest batch starts, for fade-in |

`_fonts` is replaced by `_sortedCatalogue` + `_paginator`. `dispose()` cancels
`_debounceTimer`, `_fabHideTimer`, removes the scroll listener, and disposes both the
`TextEditingController` and `ScrollController`.

**Filter pipeline** — `_rebuildResults({bool scrollToTop = false})`:
1. one pass over `_sortedCatalogue` applying query (name or category, case-insensitive) and
   category chip, collecting into a `List` while skipping names already seen
   (case-insensitive `Set<String>`).
2. `_requestId++`.
3. `_paginator.reset(filtered)`.
4. `_fadeFromIndex = 0`, `_loadMoreError = null`.
5. `setState`.

Because only 5 families are visible after a reset, the viewport's `maxScrollExtent` collapses
and Flutter clamps the offset back near the top automatically — no manual jump needed, and no
opportunity to be stranded deep inside a fresh 5-item result.

**Load more** — `_loadMore()`:

```
if (_isLoadingMore || !_paginator.hasMore) return;   // guards rapid scrolls
final id = _requestId;
setState(() { _isLoadingMore = true; _loadMoreError = null; });
try {
  final previous = _paginator.visibleCount;
  await _paginator.loadNextPage();
  if (!mounted || id != _requestId) return;          // discard stale batch
  setState(() { _isLoadingMore = false; _fadeFromIndex = previous; });
  _scheduleViewportFillCheck();
} catch (e) {
  if (!mounted || id != _requestId) return;
  setState(() {
    _isLoadingMore = false;
    _loadMoreError = 'Could not load more font families. Please try again.';
  });                                                 // cursor NOT advanced
}
```

- `_scheduleViewportFillCheck()` posts a frame callback; if `hasMore` and
  `position.maxScrollExtent < 240`, it calls `_loadMore()` again. This is what makes batches
  arrive on a tall screen where 5 cards don't overflow the viewport, and it terminates
  because `hasMore` becomes false.
- Scroll listener: on any scroll, show the FAB (if `offset > 240`) and restart the 1 s hide
  timer; when `offset >= maxScrollExtent - 400`, call `_loadMore()`.

**Retry** — the footer Retry calls `_retryLoadMore()`: if `_sortedCatalogue` is empty it
re-runs `_fetchCatalogue(forceRefresh: true)`, otherwise it re-arms `_loadMore()`. It is a
manual action only; there is no automatic retry loop.

**Fetch** — `_fetchCatalogue()` keeps the existing `FontService` call and error handling, then
stores `_sortedCatalogue` and calls `_rebuildResults()`. It captures `_requestId` before the
await and drops the response if the token moved (newer search/sort/filter won).

### 3. Sticky search header

```
CustomScrollView(controller: _scrollController, cacheExtent: 320, slivers: [
  SliverPadding(20,22,20,0)  → title + subtitle            (scrolls away)
  PinnedHeaderSliver(child: _SearchBarSurface(...))        (pinned, intrinsic height)
  SliverPadding             → count row: "5 of 1,970 font families shown"
  ... cards / empty state / initial loader ...
  SliverToBoxAdapter        → fixed-height footer slot
])
```

`PinnedHeaderSliver` measures its child and pins it, so the bar grows with the text scale
instead of clipping. `_SearchBarSurface` is an opaque `Material` (surface colour) with
vertical padding and a 1 px bottom hairline that only appears once the list is scrolled —
driven by a `ValueNotifier<bool>` the scroll listener updates, so the hairline changes without
rebuilding the whole screen. Cards pass underneath the opaque bar, never through it.

The search `TextField` keeps its current decoration, hint, prefix icon, and clear button. It
gains `textInputAction: TextInputAction.search`, a `Semantics(textField: true, label: ...)`,
and a 48 px minimum height. Debounce stays at **300 ms** (`kSearchDebounce`), inside the
required 300–400 ms window.

`cacheExtent: 320` caps how far beyond the viewport cards are built, which bounds how many
font previews can start loading during a fast fling.

### 4. Scroll-to-top FAB

```
Stack(
  children: [
    CustomScrollView(...),
    Positioned(right: 16, bottom: 16,
      child: IgnorePointer(
        ignoring: !_showScrollTop,
        child: AnimatedOpacity(
          opacity: _showScrollTop ? 1 : 0,
          duration: 200ms, curve: Curves.easeOut,
          child: Semantics(button: true, label: 'Scroll to top',
            child: Tooltip(message: 'Scroll to top',
              child: Material(elevation: 3, shape: CircleBorder(), color: surface,
                child: InkWell(onTap: _scrollToTop, customBorder: CircleBorder(),
                  child: SizedBox(48, 48, child: Icon(Icons.keyboard_arrow_up_rounded))))))))))
  ])
```

- 48×48 meets the minimum touch target; elevation 3 gives the subtle shadow.
- `_scrollToTop()` → `_scrollController.animateTo(0, duration: 480ms,
  curve: Curves.easeOutCubic)`; only if `hasClients`.
- Visibility: shown on scroll when `offset > 240`; hidden when `offset <= 240` **and** after
  1 s with no scroll events. Fade is 200 ms. `IgnorePointer` is driven by the same boolean as
  opacity, so at opacity 0 the button cannot intercept a card tap or a radio button.
- Bottom-right at `bottom: 16` sits above the nav bar and clear of the card's right-hand
  selection icon, which the card padding keeps inset.

### 5. Card fade-in

`_FadeInBatch` — a small `StatefulWidget` that animates opacity 0→1 and a 4 px upward offset
over 220 ms on first mount. Instances at `index < _fadeFromIndex` render without animating, so
scrolling back through older cards doesn't pulse. Animation is skipped entirely when
`MediaQuery.disableAnimationsOf(context)` is true.

### 6. Footer slot

A fixed-height (~76 px) area that never changes size, preventing layout shift when a batch
arrives. Contents, in priority order:

1. `_isLoadingMore` → small `CircularProgressIndicator` + "Loading more fonts..."
2. `_loadMoreError != null` → message + "Retry" `OutlinedButton`
3. `!_paginator.hasMore && totalCount > pageSize` → "All N font families loaded."
4. otherwise → empty

### 7. API-key / offline / error states

Unchanged in behavior. The existing error card and offline banner stay above the count row;
`_useOfflineCatalog` feeds `availableFonts` through the same pipeline, so offline mode pages
5 → 10 → 12 and keeps its "Connect API" action.

### 8. Font-preview loading (no waste, bounded)

The current `FontText` is the main source of unnecessary work: for a `google_fonts` family it
creates a **new** `FutureBuilder` around `GoogleFonts.pendingFonts()` on every single build, and
for other families it calls `ensureFontLoaded`, which downloads a TTF. Mounting a dozen cards
at once means a dozen of those in flight.

Changes, all inside `FontService` + `FontText` + `FontCard`:

- **One future per family.** `FontService.previewFuture(String family)` returns a memoized
  `Future<void>` keyed by family, evicting on completion failure only. `FontText` subscribes to
  that cached future instead of building a new one, so a rebuild costs nothing.
- **Regular weight only for list previews.** `FontCard` passes an explicit
  `FontWeight.w400` and `showErrorNotice: false` (already set), and `FontService` resolves the
  `regular`/`400` file for previews. No italic axis, no multi-weight fetch for a one-line sample.
- **Previews stay lazy.** `SliverList.builder` already builds only near-visible cards;
  `cacheExtent: 320` bounds the overscan. Nothing is prefetched for families the user never
  scrolls to.
- **Downloads stay capped at 3.** The existing `_downloadQueue` limiter is kept and its
  comment corrected; it is the only path that performs font-file HTTP.
- **Byte cache is bounded.** `_downloadCache` becomes an LRU capped at 64 font files
  (~15–20 MB worst case) instead of growing without limit across a 1,970-family browse. Re-visits
  still hit the cache; `_loadedFamilies` continues to short-circuit already-registered fonts.
- **Variants load on demand.** Opening Preview passes `fontWeight` through `FontText` →
  `ensureFontLoaded(weight:)`, so the chosen weight is fetched at that point only. No change to
  simulate; it is preserved and covered by a test.

### 9. Font selection is independent of the list

- `_selectedFont` remains owned by `_TypeStudioAppState`. `ExploreScreen` stays a pure consumer
  of `widget.selectedFont` / `widget.onSelectFont`, so a search, filter, sort, page reset, or
  retry cannot clear the selection.
- `FontCard.isSelected` compares family names, so the check icon and radio reflect the
  selection whenever that family is on screen — including when it reappears after being
  filtered out and back in, or after paging past it and returning.
- Clearing the search restores page 1 of the unfiltered, currently-sorted list and leaves the
  selection untouched.
- Selecting a font still jumps to Preview, exactly as today.

### 10. Accessibility

- **Reduced motion.** `MediaQuery.disableAnimationsOf(context)` is read in the FAB, the batch
  fade, and `_scrollToTop`. When true: `jumpTo(0)` instead of `animateTo`, opacity changes
  apply with `Duration.zero`, and the batch fade is skipped. Through `AnimatedOpacity`,
  `Material` ink and `AnimatedSwitcher`, Flutter already respects this where it can; the custom
  paths are made explicit.
- **Touch targets.** The FAB is 48×48; the search clear button, chips, and segmented buttons keep
  their existing targets (none are shrunk below 48 by the changes).
- **Semantics.** The FAB gets `Semantics(button: true, label: 'Scroll to top')` plus a
  `Tooltip`; the search field gets a label and `TextInputAction.search`; the footer loading
  state gets a live-region announcement ("Loading more fonts"); retry and clear buttons keep
  their existing text labels.
- **Text scaling.** `PinnedHeaderSliver` removes the fixed height entirely, so a 200 % text
  scale grows the pinned bar instead of clipping it. Cards already use `maxLines` +
  `TextOverflow.ellipsis`, so they do not overflow at large scales.
- **Contrast.** No new colours; the FAB uses `colorScheme.surface` with
  `colorScheme.onSurface` icon, and the hairline uses `dividerColor`.

### 11. Performance validation

Run against: offline mode (bundled 12), live catalogue (1,970), slow network, failing network,
rapid scrolling, rapid typing, rapid filter/sort toggling, tab switching, and small/large
viewports.

Automated in `flutter test`:

- rapid near-bottom scroll storms produce exactly one in-flight batch (spy on the paginator)
- appending a batch leaves `position.pixels` unchanged
- a batch that arrives after a query change is discarded (token test)
- switching tabs and back preserves scroll position, page count, and selection (IndexedStack)
- 200 rapid keystrokes resolve to one filter pass after the debounce
- 60 batches over a 1,970-item list keep the rendered card count bounded
- `dispose` leaves no live timers: `tester.pumpAndSettle()` after unmounting throws if a timer
  survives

Manual in a web run: pinning under fling, FAB fade timing, footer cadence, hairline transition.

No artificial delays anywhere. The only awaits are the real catalogue HTTP call, the real font
responses, and the zero-duration event-loop yield that lets the footer paint a genuine
`_isLoadingMore` frame.

## Acceptance criteria mapping

| # | Criterion | Where it is satisfied |
|---|---|---|
| 1 | Search visible while scrolling | `PinnedHeaderSliver` |
| 2 | Search without scrolling up | same, plus debounce fires wherever you are |
| 3 | Button appears during scrolling | `_showScrollTop` on `offset > 240` |
| 4 | Smooth return to top | `animateTo(0, 480ms, easeOutCubic)` (or `jumpTo` under reduced motion) |
| 5 | Fades after ~1 s idle | `_fabHideTimer` (1 s) → `AnimatedOpacity` (200 ms) |
| 6 | Invisible button can't take taps | `IgnorePointer(ignoring: !_showScrollTop)` |
| 7 | Initial batch is 5 | `FontPaginator.reset` → first page |
| 8 | Every later batch ≤ 5 | `pageSize` is fixed at 5; `loadNextPage` never exceeds it |
| 9 | Near-bottom triggers next batch | scroll listener at `maxScrollExtent - 400`, plus viewport-fill check |
| 10 | Loaded families stay visible | append-only; `reset` only on query/filter/sort change |
| 11 | Loading indicator per batch | footer slot bound to `_isLoadingMore` |
| 12 | Retry on failure | footer error state → `_retryLoadMore` |
| 13 | No duplicate requests / entries | `_isLoadingMore` + `hasMore` guards, `_requestId`, name dedupe |
| 14 | Existing features intact | filter/sort/selection flow preserved; existing tests must pass |
| 15 | Responsive, no freeze | all work is O(1) slicing; list is `SliverList.builder` |
| 16 | Lazy font previews, ≤ 3 concurrent, cached | `previewFuture` memoisation + `_downloadQueue` + LRU byte cache |
| 17 | Selection survives search/filter/sort/page reset | selection owned by `app.dart`, name comparison in `FontCard` |
| 18 | No auto-scroll on batch append | append only mutates `visibleCount`; `position.pixels` untouched |
| 19 | Reduced motion respected | `disableAnimationsOf` in FAB, fade, `_scrollToTop` |
| 20 | No clipped sticky header at large text | `PinnedHeaderSliver` intrinsic height |

Criterion 7 is satisfied at the *UI/request-scheduling* level: the app schedules one
catalogue request and reveals exactly 5 families. The endpoint itself cannot return fewer
than the whole catalogue, and the code and copy say so rather than implying otherwise.

## Testing

**`test/font_paginator_test.dart`** (new, unit)
- first page is 5; `reset` on a 12-item list → 5 visible, `hasMore` true
- three `loadNextPage` calls → 10, 12, then `hasMore` false with no over-read
- `loadNextPage` on an exhausted paginator throws and leaves `visibleCount` unchanged
- `reset` rewinds to 5 and discards the previous source
- source lists shorter than 5, and exactly 5, behave correctly
- page size is 5 and a custom size is honoured

**`test/explore_screen_ux_test.dart`** (new, widget; offline fallback path)
- initial Explore render shows exactly 5 `FontCard`s and "5 of 12 font families shown"
- dragging the list up keeps the search `TextField` hit-testable and at a fixed y position
- FAB is absent initially; after scrolling, its `AnimatedOpacity` target is 1; the wrapping
  `IgnorePointer` reports `ignoring: false`
- after 1 s idle the target opacity returns to 0 and `IgnorePointer.ignoring` is true
- tapping the FAB returns the scroll offset to 0
- reaching the bottom appends 5 more cards; `isLoadingMore` shows the footer for a frame
- searching "Roboto" resets the list to the matching family only
- a failed batch shows Retry and keeps the previous cards
- selection survives a search, a category change, a sort change, and a page reset
- reduced-motion mode uses `jumpTo` and skips the batch fade

**`test/font_service_test.dart`** (new, unit; no network)
- `previewFuture` is memoised per family (same instance on repeated calls)
- the LRU byte cache evicts past its cap while `clearCache` empties it
- a bulk register of 1,970 families keeps only bounded bytes resident

**Existing `test/widget_test.dart`** must keep passing unchanged (three tabs, theme toggle,
debounced search, empty state, clear-filters button).

## Verification

`flutter analyze` clean, `flutter test` green, plus a manual web run to confirm scrolling
feel, pinning, FAB fade, and batch cadence.

## Left to the builder

- Hairline treatment on the pinned bar.
- Whether the count row reads "Showing 5 of 1,970" or "5 of 1,970 font families shown".
- Exact fade duration/easing within the subtle range (≤ 250 ms, no bounce).
- LRU cap constant (64 chosen) and whether to expose it for tests.
