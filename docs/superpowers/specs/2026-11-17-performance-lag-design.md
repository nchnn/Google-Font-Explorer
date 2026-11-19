# Explore performance: remove catalogue and preview lag

Date: 2026-11-17
Status: awaiting approval
Scope: `lib/services/font_service.dart`, `lib/services/font_paginator.dart`,
`lib/screens/explore_screen.dart`, `lib/widgets/font_text.dart`, `lib/app.dart`,
new `lib/models/catalogue_entry.dart`, new `lib/services/catalogue_store.dart`,
`pubspec.yaml`, `test/`, `lib/dartpad_main.dart` (mirror), `README.md`

## Intent and why

Browsing the Explore tab is slow in three distinct ways:

1. The first load and every sort change decode the whole ~1,800-family Google
   Fonts response and build a full `FontModel` for every family on the UI
   thread, so the first frame stalls.
2. Every visible card triggers its own font-file path, and fonts supported by
   `google_fonts` are gated behind `GoogleFonts.pendingFonts()`, so all cards
   wait for the slowest pending download. A new batch of five cards can queue
   several `.ttf` downloads through a three-slot limiter.
3. Each loading card paints two `Text` widgets and, on the dynamic path, its own
   `CircularProgressIndicator`. Several ticking spinners plus doubled text
   layout make scrolling and the first batch janky.

The goal is to remove the work that blocks frames, not to redesign the screen.
Paging (5 per batch), search (300 ms debounce), category filters, selection,
sorting, the 64-entry byte cache, the 3-download limit, and the Floating Pill
navigation must all keep working exactly as they do now.

## Goals

1. First frame paints before the catalogue is decoded; the parse never blocks
   the frame that shows the screen.
2. Catalogue decode and modeling move off the UI thread on native platforms;
   web decodes after first paint and does not repeat the full network fetch on
   a warm launch.
3. A warm launch (cached catalogue) paints the first batch without waiting on
   the network, then revalidates in the background.
4. Each preview family completes independently; a slow or failed family never
   blocks another card.
5. Loading cards use one static placeholder, no per-card spinner.
6. Search filters using precomputed lowercase keys, not per-keystroke
   lowercasing of every family.
7. The next batch's regular-weight font bytes are prefetched during idle so
   scrolling into a batch does not start from a cold network call.
8. All 68 existing tests plus new tests pass; `flutter analyze` is clean;
   `flutter build web --release` succeeds.

## Non-goals

- Changing the 5-per-batch page size, the 300 ms search debounce, the 64-entry
  LRU cap, or the 3-concurrent-download limit.
- Redesigning the Explore screen, cards, chips, FAB, or pinned search bar.
- A backend, proxy, service worker, or offline sync engine.
- Replacing `google_fonts` for the bundled/offline catalogue.
- Changing the API-key flow or theming.
- Editing the user-owned `floating_pill_navigation.dart`.

## Anti-goals

- A background revalidation that clears a search, resets scroll, or loses the
  selected font.
- Prefetch that competes with visible cards, runs unbounded, or evicts visible
  font bytes.
- Persistence that crashes startup or blocks the UI when storage is full.
- Skeleton UI that pretends data exists; the placeholder must be visibly a
  placeholder.
- Copy or comments that claim the first-ever load downloads fewer records.
- Caching a stale catalogue forever without a revalidation attempt.

## Constraints found in the codebase

- **The Google Fonts Developer API has no pagination.** `webfonts/v1/webfonts`
  returns the entire catalogue in one response. Paging is client-side.
- `FontService.fetchCatalogue` already caches per `FontSortOrder`, but only in
  memory, and it maps every item to `FontModel` before returning.
- `FontPaginator` is typed to `FontModel` and de-duplicates by
  `item.name.toLowerCase()` in `reset`.
- `ExploreScreen` stores `_sortedCatalogue` as `List<FontModel>` and filters all
  of it in `_rebuildResults` on every search/category/sort change.
- `FontText` branches on `FontService.isGoogleFontsSupported`; the
  `google_fonts` branch calls `previewFont`, which reaches
  `ensureFontLoaded` and awaits `GoogleFonts.pendingFonts()`.
