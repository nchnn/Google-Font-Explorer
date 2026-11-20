import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:type_studio/app.dart';
import 'package:type_studio/data/font_data.dart';
import 'package:type_studio/screens/explore_screen.dart';

// The home screen blob animation uses repeat(), preventing pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _openExplore(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const TypeStudioApp());
  await _settle(tester);
  await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
  await _settle(tester);
}

void main() {
  Color? hairlineColor(WidgetTester tester) => tester
      .widget<Container>(find.byKey(const Key('pinned-search-hairline')))
      .color;

  testWidgets('search stays at a fixed position while the list scrolls', (tester) async {
    await _openExplore(tester);
    expect(find.byKey(const Key('pinned-search')), findsOneWidget);

    // At rest the bar is flush with the content, so the hairline is invisible.
    expect(hairlineColor(tester)!.a, 0.0,
        reason: 'the hairline must be invisible before the list scrolls');

    // The bar only pins once the title above it has scrolled off, so measure
    // the "fixed" position from an already-scrolled state.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -1200));
    await _settle(tester);
    expect(hairlineColor(tester)!.a, 1.0,
        reason: 'the hairline must appear once the list has scrolled');
    final before = tester.getTopLeft(find.byKey(const Key('pinned-search')));

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -300));
    await _settle(tester);

    final after = tester.getTopLeft(find.byKey(const Key('pinned-search')));
    expect(after.dy, closeTo(before.dy, 1.0),
        reason: 'the bar must stay pinned while the list scrolls');

    // Back at the top the content is once again flush with the bar.
    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, 3000));
    await _settle(tester);
    expect(hairlineColor(tester)!.a, 0.0,
        reason: 'the hairline must disappear again at the top of the list');
  });

  testWidgets('title scrolls away but search remains tappable', (tester) async {
    await _openExplore(tester);
    expect(find.text('Explore fonts'), findsOneWidget);

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -1200));
    await _settle(tester);

    expect(find.text('Explore fonts'), findsNothing,
        reason: 'the title must scroll away once the bar is pinned');

    final search = find.byType(TextField).first;
    expect(search, findsOneWidget);
    expect(tester.getRect(search).top, greaterThanOrEqualTo(0.0));
    await tester.enterText(search, 'Roboto');
    await tester.pump(const Duration(milliseconds: 350));
    await _settle(tester);
    expect(find.textContaining('Showing 1 of 1'), findsOneWidget);
  });

  testWidgets('cards scroll beneath the pinned bar, whose padding keeps the taps', (tester) async {
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
    await _settle(tester);

    await tester.drag(find.byKey(const Key('explore-scroll')), const Offset(0, -600));
    await _settle(tester);

    final bar = tester.getRect(find.byKey(const Key('pinned-search')));
    // Font cards only: the error/offline banner is a Card too and must not be
    // able to satisfy the preconditions below.
    final fontCards = find.descendant(
      of: find.byKey(const Key('font-list')),
      matching: find.byType(Card),
    );
    final underBar = fontCards.evaluate().where((element) {
      return tester.getRect(find.byWidget(element.widget)).overlaps(bar);
    });
    expect(underBar, isNotEmpty,
        reason: 'the list must actually scroll underneath the pinned bar');

    // The field is a child of the bar and always wins its own hits, so the
    // surface the bar has to defend is its padding ring. Tap inside that ring,
    // outside the field, but over the covered card's own tap target - a point
    // the card would not react to could never be leaked to it, which would make
    // this assertion vacuous. Both bands are tried because the card may only
    // reach into one of them.
    final field = tester.getRect(find.byType(TextField).first);
    final coveredCardRect = tester.getRect(find.byWidget(underBar.first.widget));
    final leakPoints = <Offset>[
      Offset(coveredCardRect.center.dx, bar.top + 2),
      Offset(coveredCardRect.center.dx, bar.bottom - 3),
    ];
    final leakPoint = leakPoints.where((point) {
      final inBar = point.dy >= bar.top && point.dy <= bar.bottom;
      final outsideField = point.dy < field.top || point.dy > field.bottom;
      final overCard = point.dy >= coveredCardRect.top && point.dy <= coveredCardRect.bottom;
      return inBar && outsideField && overCard;
    }).firstOrNull;
    if (leakPoint == null) {
      fail('no padding point of the pinned bar (${bar.height}px tall) sits over a '
          'card (${coveredCardRect.top}..${coveredCardRect.bottom}) outside the '
          'field, so the tap-through check would be vacuous');
    }

    await tester.tapAt(leakPoint);
    await tester.pump(const Duration(milliseconds: 300));
    expect(selections, 0,
        reason: "the bar's padding must not leak taps to the card beneath it");

    // Positive control: a tap outside the bar has to reach its card, otherwise
    // the assertion above would pass on a screen where taps do nothing at all.
    final listRect = tester.getRect(find.byKey(const Key('explore-scroll')));
    final cardsBelowBar = fontCards.evaluate().where((element) {
      final rect = tester.getRect(find.byWidget(element.widget));
      return rect.top > bar.bottom && rect.bottom <= listRect.bottom;
    }).toList();
    expect(cardsBelowBar, isNotEmpty,
        reason: 'a fully visible card below the bar is needed for the tap-through control');

    await tester.tapAt(tester.getRect(find.byWidget(cardsBelowBar.first.widget)).center);
    await _settle(tester);
    expect(selections, 1,
        reason: 'a tap outside the bar must still reach its card, or the check above proves nothing');
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
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('pinned-search')), findsOneWidget);
    final bar = tester.getRect(find.byKey(const Key('pinned-search')));
    final field = tester.getRect(find.byType(TextField).first);
    expect(field.bottom, lessThanOrEqualTo(bar.bottom + 1.0),
        reason: 'the pinned bar must be tall enough for the scaled field');
  });
}
