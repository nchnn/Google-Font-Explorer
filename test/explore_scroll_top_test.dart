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