- `_loadCustomFont` downloads a file, registers it with `FontLoader`, and
  records the family in `_loadedFamilies`. The same path can serve any family
  whose `FontModel.files` map has a URL — including API families that are also
  in `google_fonts`.
- `app.dart` holds `FontModel _selectedFont`; `PreviewScreen` reads
  `selectedFont.weights` and `FontText` reads the family name, so a revealed
  family must materialize a complete `FontModel`.
- `FontService` is a singleton with no HTTP-client seam, so failure and
  independence tests need an injectable `http.Client`.
- `lib/dartpad_main.dart` is a self-contained 2,200-line mirror. DartPad cannot
  use `shared_preferences` or `dart:io`; the README already documents in-memory
  caching for DartPad.
- This directory is not a git repository. Tasks end with `flutter analyze` and
  targeted test runs, not commits.
- Flutter 3.50 / Dart 3.14, `material_ui` import style, `http: ^1.2.0`,
  `google_fonts: ^9.0.0`.

## Approaches considered

### A. Surgical pass (no new dependencies)

Lazy-model the catalogue, replace the global `pendingFonts()` gate with
per-family FontLoader futures, simplify the loading placeholder, and precompute
search keys. Platform-agnostic and low risk, but leaves the raw `json.decode`
on the UI thread and the cold-start network fetch untouched. Does not meet the
"rid the lag" bar.

### B. Full pass (chosen)

Everything in A, plus:

- move `json.decode` and catalogue construction off the UI thread on native;
- paint first, then decode on web (no isolates) and verify whether `compute`
  uses a worker on the pinned Flutter build;
- persist the last-used sort's catalogue for a warm start, with best-effort
  writes and background revalidation;
- prefetch the next batch's regular-weight font bytes during idle.

Higher risk (one dependency, platform branches, revalidation races), but it is
the only option that removes the cold-start wait and the parse stall. The user
chose B.

## The design

### 1. Catalogue entry and lazy modeling

New `lib/models/catalogue_entry.dart`:

- `CatalogueEntry` holds `name`, display `category`, `searchName`,
  `searchCategory`, and the raw decoded `Map<String, dynamic>`. It exposes
  `late final FontModel model = FontModel.fromJson(raw)`.
- Two constructors: `CatalogueEntry.fromJson(Map)` for API items and
  `CatalogueEntry.fromModel(FontModel)` for the bundled/offline catalogue, which
  has no raw API map.
- `FontCatalogue` holds `List<CatalogueEntry> entries` and the raw response body
  used for persistence and equality checks.
- The constructor is cheap: extract `family`, normalize the category, compute
  two lowercase strings. The expensive `files`/`variants`/`subsets` parsing
  happens only when a family is actually revealed or selected.
- Expose the existing category normalizer as a public static helper on
  `FontModel` (rename `_formatCategory`) so the entry does not build a model to
  get a display category.

`FontService.registerFonts` keeps working for bundled models by wrapping each
`FontModel` in an already-materialized entry. `getFont(name)` returns
`entry.model`. `clearCache` clears only the in-memory API catalogue and its
entries; the bundled registry and the persisted body survive, so a test reset
does not delete the warm-start cache or the offline fallback.

### 2. Off-thread decode and paint-first

`FontService.fetchCatalogue` returns `FontCatalogue` instead of
`List<FontModel>`:

- **Native (Android/iOS/Windows/macOS/Linux):** `Isolate.run` (or `compute`)
  decodes the response body and returns the `items` list. The transfer copy is
  accepted; it is far cheaper than decoding on the UI thread. The main isolate
  then builds the cheap `CatalogueEntry` index.
- **Web/DartPad:** no isolates. Schedule the decode after the current frame
  (post-frame callback or a zero-duration task) so the skeleton paints first.
  If the pinned Flutter's `compute` runs on a real worker on web, use it;
  otherwise keep the paint-first path. This is verified during implementation,
  not assumed.
- The response body is parsed once; `CatalogueEntry.model` is built only for
  the revealed batch (5) or a selected font.

### 3. Generic paginator

`FontPaginator<T>` with a required `String Function(T) idOf`:

- `reset(Iterable<T>)` de-duplicates by `idOf(item).toLowerCase()`, first
  occurrence wins, and rewinds to the first page.
