import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:type_studio/app.dart';
import 'package:type_studio/data/font_data.dart';
import 'package:type_studio/models/catalogue_entry.dart';
import 'package:type_studio/screens/explore_screen.dart';
import 'package:type_studio/services/font_paginator.dart';
import 'package:type_studio/widgets/font_card.dart';

/// Fails every batch so the footer error path can be exercised.
class _ExplodingPaginator extends FontPaginator<CatalogueEntry> {
  _ExplodingPaginator() : super(idOf: (e) => e.name);

  @override
  Future<List<CatalogueEntry>> loadNextPage() async {
    await Future<void>.delayed(Duration.zero);
    throw StateError('injected failure');
  }
}

/// Resolves batches only when [complete] is called, so a query change can
/// race an in-flight batch.
///
/// Every batch gets its own gate, queued in call order, so a test can hold two
/// batches open at once and complete them independently.
class _SlowPaginator extends FontPaginator<CatalogueEntry> {
  _SlowPaginator() : super(idOf: (e) => e.name);

  final List<Completer<void>> _gates = <Completer<void>>[];

  /// When true the next gated batch throws instead of resolving, so a stale
  /// failure (not just a stale success) can be injected.
  bool failNext = false;

  /// Completes the oldest suspended batch.
  void complete() {
    if (_gates.isEmpty) return;
    _gates.removeAt(0).complete();
  }

  @override
  Future<List<CatalogueEntry>> loadNextPage() async {
    final shouldFail = failNext;
    final startingVisible = visibleCount;
    final startingTotal = totalCount;
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    if (shouldFail) {
      throw StateError('injected stale batch failure');
    }
    // A reset while this batch was suspended replaced the source list. The real
    // paginator abandons such a batch without advancing the new cursor, and the
    // screen's request token is what discards its result.
    if (visibleCount != startingVisible || totalCount != startingTotal) {
      return const <CatalogueEntry>[];
    }
    return super.loadNextPage();
  }
}

/// Holds the catalogue request open until [gate] completes, then fails with a
/// 500 so the screen takes its offline-catalogue fallback.
class _GatedCatalogueClient extends http.BaseClient {
  _GatedCatalogueClient(this.gate);

  final Completer<void> gate;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await gate.future;
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      500,
      request: request,
      reasonPhrase: 'Injected failure',
    );
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

/// Mounts the Explore screen directly against a test paginator.
Future<void> _mountExplore(
  WidgetTester tester,
  FontPaginator<CatalogueEntry> paginator, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
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
}

int _listItemCount(WidgetTester tester) {
  final list = tester.widget<SliverList>(find.byKey(const Key('font-list')));
  return (list.delegate as SliverChildBuilderDelegate).childCount!;
}

