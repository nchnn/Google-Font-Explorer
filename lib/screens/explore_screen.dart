import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../config/google_fonts_config.dart';
import '../data/font_data.dart';
import '../models/catalogue_entry.dart';
import '../models/font_model.dart';
import '../services/font_paginator.dart';
import '../services/font_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/fade_in_batch.dart';
import '../widgets/floating_pill_navigation.dart';
import '../widgets/error_banner.dart';
import '../widgets/explore_search_bar.dart';
import '../widgets/font_card.dart';
import '../widgets/offline_banner.dart';

/// Screen allowing users to discover and search fonts directly from the
/// Google Fonts Developer API catalogue, with debounced live search filtering,
/// category filtering, sorting (popularity, A–Z, trending), and error handling.
///
/// The catalogue itself downloads once: `webfonts/v1` has no pagination
/// parameters, and [FontPaginator] reveals it [FontPaginator.defaultPageSize]
/// families at a time as the user reaches the bottom of the list.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.selectedFont,
    this.onSelectFont,
    this.debugPaginator,
  });

  /// When null, reads from [AppState.of].
  final FontModel? selectedFont;

  /// When null, calls [AppState.selectFont].
  final ValueChanged<FontModel>? onSelectFont;

  /// Optional paginator seam for tests.
  ///
  /// Production never passes this, so the screen owns a default
  /// [FontPaginator]; the state cannot initialise the field from `widget`.
  @visibleForTesting
  final FontPaginator<CatalogueEntry>? debugPaginator;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const Duration kSearchDebounce = Duration(milliseconds: 300);

  // ---------------------------------------------------------------------------
  // State look-up helpers: fall back to AppState when constructor params are
  // null, which is the production case. Tests can still pass explicit values.
  // ---------------------------------------------------------------------------

  FontModel _effectiveSelectedFont(BuildContext context) =>
      widget.selectedFont ?? AppState.read(context).selectedFont;

  ValueChanged<FontModel> _effectiveOnSelectFont(BuildContext context) =>
      widget.onSelectFont ??
      (font) {
        final appState = AppState.read(context);
        appState.selectFont(font, preview: PreviewState.read(context));
      };

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
  FontCatalogue? _pendingCatalogue;

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
    _paginator =
        widget.debugPaginator ??
        FontPaginator<CatalogueEntry>(idOf: (e) => e.name);
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
    if (position.pixels >=
        position.maxScrollExtent - _loadMoreTriggerDistance) {
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
        unawaited(
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
          ),
        );
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
      _catalogueEntries = _sortEntries(
        availableFonts.map(CatalogueEntry.fromModel).toList(),
      );
      _rebuildResults();
      _scheduleViewportFillCheck();
      return;
    }

    // Only show full blocking spinner on cold start when there's no data yet
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
      _applyCatalogue(catalogue);
      _rebuildResults();
      _scheduleViewportFillCheck();

      // If catalogue is from cache, trigger background revalidation
      if (catalogue.isFromCache) {
        unawaited(_revalidateCatalogue(catalogueId, catalogue.rawBody));
      }
    } on FontApiException catch (e) {
      if (!mounted || catalogueId != _catalogueRequestId) return;
      _isLoading = false;
      _errorMessage = e.message;
      _isMissingApiKey = e.isMissingApiKey;
      _catalogueEntries = _sortEntries(
        availableFonts.map(CatalogueEntry.fromModel).toList(),
      );
      _rebuildResults();
      _scheduleViewportFillCheck();
    } catch (e) {
      if (!mounted || catalogueId != _catalogueRequestId) return;
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred: $e';
      _catalogueEntries = _sortEntries(
        availableFonts.map(CatalogueEntry.fromModel).toList(),
      );
      _rebuildResults();
      _scheduleViewportFillCheck();
    }
  }

  Future<void> _revalidateCatalogue(
    int catalogueId,
    String cachedRawBody,
  ) async {
    try {
      final fresh = await FontService.instance.fetchCatalogue(
        sort: _sortOrder,
        forceRefresh: true,
      );
      if (!mounted || catalogueId != _catalogueRequestId) return;

      // If the body is unchanged, do nothing.
      if (fresh.rawBody == cachedRawBody) {
        return;
      }

      // Check if user has interacted:
      final isScrollNearTop =
          !_scrollController.hasClients ||
          _scrollController.position.pixels <= 10;
      final hasNotInteracted =
          _query.isEmpty &&
          _selectedCategory == 'All' &&
          _paginator.visibleCount <= FontPaginator.defaultPageSize &&
          isScrollNearTop &&
          !_isLoadingMore;

      if (hasNotInteracted) {
        _applyCatalogue(fresh);
        _rebuildResults();
      } else {
        _pendingCatalogue = fresh;
      }
    } catch (_) {
      // Revalidation errors are silent; cached list stays usable.
    }
  }

  void _applyCatalogue(FontCatalogue catalogue) {
    _catalogueEntries = _sortEntries(catalogue.entries);
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

    // Natural reset applies any pending revalidated catalogue first
    if (_pendingCatalogue != null) {
      _applyCatalogue(_pendingCatalogue!);
      _pendingCatalogue = null;
    }

    final normalizedQuery = _query.toLowerCase();
    final normalizedCategory = _selectedCategory.toLowerCase();
    final filtered = <CatalogueEntry>[];
    final seenNames = <String>{};

    for (final entry in _catalogueEntries) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          entry.searchName.contains(normalizedQuery) ||
          entry.searchCategory.contains(normalizedQuery);
      final matchesCategory =
          _selectedCategory == 'All' ||
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
    // A reset invalidates any batch that is still in flight; the stale
    // completion bails on the request token and must not leave the footer
    // spinning forever.
    _isLoadingMore = false;
    setState(() {
      // A reset clamps the scroll offset without emitting a scroll event, so
      // [_updateScrollTop] never runs; clear the overlay here or it can linger
      // visibly and interactively over a card after a search, chip or sort.
      _fabHideTimer?.cancel();
      _fabHideTimer = null;
      _showScrollTop = false;
    });
    // A reset can leave the new result set too short to scroll, in which case
    // the scroll listener never fires; refill the viewport so a filter/search
    // reset on a tall viewport cannot strand the list at one batch.
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
      // The result is ignored on purpose: an abandoned batch returns an empty
      // list, which looks identical to "nothing to reveal". Whether another
      // batch is available is always read from the paginator.
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

  /// Schedules prefetching regular-weight font bytes for the next batch after
  /// an idle delay so scrolling into the next batch finds bytes in cache.
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
          // reuses the cards instead of rebuilding them from scratch. This is the
          // 320 px cache the plan specifies; Flutter 3.50 deprecated `cacheExtent`
          // in favour of `scrollCacheExtent`.
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
                      child: ExploreSearchBar(
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
                  // Sorting Segmented Control (Requirement 4)
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
                              label: Text(
                                'Popular',
                                style: TextStyle(fontSize: 11),
                              ),
                              icon: Icon(Icons.star_outline_rounded, size: 14),
                            ),
                            ButtonSegment(
                              value: FontSortOrder.alphabetical,
                              label: Text(
                                'A–Z',
                                style: TextStyle(fontSize: 11),
                              ),
                              icon: Icon(Icons.sort_by_alpha_rounded, size: 14),
                            ),
                            ButtonSegment(
                              value: FontSortOrder.trending,
                              label: Text(
                                'Trending',
                                style: TextStyle(fontSize: 11),
                              ),
                              icon: Icon(Icons.trending_up_rounded, size: 14),
                            ),
                          ],
                          selected: {_sortOrder},
                          onSelectionChanged: (values) =>
                              _handleSortChanged(values.first),
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
                            selectedColor: isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E2E2),
                            checkmarkColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Error or Notice Banner (Network Error Handling)
                  if (_errorMessage != null)
                    ErrorBanner(
                      errorMessage: _errorMessage,
                      isMissingApiKey: _isMissingApiKey,
                      onRetry: () =>
                          unawaited(_fetchCatalogue(forceRefresh: true)),
                      onUseOffline: () {
                        _useOfflineCatalog = true;
                        _errorMessage = null;
                        _catalogueEntries = _sortEntries(
                          availableFonts.map(CatalogueEntry.fromModel).toList(),
                        );
                        _rebuildResults();
                        _scheduleViewportFillCheck();
                      },
                    )
                  else if (_useOfflineCatalog)
                    OfflineBanner(
                      onConnect: () {
                        _useOfflineCatalog = false;
                        unawaited(_fetchCatalogue(forceRefresh: true));
                      },
                    ),
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
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                        CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: theme.disabledColor,
                        ),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                          isSelected:
                              _effectiveSelectedFont(context).name ==
                              entry.name,
                          onTap: () =>
                              _effectiveOnSelectFont(context)(entry.model),
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (!_isLoading && !_paginator.isEmpty) _buildBatchFooter(context),

            // Keep the pagination footer clear of the floating navigation pill.
            const SliverToBoxAdapter(
              child: SizedBox(height: kFloatingPillNavigationClearance),
            ),
          ],
        ),
        // Overlay, not chrome: it is hidden and inert until the list has
        // scrolled past [_scrollTopThreshold], so it never blocks a tap on a
        // card at rest.
        // Above the floating navigation pill: at 360 dp the plan's original
        // `bottom: 16` sat on top of it. The pill itself is untouched.
        Positioned(
          right: 16,
          bottom: kFloatingPillNavigationClearance + 16,
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
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _retryLoadMore,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    } else if (!_paginator.hasMore &&
        totalCount > FontPaginator.defaultPageSize) {
      content = Text(
        'All $totalCount font families loaded.',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
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
}