- `visibleItems` returns `List<T>`; `loadNextPage` returns the newly revealed
  slice with the same generation guard.
- `defaultPageSize` stays 5.
- Existing `FontModel` tests construct `FontPaginator<FontModel>(idOf: (f) =>
  f.name)`. The fake paginator in `explore_pagination_test.dart` is updated to
  the generic type.

`ExploreScreen` paginates over `List<CatalogueEntry>` and maps the visible
slice to `entry.model` for `FontCard`.

### 4. Persistence and warm start

New `lib/services/catalogue_store.dart`:

- `abstract class CatalogueStore { Future<String?> read(FontSortOrder sort);
  Future<void> write(FontSortOrder sort, String body); Future<void> clear(); }`
- `SharedPreferencesCatalogueStore` uses `shared_preferences` (new dependency)
  and stores the **last-used sort only** under a versioned key
  (`type_studio.catalogue.v1.<sort>`). Writing a new sort clears the previous
  one, which keeps the footprint to one response and stays inside typical
  localStorage quotas.
- Writes are best-effort: catch storage/quota errors, skip any body over a
  safe size on web (~4 MB), and never fail startup because persistence failed.
- `MemoryCatalogueStore` is used by tests and the DartPad mirror.

`FontService.fetchCatalogue(sort, forceRefresh)`:

1. Return the in-memory catalogue if present and not forcing a refresh.
2. If not forcing, try the store. Decode the cached body (off-thread/paint-first
   as above), register it, and return it with `isFromCache: true`.
3. Fetch live. On success, decode, register, write to the store, and return.
4. If the API key is missing and a cached body exists, return the cache instead
   of throwing. A missing key only fails when there is nothing cached.

`ExploreScreen._fetchCatalogue`:

- Keep a `List<CatalogueEntry> _results` field for the current filtered result
  set (the list the paginator windows over) and a `FontCatalogue?
  _pendingCatalogue` for a revalidated catalogue that could not be applied
  safely yet. A natural reset applies `_pendingCatalogue` before filtering.
- If a cached catalogue is returned, show it immediately (no blocking spinner)
  and start `_revalidateCatalogue()` in the background.
- Revalidation fetches with `forceRefresh: true`. If the body is unchanged,
  do nothing. If changed:
  - apply immediately only when the user has not interacted: empty query,
    category `All`, `visibleCount <= pageSize`, scroll offset at/near the top,
    and no batch in flight;
  - otherwise keep the current list untouched, persist the fresh body, and hold
    it as `_pendingCatalogue` to apply on the next natural reset (clear
    search, category change, sort change, or screen re-entry).
- Revalidation errors are silent; the cached list stays usable.

### 5. Per-family preview completion

`FontService.ensureFontLoaded` chooses the engine in this order:

1. If the family's `FontModel.files` has a URL → `_loadCustomFont` (the
   existing FontLoader path). This completes per family and never calls
   `pendingFonts()`.
2. Otherwise, if `google_fonts` supports it → the existing google_fonts path
   (bundled fallback only).
3. Otherwise → the existing missing-URL error with Retry.

This deliberately routes API families that also exist in `google_fonts`
(e.g. Roboto) through FontLoader, so each card completes independently.
`previewFont` keeps its per-family memoization and failure eviction.

`FontText` build:

- If `isFontLoaded(family)` → `Text(fontFamily: family)`.
- Else if the registry entry has a file URL → FutureBuilder on the per-family
  preview future; waiting shows one static placeholder `Text`; error shows the
  existing fallback.
- Else if `google_fonts` supports the family → the existing google_fonts
  FutureBuilder path, also with the static placeholder.
- Else → the existing fallback.
- Remove the per-card `CircularProgressIndicator`. Keep `showErrorNotice` and
  the Retry behavior unchanged.

`app.dart._selectFont` calls `ensureFontLoaded` for every selected family
(the service decides the engine) instead of only non-`google_fonts` families.

### 6. Static loading placeholder

The waiting state is one `Text` in the target style with `onSurface` at 25%
alpha. No `Stack`, no transparent duplicate, no spinner. The placeholder is
visibly a placeholder, and it does not animate or allocate a ticker.