void main() {
  testWidgets('initial batch reveals 5 families', (tester) async {
    // A phone-sized viewport: the first five cards overflow it, so the fill
    // check stays idle and the first batch is exactly one page.
    await _openExplore(tester, size: const Size(1080, 1000));
    expect(find.textContaining('Showing 5 of'), findsOneWidget);
    expect(_listItemCount(tester), 5);
  });

  testWidgets('reaching the bottom appends 5 more without jumping', (tester) async {
    final paginator = _SlowPaginator();
    await _mountExplore(tester, paginator, size: const Size(1080, 1000));
    expect(_listItemCount(tester), 5);

    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    // The batch is gated, so the pre-append offset can be read while the old
    // content is still laid out.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pump();
    final offsetBeforeAppend = position.pixels;
    expect(offsetBeforeAppend, greaterThan(0.0));
    expect(find.text('Loading more fonts...'), findsOneWidget,
        reason: 'the drag must start a batch on the screen, not just in the paginator');

    paginator.complete();
    await tester.pumpAndSettle();

    expect(_listItemCount(tester), 10);
    expect(
      position.pixels,
      closeTo(offsetBeforeAppend, 1.0),
      reason: 'appending a batch must not reset the scroll position',
    );
  });

  testWidgets('the list fills a viewport taller than one batch', (tester) async {
    await _openExplore(tester, size: const Size(1400, 3000));
    expect(_listItemCount(tester), greaterThan(5),
        reason: 'five cards do not overflow this viewport, so the fill check must load more');
  });

  testWidgets('a search resets to the first batch', (tester) async {
    // A tall viewport fills several batches without scrolling, so the search
    // field stays reachable (pin-independent) while more than one batch is up.
    await _openExplore(tester, size: const Size(1400, 3000));
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
    // A viewport where five cards overflow, so the restored result is exactly
    // one page rather than being topped up by the fill check.
    await _openExplore(tester, size: const Size(1080, 1000));
    await tester.enterText(find.byType(TextField).first, 'Roboto');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(_listItemCount(tester), 1);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(_listItemCount(tester), 5);
  });

  testWidgets('a search reset fills a tall viewport beyond the first batch', (tester) async {
    // Regression: a filter/search reset must re-run the viewport fill check.
    // Five cards never overflow this viewport, so without it the list would be
    // stranded at 'Showing 5 of 12' with maxScrollExtent == 0.
    await _openExplore(tester, size: const Size(1400, 3000));
    // 'a' matches all twelve bundled families (names or categories).
    await tester.enterText(find.byType(TextField).first, 'a');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(_listItemCount(tester), greaterThan(5),
        reason: 'a reset must refill a viewport too short to generate a scroll event');
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    if (position.maxScrollExtent == 0) {
      // Nothing can generate a scroll event, so reaching the fill check's goal
      // means every match is already revealed.
      expect(find.textContaining('Showing 12 of 12'), findsOneWidget,
          reason: 'a viewport with no scroll extent must reveal every match');
    }
  });

  testWidgets('the cursor stops at the end of the catalogue', (tester) async {
    await _openExplore(tester);
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -6000));
    await tester.pumpAndSettle();
    // Appending never auto-scrolls, so the freshly loaded last batch leaves
    // the footer below the fold; one more scroll brings it into view.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(_listItemCount(tester), 12);
    expect(find.textContaining('All 12 font families'), findsOneWidget);

    // The counter is a normal scrolling sliver below the pinned search bar, not
    // a pinned row, so it has scrolled away by the bottom of the catalogue.
    // Scroll back up to read it.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, 6000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Showing 12 of 12'), findsOneWidget);
  });

  testWidgets('a failed batch shows Retry and keeps the loaded families', (tester) async {
    final paginator = _ExplodingPaginator();
    await _mountExplore(tester, paginator, size: const Size(1080, 1920));

    final before = _listItemCount(tester);
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(_listItemCount(tester), before, reason: 'a failed batch must not advance the cursor');
    expect(paginator.visibleCount, before);
  });

  testWidgets('a batch arriving after a query change is discarded', (tester) async {
    final paginator = _SlowPaginator()..failNext = true;
    // A phone-sized viewport keeps the fill check idle, so the only batch in
    // flight is the one this test starts by scrolling.
    await _mountExplore(tester, paginator, size: const Size(1080, 1000));

    // Drive the batch through the screen: dragging to the bottom puts
    // _loadMore (and its request token) in flight against the gated paginator.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pump();
    expect(find.text('Loading more fonts...'), findsOneWidget,
        reason: 'the screen, not the paginator, must own the in-flight batch');

    // Scroll back up so the search field is reachable, then change the query
    // while the batch is still suspended.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, 3000));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Roboto');
    await tester.pump(const Duration(milliseconds: 350));

    // The suspended batch now fails against a result set it no longer owns.
    paginator.complete();
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing 1 of 1'), findsOneWidget);
    expect(_listItemCount(tester), 1,
        reason: 'the stale batch must not append to the new result set');
    expect(find.text('Retry'), findsNothing,
        reason: 'a stale batch failure must not offer a Retry for the new result set');
    expect(find.textContaining('Could not load more font families'), findsNothing,
        reason: 'a stale batch failure must not surface in the new result set');
  });

  testWidgets('a stale batch success cannot corrupt the new result set cursors', (tester) async {
    final paginator = _SlowPaginator();
    await _mountExplore(tester, paginator, size: const Size(1080, 1000));

    // Reveal a second page so the batch that goes stale starts from a cursor
    // the new result set will not share.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pump();
    expect(find.text('Loading more fonts...'), findsOneWidget);
    paginator.complete();
    await tester.pumpAndSettle();
    expect(_listItemCount(tester), 10);

    // This batch will outlive its result set.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pump();
    expect(find.text('Loading more fonts...'), findsOneWidget);

    // 'a' matches all twelve families, so the new result set has a second page.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, 3000));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'a');
    await tester.pump(const Duration(milliseconds: 350));
    expect(_listItemCount(tester), 5);

    // The batch now succeeds against a result set it no longer owns.
    paginator.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The next batch must start from the new result set's cursor. A stale
    // success that wrote its old cursor would trip _loadMore's invariant
    // (assert(_fadeFromIndex <= _paginator.visibleCount)).
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -3000));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'a stale success must not corrupt the new result set cursors');
    expect(find.text('Loading more fonts...'), findsOneWidget,
        reason: 'the new result set must still be able to page');
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a search during a pending catalogue fetch does not strand the spinner',
      (tester) async {
    final gate = Completer<void>();

    // runWithClient routes FontService's http.get through the gated client, so
    // the catalogue download is still in flight when the query changes.
    await http.runWithClient(() async {
      tester.view.physicalSize = const Size(1080, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TypeStudioApp());
      await tester.pump();
      await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
      await tester.pump();
      expect(find.text('Fetching Google Fonts catalogue...'), findsOneWidget);

      // Type inside the network window, before the catalogue arrives.
      await tester.enterText(find.byType(TextField).first, 'Roboto');
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Fetching Google Fonts catalogue...'), findsOneWidget,
          reason: 'the catalogue request is still in flight');

      gate.complete();
      // Bounded pumps rather than pumpAndSettle: the bug leaves the load
      // spinner animating forever, which would surface as a timeout instead of
      // the assertion below.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Fetching Google Fonts catalogue...'), findsNothing,
          reason: 'a query change must not abandon the fetch and leave the spinner up');
      expect(find.textContaining('Showing 1 of 1'), findsOneWidget);
      expect(_listItemCount(tester), 1);
    }, () => _GatedCatalogueClient(gate));
  });

  testWidgets('no duplicate families appear after several batches', (tester) async {
    await _openExplore(tester);
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -6000));
      await tester.pumpAndSettle();
    }
    final cards = find.descendant(
      of: find.byKey(const Key('font-list')),
      matching: find.byType(FontCard, skipOffstage: false),
    );
    final names = tester.widgetList<FontCard>(cards).map((c) => c.font.name).toList();
    expect(names, isNotEmpty);
    expect(names.toSet().length, names.length);
  });
}