### 7. Precomputed search keys

`CatalogueEntry` computes `searchName` and `searchCategory` once, at index
build time. `_rebuildResults` compares against those fields directly. Sorting
uses `searchName` for alphabetical/trending. No per-keystroke lowercasing of
the catalogue.

### 8. Next-batch prefetch

After a batch is revealed, `ExploreScreen` schedules a 300 ms idle timer:

- cancel it on reset, query change, sort change, and dispose;
- when it fires, verify the request token still matches and no batch is in
  flight, then take the next 5 entries from the current filtered results and
  call `FontService.prefetchPreviewBytes(model)` for each;
- `prefetchPreviewBytes` resolves the regular-weight URL, returns on a cache
  hit, otherwise acquires the same 3-slot limiter, downloads the bytes, stores
  them in the existing 64-entry LRU, and **does not** call `FontLoader.load`;
- errors are swallowed; prefetch is best-effort and never blocks a visible
  card. A per-URL in-flight set prevents duplicate prefetches.

### 9. DartPad mirror

`lib/dartpad_main.dart` receives the same entry/index, per-family preview,
placeholder, search-key, and prefetch behavior. It uses:

- `MemoryCatalogueStore` (no `shared_preferences` import);
- the web paint-first decode path (no isolates);
- no persistence. This is a documented platform limitation, consistent with the
  README's "in-memory caching only" row.

### 10. Test seams

`FontService` gains a `@visibleForTesting http.Client? debugHttpClient` used by
both the catalogue fetch and font downloads. Tests use
`package:http/testing.dart`'s `MockClient` (already shipped with `http`).
`FontService` also gains `@visibleForTesting` setters for the catalogue store
and a way to reset memoised state between tests (`clearCache` already exists;
extend it to clear the new index/store references where appropriate).

## Decisions left to the builder (my calls, listed for approval)

1. `FontPaginator` becomes generic with an `idOf` key function. (Call)
2. Persist only the last-used sort's raw body; writes are best-effort and
   skipped over ~4 MB on web. (Call)
3. Background revalidation never yanks an interacted list; the fresh catalogue
   waits for the next natural reset. (Call)
4. The DartPad mirror has no persistence and no isolates. (Call, documented)
5. Web decodes after first paint unless `compute` demonstrably uses a worker on
   the pinned Flutter build. (Call, verified during implementation)
6. Prefetch only regular-weight bytes for the next batch, idle-scheduled and
   token-guarded, never `FontLoader.load`. (Call)

## Acceptance criteria

1. The Explore screen paints its skeleton before the catalogue decode starts;
   the decode does not run on the UI thread on native platforms.
2. A warm launch shows the first 5 families without waiting on the network and
   revalidates in the background.
3. Two preview families load independently: a slow one does not hold the other
   in `waiting`; a failed one does not block the other.
4. No card builds a `CircularProgressIndicator` or a two-`Text` loading stack.
5. Typing in search uses precomputed keys and does not lowercase the whole
   catalogue per keystroke.
6. Scrolling into the next batch finds its regular-weight bytes in the LRU cache
   in the common case.
7. Revalidation never clears the query, resets the scroll offset, or changes the
   selection.
8. `flutter analyze` clean; all existing tests plus the new tests pass;
   `flutter build web --release` succeeds.
9. The DartPad mirror passes its manual smoke run with parity for everything
   except persistence.

## Risks and mitigations

- **`shared_preferences` quota on web.** Best-effort writes, single-sort cache,
  size guard, and graceful fallback to no persistence.
- **Isolate transfer cost.** The decoded `items` list is copied back; still
  cheaper than a main-thread decode. If the copy shows up in profiling, switch
  to a flat transferable index.
- **`compute` semantics on web.** Verified during implementation; paint-first is
  the fallback.
- **Revalidation races.** Existing `_catalogueRequestId` and `_requestId` tokens
  gate every completion; the pending-swap path only applies on a reset.
- **Generic paginator churn.** All call sites and tests are updated in the same
  task; the generation guard and dedup semantics are preserved.
- **DartPad divergence.** The only intentional difference is persistence; the
  README's limitation table is updated to say so.
